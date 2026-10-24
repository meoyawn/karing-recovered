import 'dart:convert';
import 'dart:io';
import '../lib/vpn_service.dart';
import '../lib/state.dart';

Future<int> availablePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
        'Usage: dart service_smoke.dart /absolute/path/to/karingService');
    exitCode = 64;
    return;
  }
  final executable = File(args.first).absolute.path;
  final scratch = await Directory.systemTemp.createTemp('karing-vpn-smoke-');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.write('karing-linux-proxy-ok');
    await request.response.close();
  });
  final proxyPort = await availablePort();
  final clashPort = await availablePort();
  final serviceConfig = VpnServiceConfig()
    ..base_dir = scratch.path
    ..work_dir = scratch.path
    ..cache_dir = scratch.path
    ..core_path = '${scratch.path}/core.json'
    ..err_path = '${scratch.path}/service_error.log'
    ..name = 'Karing reconstruction smoke'
    ..version = '1.2.25.2802'
    ..secret = 'local-smoke'
    ..control_port = clashPort;
  final configFile = File('${scratch.path}/service.json');
  await configFile.writeAsString(jsonEncode(serviceConfig));
  await File(serviceConfig.core_path).writeAsString(jsonEncode({
    'log': {'level': 'error'},
    'inbounds': [
      {'type': 'mixed', 'listen': '127.0.0.1', 'listen_port': proxyPort}
    ],
    'outbounds': [
      {'type': 'direct', 'tag': 'direct'}
    ],
    'route': {'final': 'direct'},
    'experimental': {
      'clash_api': {
        'external_controller': '127.0.0.1:$clashPort',
        'secret': 'local-smoke'
      }
    },
  }));
  final states = <FlutterVpnServiceState>[];
  FlutterVpnService.onStateChanged((state, params) => states.add(state));
  FlutterVpnService.prepareConfig(
      config: serviceConfig,
      tunnelServicePath: executable,
      configFilePath: configFile.path);
  try {
    final result = await FlutterVpnService.start(const Duration(seconds: 20));
    if (result.type != VpnServiceWaitType.done)
      throw StateError('Start failed: ${result.type} ${result.err}');
    if (await FlutterVpnService.currentState !=
        FlutterVpnServiceState.connected)
      throw StateError('Connection state mismatch');
    final http = HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:$proxyPort';
    try {
      final request =
          await http.getUrl(Uri.parse('http://127.0.0.1:${server.port}/smoke'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (body != 'karing-linux-proxy-ok')
        throw StateError('Proxy response mismatch: $body');
    } finally {
      http.close(force: true);
    }
    final connections =
        jsonDecode(await FlutterVpnService.clashiApiConnections(false));
    if (connections is! Map || !connections.containsKey('downloadTotal'))
      throw StateError('Invalid traffic response: $connections');
    final reload = await FlutterVpnService.restart(const Duration(seconds: 20));
    if (reload.type != VpnServiceWaitType.done)
      throw StateError('Reload failed: ${reload.err}');
    await FlutterVpnService.stop();
    if (await FlutterVpnService.currentState !=
        FlutterVpnServiceState.disconnected)
      throw StateError('Stop state mismatch');
    print(
        'PASS: real service start, HTTP proxy request, traffic API, reload, stop; states=$states');
  } finally {
    await FlutterVpnService.stop();
    await server.close(force: true);
    await scratch.delete(recursive: true);
  }
}
