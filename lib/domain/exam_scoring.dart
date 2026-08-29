/// Yanlışın doğruyu götürme kuralı.
///
/// Sınavdan sınava değişiyor ve net hesabının tamamı buna bağlı:
/// - LGS'de 3 yanlış 1 doğruyu götürür,
/// - YKS'de (TYT/AYT/YDT) 4 yanlış 1 doğruyu götürür,
/// - KPSS, AGS ve DGS'de yanlış doğruyu götürmez.
///
/// Kural sınavla birlikte saklanıyor, uygulama genelinde sabit değil: bir
/// öğrenci hem LGS hem bursluluk denemesi çözebiliyor ve ikisi farklı
/// hesaplanıyor.
enum WrongPenalty {
  /// Yanlış doğruyu götürmez (KPSS, AGS, DGS).
  none(0),

  /// Üç yanlış bir doğruyu götürür (LGS).
  oneInThree(3),

  /// Dört yanlış bir doğruyu götürür (YKS).
  oneInFour(4);

  const WrongPenalty(this.denominator);

  /// Kaç yanlışın bir doğruyu götürdüğü; [none] için sıfır.
  final int denominator;

  /// Seçim kutusunda görünen kısa ad.
  ///
  /// Üç seçenek eşit genişlikte kutularda yan yana duruyor; uzunlukları
  /// birbirinden çok farklı olunca biri sıkışıp iki satıra düşüyor ve satır
  /// orantısız görünüyordu. Ayrıntı, kutunun altındaki tek açıklama
  /// satırında.
  String get shortLabel => switch (this) {
        WrongPenalty.none => 'Yok',
        WrongPenalty.oneInThree => '3 yanlış',
        WrongPenalty.oneInFour => '4 yanlış',
      };

  /// Seçili kuralı anlatan tam cümle.
  String get label => switch (this) {
        WrongPenalty.none => 'Yanlış doğruyu götürmez',
        WrongPenalty.oneInThree => '3 yanlış 1 doğruyu götürür',
        WrongPenalty.oneInFour => '4 yanlış 1 doğruyu götürür',
      };

  /// Kuralın hangi sınavda geçerli olduğu; seçimi doğrulamayı kolaylaştırıyor.
  String get examples => switch (this) {
        WrongPenalty.none => 'KPSS, AGS, DGS',
        WrongPenalty.oneInThree => 'LGS',
        WrongPenalty.oneInFour => 'TYT, AYT, YDT',
      };

  /// Kurulumda seçilen şablona göre makul varsayılan.
  ///
  /// Öğrenciye sınav kuralını sormak yerine bildiğimizden başlıyoruz; yine de
  /// değiştirilebilir, çünkü şablon dışında deneme çözmek yaygın.
  static WrongPenalty forTemplate(String? templateId) => switch (templateId) {
        'lgs8' => WrongPenalty.oneInThree,
        'tyt' || 'ayt-sayisal' || 'ayt-esit-agirlik' || 'ayt-sozel' ||
        'ydt-ingilizce' =>
          WrongPenalty.oneInFour,
        _ => WrongPenalty.none,
      };
}

/// Bir dersin deneme sonucu.
class SubjectScore {
  const SubjectScore({
    required this.subjectId,
    required this.name,
    required this.colorIndex,
    required this.correct,
    required this.wrong,
    required this.blank,
  });

  final int subjectId;
  final String name;
  final int colorIndex;
  final int correct;
  final int wrong;
  final int blank;

  int get total => correct + wrong + blank;
}

/// Bir dersin hesaplanmış sonucu.
class SubjectAnalysis {
  const SubjectAnalysis({
    required this.score,
    required this.net,
    required this.accuracy,
  });

  final SubjectScore score;

  /// Ceza düşülmüş net.
  final double net;

  /// Doğru oranı: doğru / (doğru + yanlış). Boşlar hesaba katılmaz.
  ///
  /// Boşları dahil etmek, hiç soru çözmeyen bir öğrencinin oranını sıfıra
  /// çekip "çok yanlış yapıyor" gibi gösterirdi; oysa o soruya hiç
  /// dokunmamış. Boş bir bilgi eksiği, yanlış ise bir yanılgı.
  final double? accuracy;

  /// Cevaplanmış soru sayısı.
  int get answered => score.correct + score.wrong;
}

/// Deneme sonucundan net ve zayıf ders çıkarımı.
abstract final class ExamScoring {
  /// Net hesabı: doğru - yanlış / ceza böleni.
  ///
  /// Sonuç negatife düşebilir ve düşmesine izin veriliyor: sınav böyle
  /// hesaplıyor, uygulamanın öğrenciye gerçeği yumuşatması doğru olmaz.
  static double net(int correct, int wrong, WrongPenalty penalty) {
    if (penalty == WrongPenalty.none) return correct.toDouble();
    return correct - wrong / penalty.denominator;
  }

  static SubjectAnalysis analyse(SubjectScore score, WrongPenalty penalty) {
    final answered = score.correct + score.wrong;
    return SubjectAnalysis(
      score: score,
      net: net(score.correct, score.wrong, penalty),
      accuracy: answered == 0 ? null : score.correct / answered,
    );
  }

  /// Denemenin toplam neti.
  static double totalNet(
    Iterable<SubjectScore> scores,
    WrongPenalty penalty,
  ) {
    return scores.fold(
      0,
      (sum, score) => sum + net(score.correct, score.wrong, penalty),
    );
  }

  /// En zayıf dersler, en zayıftan başlayarak.
  ///
  /// Sıralama nete değil **doğru oranına** göre: 40 soruluk matematikte 20 net,
  /// 10 soruluk din kültüründe 8 netten daha iyi görünür ama oran tersini
  /// söyler. Zayıflık, soru sayısından bağımsız bir ölçü olmalı.
  ///
  /// Hiç cevaplanmamış dersler listeye girmez: boş bırakılan bir ders hakkında
  /// söyleyecek bir şeyimiz yok.
  static List<SubjectAnalysis> weakest(
    Iterable<SubjectScore> scores,
    WrongPenalty penalty, {
    int limit = 3,
  }) {
    final analysed = scores
        .map((score) => analyse(score, penalty))
        .where((analysis) => analysis.accuracy != null)
        .toList()
      ..sort((a, b) => a.accuracy!.compareTo(b.accuracy!));

    return analysed.take(limit).toList();
  }
}
