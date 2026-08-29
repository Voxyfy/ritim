import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/date_extensions.dart';
import 'package:ritim/data/db/database.dart';
/// Ders ve konu yönetimi. "Kendin kur" akışının tamamı buna dayanıyor:
/// şablon seçmeyen kullanıcı uygulamayı ancak bu yollarla kurabiliyor.
void main() {
  late RitimDatabase db;

  setUp(() => db = RitimDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('sıfırdan ders ve konu eklenebilir', () async {
    final subjectId = await db.addSubject(name: 'Organik Kimya', colorIndex: 7);
    await db.addTopic(subjectId: subjectId, name: 'Hidrokarbonlar');

    final subjects = await db.select(db.subjects).get();
    expect(subjects.single.name, 'Organik Kimya');
    expect(subjects.single.colorIndex, 7);
    expect((await db.watchTopics(subjectId).first).single.name, 'Hidrokarbonlar');
  });

  test('ders adı ve rengi güncellenir', () async {
    final id = await db.addSubject(name: 'Kimya', colorIndex: 0);

    await db.updateSubject(id, name: 'Organik Kimya', colorIndex: 7);

    final subject = (await db.select(db.subjects).get()).single;
    expect(subject.name, 'Organik Kimya');
    expect(subject.colorIndex, 7);
  });

  test('konu sırası dersin sonuna eklenir', () async {
    final subjectId = await db.addSubject(name: 'Matematik');

    for (final name in ['Kümeler', 'Fonksiyonlar', 'Polinomlar']) {
      await db.addTopic(
        subjectId: subjectId,
        name: name,
        position: await db.nextTopicPosition(subjectId),
      );
    }

    final topics = await db.watchTopics(subjectId).first;
    expect(topics.map((t) => t.name), ['Kümeler', 'Fonksiyonlar', 'Polinomlar']);
    expect(topics.map((t) => t.position), [0, 1, 2]);
  });

  test('konu sırası dersler arasında karışmaz', () async {
    final mat = await db.addSubject(name: 'Matematik');
    final fiz = await db.addSubject(name: 'Fizik');

    await db.addTopic(
      subjectId: mat,
      name: 'Kümeler',
      position: await db.nextTopicPosition(mat),
    );
    await db.addTopic(
      subjectId: fiz,
      name: 'Vektörler',
      position: await db.nextTopicPosition(fiz),
    );

    // İkinci dersin ilk konusu da 0'dan başlamalı.
    expect((await db.watchTopics(fiz).first).single.position, 0);
  });

  test('ders silmek konularını, kayıtlarını ve görevlerini götürür', () async {
    final subjectId = await db.addSubject(name: 'Matematik');
    final topicId = await db.addTopic(subjectId: subjectId, name: 'Kümeler');
    await db.logStudySession(topicId: topicId, minutes: 30);
    await db.addTask(title: 'Test çöz', dueOn: today(), topicId: topicId);

    await db.deleteSubject(subjectId);

    expect(await db.select(db.topics).get(), isEmpty);
    expect(await db.select(db.studySessions).get(), isEmpty);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  test('konu silmek dersi silmez', () async {
    final subjectId = await db.addSubject(name: 'Matematik');
    final topicId = await db.addTopic(subjectId: subjectId, name: 'Kümeler');

    await db.deleteTopic(topicId);

    expect(await db.select(db.topics).get(), isEmpty);
    expect(await db.select(db.subjects).get(), hasLength(1));
  });

  test('konu adı güncellenir', () async {
    final subjectId = await db.addSubject(name: 'Matematik');
    final topicId = await db.addTopic(subjectId: subjectId, name: 'Kumeler');

    await db.updateTopic(topicId, name: 'Kümeler');

    expect((await db.watchTopics(subjectId).first).single.name, 'Kümeler');
  });
}
