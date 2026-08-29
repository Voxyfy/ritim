import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/domain/exam_scoring.dart';

/// Net hesabı ve zayıf ders çıkarımı. Sınav kuralları burada, veritabanından
/// bağımsız.
void main() {
  SubjectScore score(
    String name, {
    required int correct,
    required int wrong,
    int blank = 0,
    int id = 1,
  }) =>
      SubjectScore(
        subjectId: id,
        name: name,
        colorIndex: 0,
        correct: correct,
        wrong: wrong,
        blank: blank,
      );

  group('net hesabı', () {
    test('yanlış götürmeyen sınavda net doğru sayısıdır', () {
      expect(ExamScoring.net(30, 10, WrongPenalty.none), 30);
    });

    test('LGS kuralında üç yanlış bir doğruyu götürür', () {
      expect(ExamScoring.net(20, 6, WrongPenalty.oneInThree), 18);
    });

    test('YKS kuralında dört yanlış bir doğruyu götürür', () {
      expect(ExamScoring.net(20, 8, WrongPenalty.oneInFour), 18);
    });

    test('net negatife düşebilir', () {
      // Sınav böyle hesaplıyor; gerçeği yumuşatmak öğrenciye yalan söylemek
      // olurdu.
      expect(ExamScoring.net(1, 8, WrongPenalty.oneInFour), -1);
    });

    test('toplam net dersleri birleştirir', () {
      final toplam = ExamScoring.totalNet(
        [
          score('Matematik', correct: 20, wrong: 8),
          score('Türkçe', correct: 30, wrong: 4, id: 2),
        ],
        WrongPenalty.oneInFour,
      );

      expect(toplam, 47);
    });
  });

  group('doğru oranı', () {
    test('boşlar hesaba katılmaz', () {
      final analiz = ExamScoring.analyse(
        score('Matematik', correct: 8, wrong: 2, blank: 30),
        WrongPenalty.oneInFour,
      );

      // Boş bir bilgi eksiği, yanlış ise bir yanılgı; ikisi aynı şey değil.
      expect(analiz.accuracy, closeTo(0.8, 0.001));
    });

    test('hiç cevaplanmamış derste oran yoktur', () {
      final analiz = ExamScoring.analyse(
        score('Matematik', correct: 0, wrong: 0, blank: 40),
        WrongPenalty.oneInFour,
      );

      expect(analiz.accuracy, isNull);
    });
  });

  group('zayıf ders çıkarımı', () {
    test('nete göre değil doğru oranına göre sıralar', () {
      final zayif = ExamScoring.weakest(
        [
          // 40 soruda 20 doğru: net yüksek ama oran düşük.
          score('Matematik', correct: 20, wrong: 20, id: 1),
          // 10 soruda 9 doğru: net düşük ama oran yüksek.
          score('Din Kültürü', correct: 9, wrong: 1, id: 2),
        ],
        WrongPenalty.oneInFour,
      );

      expect(zayif.first.score.name, 'Matematik');
    });

    test('boş bırakılan ders zayıf listesine girmez', () {
      final zayif = ExamScoring.weakest(
        [
          score('Matematik', correct: 5, wrong: 5, id: 1),
          score('Fizik', correct: 0, wrong: 0, blank: 14, id: 2),
        ],
        WrongPenalty.oneInFour,
      );

      // Hiç dokunulmamış bir ders hakkında söyleyecek bir şeyimiz yok.
      expect(zayif.map((a) => a.score.name), ['Matematik']);
    });

    test('sınır sayısı kadar ders döner', () {
      final zayif = ExamScoring.weakest(
        [
          score('A', correct: 1, wrong: 9, id: 1),
          score('B', correct: 2, wrong: 8, id: 2),
          score('C', correct: 3, wrong: 7, id: 3),
          score('D', correct: 4, wrong: 6, id: 4),
        ],
        WrongPenalty.oneInFour,
        limit: 2,
      );

      expect(zayif.map((a) => a.score.name), ['A', 'B']);
    });
  });

  group('etiketler', () {
    test('kısa etiketler seçim kutusuna sığacak uzunlukta', () {
      // Üç seçenek eşit genişlikte kutularda yan yana duruyor; uzunluk farkı
      // büyüyünce biri iki satıra düşüp satırı orantısız yapıyordu.
      for (final penalty in WrongPenalty.values) {
        expect(penalty.shortLabel.length, lessThanOrEqualTo(9));
      }
    });

    test('tam açıklama ve örnek sınavlar dolu', () {
      for (final penalty in WrongPenalty.values) {
        expect(penalty.label, isNotEmpty);
        expect(penalty.examples, isNotEmpty);
      }
    });
  });

  group('sınav kuralı varsayılanı', () {
    test('şablona göre seçilir', () {
      expect(WrongPenalty.forTemplate('lgs8'), WrongPenalty.oneInThree);
      expect(WrongPenalty.forTemplate('tyt'), WrongPenalty.oneInFour);
      expect(WrongPenalty.forTemplate('ayt-sozel'), WrongPenalty.oneInFour);
      expect(WrongPenalty.forTemplate('kpss-lisans'), WrongPenalty.none);
      expect(WrongPenalty.forTemplate(null), WrongPenalty.none);
    });
  });
}
