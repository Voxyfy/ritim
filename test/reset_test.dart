import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/date_extensions.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';

/// Sıfırlama seçenekleri. Her birinin neyi sildiği ve **neyi koruduğu**
/// ayrı ayrı doğrulanıyor: yanlış silen bir sıfırlama, kullanıcının bir yıllık
/// notunu götürür.
void main() {
  late RitimDatabase db;
  late int subjectId;
  late int topicId;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    subjectId = await db.addSubject(name: 'Matematik', colorIndex: 1);
    topicId = await db.addTopic(subjectId: subjectId, name: 'Üslü İfadeler');
    await db.addTopicNote(topicId, 'negatif tabanı karıştırıyorum');
    await db.addPhoto(topicId: topicId, relativePath: 'a.jpg');
    await db.logStudySession(topicId: topicId, minutes: 40);
    await db.addTask(title: 'Deneme çöz', dueOn: today());
  });
  tearDown(() => db.close());

  Future<Topic> topic() =>
      (db.select(db.topics)..where((t) => t.id.equals(topicId))).getSingle();

  group('konu ilerlemesini sıfırla', () {
    test('durumları başa alır', () async {
      expect((await topic()).status, TopicStatus.inProgress);

      await db.resetTopicProgress();

      expect((await topic()).status, TopicStatus.notStarted);
    });

    test('notu, fotoğrafı ve çalışma geçmişini korur', () async {
      await db.resetTopicProgress();

      expect(
        (await db.watchTopicNotes(topicId).first).single.body,
        'negatif tabanı karıştırıyorum',
      );
      expect(await db.select(db.topicPhotos).get(), hasLength(1));
      expect(await db.select(db.studySessions).get(), hasLength(1));
    });
  });

  group('çalışma geçmişini sil', () {
    test('kayıtları, görevleri ve tekrarları siler', () async {
      await db.resetStudyHistory();

      expect(await db.select(db.studySessions).get(), isEmpty);
      expect(await db.select(db.tasks).get(), isEmpty);
    });

    test('konu durumlarını da başa alır', () async {
      await db.resetStudyHistory();

      final t = await topic();
      // Çalışma kaydı silinmişken "çalışıyorum" görünmek, hiçbir veriye
      // dayanmayan bir iddia olurdu.
      expect(t.status, TopicStatus.notStarted);
      expect(t.lastStudiedAt, isNull);
    });

    test('ders, konu, not ve fotoğrafı korur', () async {
      await db.resetStudyHistory();

      expect(await db.select(db.subjects).get(), hasLength(1));
      expect(
        (await db.watchTopicNotes(topicId).first).single.body,
        'negatif tabanı karıştırıyorum',
      );
      expect(await db.select(db.topicPhotos).get(), hasLength(1));
    });
  });

  group('her şeyi sil', () {
    test('bütün tabloları boşaltır', () async {
      await db.clearAll();

      expect(await db.select(db.subjects).get(), isEmpty);
      expect(await db.select(db.topics).get(), isEmpty);
      expect(await db.select(db.studySessions).get(), isEmpty);
      expect(await db.select(db.tasks).get(), isEmpty);
      expect(await db.select(db.topicPhotos).get(), isEmpty);
      expect(await db.select(db.topicNotes).get(), isEmpty);
      expect(await db.select(db.settings).get(), isEmpty);
    });

    test('silinecek fotoğraf yollarını döndürür', () async {
      // Veritabanı katmanı diske dokunmuyor; dosyaları çağıran taraf siliyor
      // ve bunun için yolları bilmesi gerekiyor.
      final paths = await db.clearAll();

      expect(paths, ['a.jpg']);
    });

    test('kurulum bayrağı da silinir; uygulama karşılamaya döner', () async {
      await db.writeSetting(SettingKeys.onboarded, 'true');

      await db.clearAll();

      expect(await db.isOnboarded, isFalse);
    });
  });
}
