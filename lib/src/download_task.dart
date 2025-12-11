import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:rwkv_downloader/src/exception.dart';
import 'package:rwkv_downloader/src/utils.dart';
import 'package:rxdart/rxdart.dart';

import 'logger.dart';

enum TaskState { idle, running, stopped, completed }

class TaskUpdate {
  final TaskState state;
  final int received;
  final int totalSize;
  final int speed;
  final int timestamp;

  double get remainSeconds =>
      (speed <= 0 || !_validateState) ? -1 : ((totalSize - received) / speed);

  double get speedInMB => speed / 1024 / 1024;

  double get progress => totalSize <= 0
      ? double.nan
      : (!_validateState ? -1 : (received / totalSize * 100));

  bool get _validateState => totalSize >= received;

  bool get requesting => progress.isNaN || progress < 0;

  bool get isStopped => state == TaskState.stopped;

  bool get isCompleted => state == TaskState.completed;

  bool get isIdle => state == TaskState.idle;

  bool get isRunning => state == TaskState.running;

  TaskUpdate({
    required this.speed,
    required this.state,
    required this.received,
    required this.totalSize,
    required this.timestamp,
  });

  factory TaskUpdate.initial() {
    return TaskUpdate(
      speed: 0,
      state: TaskState.idle,
      received: 0,
      totalSize: 0,
      timestamp: 0,
    );
  }

  factory TaskUpdate.fromMap(Map<String, dynamic> json) {
    return TaskUpdate(
      state: TaskState.values[json['state'] as int],
      received: json['received'] as int,
      totalSize: json['totalSize'] as int,
      speed: json['speed'] as int,
      timestamp: json['timestamp'] ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskUpdate &&
          runtimeType == other.runtimeType &&
          speed == other.speed &&
          state == other.state &&
          received == other.received &&
          totalSize == other.totalSize &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      state.hashCode ^
      received.hashCode ^
      totalSize.hashCode ^
      speed.hashCode ^
      timestamp.hashCode;

  TaskUpdate copyWith({
    TaskState? state,
    int? received,
    int? totalSize,
    int? speed,
  }) {
    return TaskUpdate(
      state: state ?? this.state,
      speed: speed ?? this.speed,
      received: received ?? this.received,
      totalSize: totalSize ?? this.totalSize,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() => {
    'state': state.index,
    'received': received,
    'totalSize': totalSize,
    'speed': speed,
    'timestamp': timestamp,
  };

  @override
  String toString() {
    return 'TaskUpdate{state: $state, received: $received, totalSize: $totalSize, speed: $speed}';
  }
}

class DownloadConfig {
  static Dio _dio = Dio();

  static void setProxy(String proxy) {
    _dio = Dio();
    final adapter = (_dio.httpClientAdapter as IOHttpClientAdapter);
    adapter
      ..createHttpClient = () {
        final client = HttpClient();
        client.findProxy = (uri) {
          if (proxy.isNotEmpty) {
            return 'PROXY $proxy;DIRECT';
          }
          return 'DIRECT';
        };
        return client;
      };
  }
}

abstract class DownloadTask {
  /// The default file verifier, check file hash.
  static Future<bool> defaultFileVerifier(DownloadTask task, File file) async {
    final hash = task.md5 == null ? crypto.sha256 : crypto.md5;
    final expect = task.md5 == null ? task.sha256 : task.md5;
    if (expect == null || expect.isEmpty) {
      return true;
    }
    final sum = await Utils.checksum(hash, file);
    if (expect != sum) {
      throw Exception('file hash check failed, expect: $expect, actual: $sum');
    }
    return true;
  }

  static bool isCanceledManual(dynamic e) {
    final manualCancel = e is DioException && e.type == DioExceptionType.cancel;
    return manualCancel;
  }

  Stream<TaskUpdate> events();

  Future start({bool deleteExist = false});

  Future<void> cancel();

  Future<void> stop();

  int getReceivedSize();

  Future<int> getTotalSize();

  String get filePath;

  TaskState get state;

  TaskUpdate get update;

  abstract String url;

  String? md5;

  String? sha256;

  int maxRetry = 3;

  FileVerifier verifier = defaultFileVerifier;

  static Future<DownloadTask> create({
    required String url,
    required String path,
    String? md5,
    String? sha256,
    Map<String, String> header = const {},
    FileVerifier verifier = defaultFileVerifier,
    bool initTotalSize = false,
    bool initTotalSizeOnlyExist = true,
    @Deprecated('removed') int? acceptedSize,
  }) async {
    final task = _DownloadTask(
      url: url,
      path: path,
      header: header,
      md5: md5,
      sha256: sha256,
      verifier: verifier,
    );
    await task._init(
      initTotalSize: initTotalSize,
      initTotalSizeOnlyExist: initTotalSizeOnlyExist,
    );
    Logger.debug(
      'DownloadTask',
      'task init: ${task._path}, ${task._update.toString()}',
    );
    return task;
  }
}

typedef FileVerifier = Future<bool> Function(DownloadTask task, File file);

class _DownloadTask extends DownloadTask {
  static const tag = 'DownloadTask';
  static const tempFileSuffix = ".tmp";

  StreamController<int> _speedSampler = StreamController();

  final String _path;
  Map<String, String> _header;

  String? _md5;
  String? _sha256;

  String? _filename;
  StreamSubscription? _byteReceiveSubscription;
  RandomAccessFile? _tempRaf;

  bool _supportRange = true;
  CancelToken? _cancelToken;
  late File _tmpFile;

  /// Reset when receive data from server
  int _retryCount = 0;

  @override
  FileVerifier verifier;

  @override
  TaskUpdate get update => _update;

  @override
  String? get md5 => this._md5;

  @override
  String? get sha256 => this._sha256;

  TaskUpdate _update = TaskUpdate(
    state: TaskState.idle,
    received: 0,
    totalSize: 0,
    speed: 0,
    timestamp: 0,
  );

  StreamController<TaskUpdate> _eventStreamController =
      StreamController.broadcast();

  _DownloadTask({
    required String url,
    required String path,
    required FileVerifier verifier,
    Map<String, String> header = const {},
    String? md5,
    String? sha256,
  }) : this.url = url,
       this.verifier = verifier,
       _header = header,
       _path = path,
       _md5 = md5,
       _sha256 = sha256;

  void _startSpeedSampler() {
    _speedSampler.close();
    _speedSampler = StreamController();

    /// smooth speed sample, 10 seconds window, sample every second
    _speedSampler.stream
        .bufferTime(Duration(seconds: 1))
        .map((e) => e.fold(0, (p, e) => p + e))
        .scan((List<int> c, int current, int index) {
          if (c.length >= 10) {
            c.removeAt(0);
          }
          return c..add(current);
        }, <int>[])
        .listen((e) {
          final speed = e.fold(0, (p, e) => p + e) / e.length;
          _update = _update.copyWith(speed: speed.toInt());
          _notify();
        });
  }

  Future _init({
    required bool initTotalSize,
    required bool initTotalSizeOnlyExist,
  }) async {
    _tmpFile = File("$_path$tempFileSuffix");

    File downloaded = File(_path);
    int _received = 0;
    int _total = 0;
    TaskState _state = TaskState.idle;
    if (await downloaded.exists()) {
      if (await _tmpFile.exists()) {
        _tmpFile.delete();
      }
      bool verified = true;
      try {
        verified = await verifier(this, downloaded);
      } catch (_) {
        Logger.debug(tag, 'hash check failed: ${_path}');
        verified = false;
      }
      if (verified) {
        _update = _update.copyWith(state: TaskState.completed);
        return;
      } else {
        await downloaded.delete();
      }
    }

    if (await _tmpFile.exists()) {
      _received = await _tmpFile.length();
      if (_received == 0) {
        await _tmpFile.delete();
      }
    }

    final shouldInitTotalSize =
        initTotalSize && (_received > 0 || !initTotalSizeOnlyExist);

    _total = shouldInitTotalSize ? await getTotalSize() : 0;

    // final stopped = _total != 0 && _received != 0;
    final stopped = _received != 0;
    _state = stopped ? TaskState.stopped : TaskState.idle;

    _update = _update.copyWith(
      state: _state,
      received: _received,
      totalSize: _total,
    );
  }

  @override
  String url = '';

  TaskState get state => _update.state;

  @override
  String get filePath => _path;

  String get filename => _filename ?? _path.split('/').last;

  Stream<TaskUpdate> events() {
    if (_eventStreamController.isClosed) {
      _eventStreamController = StreamController.broadcast();
    }
    return _eventStreamController.stream;
  }

  Future<ResponseBody> _requestFileInfo(int rangeStart) async {
    final h = {..._header, 'range': 'bytes=$rangeStart-'};
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final response = await DownloadConfig._dio.get(
      url,
      cancelToken: _cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: h,
      ),
    );

    final data = response.data;
    if (data is! ResponseBody) {
      throw Exception("data is not ResponseBody");
    }
    _filename = response.headers
        .value("content-disposition")
        ?.split(";")
        .last
        .split("=")
        .last;
    final range = response.headers.value("content-range");
    final rangeLength = int.tryParse(range?.split("/").last ?? "") ?? -1;
    final contentLength =
        int.tryParse(response.headers.value('content-length') ?? "") ?? -1;

    _supportRange = false;
    if (rangeLength != -1) {
      _supportRange = true;
      _update = _update.copyWith(totalSize: rangeLength);
    } else if (contentLength != -1) {
      _update = _update.copyWith(totalSize: contentLength);
    } else {
      _update = _update.copyWith(totalSize: -1);
    }
    return data;
  }

  @override
  Future<int> getTotalSize() async {
    if (_update.totalSize == 0) {
      await _requestFileInfo(0);
    }
    return _update.totalSize;
  }

  @override
  int getReceivedSize() {
    return _update.received;
  }

  @override
  Future cancel() async {
    _cancelToken?.cancel();
    _cancelToken = null;

    _update = _update.copyWith(state: TaskState.idle, received: 0);
    _notify();
    _eventStreamController.close();
    _speedSampler.close();

    _byteReceiveSubscription?.cancel();
    _closeRafFile();
    _cleanTempFile();
  }

  @override
  Future stop() async {
    _update = _update.copyWith(state: TaskState.stopped);
    _notify();

    _cancelToken?.cancel();
    _cancelToken = null;
    _eventStreamController.close();
    _speedSampler.close();
    _byteReceiveSubscription?.cancel();
    _closeRafFile();
  }

  @override
  Future start({bool deleteExist = false}) async {
    if (_update.state == TaskState.running) {
      throw DownloadException(message: "task already started");
    }
    if (_update.state == TaskState.completed && !deleteExist) {
      throw DownloadException(message: 'file already downloaded');
    }
    try {
      _update = _update.copyWith(
        state: TaskState.running,
        speed: -1,
        totalSize: 0,
      );
      _notify();
      await _startInternal(deleteExist);
    } catch (e) {
      await stop();
      throw DownloadException.wrap(e);
    }
  }

  @override
  String toString() {
    return '_HttpDownloadTaskImpl{'
        'url: $url, '
        '_path: $_path, '
        '_md5: $_md5, '
        '_filename: $_filename, '
        '_sha256: $_sha256, '
        '_update: $_update}';
  }

  Future _startInternal(bool deleteExist) async {
    if (await File(_path).exists()) {
      if (deleteExist) {
        Logger.info(tag, 'delete exist file: $_path');
        await File(_path).delete();
      } else {
        throw Exception("file already exists");
      }
    }
    _tmpFile = File("$_path$tempFileSuffix");
    final tmpExists = await _tmpFile.exists();
    _update = _update.copyWith(
      received: tmpExists ? await _tmpFile.length() : 0,
    );
    try {
      await getTotalSize();
      if (!_supportRange && _update.received > 0) {
        if (tmpExists) {
          await _tmpFile.delete();
          await _tmpFile.create();
        }
      }
    } on DioException catch (e) {
      // HTTP 416 - Range Not Satisfiable
      if (e.response?.statusCode == 416) {
        Logger.info(tag, 'all data received');
        _update = _update.copyWith(totalSize: _update.received);
      } else {
        rethrow;
      }
    } catch (e) {
      rethrow;
    }

    if (_supportRange) {
      if (_update.received == _update.totalSize) {
        try {
          await _checkAndRenameTmp();
          _complete();
          return;
        } catch (e) {
          Logger.debug(tag, 'check tmp file failed:\n${e.toString()}');
          rethrow;
          // TODO retry ?
          // return _startInternal(deleteExist);
        }
      } else if (_update.received > _update.totalSize) {
        Logger.error(
          tag,
          "temp file is invalid, temp: ${_update.received}, total: ${_update.totalSize}",
        );
        if (await _tmpFile.exists()) {
          await _tmpFile.delete();
        }
        return _startInternal(deleteExist);
      }
    }

    _startSpeedSampler();
    if (!await _tmpFile.exists()) {
      await _tmpFile.create(recursive: true);
    }
    _tempRaf = await _tmpFile.open(mode: FileMode.writeOnlyAppend);
    final data = await _requestFileInfo(_update.received);
    _byteReceiveSubscription = data.stream
        .timeout(Duration(seconds: 1))
        .listen(
          (List<int> chunk) async {
            _receiveChunk(chunk);
            _retryCount = 0;
          },
          onDone: () async {
            Logger.info(tag, 'download completed');
            _speedSampler.close();
            await _closeRafFile();
            try {
              await _checkAndRenameTmp();
            } catch (e) {
              _error(e);
            }
            _complete();
          },
          onError: (e) async {
            final ep = DownloadException.wrap(e);
            if (ep.retry) {
              _retry(ep);
            } else {
              _speedSampler.close();
              _error(ep);
              _closeRafFile();
            }
          },
          cancelOnError: true,
        );
    Logger.info(
      tag,
      'start download ${_update.received}/${_update.totalSize}, $url',
    );
  }

  void _retry(dynamic e) async {
    _retryCount++;
    if (_retryCount > maxRetry) {
      _error(e);
      return;
    }
    Logger.error(tag, 'retry $_retryCount/$maxRetry, due to: $e');
    try {
      await _startInternal(false);
    } catch (e) {
      _error(e);
    }
  }

  void _receiveChunk(List<int> chunk) {
    if (_update.state == TaskState.stopped) {
      return;
    }
    if (_tempRaf != null && !_eventStreamClosed) {
      if (chunk.length > 0) {
        _tempRaf?.writeFromSync(chunk);
      }
      _update = _update.copyWith(
        state: TaskState.running,
        received: _update.received + chunk.length,
      );
      if (!_speedSampler.isClosed) {
        _speedSampler.add(chunk.length);
      }
    }
  }

  Future _checkAndRenameTmp() async {
    try {
      final verified = await verifier(this, _tmpFile);
      if (!verified) {
        throw Exception('file verification failed');
      }
    } catch (_) {
      await _tmpFile.delete();
      rethrow;
    }
    final newPath = _tmpFile.path.substring(
      0,
      _tmpFile.path.length - tempFileSuffix.length,
    );
    await _tmpFile.rename(newPath);
  }

  Future _closeRafFile() async {
    _tempRaf?.close();
    _tempRaf = null;
  }

  Future _cleanTempFile() async {
    if (await _tmpFile.exists()) {
      await _tmpFile.delete();
    }
  }

  void _complete() async {
    _update = _update.copyWith(
      state: TaskState.completed,
      received: _update.totalSize,
    );
    if (_eventStreamClosed) {
      return;
    }
    _notify();
    _eventStreamController.close();
    Logger.info(tag, 'download complete');

    if (await _tmpFile.exists()) {
      await _tmpFile.delete();
    }
  }

  void _error(e) async {
    if (_eventStreamClosed) {
      return;
    }
    _update = _update.copyWith(state: TaskState.stopped);
    _notify();
    _eventStreamController.addError(
      e is DownloadException ? e : DownloadException.wrap(e),
    );
    _eventStreamController.close();
  }

  void _notify() {
    if (_eventStreamClosed) {
      return;
    }
    _eventStreamController.add(_update);
  }

  bool get _eventStreamClosed => _eventStreamController.isClosed;
}
