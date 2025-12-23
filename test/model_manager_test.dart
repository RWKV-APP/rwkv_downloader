import 'package:rwkv_downloader/src/download_source.dart';
import 'package:rwkv_downloader/src/model_manager.dart';
import 'package:test/test.dart';

void main() {
  //
  final instance = ModelManager(
    downloadSource: DownloadSource.auto,
    configProviderUrl: 'http://localhost:8081/config/latest',
    modelDownloadDir: 'models',
  );

  //
  test('test_init_model_manager', () async {
    await instance.init();
  });

  //
  test('test_get_model_list', () async {
    await instance.init();
    for (final model in instance.models) {
      print("${model.fileName}");
    }
  });

  //
  test('test_download', () async {
    await instance.init();
    final model = instance.models[3];
    final taskId = await instance.download(model.id);

    () async {
      await Future.delayed(Duration(seconds: 4));
      instance.pauseTask(taskId);
    }();

    final events = instance.downloadUpdateEvents(id: taskId);
    events.listen(
      (e) {
        print('> update: ${e.update.state}');
      },
      onDone: () {
        print('> done');
      },
      onError: (e) {
        print('> $e');
      },
    );
    await events.last;

    print('> test finished');
    await Future.delayed(Duration(seconds: 3));
  }, timeout: Timeout(Duration(minutes: 3)));
}
