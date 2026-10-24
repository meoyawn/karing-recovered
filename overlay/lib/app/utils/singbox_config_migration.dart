import 'dart:convert';
import 'dart:io';

/// Adapts recovered configuration models to the Go core shipped in 1.2.25.2802.
///
/// The contract is taken from KaringX/sing-box revision 93f6a441a141, whose
/// parser rejects legacy DNS transports, DNS outbounds and inbound sniff fields.
Map<String, dynamic> migrateSingboxConfig(Map<String, dynamic> config) {
  final result = jsonDecode(jsonEncode(config)) as Map<String, dynamic>;
  final route =
      result.putIfAbsent('route', () => <String, dynamic>{})
          as Map<String, dynamic>;
  final routeRules = (route['rules'] as List?) ?? <dynamic>[];
  final initialRules = <Map<String, dynamic>>[];
  var inboundIndex = 0;
  for (final inbound in (result['inbounds'] as List?) ?? <dynamic>[]) {
    final entry = inbound as Map<String, dynamic>;
    final sniff = entry.remove('sniff') == true;
    final timeout = entry.remove('sniff_timeout');
    final strategy = entry.remove('domain_strategy');
    final disableUnmapping = entry.remove('udp_disable_domain_unmapping');
    entry.remove('sniff_override_destination');
    final tag = entry.putIfAbsent('tag', () => 'inbound_$inboundIndex');
    inboundIndex++;
    if (strategy is String && strategy.isNotEmpty && strategy != 'as_is') {
      initialRules.add({
        'inbound': [tag],
        'action': 'resolve',
        'strategy': strategy,
      });
    }
    if (sniff) {
      final rule = <String, dynamic>{
        'inbound': [tag],
        'action': 'sniff',
      };
      if (timeout != null) rule['timeout'] = timeout;
      initialRules.add(rule);
    }
    if (disableUnmapping == true) {
      initialRules.add({
        'inbound': [tag],
        'action': 'route-options',
        'udp_disable_domain_unmapping': true,
      });
    }
  }

  final dnsOutboundTags = <dynamic>{};
  final outbounds = (result['outbounds'] as List?) ?? <dynamic>[];
  outbounds.removeWhere((dynamic outbound) {
    if (outbound['type'] != 'dns') return false;
    dnsOutboundTags.add(outbound['tag']);
    return true;
  });
  void migrateRule(dynamic value) {
    final rule = value as Map<String, dynamic>;
    if (dnsOutboundTags.contains(rule['outbound'])) {
      rule.remove('outbound');
      rule['action'] = 'hijack-dns';
    }
    for (final nested in (rule['rules'] as List?) ?? <dynamic>[]) {
      migrateRule(nested);
    }
  }

  for (final rule in routeRules) {
    migrateRule(rule);
  }
  route['rules'] = [...initialRules, ...routeRules];
  result['outbounds'] = outbounds;

  final dns = result['dns'] as Map<String, dynamic>?;
  if (dns != null) _migrateDns(dns, route);
  return result;
}

void _migrateDns(Map<String, dynamic> dns, Map<String, dynamic> route) {
  final fakeip = dns.remove('fakeip') as Map<String, dynamic>?;
  final servers = <Map<String, dynamic>>[];
  final queryOptions = <String, Map<String, dynamic>>{};
  for (final value in (dns['servers'] as List?) ?? <dynamic>[]) {
    final server = value as Map<String, dynamic>;
    if (server['type'] != null && server['type'] != 'legacy') {
      servers.add(server);
      continue;
    }
    final tag = server['tag'] as String? ?? 'dns_${servers.length}';
    queryOptions[tag] = {
      if (server['strategy'] != null) 'strategy': server['strategy'],
      if (server['client_subnet'] != null)
        'client_subnet': server['client_subnet'],
    };
    final addresses = (server['addresses'] as List?) ?? [server['address']];
    if (addresses.length == 1) {
      servers.add(
        _dnsTransport(server, addresses.single as String, tag, fakeip),
      );
    } else {
      final children = <String>[];
      for (var index = 0; index < addresses.length; index++) {
        final childTag = '${tag}_address_$index';
        children.add(childTag);
        servers.add(
          _dnsTransport(server, addresses[index] as String, childTag, fakeip),
        );
      }
      servers.add({'type': 'batch', 'tag': tag, 'servers': children});
    }
  }

  final rules = (dns['rules'] as List?) ?? <dynamic>[];
  void migrateRule(dynamic value) {
    final rule = value as Map<String, dynamic>;
    final options = queryOptions[rule['server']];
    options?.forEach((key, value) => rule.putIfAbsent(key, () => value));
    for (final nested in (rule['rules'] as List?) ?? <dynamic>[]) {
      migrateRule(nested);
    }
  }

  for (final rule in rules) {
    migrateRule(rule);
  }
  final finalOptions = queryOptions[dns['final']];
  if (finalOptions != null && finalOptions.isNotEmpty) {
    rules.add({'server': dns['final'], ...finalOptions});
  }
  final staticIPs = dns.remove('static_ips') as Map<String, dynamic>?;
  if (staticIPs != null && staticIPs.isNotEmpty) {
    const tag = 'dns_static_ips';
    servers.insert(0, {'type': 'hosts', 'tag': tag, 'predefined': staticIPs});
    rules.insert(0, {'domain': staticIPs.keys.toList(), 'server': tag});
  }
  dns['rules'] = rules;

  // Constructors resolve bootstrap and batch dependencies immediately.
  final byTag = {for (final server in servers) server['tag']: server};
  final ordered = <Map<String, dynamic>>[];
  final visiting = <dynamic>{};
  final visited = <dynamic>{};
  void visit(Map<String, dynamic> server) {
    final tag = server['tag'];
    if (visited.contains(tag)) return;
    if (!visiting.add(tag)) {
      throw FormatException('Circular DNS transport dependency at "$tag"');
    }
    final resolver = server['domain_resolver'];
    final dependencies = <dynamic>[
      if (resolver is String) resolver,
      if (resolver is Map) resolver['server'],
      if (server['type'] == 'batch') ...(server['servers'] as List),
    ];
    for (final dependency in dependencies) {
      final target = byTag[dependency];
      if (target != null) visit(target);
    }
    visiting.remove(tag);
    visited.add(tag);
    ordered.add(server);
  }

  for (final server in servers) {
    visit(server);
  }
  dns['servers'] = ordered;
  for (final tag in [
    'dns_outbound_out',
    'dns_resolver_out',
    'dns_direct_out',
  ]) {
    if (byTag.containsKey(tag)) {
      route.putIfAbsent('default_domain_resolver', () => {'server': tag});
      break;
    }
  }
}

Map<String, dynamic> _dnsTransport(
  Map<String, dynamic> legacy,
  String address,
  String tag,
  Map<String, dynamic>? fakeip,
) {
  if (address == 'local') return {'type': 'local', 'tag': tag};
  if (address == 'fakeip') {
    return {
      'type': 'fakeip',
      'tag': tag,
      if (fakeip?['inet4_range'] != null) 'inet4_range': fakeip!['inet4_range'],
      if (fakeip?['inet6_range'] != null) 'inet6_range': fakeip!['inet6_range'],
    };
  }
  final uri = Uri.parse(
    address.contains('://')
        ? address
        : 'udp://${InternetAddress.tryParse(address)?.type == InternetAddressType.IPv6 ? '[$address]' : address}',
  );
  if (uri.scheme == 'rcode') {
    const codes = {
      'success': 0,
      'format_error': 1,
      'server_failure': 2,
      'name_error': 3,
      'not_implemented': 4,
      'refused': 5,
    };
    final code = codes[uri.host];
    if (code == null) {
      throw FormatException('Unsupported DNS response code "$address"');
    }
    return {'type': 'predefined', 'tag': tag, 'rcode': code};
  }
  if (uri.scheme == 'dhcp') {
    return {
      'type': 'dhcp',
      'tag': tag,
      if (uri.host.isNotEmpty && uri.host != 'auto') 'interface': uri.host,
    };
  }
  if (!['udp', 'tcp', 'tls', 'quic', 'https', 'h3'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    throw FormatException('Unsupported DNS server address "$address"');
  }
  final host = uri.host.replaceAll(RegExp(r'^\[|\]$'), '');
  final resolver = legacy['address_resolver'];
  return {
    'type': uri.scheme,
    'tag': tag,
    'server': host,
    if (uri.hasPort) 'server_port': uri.port,
    if (uri.scheme == 'https' || uri.scheme == 'h3')
      'path': uri.path.isEmpty ? '/dns-query' : uri.path,
    if (legacy['detour'] != null) 'detour': legacy['detour'],
    if (legacy['address_fallback_delay'] != null)
      'fallback_delay': legacy['address_fallback_delay'],
    if (resolver != null && InternetAddress.tryParse(host) == null)
      'domain_resolver': {
        'server': resolver,
        if (legacy['address_strategy'] != null)
          'strategy': legacy['address_strategy'],
      },
  };
}
