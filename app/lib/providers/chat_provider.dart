/// A single message sent to the model.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  /// `system`, `user` or `assistant`.
  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class ChatRequest {
  const ChatRequest({
    required this.messages,
    required this.model,
    this.temperature = 0.7,
    this.maxTokens,
    this.systemPrompt,
  });

  final List<ChatMessage> messages;
  final String model;
  final double temperature;
  final int? maxTokens;
  final String? systemPrompt;

  /// Messages with the system prompt (if any) prepended.
  List<ChatMessage> get messagesWithSystemPrompt => [
    if (systemPrompt != null && systemPrompt!.trim().isNotEmpty)
      ChatMessage(role: 'system', content: systemPrompt!),
    ...messages,
  ];
}

class ChatChunk {
  const ChatChunk({this.delta = '', this.finishReason, this.error});

  const ChatChunk.error(String message) : this(error: message);

  final String delta;
  final String? finishReason;
  final String? error;
}

abstract class ChatProvider {
  /// Streams the reply. Cancelling the stream subscription aborts generation.
  Stream<ChatChunk> streamChat(ChatRequest request);
}
