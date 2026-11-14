import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FlowPreferences {
  const FlowPreferences({this.theme = 'violet', this.pingMethod = 'tcp',
    this.splitMode = 'all', this.splitPackages = '', this.bypassLan = false,
    this.userName = '', this.setupComplete = false});
  final String theme;
  final String pingMethod;
  final String splitMode;
  final String splitPackages;
  final bool bypassLan;
  final String userName;
  final bool setupComplete;

  FlowPreferences copyWith({String? theme, String? pingMethod,
    String? splitMode, String? splitPackages, bool? bypassLan,
    String? userName, bool? setupComplete}) => FlowPreferences(
      theme: theme ?? this.theme, pingMethod: pingMethod ?? this.pingMethod,
      splitMode: splitMode ?? this.splitMode,
      splitPackages: splitPackages ?? this.splitPackages,
      bypassLan: bypassLan ?? this.bypassLan,
      userName: userName ?? this.userName,
      setupComplete: setupComplete ?? this.setupComplete);
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
      bypassLan: await _storage.read(key: 'bypass_lan') == 'true',
      userName: await _storage.read(key: 'user_name') ?? '',
      setupComplete: await _storage.read(key: 'setup_complete') == 'true');
  }

  Future<void> update(FlowPreferences value) async {
    state = value;
    await Future.wait([
      _storage.write(key: 'theme', value: value.theme),
      _storage.write(key: 'ping_method', value: value.pingMethod),
      _storage.write(key: 'split_mode', value: value.splitMode),
      _storage.write(key: 'split_packages', value: value.splitPackages),
      _storage.write(key: 'bypass_lan', value: value.bypassLan.toString()),
      _storage.write(key: 'user_name', value: value.userName),
      _storage.write(key: 'setup_complete', value: value.setupComplete.toString()),
    ]);
  }
}
