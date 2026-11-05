import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/providers.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';
import 'package:ritim/features/subjects/topic_list_screen.dart';

/// Konu listesinin hızlı hareketleri: sağa kaydırıp bitirme ve çoklu seçim.
void main() {
  late RitimDatabase db;
  late int subjectId;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    subjectId = await db.addSubject(name: 'Matematik', colorIndex: 1);
    for (var i = 0; i < 3; i++) {
      await db.addTopic(subjectId: subjectId, name: 'Konu $i', position: i);
    }
  });
  tearDown(() => db.close());

  // pumpAndSettle drift akışlarıyla oturmuyor; sınırlı sayıda kare yetiyor.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: TopicListScreen(subjectId: subjectId, subjectName: 'Matematik'),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<List<Topic>> topics(WidgetTester tester) async =>
      await tester.runAsync(() => db.select(db.topics).get()) ?? [];

  testWidgets('sağa kaydırma bitirir, Geri al önceki durumu geri yazar', (
    tester,
  ) async {
    final first = (await topics(tester)).first;
    await tester.runAsync(
      () => db.setTopicStatus(first.id, TopicStatus.inProgress),
    );
    await pump(tester);

    await tester.drag(find.text('Konu 0'), const Offset(500, 0));
    await settle(tester);
    expect((await topics(tester)).first.status, TopicStatus.done);
    expect(find.text('Konu 0'), findsOneWidget, reason: 'satır yerinde kalır');

    await tester.tap(find.widgetWithText(SnackBarAction, 'Geri al'));
    await settle(tester);
    expect(
      (await topics(tester)).first.status,
      TopicStatus.inProgress,
      reason: '"başlamadın"a değil, önceki duruma dönmeli',
    );

    await unmount(tester);
  });

  testWidgets('uzun basma seçimi açar; seçilenler bitirilir ve silinir', (
    tester,
  ) async {
    await pump(tester);

    await tester.longPress(find.text('Konu 0'));
    await settle(tester);
    expect(find.text('1 seçildi'), findsOneWidget);

    await tester.tap(find.text('Konu 1'));
    await settle(tester);
    expect(find.text('2 seçildi'), findsOneWidget);

    await tester.tap(find.byTooltip('Bitti olarak işaretle'));
    await settle(tester);
    expect(
      (await topics(tester)).map((t) => t.status),
      [TopicStatus.done, TopicStatus.done, TopicStatus.notStarted],
    );
    expect(find.text('Matematik'), findsOneWidget, reason: 'seçim kapanır');

    await tester.longPress(find.text('Konu 2'));
    await settle(tester);
    await tester.tap(find.byTooltip('Sil'));
    await settle(tester);
    expect(find.text('Konuyu sil'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await settle(tester);
    expect(await topics(tester), hasLength(2));

    await unmount(tester);
  });
}
