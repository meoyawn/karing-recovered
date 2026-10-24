import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'proxy_manager.dart';
import 'state.dart';
import 'vpn_service_platform_interface.dart';

export 'vpn_service_platform_interface.dart';

/// Linux adapter reconstructed from the release's Dart symbols and the exact
/// Go core revision's cmd_run_extension_karing.go IPC implementation.
class FlutterVpnService {
  static VpnServiceConfig? _config;
  static String _executable = '';
  static String _configPath = '';
  static Process? _process;
  static int _httpPort = 0;
  static FlutterVpnServiceState _state = FlutterVpnServiceState.disconnected;
  static void Function(FlutterVpnServiceState, Map<String, String>)? _callback;

  static void onStateChanged(
      void Function(FlutterVpnServiceState, Map<String, String>) callback) {
    _callback = callback;
  }

  static void _change(FlutterVpnServiceState state,
      [Map<String, String> params = const {}]) {
    _state = state;
    _callback?.call(state, params);
  }

  static Future<FlutterVpnServiceState> get currentState async => _state;

  static void prepareConfig({
    required VpnServiceConfig config,
    required String tunnelServicePath,
    required String configFilePath,
    bool systemExtension = false,
    String bundleIdentifier = '',
    String uiServerAddress = '',
    String uiLocalizedDescription = '',
    List<int> excludePorts = const [],
  }) {
    _config = config;
    _executable = File(tunnelServicePath).absolute.path;
    _configPath = File(configFilePath).absolute.path;
  }

  static Future<VpnServiceWaitResult> start(Duration timeout) async {
    if (!Platform.isLinux) {
      return VpnServiceWaitResult(
          VpnServiceWaitType.error,
          VpnServiceResultError(
              'The reconstructed service adapter supports Linux.'));
    }
    if (_state == FlutterVpnServiceState.connected) {
      return VpnServiceWaitResult(VpnServiceWaitType.done);
    }
    if (_process != null) {
      return VpnServiceWaitResult(
          VpnServiceWaitType.error,
          VpnServiceResultError(
              'Service start or stop is already in progress.'));
    }
    if (_config == null || !await File(_executable).exists()) {
      return VpnServiceWaitResult(
          VpnServiceWaitType.error,
          VpnServiceResultError(
              'VPN service executable is missing: $_executable'));
    }
    _change(FlutterVpnServiceState.connecting);
    ServerSocket? readySocket;
    try {
      // The Go core connects to this socket only after its service has started.
      readySocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final readiness = Completer<void>();
      readySocket.listen((socket) {
        socket.destroy();
        if (!readiness.isCompleted) readiness.complete();
      });
      final controlSocket =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _httpPort = controlSocket.port;
      await controlSocket.close();
      final process = await Process.start(
          _executable,
          [
            'run2',
            '--service-config=$_configPath',
            '--service-http-port=$_httpPort',
            '--connected-port=${readySocket.port}',
            '--disable-color',
          ],
          workingDirectory: _config!.base_dir);
      _process = process;
      final output = StringBuffer();
      process.stdout.transform(utf8.decoder).listen((text) {
        if (output.length < 32768) output.write(text);
      });
      process.stderr.transform(utf8.decoder).listen((text) {
        if (output.length < 32768) output.write(text);
      });
      unawaited(process.exitCode.then((code) {
        if (!identical(_process, process)) return;
        _process = null;
        _httpPort = 0;
        if (!readiness.isCompleted) {
          readiness.completeError(ProcessException(
              _executable,
              [],
              output.isEmpty
                  ? 'Service exited with code $code'
                  : output.toString(),
              code));
        }
        _change(FlutterVpnServiceState.disconnected, {
          'exitCode': '$code',
          if (output.isNotEmpty) 'error': output.toString()
        });
      }));
      await readiness.future.timeout(timeout);
      _change(FlutterVpnServiceState.connected);
      return VpnServiceWaitResult(VpnServiceWaitType.done);
    } on TimeoutException {
      await stop();
      return VpnServiceWaitResult(VpnServiceWaitType.timeout,
          VpnServiceResultError('VPN service startup timed out.'));
    } catch (error) {
      await stop();
      return VpnServiceWaitResult(
          VpnServiceWaitType.error, VpnServiceResultError(error.toString()));
    } finally {
      await readySocket?.close();
    }
  }

  static Future<String> _request(String path,
      {Duration timeout = const Duration(seconds: 5)}) async {
    if (_httpPort == 0) throw StateError('VPN service is not running.');
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:$_httpPort$path'))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      final body =
          await response.transform(utf8.decoder).join().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Service returned ${response.statusCode}: $body');
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  static Future<VpnServiceWaitResult> restart(Duration timeout) async {
    if (_state != FlutterVpnServiceState.connected) return start(timeout);
    _change(FlutterVpnServiceState.reasserting);
    try {
      final result = jsonDecode(await _request('/reload', timeout: timeout));
      if (result['err'] != null) throw StateError('${result['err']}');
      _change(FlutterVpnServiceState.connected);
      return VpnServiceWaitResult(VpnServiceWaitType.done);
    } on TimeoutException {
      await stop();
      return VpnServiceWaitResult(VpnServiceWaitType.timeout,
          VpnServiceResultError('VPN service reload timed out.'));
    } catch (error) {
      await stop();
      return VpnServiceWaitResult(
          VpnServiceWaitType.error, VpnServiceResultError(error.toString()));
    }
  }

  static Future<void> stop() async {
    final process = _process;
    if (process == null) {
      _change(FlutterVpnServiceState.disconnected);
      return;
    }
    _change(FlutterVpnServiceState.disconnecting);
    try {
      await _request('/stop');
      await process.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
      }
    }
    _process = null;
    _httpPort = 0;
    _change(FlutterVpnServiceState.disconnected);
  }

  static Future<String> clashiApiConnections(bool includeConnections) =>
      _request('/clashiApiConnections?includeConnections=$includeConnections');

  static Future<VpnServiceResultError?> installService() async =>
      await File(_executable).exists()
          ? null
          : VpnServiceResultError('Missing service: $_executable');
  static Future<VpnServiceResultError?> uninstallService() async {
    await stop();
    return null; // Linux uses a bundled child process, with no system daemon.
  }

  static Future<bool> isRunAsAdmin() async {
    if (!Platform.isLinux) return false;
    return '${(await Process.run('id', ['-u'])).stdout}'.trim() == '0';
  }

  static Future<bool> isServiceAuthorized(String servicePath) async {
    if (await isRunAsAdmin()) return true;
    try {
      final result = await Process.run(
          '/usr/sbin/getcap', [File(servicePath).absolute.path]);
      final caps = '${result.stdout}';
      if (result.exitCode == 0 &&
          caps.contains('cap_net_admin') &&
          caps.contains('ep')) return true;
      final stat = await Process.run(
          'stat', ['-c', '%u:%a', File(servicePath).absolute.path]);
      final parts = '${stat.stdout}'.trim().split(':');
      return stat.exitCode == 0 &&
          parts.length == 2 &&
          parts[0] == '0' &&
          ((int.tryParse(parts[1], radix: 8) ?? 0) & 0x800) != 0;
    } on ProcessException {
      return false;
    }
  }

  static Future<VpnServiceResultError?> authorizeService(
      String servicePath, String password) async {
    try {
      final target = await File(servicePath).resolveSymbolicLinks();
      // No shell expansion; the password is sent through stdin, never argv.
      final process = await Process.start('sudo', [
        '-S',
        '-p',
        '',
        '--',
        '/usr/sbin/setcap',
        'cap_net_admin,cap_net_raw+ep',
        target,
      ]);
      final output = process.stdout.transform(utf8.decoder).join();
      final error = process.stderr.transform(utf8.decoder).join();
      process.stdin.writeln(password);
      await process.stdin.close();
      final code = await process.exitCode;
      await output;
      final message = await error;
      if (code != 0) return VpnServiceResultError(message.trim());
      return null;
    } catch (error) {
      return VpnServiceResultError(error.toString());
    }
  }

  static Future<String> getABIs() async {
    final result = await Process.run('uname', ['-m']);
    return '${result.stdout}'.trim();
  }

  static Future<String> getSystemVersion() async =>
      Platform.operatingSystemVersion;
  static Future<void> setSystemProxy(ProxyOption option) =>
      ProxyManager().setSystemProxy(option);
  static Future<void> cleanSystemProxy() => ProxyManager().cleanSystemProxy();
  static Future<bool> getSystemProxyEnable(ProxyOption option) =>
      ProxyManager().getSystemProxyEnable(option);

  // These platform features are never called by the Linux UI. Fail explicitly
  // if another platform is enabled instead of pretending that a plugin exists.
  static Future<void> _unsupported(String feature) async =>
      throw UnsupportedError(
          '$feature is unavailable in the reconstructed Linux adapter.');
  static Future<void> setAlwaysOn(bool value) => _unsupported('Always-on VPN');
  static Future<VpnServiceResultError?> setExcludeFromRecents(
          bool value) async =>
      VpnServiceResultError('Exclude from recents is an Android feature.');
  static Future<void> hideDockIcon(bool value) =>
      _unsupported('Dock visibility');
  static Future<String?> getProcessList() async =>
      throw UnsupportedError('macOS application enumeration');
  static Future<Uint8List?> getProcessIcon(String identifier) async =>
      throw UnsupportedError('macOS application icons');
  static Future<Directory?> getAppGroupDirectory(String identifier) async =>
      Platform.isLinux ? null : throw UnsupportedError('Apple app groups');
  static Future<void> firewallAddPorts(List<int> ports, String name) =>
      _unsupported('Windows firewall');
  static Future<void> firewallAddApp(String executable, String name) =>
      _unsupported('Windows firewall');
  static Future<void> autoStartCreate(String name, String executable,
          {String processArgs = '', bool runElevated = false}) =>
      _unsupported('Windows startup task');
  static Future<void> autoStartDelete(String name) async {
    if (Platform.isWindows) await _unsupported('Windows startup task');
  }

  static Future<bool> autoStartIsActive(String name) async =>
      throw UnsupportedError('Windows startup task');
}
