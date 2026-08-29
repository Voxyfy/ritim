@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:ritim/core/providers.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';
import 'package:ritim/data/templates/study_template.dart';
import 'package:ritim/domain/exam_scoring.dart';
import 'package:ritim/main.dart';

/// App Store ekran görüntülerini çeken düzenek.
///
/// Bu bir test değil, bir **çekim aracı**; doğrulama yapmaz, PNG üretir.
/// `test/` altında duruyor çünkü gerçek widget ağacını ancak `flutter test`
/// kurabiliyor — simülatörde programatik dokunma yok, `flutter drive` ise
/// bunun için gereğinden ağır.
///
/// Normal koşuda kendini eler: `@Tags(['screenshots'])` ve aşağıdaki
/// `RITIM_SHOTS` kontrolü sayesinde `flutter test` bu dosyaya girmez.
/// Çalıştırmak için:
///
///     RITIM_SHOTS=1 flutter test test/screenshot_capture_test.dart --tags screenshots
///
/// NOT: Ekranların içeriği elle tohumlanıyor. Apple ekran görüntülerinin
/// uygulamayı dürüst temsil etmesini istiyor; bu yüzden veriler uydurma
/// ekranlar değil, gerçek şablondan (LGS 8) kurulmuş gerçek kayıtlar.
void main() {
  // Çekilecek cihaz boyutları. Apple bugün 6.9" istiyor; 6.5" hâlâ kabul
  // edildiği için ikisini birden üretiyoruz ve mağazada hangisi sorulursa
  // hazır oluyor.
  //
  // Ölçüler cihazın mantıksal alanı × 3. Klasör adı doğrudan App Store
  // Connect'teki yuvanın adı olmalı: ilk denemede 1290x2796'yı "6.9" diye
  // etiketlemiştim, oysa o ölçü 6.7" sınıfına ait. Yanlış yuvaya yüklenince
  // mağaza "The dimensions of one or more screenshots are wrong" diyor.
  const boyutlar = <_Cihaz>[
    // iPhone 16/17 Pro Max — bugün zorunlu olan tek iPhone yuvası.
    _Cihaz(ad: 'ios-6.9', mantiksal: Size(440, 956), olcek: 3), // 1320x2868
    // iPhone 14/15 Pro Max, 15/16 Plus.
    _Cihaz(ad: 'ios-6.7', mantiksal: Size(430, 932), olcek: 3), // 1290x2796
    // iPhone 11 Pro Max, XS Max, 11, XR.
    _Cihaz(ad: 'ios-6.5', mantiksal: Size(414, 896), olcek: 3), // 1242x2688
  ];

  late RitimDatabase db;

  setUpAll(() async {
    Intl.defaultLocale = appLocale.toString();
    await initializeDateFormatting(appLocale.toString());
    await _yaziTiplerimiYukle();
  });

  setUp(() => db = RitimDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  for (final cihaz in boyutlar) {
    testWidgets(
      '${cihaz.ad} ekran görüntüleri',
      // Olağan koşuda atlanıyor. Bu dosya doğrulama yapmıyor, dosya üretiyor;
      // her `flutter test` çağrısında çalışması hem koşuyu yavaşlatır hem de
      // depodaki görselleri sessizce değiştirir.
      skip: Platform.environment['RITIM_SHOTS'] != '1',
      (tester) async {
        // Tohumlama gerçek zaman kipinde: `_tohumla` drift akışlarını okuyor
        // ve sahte saat altında akış hiç ilerlemediği için test kilitleniyor.
        // Aynı tuzağa daha önce de düştük; notu README'nin test bölümünde.
        await tester.runAsync(() => _tohumla(db));

        final kok = GlobalKey();
        tester.view.physicalSize = cihaz.mantiksal * cihaz.olcek.toDouble();
        tester.view.devicePixelRatio = cihaz.olcek.toDouble();
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          RepaintBoundary(
            key: kok,
            child: ProviderScope(
              overrides: [databaseProvider.overrideWithValue(db)],
              child: const RitimApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ağaç, veritabanı kapandıktan sonra ayakta kalmasın.
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1));
        });

        Future<void> cek(String dosya) => _pngYaz(
          tester,
          kok,
          'screenshots/${cihaz.ad}/$dosya.png',
          cihaz.olcek.toDouble(),
        );

        Future<void> sekme(String etiket) async {
          await tester.tap(find.text(etiket));
          await tester.pumpAndSettle();
        }

        await cek('01-bugun');

        // Özet kartı kapalı geliyor. Grafikler ürünün en güçlü karesi, o yüzden
        // açıp ayrı bir kare alıyoruz.
        await tester.tap(find.textContaining('Bu hafta'));
        await tester.pumpAndSettle();
        await cek('02-ozet');

        await sekme('Plan');
        await cek('03-plan');
        await sekme('Dersler');
        await cek('04-dersler');
        await sekme('Deneme');
        await cek('05-deneme');

        // Asıl anlatılacak ekran analiz detayı: liste yalnızca netleri
        // sıralıyor, ders bazlı zayıflık burada çıkıyor.
        await tester.tap(find.text('Deneme 7'));
        await tester.pumpAndSettle();
        await cek('06-deneme-analiz');

        // Ağaç test gövdesi biterken sökülüyor. `addTearDown` yetmiyor: flutter
        // "bekleyen zamanlayıcı var mı" denetimini gövde biter bitmez, sökme
        // geri çağrılarından önce yapıyor. Sökmeyi buraya almazsak araç doğru
        // PNG'leri üretiyor ama koşu kırmızı bitiyor.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
}

class _Cihaz {
  const _Cihaz({
    required this.ad,
    required this.mantiksal,
    required this.olcek,
  });
  final String ad;
  final Size mantiksal;
  final int olcek;
}

/// Ağacın o anki hâlini PNG olarak diske yazar.
///
/// `matchesGoldenFile` yerine elle yakalıyoruz: golden karşılaştırıcısı
/// görüntüyü 1x piksel oranıyla alıyor ve 430x932'lik bir dosya üretiyor.
/// Mağaza tam 1290x2796 istiyor, o yüzden `toImage` çağrısını piksel oranını
/// kendimiz vererek yapıyoruz.
Future<void> _pngYaz(
  WidgetTester tester,
  GlobalKey kok,
  String yol,
  double olcek,
) async {
  final sinir =
      kok.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final gorsel = await sinir.toImage(pixelRatio: olcek);
    final bayt = await gorsel.toByteData(format: ui.ImageByteFormat.png);
    final dosya = File(yol)..parent.createSync(recursive: true);
    dosya.writeAsBytesSync(bayt!.buffer.asUint8List());
    gorsel.dispose();
  });
}

/// Gerçek yazı tiplerini teste yükler.
///
/// `flutter test` yalnızca ölçüm amaçlı bir yer tutucu yazı tipi yüklüyor;
/// yüklemezsek ekran görüntülerindeki bütün metinler siyah kutu çıkar.
///
/// Aile adlarını ve dosya yollarını elle yazmak yerine `FontManifest.json`
/// okunuyor. İlk hâlinde yolları tahmin etmiştim ve ikisi de yanlıştı:
/// paket yazı tipleri anahtarda `lib/` bölümünü koruyor ve Phosphor'un
/// düz kesiti `Phosphor` değil `PhosphorRegular` adıyla kayıtlı. Manifest
/// zaten doğru listeyi tutuyorken tahmin etmenin anlamı yok.
Future<void> _yaziTiplerimiYukle() async {
  final ham = await rootBundle.loadString('FontManifest.json');
  final aileler = (jsonDecode(ham) as List).cast<Map<String, dynamic>>();

  for (final aile in aileler) {
    final loader = FontLoader(aile['family'] as String);
    for (final yazi in (aile['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(yazi['asset'] as String));
    }
    await loader.load();
  }
}

/// Ekranların dolu görünmesi için gerçekçi veri kurar.
Future<void> _tohumla(RitimDatabase db) async {
  final sablonlar = await TemplateRepository().load();
  final lgs = sablonlar.firstWhere((s) => s.id == 'lgs8');
  await db.applyTemplate(lgs);
  await db.writeSetting(SettingKeys.tourSeen, 'true');

  final dersler = await db.watchSubjects().first;
  final matematik = dersler.firstWhere((d) => d.name == 'Matematik');
  final matKonulari = await db.watchTopics(matematik.id).first;

  // Çalışma geçmişi haftaya yayılıyor. Tek oturum kaydetmek yetmiyordu:
  // haftalık çubuk grafiğinde yalnızca bir gün doluyor, ders dağılımında tek
  // satır kalıyor ve ekran uygulamayı zayıf gösteriyordu. Bu kayıtlar
  // uydurma ekran değil, gerçek `logStudySession` çağrıları — merdiven de
  // onlara göre kuruluyor.
  //
  // Doğruluk oranları bilerek farklı: %90 ilerleyen, %55 geri düşen ve
  // arada kalan konu birlikte görünsün.
  const gecmis = [
    (ders: 'Matematik', konu: 0, gunOnce: 6, dakika: 45, soru: 30, yanlis: 3),
    (ders: 'Türkçe', konu: 0, gunOnce: 5, dakika: 40, soru: 25, yanlis: 4),
    (
      ders: 'Fen Bilimleri',
      konu: 0,
      gunOnce: 4,
      dakika: 55,
      soru: 32,
      yanlis: 6,
    ),
    (ders: 'Matematik', konu: 1, gunOnce: 3, dakika: 30, soru: 20, yanlis: 9),
    (
      ders: 'T.C. İnkılap Tarihi',
      konu: 0,
      gunOnce: 2,
      dakika: 25,
      soru: 18,
      yanlis: 2,
    ),
    (ders: 'Türkçe', konu: 1, gunOnce: 1, dakika: 35, soru: 22, yanlis: 5),
    (ders: 'Matematik', konu: 2, gunOnce: 0, dakika: 50, soru: 34, yanlis: 4),
  ];

  for (final kayit in gecmis) {
    final ders = dersler.firstWhere((d) => d.name == kayit.ders);
    final konular = await db.watchTopics(ders.id).first;
    if (kayit.konu >= konular.length) continue;

    final oturumId = await db.logStudySession(
      topicId: konular[kayit.konu].id,
      minutes: kayit.dakika,
      questionsSolved: kayit.soru,
      questionsWrong: kayit.yanlis,
    );

    // Oturum tarihi geriye alınıyor: `logStudySession` her zaman "şimdi"
    // yazıyor, biz ise haftanın tamamını göstermek istiyoruz.
    final tarih = DateTime.now().subtract(Duration(days: kayit.gunOnce));
    await db.customStatement(
      'UPDATE study_sessions SET studied_at = ? WHERE id = ?',
      [tarih.millisecondsSinceEpoch ~/ 1000, oturumId],
    );
  }

  // İlerleme halkasının bir şey anlatması için bitmiş konu gerekiyor;
  // "67 konudan 0 tanesi bitti" kimseyi ikna etmez.
  //
  // Bitmiş konular derslere dağıtılıyor. Önce kimliğe göre ilk on bir konu
  // işaretleniyordu; hepsi ilk derse düşüyor ve "Derslerin" ekranı %73'lük
  // tek bir Türkçe ile beş tane %0 gösteriyordu. Gerçek bir öğrencinin
  // ilerlemesi böyle görünmez.
  const bitenSayisi = {
    'Türkçe': 6,
    'Matematik': 4,
    'Fen Bilimleri': 5,
    'T.C. İnkılap Tarihi': 3,
    'İngilizce': 2,
    'Din Kültürü': 1,
  };
  for (final ders in dersler) {
    final adet = bitenSayisi[ders.name] ?? 0;
    if (adet == 0) continue;
    await db.customStatement(
      'UPDATE topics SET status = ? WHERE id IN '
      '(SELECT id FROM topics WHERE subject_id = ? AND status = ? '
      'ORDER BY position LIMIT ?)',
      [TopicStatus.done.index, ders.id, TopicStatus.notStarted.index, adet],
    );
  }

  await db.addTopicNote(
    matKonulari[1].id,
    'Negatif taban parantez içinde değilse üs sadece sayıya gidiyor. '
    'Sınavda iki kere buna takıldım.',
  );

  // Yedi gün birden: ekran görüntüsü hafta içi de hafta sonu da çekilebilir,
  // plan yalnızca hafta içi kurulduğunda pazar günü çekilen kare bomboş
  // çıkıyordu.
  await db.buildWeeklyPlan(
    weekdays: {1, 2, 3, 4, 5, 6, 7},
    perDay: 3,
    weeks: 1,
  );

  // Tekrarlar bugüne çekiliyor: oturumlar az önce kaydedildiği için tekrar
  // günleri yarına düşüyor ve "Bugün" ekranı boş çıkıyor. Ekran görüntüsü
  // uygulamanın olağan gününü göstermeli, ilk beş dakikasını değil.
  final bugun = DateTime.now();
  final gun = DateTime(bugun.year, bugun.month, bugun.day);
  // Yalnızca üç tekrar bugüne çekiliyor, hepsi değil. Tamamını taşıdığımda
  // "Bugün" ekranında yedi tane "Tekrar: ..." satırı yan yana diziliyordu;
  // bu, aralıklı tekrarı anlatmak yerine üst üste yığılmış bir liste
  // gösteriyor ve ürünün vaadinin tam tersini söylüyor.
  await db.customStatement(
    'UPDATE tasks SET due_on = ? WHERE id IN '
    '(SELECT id FROM tasks WHERE source = ? ORDER BY id LIMIT 3)',
    [gun.millisecondsSinceEpoch ~/ 1000, TaskSource.review.index],
  );

  // Bir iş dün kalsın: gecikmiş satırın kendi rengi var ve ekran
  // görüntüsünde bunun görünmesi, uygulamanın seni takip ettiğini anlatıyor.
  final dun = gun.subtract(const Duration(days: 1));
  await db.customStatement(
    'UPDATE tasks SET due_on = ? WHERE id = '
    '(SELECT MAX(id) FROM tasks WHERE source = ? AND done = 0)',
    [dun.millisecondsSinceEpoch ~/ 1000, TaskSource.plan.index],
  );

  // Birkaç iş bitmiş olsun: ilerleme çubuğu ve "bu hafta" özeti ancak
  // tamamlanmış iş varken bir şey anlatıyor.
  //
  // Bitenler bilerek plan işlerinden seçiliyor. Önce en küçük kimlikli iki
  // satır işaretleniyordu; tekrar kayıtları daha önce yazıldığı için hep
  // onlar bitiyor ve uygulamanın imza satırı olan "Tekrar: ..." kapalı
  // "Bitenler" bölümünün altında kalıyordu.
  await db.customStatement(
    'UPDATE tasks SET done = 1, completed_at = ? WHERE id IN '
    '(SELECT id FROM tasks WHERE due_on = ? AND source = ? '
    'ORDER BY id DESC LIMIT 2)',
    [
      gun.millisecondsSinceEpoch ~/ 1000,
      gun.millisecondsSinceEpoch ~/ 1000,
      TaskSource.plan.index,
    ],
  );

  // Beş deneme, haftalık aralıklarla ve yükselen bir eğriyle.
  //
  // Tek deneme kaydetmek listeyi neredeyse boş bırakıyordu; oysa bu ekranın
  // vaadi tam olarak "netin nereye gidiyor" sorusu. Sayılar LGS soru
  // dağılımına uyuyor (Türkçe/Matematik/Fen 20, diğerleri 10) ve öğrenci
  // gerçekçi biçimde bazı derste ilerliyor, bazısında yerinde sayıyor.
  const denemeler = [
    (ad: 'Deneme 3', haftaOnce: 5, tur: 0, mat: 9, fen: 11, sos: 6),
    (ad: 'Deneme 4', haftaOnce: 4, tur: 14, mat: 8, fen: 12, sos: 7),
    (ad: 'Deneme 5', haftaOnce: 3, tur: 15, mat: 11, fen: 13, sos: 7),
    (ad: 'Deneme 6', haftaOnce: 1, tur: 16, mat: 10, fen: 14, sos: 8),
    (ad: 'Deneme 7', haftaOnce: 0, tur: 17, mat: 13, fen: 15, sos: 8),
  ];

  for (final deneme in denemeler) {
    final sonuclar = <int, ({int correct, int wrong, int blank})>{};
    for (final ders in dersler) {
      final (dogru, toplam) = switch (ders.name) {
        'Türkçe' => (deneme.tur, 20),
        'Matematik' => (deneme.mat, 20),
        'Fen Bilimleri' => (deneme.fen, 20),
        _ => (deneme.sos, 10),
      };
      // Kalanın çoğu yanlış, bir kısmı boş: hepsini yanlış saymak
      // 3 yanlış 1 doğruyu götüren sistemde netleri gerçekçi olmayan
      // biçimde aşağı çekiyor.
      final kalan = toplam - dogru;
      sonuclar[ders.id] = (
        correct: dogru,
        wrong: (kalan * 2 / 3).round(),
        blank: kalan - (kalan * 2 / 3).round(),
      );
    }

    await db.saveMockExam(
      name: deneme.ad,
      takenOn: gun.subtract(Duration(days: deneme.haftaOnce * 7 + 2)),
      penalty: WrongPenalty.oneInThree,
      results: sonuclar,
    );
  }
}
