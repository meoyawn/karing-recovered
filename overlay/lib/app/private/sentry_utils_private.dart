// The private upstream telemetry configuration is unavailable in this source build.
// Sentry remains uninitialized, so crash reports are not uploaded.
abstract final class SentryUtilsPrivate {
  static Future<void> init() async {}
}
