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

  /// Country flag from the decoded share-link name, or a best-effort country
  /// match when the provider uses a text label instead of a flag emoji.
  String get countryFlag => _countryFlag(name, host);

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
    if (u == null || u.scheme != 'vless' || u.host.isEmpty || u.port > 65535) {
      throw const FormatException('Неверная ссылка VLESS');
    }
    final uuid = u.userInfo.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(uuid)) {
      throw const FormatException('Неверный UUID VLESS');
    }
    final q = u.queryParameters;
    final security = (q['security'] ?? 'none').toLowerCase();
    final transport = (q['type'] ?? q['network'] ?? q['net'] ?? 'tcp').toLowerCase();
    if (!{'none', 'tls', 'xtls', 'reality'}.contains(security) ||
        !{'tcp', 'raw', 'none', 'ws', 'websocket', 'grpc', 'gun',
          'http', 'h2', 'httpupgrade', 'quic'}.contains(transport)) {
      throw const FormatException('Режим или транспорт пока не поддерживается');
    }
    if (security == 'reality' &&
        (q['pbk'] ?? q['publicKey'] ?? q['public_key'] ?? q['pb'] ?? '').isEmpty) {
      throw const FormatException('REALITY требует public key');
    }
    if (q['flow'] != null && q['flow']!.isNotEmpty &&
        !{'none', 'xtls-rprx-vision', 'xtls-rprx-vision-udp443'}.contains(q['flow'])) {
      throw const FormatException('Неизвестный VLESS flow');
    }
    final fragment = _decodeFragment(u.fragment);
    final port = u.port == 0 ? 443 : u.port;
    return VlessServer(name: fragment.isEmpty ? '${u.host}:$port' : fragment,
      host: u.host, port: port, uuid: uuid, link: input.trim(),
      security: security, sni: q['sni'] ?? q['peer'] ?? q['servername'],
      publicKey: q['pbk'] ?? q['publicKey'] ?? q['public_key'] ?? q['pb'],
      shortId: q['sid'] ?? q['shortId'] ?? q['short_id'],
      fingerprint: q['fp'] ?? q['fingerprint'], flow: q['flow'], transport: transport,
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

String _decodeFragment(String value) {
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    return value;
  }
}

String _countryFlag(String name, String host) {
  final flagMatch = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true)
      .firstMatch(name);
  if (flagMatch != null) return flagMatch.group(0)!;

  final text = '${name.toLowerCase()} ${host.toLowerCase()}';
  const countries = <String, List<String>>{
    '🇷🇺': ['russia', 'россия', 'москва', 'ru.'],
    '🇺🇸': ['usa', 'united states', 'america', 'сша', 'us.'],
    '🇩🇪': ['germany', 'deutschland', 'германия', 'frankfurt', 'berlin', 'de.'],
    '🇳🇱': ['netherlands', 'holland', 'нидерланды', 'амстердам', 'nl.'],
    '🇫🇮': ['finland', 'финляндия', 'helsinki', 'fi.'],
    '🇸🇪': ['sweden', 'швеция', 'stockholm', 'se.'],
    '🇬🇧': ['united kingdom', 'great britain', 'england', 'london', 'uk.'],
    '🇫🇷': ['france', 'франция', 'paris', 'fr.'],
    '🇸🇬': ['singapore', 'сингапур', 'sg.'],
    '🇯🇵': ['japan', 'япония', 'tokyo', 'jp.'],
    '🇰🇷': ['south korea', 'korea', 'корея', 'seoul', 'kr.'],
    '🇹🇷': ['turkey', 'türkiye', 'турция', 'istanbul', 'tr.'],
    '🇵🇱': ['poland', 'польша', 'warsaw', 'pl.'],
    '🇨🇦': ['canada', 'канада', 'ca.'],
    '🇨🇭': ['switzerland', 'швейцария', 'zurich', 'ch.'],
    '🇦🇹': ['austria', 'австрия', 'vienna', 'at.'],
    '🇪🇸': ['spain', 'испания', 'madrid', 'es.'],
    '🇮🇹': ['italy', 'италия', 'milan', 'it.'],
    '🇭🇰': ['hong kong', 'гонконг', 'hk.'],
    '🇦🇪': ['uae', 'united arab emirates', 'оаэ', 'dubai', 'ae.'],
  };
  for (final entry in countries.entries) {
    if (entry.value.any(text.contains)) return entry.key;
  }
  return '🌐';
}

List<VlessServer> parseSubscription(String body) {
  var text = body.trim().replaceFirst('\uFEFF', '');
  if (!text.contains('://')) {
    try {
      final encoded = text.replaceAll(RegExp(r'\s'), '')
          .replaceAll('-', '+').replaceAll('_', '/');
      text = utf8.decode(base64.decode(base64.normalize(encoded)));
    } on FormatException {
      throw const FormatException('Неизвестный формат подписки');
    }
  }
  final unique = <String, VlessServer>{};
  for (final match in RegExp(r'vless://[^\s]+', caseSensitive: false).allMatches(text)) {
    try {
      final server = VlessServer.parse(match.group(0)!);
      unique[server.id] = server;
    } on FormatException {
      // A subscription can contain profiles this client cannot use.
    }
  }
  if (unique.isEmpty) throw const FormatException('В подписке нет серверов VLESS');
  return unique.values.toList();
}
