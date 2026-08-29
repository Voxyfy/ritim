import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:ritim/core/providers.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/templates/study_template.dart';
import 'package:ritim/main.dart';
/// 2. günün vaadini doğrular: ilk açılış kuruluma, tamamlanmış kurulum
/// uygulamaya düşer ve ikisi de açık bir gezinme çağrısı gerektirmez.
void main() {
  late RitimDatabase db;

  // Bugün ekranı tarih adlarını biçimlendiriyor; main() çalışmadığı için
  // yerel veriyi testin kendisi yüklemek zorunda.
  setUpAll(() async {
    Intl.defaultLocale = appLocale.toString();
    await initializeDateFormatting(appLocale.toString());
  });

  const lgs = StudyTemplate(
    id: 'lgs8',
    name: 'LGS · 8. Sınıf',
    group: 'Ortaokul',
    description: 'Altı ders.',
    subjects: [
      TemplateSubject(
        name: 'Matematik',
        colorIndex: 1,
        topics: ['Üslü İfadeler'],
      ),
      TemplateSubject(name: 'Türkçe', colorIndex: 0, topics: ['Fiilimsiler']),
    ],
  );

  setUp(() => db = RitimDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          templatesProvider.overrideWith(
            (ref) async => const [lgs, StudyTemplate.blank],
          ),
        ],
        child: const RitimApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Test gövdesi biterken ProviderScope'u elle söker.
  ///
  /// Aksi hâlde kapsam, test çerçevesi değişmezleri denetledikten sonra yok
  /// ediliyor; drift ise sorgu akışı iptal edilirken temizlik için sıfır süreli
  /// bir zamanlayıcı kuruyor ve o zamanlayıcı "bekleyen zamanlayıcı" hatası
  /// olarak dönüyor. Bu, uygulama kodundaki bir sızıntı değil, testin sökme
  /// sırasıyla ilgili bir ayrıntı.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // Sökme sırasında kurulan sıfır süreli zamanlayıcının çalışabilmesi için
    // bir kare daha; `pump()` tek başına zaman ilerletmediği için yetmiyor.
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('ilk açılış kurulumdan geçip uygulamaya varır', (tester) async {
    await pumpApp(tester);
    expect(find.text('Çalışmanı düzene sok.'), findsOneWidget);

    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();
    expect(find.text('Neye çalışıyorsun?'), findsOneWidget);

    // Henüz seçim yok; tek kesinleştirme eylemi devre dışı kalmalı.
    final commit = find.widgetWithText(FilledButton, 'Devam et');
    expect(tester.widget<FilledButton>(commit).onPressed, isNull);

    await tester.tap(find.text('LGS · 8. Sınıf'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(commit).onPressed, isNotNull);

    await tester.tap(commit);
    await tester.pumpAndSettle();

    // Şablon seçiminden sonra sıra üç adımlık tanıtımda.
    expect(find.text('Konularını takip et'), findsOneWidget);
    expect(await db.isOnboarded, isTrue);

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    // Bizi taşıyan şey bayrağın değişmesi oldu, birinin ekran itmesi değil.
    expect(find.text('Bugün planın boş'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('şablona dokunmak tek başına hiçbir şey yazmaz', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LGS · 8. Sınıf'));
    await tester.pumpAndSettle();

    // Akış değil tek seferlik okuma: widget testinin sahte saati altında bir
    // drift akışına abone olup ilk değeri beklemek ilerlemiyor, test kilitleniyor.
    expect(await db.select(db.subjects).get(), isEmpty);
    expect(await db.isOnboarded, isFalse);

    await disposeApp(tester);
  });

  testWidgets('kurulumu bitirmiş kullanıcı karşılama ekranını görmez',
      (tester) async {
    await db.applyTemplate(lgs);
    await db.writeSetting(SettingKeys.tourSeen, 'true');

    await pumpApp(tester);

    expect(find.text('Bugün planın boş'), findsOneWidget);
    expect(find.text('Başlayalım'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('boş şablon hiçbir satır yazmadan kurulumu bitirir',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(StudyTemplate.blank.name));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    expect(find.text('Bugün planın boş'), findsOneWidget);
    expect(await db.select(db.subjects).get(), isEmpty);

    await disposeApp(tester);
  });
}
