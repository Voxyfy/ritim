/// Deneme girişindeki bir kutu: dersin doğrusu, yanlışı ya da boşu.
enum CountField { correct, wrong, blank }

/// Bir kutunun adresi: hangi dersin hangi sayısı.
typedef CountCell = ({int subjectId, CountField field});

/// Deneme giriş tuş takımının saf mantığı.
///
/// Widget'tan ayrı duruyor çünkü asıl hız kararları burada: kaç hanede
/// sonraki kutuya geçileceği, baştaki sıfır, geçiş sırası. Bunları widget
/// testinde tuşlara basarak doğrulamak yavaş ve kırılgan olurdu.
///
/// Derslerin soru sayısı veritabanında yok; bu yüzden boş, toplamdan
/// hesaplanamıyor ve isteğe bağlı üçüncü kutu olarak kalıyor. Otomatik geçiş
/// boşu atlıyor: net ve doğru oranı boşa bakmıyor, öğrenciyi her derste
/// fazladan bir kutudan geçirmek girişi yavaşlatırdı.
class ExamEntryPad {
  /// Kutu başına en çok hane.
  ///
  /// Türkiye'deki hiçbir denemede tek dersin 99'dan fazla sorusu yok; iki
  /// hane dolunca kutu başka rakam alamaz, öğrenciyi "Sonraki"ye bastırmadan
  /// geçiyoruz.
  static const maxDigits = 2;

  final _values = <CountCell, String>{};

  /// Tuş takımının yazdığı kutu; `null` ise tuş takımı gizli.
  CountCell? focus;

  String valueOf(CountCell cell) => _values[cell] ?? '';

  int countOf(int subjectId, CountField field) =>
      int.tryParse(valueOf((subjectId: subjectId, field: field))) ?? 0;

  /// Odaktaki kutuya rakam ekler; kutu dolduysa [order] sırasıyla sonrakine
  /// geçer.
  void typeDigit(int digit, List<int> order) {
    final cell = focus;
    if (cell == null) return;
    final current = valueOf(cell);
    // Dolu bir kutuya dokunup yazmak düzeltme demek: eskisinin sonuna
    // eklemek yerine baştan başlıyoruz. Baştaki sıfır da atılıyor.
    final next = current.length >= maxDigits || current == '0'
        ? '$digit'
        : '$current$digit';
    _values[cell] = next;
    // "0"ın arkasına anlamlı bir rakam gelmez; "0 yanlış" tek dokunuş olsun.
    if (next.length >= maxDigits || next == '0') advance(order);
  }

  void backspace() {
    final cell = focus;
    if (cell == null) return;
    final current = valueOf(cell);
    if (current.isEmpty) return;
    _values[cell] = current.substring(0, current.length - 1);
  }

  /// Doğru → yanlış → sonraki dersin doğrusu. Son derste odak kalkar, tuş
  /// takımı iner ve Kaydet ile tüm liste görünür olur.
  void advance(List<int> order) {
    final cell = focus;
    if (cell == null) return;
    if (cell.field == CountField.correct) {
      focus = (subjectId: cell.subjectId, field: CountField.wrong);
      return;
    }
    final index = order.indexOf(cell.subjectId);
    focus = index >= 0 && index + 1 < order.length
        ? (subjectId: order[index + 1], field: CountField.correct)
        : null;
  }

  /// Kaydedilecek sonuçlar. Hiç girilmeyen ders sıfırlarla geliyor; onu
  /// atlamak veritabanının işi (`saveMockExam`).
  Map<int, ({int correct, int wrong, int blank})> results(List<int> order) => {
    for (final id in order)
      id: (
        correct: countOf(id, CountField.correct),
        wrong: countOf(id, CountField.wrong),
        blank: countOf(id, CountField.blank),
      ),
  };
}
