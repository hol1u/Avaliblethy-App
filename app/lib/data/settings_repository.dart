import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_key_storage.dart';

enum ProviderKind { mock, remote }

class AppSettings {
  const AppSettings({
    this.provider = ProviderKind.mock,
    this.baseUrl = 'http://localhost:8080',
    this.apiKey = '',
    this.rememberApiKeyOnDevice = false,
    this.model = 'default',
    this.systemPrompt = '',
    this.temperature = 0.7,
    this.themeMode = ThemeMode.system,
  });

  final ProviderKind provider;
  final String baseUrl;
  final String apiKey;
  final bool rememberApiKeyOnDevice;
  final String model;
  final String systemPrompt;
  final double temperature;
  final ThemeMode themeMode;

  AppSettings copyWith({
    ProviderKind? provider,
    String? baseUrl,
    String? apiKey,
    bool? rememberApiKeyOnDevice,
    String? model,
    String? systemPrompt,
    double? temperature,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      rememberApiKeyOnDevice:
          rememberApiKeyOnDevice ?? this.rememberApiKeyOnDevice,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsRepository {
  SettingsRepository(this._prefs, this._apiKeyStorage, {required this.isWeb});

  final SharedPreferences _prefs;
  final ApiKeyStorage _apiKeyStorage;
  final bool isWeb;

  Future<AppSettings> load() async {
    const d = AppSettings();
    final rememberApiKeyOnDevice =
        _prefs.getBool('rememberApiKeyOnDevice') ?? false;
    final storedApiKey = isWeb && !rememberApiKeyOnDevice
        ? null
        : await _apiKeyStorage.read();
    final legacyApiKey = _prefs.getString('apiKey');
    final apiKey = storedApiKey ?? legacyApiKey ?? d.apiKey;

    if (legacyApiKey != null) {
      if (storedApiKey == null &&
          legacyApiKey.isNotEmpty &&
          (!isWeb || rememberApiKeyOnDevice)) {
        await _apiKeyStorage.write(legacyApiKey);
      }
      await _prefs.remove('apiKey');
    }
    if (isWeb && !rememberApiKeyOnDevice) {
      await _apiKeyStorage.delete();
    }

    return AppSettings(
      provider: _enum(
        ProviderKind.values,
        _prefs.getString('provider'),
        d.provider,
      ),
      baseUrl: _prefs.getString('baseUrl') ?? d.baseUrl,
      apiKey: apiKey,
      rememberApiKeyOnDevice: rememberApiKeyOnDevice,
      model: _prefs.getString('model') ?? d.model,
      systemPrompt: _prefs.getString('systemPrompt') ?? d.systemPrompt,
      temperature: _prefs.getDouble('temperature') ?? d.temperature,
      themeMode: _enum(
        ThemeMode.values,
        _prefs.getString('themeMode'),
        d.themeMode,
      ),
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setString('provider', s.provider.name);
    await _prefs.setString('baseUrl', s.baseUrl);
    await _prefs.setBool('rememberApiKeyOnDevice', s.rememberApiKeyOnDevice);
    await _prefs.setString('model', s.model);
    await _prefs.setString('systemPrompt', s.systemPrompt);
    await _prefs.setDouble('temperature', s.temperature);
    await _prefs.setString('themeMode', s.themeMode.name);

    if (s.apiKey.isEmpty || (isWeb && !s.rememberApiKeyOnDevice)) {
      await _apiKeyStorage.delete();
    } else {
      await _apiKeyStorage.write(s.apiKey);
    }
  }

  static T _enum<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
