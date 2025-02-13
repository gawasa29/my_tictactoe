import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'src/app_lifecycle/app_lifecycle.dart';
import 'src/audio/audio_controller.dart';
import 'src/main_menu/main_menu_screen.dart';
import 'src/play_session/play_session_screen.dart';
import 'src/settings/persistence/local_storage_settings_persistence.dart';
import 'src/settings/persistence/settings_persistence.dart';
import 'src/settings/settings.dart';
import 'src/settings/settings_screen.dart';
import 'src/style/ink_transition.dart';
import 'src/style/palette.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 基本的なロギングの設定
  if (kDebugMode) {
    // デバッグモードでは、より多くのログを記録する
    Logger.root.level = Level.FINE;
  }
  // ログメッセージを購読する
  Logger.root.onRecord.listen((record) {
    final message = '${record.level.name}: ${record.time}: '
        '${record.loggerName}: '
        '${record.message}';

    debugPrint(message);
  });

  // フルスクリーン設定
  _log.info('Going full screen');
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  // モバイルデバイスでゲームを縦画面にロックする
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(MyApp(
    settingsPersistence: LocalStorageSettingsPersistence(),
  ));
}

Logger _log = Logger('main.dart');

class MyApp extends StatelessWidget {
  static final _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const MainMenuScreen(key: Key('main menu')),
        routes: [
          GoRoute(
            path: 'session',
            pageBuilder: (context, state) {
              return buildTransition<void>(
                child: PlaySessionScreen(
                  key: const Key('play session'),
                ),
                color: context.watch<Palette>().backgroundPlaySession,
                flipHorizontally: true,
              );
            },
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) =>
                const SettingsScreen(key: Key('settings')),
          ),
        ],
      ),
    ],
  );

  final SettingsPersistence settingsPersistence;

  const MyApp({
    super.key,
    required this.settingsPersistence,
  });

  @override
  Widget build(BuildContext context) {
    return AppLifecycleObserver(
      child: MultiProvider(
        providers: [
          Provider(create: (context) => Palette()),
          Provider<SettingsController>(
            lazy: false,
            create: (context) => SettingsController(
              persistence: settingsPersistence,
            )..loadStateFromPersistence(),
          ),
          ProxyProvider2<SettingsController, ValueNotifier<AppLifecycleState>,
              AudioController>(
            // Ensures that the AudioController is created on startup,
            // and not "only when it's needed", as is default behavior.
            // This way, music starts immediately.
            lazy: false,
            create: (context) => AudioController()..initialize(),
            update: (context, settings, lifecycleNotifier, audio) {
              if (audio == null) throw ArgumentError.notNull();
              audio.attachSettings(settings);
              audio.attachLifecycleNotifier(lifecycleNotifier);
              return audio;
            },
            dispose: (context, audio) => audio.dispose(),
          ),
        ],
        child: Builder(builder: (context) {
          final palette = context.watch<Palette>();

          return MaterialApp.router(
            title: 'My Flutter Game',
            theme: ThemeData.from(
              colorScheme: ColorScheme.fromSeed(
                seedColor: palette.darkPen,
                surface: palette.backgroundMain,
              ),
              textTheme: TextTheme(
                bodyMedium: TextStyle(color: palette.ink),
              ),
              useMaterial3: true,
            ).copyWith(
              // Make buttons more fun.
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  textStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            routerConfig: _router,
          );
        }),
      ),
    );
  }
}
