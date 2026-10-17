import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_providers.dart';
import 'core/theme.dart';
import 'features/chat/chat_screen.dart';
import 'features/settings/settings_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const ChatScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  ],
);

class AvaliblethyApp extends ConsumerWidget {
  const AvaliblethyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'Avaliblethy',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
