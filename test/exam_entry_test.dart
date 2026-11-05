import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/features/exams/exam_entry.dart';

/// Deneme tuş takımının saf mantığı: hane sınırı, otomatik geçiş, sonuçlar.
void main() {
  const order = [10, 20];
  late ExamEntryPad pad;

  CountCell at(int id, CountField f) => (subjectId: id, field: f);

  setUp(() {
    pad = ExamEntryPad()..focus = at(10, CountField.correct);
  });

  test(
    'iki hane dolunca doğrudan yanlışa, sonra sonraki dersin doğrusuna geçer',
    () {
      pad
        ..typeDigit(1, order)
        ..typeDigit(2, order);
      expect(pad.focus, at(10, CountField.wrong));

      pad
        ..typeDigit(3, order)
        ..advance(order);
      // Boş atlanıyor: net ve doğru oranı ona bakmıyor.
      expect(pad.focus, at(20, CountField.correct));
    },
  );

  test('sıfır tek dokunuşta geçer, baştaki sıfır tutulmaz', () {
    pad.typeDigit(0, order);
    expect(pad.valueOf(at(10, CountField.correct)), '0');
    expect(pad.focus, at(10, CountField.wrong));

    // Geri dönüp sıfırın üstüne yazmak sıfırı değiştirir.
    pad
      ..focus = at(10, CountField.correct)
      ..typeDigit(7, order);
    expect(pad.valueOf(at(10, CountField.correct)), '7');
  });

  test('dolu kutuya yazmak baştan başlatır, silme son haneyi alır', () {
    pad
      ..typeDigit(1, order)
      ..typeDigit(5, order)
      ..focus = at(10, CountField.correct)
      ..typeDigit(4, order);
    expect(pad.valueOf(at(10, CountField.correct)), '4');

    pad
      ..backspace()
      ..backspace();
    expect(pad.valueOf(at(10, CountField.correct)), '');
  });

  test('boştan ve son dersten geçiş', () {
    pad
      ..focus = at(10, CountField.blank)
      ..advance(order);
    expect(pad.focus, at(20, CountField.correct));

    pad
      ..focus = at(20, CountField.wrong)
      ..advance(order);
    expect(pad.focus, isNull, reason: 'son kutudan sonra tuş takımı iner');

    // Odak yokken tuşlar hiçbir şey yazmaz.
    pad.typeDigit(9, order);
    expect(pad.results(order)[20], (correct: 0, wrong: 0, blank: 0));
  });

  test('sonuçlar her ders için üç sayıyı verir', () {
    pad
      ..typeDigit(1, order)
      ..typeDigit(8, order)
      ..typeDigit(2, order)
      ..advance(order)
      ..focus = at(10, CountField.blank)
      ..typeDigit(0, order);
    expect(pad.results(order), {
      10: (correct: 18, wrong: 2, blank: 0),
      20: (correct: 0, wrong: 0, blank: 0),
    });
  });
}
