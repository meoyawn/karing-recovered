// ignore_for_file: empty_catches, no_leading_underscores_for_local_identifiers

import 'dart:convert';
import 'dart:io';

import 'package:karing/app/local_services/vpn_service.dart';
import 'package:karing/app/modules/remote_config.dart';
import 'package:karing/app/modules/remote_config_manager.dart';
import 'package:karing/app/modules/setting_manager.dart';
import 'package:karing/app/runtime/return_result.dart';
import 'package:karing/app/utils/app_utils.dart';
import 'package:karing/app/utils/http_utils.dart';
import 'package:karing/app/utils/install_referrer_utils.dart';
import 'package:karing/app/utils/log.dart';
import 'package:karing/app/utils/url_launcher_utils.dart';

import 'package:karing/app/utils/notice_utils.dart';
import 'package:karing/app/utils/auto_update_utils.dart';

abstract final class KaringUtils {
  static Future<ReturnResult<List<AutoupdateItem>>> getAutoupdate() async {
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

  static Future<ReturnResult<RemoteConfig>> getRemoteConfig() async {
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

  static Future<ReturnResult<RawNoticeItem>> getNotice(
    String url, [
    bool updateWhenConnected = false,
  ]) async {
    if (url.isEmpty) {
      return ReturnResult(error: ReturnResultError("url is empty"));
    }
    var settingConfig = SettingManager.getConfig();

    String regionCode = settingConfig.regionCode.toLowerCase();

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
    String version = AppUtils.getBuildinVersion();
    try {
      if (response.data!.isNotEmpty) {
        var decodedResponse = jsonDecode(response.data!);
        if (decodedResponse is List) {
          String channelName = await InstallReferrerUtils.getString();
          for (var i in decodedResponse) {
            RawNoticeItem item = RawNoticeItem();
            item.fromJson(i);
            if (item.platform == Platform.operatingSystem) {
              List channels = item.channel.split(",");
              if (channels.contains("*") || channels.contains(channelName)) {
                List regionCodes = item.regionCode.split(",");
                if (item.regionCode.isEmpty ||
                    regionCodes.contains("*") ||
                    regionCodes.contains(regionCode)) {
                  List versions = item.versionRegex.split(",");
                  if (item.versionRegex.isEmpty ||
                      versions.contains("*") ||
                      versions.contains(version)) {
                    if (item.expireTime.isNotEmpty) {
                      DateTime? date = DateTime.tryParse(item.expireTime);
                      if (date != null && date.isBefore(DateTime.now())) {
                        return ReturnResult(data: item);
                      }
                    } else {
                      return ReturnResult(data: item);
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (err, _) {
      Log.i('KaringUtils getNotice exception ${err.toString()}');
    }
    return ReturnResult(error: ReturnResultError("not found"));
  }
}
