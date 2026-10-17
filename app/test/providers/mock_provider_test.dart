import 'package:avaliblethy_app/providers/chat_provider.dart';
import 'package:avaliblethy_app/providers/mock_provider.dart';
import 'package:flutter_test/flutter_test.dart';

ChatRequest request(String text) => ChatRequest(
  messages: [ChatMessage(role: 'user', content: text)],
  model: 'mock',
);

void main() {
  final provider = MockProvider(tokenDelay: Duration.zero);

  test('streams reply token by token and finishes with stop', () async {
    final chunks = await provider.streamChat(request('hello')).toList();
    expect(chunks.length, greaterThan(5));
    expect(chunks.last.finishReason, 'stop');
    final text = chunks.map((c) => c.delta).join();
    expect(text, contains('hello'));
    expect(chunks.every((c) => c.error == null), isTrue);
  });

  test('/long streams markdown with code blocks', () async {
    final chunks = await provider.streamChat(request('/long')).toList();
    final text = chunks.map((c) => c.delta).join();
    expect(text, contains('```dart'));
    expect(text, contains('```python'));
  });

  test('/error emits a partial reply then an error', () async {
    final chunks = await provider.streamChat(request('/error')).toList();
    expect(chunks.last.error, isNotNull);
    expect(chunks.where((c) => c.delta.isNotEmpty), isNotEmpty);
  });

  test('cancelling the subscription stops the stream', () async {
    final slow = MockProvider(tokenDelay: const Duration(milliseconds: 5));
    var count = 0;
    final sub = slow.streamChat(request('/long')).listen((_) => count++);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await sub.cancel();
    final atCancel = count;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(count, atCancel);
    expect(atCancel, lessThan(50));
  });
}
