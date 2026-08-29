import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';
import 'package:ritim/domain/exam_scoring.dart';

/// Deneme kaydının veritabanı tarafı.
void main() {
  late RitimDatabase db;
  late int matematik;
  late int turkce;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    matematik = await db.addSubject(name: 'Matematik', colorIndex: 1);
    turkce = await db.addSubject(name: 'Türkçe', colorIndex: 0);
    for (var i = 0; i < 3; i++) {
      await db.addTopic(subjectId: matematik, name: 'Mat $i', position: i);
      await db.addTopic(subjectId: turkce, name: 'Tur $i', position: i);
    }
  });
  tearDown(() => db.close());

  test('deneme ve ders sonuçları kaydedilir', () async {
    final examId = await db.saveMockExam(
      name: 'TYT Deneme 1',
      takenOn: DateTime(2026, 8, 30, 14, 30),
      penalty: WrongPenalty.oneInFour,
      results: {
        matematik: (correct: 20, wrong: 8, blank: 12),
        turkce: (correct: 30, wrong: 4, blank: 6),
      },
    );

    final exam = (await db.watchMockExams().first).single;
    expect(exam.id, examId);
    expect(exam.name, 'TYT Deneme 1');
    // Saat bilgisi düşürülüyor; deneme bir gün, bir an değil.
    expect(exam.takenOn, DateTime(2026, 8, 30));
    expect(WrongPenalty.values[exam.penalty], WrongPenalty.oneInFour);

    final scores = await db.watchExamScores(examId).first;
    expect(scores, hasLength(2));
    expect(ExamScoring.totalNet(scores, WrongPenalty.oneInFour), 47);
  });

  test('hiç girilmeyen ders kaydedilmez', () async {
    final examId = await db.saveMockExam(
      name: 'Deneme',
      takenOn: DateTime.now(),
      penalty: WrongPenalty.none,
      results: {
        matematik: (correct: 10, wrong: 2, blank: 0),
        // Öğrenci bu derse hiç dokunmadı; sıfır doğru olarak saklamak analizi
        // yanlış yönlendirirdi.
        turkce: (correct: 0, wrong: 0, blank: 0),
      },
    );

    final scores = await db.watchExamScores(examId).first;
    expect(scores.map((s) => s.name), ['Matematik']);
  });

  test('denemeler en yeniden eskiye sıralanır', () async {
    await db.saveMockExam(
      name: 'Eski',
      takenOn: DateTime(2026, 8, 1),
      penalty: WrongPenalty.none,
      results: {matematik: (correct: 5, wrong: 0, blank: 0)},
    );
    await db.saveMockExam(
      name: 'Yeni',
      takenOn: DateTime(2026, 8, 20),
      penalty: WrongPenalty.none,
      results: {matematik: (correct: 5, wrong: 0, blank: 0)},
    );

    expect((await db.watchMockExams().first).map((e) => e.name), ['Yeni', 'Eski']);
  });

  test('deneme silinince sonuçları da gider', () async {
    final examId = await db.saveMockExam(
      name: 'Deneme',
      takenOn: DateTime.now(),
      penalty: WrongPenalty.none,
      results: {matematik: (correct: 5, wrong: 1, blank: 0)},
    );

    await db.deleteMockExam(examId);

    expect(await db.select(db.mockExamResults).get(), isEmpty);
  });

  test('ders silinince o dersin deneme sonucu da gider', () async {
    final examId = await db.saveMockExam(
      name: 'Deneme',
      takenOn: DateTime.now(),
      penalty: WrongPenalty.none,
      results: {
        matematik: (correct: 5, wrong: 1, blank: 0),
        turkce: (correct: 8, wrong: 2, blank: 0),
      },
    );

    await db.deleteSubject(matematik);

    // Geçmiş deneme, artık var olmayan bir dersin satırını taşımamalı.
    final scores = await db.watchExamScores(examId).first;
    expect(scores.map((s) => s.name), ['Türkçe']);
  });

  test('zayıf derslere plan kurmak yalnızca o dersleri kapsar', () async {
    await db.buildWeeklyPlan(
      weekdays: {DateTime.monday, DateTime.tuesday, DateTime.wednesday},
      perDay: 3,
      from: DateTime(2026, 8, 31),
      onlySubjects: {matematik},
    );

    final planned = await (db.select(db.tasks)
          ..where((t) => t.source.equalsValue(TaskSource.plan)))
        .get();

    expect(planned, isNotEmpty);
    expect(planned.every((t) => t.title.startsWith('Mat')), isTrue);
  });
}
