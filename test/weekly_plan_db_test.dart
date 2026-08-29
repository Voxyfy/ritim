import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/date_extensions.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';
/// Haftalık planın veritabanı tarafı: üretim, yenileme ve neyin korunduğu.
void main() {
  late RitimDatabase db;
  late int matematik;
  late int turkce;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    matematik = await db.addSubject(name: 'Matematik', colorIndex: 1);
    turkce = await db.addSubject(name: 'Türkçe', colorIndex: 0);
    for (var i = 0; i < 4; i++) {
      await db.addTopic(subjectId: matematik, name: 'Mat $i', position: i);
      await db.addTopic(subjectId: turkce, name: 'Tur $i', position: i);
    }
  });
  tearDown(() => db.close());

  Future<List<Task>> planTasks() => (db.select(db.tasks)
        ..where((t) => t.source.equalsValue(TaskSource.plan))
        ..orderBy([(t) => OrderingTerm(expression: t.id)]))
      .get();

  /// Testin haftanın hangi gününde koştuğuna bağlı kalmamak için sabit bir
  /// pazartesiden başlıyoruz.
  final pazartesi = DateTime(2026, 8, 31);

  test('plan görevleri konu adıyla ve plan kaynağıyla oluşur', () async {
    final count = await db.buildWeeklyPlan(
      weekdays: {DateTime.monday, DateTime.tuesday},
      perDay: 2,
      from: pazartesi,
    );

    final tasks = await planTasks();
    expect(count, 4);
    expect(tasks, hasLength(4));
    expect(tasks.first.source, TaskSource.plan);
    expect(tasks.first.topicId, isNotNull);
    expect(tasks.map((t) => t.title), contains('Mat 0'));
  });

  test('bitmiş konular plana girmez', () async {
    final topics = await db.watchTopics(matematik).first;
    for (final topic in topics) {
      await db.setTopicDone(topic.id, done: true);
    }

    await db.buildWeeklyPlan(
      weekdays: {DateTime.monday},
      perDay: 4,
      from: pazartesi,
    );

    final titles = (await planTasks()).map((t) => t.title);
    expect(titles.every((t) => t.startsWith('Tur')), isTrue);
  });

  test('planı yenilemek tamamlanmamış eski plan işlerini siler', () async {
    await db.buildWeeklyPlan(
      weekdays: {DateTime.monday},
      perDay: 2,
      from: pazartesi,
    );
    expect(await planTasks(), hasLength(2));

    await db.buildWeeklyPlan(
      weekdays: {DateTime.monday},
      perDay: 3,
      from: pazartesi,
    );

    expect(await planTasks(), hasLength(3));
  });

  test('tamamlanmış plan işleri yenilemede korunur', () async {
    await db.buildWeeklyPlan(
      weekdays: {DateTime.monday},
      perDay: 2,
      from: pazartesi,
    );
    final first = (await planTasks()).first;
    await db.setTaskDone(first.id, done: true);

    await db.buildWeeklyPlan(
      weekdays: {DateTime.monday},
      perDay: 2,
      from: pazartesi,
    );

    final tasks = await planTasks();
    // Yapılan iş silinmedi: 1 tamamlanmış + 2 yeni.
    expect(tasks.where((t) => t.done), hasLength(1));
    expect(tasks, hasLength(3));
  });

  test('kullanıcının elle eklediği işler plandan etkilenmez', () async {
    await db.addTask(title: 'Deneme çöz', dueOn: today());

    await db.buildWeeklyPlan(
      weekdays: {DateTime.monday},
      perDay: 2,
      from: pazartesi,
    );
    await db.buildWeeklyPlan(
      weekdays: {DateTime.monday},
      perDay: 2,
      from: pazartesi,
    );

    final manual = await (db.select(db.tasks)
          ..where((t) => t.source.equalsValue(TaskSource.manual)))
        .get();
    expect(manual, hasLength(1));
  });

  test('plan tercihleri kaydedilir ve geri okunur', () async {
    await db.buildWeeklyPlan(
      weekdays: {DateTime.monday, DateTime.friday},
      perDay: 3,
      from: pazartesi,
    );

    final saved = await db.readPlanSettings();
    expect(saved?.weekdays, {DateTime.monday, DateTime.friday});
    expect(saved?.perDay, 3);
  });

  test('hiç plan kurulmamışsa tercih okuması boş döner', () async {
    expect(await db.readPlanSettings(), isNull);
  });

  test('bekleyen plan sayısı tamamlananları saymaz', () async {
    await db.buildWeeklyPlan(
      weekdays: {DateTime.monday},
      perDay: 3,
      from: pazartesi,
    );
    final first = (await planTasks()).first;
    await db.setTaskDone(first.id, done: true);

    expect(await db.watchPendingPlanCount().first, 2);
  });

  test('konu bitince işareti kaldırmak çalışma kaydına göre durum verir',
      () async {
    final topic = (await db.watchTopics(matematik).first).first;

    await db.setTopicDone(topic.id, done: true);
    await db.setTopicDone(topic.id, done: false);
    var updated = (await db.watchTopics(matematik).first).first;
    expect(updated.status, TopicStatus.notStarted);

    await db.logStudySession(topicId: topic.id, minutes: 30);
    await db.setTopicDone(topic.id, done: true);
    await db.setTopicDone(topic.id, done: false);
    updated = (await db.watchTopics(matematik).first).first;
    // Çalışma kaydı varken "başlamadım"a dönmek yaptığı işi yok saymak olurdu.
    expect(updated.status, TopicStatus.inProgress);
  });
}
