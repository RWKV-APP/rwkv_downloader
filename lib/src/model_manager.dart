import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:rwkv_downloader/rwkv_downloader.dart';
import 'package:rwkv_downloader/src/logger.dart';
import 'package:rwkv_downloader/src/model/model.dart';
import 'package:rxdart/rxdart.dart';

typedef ModelFilter = bool Function(ModelInfo config);

typedef TaskId = String;

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

  late final _dio = Dio();

  ModelConfig _config = ModelConfig.empty();

  // model-file-name to model info
  Map<String, ModelInfo> _models = {};
  Map<TaskId, DownloadTask> _downloadTasks = {};

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
  List<ModelInfo> get models => _models.values.toList();

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

  Future init() async {
    await _checkDownloadDirAvailable();
    await _updateLocalModelFiles();
    try {
      await updateConfig();
      return;
    } catch (e) {
      Logger.debug(tag, 'pull remote config failed: $e');
    }
    try {
      await _restoreCache();
    } catch (e) {
      Logger.debug(tag, 'restore cache failed: $e');
    }
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
  Stream<DownloadEvent> downloadUpdateEvents({TaskId? id}) {
    var stream = _downloadEvent.stream;
    if (id == null) {
      return stream;
    }
    _checkDownloadTask(id);
    stream = stream.where((event) => event.model.id == id);
    return stream.takeWhileInclusive((e) => e.update.isRunning);
  }

  Future cancelTask(TaskId id) async {
    _checkDownloadTask(id);
    final task = _downloadTasks[id]!;
    await task.cancel();
    _downloadTasks.remove(id);
  }

  Future pauseTask(TaskId id) async {
    _checkDownloadTask(id);
    final task = _downloadTasks[id]!;
    assert(task.state == TaskState.running);
    await task.stop();
  }

  Future<TaskId> download(ModelInfo model) async {
    final taskId = model.url;
    final exists = _downloadTasks[taskId];
    if (exists != null && exists.state == TaskState.running) {
      throw Exception('model already downloading');
    }
    File file = File(
      [_modelDownloadDir.path, model.fileName].join(Platform.pathSeparator),
    );
    if (await file.exists()) {
      throw Exception('file already downloaded');
    }
    final task = await downloadSource.createDownloadTask(model.url, file.path);

    task.md5 = model.md5;
    task.sha256 = model.sha256;
    task.verifier = _downloadFileVerifier;

    _downloadTasks[taskId] = task;

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
      _downloadTasks.remove(taskId);
      rethrow;
    }
    return model.id;
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
      } else if (!_models.containsKey(name)) {
        Logger.info(tag, 'delete outdated model file: ${file.path}');
      }
    }
  }

  void _checkDownloadTask(TaskId id) {
    if (!_downloadTasks.containsKey(id)) {
      throw StateError('no such task: ${id}');
    }
  }

  Future _restoreCache() async {
    final file = await File(_configFileCachePath);
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
    _models = {};
    for (final model in _config.models) {
      if (_modelFilter != null && !_modelFilter!(model)) {
        continue;
      }
      if (_excludeModelFilter != null && _excludeModelFilter!(model)) {
        continue;
      }
      final file = _localCacheFiles[model.fileName];
      _models[model.fileName] = model.copyWith(localPath: file?.path);
    }
    Logger.debug(
      tag,
      'config resolved: '
      'version: ${_config.version}, '
      'timestamp: ${_config.timestamp}, '
      '${_models.length}/${_config.models.length} available models, '
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
        final info = _models[fileName];
        if (info != null) {
          _models[fileName] = info.copyWith(localPath: file.path);
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
