import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/theme.dart';
import 'chat_controller.dart';
import 'widgets/composer.dart';
import 'widgets/conversation_list.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final selected = ref.watch(selectedConversationProvider);
    final conversations = ref.watch(conversationsProvider).value;
    final title =
        conversations
            ?.where((c) => c.id == selected)
            .map((c) => c.title)
            .firstOrNull ??
        'New chat';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        automaticallyImplyLeading: !wide,
      ),
      drawer: wide
          ? null
          : Drawer(
              child: Builder(
                builder: (context) => ConversationList(
                  onNavigate: () => Scaffold.of(context).closeDrawer(),
                ),
              ),
            ),
      body: wide
          ? Row(
              children: [
                const SizedBox(width: 300, child: ConversationList()),
                const VerticalDivider(width: 1),
                Expanded(child: _ChatPane(conversationId: selected)),
              ],
            )
          : _ChatPane(conversationId: selected),
    );
  }
}

class _ChatPane extends ConsumerWidget {
  const _ChatPane({required this.conversationId});

  final int? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    final messages = conversationId == null
        ? const <(String, String)>[]
        : [
            for (final m
                in ref.watch(messagesProvider(conversationId!)).value ?? [])
              (m.role, m.content),
          ];

    final showLive =
        chat.conversationId == conversationId &&
        conversationId != null &&
        (chat.generating || chat.error != null);

    // Newest first, because the list is reversed to stay pinned to the bottom.
    final items = <Widget>[
      if (showLive && chat.error != null) _ErrorBanner(message: chat.error!),
      if (showLive && chat.generating)
        MessageBubble(
          key: const Key('streaming-message'),
          role: 'assistant',
          content: chat.streamingText,
          streaming: true,
        ),
      for (final (role, content) in messages.reversed)
        MessageBubble(role: role, content: content),
    ];

    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Start a conversation'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kMaxContentWidth,
                    ),
                    child: ListView(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: items,
                    ),
                  ),
                ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Composer(
              generating: chat.generating,
              onSend: (text) =>
                  ref.read(chatControllerProvider.notifier).send(text),
              onStop: () => ref.read(chatControllerProvider.notifier).stop(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
