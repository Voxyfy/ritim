/// Hızlı ekleme satırının çözümleyicisi.
///
/// "yarın mat türev" gibi tek bir satırdan gün, ders ve konuyu çıkarır.
/// Tamamen cihaz içi ve kural tabanlı: sınav haftasında internetsiz bir
/// öğrencinin de aynı hızla görev girebilmesi gerekiyor.
///
/// Temel ilke: emin olunamayan yerde eşleşme yok. Yanlış derse düşen bir
/// görev, hiç ders seçilmemiş bir görevden daha pahalıya patlar; öğrenci onu
/// fark edip düzeltmek zorunda kalır.
library;

/// Satırdan çıkarılabilen yorum türleri.
enum QuickAddPart { day, subject, topic }

class QuickAddTopic {
  const QuickAddTopic({required this.id, required this.name});

  final int id;
  final String name;
}

class QuickAddSubject {
  const QuickAddSubject({
    required this.id,
    required this.name,
    this.topics = const [],
  });

  final int id;
  final String name;
  final List<QuickAddTopic> topics;
}

/// Girdide bir yoruma harcanan karakter aralığı (`end` hariç).
class QuickAddSpan {
  const QuickAddSpan(this.part, this.start, this.end);

  final QuickAddPart part;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is QuickAddSpan &&
      other.part == part &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(part, start, end);

  @override
  String toString() => 'QuickAddSpan($part, $start, $end)';
}

class QuickAddResult {
  const QuickAddResult({
    required this.title,
    this.dayOffset,
    this.dayLabel,
    this.subjectId,
    this.subjectName,
    this.topicId,
    this.topicName,
    this.spans = const [],
  });

  /// Yorumlanan kelimeler çıkarıldıktan sonra kalan başlık.
  final String title;

  /// Bugünden kaç gün sonra; gün kelimesi yoksa `null`.
  final int? dayOffset;
  final String? dayLabel;
  final int? subjectId;
  final String? subjectName;
  final int? topicId;
  final String? topicName;
  final List<QuickAddSpan> spans;
}

abstract final class QuickAddParser {
  /// [today] yalnızca hafta gününü bulmak için kullanılır. [ignore] içindeki
  /// yorumlar hiç yapılmaz: kullanıcı bir rozeti kaldırdığında o kelime
  /// yeniden başlığın parçası olur.
  static QuickAddResult parse(
    String input, {
    required List<QuickAddSubject> subjects,
    required DateTime today,
    Set<QuickAddPart> ignore = const {},
  }) {
    final tokens = [
      for (final m in RegExp(r'\S+').allMatches(input))
        _Token(m.start, m.end, m.group(0)!, normalize(m.group(0)!)),
    ];
    final used = <int>{};
    final spans = <QuickAddSpan>[];

    void consume(QuickAddPart part, List<int> indexes) {
      used.addAll(indexes);
      for (final i in indexes) {
        spans.add(QuickAddSpan(part, tokens[i].start, tokens[i].end));
      }
    }

    // Gün
    int? dayOffset;
    String? dayLabel;
    if (!ignore.contains(QuickAddPart.day)) {
      for (var i = 0; i < tokens.length && dayOffset == null; i++) {
        final day = _matchDay(tokens, i, today);
        if (day == null) continue;
        dayOffset = day.offset;
        dayLabel = day.label;
        consume(QuickAddPart.day, [for (var k = 0; k < day.length; k++) i + k]);
      }
    }

    // Ders
    QuickAddSubject? subject;
    if (!ignore.contains(QuickAddPart.subject)) {
      for (var i = 0; i < tokens.length && subject == null; i++) {
        if (used.contains(i)) continue;
        final matches = _subjectsFor(tokens[i].norm, subjects);
        if (matches.length != 1) continue;
        subject = matches.single;
        // "fen bilimleri", "din kültürü" gibi tam yazılan adlar tek parça
        // sayılır; yoksa ikinci kelime başlıkta artık kalıyordu.
        final words = _words(subject.name);
        final indexes = [i];
        for (var j = i + 1; j < tokens.length && !used.contains(j); j++) {
          final tk = tokens[j].norm;
          if (tk.length < 2 || !words.any((w) => w.startsWith(tk))) break;
          indexes.add(j);
        }
        consume(QuickAddPart.subject, indexes);
      }
    }

    // Konu: ders bulunduysa onun konularında, bulunmadıysa hepsinde.
    QuickAddTopic? topic;
    var inferredSubject = subject;
    if (!ignore.contains(QuickAddPart.topic)) {
      final pool = [
        for (final s in subject == null ? subjects : [subject])
          for (final t in s.topics) (subject: s, topic: t),
      ];
      final free = [
        for (var i = 0; i < tokens.length; i++)
          if (!used.contains(i) && _topicWorthy(tokens[i].norm)) i,
      ];
      var best = 0;
      var winners = <({QuickAddSubject subject, QuickAddTopic topic})>[];
      final hitsOf = <int, List<int>>{};
      for (final entry in pool) {
        final words = _words(entry.topic.name);
        final hits = [
          for (final i in free)
            if (words.any((w) => _wordMatches(tokens[i].norm, w))) i,
        ];
        if (hits.isEmpty || hits.length < best) continue;
        if (hits.length > best) {
          best = hits.length;
          winners = [];
        }
        winners.add(entry);
        hitsOf[entry.topic.id] = hits;
      }
      if (winners.length == 1) {
        topic = winners.single.topic;
        inferredSubject = winners.single.subject;
        consume(QuickAddPart.topic, hitsOf[topic.id]!);
      } else if (subject == null &&
          winners.isNotEmpty &&
          winners.every((w) => w.subject.id == winners.first.subject.id) &&
          !ignore.contains(QuickAddPart.subject)) {
        // "paragraf" iki Türkçe konusuna uyuyor: konu belirsiz ama ders
        // kesin. Kelime başlıkta kalır, yalnızca ders seçilir.
        inferredSubject = winners.first.subject;
      }
    }

    final rest = [
      for (var i = 0; i < tokens.length; i++)
        if (!used.contains(i)) tokens[i].raw,
    ].join(' ');
    // Konu bulunduysa başlık konunun düzgün yazılmış adıyla başlar:
    // "cuma fizik vektörler 45 dk" → "Vektörler 45 dk".
    final title = topic != null
        ? [topic.name, if (rest.isNotEmpty) rest].join(' ')
        : rest.isNotEmpty
        ? rest
        : subject?.name ?? '';

    spans.sort((a, b) => a.start.compareTo(b.start));
    return QuickAddResult(
      title: _capitalize(title),
      dayOffset: dayOffset,
      dayLabel: dayLabel,
      subjectId: inferredSubject?.id,
      subjectName: inferredSubject?.name,
      topicId: topic?.id,
      topicName: topic?.name,
      spans: spans,
    );
  }

  /// Karşılaştırma biçimi: Türkçe küçük harf, aksansız, yalnız harf/rakam.
  ///
  /// Dart'ın `toLowerCase`'i "I"yı "i" yapar; önce İ/I elle çevrilir. Aksan
  /// atılır çünkü öğrenciler sık sık "turev", "cografya" diye yazıyor.
  static String normalize(String text) {
    final lower = text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final c = String.fromCharCode(rune);
      final plain = _plain[c] ?? c;
      if (RegExp(r'[a-z0-9]').hasMatch(plain)) buffer.write(plain);
    }
    return buffer.toString();
  }

  static const _plain = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', //
    'â': 'a', 'î': 'i', 'û': 'u',
  };

  /// Adı kelimelerine ayırır; "Tarih-1", "T.C." gibi işaretler ayraç sayılır.
  static List<String> _words(String name) => name
      .split(RegExp(r"[\s\-.,:'’()/]+"))
      .map(normalize)
      .where((w) => w.isNotEmpty)
      .toList();

  /// Ders adlarının önekle yakalanamayan kısaltmaları. Değerler ad
  /// kelimelerinin önekleri; lisede "Türkçe" dersi "Türk Dili ve Edebiyatı".
  static const _subjectAliases = {
    'tr': ['turkce', 'edebiyat'],
    'turkce': ['turkce', 'edebiyat'],
    'tde': ['edebiyat'],
    'edb': ['edebiyat'],
    'eng': ['ingilizce'],
  };

  static List<QuickAddSubject> _subjectsFor(
    String token,
    List<QuickAddSubject> subjects,
  ) {
    final aliases = _subjectAliases[token];
    if (aliases == null && token.length < 3) return const [];
    if (_stopWords.contains(token)) return const [];
    return [
      for (final s in subjects)
        if (_words(s.name).any(
          (w) =>
              _wordMatches(token, w, minLength: 3) ||
              (aliases?.any(w.startsWith) ?? false),
        ))
          s,
    ];
  }

  /// Kelime öneki iki yönlü: "mat" → "matematik", "türevi" → "türev".
  static bool _wordMatches(String token, String word, {int minLength = 4}) =>
      (token.length >= minLength && word.startsWith(token)) ||
      (word.length >= 4 && token.startsWith(word));

  /// Görev cümlelerinde sık geçen ama konu adı olmayan kelimeler. Bunlar
  /// eşleşseydi "denklem çözme" gibi konular her "soru çöz" yazana düşerdi.
  static const _stopWords = {
    'test',
    'soru',
    'coz',
    'cozme',
    'calis',
    'calisma',
    'tekrar',
    'deneme',
    'konu',
    'odev',
    'bitir',
    'oku',
    'yap',
    'dakika',
    'saat',
    'sayfa',
    'tarama',
    'ozet',
    'not',
    'notlar',
  };

  static bool _topicWorthy(String token) =>
      token.length >= 4 &&
      !_stopWords.contains(token) &&
      !RegExp(r'\d').hasMatch(token);

  // Gün kelimeleri, kısaltmadan uzuna değil uzundan kısaya: "cumartesi"
  // "cuma"dan önce denenmeli.
  static const _weekdays = <String, int>{
    'pazartesi': DateTime.monday,
    'cumartesi': DateTime.saturday,
    'carsamba': DateTime.wednesday,
    'persembe': DateTime.thursday,
    'pazar': DateTime.sunday,
    'cuma': DateTime.friday,
    'sali': DateTime.tuesday,
  };

  static const _weekdayShort = <String, int>{
    'pzt': DateTime.monday,
    'sal': DateTime.tuesday,
    'car': DateTime.wednesday,
    'crs': DateTime.wednesday,
    'per': DateTime.thursday,
    'prs': DateTime.thursday,
    'cum': DateTime.friday,
    'cmt': DateTime.saturday,
    'paz': DateTime.sunday,
  };

  static const _weekdayLabels = {
    DateTime.monday: 'Pazartesi',
    DateTime.tuesday: 'Salı',
    DateTime.wednesday: 'Çarşamba',
    DateTime.thursday: 'Perşembe',
    DateTime.friday: 'Cuma',
    DateTime.saturday: 'Cumartesi',
    DateTime.sunday: 'Pazar',
  };

  /// "cumaya", "salıya", "yarına" gibi yönelme/bulunma ekleri.
  static const _suffixes = {
    '', 'a', 'e', 'ya', 'ye', 'i', 'yi', 'da', 'de', 'ta', 'te', 'dan', //
    'den', 'ki',
  };

  static bool _isWord(String token, String stem) =>
      token.startsWith(stem) &&
      _suffixes.contains(token.substring(stem.length));

  static ({int offset, String label, int length})? _matchDay(
    List<_Token> tokens,
    int i,
    DateTime today,
  ) {
    final tk = tokens[i].norm;
    if (_isWord(tk, 'bugun')) return (offset: 0, label: 'Bugün', length: 1);
    if (_isWord(tk, 'yarin')) return (offset: 1, label: 'Yarın', length: 1);
    if (_isWord(tk, 'oburgun')) {
      return (offset: 2, label: 'Öbür gün', length: 1);
    }
    if (tk == 'obur' &&
        i + 1 < tokens.length &&
        _isWord(tokens[i + 1].norm, 'gun')) {
      return (offset: 2, label: 'Öbür gün', length: 2);
    }

    int? weekday = _weekdayShort[tk];
    if (weekday == null) {
      for (final entry in _weekdays.entries) {
        if (_isWord(tk, entry.key)) {
          weekday = entry.value;
          break;
        }
      }
    }
    if (weekday == null) return null;
    // Bugünün adı yazıldıysa gelecek hafta kastediliyor; bugün için
    // "bugün" kelimesi var.
    final diff = (weekday - today.weekday) % 7;
    return (
      offset: diff == 0 ? 7 : diff,
      label: _weekdayLabels[weekday]!,
      length: 1,
    );
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    final first = switch (text[0]) {
      'i' => 'İ',
      'ı' => 'I',
      final c => c.toUpperCase(),
    };
    return first + text.substring(1);
  }
}

class _Token {
  const _Token(this.start, this.end, this.raw, this.norm);

  final int start;
  final int end;
  final String raw;
  final String norm;
}
