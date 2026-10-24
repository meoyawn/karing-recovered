import 'dart:io';
import '../lib/proxy_manager.dart';

Future<String> settings(List<String> args) async {
  final result = await Process.run('gsettings', args);
  if (result.exitCode != 0) throw StateError('${result.stderr}');
  return '${result.stdout}'.trim();
}

Future<void> main(List<String> args) async {
  if (!args.contains('--isolated')) {
    final scratch =
        await Directory.systemTemp.createTemp('karing-proxy-smoke-');
    try {
      // Configure the D-Bus daemon's environment too, so dconf's activated
      // service cannot write to the real user's configuration directory.
      final result = await Process.run('dbus-run-session', [
        '--',
        Platform.resolvedExecutable,
        Platform.script.toFilePath(),
        '--isolated',
      ], environment: {
        'XDG_CONFIG_HOME': scratch.path
      });
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      exitCode = result.exitCode;
    } finally {
      await scratch.delete(recursive: true);
    }
    return;
  }
  final previous = {
    'org.gnome.system.proxy mode': "'manual'",
    'org.gnome.system.proxy.http host': "'previous.proxy.test'",
    'org.gnome.system.proxy.http port': '8080',
    'org.gnome.system.proxy ignore-hosts': "['localhost', 'previous.local']",
  };
  for (final entry in previous.entries) {
    final key = entry.key.split(' ');
    await settings(['set', key[0], key[1], entry.value]);
  }
  final proxy = ProxyManager();
  final option =
      ProxyOption('127.0.0.1', 3067, bypassDomains: ['localhost', '*.lan']);
  await proxy.setSystemProxy(option);
  if (!await proxy.getSystemProxyEnable(option))
    throw StateError('Proxy was not enabled');
  for (final protocol in ['http', 'https', 'ftp', 'socks']) {
    if (await settings(['get', 'org.gnome.system.proxy.$protocol', 'port']) !=
        '3067') {
      throw StateError('Proxy port mismatch for $protocol');
    }
  }
  await proxy.cleanSystemProxy();
  for (final entry in previous.entries) {
    final key = entry.key.split(' ');
    if (await settings(['get', key[0], key[1]]) != entry.value)
      throw StateError('Previous setting was not restored: ${entry.key}');
  }
  print(
      'PASS: actual GNOME proxy enable/readback and previous configuration restoration in isolated D-Bus session');
}
