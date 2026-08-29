import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/data/db/database.dart';
/// Seri ve haftalık özet kuralları.
void main() {
  late RitimDatabase db;
  late int topicId;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    final subjectId = await db.addSubject(name: 'Matematik');
    topicId = await db.addTopic(subjectId: subjectId, name: 'Üslü İfadeler');
  });
  tearDown(() => db.close());

  /// Belirtilen gün önceye çalışma kaydı yazar.
  Future<void> logDaysAgo(int daysAgo, {int minutes = 30}) async {
    final id = await db.logStudySession(topicId: topicId, minutes: minutes);
    final now = DateTime.now();
    final when = DateTime(now.year, now.month, now.day - daysAgo, 12);
    await (db.update(db.studySessions)..where((s) => s.id.equals(id)))
        .write(StudySessionsCompanion(studiedAt: Value(when)));
  }

  test('kayıt yokken seri sıfırdır', () async {
    expect(await db.watchStreak().first, 0);
  });

  test('ardışık günler seriyi büyütür', () async {
    await logDaysAgo(0);
    await logDaysAgo(1);
    await logDaysAgo(2);

    expect(await db.watchStreak().first, 3);
  });

  test('araya giren boş gün seriyi keser', () async {
    await logDaysAgo(0);
    await logDaysAgo(1);
    await logDaysAgo(3);

    expect(await db.watchStreak().first, 2);
  });

  test('bugün çalışılmamışsa seri dünden sayılır ve bozulmaz', () async {
    await logDaysAgo(1);
    await logDaysAgo(2);

    // Sabah uygulamayı açan öğrenciye "serin bitti" demiyoruz.
    expect(await db.watchStreak().first, 2);
  });

  test('iki gün önce biten seri bugün sıfırdır', () async {
    await logDaysAgo(2);
    await logDaysAgo(3);

    expect(await db.watchStreak().first, 0);
  });

  test('aynı güne iki kayıt seriyi bir kez sayar', () async {
    await logDaysAgo(0);
    await logDaysAgo(0);

    expect(await db.watchStreak().first, 1);
  });

  test('haftalık özet yalnızca son yedi günü toplar', () async {
    await logDaysAgo(0, minutes: 40);
    await logDaysAgo(6, minutes: 20);
    await logDaysAgo(9, minutes: 90);

    final summary = await db.watchWeeklySummary().first;

    expect(summary.minutes, 60);
  });

  test('günlük dakikalar boş günler dahil yedi satır döner', () async {
    await logDaysAgo(0, minutes: 40);
    await logDaysAgo(2, minutes: 25);

    final daily = await db.watchDailyMinutes().first;

    expect(daily, hasLength(7));
    expect(daily.last.minutes, 40);
    expect(daily[4].minutes, 25);
    expect(daily.first.minutes, 0);
    // Sıralama eskiden yeniye olmalı; grafiğin soldan sağa akması buna bağlı.
    expect(daily.first.day.isBefore(daily.last.day), isTrue);
  });
}
