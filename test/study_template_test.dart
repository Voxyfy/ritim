import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/data/templates/study_template.dart';
/// Paketlenen varlıkları korur: bozuk bir şablon ancak çalışma anında, hem de
/// ilk açılış ekranında patlar — bunu öğrenmek için en kötü yer.
void main() {
  test('şablon kimlikleri benzersizdir', () {
    final ids = TemplateRepository.assetIds;
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, isNot(contains(StudyTemplate.blank.id)));
  });

  for (final id in TemplateRepository.assetIds) {
    test('"$id" şablonu ayrıştırılıyor ve dolu', () {
      final file = File('assets/templates/$id.json');
      expect(file.existsSync(), isTrue, reason: '${file.path} yok');

      final template = StudyTemplate.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );

      expect(template.id, id, reason: 'kimlik dosya adıyla aynı olmalı');
      expect(template.name, isNotEmpty);
      expect(template.group, isNotEmpty, reason: 'kurulum buna göre grupluyor');
      expect(template.description, isNotEmpty);
      expect(template.subjects, isNotEmpty);

      for (final subject in template.subjects) {
        expect(subject.name, isNotEmpty);
        expect(
          subject.topics,
          isNotEmpty,
          reason: '${subject.name} dersinin konusu yok',
        );
        expect(
          subject.colorIndex,
          inInclusiveRange(0, 11),
          reason: '${subject.name} paletin dışına işaret ediyor',
        );
        expect(
          subject.topics.toSet(),
          hasLength(subject.topics.length),
          reason: '${subject.name} dersinde tekrarlanan konu var',
        );
      }

      // Aynı şablonda iki dersin aynı rengi kullanması etiketleri birbirine
      // karıştırır; ders paletinin varlık sebebi tam da bu.
      final colours = template.subjects.map((s) => s.colorIndex).toList();
      expect(
        colours.toSet(),
        hasLength(colours.length),
        reason: 'iki ders aynı rengi paylaşıyor',
      );

      final names = template.subjects.map((s) => s.name).toList();
      expect(
        names.toSet(),
        hasLength(names.length),
        reason: 'aynı ders iki kez tanımlanmış',
      );
    });
  }
}
