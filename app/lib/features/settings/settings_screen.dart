import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/theme.dart';
import '../../data/settings_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late final TextEditingController _systemPrompt;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _baseUrl = TextEditingController(text: s.baseUrl);
    _apiKey = TextEditingController(text: s.apiKey);
    _model = TextEditingController(text: s.model);
    _systemPrompt = TextEditingController(text: s.systemPrompt);
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _systemPrompt.dispose();
    super.dispose();
  }

  void _update(AppSettings Function(AppSettings) change) {
    ref.read(settingsProvider.notifier).update(change);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final remote = s.provider == ProviderKind.remote;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _Label('Provider'),
              SegmentedButton<ProviderKind>(
                segments: const [
                  ButtonSegment(value: ProviderKind.mock, label: Text('Mock')),
                  ButtonSegment(
                    value: ProviderKind.remote,
                    label: Text('Remote'),
                  ),
                ],
                selected: {s.provider},
                onSelectionChanged: (v) =>
                    _update((s) => s.copyWith(provider: v.first)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _baseUrl,
                enabled: remote,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  helperText: 'Requests go to {base URL}/v1/chat/completions',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _update((s) => s.copyWith(baseUrl: v)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKey,
                enabled: remote,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API key (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _update((s) => s.copyWith(apiKey: v)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _model,
                decoration: const InputDecoration(
                  labelText: 'Model name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _update((s) => s.copyWith(model: v)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _systemPrompt,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'System prompt',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _update((s) => s.copyWith(systemPrompt: v)),
              ),
              const SizedBox(height: 16),
              _Label('Temperature: ${s.temperature.toStringAsFixed(1)}'),
              Slider(
                value: s.temperature,
                min: 0,
                max: 2,
                divisions: 20,
                onChanged: (v) => _update((s) => s.copyWith(temperature: v)),
              ),
              const SizedBox(height: 8),
              const _Label('Theme'),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) =>
                    _update((s) => s.copyWith(themeMode: v.first)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
