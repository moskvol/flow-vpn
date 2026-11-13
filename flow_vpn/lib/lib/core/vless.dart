import 'dart:convert';

class VlessServer {
  const VlessServer({required this.name, required this.host, required this.port,
    required this.uuid, required this.link, this.security = 'none', this.sni,
    this.publicKey, this.shortId, this.fingerprint, this.flow,
    this.transport = 'tcp', this.path, this.serviceName, this.hostHeader,
    this.favorite = false});

  final String name, host, uuid, link, security, transport;
  final int port;
  final String? sni, publicKey, shortId, fingerprint, flow, path, serviceName, hostHeader;
  final bool favorite;
  String get id => [uuid, host.toLowerCase(), port, security, transport, sni, path].join('|');

  VlessServer withFavorite(bool value) => VlessServer(
    name: name, host: host, port: port, uuid: uuid, link: link,
    security: security, sni: sni, publicKey: publicKey, shortId: shortId,
    fingerprint: fingerprint, flow: flow, transport: transport, path: path,
    serviceName: serviceName, hostHeader: hostHeader, favorite: value);

  Map<String, Object?> toJson() => {
    'name': name, 'host': host, 'port': port, 'uuid': uuid, 'link': link,
    'security': security, 'sni': sni, 'publicKey': publicKey, 'shortId': shortId,
    'fingerprint': fingerprint, 'flow': flow, 'transport': transport,
    'path': path, 'serviceName': serviceName, 'hostHeader': hostHeader,
    'favorite': favorite};
  factory VlessServer.fromJson(Map<String, dynamic> j) => VlessServer(
    name: j['name'] as String, host: j['host'] as String, port: j['port'] as int,
    uuid: j['uuid'] as String, link: j['link'] as String,
    security: j['security'] as String? ?? 'none', sni: j['sni'] as String?,
    publicKey: j['publicKey'] as String?, shortId: j['shortId'] as String?,
    fingerprint: j['fingerprint'] as String?, flow: j['flow'] as String?,
    transport: j['transport'] as String? ?? 'tcp', path: j['path'] as String?,
    serviceName: j['serviceName'] as String?, hostHeader: j['hostHeader'] as String?,
    favorite: j['favorite'] as bool? ?? false);

  static VlessServer parse(String input) {
    final u = Uri.tryParse(input.trim());
    if (u == null || u.scheme != 'vless' || u.host.isEmpty || u.port < 1 || u.port > 65535) {
      throw const FormatException('Неверная ссылка VLESS');
    }
    final uuid = u.userInfo.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(uuid)) {
      throw const FormatException('Неверный UUID VLESS');
    }
    final q = u.queryParameters;
    final security = q['security'] ?? 'none';
    final transport = q['type'] ?? 'tcp';
    if (!{'none', 'tls', 'reality'}.contains(security) || !{'tcp', 'ws', 'grpc'}.contains(transport)) {
      throw const FormatException('Режим или транспорт пока не поддерживается');
    }
    if (security == 'reality' && (q['pbk'] ?? q['pb'] ?? '').isEmpty) {
      throw const FormatException('REALITY требует public key');
    }
    if (q['flow'] != null && q['flow']!.isNotEmpty && q['flow'] != 'xtls-rprx-vision') {
      throw const FormatException('Неизвестный VLESS flow');
    }
    return VlessServer(name: u.fragment.isEmpty ? '${u.host}:${u.port}' : u.fragment,
      host: u.host, port: u.port, uuid: uuid, link: input.trim(),
      security: security, sni: q['sni'], publicKey: q['pbk'] ?? q['pb'], shortId: q['sid'],
      fingerprint: q['fp'], flow: q['flow'], transport: transport,
      path: q['path'], serviceName: q['serviceName'], hostHeader: q['host']);
  }

  Map<String, Object?> toOutbound() {
    final o = <String, Object?>{'type': 'vless', 'tag': 'proxy',
      'server': host, 'server_port': port, 'uuid': uuid};
    if (flow != null && flow!.isNotEmpty) o['flow'] = flow;
    if (security != 'none') {
      final tls = <String, Object?>{'enabled': true, 'server_name': sni ?? host, 'insecure': false};
      if (fingerprint != null && fingerprint!.isNotEmpty) {
        tls['utls'] = {'enabled': true, 'fingerprint': fingerprint};
      }
      if (security == 'reality') {
        tls['reality'] = {'enabled': true, 'public_key': publicKey, 'short_id': shortId ?? ''};
      }
      o['tls'] = tls;
    }
    if (transport == 'ws') {
      o['transport'] = {'type': 'ws', 'path': path ?? '/',
        if (hostHeader != null && hostHeader!.isNotEmpty) 'headers': {'Host': hostHeader}};
    } else if (transport == 'grpc') {
      o['transport'] = {'type': 'grpc', 'service_name': serviceName ?? ''};
    }
    return o;
  }
}

List<VlessServer> parseSubscription(String body) {
  var text = body.trim();
  if (!text.contains('://')) {
    try {
      text = utf8.decode(base64.decode(base64.normalize(text.replaceAll(RegExp(r'\s'), ''))));
    } on FormatException {
      throw const FormatException('Неизвестный формат подписки');
    }
  }
  final unique = <String, VlessServer>{};
  for (final line in const LineSplitter().convert(text)) {
    final value = line.trim();
    if (value.startsWith('vless://')) {
      final server = VlessServer.parse(value);
      unique[server.id] = server;
    }
  }
  if (unique.isEmpty) throw const FormatException('В подписке нет серверов VLESS');
  return unique.values.toList();
}
