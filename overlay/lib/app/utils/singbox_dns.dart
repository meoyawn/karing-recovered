import 'package:karing/app/runtime/return_result.dart';

class SingboxDNSDomainResolver {
  String server;
  String? strategy;
  SingboxDNSDomainResolver({required this.server, this.strategy});
  Map<String, dynamic> toJson() => {
    'server': server,
    if (strategy != null && strategy!.isNotEmpty) 'strategy': strategy,
  };
}

class SingboxDNSServer {
  String tag;
  final Map<String, dynamic> options;
  SingboxDNSServer(this.tag, this.options);
  Map<String, dynamic> toJson() => {'tag': tag, ...options};
}

class SingboxDNSServerBatchOptions extends SingboxDNSServer {
  SingboxDNSServerBatchOptions(String tag, {required List<String> servers})
    : super(tag, {'type': 'batch', 'servers': servers});
}

ReturnResult<List<SingboxDNSServer>> SingboxDNSTryParseList(
  List<String> urls,
  String? detour,
  SingboxDNSDomainResolver? resolver,
) {
  final servers = <SingboxDNSServer>[];
  try {
    for (final address in urls.toSet()) {
      if (address.isEmpty) continue;
      if (address == 'local' || address == 'system') {
        servers.add(SingboxDNSServer(address, {'type': 'local'}));
        continue;
      }
      final uri = Uri.parse(
        address.contains('://') ? address : 'udp://$address',
      );
      if (uri.host.isEmpty)
        throw FormatException('Invalid DNS server: $address');
      final type = {
        'https': 'https',
        'h3': 'http3',
        'tls': 'tls',
        'quic': 'quic',
        'tcp': 'tcp',
        'udp': 'udp',
      }[uri.scheme];
      if (type == null)
        throw FormatException('Unsupported DNS transport: ${uri.scheme}');
      servers.add(
        SingboxDNSServer(address, {
          'type': type,
          'server': uri.host,
          if (uri.hasPort) 'server_port': uri.port,
          if ((type == 'https' || type == 'http3') && uri.path.isNotEmpty)
            'path': uri.path,
          if (detour != null && detour.isNotEmpty) 'detour': detour,
          if (resolver != null) 'domain_resolver': resolver.toJson(),
        }),
      );
    }
    return ReturnResult(data: servers);
  } catch (error) {
    return ReturnResult(error: ReturnResultError(error.toString()));
  }
}
