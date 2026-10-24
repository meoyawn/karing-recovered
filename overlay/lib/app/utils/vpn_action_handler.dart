abstract final class VpnActionHandler {
  static Future<void> Function(String from, bool background)? vpnConnect;
  static Future<void> Function(String from, bool background)? vpnDisconnect;
  static Future<void> Function(String from, bool background)? vpnReconnect;
}
