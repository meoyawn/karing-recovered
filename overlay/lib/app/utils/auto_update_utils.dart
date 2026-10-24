// ignore_for_file: empty_catches, no_leading_underscores_for_local_identifiers

import 'dart:convert';
import 'dart:io';

import 'package:karing/app/local_services/vpn_service.dart';
import 'package:karing/app/modules/remote_config.dart';
import 'package:karing/app/modules/remote_config_manager.dart';
import 'package:karing/app/modules/remote_isp_config.dart';
import 'package:karing/app/modules/setting_manager.dart';
import 'package:karing/app/runtime/return_result.dart';
import 'package:karing/app/utils/app_utils.dart';
import 'package:karing/app/utils/http_utils.dart';
import 'package:karing/app/utils/install_referrer_utils.dart';
import 'package:karing/app/utils/log.dart';
import 'package:karing/app/utils/url_launcher_utils.dart';

class AutoupdateItem {
  String platform = "";

  List<String> channels = [];

  List<String> abis = [];
  String version = "";
  String url = "";
  String fileName = "";
  String sha256 = "";
  List<String> updateChannel = []; //stable, beta
  bool force = false;
  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }
    platform = map["platform"] ?? "";

    var _channels = map["channels"] ?? [];
    for (var i in _channels) {
      channels.add(i as String);
    }

    var _abis = map["abis"] ?? [];
    for (var i in _abis) {
      abis.add(i as String);
    }
    version = map["version"] ?? "";
    url = map["url"] ?? "";
    fileName = map["file_name"] ?? "";
    sha256 = map["sha256"] ?? "";
    updateChannel = List<String>.from(
      map["version_channel"] ?? map["update_channel"] ?? [],
    );
    force = map["force"] ?? false;
  }
}

abstract final class AutoupdateUtils {
  static Future<ReturnResult<List<AutoupdateItem>>> getAutoupdate(
    bool body,
    bool updateWhenConnected,
  ) async {
    String url = RemoteConfigManager.getConfig().autoUpdate;
    late ReturnResult<String> response;
    List<int?> ports = await VPNService.getPortsByPrefer(false);
    for (var port in ports) {
      response = await HttpUtils.httpGetRequestLegacy(
        url,
        port,
        null,
        const Duration(seconds: 10),
        null,
        null,
      );
      if (response.error == null) {
        break;
      }
    }
    List<AutoupdateItem> items = [];
    if (response.error != null) {
      return ReturnResult(error: response.error);
    }
    try {
      if (response.data!.isNotEmpty) {
        var decodedResponse = jsonDecode(response.data!);
        if (decodedResponse is List) {
          for (var i in decodedResponse) {
            AutoupdateItem item = AutoupdateItem();
            item.fromJson(i);
            if (item.platform == Platform.operatingSystem) {
              items.add(item);
            }
          }
        }
      }
    } catch (err, _) {
      Log.i('KaringUtils getAutoupdate exception ${err.toString()}');
    }
    return ReturnResult(data: items);
  }

  static Future<ReturnResult<RemoteConfig>> getRemoteConfig(
    bool updateWhenConnected,
  ) async {
    RemoteConfig rc = RemoteConfig();
    String url = RemoteConfigManager.getConfig().config;
    late ReturnResult<String> response;
    List<int?> ports = await VPNService.getPortsByPrefer(false);
    for (var port in ports) {
      response = await HttpUtils.httpGetRequestLegacy(
        url,
        port,
        null,
        const Duration(seconds: 10),
        null,
        null,
      );
      if (response.error == null) {
        break;
      }
    }

    if (response.error != null) {
      return ReturnResult(error: response.error);
    }
    try {
      if (response.data!.isNotEmpty) {
        var decodedResponse = jsonDecode(response.data!);
        rc.fromJson(decodedResponse);
      }
    } catch (err, _) {
      Log.i('KaringUtils getRemoteConfig exception ${err.toString()}');
    }
    return ReturnResult(data: rc);
  }
}
