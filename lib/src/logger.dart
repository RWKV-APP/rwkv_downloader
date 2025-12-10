

class Logger {
  static void info(String tag, String msg) {
    print('INFO/$tag: $msg');
  }

  static void debug(String tag, String msg) {
    print('DEBUG/$tag: $msg');
  }

  static void error(String tag, String msg) {
    print('ERROR/$tag: $msg');
  }
}
