import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/date_extensions.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';
/// Gerçek bir öğrencinin kafasını karıştıracak durumlar.
///
/// Buradaki testler "kod çalışıyor mu" diye sormuyor; "kullanıcı ne
/// anlayacak" diye soruyor. Her biri, uygulamayı bir öğrenci gibi kullanırken
/// fark edilen bir tutarsızlıktan doğdu.
void main() {
  late RitimDatabase db;
  late int matematik;
  late int carpanlar;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    matematik = await db.addSubject(name: 'Matematik', colorIndex: 1);
    carpanlar =
        await db.addTopic(subjectId: matematik, name: 'Çarpanlar ve Katlar');
    await db.addTopic(subjectId: matematik, name: 'Üslü İfadeler', position: 1);
  });
  tearDown(() => db.close());

  Future<List<TaskItem>> todayList() => db.watchTasksUpTo(today()).first;

  group('aynı konu iki kez listede', () {
    test('tekrarı bekleyen konu plana yeniden girmez', () async {
      // Öğrenci dün çalıştı, bugün tekrarı düştü. Plan kurunca aynı konuyu
      // bir kez daha görürse listede iki özdeş satır oluyor ve hangisini
      // yapacağını bilemiyor.
      await db.logStudySession(topicId: carpanlar, minutes: 40);

      await db.buildWeeklyPlan(
        weekdays: {DateTime.monday, DateTime.tuesday, DateTime.wednesday,
                   DateTime.thursday, DateTime.friday, DateTime.saturday,
                   DateTime.sunday},
        perDay: 4,
      );

      final planned = await (db.select(db.tasks)
            ..where((t) => t.source.equalsValue(TaskSource.plan)))
          .get();

      expect(
        planned.map((t) => t.topicId),
        isNot(contains(carpanlar)),
        reason: 'tekrarı bekleyen konu plana da girerse listede iki kez çıkar',
      );
    });
  });

  group('yaptığını söylemenin iki yolu', () {
    test('konuya bağlı görevi tamamlamak çalışma kaydı üretir', () async {
      // Öğrenci listede "Çarpanlar ve Katlar" görüp çalışıyor ve işaretliyor.
      // Uygulama bunu "çalıştı" saymazsa tekrar hiç planlanmıyor ve
      // uygulamanın asıl vaadi sessizce çalışmıyor.
      await db.buildWeeklyPlan(weekdays: {today().weekday}, perDay: 2);
      final task = (await todayList()).firstWhere((i) => i.topic != null);

      await db.completeTaskAsStudied(task.task.id, minutes: 30);

      final sessions = await db.select(db.studySessions).get();
      expect(sessions, hasLength(1));
      expect(sessions.single.topicId, task.topic!.id);

      final reviews = await (db.select(db.tasks)
            ..where((t) => t.source.equalsValue(TaskSource.review)))
          .get();
      expect(reviews, hasLength(1), reason: 'tekrar planlanmadı');
    });

    test('konusu olmayan görevi tamamlamak çalışma kaydı üretmez', () async {
      // "Kalem al" gibi bir iş çalışma sayılmamalı.
      final id = await db.addTask(title: 'Kalem al', dueOn: today());

      await db.setTaskDone(id, done: true);

      expect(await db.select(db.studySessions).get(), isEmpty);
    });
  });

  group('eski planın birikmesi', () {
    test('plan yenilenince geçmişte kalan yapılmamış işler temizlenir',
        () async {
      await db.buildWeeklyPlan(
        weekdays: {today().addDays(-3).weekday},
        perDay: 2,
        from: today().addDays(-3),
      );
      final eski = await (db.select(db.tasks)
            ..where((t) => t.source.equalsValue(TaskSource.plan)))
          .get();
      expect(eski, isNotEmpty);

      await db.buildWeeklyPlan(weekdays: {today().weekday}, perDay: 2);

      final gecikmis = (await todayList())
          .where((i) => i.task.source == TaskSource.plan && i.isOverdue(today()));
      expect(
        gecikmis,
        isEmpty,
        reason: 'yenilenen plan, geçmişten kalan işleri gecikmiş olarak '
            'bırakırsa öğrenci ilk gün 20 gecikmiş işle karşılaşıyor',
      );
    });
  });
}
