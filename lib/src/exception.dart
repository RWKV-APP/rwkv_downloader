import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

class DownloadException implements Exception {
  final dynamic raw;
  final String? message;
  final bool retry;

  DownloadException({this.raw, this.message, this.retry = false});

  factory DownloadException.wrap(dynamic raw) {
    if (raw is DownloadException) {
      return raw;
    }
    return DownloadException(
      raw: raw,
      message: _getMessage(raw),
      retry: _shouldRetry(raw),
    );
  }

  static bool _shouldRetry(dynamic e) {
    if (e is DioException) {
      final retry = {
        DioExceptionType.connectionTimeout,
        // DioExceptionType.connectionError,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      }.contains(e.type);
      return retry;
    } else if (e is TimeoutException) {
      return true;
    }
    return false;
  }

  static String? _getMessage(dynamic raw) {
    if (raw is DioException) {
      if (raw.type == DioExceptionType.badResponse && raw.response != null) {
        return '${raw.response?.statusCode} ${raw.response?.statusMessage}';
      }
      if (raw.type == DioExceptionType.connectionError) {
        final error = raw.error;
        if (error is SocketException) {
          final os = "${error.osError?.errorCode} ${error.osError?.message}";
          return "SocketException: ${error.message} ($os)";
        }
      }
      final m = {
        DioExceptionType.connectionTimeout: 'ConnectionTimeout',
        DioExceptionType.sendTimeout: 'SendTimeout',
        DioExceptionType.receiveTimeout: 'ReceiveTimeout',
        DioExceptionType.badCertificate: 'BadCertificate',
        DioExceptionType.cancel: 'UserCancelled',
        DioExceptionType.connectionError: 'ConnectionError',
      }[raw.type];
      if (m != null) {
        return m;
      }
    }
    return null;
  }

  @override
  String toString() {
    if (message != null) {
      return "DownloadException: $message";
    }
    return "DownloadException: $raw";
  }
}
