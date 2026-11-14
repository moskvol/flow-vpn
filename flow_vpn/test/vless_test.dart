import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_vpn/core/vless.dart';

void main() {
  const link = 'vless://00000000-0000-4000-8000-000000000001@example.com:443'
    '?security=reality&sni=cdn.example.com&pb=abc&sid=0123&fp=chrome'
    '&flow=xtls-rprx-vision#Example';

  test('parses VLESS REALITY and generates an outbound', () {
    final server = VlessServer.parse(link);
    expect(server.name, 'Example');
    expect(server.toOutbound()['type'], 'vless');
    final tls = server.toOutbound()['tls'] as Map<String, Object?>;
    expect((tls['reality'] as Map)['public_key'], 'abc');
    expect(tls['insecure'], false);
  });

  test('decodes base64 subscriptions and deduplicates servers', () {
    final body = base64.encode(utf8.encode(link + '\n' + link));
    expect(parseSubscription(body).length, 1);
  });

  test('rejects malformed UUID and unsupported transport', () {
    expect(() => VlessServer.parse('vless://bad@example.com:443'), throwsFormatException);
    expect(() => VlessServer.parse(link.replaceFirst('flow=xtls-rprx-vision', 'type=xhttp')),
      throwsFormatException);
  });

  test('keeps usable servers when a subscription contains an unsupported profile', () {
    final body = '\uFEFF$link\n'
      '${link.replaceFirst('flow=xtls-rprx-vision', 'type=xhttp')}\n'
      '${link.replaceFirst('flow=xtls-rprx-vision', 'type=h2')}';
    final servers = parseSubscription(body);
    expect(servers.length, 2);
    expect(servers.last.transport, 'h2');
  });

  test('uses the standard VLESS port when a link omits it', () {
    final server = VlessServer.parse(
      'vless://00000000-0000-4000-8000-000000000001@example.com?security=tls');
    expect(server.port, 443);
  });
}
