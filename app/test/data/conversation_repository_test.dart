import 'package:avaliblethy_app/data/conversation_repository.dart';
import 'package:avaliblethy_app/data/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ConversationRepository repo;
  var tick = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tick = 0;
    repo = ConversationRepository(
      db,
      clock: () => DateTime(2026).add(Duration(seconds: tick++)),
    );
  });

  tearDown(() => db.close());

  test('creates conversations, newest activity first', () async {
    final a = await repo.createConversation('A');
    final b = await repo.createConversation('B');
    expect((await repo.watchConversations().first).map((c) => c.id), [b, a]);

    await repo.addMessage(a, 'user', 'bump');
    expect((await repo.watchConversations().first).map((c) => c.id), [a, b]);
  });

  test('stores messages in order per conversation', () async {
    final a = await repo.createConversation('A');
    final b = await repo.createConversation('B');
    await repo.addMessage(a, 'user', 'q');
    await repo.addMessage(a, 'assistant', 'r');
    await repo.addMessage(b, 'user', 'other');

    final messages = await repo.getMessages(a);
    expect(messages.map((m) => (m.role, m.content)), [
      ('user', 'q'),
      ('assistant', 'r'),
    ]);
  });

  test('renames a conversation', () async {
    final a = await repo.createConversation('A');
    await repo.renameConversation(a, 'Renamed');
    expect((await repo.watchConversations().first).single.title, 'Renamed');
  });

  test('delete removes the conversation and its messages only', () async {
    final a = await repo.createConversation('A');
    final b = await repo.createConversation('B');
    await repo.addMessage(a, 'user', 'x');
    await repo.addMessage(b, 'user', 'y');

    await repo.deleteConversation(a);

    expect((await repo.watchConversations().first).map((c) => c.id), [b]);
    expect(await repo.getMessages(a), isEmpty);
    expect(await repo.getMessages(b), hasLength(1));
  });
}
