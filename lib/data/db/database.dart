import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/exam_scoring.dart';
import '../../domain/review_ladder.dart';
import '../../domain/weekly_planner.dart';
import '../templates/study_template.dart';
import 'tables.dart';
part 'database.g.dart';

/// [Settings] tablosunda kullanılan anahtarlar.
abstract final class SettingKeys {
  static const onboarded = 'onboarded';
  static const templateId = 'template_id';

  /// Bildirim izni kullanıcıya soruldu mu? Sistem uyarısı bir kez
  /// gösterilebildiği için bunu kendimiz saklamak zorundayız.
  static const remindersAsked = 'reminders_asked';

  /// Kullanıcı hatırlatmaları açtı mı?
  static const remindersEnabled = 'reminders_enabled';

  /// Hatırlatma saati (0-23).
  static const reminderHour = 'reminder_hour';

  /// Üç adımlık tanıtım gösterildi mi?
  static const tourSeen = 'tour_seen';

  /// Haftalık planın günleri, virgülle ayrılmış (1 = pazartesi).
  static const planWeekdays = 'plan_weekdays';

  /// Haftalık planda günde kaç konu.
  static const planPerDay = 'plan_per_day';
}

/// Uygulamanın tek SQLite veritabanı.
///
/// Ritim çevrimdışı öncelikli; hesap da sunucu da yok, dolayısıyla kalıcılık
/// katmanının tamamı bu sınıf. Sorgular yüzey küçük kaldığı sürece burada
/// durur; bir özelliğin sorguları bir ekranı aşınca kendi DAO'suna taşınır.
@DriftDatabase(
  tables: [
    Subjects,
    Topics,
    StudySessions,
    Tasks,
    TopicNotes,
    TopicPhotos,
    MockExams,
    MockExamResults,
    Settings,
  ],
)
class RitimDatabase extends _$RitimDatabase {
  RitimDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'ritim'));

  /// Yayınlanan her şema değişikliğinde artırılır ve karşılığında bir göç
  /// adımı yazılır.
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // Göç adımları birikimli ve sıralı: v1'den v3'e atlayan bir cihaz
          // ikisini de sırayla çalıştırmalı. Bu yüzden `if` zinciri, `switch`
          // değil.
          if (from < 2) {
            await m.addColumn(tasks, tasks.note);
            await m.createTable(topicPhotos);
          }
          if (from < 3) {
            await m.createTable(mockExams);
            await m.createTable(mockExamResults);
          }
          if (from < 4) {
            await m.createTable(topicNotes);

            // Eski tekil notlar yeni tabloya taşınıyor. Ham SQL kullanılıyor
            // çünkü `note` sütunu artık Dart tarafındaki tablo tanımında yok;
            // veriyi taşımadan sütunu düşürmek, kullanıcının yazdığı her notu
            // sessizce silerdi.
            final eskiNotlar = await customSelect(
              'SELECT id, note FROM topics '
              "WHERE note IS NOT NULL AND TRIM(note) <> ''",
            ).get();
            for (final row in eskiNotlar) {
              await into(topicNotes).insert(
                TopicNotesCompanion.insert(
                  topicId: row.read<int>('id'),
                  body: row.read<String>('note'),
                ),
              );
            }

            await m.alterTable(TableMigration(topics));
          }
        },
        beforeOpen: (details) async {
          // SQLite yabancı anahtarları bağlantı başına kapalı tutar; bu
          // satır olmadan tablolardaki cascade kuralları hiç çalışmaz. Göç
          // içinde değil beforeOpen'da olmak zorunda: pragma şema değil
          // bağlantı durumudur ve drift, izolat yeniden başladığında yeni bir
          // bağlantı açar.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // --- Settings ------------------------------------------------------------

  Future<String?> readSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> writeSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(Setting(key: key, value: value));

  Future<bool> get isOnboarded async =>
      await readSetting(SettingKeys.onboarded) == 'true';

  /// Hatırlatma ayarları; kayıt yoksa varsayılanlar döner.
  Stream<ReminderSettings> watchReminderSettings() {
    return select(settings).watch().map((rows) {
      final map = {for (final row in rows) row.key: row.value};
      return ReminderSettings(
        asked: map[SettingKeys.remindersAsked] == 'true',
        enabled: map[SettingKeys.remindersEnabled] == 'true',
        hour: int.tryParse(map[SettingKeys.reminderHour] ?? '') ??
            ReminderSettings.defaultHour,
      );
    });
  }

  Future<void> saveReminderSettings(ReminderSettings value) async {
    await transaction(() async {
      await writeSetting(SettingKeys.remindersAsked, '${value.asked}');
      await writeSetting(SettingKeys.remindersEnabled, '${value.enabled}');
      await writeSetting(SettingKeys.reminderHour, '${value.hour}');
    });
  }

  /// Bekleyen tekrar görevleri, en yakın tarihten başlayarak.
  ///
  /// Bildirim kurmak için kullanılıyor; bugünün listesinden farklı olarak
  /// ileri tarihli görevleri de içerir.
  Stream<List<TaskItem>> watchUpcomingReviews({int limit = 40}) {
    final query = select(tasks).join([
      leftOuterJoin(topics, topics.id.equalsExp(tasks.topicId)),
      leftOuterJoin(subjects, subjects.id.equalsExp(topics.subjectId)),
    ])
      ..where(tasks.done.equals(false))
      ..orderBy([OrderingTerm(expression: tasks.dueOn)])
      ..limit(limit);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => TaskItem(
                  task: row.readTable(tasks),
                  topic: row.readTableOrNull(topics),
                  subject: row.readTableOrNull(subjects),
                ),
              )
              .toList(),
        );
  }

  /// Kurulum ve tanıtımın durumu; yönlendirici hangi ekranın gösterileceğine
  /// buna bakarak karar verir. Tek seferlik okuma yerine
  /// akış olmasının sebebi: kurulum bitince ya da veri silinince kimse `go()`
  /// çağırmadan kullanıcının yeri değişsin.
  Stream<SetupState> watchSetupState() {
    return select(settings).watch().map((rows) {
      final map = {for (final row in rows) row.key: row.value};
      return SetupState(
        onboarded: map[SettingKeys.onboarded] == 'true',
        tourSeen: map[SettingKeys.tourSeen] == 'true',
      );
    });
  }

  // --- Reads ---------------------------------------------------------------

  // NOT: Aşağıdaki sorguların tamamı isme göre değil, açık `position`
  // sütununa göre sıralar. SQLite'ın varsayılan BINARY karşılaştırması Türkçe
  // metni yanlış sıralıyor — ç, ğ, ı, ö, ş, ü harflerinin hepsi z'den sonra
  // geliyor, yani "Çember" ile "Vektörler" ters diziliyor. İsme göre sıralama
  // ya da arama eklediğimiz gün yerel duyarlı bir karşılaştırma gerekecek;
  // planım özel bir collation kaydetmek değil, ekleme sırasında yazılan
  // normalize edilmiş bir `nameKey` sütunu tutmak: collation veritabanı
  // açılmadan önce var olmak zorunda ve `drift_flutter`'ın bağlantı kurulumunu
  // bozuyor.

  Stream<List<Subject>> watchSubjects() {
    return (select(subjects)
          ..where((s) => s.archived.equals(false))
          ..orderBy([(s) => OrderingTerm(expression: s.position)]))
        .watch();
  }

  Stream<List<Topic>> watchTopics(int subjectId) {
    return (select(topics)
          ..where((t) => t.subjectId.equals(subjectId))
          ..orderBy([(t) => OrderingTerm(expression: t.position)]))
        .watch();
  }

  /// Ders kimliğine göre konu sayıları. Her ders için ayrı sorgu atmak yerine
  /// tek gruplanmış sorguyla çözülür.
  Stream<Map<int, int>> watchTopicCounts() {
    final total = topics.id.count();
    final query = selectOnly(topics)
      ..addColumns([topics.subjectId, total])
      ..groupBy([topics.subjectId]);
    return query.watch().map(
          (rows) => {
            for (final row in rows)
              row.read(topics.subjectId)!: row.read(total) ?? 0,
          },
        );
  }

  /// Bir görev satırı, bağlı olduğu konu ve dersle birlikte.
  ///
  /// Liste her satırda ders rengini ve konu adını gösterdiği için üçlü join
  /// tek sorguda yapılır; alternatif, her görev için ayrı sorgu atmaktı.
  Stream<List<TaskItem>> watchTasksUpTo(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);

    final query = select(tasks).join([
      leftOuterJoin(topics, topics.id.equalsExp(tasks.topicId)),
      leftOuterJoin(subjects, subjects.id.equalsExp(topics.subjectId)),
    ])
      ..where(
        tasks.dueOn.isSmallerOrEqualValue(dayStart) &
            // Geçmiş günlerde tamamlanmış işler listeyi şişirmesin: bugün
            // tamamlananlar kalsın ki kullanıcı yaptığını görebilsin.
            (tasks.done.equals(false) |
                tasks.completedAt.isBiggerOrEqualValue(dayStart)),
      )
      ..orderBy([
        OrderingTerm(expression: tasks.done),
        OrderingTerm(expression: tasks.dueOn),
        OrderingTerm(expression: tasks.id),
      ]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => TaskItem(
                  task: row.readTable(tasks),
                  topic: row.readTableOrNull(topics),
                  subject: row.readTableOrNull(subjects),
                ),
              )
              .toList(),
        );
  }

  // --- Writes --------------------------------------------------------------

  Future<int> addSubject({
    required String name,
    int colorIndex = 0,
    int? position,
  }) async {
    return into(subjects).insert(
      SubjectsCompanion.insert(
        name: name,
        colorIndex: Value(colorIndex),
        position: Value(position ?? await _nextSubjectPosition()),
      ),
    );
  }

  Future<int> addTopic({
    required int subjectId,
    required String name,
    int position = 0,
  }) {
    return into(topics).insert(
      TopicsCompanion.insert(
        subjectId: subjectId,
        name: name,
        position: Value(position),
      ),
    );
  }

  Future<void> updateSubject(
    int id, {
    required String name,
    required int colorIndex,
  }) {
    return (update(subjects)..where((s) => s.id.equals(id))).write(
      SubjectsCompanion(name: Value(name), colorIndex: Value(colorIndex)),
    );
  }

  /// Dersi ve altındaki her şeyi siler.
  ///
  /// Cascade kuralları konuları, çalışma kayıtlarını ve görevleri zaten
  /// götürüyor; bu yüzden burada tek satırlık bir silme yetiyor.
  Future<void> deleteSubject(int id) =>
      (delete(subjects)..where((s) => s.id.equals(id))).go();

  Future<void> updateTopic(int id, {required String name}) {
    return (update(topics)..where((t) => t.id.equals(id)))
        .write(TopicsCompanion(name: Value(name)));
  }

  Future<void> deleteTopic(int id) =>
      (delete(topics)..where((t) => t.id.equals(id))).go();

  /// Bir dersin sonraki konu sırası.
  Future<int> nextTopicPosition(int subjectId) async {
    final highest = topics.position.max();
    final query = selectOnly(topics)
      ..addColumns([highest])
      ..where(topics.subjectId.equals(subjectId));
    return ((await query.getSingle()).read(highest) ?? -1) + 1;
  }

  Future<int> _nextSubjectPosition() async {
    final highest = subjects.position.max();
    final query = selectOnly(subjects)..addColumns([highest]);
    return ((await query.getSingle()).read(highest) ?? -1) + 1;
  }

  Future<int> addTask({
    required String title,
    required DateTime dueOn,
    int? topicId,
    TaskSource source = TaskSource.manual,
    int reviewStep = 0,
  }) {
    return into(tasks).insert(
      TasksCompanion.insert(
        title: title,
        dueOn: DateTime(dueOn.year, dueOn.month, dueOn.day),
        topicId: Value(topicId),
        source: Value(source),
        reviewStep: Value(reviewStep),
      ),
    );
  }

  /// Görevi tamamlar ya da tamamlamayı geri alır.
  ///
  /// [Tasks.completedAt] yalnızca burada yazılır; geri alındığında temizlenir,
  /// aksi hâlde bugün tamamlanıp geri alınan bir görev listede takılı kalırdı.
  Future<void> setTaskDone(int id, {required bool done}) async {
    await transaction(() async {
      final task =
          await (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (task == null) return;

      await (update(tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          done: Value(done),
          completedAt: Value(done ? DateTime.now() : null),
        ),
      );

      // Zincirin kapandığı yer: bir tekrar tamamlandığında bir sonraki
      // kendiliğinden planlanır. Kullanıcı hiçbir zaman "sıradaki tekrarı
      // kur" diye bir düğmeye basmaz.
      if (done && task.source == TaskSource.review && task.topicId != null) {
        await _scheduleReview(
          topicId: task.topicId!,
          lastStep: task.reviewStep,
        );
      }
    });
  }

  /// Konuya bağlı bir görevi "çalıştım" diyerek tamamlar.
  ///
  /// Öğrencinin yaptığını söylemesinin iki yolu vardı ve sonuçları farklıydı:
  /// listedeki kutuyu işaretlemek görevi kapatıyor ama çalışma kaydı
  /// üretmiyordu; yani tekrar hiç planlanmıyordu. Öğrenci konuyu çalışıp
  /// işaretliyor, uygulama ise onu hiç çalışmamış sayıyordu — uygulamanın
  /// asıl vaadi tam da burada sessizce kırılıyordu.
  ///
  /// Artık konuya bağlı bir görevi tamamlamak çalışma kaydı yazar; kayıt da
  /// tekrarı planlar. Konusu olmayan işler ("kalem al") eskisi gibi yalnızca
  /// kapanır.
  Future<void> completeTaskAsStudied(
    int taskId, {
    required int minutes,
    int? questionsSolved,
    int? questionsWrong,
    String? note,
  }) async {
    final task =
        await (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return;

    if (task.topicId != null) {
      await logStudySession(
        topicId: task.topicId!,
        minutes: minutes,
        questionsSolved: questionsSolved,
        questionsWrong: questionsWrong,
        note: note,
      );
    }
    await setTaskDone(taskId, done: true);
  }

  /// Görevin başlığını, gününü ve kısa notunu günceller.
  ///
  /// Boş not `null` olarak saklanır ki "notu var mı" kontrolü her yerde tek
  /// biçimde yapılabilsin — konu notunda da aynı kural geçerli.
  Future<void> updateTask(
    int id, {
    String? title,
    DateTime? dueOn,
    String? note,
  }) {
    final trimmedNote = note?.trim();
    return (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        title: title == null ? const Value.absent() : Value(title.trim()),
        dueOn: dueOn == null
            ? const Value.absent()
            : Value(DateTime(dueOn.year, dueOn.month, dueOn.day)),
        note: note == null
            ? const Value.absent()
            : Value(trimmedNote!.isEmpty ? null : trimmedNote),
      ),
    );
  }

  /// Görevi ileri bir güne atar ve kaç kez ertelendiğini sayar.
  ///
  /// Sayaç şimdilik yalnızca veri: sürekli ertelenen konuları ileride tekrar
  /// motoruna ve haftalık özete taşıyacağız.
  Future<void> snoozeTask(int id, {int days = 1}) async {
    final task = await (select(tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (task == null) return;

    final next = task.dueOn.add(Duration(days: days));
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        dueOn: Value(DateTime(next.year, next.month, next.day)),
        snoozeCount: Value(task.snoozeCount + 1),
      ),
    );
  }

  Future<void> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  /// Son [days] günün günlük çalışma dakikaları, bugünden geriye doğru.
  ///
  /// Boş günler de listede 0 olarak yer alır; haftalık özet çubuklarının
  /// eksik gün yüzünden kayması, "bu hafta hiç çalışmadım" hissini bozuyordu.
  Stream<List<DailyMinutes>> watchDailyMinutes({int days = 7}) {
    final start = DateTime.now().subtract(Duration(days: days - 1));
    final startOfDay = DateTime(start.year, start.month, start.day);

    return (select(studySessions)
          ..where((s) => s.studiedAt.isBiggerOrEqualValue(startOfDay)))
        .watch()
        .map((rows) {
      final byDay = <DateTime, int>{};
      for (final row in rows) {
        final day = DateTime(
          row.studiedAt.year,
          row.studiedAt.month,
          row.studiedAt.day,
        );
        byDay[day] = (byDay[day] ?? 0) + row.minutes;
      }

      return [
        for (var i = days - 1; i >= 0; i--)
          () {
            final now = DateTime.now();
            final day = DateTime(now.year, now.month, now.day - i);
            return DailyMinutes(day: day, minutes: byDay[day] ?? 0);
          }(),
      ];
    });
  }

  /// Önümüzdeki [days] günün planı: her gün ve o güne düşen işler.
  ///
  /// Plan ekranı bunu doğrudan çiziyor. Boş günler de listede: planın hangi
  /// günleri boş bıraktığını görmek, planın kendisi kadar bilgi veriyor.
  Stream<List<PlannedDay>> watchUpcomingDays({int days = 14}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(start.year, start.month, start.day + days);

    final query = select(tasks).join([
      leftOuterJoin(topics, topics.id.equalsExp(tasks.topicId)),
      leftOuterJoin(subjects, subjects.id.equalsExp(topics.subjectId)),
    ])
      ..where(
        tasks.dueOn.isBiggerOrEqualValue(start) &
            tasks.dueOn.isSmallerThanValue(end),
      )
      ..orderBy([
        OrderingTerm(expression: tasks.dueOn),
        OrderingTerm(expression: tasks.source),
        OrderingTerm(expression: tasks.id),
      ]);

    return query.watch().map((rows) {
      final byDay = <DateTime, List<TaskItem>>{};
      for (final row in rows) {
        final task = row.readTable(tasks);
        final day = DateTime(task.dueOn.year, task.dueOn.month, task.dueOn.day);
        byDay.putIfAbsent(day, () => []).add(
              TaskItem(
                task: task,
                topic: row.readTableOrNull(topics),
                subject: row.readTableOrNull(subjects),
              ),
            );
      }

      return [
        for (var i = 0; i < days; i++)
          () {
            final day = DateTime(start.year, start.month, start.day + i);
            return PlannedDay(day: day, items: byDay[day] ?? const []);
          }(),
      ];
    });
  }

  /// Ders bazlı çalışma dağılımı: son [days] günde hangi derse kaç dakika.
  ///
  /// Süresi olmayan dersler listeye girmez; grafikte sıfır uzunlukta çubuk
  /// çizmek yer kaplamaktan başka bir işe yaramıyor.
  Stream<List<SubjectMinutes>> watchSubjectMinutes({int days = 7}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - (days - 1));

    final total = studySessions.minutes.sum();
    final query = selectOnly(studySessions).join([
      innerJoin(topics, topics.id.equalsExp(studySessions.topicId)),
      innerJoin(subjects, subjects.id.equalsExp(topics.subjectId)),
    ])
      ..addColumns([subjects.id, subjects.name, subjects.colorIndex, total])
      ..where(studySessions.studiedAt.isBiggerOrEqualValue(start))
      ..groupBy([subjects.id])
      ..orderBy([OrderingTerm(expression: total, mode: OrderingMode.desc)]);

    return query.watch().map(
          (rows) => [
            for (final row in rows)
              SubjectMinutes(
                subjectId: row.read(subjects.id)!,
                name: row.read(subjects.name)!,
                colorIndex: row.read(subjects.colorIndex)!,
                minutes: row.read(total) ?? 0,
              ),
          ],
        );
  }

  /// Tüm konuların ilerleme sayıları.
  Stream<TopicProgress> watchTopicProgress() {
    return select(topics).watch().map((rows) {
      var done = 0;
      var inProgress = 0;
      for (final row in rows) {
        if (row.status == TopicStatus.done) done++;
        if (row.status == TopicStatus.inProgress) inProgress++;
      }
      return TopicProgress(
        total: rows.length,
        done: done,
        inProgress: inProgress,
      );
    });
  }

  /// Kesintisiz çalışma serisi: bugünden (ya da dünden) geriye doğru, en az bir
  /// çalışma kaydı olan ardışık gün sayısı.
  ///
  /// Bugün henüz çalışılmamışsa seri düne kadar sayılır ve bozulmuş sayılmaz;
  /// sabah uygulamayı açan öğrenciye "serin bitti" demek, gün daha
  /// başlamadan cezalandırmak olurdu.
  Stream<int> watchStreak() {
    return select(studySessions).watch().map((rows) {
      if (rows.isEmpty) return 0;

      final days = rows
          .map((r) => DateTime(r.studiedAt.year, r.studiedAt.month, r.studiedAt.day))
          .toSet();

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      var cursor = days.contains(todayStart)
          ? todayStart
          : todayStart.subtract(const Duration(days: 1));

      var streak = 0;
      while (days.contains(cursor)) {
        streak++;
        cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      }
      return streak;
    });
  }

  /// Son [days] günün toplam süresi, çözülen soru ve tamamlanan konu sayısı.
  Stream<WeeklySummary> watchWeeklySummary({int days = 7}) {
    final start = DateTime.now().subtract(Duration(days: days - 1));
    final startOfDay = DateTime(start.year, start.month, start.day);

    final minutes = studySessions.minutes.sum();
    final solved = studySessions.questionsSolved.sum();
    final query = selectOnly(studySessions)
      ..addColumns([minutes, solved])
      ..where(studySessions.studiedAt.isBiggerOrEqualValue(startOfDay));

    return query.watchSingle().map(
          (row) => WeeklySummary(
            minutes: row.read(minutes) ?? 0,
            solved: row.read(solved) ?? 0,
          ),
        );
  }

  /// Konunun durumunu doğrudan değiştirir. Çoğunlukla [setTopicDone]
  /// kullanılır; bu, testler ve içe aktarma gibi durumlar için.
  Future<void> setTopicStatus(int topicId, TopicStatus status) {
    return (update(topics)..where((t) => t.id.equals(topicId)))
        .write(TopicsCompanion(status: Value(status)));
  }

  /// Konuyu bitmiş olarak işaretler ya da işareti kaldırır.
  ///
  /// Arayüzde üç durumlu bir seçici yok: "başlamadım" varsayılan, "çalışıyorum"
  /// ilk çalışma kaydında kendiliğinden yazılıyor. Kullanıcının vereceği tek
  /// gerçek karar "bitirdim mi" olduğu için tek anahtar var; işaret
  /// kaldırıldığında konu, çalışma kaydı varsa "çalışıyorum"a, yoksa
  /// "başlamadım"a döner.
  Future<void> setTopicDone(int topicId, {required bool done}) async {
    if (done) {
      await setTopicStatus(topicId, TopicStatus.done);
      return;
    }

    final count = studySessions.id.count();
    final query = selectOnly(studySessions)
      ..addColumns([count])
      ..where(studySessions.topicId.equals(topicId));
    final hasSessions = ((await query.getSingle()).read(count) ?? 0) > 0;

    await setTopicStatus(
      topicId,
      hasSessions ? TopicStatus.inProgress : TopicStatus.notStarted,
    );
  }

  /// Deneme sonucunu kaydeder.
  ///
  /// Tek işlem: yarım kaydedilmiş bir deneme, netleri yanlış gösterir ve
  /// öğrenci sebebini anlayamaz.
  Future<int> saveMockExam({
    required String name,
    required DateTime takenOn,
    required WrongPenalty penalty,
    required Map<int, ({int correct, int wrong, int blank})> results,
  }) async {
    return transaction(() async {
      final examId = await into(mockExams).insert(
        MockExamsCompanion.insert(
          name: name,
          takenOn: DateTime(takenOn.year, takenOn.month, takenOn.day),
          penalty: Value(penalty.index),
        ),
      );

      for (final entry in results.entries) {
        final value = entry.value;
        // Tamamen boş bırakılan ders kaydedilmiyor: öğrencinin girmediği bir
        // dersi sıfır doğru olarak saklamak, analizi yanlış yönlendirir.
        if (value.correct == 0 && value.wrong == 0 && value.blank == 0) {
          continue;
        }
        await into(mockExamResults).insert(
          MockExamResultsCompanion.insert(
            examId: examId,
            subjectId: entry.key,
            correct: Value(value.correct),
            wrong: Value(value.wrong),
            blank: Value(value.blank),
          ),
        );
      }

      return examId;
    });
  }

  /// Denemeler, en yeniden eskiye.
  Stream<List<MockExam>> watchMockExams() {
    return (select(mockExams)
          ..orderBy([
            (e) => OrderingTerm(expression: e.takenOn, mode: OrderingMode.desc),
            (e) => OrderingTerm(expression: e.id, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Bir denemenin ders sonuçları, ders adı ve rengiyle birlikte.
  Stream<List<SubjectScore>> watchExamScores(int examId) {
    final query = select(mockExamResults).join([
      innerJoin(subjects, subjects.id.equalsExp(mockExamResults.subjectId)),
    ])
      ..where(mockExamResults.examId.equals(examId))
      ..orderBy([OrderingTerm(expression: subjects.position)]);

    return query.watch().map(
          (rows) => [
            for (final row in rows)
              () {
                final result = row.readTable(mockExamResults);
                final subject = row.readTable(subjects);
                return SubjectScore(
                  subjectId: subject.id,
                  name: subject.name,
                  colorIndex: subject.colorIndex,
                  correct: result.correct,
                  wrong: result.wrong,
                  blank: result.blank,
                );
              }(),
          ],
        );
  }

  Future<void> deleteMockExam(int examId) =>
      (delete(mockExams)..where((e) => e.id.equals(examId))).go();

  /// Haftalık planı kurar: eski plan görevlerini silip yenilerini yazar.
  ///
  /// Yalnızca tamamlanmamış plan görevleri silinir — kullanıcının bitirdiği
  /// işleri geçmişten silmek, yaptığı çalışmayı yok saymak olurdu.
  ///
  /// Tek işlem: yarım kalan bir yenileme, kullanıcıyı planı silinmiş ama
  /// yenisi kurulmamış hâlde bırakamaz.
  Future<int> buildWeeklyPlan({
    required Set<int> weekdays,
    required int perDay,
    DateTime? from,
    int weeks = 1,
    Set<int>? onlySubjects,
  }) async {
    return transaction(() async {
      // Yapılmamış plan işlerinin tamamı silinir; geçmişte kalanlar dahil.
      // Aksi hâlde bir hafta plana uymayan öğrenci, yeni planı kurduğunda
      // eski haftadan devreden yirmi "gecikmiş" işle karşılaşıyordu.
      await (delete(tasks)
            ..where(
              (t) => t.source.equalsValue(TaskSource.plan) & t.done.equals(false),
            ))
          .go();

      // Tekrarı bekleyen konular plana girmez: aynı konu hem tekrar hem plan
      // olarak listelenirse öğrenci iki özdeş satır görüp hangisini
      // yapacağını bilemiyor.
      final pendingReviewTopics = (await (select(tasks)
                ..where(
                  (t) =>
                      t.source.equalsValue(TaskSource.review) &
                      t.done.equals(false),
                ))
              .get())
          .map((t) => t.topicId)
          .whereType<int>()
          .toSet();

      final rows = (await (select(topics)
                ..where((t) => t.status.equalsValue(TopicStatus.done).not()))
              .get())
          .where((t) => !pendingReviewTopics.contains(t.id))
          // Deneme sonrası "zayıf derslere odaklan" akışı bu süzgeci
          // kullanıyor: plan yalnızca seçilen derslerin konularından kuruluyor.
          .where((t) => onlySubjects == null || onlySubjects.contains(t.subjectId))
          .toList();

      final plan = WeeklyPlanner.build(
        topics: [
          for (final row in rows)
            PlannableTopic(
              id: row.id,
              subjectId: row.subjectId,
              position: row.position,
            ),
        ],
        weekdays: weekdays,
        perDay: perDay,
        from: from ?? DateTime.now(),
        weeks: weeks,
      );

      final names = {for (final row in rows) row.id: row.name};
      for (final item in plan) {
        await into(tasks).insert(
          TasksCompanion.insert(
            title: names[item.topicId] ?? 'Konu çalışması',
            dueOn: item.dueOn,
            topicId: Value(item.topicId),
            source: const Value(TaskSource.plan),
          ),
        );
      }

      await writeSetting(SettingKeys.planWeekdays, weekdays.join(','));
      await writeSetting(SettingKeys.planPerDay, '$perDay');
      return plan.length;
    });
  }

  /// Kayıtlı plan tercihleri; hiç plan kurulmamışsa `null`.
  Future<({Set<int> weekdays, int perDay})?> readPlanSettings() async {
    final raw = await readSetting(SettingKeys.planWeekdays);
    if (raw == null || raw.isEmpty) return null;

    final weekdays = raw
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    final perDay = int.tryParse(await readSetting(SettingKeys.planPerDay) ?? '');
    if (weekdays.isEmpty || perDay == null) return null;
    return (weekdays: weekdays, perDay: perDay);
  }

  /// Bekleyen plan görevlerinin sayısı; plan kartının özetinde kullanılıyor.
  Stream<int> watchPendingPlanCount() {
    final total = tasks.id.count();
    final query = selectOnly(tasks)
      ..addColumns([total])
      ..where(
        tasks.source.equalsValue(TaskSource.plan) & tasks.done.equals(false),
      );
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  /// Konunun notları, en yeniden eskiye.
  Stream<List<TopicNote>> watchTopicNotes(int topicId) {
    return (select(topicNotes)
          ..where((n) => n.topicId.equals(topicId))
          ..orderBy([
            (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
            // Aynı saniyede yazılan iki not için kimlik sırayı kesinleştiriyor;
            // zaman damgası SQLite'ta saniye hassasiyetinde.
            (n) => OrderingTerm(expression: n.id, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Not ekler. Boş metin yazılmaz; boş bir not satırı listeyi kirletir.
  Future<int?> addTopicNote(int topicId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return into(topicNotes).insert(
      TopicNotesCompanion.insert(topicId: topicId, body: trimmed),
    );
  }

  /// Notu günceller; metin boşaltıldıysa notu siler.
  ///
  /// İçeriği silinmiş bir notu boş bir kart olarak listede tutmak, kullanıcıya
  /// ayrıca "sil" dedirtmek olurdu.
  Future<void> updateTopicNote(int noteId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      await deleteTopicNote(noteId);
      return;
    }
    await (update(topicNotes)..where((n) => n.id.equals(noteId)))
        .write(TopicNotesCompanion(body: Value(trimmed)));
  }

  Future<void> deleteTopicNote(int noteId) =>
      (delete(topicNotes)..where((n) => n.id.equals(noteId))).go();

  /// Konunun not sayısı; liste satırındaki işaret için.
  Stream<Map<int, int>> watchNoteCounts(int subjectId) {
    final total = topicNotes.id.count();
    final query = selectOnly(topicNotes).join([
      innerJoin(topics, topics.id.equalsExp(topicNotes.topicId)),
    ])
      ..addColumns([topicNotes.topicId, total])
      ..where(topics.subjectId.equals(subjectId))
      ..groupBy([topicNotes.topicId]);

    return query.watch().map(
          (rows) => {
            for (final row in rows)
              row.read(topicNotes.topicId)!: row.read(total) ?? 0,
          },
        );
  }

  Stream<List<TopicPhoto>> watchPhotos(int topicId) {
    return (select(topicPhotos)
          ..where((p) => p.topicId.equals(topicId))
          ..orderBy([
            (p) => OrderingTerm(expression: p.addedAt, mode: OrderingMode.desc),
            // Zaman damgası SQLite'ta saniye hassasiyetinde; arka arkaya
            // çekilen iki fotoğraf aynı damgayı alıyor ve sıra belirsiz
            // kalıyordu. Kimlik, sırayı kesinleştiren ikinci ölçüt.
            (p) => OrderingTerm(expression: p.id, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<int> addPhoto({required int topicId, required String relativePath}) {
    return into(topicPhotos).insert(
      TopicPhotosCompanion.insert(
        topicId: topicId,
        relativePath: relativePath,
      ),
    );
  }

  /// Fotoğraf satırını siler ve silinen satırın yolunu döndürür; çağıran taraf
  /// dosyayı da siliyor.
  ///
  /// Dosya silme işini veritabanı katmanına koymadım: burası diske değil
  /// tabloya bakıyor ve testlerde gerçek dosya sistemi istemiyoruz.
  Future<String?> removePhoto(int photoId) async {
    final row = await (select(topicPhotos)..where((p) => p.id.equals(photoId)))
        .getSingleOrNull();
    if (row == null) return null;
    await (delete(topicPhotos)..where((p) => p.id.equals(photoId))).go();
    return row.relativePath;
  }

  /// Konu kimliğine göre fotoğraf sayısı; görev sayfasındaki sayaç için.
  Stream<int> watchPhotoCount(int topicId) {
    final total = topicPhotos.id.count();
    final query = selectOnly(topicPhotos)
      ..addColumns([total])
      ..where(topicPhotos.topicId.equals(topicId));
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  /// Çalışma kaydı ekler ve konuyu buna göre günceller.
  ///
  /// Tek işlem: kayıt yazılıp konu güncellenmezse ilerleme ekranı, gerçekte
  /// çalışılmış bir konuyu "başlanmadı" gösterirdi. Durum yalnızca ileri
  /// gider — tamamlanmış bir konuya tekrar çalışmak onu geri almaz.
  Future<int> logStudySession({
    required int topicId,
    required int minutes,
    int? questionsSolved,
    int? questionsWrong,
    String? note,
  }) async {
    return transaction(() async {
      final id = await into(studySessions).insert(
        StudySessionsCompanion.insert(
          topicId: topicId,
          minutes: minutes,
          questionsSolved: Value(questionsSolved),
          questionsWrong: Value(questionsWrong),
          note: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
        ),
      );

      final topic = await (select(topics)..where((t) => t.id.equals(topicId)))
          .getSingle();

      await (update(topics)..where((t) => t.id.equals(topicId))).write(
        TopicsCompanion(
          lastStudiedAt: Value(DateTime.now()),
          status: topic.status == TopicStatus.notStarted
              ? const Value(TopicStatus.inProgress)
              : const Value.absent(),
        ),
      );

      // Çalışmanın karşılığı tekrardır: kayıt girildiği anda konu merdivene
      // girer. Bekleyen bir tekrar varsa basamağı korunur, yalnızca tarihi
      // yenilenir — bugün çalışılan konuyu yarın tekrar etmek istiyoruz.
      await _scheduleReview(topicId: topicId, lastStep: await _lastStep(topicId));

      return id;
    });
  }

  /// Konuda tamamlanmış son tekrarın basamağı; hiç yoksa
  /// [ReviewLadder.noReviewYet].
  Future<int> _lastStep(int topicId) async {
    final query = select(tasks)
      ..where(
        (t) =>
            t.topicId.equals(topicId) &
            t.source.equalsValue(TaskSource.review) &
            t.done.equals(true),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.reviewStep, mode: OrderingMode.desc),
      ])
      ..limit(1);

    final last = await query.getSingleOrNull();
    return last?.reviewStep ?? ReviewLadder.noReviewYet;
  }

  /// Konu için bekleyen tekrar görevini kurar ya da tarihini yeniler.
  ///
  /// Bir konunun aynı anda yalnızca bir bekleyen tekrarı olur; aksi hâlde
  /// üst üste üç gün çalışan bir öğrencinin günlük listesi aynı konunun üç
  /// tekrarıyla dolardı.
  Future<void> _scheduleReview({
    required int topicId,
    required int lastStep,
  }) async {
    final topic =
        await (select(topics)..where((t) => t.id.equals(topicId))).getSingle();

    final totals = await _totalsFor(topicId);
    final plan = ReviewLadder.planNext(
      lastStep: lastStep,
      accuracy: totals.accuracy,
    );

    final due = DateTime.now().add(Duration(days: plan.days));
    final dueOn = DateTime(due.year, due.month, due.day);

    final pending = await (select(tasks)
          ..where(
            (t) =>
                t.topicId.equals(topicId) &
                t.source.equalsValue(TaskSource.review) &
                t.done.equals(false),
          ))
        .getSingleOrNull();

    if (pending != null) {
      await (update(tasks)..where((t) => t.id.equals(pending.id))).write(
        TasksCompanion(dueOn: Value(dueOn), reviewStep: Value(plan.step)),
      );
      return;
    }

    await into(tasks).insert(
      TasksCompanion.insert(
        title: 'Tekrar: ${topic.name}',
        dueOn: dueOn,
        topicId: Value(topicId),
        source: const Value(TaskSource.review),
        reviewStep: Value(plan.step),
      ),
    );
  }

  /// [watchTopicTotals] ile aynı hesap, tek seferlik okuma olarak.
  Future<TopicTotals> _totalsFor(int topicId) async {
    final minutes = studySessions.minutes.sum();
    final solved = studySessions.questionsSolved.sum();
    final wrong = studySessions.questionsWrong.sum();

    final query = selectOnly(studySessions)
      ..addColumns([minutes, solved, wrong])
      ..where(studySessions.topicId.equals(topicId));

    final row = await query.getSingle();
    return TopicTotals(
      minutes: row.read(minutes) ?? 0,
      solved: row.read(solved) ?? 0,
      wrong: row.read(wrong) ?? 0,
    );
  }

  Stream<List<StudySession>> watchSessions(int topicId) {
    return (select(studySessions)
          ..where((s) => s.topicId.equals(topicId))
          ..orderBy([
            (s) => OrderingTerm(
                  expression: s.studiedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  /// Bir konunun toplam çalışma süresi ve soru sayıları.
  Stream<TopicTotals> watchTopicTotals(int topicId) {
    final minutes = studySessions.minutes.sum();
    final solved = studySessions.questionsSolved.sum();
    final wrong = studySessions.questionsWrong.sum();

    final query = selectOnly(studySessions)
      ..addColumns([minutes, solved, wrong])
      ..where(studySessions.topicId.equals(topicId));

    return query.watchSingle().map(
          (row) => TopicTotals(
            minutes: row.read(minutes) ?? 0,
            solved: row.read(solved) ?? 0,
            wrong: row.read(wrong) ?? 0,
          ),
        );
  }

  /// Ders kimliğine göre tamamlanmış konu sayısı; ilerleme halkaları için.
  Stream<Map<int, int>> watchCompletedTopicCounts() {
    final total = topics.id.count();
    final query = selectOnly(topics)
      ..addColumns([topics.subjectId, total])
      ..where(topics.status.equalsValue(TopicStatus.done))
      ..groupBy([topics.subjectId]);

    return query.watch().map(
          (rows) => {
            for (final row in rows)
              row.read(topics.subjectId)!: row.read(total) ?? 0,
          },
        );
  }

  /// Şablondaki ders ve konuları yazar, ardından kurulumu tamamlanmış olarak
  /// işaretler.
  ///
  /// Tek işlem içinde çalışır: yarıda kalan bir hata, kullanıcıyı yarım
  /// müfredat ve "kurulum tamam" bayrağıyla baş başa bırakamaz.
  /// [StudyTemplate.blank] hiçbir satır yazmaz, yalnızca seçimi kaydeder.
  Future<void> applyTemplate(StudyTemplate template) async {
    await transaction(() async {
      var position = await _nextSubjectPosition();
      for (final subject in template.subjects) {
        final subjectId = await addSubject(
          name: subject.name,
          colorIndex: subject.colorIndex,
          position: position++,
        );
        for (var i = 0; i < subject.topics.length; i++) {
          await addTopic(
            subjectId: subjectId,
            name: subject.topics[i],
            position: i,
          );
        }
      }
      await writeSetting(SettingKeys.templateId, template.id);
      await writeSetting(SettingKeys.onboarded, 'true');
    });
  }

  /// Çalışma geçmişini siler: kayıtlar, görevler ve bekleyen tekrarlar.
  ///
  /// Dersler, konular, notlar ve fotoğraflar kalır. "Bu dönem kötü geçti,
  /// baştan ölçmek istiyorum" durumu için — öğrencinin biriktirdiği bilgiyi
  /// silmeden sayacı sıfırlıyor.
  ///
  /// Konu durumları da başa dönüyor: çalışma kaydı silinmişken bir konunun
  /// "çalışıyorum" görünmesi, hiçbir veriye dayanmayan bir iddia olurdu.
  Future<void> resetStudyHistory() async {
    await transaction(() async {
      await delete(studySessions).go();
      await delete(tasks).go();
      await update(topics).write(
        const TopicsCompanion(
          status: Value(TopicStatus.notStarted),
          lastStudiedAt: Value(null),
        ),
      );
    });
  }

  /// Konu durumlarını sıfırlar; geçmişe dokunmaz.
  ///
  /// Yeni dönem için: konu listesi aynı kalıyor, "hangisini bitirdim"
  /// sayacı başa dönüyor. Çalışma kayıtları duruyor, çünkü geçen dönem
  /// gerçekten çalışıldı ve bu bilgi haftalık özette anlamını koruyor.
  Future<void> resetTopicProgress() async {
    await (update(topics)).write(
      const TopicsCompanion(status: Value(TopicStatus.notStarted)),
    );
  }

  /// Her şeyi siler ve uygulamayı ilk açılış hâline döndürür.
  ///
  /// Fotoğraf dosyaları burada silinmiyor; bu katman diske bakmıyor. Çağıran
  /// taraf silinecek yolları [watchPhotos] yerine bu işlemden önce almalı —
  /// bu yüzden silinen yolların listesi döndürülüyor.
  Future<List<String>> clearAll() async {
    return transaction(() async {
      final photoPaths = (await select(topicPhotos).get())
          .map((p) => p.relativePath)
          .toList();

      await delete(tasks).go();
      await delete(studySessions).go();
      await delete(topicPhotos).go();
      await delete(topics).go();
      await delete(subjects).go();
      await delete(settings).go();

      return photoPaths;
    });
  }
}

/// Listede bir satırı çizmek için gereken her şey.
///
/// [topic] ve [subject] boş olabilir: konuya bağlı olmayan bağımsız görevler
/// de aynı listede görünür.
class TaskItem {
  const TaskItem({required this.task, this.topic, this.subject});

  final Task task;
  final Topic? topic;
  final Subject? subject;

  bool isOverdue(DateTime today) => !task.done && task.dueOn.isBefore(today);

  /// Satırda başlığın altında gösterilecek bağlam etiketi.
  ///
  /// Plan görevlerinin başlığı zaten konu adı; altına bir kez daha konu adını
  /// yazmak satırı kendini tekrar eder hâle getiriyordu ("Sözcükte Anlam"
  /// başlık, altında "Sözcükte Anlam" etiketi). Başlık konu adıyla aynıysa
  /// etiket dersi gösteriyor — böylece satır bir bilgi daha veriyor.
  String? get contextLabel {
    if (subject == null) return null;
    final topicName = topic?.name;
    if (topicName == null) return subject!.name;
    return topicName == task.title ? subject!.name : topicName;
  }
}

/// Bir konunun çalışma toplamları.
class TopicTotals {
  const TopicTotals({
    required this.minutes,
    required this.solved,
    required this.wrong,
  });

  final int minutes;
  final int solved;
  final int wrong;

  bool get hasQuestions => solved > 0;

  /// Doğru oranı; soru girilmemişse `null`. Tekrar motoru 5. günde bu orana
  /// bakarak aralığı kısaltacak.
  double? get accuracy => solved == 0 ? null : (solved - wrong) / solved;
}

/// Hatırlatma tercihleri.
class ReminderSettings {
  const ReminderSettings({
    required this.asked,
    required this.enabled,
    required this.hour,
  });

  /// Akşam etüt saatine denk gelsin diye 19:00. Kullanıcı değiştirebilir.
  static const defaultHour = 19;

  static const initial =
      ReminderSettings(asked: false, enabled: false, hour: defaultHour);

  /// İzin bir kez soruldu mu? Sistem uyarısı ikinci kez gösterilemediği için
  /// bunu kendimiz takip ediyoruz.
  final bool asked;
  final bool enabled;
  final int hour;

  ReminderSettings copyWith({bool? asked, bool? enabled, int? hour}) {
    return ReminderSettings(
      asked: asked ?? this.asked,
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
    );
  }
}

/// Bir günün toplam çalışma süresi.
class DailyMinutes {
  const DailyMinutes({required this.day, required this.minutes});

  final DateTime day;
  final int minutes;
}

/// Haftalık özet kartının sayıları.
class WeeklySummary {
  const WeeklySummary({required this.minutes, required this.solved});

  final int minutes;
  final int solved;

  bool get isEmpty => minutes == 0;
}

/// Kullanıcının kurulum akışında nerede olduğu.
class SetupState {
  const SetupState({required this.onboarded, required this.tourSeen});

  static const initial = SetupState(onboarded: false, tourSeen: false);

  /// Şablon seçimi tamamlandı mı?
  final bool onboarded;

  /// Üç adımlık tanıtım görüldü mü?
  final bool tourSeen;

  bool get isComplete => onboarded && tourSeen;
}

/// Plan ekranındaki bir gün.
class PlannedDay {
  const PlannedDay({required this.day, required this.items});

  final DateTime day;
  final List<TaskItem> items;

  bool get isEmpty => items.isEmpty;
  int get doneCount => items.where((i) => i.task.done).length;
}

/// Bir dersin belirli aralıktaki çalışma süresi.
class SubjectMinutes {
  const SubjectMinutes({
    required this.subjectId,
    required this.name,
    required this.colorIndex,
    required this.minutes,
  });

  final int subjectId;
  final String name;
  final int colorIndex;
  final int minutes;
}

/// Konuların genel ilerlemesi.
class TopicProgress {
  const TopicProgress({
    required this.total,
    required this.done,
    required this.inProgress,
  });

  final int total;
  final int done;
  final int inProgress;

  double get ratio => total == 0 ? 0 : done / total;
  int get notStarted => total - done - inProgress;
}
