import 'package:rwkv_downloader/src/download_source.dart';
import 'package:test/test.dart';

void main() {
  //

  test('test_speed_test', () async {
    final speed = await DownloadSource.aiFastHub.test(
      'mollysama/rwkv-mobile-models/resolve/main/gguf/rwkv7-g0a-7.2b-20250829-ctx4096-q4_k_m.gguf',
      'test',
    );
    print('speed: $speed');
  });

  test('test_auto_source', () async {
    final speed = await DownloadSource.auto.test(
      'mollysama/rwkv-mobile-models/resolve/main/gguf/rwkv7-g0a-7.2b-20250829-ctx4096-q4_k_m.gguf',
      'test',
    );
    print('${DownloadSource.auto.url}');
    print('speed: $speed');
  });

  test('test_retry_source', () async {
    final task = await DownloadSource.auto.createDownloadTask(
      'mollysama/rwkv-mobile-models/resolve/main/gguf/rwkv7-g0a-7.2b-20250829-ctx4096-q4_k_m.gguf',
      'test',
    );
    await task.start();
    await for (final event in task.events()) {
      //
    }
  });
}
