import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:avaliblethy_app/providers/chat_provider.dart';
import 'package:avaliblethy_app/providers/remote_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions) respond;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody sse(List<String> lines, {int status = 200}) => ResponseBody(
  Stream.fromIterable([Uint8List.fromList(utf8.encode(lines.join('\n')))]),
  status,
  headers: {
    Headers.contentTypeHeader: ['text/event-stream'],
  },
);

String delta(String text) =>
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': text},
          'finish_reason': null,
        },
      ],
    })}\n';

const request = ChatRequest(
  messages: [ChatMessage(role: 'user', content: 'hi')],
  model: 'm',
  systemPrompt: 'be brief',
  maxTokens: 10,
);

void main() {
  test('normalizeBaseUrl', () {
    expect(RemoteProvider.normalizeBaseUrl('http://h:1/'), 'http://h:1');
    expect(RemoteProvider.normalizeBaseUrl('http://h:1/v1/'), 'http://h:1');
  });

  test('streams deltas, sends OpenAI request and stops at [DONE]', () async {
    final adapter = FakeAdapter(
      (_) => sse([
        delta('Hel'),
        delta('lo'),
        'data: [DONE]\n',
        delta('ignored'),
        '',
      ]),
    );
    final provider = RemoteProvider(
      baseUrl: 'http://example.test/',
      apiKey: 'secret',
      dio: Dio()..httpClientAdapter = adapter,
    );

    final chunks = await provider.streamChat(request).toList();

    expect(chunks.map((c) => c.delta).join(), 'Hello');
    final sent = adapter.last!;
    expect(sent.uri.toString(), 'http://example.test/v1/chat/completions');
    expect(sent.headers['Authorization'], 'Bearer secret');
    final body = sent.data as Map<String, dynamic>;
    expect(body['stream'], true);
    expect(body['max_tokens'], 10);
    expect((body['messages'] as List).first, {
      'role': 'system',
      'content': 'be brief',
    });
  });

  test('reports HTTP errors as an error chunk', () async {
    final provider = RemoteProvider(
      baseUrl: 'http://example.test',
      dio: Dio()
        ..httpClientAdapter = FakeAdapter(
          (_) => ResponseBody.fromString('{"error":"nope"}', 401),
        ),
    );
    final chunks = await provider.streamChat(request).toList();
    expect(chunks.single.error, contains('401'));
  });

  test('redacts the API key from server errors', () async {
    const secret = 'sensitive-api-token';
    final provider = RemoteProvider(
      baseUrl: 'http://example.test',
      apiKey: '  $secret  ',
      dio: Dio()
        ..httpClientAdapter = FakeAdapter(
          (_) =>
              ResponseBody.fromString('{"error":"invalid key: $secret"}', 401),
        ),
    );

    final chunks = await provider.streamChat(request).toList();

    expect(chunks.single.error, isNot(contains(secret)));
  });

  test('parseCompletionChunk', () {
    expect(parseCompletionChunk('not json'), isNull);
    expect(parseCompletionChunk('{"choices":[]}'), isNull);
    final c = parseCompletionChunk(
      '{"choices":[{"delta":{},"finish_reason":"stop"}]}',
    )!;
    expect(c.finishReason, 'stop');
    expect(c.delta, '');
    expect(parseCompletionChunk('{"error":{"message":"bad"}}')!.error, 'bad');
  });
}
