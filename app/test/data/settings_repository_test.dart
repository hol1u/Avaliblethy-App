import 'package:avaliblethy_app/data/api_key_storage.dart';
import 'package:avaliblethy_app/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryApiKeyStorage implements ApiKeyStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'migrates the legacy API key to secure storage and removes old value',
    () async {
      SharedPreferences.setMockInitialValues({'apiKey': 'legacy-secret'});
      final prefs = await SharedPreferences.getInstance();
      final storage = MemoryApiKeyStorage();
      final repository = SettingsRepository(prefs, storage, isWeb: false);

      final settings = await repository.load();

      expect(settings.apiKey, 'legacy-secret');
      expect(storage.value, 'legacy-secret');
      expect(prefs.containsKey('apiKey'), isFalse);

      await repository.save(settings.copyWith(apiKey: 'updated-secret'));
      expect(storage.value, 'updated-secret');
      expect(prefs.containsKey('apiKey'), isFalse);
    },
  );

  test('reads an existing key through the storage abstraction', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = MemoryApiKeyStorage()..value = 'stored-secret';
    final repository = SettingsRepository(prefs, storage, isWeb: false);

    final settings = await repository.load();

    expect(settings.apiKey, 'stored-secret');
  });

  test(
    'web keeps a migrated key in memory unless remembering is enabled',
    () async {
      SharedPreferences.setMockInitialValues({'apiKey': 'legacy-secret'});
      final prefs = await SharedPreferences.getInstance();
      final storage = MemoryApiKeyStorage();
      final repository = SettingsRepository(prefs, storage, isWeb: true);

      final settings = await repository.load();

      expect(settings.apiKey, 'legacy-secret');
      expect(settings.rememberApiKeyOnDevice, isFalse);
      expect(storage.value, isNull);
      expect(prefs.containsKey('apiKey'), isFalse);

      await repository.save(settings);
      expect(storage.value, isNull);
      expect(prefs.containsKey('apiKey'), isFalse);
    },
  );

  test('web persists a key only after explicit opt-in', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = MemoryApiKeyStorage();
    final repository = SettingsRepository(prefs, storage, isWeb: true);

    await repository.save(
      const AppSettings(
        apiKey: 'remembered-secret',
        rememberApiKeyOnDevice: true,
      ),
    );

    expect(storage.value, 'remembered-secret');
    expect(prefs.getBool('rememberApiKeyOnDevice'), isTrue);

    final reloaded = await repository.load();
    expect(reloaded.apiKey, 'remembered-secret');
  });
}
