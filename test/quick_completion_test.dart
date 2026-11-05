import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';

/// Bugün ekranındaki tek dokunuşla kaydın "Geri al"ı: geri alınan tamamlama
/// veritabanında iz bırakmamalı. Yarım geri alma (kayıt silinip tekrar ileri
/// tarihte kalırsa) öğrencinin tekrar merdivenini sessizce kaydırırdı.
void main() {
  late RitimDatabase db;
  late int topicId;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    final subjectId = await db.addSubject(name: 'Matematik', colorIndex: 1);
    topicId = await db.addTopic(subjectId: subjectId, name: 'Üslü İfadeler');
  });
  tearDown(() => db.close());

  // Liste listesi: `expect` iç içe listeleri derin karşılaştırıyor.
  Future<List<List<Object>>> dump() async => [
    await db.select(db.tasks).get(),
    await db.select(db.topics).get(),
    await db.select(db.studySessions).get(),
  ];
  List<Task> tasksOf(List<List<Object>> d) => d[0].cast<Task>();

  test(
    'bekleyen tekrar yokken tamamla + geri al her şeyi eski hâline döndürür',
    () async {
      final taskId = await db.addTask(
        title: 'Üslü İfadeler',
        dueOn: DateTime.now(),
        topicId: topicId,
        source: TaskSource.plan,
      );
      final before = await dump();

      final snapshot = await db.completeTaskAsStudied(taskId, minutes: 30);
      expect(snapshot, isNotNull);
      final after = await dump();
      expect(after[2], hasLength(1));
      expect(
        tasksOf(after).where((t) => t.source == TaskSource.review),
        hasLength(1),
      );
      expect(tasksOf(after).firstWhere((t) => t.id == taskId).done, isTrue);

      await db.undoQuickCompletion(snapshot!);
      expect(await dump(), before);
    },
  );

  test(
    'bekleyen tekrar varken tamamla + geri al tekrarın tarihini de geri alır',
    () async {
      await db.logStudySession(topicId: topicId, minutes: 20);
      // Tarihleri bilerek eskiye çekiyoruz: aynı gün yeniden planlanan tekrar
      // aynı tarihe düşer ve geri almanın tarihi düzelttiği görünmezdi.
      await (db.update(db.tasks)
            ..where((t) => t.source.equalsValue(TaskSource.review)))
          .write(TasksCompanion(dueOn: Value(DateTime(2020, 1, 5))));
      await (db.update(db.topics)..where((t) => t.id.equals(topicId))).write(
        TopicsCompanion(lastStudiedAt: Value(DateTime(2020, 1, 1))),
      );

      final taskId = await db.addTask(
        title: 'Üslü İfadeler',
        dueOn: DateTime.now(),
        topicId: topicId,
        source: TaskSource.plan,
      );
      final before = await dump();

      final snapshot = await db.completeTaskAsStudied(taskId, minutes: 45);
      final after = await dump();
      expect(after, isNot(before));
      expect(
        snapshot!.createdTaskIds,
        isEmpty,
        reason: 'tekrar yeniden kurulmamalı',
      );

      await db.undoQuickCompletion(snapshot);
      expect(await dump(), before);
    },
  );

  test(
    'tekrar görevinin kendisini tamamla + geri al zinciri geri sarar',
    () async {
      await db.logStudySession(topicId: topicId, minutes: 20);
      final review = (await db.select(db.tasks).get()).singleWhere(
        (t) => t.source == TaskSource.review,
      );
      final before = await dump();

      final snapshot = await db.completeTaskAsStudied(review.id, minutes: 15);
      expect(snapshot!.createdTaskIds, hasLength(1), reason: 'sıradaki tekrar');

      await db.undoQuickCompletion(snapshot);
      expect(await dump(), before);
    },
  );

  test('konusuz görev yalnızca kapanır ve geri alınca açılır', () async {
    final taskId = await db.addTask(title: 'Kalem al', dueOn: DateTime.now());
    final before = await dump();

    final snapshot = await db.completeTaskAsStudied(taskId, minutes: 15);
    expect((await dump())[2], isEmpty);

    await db.undoQuickCompletion(snapshot!);
    expect(await dump(), before);
  });
}
