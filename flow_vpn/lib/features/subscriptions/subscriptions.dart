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
  static const _maxBytes = 5 * 1024 * 1024;

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
    final input = url.trim();
    final direct = input.startsWith('vless://');
    final uri = Uri.tryParse(input);
    if (uri == null || (!direct && !_validSubscriptionUri(uri))) {
      throw const FormatException('Вставьте HTTPS-ссылку подписки или VLESS-ссылку');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      HttpClientResponse? response;
      var location = uri;
      if (!direct) {
        for (var redirects = 0; redirects <= 5; redirects++) {
          final request = await client.getUrl(location)
              .timeout(const Duration(seconds: 20));
          request.followRedirects = false;
          response = await request.close().timeout(const Duration(seconds: 20));
          if (![301, 302, 303, 307, 308].contains(response.statusCode)) break;
          final target = response.headers.value(HttpHeaders.locationHeader);
          if (target == null || redirects == 5) {
            throw const HttpException('Слишком много перенаправлений подписки');
          }
          final next = location.resolve(target);
          if (!_validSubscriptionUri(next)) {
            throw const FormatException('Перенаправление подписки должно вести на HTTPS');
          }
          await response.drain<void>();
          location = next;
        }
      }
      if (direct) {
        return _subscriptionFromText(input, input, uri.host, name, previous);
      }
      if (response == null) throw const HttpException('Нет ответа сервера подписки');
      if (response.statusCode != 200) {
        throw HttpException('Ошибка загрузки: HTTP ' + response.statusCode.toString());
      }
      if (response.contentLength > _maxBytes) {
        throw const FormatException('Подписка превышает 5 МБ');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBytes) {
          throw const FormatException('Подписка превышает 5 МБ');
        }
      }
      return _subscriptionFromText(utf8.decode(bytes, allowMalformed: false),
          input, location.host, name, previous);
    } finally {
      client.close(force: true);
    }
  }

  bool _validSubscriptionUri(Uri uri) => uri.scheme == 'https' &&
      uri.host.isNotEmpty && uri.userInfo.isEmpty;

  VpnSubscription _subscriptionFromText(String body, String source,
      String fallbackName, String? name, VpnSubscription? previous) {
      final parsed = parseSubscription(body);
      if (parsed.length > 500) {
        throw const FormatException('Слишком много серверов в подписке');
      }
      final favorites = {
        for (final server in previous?.servers ?? <VlessServer>[])
          server.id: server.favorite
      };
      final servers = parsed.map((s) => s.withFavorite(favorites[s.id] ?? false)).toList();
      return VpnSubscription(url: source,
        name: name?.trim().isNotEmpty == true ? name!.trim() :
          previous?.name ?? fallbackName,
        servers: servers, updatedAt: DateTime.now());
  }
}
