import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/templates/study_template.dart';
void main() {
  late RitimDatabase db;

  setUp(() => db = RitimDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const template = StudyTemplate(
    id: 'test',
    name: 'Test',
    group: 'Test',
    description: '',
    subjects: [
      TemplateSubject(name: 'Matematik', colorIndex: 1, topics: ['Üslü Sayılar', 'Köklü Sayılar']),
      TemplateSubject(name: 'Fizik', colorIndex: 7, topics: ['Vektörler']),
    ],
  );

  test('şablon uygulamak ders, konu ve kurulum bayrağını yazar', () async {
    expect(await db.isOnboarded, isFalse);

    await db.applyTemplate(template);

    final subjects = await db.watchSubjects().first;
    expect(subjects.map((s) => s.name), ['Matematik', 'Fizik']);
    expect(subjects.map((s) => s.position), [0, 1]);
    expect(await db.watchTopicCounts().first,
        {subjects[0].id: 2, subjects[1].id: 1});
    expect(await db.isOnboarded, isTrue);
    expect(await db.readSetting(SettingKeys.templateId), 'test');
  });

  test('boş şablon hiçbir satır yazmadan kurulumu bitirir', () async {
    await db.applyTemplate(StudyTemplate.blank);

    expect(await db.watchSubjects().first, isEmpty);
    expect(await db.isOnboarded, isTrue);
  });

  test('ikinci şablon sırayı sıfırlamaz, sona ekler', () async {
    await db.applyTemplate(template);
    await db.applyTemplate(template);

    final subjects = await db.watchSubjects().first;
    expect(subjects.map((s) => s.position), [0, 1, 2, 3]);
  });

  test('ders silmek konularını da siler', () async {
    await db.applyTemplate(template);
    final subjects = await db.watchSubjects().first;

    await (db.delete(db.subjects)..where((s) => s.id.equals(subjects.first.id)))
        .go();

    expect(await db.watchTopics(subjects.first.id).first, isEmpty);
  });
}
