import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

class Utils {
  static Future<String> checksum(Hash hash, File file) async {
    final accessFile = await file.open();
    final len = await accessFile.length();
    int chunkSize = 1024 * 1024;

    var output = StreamController<Digest>();
    var input = sha256.startChunkedConversion(output.sink);

    try {
      int offset = 0;
      while (offset < len) {
        int bytesToRead = (offset + chunkSize < len)
            ? chunkSize
            : (len - offset);
        List<int> buffer = await accessFile.read(bytesToRead);

        input.add(buffer);
        offset += bytesToRead;
      }

      input.close();
      return (await output.stream.single).toString();
    } finally {
      await accessFile.close();
    }
  }
}
