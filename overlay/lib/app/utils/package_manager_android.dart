import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:android_package_manager/android_package_manager.dart';
import 'package:android_package_manager/src/entities/enums.dart'
    show AndroidInstallLocation;

class PackageInfoImpl extends PackageInfo {
  PackageInfoImpl(String name)
    : super(
        packageName: name,
        installLocation: AndroidInstallLocation.unspecified,
      );
}

class PackageInfoEx {
  PackageInfo info = PackageInfoImpl('');
  String name = '';
  Image? icon;
}

abstract final class PackageManagerAndroid {
  static const kAndroidFlagSystem = 1;
  static const kRemoved = '(removed)';
  static Future<List<PackageInfoEx>> getInstalledPackages({
    bool Function(PackageInfo)? onValid,
  }) async {
    if (!Platform.isAndroid) return [];
    final pm = AndroidPackageManager();
    final packages = await pm.getInstalledPackages() ?? [];
    final results = <PackageInfoEx>[];
    for (final info in packages) {
      if (info.packageName == null || (onValid != null && !onValid(info)))
        continue;
      final app = PackageInfoEx()..info = info;
      app.name =
          await pm.getApplicationLabel(packageName: info.packageName!) ??
          info.packageName!;
      results.add(app);
    }
    return results;
  }

  static int sortByName(PackageInfoEx a, PackageInfoEx b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  static Future<Image?> getInstalledPackageIcon(
    List<PackageInfoEx> apps,
    String packageName,
  ) async {
    if (!Platform.isAndroid) return null;
    final bytes = await AndroidPackageManager().getApplicationIcon(
      packageName: packageName,
    );
    final icon = bytes == null ? null : Image.memory(bytes);
    for (final app in apps) {
      if (app.info.packageName == packageName) app.icon = icon;
    }
    return icon;
  }
}
