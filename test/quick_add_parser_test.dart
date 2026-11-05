import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/domain/quick_add_parser.dart';

/// Hızlı ekleme çözümleyicisi. Asıl güvence ikinci yarıda: belirsiz girdi
/// yanlış derse/konuya düşmemeli, eşleşmesiz kalmalı.
void main() {
  // 2026-11-04 Çarşamba.
  final wednesday = DateTime(2026, 11, 4);

  const tyt = [
    QuickAddSubject(
      id: 1,
      name: 'Matematik',
      topics: [
        QuickAddTopic(id: 11, name: 'Türev'),
        QuickAddTopic(id: 12, name: 'Üslü Sayılar'),
        QuickAddTopic(id: 13, name: 'Rasyonel Sayılar'),
        QuickAddTopic(id: 14, name: 'Denklem Çözme'),
      ],
    ),
    QuickAddSubject(
      id: 2,
      name: 'Fizik',
      topics: [QuickAddTopic(id: 21, name: 'Vektörler')],
    ),
    QuickAddSubject(
      id: 3,
      name: 'Geometri',
      topics: [QuickAddTopic(id: 31, name: 'Vektörler')],
    ),
    QuickAddSubject(
      id: 4,
      name: 'Türkçe',
      topics: [
        QuickAddTopic(id: 41, name: 'Paragrafta Anlam'),
        QuickAddTopic(id: 42, name: 'Paragrafta Yapı'),
        QuickAddTopic(id: 43, name: 'İsim Tamlamaları'),
      ],
    ),
    QuickAddSubject(id: 5, name: 'Fen Bilimleri'),
    QuickAddSubject(id: 6, name: 'İngilizce'),
    QuickAddSubject(id: 7, name: 'Coğrafya'),
  ];

  QuickAddResult parse(
    String input, {
    List<QuickAddSubject> subjects = tyt,
    Set<QuickAddPart> ignore = const {},
  }) => QuickAddParser.parse(
    input,
    subjects: subjects,
    today: wednesday,
    ignore: ignore,
  );

  group('gün', () {
    test('bugün, yarın, öbür gün', () {
      expect(parse('bugün paragraf').dayOffset, 0);
      expect(parse('yarın deneme').dayOffset, 1);
      expect(parse('öbür gün deneme').dayOffset, 2);
      expect(parse('öbürgün deneme').dayOffset, 2);
      expect(parse('öbür gün deneme').title, 'Deneme');
    });

    test('hafta günü bir sonraki karşılığı; bugünün adı gelecek hafta', () {
      expect(parse('cuma deneme').dayOffset, 2);
      expect(parse('pazartesi deneme').dayOffset, 5);
      expect(parse('salı deneme').dayOffset, 6);
      expect(parse('çarşamba deneme').dayOffset, 7);
      expect(parse('cumartesi deneme').dayOffset, 3);
      expect(parse('cumartesi deneme').dayLabel, 'Cumartesi');
    });

    test('ek, kesme işareti, büyük harf ve aksansız yazım', () {
      expect(parse('cumaya deneme').dayOffset, 2);
      expect(parse("Cuma'ya deneme").dayOffset, 2);
      expect(parse('salıya deneme').dayOffset, 6);
      expect(parse('SALI deneme').dayOffset, 6);
      expect(parse('YARIN deneme').dayOffset, 1);
      expect(parse('yarin deneme').dayOffset, 1);
      expect(parse('yarına deneme').dayOffset, 1);
      expect(parse('pzt deneme').dayOffset, 5);
      expect(parse('cmt deneme').dayOffset, 3);
    });

    test('gün kelimesi yoksa null; benzeyen kelime gün sayılmaz', () {
      expect(parse('deneme çöz').dayOffset, isNull);
      expect(parse('pazarlama ödevi').dayOffset, isNull);
      expect(parse('salih ile çalış').dayOffset, isNull);
    });
  });

  group('ders', () {
    test('önek ve kısaltmalar', () {
      expect(parse('mat deneme').subjectId, 1);
      expect(parse('fiz deneme').subjectId, 2);
      expect(parse('geo deneme').subjectId, 3);
      expect(parse('tr deneme').subjectId, 4);
      expect(parse('fen deneme').subjectId, 5);
      expect(parse('ing kelime').subjectId, 6);
      expect(parse('coğ harita').subjectId, 7);
      expect(parse('cog harita').subjectId, 7);
    });

    test('Türkçe büyük/küçük harf: İ ve I', () {
      expect(parse('İNGİLİZCE kelime').subjectId, 6);
      expect(parse('ingilizce kelime').subjectId, 6);
      expect(parse('TÜRKÇE deneme').subjectId, 4);
    });

    test('iki kelimelik ders adı tek parça yutulur', () {
      final r = parse('yarın fen bilimleri deneme');
      expect(r.subjectId, 5);
      expect(r.title, 'Deneme');
    });

    test('lisede "türkçe" Türk Dili ve Edebiyatı dersine gider', () {
      const lise = [
        QuickAddSubject(id: 1, name: 'Türk Dili ve Edebiyatı'),
        QuickAddSubject(id: 2, name: 'Tarih'),
      ];
      expect(parse('türkçe ödev', subjects: lise).subjectId, 1);
      expect(parse('edebiyat ödev', subjects: lise).subjectId, 1);
    });

    test('belirsiz kısaltma eşleşmez', () {
      const sozel = [
        QuickAddSubject(id: 1, name: 'Tarih-1'),
        QuickAddSubject(id: 2, name: 'Tarih-2'),
      ];
      final r = parse('tarih okuma', subjects: sozel);
      expect(r.subjectId, isNull);
      expect(r.title, 'Tarih okuma');
    });

    test('iki harfli rastgele kelime ders sayılmaz', () {
      expect(parse('ma deneme').subjectId, isNull);
      expect(parse('soru çöz').subjectId, isNull);
    });

    test('ders tek başına kalırsa başlık ders adı olur', () {
      expect(parse('yarın mat').title, 'Matematik');
    });
  });

  group('konu', () {
    test('ders içinde konu; başka kelime yoksa başlık konu adı', () {
      final r = parse('yarın mat türev');
      expect(r.dayOffset, 1);
      expect(r.subjectId, 1);
      expect(r.topicId, 11);
      expect(r.title, 'Türev');
      expect(r.spans, const [
        QuickAddSpan(QuickAddPart.day, 0, 5),
        QuickAddSpan(QuickAddPart.subject, 6, 9),
        QuickAddSpan(QuickAddPart.topic, 10, 15),
      ]);
    });

    test('kalan kelimeler konu adının ardına eklenir', () {
      final r = parse('cuma fizik vektörler 45 dk');
      expect(r.dayOffset, 2);
      expect(r.subjectId, 2);
      expect(r.topicId, 21);
      expect(r.title, 'Vektörler 45 dk');
    });

    test('ders yazılmadan konu tekse ders de bulunur', () {
      final r = parse('yarın türev');
      expect(r.subjectId, 1);
      expect(r.topicId, 11);
    });

    test('iki derste aynı konu: ders yoksa eşleşme yok', () {
      final r = parse('vektörler');
      expect(r.topicId, isNull);
      expect(r.subjectId, isNull);
      expect(r.title, 'Vektörler');
    });

    test('belirsiz konu ama tek ders: ders seçilir, kelime başlıkta kalır', () {
      final r = parse('bugün paragraf');
      expect(r.subjectId, 4);
      expect(r.topicId, isNull);
      expect(r.title, 'Paragraf');
    });

    test('daha çok kelimeyle eşleşen konu kazanır', () {
      expect(parse('mat üslü sayılar').topicId, 12);
      expect(parse('mat sayılar').topicId, isNull);
    });

    test('ekli ve aksansız konu kelimesi', () {
      expect(parse('mat türevi').topicId, 11);
      expect(parse('mat turev').topicId, 11);
      expect(parse('isim tamlamaları').topicId, 43);
    });

    test('görev fiilleri konu sayılmaz', () {
      final r = parse('mat 40 soru çöz');
      expect(r.topicId, isNull);
      expect(r.title, '40 soru çöz');
    });
  });

  group('yok sayma', () {
    test('kaldırılan yorumun kelimesi başlığa döner', () {
      final r = parse('yarın mat türev', ignore: {QuickAddPart.day});
      expect(r.dayOffset, isNull);
      expect(r.topicId, 11);
      expect(r.title, 'Türev yarın');
      expect(
        parse('yarın mat türev', ignore: {QuickAddPart.topic}).title,
        'Türev',
      );
    });

    test('ders kaldırılınca çıkarım da yapılmaz', () {
      final r = parse('bugün paragraf', ignore: {QuickAddPart.subject});
      expect(r.subjectId, isNull);
    });
  });

  test('boş ve sade girdi', () {
    expect(parse('').title, '');
    expect(parse('   ').title, '');
    expect(parse('deneme çöz').title, 'Deneme çöz');
    expect(parse('deneme çöz').spans, isEmpty);
    expect(parse('yarın').title, '');
  });
}
