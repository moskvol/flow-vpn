import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sing_box/sing_box.dart';
import '../../core/vless.dart';

abstract class VpnEngine {
  Future<void> initialize();
  Future<void> connect(VlessServer server);
  Future<void> disconnect();
  Future<bool> isConnected();
  VlessServer? get currentServer;
}

VpnEngine createVpnEngine() {
  if (Platform.isAndroid) return AndroidVpnEngine();
  if (Platform.isWindows) return WindowsVpnEngine();
  throw UnsupportedError('Flow VPN поддерживает только Android и Windows');
}

class AndroidVpnEngine implements VpnEngine {
  VlessServer? _current;
  @override
  VlessServer? get currentServer => _current;

  @override
  Future<void> initialize() => SingBox.instance.initialize(
    const SingBoxOptions(android: SingBoxAndroidOptions(
      notificationTitle: 'Flow VPN')));

  @override
  Future<void> connect(VlessServer server) async {
    if (!await SingBox.instance.requestNotificationPermission()) {
      // Android may allow the tunnel even when notifications are hidden.
    }
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

class WindowsVpnEngine implements VpnEngine {
  Process? _process;
  File? _config;
  VlessServer? _current;
  @override
  VlessServer? get currentServer => _current;

  String get _binary {
    final path = Platform.environment['FLOW_VPN_SING_BOX'];
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      throw StateError('Укажите проверенный sing-box.exe в FLOW_VPN_SING_BOX');
    }
    return path;
  }

  @override
  Future<void> initialize() async {
    // Binary validation is deferred until the first connection so the UI opens
    // even when a local core has not been installed.
  }

  Map<String, Object?> _configFor(VlessServer server) => {
    'log': {'level': 'warn', 'timestamp': false},
    'dns': {
      'servers': [
        {'tag': 'remote', 'type': 'https', 'server': '1.1.1.1', 'detour': 'proxy'},
        {'tag': 'local', 'type': 'local'}
      ],
      'final': 'remote'
    },
    'inbounds': [
      {'type': 'tun', 'tag': 'tun-in', 'address': [
        '172.19.0.1/30', 'fdfe:dcba:9876::1/126'
      ], 'auto_route': true, 'strict_route': true}
    ],
    'outbounds': [server.toOutbound(), {'type': 'direct', 'tag': 'direct'}],
    'route': {
      'rules': [
        {'action': 'sniff'},
        {'protocol': 'dns', 'action': 'hijack-dns'},
        {'ip_is_private': true, 'outbound': 'direct'}
      ],
      'final': 'proxy',
      'auto_detect_interface': true,
      'default_domain_resolver': 'local'
    }
  };

  @override
  Future<void> connect(VlessServer server) async {
    await disconnect();
    final binary = _binary;
    final version = await Process.run(binary, ['version'])
      .timeout(const Duration(seconds: 8));
    if (version.exitCode != 0 || !version.stdout.toString().contains('sing-box version 1.14.')) {
      throw StateError('Требуется sing-box 1.14.x');
    }
    final directory = await Directory.systemTemp.createTemp('flow-vpn-');
    final config = File(directory.path + Platform.pathSeparator + 'config.json');
    _config = config;
    try {
      await config.writeAsString(jsonEncode(_configFor(server)), flush: true);
      final check = await Process.run(binary, ['check', '-c', config.path])
        .timeout(const Duration(seconds: 10));
      if (check.exitCode != 0) {
        throw StateError('Конфигурация отклонена sing-box: ' +
          check.stderr.toString().replaceAll(server.uuid, '[скрыто]'));
      }
      final process = await Process.start(binary, ['run', '-c', config.path],
        runInShell: false);
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      _process = process;
      final exit = process.exitCode.then((code) {
        if (identical(_process, process)) {
          _process = null;
          _current = null;
        }
        return code;
      });
      final first = await Future.any<Object>([
        exit, Future<Object>.delayed(const Duration(seconds: 3), () => 'running')
      ]);
      if (first != 'running') {
        throw StateError('sing-box завершился при запуске: ' + first.toString());
      }
      _current = server;
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final process = _process;
    _process = null;
    _current = null;
    if (process != null) {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5),
        onTimeout: () { process.kill(ProcessSignal.sigkill); return -1; });
    }
    final config = _config;
    _config = null;
    if (config != null) {
      try { await config.parent.delete(recursive: true); } on FileSystemException { }
    }
  }

  @override
  Future<bool> isConnected() async => _process != null;
}
