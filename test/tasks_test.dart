import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/date_extensions.dart';
import 'package:ritim/data/db/database.dart';
/// Bugün listesinin kuralları: neyin görüneceği, neyin görünmeyeceği.
void main() {
  late RitimDatabase db;

  setUp(() => db = RitimDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<TaskItem>> todayList() => db.watchTasksUpTo(today()).first;

  test('bugüne ve geçmişe planlanan işler listede, gelecek olanlar değil',
      () async {
    await db.addTask(title: 'Dünden kalan', dueOn: today().addDays(-1));
    await db.addTask(title: 'Bugünkü', dueOn: today());
    await db.addTask(title: 'Yarınki', dueOn: today().addDays(1));

    final items = await todayList();

    expect(items.map((i) => i.task.title), ['Dünden kalan', 'Bugünkü']);
  });

  test('geçmişten kalan tamamlanmamış iş gecikmiş sayılır', () async {
    await db.addTask(title: 'Dünden kalan', dueOn: today().addDays(-2));
    await db.addTask(title: 'Bugünkü', dueOn: today());

    final items = await todayList();

    expect(items.first.isOverdue(today()), isTrue);
    expect(items.last.isOverdue(today()), isFalse);
  });

  test('tamamlama zaman damgası yazar, geri alma temizler', () async {
    final id = await db.addTask(title: 'Fiilimsiler', dueOn: today());

    await db.setTaskDone(id, done: true);
    var task = (await todayList()).single.task;
    expect(task.done, isTrue);
    expect(task.completedAt, isNotNull);

    await db.setTaskDone(id, done: false);
    task = (await todayList()).single.task;
    expect(task.done, isFalse);
    // Damga temizlenmezse geri alınan görev "bugün tamamlandı" filtresine
    // takılıp listede yanlış yerde kalırdı.
    expect(task.completedAt, isNull);
  });

  test('bugün tamamlanan iş listede kalır, dün tamamlanan kalmaz', () async {
    final bugun = await db.addTask(title: 'Bugün biten', dueOn: today());
    final dun = await db.addTask(title: 'Dün biten', dueOn: today().addDays(-1));

    await db.setTaskDone(bugun, done: true);
    await db.setTaskDone(dun, done: true);
    // Dün tamamlanmış gibi göstermek için damgayı geriye alıyoruz.
    await (db.update(db.tasks)..where((t) => t.id.equals(dun))).write(
      TasksCompanion(completedAt: Value(today().addDays(-1))),
    );

    final items = await todayList();

    expect(items.map((i) => i.task.title), ['Bugün biten']);
  });

  test('erteleme görevi bir gün ileri atar ve sayacı artırır', () async {
    final id = await db.addTask(title: 'Üslü Sayılar', dueOn: today());

    await db.snoozeTask(id);

    expect(await todayList(), isEmpty);
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(id)))
        .getSingle();
    expect(task.dueOn, today().addDays(1));
    expect(task.snoozeCount, 1);
  });

  test('görev, konusu ve dersiyle birlikte okunur', () async {
    final subjectId = await db.addSubject(name: 'Matematik', colorIndex: 1);
    final topicId = await db.addTopic(subjectId: subjectId, name: 'Çarpanlar');
    await db.addTask(title: 'Test çöz', dueOn: today(), topicId: topicId);

    final item = (await todayList()).single;

    expect(item.topic?.name, 'Çarpanlar');
    expect(item.subject?.name, 'Matematik');
    expect(item.subject?.colorIndex, 1);
  });

  test('ders silinince ona bağlı görev de gider', () async {
    final subjectId = await db.addSubject(name: 'Matematik');
    final topicId = await db.addTopic(subjectId: subjectId, name: 'Çarpanlar');
    await db.addTask(title: 'Test çöz', dueOn: today(), topicId: topicId);

    await (db.delete(db.subjects)..where((s) => s.id.equals(subjectId))).go();

    expect(await todayList(), isEmpty);
  });
}
