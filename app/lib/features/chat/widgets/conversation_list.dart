import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_providers.dart';
import '../../../data/database.dart';
import '../chat_controller.dart';

class ConversationList extends ConsumerWidget {
  const ConversationList({super.key, this.onNavigate});

  /// Called after the user picks an item (used to close the mobile drawer).
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final selected = ref.watch(selectedConversationProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('new-chat'),
                icon: const Icon(Icons.add),
                label: const Text('New chat'),
                onPressed: () {
                  ref.read(selectedConversationProvider.notifier).select(null);
                  onNavigate?.call();
                },
              ),
            ),
          ),
          Expanded(
            child: conversations.when(
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No conversations yet'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => _Tile(
                        conversation: items[i],
                        selected: items[i].id == selected,
                        onNavigate: onNavigate,
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              onNavigate?.call();
              context.push('/settings');
            },
          ),
        ],
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({
    required this.conversation,
    required this.selected,
    this.onNavigate,
  });

  final Conversation conversation;
  final bool selected;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      selected: selected,
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        ref.read(selectedConversationProvider.notifier).select(conversation.id);
        onNavigate?.call();
      },
      trailing: PopupMenuButton<String>(
        tooltip: 'Conversation options',
        onSelected: (value) async {
          if (value == 'rename') {
            await _rename(context, ref);
          } else {
            await _delete(context, ref);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.trim().isEmpty) return;
    await ref
        .read(conversationRepositoryProvider)
        .renameConversation(conversation.id, title.trim());
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text('"${conversation.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final chat = ref.read(chatControllerProvider);
    if (chat.generating && chat.conversationId == conversation.id) {
      ref.read(chatControllerProvider.notifier).stop();
    }
    if (ref.read(selectedConversationProvider) == conversation.id) {
      ref.read(selectedConversationProvider.notifier).select(null);
    }
    await ref
        .read(conversationRepositoryProvider)
        .deleteConversation(conversation.id);
  }
}
