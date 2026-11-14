import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FlowPreferences {
  const FlowPreferences({this.theme = 'violet', this.pingMethod = 'tcp',
    this.splitMode = 'all', this.splitPackages = '', this.bypassLan = false});
  final String theme;
  final String pingMethod;
  final String splitMode;
  final String splitPackages;
  final bool bypassLan;

  FlowPreferences copyWith({String? theme, String? pingMethod,
    String? splitMode, String? splitPackages, bool? bypassLan}) => FlowPreferences(
      theme: theme ?? this.theme, pingMethod: pingMethod ?? this.pingMethod,
      splitMode: splitMode ?? this.splitMode,
      splitPackages: splitPackages ?? this.splitPackages,
      bypassLan: bypassLan ?? this.bypassLan);
}

final preferencesProvider = NotifierProvider<PreferencesController, FlowPreferences>(
  PreferencesController.new);

class PreferencesController extends Notifier<FlowPreferences> {
  static const _storage = FlutterSecureStorage();
  @override
  FlowPreferences build() => const FlowPreferences();

  Future<void> load() async {
    state = FlowPreferences(
      theme: await _storage.read(key: 'theme') ?? 'violet',
      pingMethod: await _storage.read(key: 'ping_method') ?? 'tcp',
      splitMode: await _storage.read(key: 'split_mode') ?? 'all',
      splitPackages: await _storage.read(key: 'split_packages') ?? '',
      bypassLan: await _storage.read(key: 'bypass_lan') == 'true');
  }

  Future<void> update(FlowPreferences value) async {
    state = value;
    await Future.wait([
      _storage.write(key: 'theme', value: value.theme),
      _storage.write(key: 'ping_method', value: value.pingMethod),
      _storage.write(key: 'split_mode', value: value.splitMode),
      _storage.write(key: 'split_packages', value: value.splitPackages),
      _storage.write(key: 'bypass_lan', value: value.bypassLan.toString()),
    ]);
  }
}

