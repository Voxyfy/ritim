import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
/// [StudyTemplate] içindeki tek bir ders kaydı.
class TemplateSubject {
  const TemplateSubject({
    required this.name,
    required this.colorIndex,
    required this.topics,
  });

  factory TemplateSubject.fromJson(Map<String, dynamic> json) {
    return TemplateSubject(
      name: json['name'] as String,
      colorIndex: json['colorIndex'] as int? ?? 0,
      topics: (json['topics'] as List<dynamic>? ?? const [])
          .cast<String>()
          .toList(growable: false),
    );
  }

  final String name;
  final int colorIndex;
  final List<String> topics;
}

/// Kurulumda sunulan hazır ders ve konu takımı.
///
/// Şablonlar varlık olarak paketlenen saf veridir, koda gömülü müfredat
/// değildir: bir şablonu uygulamak, sonradan düzenlenebilen ya da silinebilen
/// sıradan kullanıcı satırları yazar. Yeni bir sınav ya da sınıf eklemek, bir
/// JSON dosyası koyup kimliğini [TemplateRepository.assetIds] listesine
/// yazmaktan ibarettir; kod değişmez.
class StudyTemplate {
  const StudyTemplate({
    required this.id,
    required this.name,
    required this.group,
    required this.description,
    required this.subjects,
  });

  factory StudyTemplate.fromJson(Map<String, dynamic> json) {
    return StudyTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      group: json['group'] as String? ?? '',
      description: json['description'] as String? ?? '',
      subjects: (json['subjects'] as List<dynamic>? ?? const [])
          .map((e) => TemplateSubject.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  /// Ayarlarda saklanan kalıcı kimlik; yayınlandıktan sonra değiştirilmez.
  final String id;

  /// Kurulumda olduğu gibi gösterilen ad.
  final String name;

  /// Şablonun kurulumda hangi başlık altında listeleneceği ("Ortaokul",
  /// "Lise ve YKS", "Kamu sınavları"). Gruplama koda gömülü bir switch değil
  /// veri; yeni bir bölüm tek bir JSON alanına mal olur.
  final String group;

  final String description;
  final List<TemplateSubject> subjects;

  /// Hiçbir satır yazmayan "sıfırdan başla" seçeneği. Listenin en başında
  /// durur.
  static const blank = StudyTemplate(
    id: 'blank',
    name: 'Kendin kur',
    group: 'Kendi planın',
    description: 'Derslerini ve konularını kendin ekle.',
    subjects: [],
  );

  int get topicCount =>
      subjects.fold(0, (total, subject) => total + subject.topics.length);

  /// [group] alanına göre gruplanmış şablonlar; hem gruplar arasında hem grup
  /// içinde [assetIds] sırasını korur. Kurulum ekranı bunu doğrudan çizer.
  static Map<String, List<StudyTemplate>> byGroup(
    List<StudyTemplate> templates,
  ) {
    final grouped = <String, List<StudyTemplate>>{};
    for (final template in templates) {
      grouped.putIfAbsent(template.group, () => []).add(template);
    }
    return grouped;
  }
}

/// Uygulamayla gelen şablonları yükler.
///
/// Varlıklar tembel okunur ve süreç boyunca önbellekte tutulur: kurulum ekranı
/// listeyi her yeniden çiziminde ister, bu dosyalar ise çalışma sırasında hiç
/// değişmez.
class TemplateRepository {
  TemplateRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Uygulamayla gelen şablon kimlikleri, kurulumda sunulacakları sırayla:
  /// önce en küçük yaş grubu, sonra sınavlar. Buradaki her kimliğin
  /// `assets/templates/<id>.json` karşılığı olmak zorunda;
  /// `study_template_test.dart` bunu denetler.
  static const assetIds = <String>[
    'ortaokul-5',
    'ortaokul-6',
    'ortaokul-7',
    'lgs8',
    'lise-9',
    'lise-10',
    'lise-11',
    'tyt',
    'ayt-sayisal',
    'ayt-esit-agirlik',
    'ayt-sozel',
    'ydt-ingilizce',
    'kpss-lisans',
    'ags',
    'dgs',
  ];

  final AssetBundle _bundle;
  List<StudyTemplate>? _cache;

  /// Önce [StudyTemplate.blank], ardından paketlenmiş şablonlar.
  ///
  /// Boş seçenek başta: on beş kartın sonuna kadar kaydırmak, kendi derslerini
  /// kuracak kullanıcıyı cezalandırıyordu. Hazır şablon arayan zaten listeyi
  /// gözden geçirecek, kendi kuracak olan ise ilk ekranda çıkışını buluyor.
  Future<List<StudyTemplate>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final loaded = <StudyTemplate>[StudyTemplate.blank];
    for (final id in assetIds) {
      final raw = await _bundle.loadString('assets/templates/$id.json');
      loaded.add(
        StudyTemplate.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      );
    }
    return _cache = List.unmodifiable(loaded);
  }
}
