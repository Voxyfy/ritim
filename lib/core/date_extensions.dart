import 'package:intl/intl.dart';

/// Gün bazlı tarih yardımcıları.
///
/// Uygulamanın tamamı görevleri güne göre planlar, saate göre değil. Bu yüzden
/// karşılaştırmaya giren her [DateTime] önce [dateOnly] ile yerel gece yarısına
/// indirilir; aksi hâlde "bugün" sorgusu satırın yazıldığı saate göre kayar.
extension DateOnly on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  DateTime addDays(int days) => DateTime(year, month, day + days);
}

/// Bugünün yerel gece yarısı.
DateTime today() => DateTime.now().dateOnly;

/// "29 Ağustos Cumartesi" — ekran başlıklarında kullanılır.
String formatLongDate(DateTime date) =>
    DateFormat('d MMMM EEEE', 'tr_TR').format(date);

/// Geciken görevlerde "3 gün gecikti" gibi kısa bir ifade üretir.
String formatOverdue(DateTime dueOn, {DateTime? now}) {
  final days = (now ?? today()).dateOnly.difference(dueOn.dateOnly).inDays;
  if (days <= 0) return '';
  if (days == 1) return 'Dün';
  return '$days gün gecikti';
}

/// Dakikayı "40 dk" / "2 sa" / "1 sa 20 dk" olarak yazar.
///
/// Üç ayrı yerde aynı biçimlendirme kopyalanmıştı; ufak bir fonksiyon ama
/// kopyalar birbirinden ayrılmaya başlamıştı ("2 sa" ve "2.0 sa").
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes dk';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours sa' : '$hours sa $rest dk';
}
