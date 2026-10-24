import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

abstract final class AccessibilityUtils {
  static bool _enabled = false;
  static bool getAccessibilityEnabled() => _enabled;
  static void setAccessibilityEnabled(bool enabled) {
    _enabled = enabled;
  }

  static void announce(BuildContext context, String message) {
    if (_enabled && context.mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      );
    }
  }
}
