import 'dart:io';
import 'package:move_to_background/move_to_background.dart';
import 'package:window_manager/window_manager.dart';

abstract final class MoveToBackgroundUtils {
  static Future<void> moveToBackground({
    Duration duration = Duration.zero,
  }) async {
    if (duration > Duration.zero) await Future<void>.delayed(duration);
    if (Platform.isAndroid) {
      await MoveToBackground.moveTaskToBack();
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      await windowManager.hide();
    }
  }
}
