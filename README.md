## HTTP File Downloader

A simple http file downloader for dart

**Usage**

```dart
void example() async {
  final task = await DownloadTask.create(
    url: 'url',
    path: 'path',
  );
  final events = task.start();
  events.listen(
    (event) {
      print('${event.state}, ${event.progress}');
    },
    onError: (e) {
      // handle error
    },
  );
  task.stop();
  // stop and delete file
  task.cancel();
}
```