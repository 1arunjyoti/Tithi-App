import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';


import 'storage_provider.dart';

class ProNotifier extends StateNotifier<bool> {
  final Box<dynamic> _settingsBox;
  static const _proKey = 'is_pro_version';

  ProNotifier(this._settingsBox) : super(_settingsBox.get(_proKey, defaultValue: false) as bool);

  void setPro(bool value) {
    state = value;
    _settingsBox.put(_proKey, value);
  }

  void togglePro() {
    setPro(!state);
  }
}

final proProvider = StateNotifierProvider<ProNotifier, bool>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final settingsBox = storageService.getSettingsBox();
  return ProNotifier(settingsBox);
});
