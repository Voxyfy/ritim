import 'package:drift/drift.dart';

/// Öğrencinin bir konuda hangi aşamada olduğu.
enum TopicStatus { notStarted, inProgress, done }

/// Görevin kaynağı.
///
/// Sıra önemli: değerler veritabanına indeks olarak yazılıyor, araya değer
/// eklemek mevcut satırların anlamını değiştirir. Yeni kaynak hep sona.
enum TaskSource {
  /// Kullanıcının elle yazdığı iş.
  manual,

  /// Tekrar motorunun ürettiği tekrar.
  review,

  /// Haftalık planın güne dağıttığı konu çalışması.
  plan,
}

/// Öğrencinin çalıştığı üst başlık ("Matematik", "Organik Kimya").
///
/// Dersler kullanıcıya aittir; şablonlar yalnızca tohumlar, sabit müfredat
/// gibi davranmaz. Uygulamanın ortaokuldan üniversiteye kadar aynı kalmasının
/// sebebi budur.
@DataClassName('Subject')
class Subjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// Ders renginin `SubjectPalette` içindeki sırası. Renk, onaltılık değer
  /// yerine indeks olarak saklanır; böylece tema baştan boyanırken şema
  /// göçüne gerek kalmaz.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Çalışmanın en küçük birimi ve tekrar motorunun planlama yaptığı birim.
///
/// Notlar ayrı bir defterde değil konuya bağlı durur ([TopicNotes]): bir not
/// ancak tekrar günü konuyla birlikte önüne geldiğinde işe yarar.
@DataClassName('Topic')
class Topics extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get status =>
      intEnum<TopicStatus>().withDefault(const Constant(0))();
  DateTimeColumn get lastStudiedAt => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Bir konuya ait tek çalışma kaydı.
///
/// Zorunlu tek ölçü [minutes]. Soru sayıları bilerek opsiyonel: sınava
/// hazırlanan doldurur, üniversiteli boş geçer; veri yoksa tekrar motoru sabit
/// aralıklara düşer.
@DataClassName('StudySession')
class StudySessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get topicId =>
      integer().references(Topics, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get studiedAt =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get minutes => integer()();
  IntColumn get questionsSolved => integer().nullable()();
  IntColumn get questionsWrong => integer().nullable()();
  TextColumn get note => text().nullable()();
}

/// Günün listesindeki bir satır; elle yazılmış ya da tekrar motorunun
/// planladığı fark etmez, ikisi de burada durur.
@DataClassName('Task')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Konuya bağlı olmayan bağımsız görevlerde boş kalır.
  IntColumn get topicId => integer()
      .nullable()
      .references(Topics, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 160)();

  /// Görevin planlandığı gün, yerel gece yarısına normalize edilir. Böylece
  /// "bugün" karşılaştırması satırın yazıldığı saate bağlı kalmaz.
  DateTimeColumn get dueOn => dateTime()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get source =>
      intEnum<TaskSource>().withDefault(const Constant(0))();

  /// Göreve iliştirilen kısa not ("kitap s. 42-58").
  ///
  /// Bilerek tek satırlık bir etiket: uzun not ve fotoğraf konuya ait, çünkü
  /// görev tamamlanınca kapanıyor, konu ise tekrar günü geri geliyor.
  TextColumn get note => text().nullable()();

  /// 1-3-7-21 günlük tekrar merdiveninde kaçıncı basamakta olduğumuz; elle
  /// eklenen görevlerde 0.
  IntColumn get reviewStep => integer().withDefault(const Constant(0))();
  IntColumn get snoozeCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Bir konuya yazılmış not.
///
/// Önce konunun kendisinde tek bir metin alanıydı. Haftalarca aynı konuya
/// çalışan öğrenci farklı zamanlarda farklı şeyler fark ediyor ("negatif
/// tabanı karıştırıyorum", "sıfırıncı kuvvet kuralı") ve tek alan bunları tek
/// bir yığına yazmaya zorluyordu; ayrı notlar ayrı ayrı silinebilmeli ve
/// tarihleriyle görünebilmeli.
@DataClassName('TopicNote')
class TopicNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get topicId =>
      integer().references(Topics, #id, onDelete: KeyAction.cascade)();
  TextColumn get body => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Bir konuya iliştirilen görsel.
///
/// Dosyanın kendisi uygulamanın belge klasöründe duruyor, veritabanında
/// yalnızca yolu var: birkaç yüz kilobaytlık fotoğrafları SQLite'a gömmek
/// veritabanını şişirir ve her sorguyu yavaşlatır.
@DataClassName('TopicPhoto')
class TopicPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get topicId =>
      integer().references(Topics, #id, onDelete: KeyAction.cascade)();

  /// Belge klasörüne göre göreli yol. Mutlak yol saklanmıyor: iOS uygulama
  /// klasörünün tam yolu her kurulumda ve yedekten dönüşte değişiyor, mutlak
  /// yol saklayan uygulamalar güncellemeden sonra tüm görselleri kaybediyor.
  TextColumn get relativePath => text()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Çözülen bir deneme sınavı.
///
/// Netler burada saklanmıyor, ham sayılardan hesaplanıyor: yanlış götürme
/// kuralı değişirse (öğrenci sınavı yanlış işaretlemişse) geçmiş denemeler de
/// doğru hesaplanmalı. Türetilmiş değeri saklamak, kuralı değiştiremez hâle
/// getirirdi.
@DataClassName('MockExam')
class MockExams extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  DateTimeColumn get takenOn => dateTime()();

  /// Yanlışın doğruyu götürme kuralı; [WrongPenalty] sırası.
  IntColumn get penalty => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Bir denemede tek bir dersin sonucu.
@DataClassName('MockExamResult')
class MockExamResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get examId =>
      integer().references(MockExams, #id, onDelete: KeyAction.cascade)();

  /// Ders silinirse sonuç da gider; geçmiş deneme, artık var olmayan bir dersin
  /// satırını taşımamalı.
  IntColumn get subjectId =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  IntColumn get correct => integer().withDefault(const Constant(0))();
  IntColumn get wrong => integer().withDefault(const Constant(0))();
  IntColumn get blank => integer().withDefault(const Constant(0))();
}

/// Uygulama düzeyindeki durum için anahtar-değer deposu (kurulum tamamlandı
/// mı, hangi şablon seçildi).
@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
