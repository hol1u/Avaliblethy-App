import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'chat_provider.dart';
import 'sse_parser.dart';

/// OpenAI-compatible streaming chat completions client.
class RemoteProvider implements ChatProvider {
  RemoteProvider({
    required String baseUrl,
    this.apiKey,
    Dio? dio,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 120),
  }) : baseUrl = normalizeBaseUrl(baseUrl),
       _dio = (dio ?? Dio())..options.connectTimeout = connectTimeout;

  final String baseUrl;
  final String? apiKey;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Dio _dio;

  /// Strips trailing slashes and a trailing `/v1`, since the path is appended.
  static String normalizeBaseUrl(String url) {
    var result = url.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    if (result.endsWith('/v1')) {
      result = result.substring(0, result.length - 3);
    }
    return result;
  }

  Uri get endpoint => Uri.parse('$baseUrl/v1/chat/completions');

  @override
  Stream<ChatChunk> streamChat(ChatRequest request) {
    final cancelToken = CancelToken();
    late final StreamController<ChatChunk> controller;
    controller = StreamController<ChatChunk>(
      onListen: () => _run(request, cancelToken, controller),
      onCancel: () => cancelToken.cancel('cancelled by user'),
    );
    return controller.stream;
  }

  Future<void> _run(
    ChatRequest request,
    CancelToken cancelToken,
    StreamController<ChatChunk> controller,
  ) async {
    try {
      final key = apiKey?.trim();
      final response = await _dio.postUri<ResponseBody>(
        endpoint,
        data: {
          'model': request.model,
          'messages': [
            for (final m in request.messagesWithSystemPrompt) m.toJson(),
          ],
          'temperature': request.temperature,
          if (request.maxTokens != null) 'max_tokens': request.maxTokens,
          'stream': true,
        },
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          contentType: Headers.jsonContentType,
          headers: {
            'Accept': 'text/event-stream',
            if (key != null && key.isNotEmpty) 'Authorization': 'Bearer $key',
          },
          receiveTimeout: receiveTimeout,
        ),
      );

      await for (final data in parseSse(response.data!.stream)) {
        if (data.trim() == '[DONE]') break;
        final chunk = parseCompletionChunk(data);
        if (chunk != null) {
          controller.add(
            chunk.error == null
                ? chunk
                : ChatChunk.error(_redactSecret(chunk.error!)),
          );
        }
      }
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        controller.add(ChatChunk.error(_redactSecret(await _describe(e))));
      }
    } catch (_) {
      controller.add(ChatChunk.error('Request failed.'));
    } finally {
      await controller.close();
    }
  }

  Future<String> _describe(DioException e) async {
    final status = e.response?.statusCode;
    if (status != null) {
      var body = '';
      final data = e.response?.data;
      try {
        if (data is ResponseBody) {
          body = await utf8.decoder.bind(data.stream.cast<List<int>>()).join();
        } else if (data != null) {
          body = data.toString();
        }
      } catch (_) {}
      body = body.trim();
      if (body.length > 300) body = '${body.substring(0, 300)}…';
      body = _redactSecret(body);
      return 'HTTP $status${body.isEmpty ? '' : ': $body'}';
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => 'Request timed out.',
      _ =>
        'Connection failed: ${_redactSecret(e.message ?? e.error?.toString() ?? 'unknown error')}',
    };
  }

  String _redactSecret(String message) {
    final key = apiKey?.trim();
    return key == null || key.isEmpty
        ? message
        : message.replaceAll(key, '[redacted]');
  }
}

/// Parses one OpenAI `chat.completion.chunk` JSON payload.
ChatChunk? parseCompletionChunk(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;

  final error = decoded['error'];
  if (error != null) {
    final message = error is Map ? error['message'] : error;
    return ChatChunk.error(message?.toString() ?? 'Unknown server error');
  }

  final choices = decoded['choices'];
  if (choices is! List || choices.isEmpty) return null;
  final choice = choices.first;
  if (choice is! Map) return null;

  final delta = choice['delta'];
  final content = delta is Map ? delta['content'] : null;
  return ChatChunk(
    delta: content is String ? content : '',
    finishReason: choice['finish_reason'] as String?,
  );
}
