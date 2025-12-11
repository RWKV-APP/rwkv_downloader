import 'dart:io';

import 'package:rwkv_downloader/rwkv_downloader.dart';
import 'package:rwkv_downloader/src/logger.dart';

class DownloadSource {
  static final _allDownloadSource = [
    aiFastHub,
    hfMirror,
    huggingface,
    googleApis,
  ];

  static final DownloadSource aiFastHub = DownloadSource(
    'https://aifasthub.com/',
  );
  static final DownloadSource hfMirror = DownloadSource(
    'https://hf-mirror.com/',
  );
  static final DownloadSource huggingface = DownloadSource(
    'https://huggingface.co/',
  );
  static final DownloadSource googleApis = DownloadSource(
    'https://googleapis.com/',
  );
  static final DownloadSource auto = _AutoDownloadSource();

  static Duration speedTestDuration = Duration(seconds: 10);
  static Duration speedTestRequestTimeout = Duration(seconds: 5);

  final String url;
  int speed = -1;

  String get name => this == auto ? 'auto' : Uri.parse(url).host;

  DownloadSource([this.url = '']);

  Future<DownloadTask> createDownloadTask(String path, String filePath) async {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return DownloadTask.create(url: path, path: filePath);
    }
    final Uri uri = Uri.parse(url).replace(path: path);
    return DownloadTask.create(url: uri.toString(), path: filePath);
  }

  Future<int> test(String path, String filePath) async {
    final task = await createDownloadTask(path, filePath);
    task.maxRetry = 0;
    task.md5 = null;
    task.sha256 = null;
    try {
      await task.start(deleteExist: true).timeout(speedTestRequestTimeout);
      () async {
        await Future.delayed(speedTestDuration);
        await task.stop();
        await task.cancel();
      }();
      final last = await task.events().last;
      speed = last.speed;
      return last.speed;
    } catch (e) {
      Logger.debug('DownloadSource', 'test failed: ${url}, ${e.toString()}');
      return -1;
    }
  }
}

class _AutoDownloadSource extends DownloadSource {
  static const tag = 'AutoDownloadSource';

  _AutoDownloadSource();

  DownloadSource? _source;

  @override
  String get url => _source!.url;

  @override
  Future<DownloadTask> createDownloadTask(String path, String filePath) async {
    final isUrl = path.startsWith('http://') || path.startsWith('https://');
    if (isUrl) {
      return DownloadTask.create(url: path, path: filePath);
    }
    final task = await DownloadTask.create(url: path, path: filePath);
    return _AutoSourceTask(source: this, task: task, resourcePath: path);
  }

  @override
  Future<int> test(String path, String filePath) async {
    if (_source == null) {
      Logger.debug(tag, 'start testing download sources...');
      final tasks = Future.wait([
        for (final (index, source) in DownloadSource._allDownloadSource.indexed)
          source
              .test(path, "${filePath}.${index}.spd_test")
              .catchError((e) => -1),
      ]);
      final result = await tasks;
      await Future.delayed(Duration(milliseconds: 100));
      _cleanup(filePath);
      final max = result.fold(
        0,
        (pre, element) => element > pre ? element : pre,
      );
      if (max <= 0) {
        _source = DownloadSource._allDownloadSource.first;
        Logger.error(
          tag,
          'no available download source, fallback to first one, ${url}',
        );
        return -1;
      }
      _source = DownloadSource._allDownloadSource[result.indexOf(max)];
      Logger.debug(tag, 'selected source: ${_source!.url}');
    }
    return _source!.speed;
  }

  void _cleanup(String filePath) async {
    final dir = File(filePath).parent;
    final candidates = <File>[];
    await dir.list().forEach((file) async {
      if (file.path.contains('.spd_test')) {
        if (file.path.startsWith(filePath)) {
          candidates.add(File(file.path));
        } else {
          await file.delete();
        }
      }
    });
    File? file;
    int size = 0;
    for (final f in candidates) {
      final s = await f.length();
      if (s > size) {
        size = s;
        file = f;
      }
    }
    for (final f in candidates) {
      if (f != file) {
        await f.delete();
      }
    }
    if (file == null) {
      return;
    }
    String path = file.path;
    for (var i = 0; i < DownloadSource._allDownloadSource.length; i++) {
      path = path.replaceAll('.${i}.spd_test', '');
    }
    final target = File(path);
    if (await target.exists()) {
      await file.delete();
      return;
    }
    if (!await file.exists()) {
      return;
    }
    await file.rename(target.path);
  }
}

class _AutoSourceTask extends DownloadTask {
  final _AutoDownloadSource source;
  final DownloadTask task;
  final String resourcePath;

  _AutoSourceTask({
    required this.source,
    required this.task,
    required this.resourcePath,
  });

  @override
  Future start({bool deleteExist = false}) async {
    if (source._source == null) {
      await source.test(resourcePath, filePath);

      /// avoid baned by server by too frequent requests
      await Future.delayed(Duration(seconds: 1));
    }
    final Uri uri = Uri.parse(source.url).replace(path: resourcePath);
    task.url = uri.toString();
    return task.start(deleteExist: deleteExist);
  }

  @override
  Future<void> cancel() => task.cancel();

  @override
  Stream<TaskUpdate> events() => task.events();

  @override
  String get filePath => task.filePath;

  @override
  int getReceivedSize() => task.getReceivedSize();

  @override
  Future<int> getTotalSize() => task.getTotalSize();

  @override
  TaskState get state => task.state;

  @override
  Future<void> stop() => task.stop();

  @override
  TaskUpdate get update => task.update;

  @override
  String get url => task.url;

  @override
  set url(String value) => task.url = value;
}
