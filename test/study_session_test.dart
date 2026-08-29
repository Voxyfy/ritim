import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';
/// 4. günün kuralları: çalışma kaydı konuyu ilerletir, notlar konuya yapışır.
void main() {
  late RitimDatabase db;
  late int subjectId;
  late int topicId;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    subjectId = await db.addSubject(name: 'Matematik', colorIndex: 1);
    topicId = await db.addTopic(subjectId: subjectId, name: 'Üslü İfadeler');
  });
  tearDown(() => db.close());

  Future<Topic> topic() =>
      (db.select(db.topics)..where((t) => t.id.equals(topicId))).getSingle();

  test('ilk çalışma kaydı konuyu "çalışıyorum" durumuna taşır', () async {
    expect((await topic()).status, TopicStatus.notStarted);

    await db.logStudySession(topicId: topicId, minutes: 40);

    final updated = await topic();
    expect(updated.status, TopicStatus.inProgress);
    expect(updated.lastStudiedAt, isNotNull);
  });

  test('tamamlanmış bir konuya çalışmak durumu geri almaz', () async {
    await db.setTopicStatus(topicId, TopicStatus.done);

    await db.logStudySession(topicId: topicId, minutes: 25);

    expect((await topic()).status, TopicStatus.done);
  });

  test('toplamlar birden çok kaydı birleştirir', () async {
    await db.logStudySession(
      topicId: topicId,
      minutes: 40,
      questionsSolved: 20,
      questionsWrong: 4,
    );
    await db.logStudySession(
      topicId: topicId,
      minutes: 20,
      questionsSolved: 10,
      questionsWrong: 1,
    );

    final totals = await db.watchTopicTotals(topicId).first;

    expect(totals.minutes, 60);
    expect(totals.solved, 30);
    expect(totals.wrong, 5);
    expect(totals.accuracy, closeTo(25 / 30, 0.001));
  });

  test('soru girilmemişse doğru oranı hesaplanmaz', () async {
    await db.logStudySession(topicId: topicId, minutes: 45);

    final totals = await db.watchTopicTotals(topicId).first;

    expect(totals.hasQuestions, isFalse);
    expect(totals.accuracy, isNull);
  });

  test('boş not yazılmaz, dolu not kırpılarak saklanır', () async {
    expect(await db.addTopicNote(topicId, '   '), isNull);
    expect(await db.watchTopicNotes(topicId).first, isEmpty);

    await db.addTopicNote(topicId, '  negatif tabanı karıştırıyorum  ');
    final notes = await db.watchTopicNotes(topicId).first;
    expect(notes.single.body, 'negatif tabanı karıştırıyorum');
  });

  test('tamamlanan konu sayısı ders kimliğine göre gruplanır', () async {
    final ikinci = await db.addTopic(subjectId: subjectId, name: 'Kareköklü');
    await db.setTopicStatus(topicId, TopicStatus.done);

    var counts = await db.watchCompletedTopicCounts().first;
    expect(counts[subjectId], 1);

    await db.setTopicStatus(ikinci, TopicStatus.done);
    counts = await db.watchCompletedTopicCounts().first;
    expect(counts[subjectId], 2);
  });

  test('çalışma kaydıyla birlikte konu bitmiş işaretlenebilir', () async {
    // Konuyu bitmiş saymanın tek yolu konu detayındaki anahtardı; günlük
    // listeden çalışan öğrencinin ilerlemesi sonsuza kadar %0 kalıyordu.
    await db.logStudySession(topicId: topicId, minutes: 40);
    await db.setTopicDone(topicId, done: true);

    expect((await topic()).status, TopicStatus.done);
    expect(await db.watchCompletedTopicCounts().first, {subjectId: 1});
  });

  test('konu silinince çalışma kayıtları da gider', () async {
    await db.logStudySession(topicId: topicId, minutes: 30);

    await (db.delete(db.topics)..where((t) => t.id.equals(topicId))).go();

    expect(await db.select(db.studySessions).get(), isEmpty);
  });
}
