// ignore_for_file: unused_catch_stack
import 'dart:io';

import 'package:dio/io.dart';
import 'package:karing/app/runtime/return_result.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

class WebdavClientUtils {
  static const String _prefix = "karing/";
  static Future<ReturnResult<WebdavClient>> connect(
    String? proxyUrl,
    String url,
    String user,
    String password,
  ) async {
    var client = WebdavClient.basicAuth(
      url: url.trim(),
      user: user.trim(),
      pwd: password.trim(),
    );
    if (proxyUrl != null && proxyUrl.isNotEmpty) {
      client.setHttpClientAdapter(
        IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient()
              ..idleTimeout = const Duration(seconds: 3);
            client.findProxy = (Uri uri) =>
                "PROXY ${Uri.parse(proxyUrl).host}:${Uri.parse(proxyUrl).port}";
            return client;
          },
        ),
      );
    }

    client.setHeaders({'accept-charset': 'utf-8'});

    // Set the connection server timeout time in milliseconds.
    client.setConnectTimeout(8000);

    // Set send data timeout time in milliseconds.
    /* _client!.setSendTimeout(8000);

    // Set transfer data time in milliseconds.
    _client!.setReceiveTimeout(8000);*/

    // Test whether the service can connect
    try {
      await client.ping();
    } catch (err, stacktrace) {
      return ReturnResult(error: ReturnResultError(err.toString()));
    }
    try {
      await client.mkdir(_prefix);
    } catch (err, stacktrace) {
      return ReturnResult(error: ReturnResultError(err.toString()));
    }
    return ReturnResult(data: client);
  }

  static Future<ReturnResult<List<String>>> list(WebdavClient client) async {
    try {
      final list = await client.readDir(_prefix);
      final names = <String>[];
      for (final item in list) {
        if (item.isDir) continue;
        names.add(item.name);
      }
      return ReturnResult(data: names);
    } catch (err, stacktrace) {
      return ReturnResult(error: ReturnResultError(err.toString()));
    }
  }

  static Future<ReturnResultError?> upload(
    WebdavClient client, {
    required String relativePath,
    required String localPath,
  }) async {
    try {
      await client.writeFile(localPath, _prefix + relativePath);
    } catch (err, stacktrace) {
      return ReturnResultError(err.toString());
    }
    return null;
  }

  static Future<ReturnResultError?> delete(
    WebdavClient client,
    String relativePath,
  ) async {
    try {
      await client.remove(_prefix + relativePath);
    } catch (err, stacktrace) {
      return ReturnResultError(err.toString());
    }
    return null;
  }

  static Future<ReturnResultError?> download(
    WebdavClient client, {
    required String relativePath,
    required String localPath,
  }) async {
    try {
      await client.readFile(_prefix + relativePath, localPath);
    } catch (err, stacktrace) {
      return ReturnResultError(err.toString());
    }
    return null;
  }
}
