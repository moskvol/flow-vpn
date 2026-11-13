import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/vless.dart';

class VpnSubscription {
  const VpnSubscription({required this.url, required this.name,
    required this.servers, this.updatedAt});
  final String url, name;
  final List<VlessServer> servers;
  final DateTime? updatedAt;

  VpnSubscription withServers(List<VlessServer> updated) => VpnSubscription(
    url: url, name: name, servers: updated, updatedAt: DateTime.now());
  Map<String, Object?> toJson() => {
    'url': url, 'name': name,
    'servers': servers.map((s) => s.toJson()).toList(),
    'updatedAt': updatedAt?.toIso8601String()};
  factory VpnSubscription.fromJson(Map<String, dynamic> j) => VpnSubscription(
    url: j['url'] as String, name: j['name'] as String,
    servers: (j['servers'] as List).map((s) =>
      VlessServer.fromJson(Map<String, dynamic>.from(s as Map))).toList(),
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''));
}

class SubscriptionRepository {
  SubscriptionRepository([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'flow_vpn_subscriptions_v1';
  static const _selectedKey = 'flow_vpn_selected_server_v1';
  static const _maxBytes = 1024 * 1024;

  Future<List<VpnSubscription>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((j) =>
      VpnSubscription.fromJson(Map<String, dynamic>.from(j as Map))).toList();
  }

  Future<void> save(List<VpnSubscription> subscriptions) =>
    _storage.write(key: _key, value: jsonEncode(
      subscriptions.map((s) => s.toJson()).toList()));

  Future<String?> selectedId() => _storage.read(key: _selectedKey);
  Future<void> saveSelectedId(String id) =>
    _storage.write(key: _selectedKey, value: id);

  Future<VpnSubscription> fetch(String url, {String? name,
      VpnSubscription? previous}) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Требуется HTTPS-ссылка подписки');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    client.autoUncompress = false;
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw HttpException('Ошибка загрузки: HTTP ' + response.statusCode.toString());
      }
      if (response.contentLength > _maxBytes) {
        throw const FormatException('Подписка превышает 1 МБ');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBytes) {
          throw const FormatException('Подписка превышает 1 МБ');
        }
      }
      final parsed = parseSubscription(utf8.decode(bytes, allowMalformed: false));
      if (parsed.length > 500) {
        throw const FormatException('Слишком много серверов в подписке');
      }
      final favorites = {
        for (final server in previous?.servers ?? <VlessServer>[])
          server.id: server.favorite
      };
      final servers = parsed.map((s) => s.withFavorite(favorites[s.id] ?? false)).toList();
      return VpnSubscription(url: uri.toString(),
        name: name?.trim().isNotEmpty == true ? name!.trim() :
          previous?.name ?? uri.host,
        servers: servers, updatedAt: DateTime.now());
    } finally {
      client.close(force: true);
    }
  }
}
