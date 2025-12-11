import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:rwkv_downloader/rwkv_downloader.dart';
import 'package:rwkv_downloader/src/exception.dart';
import 'package:rwkv_downloader/src/logger.dart';
import 'package:rxdart/rxdart.dart';

typedef ModelFilter = bool Function(ModelInfo config);

typedef ModelId = String;

bool _defaultModelFilter(ModelInfo config) {
  if (config.isDebug) {
    return false;
  }
  final conditions = {
    config.platforms.contains(ModelPlatform.current),
    config.backend != ModelBackend.qnn || !Platform.isAndroid,
    config.backend != ModelBackend.mlx || !Platform.isIOS,
    config.backend != ModelBackend.albatross ||
        !Platform.isWindows ||
        !Platform.isLinux,
  };
  return conditions.every((element) => element);
}

class DownloadEvent {
  final ModelInfo model;

  /// The latest download task update state
  final TaskUpdate update;

  /// Non-null if error occurred
  final dynamic error;

  DownloadEvent({required this.model, required this.update, this.error});
}

class ModelManager {
  static const String tag = 'ModelManager';
  static const ModelFilter defaultModelFilter = _defaultModelFilter;

  late final _dio = Dio(
    BaseOptions(
      connectTimeout: Duration(seconds: 3),
      receiveTimeout: Duration(seconds: 3),
    ),
  );

  ModelConfig _config = ModelConfig.empty();

  // model-file-name to model info
  Map<String, ModelInfo> _filename2models = {};
  Map<String, ModelInfo> _id2model = {};
  Map<ModelId, DownloadTask> _downloadTasks = {};

  // file-name to file
  Map<String, File> _localCacheFiles = {};

  late final String? _remoteConfigUrl;
  late final String _configFileCachePath;
  late final Directory _modelDownloadDir;

  final _downloadEvent = StreamController<DownloadEvent>.broadcast();

  ModelFilter? _modelFilter;
  ModelFilter? _excludeModelFilter;

  FileVerifier _downloadFileVerifier;

  DownloadSource downloadSource = DownloadSource.auto;

  /// Return all models get from config file
  List<ModelInfo> get allModels => _config.models;

  /// Return available models
  List<ModelInfo> get models => _filename2models.values.toList();

  ModelManager({
    required DownloadSource downloadSource,
    required String modelDownloadDir,
    String? configFileCachePath,
    String? configProviderUrl,
    FileVerifier downloadFileVerifier = DownloadTask.defaultFileVerifier,
    ModelFilter? filter = defaultModelFilter,
    ModelFilter? exclude,
  }) : this._downloadFileVerifier = downloadFileVerifier,
       this.downloadSource = downloadSource,
       this._remoteConfigUrl = configProviderUrl,
       this._configFileCachePath =
           configFileCachePath ?? '${modelDownloadDir}/model_config.json',
       this._modelDownloadDir = Directory(modelDownloadDir),
       this._modelFilter = filter,
       this._excludeModelFilter = exclude;

  Future<Map<ModelId, DownloadTask>> init() async {
    await _checkDownloadDirAvailable();
    await _updateLocalModelFiles();
    try {
      await updateConfig();
    } catch (e) {
      Logger.debug(tag, 'pull remote config failed: $e');
      try {
        await _restoreCache();
      } catch (e) {
        Logger.debug(tag, 'restore cache failed: $e');
      }
    }
    await _restoreDownloadTasks();
    Logger.info(tag, 'initialized!');
    return {..._downloadTasks};
  }

  /// Try to pull config-file from remote, update local cache, and model list.
  Future updateConfig() async {
    if (_remoteConfigUrl == null || _remoteConfigUrl.isEmpty) {
      throw Exception('configUrl is not set');
    }
    // todo version check
    final response = await _dio.get(_remoteConfigUrl);
    if (response.statusCode == 200) {
      _config = ModelConfig.fromMap(response.data);
      _resolveConfig();
      Logger.info(tag, 'update config success');
      final cache = File(_configFileCachePath);
      if (await cache.exists()) {
        await cache.delete();
      }
      await cache.create();
      await cache.writeAsString(jsonEncode(_config.toMap()));
      Logger.info(tag, 'cache config success');
    }
  }

  /// Event stream for download tasks.
  Stream<DownloadEvent> downloadUpdateEvents({ModelId? id}) {
    var stream = _downloadEvent.stream;
    if (id == null) {
      return stream;
    }
    _checkDownloadTask(id);
    stream = stream.where((event) => event.model.id == id);
    return stream.takeWhileInclusive((e) => e.update.isRunning);
  }

  Future cancelTask(ModelId id) async {
    _checkDownloadTask(id);
    final task = _downloadTasks[id]!;
    await task.cancel();
    _downloadTasks.remove(id);
  }

  Future pauseTask(ModelId id) async {
    _checkDownloadTask(id);
    final task = _downloadTasks[id]!;
    assert(task.state == TaskState.running);
    await task.stop();
  }

  Future download(ModelId id) async {
    final model = models.firstWhere((element) => element.id == id);
    final exists = _downloadTasks[id];
    if (exists != null && exists.state == TaskState.running) {
      throw DownloadException(message: 'model already downloading');
    }
    File file = File(
      [_modelDownloadDir.path, model.fileName].join(Platform.pathSeparator),
    );
    if (await file.exists()) {
      throw DownloadException(message: 'file already downloaded');
    }
    final task = await downloadSource.createDownloadTask(model.url, file.path);

    task.md5 = model.md5;
    task.sha256 = model.sha256;
    task.verifier = _downloadFileVerifier;

    _downloadTasks[id] = task;

    final sp = task.events().listen(
      (event) {
        _downloadEvent.add(DownloadEvent(model: model, update: event));
      },
      onDone: () {
        _updateLocalModelFiles();
      },
      onError: (e) {
        _downloadEvent.add(
          DownloadEvent(model: model, update: task.update, error: e),
        );
        _updateLocalModelFiles();
      },
    );
    try {
      await task.start();
    } catch (_) {
      sp.cancel();
      task.cancel();
      _downloadTasks.remove(id);
      rethrow;
    }
    return model.id;
  }

  Future deleteLocalModelFiles(ModelId id) async {
    final model = models.firstWhere((element) => element.id == id);
    final path = [
      _modelDownloadDir.path,
      model.fileName,
    ].join(Platform.pathSeparator);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      _filename2models[model.fileName] = model.copyWith(localPath: '');
    } else {
      throw Exception('file not exists: $path');
    }
  }

  Future cleanOutdatedModelFiles({bool cleanDownloadCache = false}) async {
    if (!await _modelDownloadDir.exists()) {
      return;
    }
    final files = await _modelDownloadDir.list().toList();
    for (final file in files) {
      if (file is! File) {
        continue;
      }
      final name = file.path.split(Platform.pathSeparator).last;
      if (cleanDownloadCache && file.path.endsWith('.tmp')) {
        await file.delete();
        Logger.info(tag, 'delete download cache file: ${file.path}');
      } else if (!file.path.endsWith('.json')) {
        //
      } else if (!_filename2models.containsKey(name)) {
        Logger.info(tag, 'delete outdated model file: ${file.path}');
      }
    }
  }

  void _checkDownloadTask(ModelId id) {
    if (!_downloadTasks.containsKey(id)) {
      throw StateError('no such task: ${id}');
    }
  }

  Future _restoreCache() async {
    final file = File(_configFileCachePath);
    if (!await file.exists()) {
      return;
    }
    final cache = await file.readAsString();
    _config = ModelConfig.empty();
    if (cache.isNotEmpty) {
      final json = jsonDecode(cache);
      _config = ModelConfig.fromMap(json);
      _resolveConfig();
      Logger.info(tag, 'restore cache success');
    }
  }

  void _resolveConfig() {
    _filename2models = {};
    for (final model in _config.models) {
      if (_modelFilter != null && !_modelFilter!(model)) {
        continue;
      }
      if (_excludeModelFilter != null && _excludeModelFilter!(model)) {
        continue;
      }
      final file = _localCacheFiles[model.fileName];
      _filename2models[model.fileName] = model.copyWith(localPath: file?.path);
      _id2model[model.id] = model;
    }
    for (final id in _downloadTasks.keys) {
      if (!_id2model.containsKey(id)) {
        _downloadTasks.remove(id)?.cancel();
      }
    }
    Logger.debug(
      tag,
      'config resolved: '
      'version: ${_config.version}, '
      'timestamp: ${_config.timestamp}, '
      '${_filename2models.length}/${_config.models.length} available models, '
      '${_config.tags.length} tags, '
      '${_config.groups.length} groups',
    );
  }

  Future _updateLocalModelFiles() async {
    _localCacheFiles = {};
    try {
      if (!await _modelDownloadDir.exists()) {
        await _modelDownloadDir.create();
      }
      await for (final file in _modelDownloadDir.list()) {
        if (file is! File) continue;

        final fileName = file.path.split(Platform.pathSeparator).last;
        final suffix = fileName.split('.').last;

        if ({'json', 'txt', 'tmp', 'log'}.contains(suffix)) {
          continue;
        }
        _localCacheFiles[fileName] = File(file.path);
        final info = _filename2models[fileName];
        if (info != null) {
          _filename2models[fileName] = info.copyWith(localPath: file.path);
        }
      }
      Logger.info(
        tag,
        'update local model files success, ${_localCacheFiles.length} files',
      );
    } catch (e) {
      Logger.error(tag, 'list models failed: $e');
    }
  }

  Future _restoreDownloadTasks() async {
    try {
      if (!await _modelDownloadDir.exists()) {
        return;
      }
      _downloadTasks = {};
      await for (final file in _modelDownloadDir.list()) {
        if (file is! File) continue;

        final fileName = file.path.split(Platform.pathSeparator).last;

        if (!fileName.endsWith('.tmp')) {
          continue;
        }
        final realName = fileName.substring(0, fileName.length - 4);
        final model = _filename2models[realName];
        if (model != null) {
          try {
            _downloadTasks[model.id] = await downloadSource.createDownloadTask(
              model.url,
              file.path.substring(0, file.path.length - 4),
            );
          } catch (e) {
            Logger.error(tag, 'restore download task failed: $e');
          }
        }
      }
      Logger.info(tag, '${_downloadTasks.length} download tasks restored');
    } catch (e) {
      Logger.error(tag, 'restore download tasks failed: $e');
    }
  }

  Future _checkDownloadDirAvailable() async {
    final flagFile = File(
      '${_modelDownloadDir.path}${Platform.pathSeparator}.rwkv_downloader.json',
    );
    if (!await flagFile.exists()) {
      if (await _modelDownloadDir.exists()) {
        final files = await (await _modelDownloadDir.list()).toList();
        if (files.isNotEmpty) {
          Logger.error(
            tag,
            'IMPORTANT NOTE: [modelDownloadDir] absolute path is ${_modelDownloadDir.absolute.path}',
          );
          Logger.error(
            tag,
            'IMPORTANT NOTE: [modelDownloadDir] is not an empty directory before ModelManager is used.'
            ' Please select an empty directory to ensure file safety.',
          );
        }
      } else {
        await _modelDownloadDir.create();
        await flagFile.create();
      }
    }
  }
}
