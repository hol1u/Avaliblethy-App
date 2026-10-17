import 'package:avaliblethy_app/app.dart';
import 'package:avaliblethy_app/app_providers.dart';
import 'package:avaliblethy_app/data/database.dart';
import 'package:avaliblethy_app/providers/mock_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('sends a message and renders the streamed mock reply', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          chatProviderProvider.overrideWithValue(
            MockProvider(tokenDelay: const Duration(milliseconds: 10)),
          ),
        ],
        child: const AvaliblethyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('composer-field')), 'ping');
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Mid-stream: Stop button visible.
    expect(find.byKey(const Key('stop-button')), findsOneWidget);

    for (
      var i = 0;
      i < 200 && find.byKey(const Key('stop-button')).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('send-button')), findsOneWidget);
    expect(
      find.textContaining('This is a mock reply', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('ping'), findsWidgets);

    // Unmount so drift's cleanup timers can run before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
