import 'dart:io';
import 'package:crypto/crypto.dart';

abstract final class CryptoUtils {
  static Future<String> getFileSha256(String path) async =>
      (await sha256.bind(File(path).openRead()).first).toString();
}
