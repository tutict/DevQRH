import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_store.dart';
import '../../features/lookup/presentation/lookup_controller.dart';
import 'app_localizations.dart';

final appLocaleModeProvider =
    StateNotifierProvider<AppLocaleController, AppLocaleMode>((ref) {
      return AppLocaleController(ref.watch(localStoreProvider))..load();
    });

class AppLocaleController extends StateNotifier<AppLocaleMode> {
  AppLocaleController(this._localStore) : super(AppLocaleMode.system);

  final LocalStore _localStore;

  Locale? get locale {
    return switch (state) {
      AppLocaleMode.system => null,
      AppLocaleMode.english => const Locale('en'),
      AppLocaleMode.chinese => const Locale('zh'),
    };
  }

  Future<void> load() async {
    state = await _localStore.loadAppLocaleMode();
  }

  Future<void> setMode(AppLocaleMode mode) async {
    state = mode;
    await _localStore.saveAppLocaleMode(mode);
  }
}
