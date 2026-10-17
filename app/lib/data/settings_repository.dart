import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ProviderKind { mock, remote }

class AppSettings {
  const AppSettings({
    this.provider = ProviderKind.mock,
    this.baseUrl = 'http://localhost:8080',
    this.apiKey = '',
    this.model = 'default',
    this.systemPrompt = '',
    this.temperature = 0.7,
    this.themeMode = ThemeMode.system,
  });

  final ProviderKind provider;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String systemPrompt;
  final double temperature;
  final ThemeMode themeMode;

  AppSettings copyWith({
    ProviderKind? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? systemPrompt,
    double? temperature,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  AppSettings load() {
    const d = AppSettings();
    return AppSettings(
      provider: _enum(
        ProviderKind.values,
        _prefs.getString('provider'),
        d.provider,
      ),
      baseUrl: _prefs.getString('baseUrl') ?? d.baseUrl,
      apiKey: _prefs.getString('apiKey') ?? d.apiKey,
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
    await _prefs.setString('apiKey', s.apiKey);
    await _prefs.setString('model', s.model);
    await _prefs.setString('systemPrompt', s.systemPrompt);
    await _prefs.setDouble('temperature', s.temperature);
    await _prefs.setString('themeMode', s.themeMode.name);
  }

  static T _enum<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
