import 'dart:convert';

import 'package:sing_box/sing_box.dart';
import '../../core/vless.dart';

abstract class VpnEngine {
  Future<void> initialize();
  Future<void> connect(VlessServer server);
  Future<void> disconnect();
  Future<bool> isConnected();
  VlessServer? get currentServer;
}

VpnEngine createVpnEngine() => AndroidVpnEngine();

class AndroidVpnEngine implements VpnEngine {
  VlessServer? _current;

  @override
  VlessServer? get currentServer => _current;

  @override
  Future<void> initialize() => SingBox.instance.initialize(
    const SingBoxOptions(
      android: SingBoxAndroidOptions(notificationTitle: 'Flow VPN'),
    ),
  );

  @override
  Future<void> connect(VlessServer server) async {
    await SingBox.instance.requestNotificationPermission();
    await SingBox.instance.connect(jsonEncode(server.toOutbound()));
    _current = server;
  }

  @override
  Future<void> disconnect() async {
    await SingBox.instance.disconnect();
    _current = null;
  }

  @override
  Future<bool> isConnected() async =>
      SingBox.instance.status == SingBoxConnectionStatus.connected;
}
