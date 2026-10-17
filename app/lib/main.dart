import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_providers.dart';
import 'data/api_key_storage.dart';
import 'data/database.dart';
import 'data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final apiKeyStorage = FlutterSecureApiKeyStorage();
  final settingsRepository = SettingsRepository(
    prefs,
    apiKeyStorage,
    isWeb: kIsWeb,
  );
  final initialSettings = await settingsRepository.load();
  final db = AppDatabase.open();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiKeyStorageProvider.overrideWithValue(apiKeyStorage),
        isWebProvider.overrideWithValue(kIsWeb),
        initialAppSettingsProvider.overrideWithValue(initialSettings),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        databaseProvider.overrideWithValue(db),
      ],
      child: const AvaliblethyApp(),
    ),
  );
}
