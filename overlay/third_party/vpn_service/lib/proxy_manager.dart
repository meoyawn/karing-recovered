import 'dart:io';

// Public spelling retained for compatibility with Karing's settings files.
const Set<String> ProxyBypassDoaminsDefault = {
  'localhost',
  '127.0.0.0/8',
  '::1',
  '10.0.0.0/8',
  '172.16.0.0/12',
  '192.168.0.0/16',
};

class ProxyOption {
  final String host;
  final int port;
  final List<String> bypassDomains;
  ProxyOption(this.host, this.port, {List<String>? bypassDomains})
      : bypassDomains = bypassDomains ?? ProxyBypassDoaminsDefault.toList();
}

/// Linux GNOME proxy support, matching the gsettings/schema evidence in libapp.so.
/// Other desktop environments report an unsupported operation explicitly.
class ProxyManager {
  static final ProxyManager _instance = ProxyManager._();
  factory ProxyManager() => _instance;
  ProxyManager._();
  final Map<String, String> _previous = {};

  void setExcludeDevices(Set<String> devices) {
    if (!Platform.isLinux) {
      throw UnsupportedError(
          'This reconstructed proxy manager supports Linux.');
    }
  }

  Future<String> _settings(List<String> args) async {
    if (!Platform.isLinux) {
      throw UnsupportedError(
          'System proxy configuration requires Linux GNOME.');
    }
    final result = await Process.run('gsettings', args);
    if (result.exitCode != 0) {
      throw ProcessException(
          'gsettings', args, '${result.stderr}', result.exitCode);
    }
    return '${result.stdout}'.trim();
  }

  Future<void> _set(String schema, String key, String value) async {
    final identity = '$schema $key';
    _previous[identity] ??= await _settings(['get', schema, key]);
    await _settings(['set', schema, key, value]);
  }

  Future<void> setSystemProxy(ProxyOption option) async {
    try {
      for (final protocol in ['http', 'https', 'ftp', 'socks']) {
        final schema = 'org.gnome.system.proxy.$protocol';
        await _set(schema, 'host', _quote(option.host));
        await _set(schema, 'port', '${option.port}');
      }
      await _set('org.gnome.system.proxy', 'ignore-hosts',
          '[${option.bypassDomains.map(_quote).join(', ')}]');
      await _set('org.gnome.system.proxy', 'mode', "'manual'");
    } catch (_) {
      await cleanSystemProxy();
      rethrow;
    }
  }

  Future<void> cleanSystemProxy() async {
    // Restore the user's pre-existing proxy instead of erasing their settings.
    for (final entry in _previous.entries.toList().reversed) {
      final key = entry.key.split(' ');
      await _settings(['set', key[0], key[1], entry.value]);
      _previous.remove(entry.key);
    }
  }

  Future<bool> getSystemProxyEnable(ProxyOption option) async {
    try {
      final mode = await _settings(['get', 'org.gnome.system.proxy', 'mode']);
      final host =
          await _settings(['get', 'org.gnome.system.proxy.http', 'host']);
      final port =
          await _settings(['get', 'org.gnome.system.proxy.http', 'port']);
      return mode == "'manual'" &&
          host == _quote(option.host) &&
          port == '${option.port}';
    } on ProcessException {
      return false;
    }
  }

  static String _quote(String value) =>
      "'${value.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'";
}
