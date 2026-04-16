import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'i18n/app_localizations.dart';
import 'i18n/locale_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class DevQrhApp extends ConsumerWidget {
  const DevQrhApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final localeMode = ref.watch(appLocaleModeProvider);
    final locale = ref.read(appLocaleModeProvider.notifier).locale;
    final title = switch (localeMode) {
      AppLocaleMode.chinese => AppLocalizations.chinese.appTitle,
      _ => AppLocalizations.english.appTitle,
    };

    return MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
