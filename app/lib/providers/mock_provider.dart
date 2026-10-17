import 'dart:math';

import 'chat_provider.dart';

/// Fake provider for UI development. Special prompts:
/// `/error` streams a partial reply then fails, `/long` or `/code` streams a
/// long markdown reply with code blocks.
class MockProvider implements ChatProvider {
  MockProvider({
    this.tokenDelay = const Duration(milliseconds: 35),
    Random? random,
  }) : _random = random ?? Random();

  final Duration tokenDelay;
  final Random _random;

  static final _tokenPattern = RegExp(r'\S+\s*');

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) async* {
    final lastUser = request.messages.lastWhere(
      (m) => m.role == 'user',
      orElse: () => const ChatMessage(role: 'user', content: ''),
    );
    final prompt = lastUser.content.trim().toLowerCase();

    final isError = prompt.contains('/error');
    final reply = (prompt.contains('/long') || prompt.contains('/code'))
        ? _longReply
        : _shortReply(lastUser.content);

    var tokens = _tokenPattern.allMatches(reply).map((m) => m[0]!).toList();
    if (isError) tokens = tokens.take(6).toList();

    for (final token in tokens) {
      await _wait();
      yield ChatChunk(delta: token);
    }

    if (isError) {
      yield const ChatChunk.error('Simulated provider error.');
      return;
    }
    yield const ChatChunk(finishReason: 'stop');
  }

  Future<void> _wait() {
    if (tokenDelay == Duration.zero) return Future<void>.value();
    final jitter = _random.nextInt(tokenDelay.inMilliseconds ~/ 2 + 1);
    return Future<void>.delayed(tokenDelay + Duration(milliseconds: jitter));
  }

  String _shortReply(String prompt) {
    final quoted = prompt.trim().replaceAll(RegExp(r'\s+'), ' ');
    return 'This is a **mock** reply. You said: "$quoted". '
        'Try `/long` for a long markdown answer or `/error` for a failure.';
  }

  static const _longReply = '''
# Mock markdown showcase

Here is a **long** answer with *formatting*, lists and code.

## Lists

- First item
- Second item with `inline code`
- Third item

1. Step one
2. Step two
3. Step three

## Dart

```dart
Future<int> fibonacci(int n) async {
  if (n < 2) return n;
  return await fibonacci(n - 1) + await fibonacci(n - 2);
}
```

## Python

```python
def greet(name: str) -> str:
    return f"Hello, {name}!"

print(greet("world"))
```

> Block quotes work too.

| Feature | Supported |
| ------- | --------- |
| Tables  | yes       |
| Code    | yes       |

That is the end of the mock reply.
''';
}
