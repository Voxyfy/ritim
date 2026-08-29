import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/date_extensions.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';
import 'package:ritim/domain/review_ladder.dart';
/// Motorun veritabanı tarafı: çalışmanın tekrara, tekrarın bir sonrakine
/// dönüştüğü zincir.
void main() {
  late RitimDatabase db;
  late int topicId;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    final subjectId = await db.addSubject(name: 'Matematik', colorIndex: 1);
    topicId = await db.addTopic(subjectId: subjectId, name: 'Üslü İfadeler');
  });
  tearDown(() => db.close());

  Future<List<Task>> reviews() => (db.select(db.tasks)
        ..where((t) => t.source.equalsValue(TaskSource.review))
        ..orderBy([(t) => OrderingTerm(expression: t.id)]))
      .get();

  test('çalışma kaydı konuyu merdivene sokar, ilk tekrar yarına düşer',
      () async {
    await db.logStudySession(topicId: topicId, minutes: 40);

    final review = (await reviews()).single;
    expect(review.title, 'Tekrar: Üslü İfadeler');
    expect(review.source, TaskSource.review);
    expect(review.reviewStep, 0);
    expect(review.dueOn, today().addDays(1));
  });

  test('üst üste çalışmak ikinci bir tekrar açmaz, tarihi yeniler', () async {
    await db.logStudySession(topicId: topicId, minutes: 40);
    await db.logStudySession(topicId: topicId, minutes: 30);
    await db.logStudySession(topicId: topicId, minutes: 20);

    final list = await reviews();
    expect(list, hasLength(1));
    expect(list.single.dueOn, today().addDays(1));
  });

  test('tekrarı tamamlamak bir sonrakini kendiliğinden planlar', () async {
    await db.logStudySession(topicId: topicId, minutes: 40);
    final first = (await reviews()).single;

    await db.setTaskDone(first.id, done: true);

    final list = await reviews();
    expect(list, hasLength(2));
    final next = list.last;
    expect(next.done, isFalse);
    expect(next.reviewStep, 1);
    expect(next.dueOn, today().addDays(3));
  });

  test('merdiven 1-3-7-21 sırasıyla tırmanır', () async {
    await db.logStudySession(topicId: topicId, minutes: 40);

    final gorulen = <int>[];
    for (var i = 0; i < ReviewLadder.intervals.length; i++) {
      final pending = (await reviews()).firstWhere((t) => !t.done);
      gorulen.add(pending.dueOn.difference(today()).inDays);
      await db.setTaskDone(pending.id, done: true);
    }

    expect(gorulen, ReviewLadder.intervals);
  });

  test('yanlış oranı yüksek konuda aralık uzamaz', () async {
    // 20 soruda 12 yanlış: doğru oranı %40, yani "zorlanıyor" bandı.
    await db.logStudySession(
      topicId: topicId,
      minutes: 40,
      questionsSolved: 20,
      questionsWrong: 12,
    );
    final first = (await reviews()).single;
    expect(first.dueOn, today().addDays(1));

    await db.setTaskDone(first.id, done: true);

    // Basamak ilerlemek yerine 0'da kalır: aralık yine ertesi gün.
    final next = (await reviews()).firstWhere((t) => !t.done);
    expect(next.reviewStep, 0);
    expect(next.dueOn, today().addDays(1));
  });

  test('yüksek doğru oranında aralık merdiveni atlamadan uzar', () async {
    await db.logStudySession(
      topicId: topicId,
      minutes: 40,
      questionsSolved: 20,
      questionsWrong: 1,
    );

    final first = (await reviews()).single;
    await db.setTaskDone(first.id, done: true);

    final next = (await reviews()).firstWhere((t) => !t.done);
    expect(next.reviewStep, 1);
    expect(next.dueOn, today().addDays(3));
  });

  test('elle eklenen görevi tamamlamak tekrar üretmez', () async {
    final id = await db.addTask(title: 'Test çöz', dueOn: today());

    await db.setTaskDone(id, done: true);

    expect(await reviews(), isEmpty);
  });

  test('bekleyen tekrarlar en yakın tarihten başlayarak listelenir', () async {
    final ikinci = await db.addTopic(
      subjectId: (await db.watchSubjects().first).single.id,
      name: 'Kareköklü İfadeler',
    );
    await db.logStudySession(topicId: topicId, minutes: 40);
    await db.logStudySession(topicId: ikinci, minutes: 30);
    // İlk konunun tekrarını bir kez tamamlayıp ileriye atıyoruz.
    final ilk = (await reviews()).firstWhere((t) => t.topicId == topicId);
    await db.setTaskDone(ilk.id, done: true);

    final upcoming = await db.watchUpcomingReviews().first;

    expect(upcoming.first.topic?.name, 'Kareköklü İfadeler');
    expect(upcoming.last.topic?.name, 'Üslü İfadeler');
  });

  group('hatırlatma ayarları', () {
    test('kayıt yokken varsayılanlar döner', () async {
      final settings = await db.watchReminderSettings().first;

      expect(settings.asked, isFalse);
      expect(settings.enabled, isFalse);
      expect(settings.hour, ReminderSettings.defaultHour);
    });

    test('kaydedilen tercih geri okunur', () async {
      await db.saveReminderSettings(
        const ReminderSettings(asked: true, enabled: true, hour: 21),
      );

      final settings = await db.watchReminderSettings().first;
      expect(settings.asked, isTrue);
      expect(settings.enabled, isTrue);
      expect(settings.hour, 21);
    });

    test('izin reddedilse bile soruldu olarak işaretlenir', () async {
      await db.saveReminderSettings(
        ReminderSettings.initial.copyWith(asked: true),
      );

      final settings = await db.watchReminderSettings().first;
      // "asked" olmadan sistem uyarısı her açılışta tekrar denenirdi.
      expect(settings.asked, isTrue);
      expect(settings.enabled, isFalse);
    });
  });

  test('tekrar görevi bugünün listesinde görünür', () async {
    await db.logStudySession(topicId: topicId, minutes: 40);
    // Tekrar yarına planlandığı için bugün görünmemeli.
    expect(await db.watchTasksUpTo(today()).first, isEmpty);

    final items = await db.watchTasksUpTo(today().addDays(1)).first;
    expect(items.single.task.title, 'Tekrar: Üslü İfadeler');
    expect(items.single.topic?.name, 'Üslü İfadeler');
  });
}
