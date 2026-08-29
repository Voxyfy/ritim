import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/date_extensions.dart';
import 'package:ritim/data/db/database.dart';
/// Görev sayfasının veri tarafı ve şema göçü.
void main() {
  late RitimDatabase db;

  setUp(() => db = RitimDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Task> read(int id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();

  test('başlık, gün ve not güncellenir', () async {
    final id = await db.addTask(title: 'Test çöz', dueOn: today());

    await db.updateTask(
      id,
      title: 'Deneme çöz',
      dueOn: today().addDays(2),
      note: 'kitap s. 42-58',
    );

    final task = await read(id);
    expect(task.title, 'Deneme çöz');
    expect(task.dueOn, today().addDays(2));
    expect(task.note, 'kitap s. 42-58');
  });

  test('boş not null olarak saklanır', () async {
    final id = await db.addTask(title: 'Test çöz', dueOn: today());
    await db.updateTask(id, note: 'bir şey');
    expect((await read(id)).note, 'bir şey');

    await db.updateTask(id, note: '   ');
    // "Notu var mı" kontrolü her yerde aynı biçimde yapılabilsin diye boş
    // metin saklanmıyor.
    expect((await read(id)).note, isNull);
  });

  test('verilmeyen alanlar korunur', () async {
    final id = await db.addTask(title: 'Test çöz', dueOn: today());
    await db.updateTask(id, note: 'not');

    await db.updateTask(id, title: 'Yeni başlık');

    final task = await read(id);
    expect(task.title, 'Yeni başlık');
    expect(task.note, 'not', reason: 'dokunulmayan alan silinmemeli');
    expect(task.dueOn, today());
  });

  test('gün saat bilgisinden arındırılarak saklanır', () async {
    final id = await db.addTask(title: 'Test çöz', dueOn: today());

    await db.updateTask(id, dueOn: DateTime(2026, 9, 15, 23, 47));

    expect((await read(id)).dueOn, DateTime(2026, 9, 15));
  });

  group('satır etiketi başlığı tekrar etmez', () {
    late int subjectId;
    late int topicId;

    setUp(() async {
      subjectId = await db.addSubject(name: 'Geometri', colorIndex: 6);
      topicId = await db.addTopic(
        subjectId: subjectId,
        name: 'Doğruda ve Üçgende Açılar',
      );
    });

    Future<TaskItem> itemFor(int id) async {
      final items = await db.watchTasksUpTo(today()).first;
      return items.firstWhere((i) => i.task.id == id);
    }

    test('başlık konu adıyla aynıysa etiket dersi gösterir', () async {
      final id = await db.addTask(
        title: 'Doğruda ve Üçgende Açılar',
        dueOn: today(),
        topicId: topicId,
      );

      expect((await itemFor(id)).contextLabel, 'Geometri');
    });

    test('başlık farklıysa etiket konuyu gösterir', () async {
      final id = await db.addTask(
        title: '20 soru çöz',
        dueOn: today(),
        topicId: topicId,
      );

      expect((await itemFor(id)).contextLabel, 'Doğruda ve Üçgende Açılar');
    });

    test('konusu olmayan görevde etiket yok', () async {
      final id = await db.addTask(title: 'Kalem al', dueOn: today());

      expect((await itemFor(id)).contextLabel, isNull);
    });
  });

  test('konu silinince ona bağlı görev ve fotoğrafları da gider', () async {
    final subjectId = await db.addSubject(name: 'Matematik');
    final topicId = await db.addTopic(subjectId: subjectId, name: 'Kümeler');
    await db.addTask(title: 'Test çöz', dueOn: today(), topicId: topicId);
    await db.into(db.topicPhotos).insert(
          TopicPhotosCompanion.insert(
            topicId: topicId,
            relativePath: 'fotograflar/1.jpg',
          ),
        );

    await db.deleteTopic(topicId);

    expect(await db.select(db.tasks).get(), isEmpty);
    expect(await db.select(db.topicPhotos).get(), isEmpty);
  });
}
