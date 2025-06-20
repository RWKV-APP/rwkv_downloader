import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

enum TaskState { idle, running, stopped, completed }

class TaskUpdate {
  final TaskState state;
  final int received;
  final int totalSize;
  final int speed;

  double get remainSeconds =>
      (speed <= 0 || !_validateState) ? -1 : ((totalSize - received) / speed);

  double get speedInMB => speed / 1024 / 1024;

  double get progress => !_validateState ? -1 : (received / totalSize * 100);

  bool get _validateState => totalSize >= received;

  TaskUpdate({
    required this.speed,
    required this.state,
    required this.received,
    required this.totalSize,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskUpdate &&
          runtimeType == other.runtimeType &&
          speed == other.speed &&
          state == other.state &&
          received == other.received &&
          totalSize == other.totalSize;

  @override
  int get hashCode =>
      state.hashCode ^ received.hashCode ^ totalSize.hashCode ^ speed.hashCode;

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
    );
  }

  @override
  String toString() {
    return 'TaskUpdate{state: $state, received: $received, totalSize: $totalSize, speed: $speed}';
  }
}

abstract class DownloadTask {
  Stream<TaskUpdate> events();

  Future start();

  Future<void> cancel();

  Future<void> stop();

  int getReceivedSize();

  Future<int> getTotalSize();

  String get filePath;

  TaskState get state;

  static Future<DownloadTask> create({
    required String url,
    required String path,
    Map<String, String> header = const {},
    bool initTotalSize = false,
    bool initTotalSizeOnlyExist = true,
    int? acceptedSize,
  }) async {
    final task = _DownloadTask(url: url, path: path, header: header);
    await task._init(
      initTotalSize: initTotalSize,
      initTotalSizeOnlyExist: initTotalSizeOnlyExist,
      acceptedSize: acceptedSize,
    );
    return task;
  }
}

class _DownloadTask extends DownloadTask {
  static const tempFileSuffix = ".tmp";

  final String _url;
  final String _path;
  Map<String, String> _header;

  String? _md5;

  String? _filename;
  StreamSubscription? _byteReceiveSubscription;
  RandomAccessFile? _tempRaf;
  bool _supportRange = true;

  TaskUpdate _update = TaskUpdate(
    state: TaskState.idle,
    received: 0,
    totalSize: 0,
    speed: 0,
  );

  StreamController<TaskUpdate> _eventStreamController = StreamController();

  _DownloadTask({
    required String url,
    required String path,
    Map<String, String> header = const {},
  }) : _header = header,
       _path = path,
       _url = url;

  Future _init({
    required bool initTotalSize,
    required bool initTotalSizeOnlyExist,
    required int? acceptedSize,
  }) async {
    File downloaded = File(_path);
    int _received = 0;
    int _total = 0;
    TaskState _state = TaskState.idle;
    if (downloaded.existsSync()) {
      bool verified = true;
      if (acceptedSize != null) {
        verified = acceptedSize == await downloaded.length();
      }
      if (verified) {
        _update = _update.copyWith(state: TaskState.completed);
        return;
      } else {
        await downloaded.delete();
      }
    }

    File tmpFile = File("$_path$tempFileSuffix");
    if (await tmpFile.exists()) {
      _received = tmpFile.lengthSync();
      if (_received == 0) {
        await tmpFile.delete();
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

  void setFileMd5(String md5) {
    _md5 = md5;
  }

  TaskState get state => _update.state;

  @override
  String get filePath => _path;

  String get filename => _filename ?? _path.split('/').last;

  Stream<TaskUpdate> events() {
    if (_eventStreamClosed) {
      _eventStreamController = StreamController();
    }
    return _eventStreamController.stream;
  }

  Future<File> getTempFile() async {
    File tmpFile = File("$_path$tempFileSuffix");
    if (!await tmpFile.exists()) {
      await tmpFile.create(recursive: true);
    }
    return tmpFile;
  }

  Future<ResponseBody> _requestFileInfo(int rangeStart) async {
    final h = {..._header, 'range': 'bytes=$rangeStart-'};
    final response = await Dio().get(
      _url,
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
      throw Exception("get file length failed: $rangeLength, range: $range");
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
    final tmpPath = _tempRaf?.path;

    _byteReceiveSubscription?.cancel();
    _closeFile();

    _update = _update.copyWith(state: TaskState.idle, received: 0);
    _notify();

    if (tmpPath != null) {
      if (File(tmpPath).existsSync()) {
        await File(tmpPath).delete();
      }
    }
    _eventStreamController.close();
  }

  @override
  Future stop() async {
    _update = _update.copyWith(state: TaskState.stopped);
    _notify();
    _closeFile();
    _eventStreamController.close();
    _byteReceiveSubscription?.cancel();
  }

  @override
  Future start({bool deleteExist = false}) async {
    if (_update.state == TaskState.running) {
      throw Exception("task is running");
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
      rethrow;
    }
  }

  @override
  String toString() {
    return '_HttpDownloadTaskImpl{'
        '_url: $_url, '
        '_path: $_path, '
        '_md5: $_md5, '
        '_update: $_update}';
  }

  Future _startInternal(bool deleteExist) async {
    if (await File(_path).exists()) {
      if (deleteExist) {
        await File(_path).delete();
      } else {
        throw Exception("file already exists");
      }
    }

    File tmpFile = await getTempFile();
    final received = await tmpFile.length();
    _update = _update.copyWith(received: received);
    ResponseBody data;
    try {
      data = await _requestFileInfo(_update.received);
      if (!_supportRange && _update.received > 0) {
        await tmpFile.delete();
        await tmpFile.create();
        _update = _update.copyWith(received: 0);
      }
    } catch (e) {
      rethrow;
    }
    final rcv = await _checkTempFile(tmpFile, _update.totalSize);
    _update = _update.copyWith(received: rcv);
    if (received == _update.totalSize) {
      _complete();
      return;
    }
    _tempRaf = await tmpFile.open(mode: FileMode.append);

    int timestamp = DateTime.now().millisecondsSinceEpoch;
    int chunkSize = 0;
    List<int> speedSamples = [];
    // receiving
    _byteReceiveSubscription = data.stream.listen(
      (List<int> chunk) async {
        if (_update.state == TaskState.stopped) {
          return;
        }
        if (_tempRaf != null && !_eventStreamClosed) {
          _tempRaf?.writeFromSync(chunk);

          /// calculate speed
          chunkSize += chunk.length;
          final ts = DateTime.now().millisecondsSinceEpoch;
          final span = ts - timestamp;
          int? speed = null;
          if (span >= 1000) {
            speed = (chunkSize / (span / 1000)).round();
            speedSamples.add(speed);
            chunkSize = 0;
            timestamp = ts;
            if (speedSamples.length >= 10) {
              speed =
                  (speedSamples.reduce((a, b) => a + b) / speedSamples.length)
                      .toInt();
              if (speedSamples.length > 10) {
                speedSamples.removeAt(0);
              }
            }
          }
          _update = _update.copyWith(
            speed: speed,
            state: TaskState.running,
            received: _update.received + chunk.length,
          );
          _notify();
        }
      },
      onDone: () async {
        await _closeFile();
        try {
          await _checkAndRename(tmpFile);
        } catch (e) {
          _error(e);
        }
        _complete();
      },
      onError: (e) async {
        _error(e);
        _closeFile();
      },
      cancelOnError: true,
    );
  }

  Future<int> _checkTempFile(File tmpFile, int total) async {
    int received = await tmpFile.length();
    if (total == received) {
      await _checkAndRename(tmpFile);
      return received;
    } else if (received > total) {
      stderr.writeln("temp file is invalid, temp: $received, total: $total");
      await tmpFile.delete();
      tmpFile = await getTempFile();
      received = 0;
    }
    if (received != 0) {
      // stdout.writeln("resume download from $received, total: $total");
    }
    return received;
  }

  Future _checkAndRename(File tmpFile) async {
    if (_md5 != null) {
      final sum = (await md5.bind(tmpFile.openRead()).first).toString();
      if (_md5 != sum) {
        throw Exception("file md5 check failed, expect: $_md5, actual: $sum");
      }
    }
    final name = tmpFile.path.substring(0, tmpFile.path.length - 4);
    await tmpFile.rename(name);
  }

  Future _closeFile() async {
    _tempRaf?.close();
    _tempRaf = null;
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
  }

  void _error(e) async {
    if (_eventStreamClosed) {
      return;
    }
    _update = _update.copyWith(state: TaskState.stopped);
    _notify();
    _eventStreamController.addError(e);
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
