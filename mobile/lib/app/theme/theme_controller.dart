import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/storage/local_store.dart';
import '../../core/storage/local_store_provider.dart';

final appThemeModeProvider =
    StateNotifierProvider<AppThemeController, ThemeMode>((ref) {
      return AppThemeController(ref.watch(localStoreProvider))..load();
    });

class AppThemeController extends StateNotifier<ThemeMode> {
  AppThemeController(this._localStore) : super(ThemeMode.system);

  final LocalStore _localStore;

  Future<void> load() async {
    state = await _localStore.loadAppThemeMode();
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _localStore.saveAppThemeMode(mode);
  }
}
