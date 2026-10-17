import 'package:drift/drift.dart';

import 'database.dart';

class ConversationRepository {
  ConversationRepository(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Stream<List<Conversation>> watchConversations() {
    return (_db.select(_db.conversations)..orderBy([
          (c) => OrderingTerm.desc(c.updatedAt),
          (c) => OrderingTerm.desc(c.id),
        ]))
        .watch();
  }

  Future<int> createConversation(String title) {
    final now = _now();
    return _db
        .into(_db.conversations)
        .insert(
          ConversationsCompanion.insert(
            title: title,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> renameConversation(int id, String title) {
    return (_db.update(_db.conversations)..where((c) => c.id.equals(id))).write(
      ConversationsCompanion(title: Value(title)),
    );
  }

  Future<void> deleteConversation(int id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.messages,
      )..where((m) => m.conversationId.equals(id))).go();
      await (_db.delete(_db.conversations)..where((c) => c.id.equals(id))).go();
    });
  }

  Stream<List<Message>> watchMessages(int conversationId) {
    return _messagesQuery(conversationId).watch();
  }

  Future<List<Message>> getMessages(int conversationId) {
    return _messagesQuery(conversationId).get();
  }

  Future<int> addMessage(int conversationId, String role, String content) {
    return _db.transaction(() async {
      final now = _now();
      final id = await _db
          .into(_db.messages)
          .insert(
            MessagesCompanion.insert(
              conversationId: conversationId,
              role: role,
              content: content,
              createdAt: now,
            ),
          );
      await (_db.update(_db.conversations)
            ..where((c) => c.id.equals(conversationId)))
          .write(ConversationsCompanion(updatedAt: Value(now)));
      return id;
    });
  }

  SimpleSelectStatement<$MessagesTable, Message> _messagesQuery(int id) {
    return _db.select(_db.messages)
      ..where((m) => m.conversationId.equals(id))
      ..orderBy([(m) => OrderingTerm.asc(m.id)]);
  }
}
