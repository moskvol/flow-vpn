import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/vless.dart';
import '../features/subscriptions/subscriptions.dart';
import '../features/vpn/vpn_engine.dart';

enum VpnPhase { disconnected, connecting, connected, disconnecting, error }

class FlowState {
  const FlowState({this.subscriptions = const [], this.selectedId,
    this.phase = VpnPhase.disconnected, this.busy = false, this.error});
  final List<VpnSubscription> subscriptions;
  final String? selectedId;
  final VpnPhase phase;
  final bool busy;
  final String? error;
  List<VlessServer> get servers {
    final unique = <String, VlessServer>{};
    for (final subscription in subscriptions) {
      for (final server in subscription.servers) {
        unique[server.id] = server;
      }
    }
    return unique.values.toList();
  }
  VlessServer? get selected {
    for (final server in servers) {
      if (server.id == selectedId) return server;
    }
    return null;
  }
  FlowState copyWith({List<VpnSubscription>? subscriptions, String? selectedId,
    VpnPhase? phase, bool? busy, String? error}) => FlowState(
    subscriptions: subscriptions ?? this.subscriptions,
    selectedId: selectedId ?? this.selectedId,
    phase: phase ?? this.phase, busy: busy ?? this.busy, error: error);
}

final flowProvider = NotifierProvider<FlowController, FlowState>(FlowController.new);

class FlowController extends Notifier<FlowState> {
  late final SubscriptionRepository _repository;
  late final VpnEngine _engine;
  @override
  FlowState build() {
    _repository = SubscriptionRepository();
    _engine = createVpnEngine();
    final timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        if (state.phase == VpnPhase.connected && !await _engine.isConnected()) {
          state = state.copyWith(phase: VpnPhase.error,
            error: 'VPN-движок завершился. Проверьте сеть и подключитесь снова.');
        }
      } catch (e) {
        state = state.copyWith(phase: VpnPhase.error, error: _safeError(e));
      }
    });
    ref.onDispose(timer.cancel);
    return const FlowState();
  }

  Future<void> load() async {
    state = state.copyWith(busy: true);
    try {
      await _engine.initialize();
      final subscriptions = await _repository.load();
      final savedId = await _repository.selectedId();
      final allServers = subscriptions.expand((s) => s.servers).toList();
      state = FlowState(subscriptions: subscriptions,
        selectedId: allServers.any((s) => s.id == savedId)
          ? savedId : allServers.isEmpty ? null : allServers.first.id,
        phase: await _engine.isConnected() ? VpnPhase.connected : VpnPhase.disconnected);
    } catch (e) {
      state = state.copyWith(busy: false, error: _safeError(e));
    }
  }

  Future<void> addSubscription(String url, String name) async {
    state = state.copyWith(busy: true, error: null);
    try {
      VpnSubscription? previous;
      for (final subscription in state.subscriptions) {
        if (subscription.url == url) previous = subscription;
      }
      final updated = await _repository.fetch(url, name: name, previous: previous);
      final list = [...state.subscriptions.where((s) => s.url != url), updated];
      await _repository.save(list);
      state = FlowState(subscriptions: list,
        selectedId: state.selectedId ?? updated.servers.first.id,
        phase: state.phase);
    } catch (e) {
      state = state.copyWith(busy: false, error: _safeError(e));
    }
  }

  Future<void> refresh(VpnSubscription subscription) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final updated = await _repository.fetch(subscription.url,
        name: subscription.name, previous: subscription);
      final list = state.subscriptions.map((s) =>
        s.url == subscription.url ? updated : s).toList();
      await _repository.save(list);
      state = state.copyWith(subscriptions: list, busy: false, error: null);
    } catch (e) {
      state = state.copyWith(busy: false, error: _safeError(e));
    }
  }

  Future<void> remove(VpnSubscription subscription) async {
    if (state.phase == VpnPhase.connected &&
        subscription.servers.any((s) => s.id == state.selectedId)) {
      await disconnect();
    }
    final list = state.subscriptions.where((s) => s.url != subscription.url).toList();
    await _repository.save(list);
    final remaining = list.expand((s) => s.servers).toList();
    state = FlowState(subscriptions: list, phase: state.phase,
      selectedId: remaining.any((s) => s.id == state.selectedId)
        ? state.selectedId : remaining.isEmpty ? null : remaining.first.id);
  }

  void clearError() => state = state.copyWith(error: null);

  Future<void> select(VlessServer server) async {
    final wasConnected = state.phase == VpnPhase.connected;
    await _repository.saveSelectedId(server.id);
    state = state.copyWith(selectedId: server.id, error: null);
    if (wasConnected) await connect();
  }

  Future<void> toggleFavorite(VlessServer server) async {
    final list = state.subscriptions.map((sub) => VpnSubscription(
      url: sub.url, name: sub.name, updatedAt: sub.updatedAt,
      servers: sub.servers.map((s) => s.id == server.id
        ? s.withFavorite(!s.favorite) : s).toList())).toList();
    await _repository.save(list);
    state = state.copyWith(subscriptions: list);
  }

  Future<void> connect() async {
    final server = state.selected;
    if (server == null) {
      state = state.copyWith(error: 'Сначала выберите сервер');
      return;
    }
    state = state.copyWith(phase: VpnPhase.connecting, error: null);
    try {
      await _engine.connect(server);
      state = state.copyWith(phase: VpnPhase.connected, error: null);
    } catch (e) {
      state = state.copyWith(phase: VpnPhase.error, error: _safeError(e));
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(phase: VpnPhase.disconnecting, error: null);
    try {
      await _engine.disconnect();
      state = state.copyWith(phase: VpnPhase.disconnected, error: null);
    } catch (e) {
      state = state.copyWith(phase: VpnPhase.error, error: _safeError(e));
    }
  }

  String _safeError(Object error) => error.toString()
    .replaceAll(RegExp(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}'), '[UUID]')
    .replaceAll(RegExp(r'https?://\S+'), '[URL]');
}
