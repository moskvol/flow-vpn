import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sing_box/sing_box.dart';

import 'app/flow_controller.dart';
import 'app/preferences.dart';
import 'core/vless.dart';
import 'features/subscriptions/subscriptions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FlowApp()));
}

final router = GoRouter(routes: [
  ShellRoute(builder: (context, state, child) => FlowShell(child: child), routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/servers', builder: (context, state) => const ServersScreen()),
    GoRoute(path: '/subscriptions', builder: (context, state) => const SubscriptionsScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ])
]);

const _themes = <String, (String, Color)>{
  'violet': ('Аметист', Color(0xFF7667F5)),
  'ocean': ('Океан', Color(0xFF168AAD)),
  'emerald': ('Изумруд', Color(0xFF1A9C78)),
  'sunset': ('Закат', Color(0xFFE06C45)),
  'rose': ('Розовый кварц', Color(0xFFCF5C91)),
  'amber': ('Янтарь', Color(0xFFB98613)),
  'ice': ('Лёд', Color(0xFF5278C9)),
  'graphite': ('Графит', Color(0xFF727983)),
};

class FlowApp extends ConsumerStatefulWidget {
  const FlowApp({super.key});
  @override
  ConsumerState<FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends ConsumerState<FlowApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(flowProvider.notifier).load());
    Future.microtask(() => ref.read(preferencesProvider.notifier).load());
  }
  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final seed = _themes[prefs.theme]?.$2 ?? _themes['violet']!.$2;
    return MaterialApp.router(
      title: 'Flow VPN',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: ThemeMode.system,
      theme: ThemeData(useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF9F7FF)),
      darkTheme: ThemeData(useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark)),
    );
  }
}

class FlowShell extends ConsumerWidget {
  const FlowShell({required this.child, super.key});
  final Widget child;
  static const paths = ['/', '/servers', '/subscriptions', '/settings'];
  static const labels = ['Главная', 'Серверы', 'Подписки', 'Настройки'];
  static const icons = [Icons.power_settings_new_rounded, Icons.dns_rounded,
    Icons.link_rounded, Icons.tune_rounded];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = GoRouterState.of(context).uri.path;
    final found = paths.indexOf(route);
    final index = found < 0 ? 0 : found;
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final state = ref.watch(flowProvider);
    final nav = <NavigationDestination>[
      for (var i = 0; i < paths.length; i++)
        NavigationDestination(icon: Icon(icons[i]), label: labels[i])
    ];
    final content = Column(children: [
      if (state.error != null)
        MaterialBanner(content: Text(state.error!),
          actions: [TextButton(onPressed: () => ref.read(flowProvider.notifier).clearError(),
            child: const Text('Закрыть'))]),
      Expanded(child: child),
    ]);
    return Scaffold(
      appBar: AppBar(title: const Text('Flow VPN'), centerTitle: false),
      body: wide ? Row(children: [
        NavigationRail(
          selectedIndex: index,
          onDestinationSelected: (i) => context.go(paths[i]),
          extended: MediaQuery.sizeOf(context).width >= 1050,
          destinations: [
            for (var i = 0; i < paths.length; i++)
              NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i]))
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: content),
      ]) : content,
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: index, destinations: nav,
        onDestinationSelected: (i) => context.go(paths[i])),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(flowProvider);
    final server = state.selected;
    final active = state.phase == VpnPhase.connected;
    final moving = state.phase == VpnPhase.connecting ||
      state.phase == VpnPhase.disconnecting;
    final scheme = Theme.of(context).colorScheme;
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 24),
        Text(active ? (Platform.isWindows ? 'VPN-ядро запущено' : 'VPN подключён') :
          moving ? 'Подключение…' : 'Готовы к подключению',
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 32),
        Center(child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 196, height: 196,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: active ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            boxShadow: active ? [BoxShadow(color: scheme.primary.withValues(alpha: .18),
              blurRadius: 38, spreadRadius: 10)] : null),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: server == null || moving ? null : () {
              if (active) {
                ref.read(flowProvider.notifier).disconnect();
              } else {
                ref.read(flowProvider.notifier).connect();
              }
            },
            child: moving ? const Center(child: CircularProgressIndicator()) :
              Icon(Icons.power_settings_new_rounded, size: 82,
                color: active ? scheme.primary : scheme.onSurfaceVariant),
          ),
        )),
        const SizedBox(height: 18),
        Text(active ? 'Отключить VPN' : 'Подключить VPN',
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 36),
        Card(child: ListTile(
          leading: const Icon(Icons.dns_rounded),
          title: Text(server?.name ?? 'Сервер не выбран'),
          subtitle: Text(server == null ? 'Добавьте подписку' :
            'VLESS · ' + server.security.toUpperCase() + ' · ' + server.host),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/servers'),
        )),
        const SizedBox(height: 10),
        if (Platform.isWindows)
          const Padding(padding: EdgeInsets.all(12),
            child: Text('Для системного TUN нужны sing-box 1.14.x, Wintun и права администратора.')),
      ]),
    ));
  }
}

class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key});
  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}
class _ServersScreenState extends ConsumerState<ServersScreen> {
  String query = '';
  final Map<String, String> _pings = {};
  final Set<String> _pinging = {};
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(flowProvider);
    final servers = state.servers.where((s) =>
      s.name.toLowerCase().contains(query.toLowerCase()) ||
      s.host.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      TextField(decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search_rounded), hintText: 'Поиск серверов',
        border: OutlineInputBorder()),
        onChanged: (v) => setState(() => query = v)),
      const SizedBox(height: 12),
      if (servers.isEmpty) const Card(child: Padding(
        padding: EdgeInsets.all(24), child: Text('Серверов пока нет'))),
      for (final server in servers)
        Card(child: Column(children: [
          ListTile(
            leading: CircleAvatar(child: Text(server.countryFlag,
              style: const TextStyle(fontSize: 24))),
            title: Text(server.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('VLESS · ' + server.security.toUpperCase() + ' · ' + server.host,
              maxLines: 1, overflow: TextOverflow.ellipsis),
            selected: server.id == state.selectedId,
            onTap: () async {
              await ref.read(flowProvider.notifier).select(server);
              if (context.mounted) context.go('/');
            },
            trailing: IconButton(
              tooltip: server.favorite ? 'Убрать из избранного' : 'В избранное',
              icon: Icon(server.favorite ? Icons.star_rounded : Icons.star_outline_rounded),
              onPressed: () => ref.read(flowProvider.notifier).toggleFavorite(server),
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(child: Text(_pings[server.id] ?? '')),
              TextButton.icon(
                onPressed: _pinging.contains(server.id) ? null : () => _ping(server),
                icon: _pinging.contains(server.id)
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_ping_rounded),
                label: const Text('Пропинговать')),
            ])),
        ])),
    ]);
  }

  Future<void> _ping(VlessServer server) async {
    final prefs = ref.read(preferencesProvider);
    final vpn = ref.read(flowProvider);
    if (prefs.pingMethod == 'http' && vpn.phase != VpnPhase.connected) {
      setState(() => _pings[server.id] = 'HTTP-тест доступен при подключённом VPN');
      return;
    }
    setState(() { _pinging.add(server.id); _pings.remove(server.id); });
    final watch = Stopwatch()..start();
    HttpClient? client;
    try {
      if (prefs.pingMethod == 'http') {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
        final request = await client.getUrl(Uri.parse('https://www.gstatic.com/generate_204'))
          .timeout(const Duration(seconds: 10));
        final response = await request.close().timeout(const Duration(seconds: 10));
        await response.drain<void>();
      } else {
        final socket = await Socket.connect(server.host, server.port,
          timeout: const Duration(seconds: 8));
        socket.destroy();
      }
      watch.stop();
      if (mounted) setState(() => _pings[server.id] = '${watch.elapsedMilliseconds} мс');
    } catch (_) {
      if (mounted) setState(() => _pings[server.id] = 'Нет ответа');
    } finally {
      client?.close(force: true);
      if (mounted) setState(() => _pinging.remove(server.id));
    }
  }
}

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(flowProvider);
    return ListView(padding: const EdgeInsets.all(20), children: [
      FilledButton.icon(onPressed: state.busy ? null : () => _add(context, ref),
        icon: const Icon(Icons.add_rounded), label: const Text('Добавить подписку')),
      const SizedBox(height: 12),
      if (state.busy) const LinearProgressIndicator(),
      for (final sub in state.subscriptions) _SubscriptionCard(subscription: sub),
    ]);
  }
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final url = TextEditingController();
    final name = TextEditingController();
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Добавить подписку'),
        content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: url, decoration: const InputDecoration(
            labelText: 'HTTPS-ссылка подписки')),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: const InputDecoration(
            labelText: 'Название (необязательно)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена')),
          FilledButton(onPressed: () {
            Navigator.pop(dialogContext);
            ref.read(flowProvider.notifier).addSubscription(url.text, name.text);
          }, child: const Text('Добавить')),
        ],
      ));
    } finally {
      url.dispose();
      name.dispose();
    }
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.subscription});
  final VpnSubscription subscription;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(title: Text(subscription.name),
        subtitle: Text(subscription.servers.length.toString() + ' серверов · VLESS')),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(subscription.updatedAt == null ? 'Не обновлялась' :
          'Обновлено: ' + subscription.updatedAt!.toLocal().toString().split('.').first)),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton.icon(
          onPressed: () => ref.read(flowProvider.notifier).refresh(subscription),
          icon: const Icon(Icons.refresh_rounded), label: const Text('Обновить')),
        TextButton.icon(
          onPressed: () => ref.read(flowProvider.notifier).remove(subscription),
          icon: const Icon(Icons.delete_outline_rounded), label: const Text('Удалить')),
      ]),
    ]),
  ));
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _packages;
  String _lastPackageValue = '';
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _packages = TextEditingController(text: ref.read(preferencesProvider).splitPackages);
    _lastPackageValue = _packages.text;
  }
  @override
  void dispose() { _packages.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    if (prefs.splitPackages != _lastPackageValue) {
      _lastPackageValue = prefs.splitPackages;
      _packages.text = prefs.splitPackages;
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Внешний вид', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final entry in _themes.entries)
          ChoiceChip(label: Text(entry.value.$1), selected: prefs.theme == entry.key,
            avatar: CircleAvatar(backgroundColor: entry.value.$2, radius: 8),
            onSelected: (_) => _save(prefs.copyWith(theme: entry.key))),
      ]),
      const SizedBox(height: 20),
      Text('Проверка задержки', style: Theme.of(context).textTheme.titleLarge),
      Card(child: Column(children: [
        RadioListTile<String>(value: 'tcp', groupValue: prefs.pingMethod,
          title: const Text('TCP до сервера'),
          subtitle: const Text('Проверяет время открытия соединения с узлом'),
          onChanged: (v) { if (v != null) _save(prefs.copyWith(pingMethod: v)); }),
        RadioListTile<String>(value: 'http', groupValue: prefs.pingMethod,
          title: const Text('HTTP через сеть VPN'),
          subtitle: const Text('Измеряет запрос через текущий туннель; требует подключение'),
          onChanged: (v) { if (v != null) _save(prefs.copyWith(pingMethod: v)); }),
      ])),
      const SizedBox(height: 12),
      Text('Раздельное туннелирование', style: Theme.of(context).textTheme.titleLarge),
      if (Platform.isAndroid) ...[
        Card(child: Column(children: [
          RadioListTile<String>(value: 'all', groupValue: prefs.splitMode,
            title: const Text('Все приложения через VPN'),
            onChanged: (v) { if (v != null) _changeSplitMode(v); }),
          RadioListTile<String>(value: 'bypass', groupValue: prefs.splitMode,
            title: const Text('Исключить выбранные приложения'),
            onChanged: (v) { if (v != null) _changeSplitMode(v); }),
          RadioListTile<String>(value: 'only', groupValue: prefs.splitMode,
            title: const Text('Только выбранные приложения через VPN'),
            onChanged: (v) { if (v != null) _changeSplitMode(v); }),
          if (prefs.splitMode != 'all') Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: [
              TextField(controller: _packages, minLines: 1, maxLines: 4,
                decoration: const InputDecoration(labelText: 'Package ID приложений',
                  hintText: 'com.example.app, org.telegram.messenger',
                  helperText: 'Укажите ID через запятую. Узнать его можно в сведениях о приложении.'),
                onChanged: (_) => setState(() {})),
              Align(alignment: Alignment.centerRight, child: FilledButton.icon(
                onPressed: _saving ? null : _applySplit,
                icon: _saving ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                label: const Text('Применить'))),
            ])),
        ])),
        SwitchListTile(title: const Text('Обходить локальную сеть'),
          subtitle: const Text('Локальные адреса пойдут напрямую, минуя VPN'),
          value: prefs.bypassLan,
          onChanged: (value) => _applyLan(value)),
      ] else const Card(child: ListTile(
        leading: Icon(Icons.info_outline_rounded),
        title: Text('Раздельное туннелирование доступно на Android'),
        subtitle: Text('В этой сборке системная маршрутизация приложений поддерживается Android VpnService.'),
      )),
      const SizedBox(height: 12),
      const Card(child: ListTile(
        leading: Icon(Icons.info_outline_rounded),
        title: Text('Flow VPN 0.2.0'),
        subtitle: Text('Вертикальный срез: VLESS, TLS, REALITY, WebSocket, gRPC. '
          'Проверка работоспособности зависит от ядра и вашего сервера.'),
      )),
      if (Platform.isWindows) const Card(child: ListTile(
        leading: Icon(Icons.terminal_rounded),
        title: Text('Windows TUN'),
        subtitle: Text('Путь к sing-box.exe задаётся переменной FLOW_VPN_SING_BOX. '
          'Нужны sing-box 1.14.x, Wintun и права на создание TUN.'),
      )),
      const Card(child: ListTile(
        leading: Icon(Icons.lock_outline_rounded),
        title: Text('Приватность'),
        subtitle: Text('Подписки и ссылки хранятся в защищённом хранилище устройства. '
          'Аналитика не собирается.'),
      )),
    ]);
  }

  Future<void> _save(FlowPreferences value) async {
    await ref.read(preferencesProvider.notifier).update(value);
  }

  List<String> get _packageIds => _packages.text.split(RegExp(r'[,;\s]+'))
    .map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList();

  Future<void> _applySplit() async {
    await _applySplitMode(ref.read(preferencesProvider).splitMode);
  }

  Future<void> _changeSplitMode(String mode) async {
    await _save(ref.read(preferencesProvider).copyWith(splitMode: mode));
    await _applySplitMode(mode);
  }

  Future<void> _applySplitMode(String mode) async {
    final ids = _packageIds;
    if (mode != 'all' && ids.any((id) => !RegExp(r'^[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+$').hasMatch(id))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проверьте формат package ID')));
      return;
    }
    setState(() => _saving = true);
    try {
      await SingBox.instance.updateRoutingRules((rules) => rules.copyWith(
        bypassApps: mode == 'bypass' ? ids : const <String>[],
        proxyApps: mode == 'only' ? ids : const <String>[]));
      await _save(ref.read(preferencesProvider).copyWith(splitPackages: _packages.text));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Правила туннелирования применены')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось применить правила. Запустите VPN и попробуйте ещё раз.')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _applyLan(bool value) async {
    final prefs = ref.read(preferencesProvider);
    try {
      await SingBox.instance.updateRoutingRules((rules) => rules.copyWith(bypassLan: value));
      await _save(prefs.copyWith(bypassLan: value));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить правило обхода LAN')));
    }
  }
}

