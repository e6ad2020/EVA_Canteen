import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_router.dart';
import 'core/media/eva_image_cache.dart';
import 'core/notifications/notification_providers.dart';
import 'core/state/canteen_providers.dart';
import 'design_system/eva_theme.dart';
import 'features/splash/eva_splash_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EvaImageCache.configureMemoryCache();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const EvaCanteenApp(),
    ),
  );
}

class EvaCanteenApp extends ConsumerWidget {
  const EvaCanteenApp({super.key, this.forceShowSplashInTests = false});

  final bool forceShowSplashInTests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationControllerProvider);
    final prefs = ref.watch(appPreferencesProvider);
    final router = ref.watch(appRouterProvider);
    final i18n = ref.watch(i18nProvider);

    final theme = EvaThemeBuilder.build(
      locale: prefs.locale,
      mode: prefs.surfaceMode,
      accent: prefs.accentPreset,
      showDoodlePattern: prefs.showDoodlePattern,
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: i18n.t('canteen_name'),
      theme: theme,
      locale: prefs.locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => EvaSplashOverlay(
        forceShowInTests: forceShowSplashInTests,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
