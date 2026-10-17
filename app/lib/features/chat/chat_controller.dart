import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../providers/chat_provider.dart';

/// The conversation shown in the chat pane; `null` means a new, unsaved chat.
class SelectedConversation extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedConversationProvider =
    NotifierProvider<SelectedConversation, int?>(SelectedConversation.new);

class ChatState {
  const ChatState({
    this.conversationId,
    this.streamingText = '',
    this.generating = false,
    this.error,
  });

  /// Conversation that `streamingText` / `error` belong to.
  final int? conversationId;
  final String streamingText;
  final bool generating;
  final String? error;
}

class ChatController extends Notifier<ChatState> {
  StreamSubscription<ChatChunk>? _subscription;
  Completer<void>? _done;

  @override
  ChatState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const ChatState();
  }

  static String titleFrom(String text) {
    final line = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return line.length <= 40 ? line : '${line.substring(0, 40)}…';
  }

  Future<void> send(String text) async {
    text = text.trim();
    if (text.isEmpty || state.generating) return;

    final repo = ref.read(conversationRepositoryProvider);
    final settings = ref.read(settingsProvider);
    final provider = ref.read(chatProviderProvider);
    final selected = ref.read(selectedConversationProvider.notifier);

    var id = ref.read(selectedConversationProvider);
    if (id == null) {
      id = await repo.createConversation(titleFrom(text));
      selected.select(id);
    }
    await repo.addMessage(id, 'user', text);
    final history = await repo.getMessages(id);

    final request = ChatRequest(
      messages: [
        for (final m in history) ChatMessage(role: m.role, content: m.content),
      ],
      model: settings.model,
      temperature: settings.temperature,
      systemPrompt: settings.systemPrompt,
    );

    final buffer = StringBuffer();
    String? error;
    final done = _done = Completer<void>();
    state = ChatState(conversationId: id, generating: true);

    _subscription = provider
        .streamChat(request)
        .listen(
          (chunk) {
            if (chunk.delta.isNotEmpty) {
              buffer.write(chunk.delta);
              state = ChatState(
                conversationId: id,
                streamingText: buffer.toString(),
                generating: true,
              );
            }
            if (chunk.error != null) error = chunk.error;
          },
          onError: (Object e) => error = e.toString(),
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );

    await done.future;
    _subscription = null;

    // Partial text is kept after Stop or an error.
    if (buffer.isNotEmpty) {
      await repo.addMessage(id, 'assistant', buffer.toString());
    }
    state = ChatState(conversationId: id, error: error);
  }

  /// Cancels generation; the partial reply is kept.
  void stop() {
    _subscription?.cancel();
    final done = _done;
    if (done != null && !done.isCompleted) done.complete();
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
