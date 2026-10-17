import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/conversation_repository.dart';
import 'data/database.dart';
import 'data/settings_repository.dart';
import 'providers/chat_provider.dart';
import 'providers/mock_provider.dart';
import 'providers/remote_provider.dart';

/// Must be overridden in `ProviderScope` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// Must be overridden in `ProviderScope` with an opened database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider not overridden'),
);

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => ConversationRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> update(AppSettings Function(AppSettings) change) {
    state = change(state);
    return ref.read(settingsRepositoryProvider).save(state);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// The active provider, chosen in Settings.
final chatProviderProvider = Provider<ChatProvider>((ref) {
  final s = ref.watch(settingsProvider);
  return switch (s.provider) {
    ProviderKind.mock => MockProvider(),
    ProviderKind.remote => RemoteProvider(baseUrl: s.baseUrl, apiKey: s.apiKey),
  };
});

final conversationsProvider = StreamProvider<List<Conversation>>(
  (ref) => ref.watch(conversationRepositoryProvider).watchConversations(),
);

final messagesProvider = StreamProvider.family<List<Message>, int>(
  (ref, id) => ref.watch(conversationRepositoryProvider).watchMessages(id),
);
