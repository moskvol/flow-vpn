import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/flow_controller.dart';
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
  }
  @override
  Widget build(BuildContext context) => DynamicColorBuilder(
    builder: (light, dark) => MaterialApp.router(
      title: 'Flow VPN',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: ThemeMode.system,
      theme: ThemeData(useMaterial3: true,
        colorScheme: light ?? ColorScheme.fromSeed(seedColor: const Color(0xFF6559D8)),
        scaffoldBackgroundColor: const Color(0xFFF9F7FF)),
      darkTheme: ThemeData(useMaterial3: true,
        colorScheme: dark ?? ColorScheme.fromSeed(
          seedColor: const Color(0xFFBDB4FF), brightness: Brightness.dark)),
    ),
  );
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
        Card(child: ListTile(
          leading: CircleAvatar(child: Text(server.name.isEmpty ? 'V' : server.name[0].toUpperCase())),
          title: Text(server.name),
          subtitle: Text('VLESS · ' + server.security.toUpperCase() + ' · ' + server.host),
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
        )),
    ]);
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20), children: [
      const Card(child: ListTile(
        leading: Icon(Icons.info_outline_rounded),
        title: Text('Flow VPN 0.1.0'),
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
