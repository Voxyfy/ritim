import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/data/db/database.dart';
/// Konu fotoğraflarının veri tarafı.
///
/// Dosya sistemi burada yok: [PhotoStore] diske bakıyor, veritabanı yalnızca
/// göreli yolu tutuyor. İkisini ayırmak, testin gerçek dosya açmasını
/// gerektirmiyor.
void main() {
  late RitimDatabase db;
  late int topicId;

  setUp(() async {
    db = RitimDatabase(NativeDatabase.memory());
    final subjectId = await db.addSubject(name: 'Matematik');
    topicId = await db.addTopic(subjectId: subjectId, name: 'Üslü İfadeler');
  });
  tearDown(() => db.close());

  test('fotoğraf eklenir ve en yeniden eskiye listelenir', () async {
    // Aynı saniye içinde eklenen iki fotoğraf: zaman damgası SQLite'ta
    // saniye hassasiyetinde olduğu için sıra kimlikle kesinleşmeli.
    await db.addPhoto(topicId: topicId, relativePath: 'a.jpg');
    await db.addPhoto(topicId: topicId, relativePath: 'b.jpg');

    final photos = await db.watchPhotos(topicId).first;

    expect(photos.map((p) => p.relativePath), ['b.jpg', 'a.jpg']);
  });

  test('silme, dosyayı silebilmek için yolu geri döndürür', () async {
    final id = await db.addPhoto(topicId: topicId, relativePath: 'a.jpg');

    final path = await db.removePhoto(id);

    expect(path, 'a.jpg');
    expect(await db.watchPhotos(topicId).first, isEmpty);
  });

  test('olmayan fotoğrafı silmek hata vermez', () async {
    expect(await db.removePhoto(999), isNull);
  });

  test('fotoğraf sayısı yalnızca o konuyu sayar', () async {
    final digerKonu = await db.addTopic(
      subjectId: (await db.select(db.subjects).get()).single.id,
      name: 'Kareköklü İfadeler',
    );
    await db.addPhoto(topicId: topicId, relativePath: 'a.jpg');
    await db.addPhoto(topicId: topicId, relativePath: 'b.jpg');
    await db.addPhoto(topicId: digerKonu, relativePath: 'c.jpg');

    expect(await db.watchPhotoCount(topicId).first, 2);
    expect(await db.watchPhotoCount(digerKonu).first, 1);
  });

  test('konu silinince fotoğraf satırları da gider', () async {
    await db.addPhoto(topicId: topicId, relativePath: 'a.jpg');

    await db.deleteTopic(topicId);

    expect(await db.select(db.topicPhotos).get(), isEmpty);
  });
}
