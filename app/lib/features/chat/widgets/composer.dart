import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.generating,
    required this.onSend,
    required this.onStop,
  });

  final bool generating;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.generating) return;
    _controller.clear();
    widget.onSend(text);
  }

  // Enter sends, Shift+Enter inserts a newline.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter || event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    final composing = _controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    _submit();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Focus(
              onKeyEvent: _onKey,
              child: TextField(
                key: const Key('composer-field'),
                controller: _controller,
                minLines: 1,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.generating)
            IconButton.filled(
              key: const Key('stop-button'),
              tooltip: 'Stop',
              icon: const Icon(Icons.stop),
              onPressed: widget.onStop,
            )
          else
            IconButton.filled(
              key: const Key('send-button'),
              tooltip: 'Send',
              icon: const Icon(Icons.arrow_upward),
              onPressed: _submit,
            ),
        ],
      ),
    );
  }
}
