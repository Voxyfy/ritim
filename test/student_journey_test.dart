import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:ritim/core/date_extensions.dart';
import 'package:ritim/core/providers.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/data/db/tables.dart';
import 'package:ritim/data/templates/study_template.dart';
import 'package:ritim/main.dart';
/// Gerçek bir öğrencinin uygulamayı ilk kez açtığı andan ilk tekrarına kadar
/// olan yolculuğu, tek testte baştan sona.
///
/// Diğer testler tek tek parçaları doğruluyor; buranın işi **akışın kendisini**
/// denemek. Her adımda "kullanıcı buradan çıkabiliyor mu, sıradaki adım
/// görünüyor mu" sorusu soruluyor — çıkmaz sokaklar ancak böyle görünüyor.
void main() {
  late RitimDatabase db;

  const lgs = StudyTemplate(
    id: 'lgs8',
    name: 'LGS · 8. Sınıf',
    group: 'Ortaokul',
    description: 'Altı ders.',
    subjects: [
      TemplateSubject(
        name: 'Matematik',
        colorIndex: 1,
        topics: ['Çarpanlar ve Katlar', 'Üslü İfadeler'],
      ),
      TemplateSubject(
        name: 'Türkçe',
        colorIndex: 0,
        topics: ['Fiilimsiler', 'Cümlenin Ögeleri'],
      ),
    ],
  );

  setUpAll(() async {
    Intl.defaultLocale = appLocale.toString();
    await initializeDateFormatting(appLocale.toString());
  });

  setUp(() => db = RitimDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    // Test yüzeyi varsayılan olarak 800x600; bu bir telefon değil, ve yüzen
    // sekme çubuğu ile düğme o yükseklikte bildirim çubuğuna yer bırakmıyor.
    // Uygulama telefon için tasarlandı, testi de telefon boyutunda koşuyoruz.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Test gövdesi hata verse bile ağaç sökülsün: aksi hâlde kapanmış
    // veritabanına bağlı sağlayıcılar ayakta kalıyor ve bir sonraki test
    // "Can't re-open a database after closing it" ile düşüyordu. Hata veren
    // testin komşusunu da düşürmesi, asıl hatayı bulmayı zorlaştırıyor.
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          templatesProvider.overrideWith(
            (ref) async => const [StudyTemplate.blank, lgs],
          ),
        ],
        child: const RitimApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Sekme çubuğundaki bir sekmeye geçer.
  Future<void> goToTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('ilk açılıştan ilk tekrara: bir öğrencinin tam yolculuğu',
      (tester) async {
    await pumpApp(tester);

    // 1. Karşılama: tek vaat, tek düğme.
    expect(find.text('Çalışmanı düzene sok.'), findsOneWidget);
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();

    // 2. Şablon seçimi. "Kendin kur" listenin başında olmalı; kendi dersini
    //    kuracak öğrenci on beş kartı kaydırmak zorunda kalmamalı.
    expect(find.text('Neye çalışıyorsun?'), findsOneWidget);
    final kendinKur = tester.getTopLeft(find.text('Kendin kur'));
    final ilkSablon = tester.getTopLeft(find.text('LGS · 8. Sınıf'));
    expect(kendinKur.dy, lessThan(ilkSablon.dy));

    await tester.tap(find.text('LGS · 8. Sınıf'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
    await tester.pumpAndSettle();

    // 3. Tanıtım: üç adım, her adımda çıkış var.
    expect(find.text('Konularını takip et'), findsOneWidget);
    expect(find.text('Atla'), findsOneWidget);
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('Çalıştıkça kaydet'), findsOneWidget);
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('Tekrarı Ritim planlasın'), findsOneWidget);
    await tester.tap(find.text('Hadi başlayalım'));
    await tester.pumpAndSettle();

    // 4. Bugün ekranı boş. Boş ekran çıkmaz sokak olmamalı: buradan devam
    //    edecek görünür bir eylem olmalı.
    expect(find.text('Bugün için bir şey planlamadın'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Haftalık plan kur'), findsOneWidget);

    // 5. Öğrenci haftalık plan kuruyor.
    await tester.tap(find.widgetWithText(FilledButton, 'Haftalık plan kur'));
    await tester.pumpAndSettle();
    expect(find.text('Haftalık plan'), findsOneWidget);

    // Varsayılan günler hafta içi. Test hafta sonu koşarsa plan bugüne hiçbir
    // iş düşürmez ve devamındaki adımlar boşa çıkar; bugünü de seçiyoruz.
    const gunEtiketleri = {
      DateTime.monday: 'Pzt',
      DateTime.tuesday: 'Sal',
      DateTime.wednesday: 'Çar',
      DateTime.thursday: 'Per',
      DateTime.friday: 'Cum',
      DateTime.saturday: 'Cmt',
      DateTime.sunday: 'Paz',
    };
    if (today().weekday >= DateTime.saturday) {
      await tester.tap(find.text(gunEtiketleri[today().weekday]!));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.widgetWithText(FilledButton, 'Planı kur'));
    await tester.pumpAndSettle();

    // Plan görevleri yazıldı mı?
    final planTasks = await (db.select(db.tasks)
          ..where((t) => t.source.equalsValue(TaskSource.plan)))
        .get();
    expect(planTasks, isNotEmpty, reason: 'plan hiç görev üretmedi');

    // 6. Plan sekmesinde planı görebiliyor mu? (Kurup göremediği bir plan,
    //    kurulmamış plandır.)
    await goToTab(tester, 'Plan');
    expect(find.text('Planın'), findsOneWidget);
    expect(find.text('Henüz plan kurmadın'), findsNothing);

    // 7. Dersler sekmesi: şablonun getirdiği dersler görünüyor mu?
    await goToTab(tester, 'Dersler');
    expect(find.text('Matematik'), findsOneWidget);
    expect(find.text('Türkçe'), findsOneWidget);

    // 8. Derse giriyor, konuya giriyor.
    await tester.tap(find.text('Matematik'));
    await tester.pumpAndSettle();
    expect(find.text('Çarpanlar ve Katlar'), findsOneWidget);

    await tester.tap(find.text('Çarpanlar ve Katlar'));
    await tester.pumpAndSettle();

    // 9. Konu ekranında "Çalıştım" var, üç durumlu seçici yok: "Çalışıyorum"
    //    ile "Çalıştım" yan yana durunca kullanıcı ikisini ayıramıyordu.
    expect(find.text('Çalıştım'), findsOneWidget);
    expect(find.text('Çalışıyorum'), findsNothing);
    expect(find.text('Bu konuyu bitirdim'), findsOneWidget);

    // 10. Çalışma kaydı giriyor.
    await tester.tap(find.text('Çalıştım'));
    await tester.pumpAndSettle();
    expect(find.text('Ne kadar çalıştın?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    // 11. İlk kayıttan sonra bildirim izni soruluyor; "şimdi değil" diyen
    //     kullanıcıya sistem uyarısı hiç gösterilmemeli.
    expect(find.text('Tekrar günü haber verelim mi?'), findsOneWidget);
    await tester.tap(find.text('Şimdi değil'));
    await tester.pumpAndSettle();

    // Akış değil tek seferlik okuma: widget testinin sahte saati altında bir
    // drift akışını beklemek ilerlemiyor ve test kilitleniyor.
    expect(await db.readSetting(SettingKeys.remindersAsked), 'true');
    expect(await db.readSetting(SettingKeys.remindersEnabled), 'false');

    // 12. Çalışma kaydı yazıldı, konu ilerledi, tekrar planlandı.
    final sessions = await db.select(db.studySessions).get();
    expect(sessions, hasLength(1));

    final reviews = await (db.select(db.tasks)
          ..where((t) => t.source.equalsValue(TaskSource.review)))
        .get();
    expect(reviews, hasLength(1), reason: 'çalışma tekrar üretmedi');
    expect(reviews.single.title, contains('Çarpanlar ve Katlar'));

    // 13. Bugün listesinde görevin nereden geldiği yazıyor mu? Aynı konu adı
    //     hem tekrar hem plan olarak çıkabiliyor.
    await goToTab(tester, 'Bugün');
    expect(find.text('plan'), findsWidgets);

    // 14. Listedeki konuya bağlı bir işi işaretlemek "Çalıştım" sayfasını
    //     açmalı: öğrenci çalışıp işaretliyor, uygulama bunu çalışma
    //     saymazsa tekrar hiç planlanmıyor.
    final oncekiKayit = (await db.select(db.studySessions).get()).length;
    final bugunkuPlan = (await db.select(db.tasks).get())
        .where((t) => t.source == TaskSource.plan && !t.done)
        .first;
    await tester.tap(find.byKey(ValueKey('gorev-onay-${bugunkuPlan.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Ne kadar çalıştın?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    expect(
      (await db.select(db.studySessions).get()).length,
      oncekiKayit + 1,
      reason: 'listeden tamamlamak çalışma kaydı üretmedi',
    );

    await disposeApp(tester);
  });

  testWidgets('şablon almayan öğrenci de uygulamayı kurabiliyor',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kendin kur'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    // Dersler sekmesi bomboş; buradan çıkış yolu görünmeli, yoksa uygulama
    // ilk ekranda çıkmaz sokak.
    await goToTab(tester, 'Dersler');
    expect(find.text('İlk dersini ekle'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Ders ekle'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Organik Kimya');
    // "Dersi ekle" ad boşken devre dışı; yazılan ad düğmeye yansısın diye
    // dokunmadan önce bir kare çizilmeli. enterText tek başına çizmiyor.
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Dersi ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Organik Kimya'), findsOneWidget);

    // Ders açıldı ama konusu yok: yine bir çıkış yolu olmalı.
    await tester.tap(find.text('Organik Kimya'));
    await tester.pumpAndSettle();
    expect(find.text('Bu derste henüz konu yok'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Konu ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Hidrokarbonlar');
    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Hidrokarbonlar'), findsOneWidget);
    expect(await db.select(db.topics).get(), hasLength(1));

    await disposeApp(tester);
  });
}
