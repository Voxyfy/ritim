import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/date_extensions.dart';
import 'package:ritim/core/providers.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/features/today/widgets/add_task_sheet.dart';

/// Hızlı ekleme sayfası: tek satırdan gün, ders ve konuyla kayıt.
void main() {
  late RitimDatabase db;
  late int turev;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    final mat = await db.addSubject(
      name: 'Matematik',
      colorIndex: 1,
      position: 0,
    );
    await db.addTopic(subjectId: mat, name: 'Limit', position: 0);
    turev = await db.addTopic(subjectId: mat, name: 'Türev', position: 1);
  });
  tearDown(() => db.close());

  // Odaklı metin alanının imleci yüzünden pumpAndSettle hiç oturmuyor.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<List<Task>> tasks(WidgetTester tester) async =>
      await tester.runAsync(() => db.select(db.tasks).get()) ?? [];

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: AddTaskSheet())),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('"yarın mat türev" rozet gösterir, Enter konuyla kaydeder', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(find.byType(TextField), 'yarın mat türev');
    await settle(tester);

    expect(find.text('Türev'), findsOneWidget);
    expect(find.text('Yarın'), findsNWidgets(2)); // çözümleme + gün rozeti

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    final saved = await tasks(tester);
    expect(saved, hasLength(1));
    expect(saved.single.title, 'Türev');
    expect(saved.single.topicId, turev);
    expect(saved.single.dueOn, today().addDays(1));
    await unmount(tester);
  });

  testWidgets('rozete dokunmak yorumu kaldırır, kelime başlığa döner', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(find.byType(TextField), 'yarın deneme çöz');
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Yarın yorumunu kaldır'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await settle(tester);

    final saved = await tasks(tester);
    expect(saved.single.title, 'Yarın deneme çöz');
    expect(saved.single.dueOn, today());
    expect(saved.single.topicId, isNull);
    await unmount(tester);
  });
}
