/// Plana girecek konunun ihtiyaç duyulan alanları.
///
/// Veritabanı satırı yerine sade bir kayıt: planlayıcı saf kalsın, testi
/// veritabanı kurmadan yazılabilsin diye.
class PlannableTopic {
  const PlannableTopic({
    required this.id,
    required this.subjectId,
    required this.position,
  });

  final int id;
  final int subjectId;

  /// Konunun ders içindeki sırası. Müfredat sırası korunur; planlayıcı konu
  /// seçmez, yalnızca sıradakileri güne dağıtır.
  final int position;
}

/// Planın tek bir satırı: hangi konu, hangi gün.
class PlannedItem {
  const PlannedItem({required this.topicId, required this.dueOn});

  final int topicId;
  final DateTime dueOn;

  @override
  String toString() => 'PlannedItem($topicId, ${dueOn.toIso8601String()})';
}

/// Haftalık çalışma planı üretir.
///
/// Öğrencinin elinde 41 konu ve boş bir gün var; aradaki köprü bu. Plan yeni
/// bir iş icat etmez, mevcut konuları seçilen günlere dağıtır.
///
/// Kurallar:
/// - Yalnızca bitmemiş konular girer; tamamlanmış konu tekrar motorunun işi.
/// - Dersler sırayla dolaşılır, böylece bir güne aynı dersten üç konu
///   düşmez. Bir öğrenciye "bugün 3 matematik" demek, planı ilk gün
///   terk ettiren şeydir.
/// - Ders içinde müfredat sırası korunur.
/// - Üretim tamamen belirlenimci: aynı girdi her zaman aynı planı verir, bu
///   yüzden "planı yenile" beklenmedik bir sonuç doğurmaz.
abstract final class WeeklyPlanner {
  /// Bir günde önerilebilecek en fazla konu. Üstü, planı ilk hafta
  /// terk ettiren miktar.
  static const maxPerDay = 4;

  /// [from] gününden başlayarak [weekdays] günlerine, her güne [perDay] konu
  /// düşecek şekilde plan üretir.
  ///
  /// [weekdays] değerleri [DateTime.monday] - [DateTime.sunday] aralığında.
  /// Boşsa ya da [perDay] sıfırsa boş plan döner.
  static List<PlannedItem> build({
    required List<PlannableTopic> topics,
    required Set<int> weekdays,
    required int perDay,
    required DateTime from,
    int weeks = 1,
  }) {
    if (topics.isEmpty || weekdays.isEmpty || perDay < 1) return const [];

    final ordered = _interleaveBySubject(topics);
    final days = _daysFor(weekdays: weekdays, from: from, weeks: weeks);
    final slots = days.length * perDay.clamp(1, maxPerDay);

    final plan = <PlannedItem>[];
    for (var i = 0; i < ordered.length && i < slots; i++) {
      plan.add(
        PlannedItem(
          topicId: ordered[i].id,
          dueOn: days[i ~/ perDay.clamp(1, maxPerDay)],
        ),
      );
    }
    return plan;
  }

  /// Konuları dersler arasında sırayla dizer: A1, B1, C1, A2, B2, C2…
  ///
  /// Ders sırası ilk görülme sırasına göre; böylece kullanıcının ders
  /// listesindeki düzen planda da korunur.
  static List<PlannableTopic> _interleaveBySubject(List<PlannableTopic> topics) {
    final bySubject = <int, List<PlannableTopic>>{};
    for (final topic in topics) {
      bySubject.putIfAbsent(topic.subjectId, () => []).add(topic);
    }
    for (final list in bySubject.values) {
      list.sort((a, b) => a.position.compareTo(b.position));
    }

    final queues = bySubject.values.toList();
    final result = <PlannableTopic>[];
    var index = 0;
    while (result.length < topics.length) {
      var placed = false;
      for (final queue in queues) {
        if (index < queue.length) {
          result.add(queue[index]);
          placed = true;
        }
      }
      if (!placed) break;
      index++;
    }
    return result;
  }

  /// [from] gününden itibaren seçilen hafta günlerine denk gelen tarihler.
  ///
  /// Bugün seçili günlerden biriyse plana dahil edilir: "pazartesi planı kur"
  /// diyen kullanıcıya "planın yarın başlıyor" demek gereksiz bir gecikme.
  static List<DateTime> _daysFor({
    required Set<int> weekdays,
    required DateTime from,
    required int weeks,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    final days = <DateTime>[];
    for (var i = 0; i < weeks * 7; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      if (weekdays.contains(day.weekday)) days.add(day);
    }
    return days;
  }
}
