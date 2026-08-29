import 'dart:math' as math;

/// Bir tekrarın ne zaman ve hangi basamaktan planlanacağı.
class ReviewPlan {
  const ReviewPlan({required this.step, required this.days});

  /// Planlanan tekrarın basamak sırası (0 tabanlı). Bu tekrar tamamlandığında
  /// bir sonraki plan için [ReviewLadder.planNext] girdisi olur.
  final int step;

  /// Bugünden kaç gün sonra tekrar edilecek.
  final int days;

  @override
  String toString() => 'ReviewPlan(step: $step, days: $days)';
}

/// Aralıklı tekrar merdiveni.
///
/// Aralıklar 1-3-7-21 gün. Bu dizi bir hafıza modelinden değil, sınav
/// hazırlığının ritminden geliyor: ertesi gün, hafta içi, hafta sonu, ay
/// başı. SM-2 gibi kuramsal algoritmalar öğrenciden her tekrarda bir "zorluk"
/// puanı ister; buradaki fikir ise puan sormadan, zaten girilen yanlış
/// sayısından ilerlemek.
abstract final class ReviewLadder {
  static const intervals = <int>[1, 3, 7, 21];

  /// Son basamak tekrar ettikten sonra kullanılacak aralık.
  ///
  /// Merdiven bitince tekrar durmaz, aylık ritme oturur.
  static const repeatingInterval = 30;

  /// Bu oranın altında konu geriye düşer.
  static const strugglingBelow = 0.6;

  /// Bu oranın üstünde konu bir üst basamağa çıkar.
  static const confidentAtOrAbove = 0.85;

  /// Hiç tekrar edilmemiş konu için [planNext] girdisi.
  ///
  /// Ayrı bir sabit: "-1" değerinin çağrı yerinde çıplak gezinmesi, ilk
  /// tekrarın neden 1 gün sonra olduğunu okunmaz hâle getiriyordu.
  static const noReviewYet = -1;

  /// Bir sonraki tekrarı planlar.
  ///
  /// [lastStep] tamamlanmış son tekrarın basamağıdır; konu hiç tekrar
  /// edilmemişse [noReviewYet] verilir. [accuracy] konudaki toplam doğru
  /// oranı; soru girilmemişse `null` gelir ve merdiven sabit ilerler — soru
  /// çözmeyen bir üniversite öğrencisi de motordan faydalanabilsin diye.
  ///
  /// Kural üç dallı:
  /// - Oran yüksekse (%85+) bir üst basamağa çıkılır,
  /// - ortadaysa aynı basamak tekrarlanır, aralık uzamaz,
  /// - düşükse (%60 altı) bir basamak geriye düşülür.
  ///
  /// Üç dalda da sonuç 0'ın altına inmez: ilk tekrarda zorlanan öğrenci için
  /// "daha da sık" diye bir aralık yok, en sıkı aralık zaten ertesi gün.
  static ReviewPlan planNext({required int lastStep, double? accuracy}) {
    final nextStep = switch (accuracy) {
      null => lastStep + 1,
      final value when value >= confidentAtOrAbove => lastStep + 1,
      final value when value < strugglingBelow => lastStep - 1,
      _ => lastStep,
    };

    final clamped = math.max(0, nextStep);
    return ReviewPlan(step: clamped, days: intervalForStep(clamped));
  }

  /// Bir basamağın gün karşılığı. Merdivenin sonundan sonrası sabit.
  static int intervalForStep(int step) {
    if (step < 0) return intervals.first;
    if (step >= intervals.length) return repeatingInterval;
    return intervals[step];
  }
}
