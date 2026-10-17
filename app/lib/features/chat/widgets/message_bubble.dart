import 'package:flutter/material.dart';

import 'markdown_view.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    this.streaming = false,
  });

  final String role;
  final String content;
  final bool streaming;

  bool get _isUser => role == 'user';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              content,
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.isEmpty)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            MarkdownView(data: content),
          if (!streaming)
            IconButton(
              tooltip: 'Copy message',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              onPressed: () => copyToClipboard(context, content),
            ),
        ],
      ),
    );
  }
}
