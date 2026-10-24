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

class RawNoticeItem {
  String platform = "";
  String channel = "";
  String updateTime = "";
  String expireTime = "";
  String title = "";
  String content = "";
  String url = "";
  String versionRegex = "";
  String regionCode = "";

  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }
    platform = map["platform"] ?? "";
    channel = map["channel"] ?? "";
    updateTime = map["update_time"] ?? "";
    expireTime = map["expire_time"] ?? "";
    title = map["title"] ?? "";
    content = map["content"] ?? "";
    url = map["url"] ?? "";
    versionRegex = map["version_regex"] ?? "";
    regionCode = (map["region_code"] ?? "").toLowerCase();
  }
}

abstract final class NoticeUtils {
  static Future<RawNoticeItem?> parseNotice(String content) async {
    final decoded = jsonDecode(content);
    final entries = decoded is List ? decoded : [decoded];
    final channel = await InstallReferrerUtils.getString();
    final region = SettingManager.getConfig().regionCode.toLowerCase();
    final version = AppUtils.getBuildinVersion();
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      final item = RawNoticeItem()..fromJson(entry);
      bool matches(String value, String expected) =>
          value.isEmpty ||
          value.split(',').contains('*') ||
          value.split(',').contains(expected);
      if (!matches(item.platform, Platform.operatingSystem) ||
          !matches(item.channel, channel) ||
          !matches(item.regionCode, region))
        continue;
      if (!matches(item.versionRegex, version)) {
        try {
          if (!RegExp(item.versionRegex).hasMatch(version)) continue;
        } on FormatException {
          continue;
        }
      }
      final expires = DateTime.tryParse(item.expireTime);
      if (expires != null && expires.isBefore(DateTime.now())) continue;
      return item;
    }
    return null;
  }
}
