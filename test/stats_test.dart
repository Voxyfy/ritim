import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';
/// Ana ekran istatistiklerinin veri tarafı.
void main() {
  late RitimDatabase db;
  late int matematik;
  late int turkce;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    matematik = await db.addSubject(name: 'Matematik', colorIndex: 1);
    turkce = await db.addSubject(name: 'Türkçe', colorIndex: 0);
  });
  tearDown(() => db.close());

  test('ders dağılımı süreye göre azalan sıralanır', () async {
    final mat = await db.addTopic(subjectId: matematik, name: 'Kümeler');
    final tur = await db.addTopic(subjectId: turkce, name: 'Paragraf');
    await db.logStudySession(topicId: mat, minutes: 30);
    await db.logStudySession(topicId: tur, minutes: 90);

    final rows = await db.watchSubjectMinutes().first;

    expect(rows.map((r) => r.name), ['Türkçe', 'Matematik']);
    expect(rows.first.minutes, 90);
    expect(rows.last.colorIndex, 1);
  });

  test('aynı dersin birden çok konusu tek satırda toplanır', () async {
    final a = await db.addTopic(subjectId: matematik, name: 'Kümeler');
    final b = await db.addTopic(subjectId: matematik, name: 'Fonksiyonlar');
    await db.logStudySession(topicId: a, minutes: 20);
    await db.logStudySession(topicId: b, minutes: 25);

    final rows = await db.watchSubjectMinutes().first;

    expect(rows, hasLength(1));
    expect(rows.single.minutes, 45);
  });

  test('hiç çalışılmamış ders dağılımda görünmez', () async {
    final mat = await db.addTopic(subjectId: matematik, name: 'Kümeler');
    await db.addTopic(subjectId: turkce, name: 'Paragraf');
    await db.logStudySession(topicId: mat, minutes: 30);

    final rows = await db.watchSubjectMinutes().first;

    expect(rows.map((r) => r.name), ['Matematik']);
  });

  test('konu ilerlemesi üç durumu ayrı sayar', () async {
    final a = await db.addTopic(subjectId: matematik, name: 'Kümeler');
    final b = await db.addTopic(subjectId: matematik, name: 'Fonksiyonlar');
    await db.addTopic(subjectId: turkce, name: 'Paragraf');

    await db.setTopicDone(a, done: true);
    await db.setTopicStatus(b, TopicStatus.inProgress);

    final progress = await db.watchTopicProgress().first;

    expect(progress.total, 3);
    expect(progress.done, 1);
    expect(progress.inProgress, 1);
    expect(progress.notStarted, 1);
    expect(progress.ratio, closeTo(1 / 3, 0.001));
  });

  test('konu yokken ilerleme oranı sıfırdır, bölme hatası vermez', () async {
    final progress = await db.watchTopicProgress().first;

    expect(progress.total, 0);
    expect(progress.ratio, 0);
  });

  test('plan günleri boş günleri de içerir ve bugünden başlar', () async {
    final mat = await db.addTopic(subjectId: matematik, name: 'Kümeler');
    await db.logStudySession(topicId: mat, minutes: 30);

    final days = await db.watchUpcomingDays().first;

    expect(days, hasLength(14));
    final now = DateTime.now();
    expect(days.first.day, DateTime(now.year, now.month, now.day));
    // Çalışma kaydı yarına bir tekrar planladı.
    expect(days[1].items.single.task.source, TaskSource.review);
    expect(days[1].items.single.topic?.name, 'Kümeler');
  });
}
