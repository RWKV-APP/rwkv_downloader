import 'dart:io';

class Logger {
  static void info(String tag, String msg) {
    stdout.writeln('INFO/$tag: $msg');
  }

  static void debug(String tag, String msg) {
    stdout.writeln('DEBUG/$tag: $msg');
  }

  static void error(String tag, String msg) {
    stdout.writeln('ERROR/$tag: $msg');
  }
}
