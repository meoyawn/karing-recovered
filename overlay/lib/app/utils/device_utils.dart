import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

abstract final class DeviceUtils {
  static Future<bool> disableOrientation() async {
    if (!Platform.isAndroid)
      return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.systemFeatures.contains('android.software.leanback');
  }
}
