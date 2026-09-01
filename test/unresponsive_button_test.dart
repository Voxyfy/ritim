import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:ritim/core/providers.dart';
import 'package:ritim/data/db/database.dart';
import 'package:ritim/features/exams/exam_editor_screen.dart';
import 'package:ritim/features/subjects/widgets/subject_editor_sheet.dart';
import 'package:ritim/features/today/widgets/add_task_sheet.dart';
import 'package:ritim/main.dart';

/// Basıldığında hiçbir şey olmayan düğmeler.
///
/// App Review 1.0 (3) sürümünü "Kaydet düğmesi tepkisiz" diyerek reddetti.
/// Sebep çökme ya da iPad'e özel bir düzen sorunu değildi: deneme adı alanı
/// ekranın en üstünde duruyor, öğrenci ders sonuçlarını girmek için aşağı
/// kaydırınca gözden kayboluyor ve adsız kaydetmeye çalıştığında `_save`
/// sessizce geri dönüyordu. Basılan ama ne yapan ne de neden yapmadığını
/// söyleyen bir düğme, kullanıcı için bozuk bir düğmedir.
///
/// Buradaki testler koşulun kendisini değil, koşul sağlanmadığında düğmenin
/// **görünür** bir şey yapmasını doğruluyor: ya işi yapıyor ya sönük duruyor.
/// Sessiz üçüncü yol kapalı.
void main() {
  late RitimDatabase db;

  setUpAll(() async {
    Intl.defaultLocale = appLocale.toString();
    await initializeDateFormatting(appLocale.toString());
  });

  setUp(() => db = RitimDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Sınırlı sayıda kare çizer.
  ///
  /// `pumpAndSettle` burada kullanılamıyor: bu ekranların hepsinde odaklanan
  /// bir metin alanı var ve yanıp sönen imleç sonsuza kadar kare istiyor,
  /// yani ağaç hiç "oturmuyor". Test on dakika asılı kalıp düşüyordu.
  /// Kaydetme ve yönlendirme birkaç kare sürüyor; bu kadarı yetiyor.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Ağacı söker ve arkada kalan zamanlayıcıları boşaltır.
  ///
  /// Sağlayıcılar sökülürken drift, sorgu akışlarını kapatmak için sıfır
  /// süreli bir zamanlayıcı kuruyor. Test o zamanlayıcı beklerken biterse
  /// "A Timer is still pending" ile düşüyor — hata testin kendisinde değil,
  /// bitiş biçiminde. Bir kare daha çizmek zamanlayıcıyı boşaltıyor.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Tek bir widget'ı uygulamanın teması ve veritabanıyla kurar.
  ///
  /// Kurulum akışının tamamını sürmek yerine ekranı doğrudan açıyoruz: hata
  /// düğmenin kendisinde, oraya varana kadarki on adımda değil.
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: child),
      ),
    );
    await settle(tester);
  }

  testWidgets('adsız deneme Kaydet ile gerçekten kaydedilir', (tester) async {
    await db.addSubject(name: 'Matematik', colorIndex: 1);

    // Ekran kaydedince `context.go` çağırıyor; en küçük yönlendirici yeter.
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ExamEditorScreen()),
        GoRoute(
          path: '/denemeler/:examId',
          builder: (_, _) => const Scaffold(body: Text('deneme açıldı')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);

    // App Review'un yaptığı: ada hiç dokunmadan sonuçları gir ve Kaydet'e bas.
    await tester.enterText(find.widgetWithText(TextField, 'Doğru'), '12');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Kaydet'));
    await settle(tester);

    // Gerçek bir veritabanı akışını doğrudan `await` etmek testi asıyor:
    // `testWidgets` sahte bir zaman düzleminde koşuyor ve akışın olayı hiç
    // teslim edilmiyor. Gerçek zamana çıkmanın yolu `runAsync`.
    final denemeler =
        await tester.runAsync(() => db.watchMockExams().first) ?? [];
    expect(
      denemeler,
      hasLength(1),
      reason: 'adsız denemede Kaydet sessizce hiçbir şey yapmamalı',
    );
    // Ad boş bırakıldığı için tarihten türetiliyor — alanın ipucunda yazan ad.
    expect(denemeler.single.name, isNotEmpty);
    expect(find.text('deneme açıldı'), findsOneWidget);

    await unmount(tester);
    router.dispose();
  });

  testWidgets('adı boş ders düğmesi tepkisiz değil, sönük', (tester) async {
    await pump(tester, const Scaffold(body: SubjectEditorSheet()));

    final ekle = find.widgetWithText(FilledButton, 'Dersi ekle');
    expect(
      tester.widget<FilledButton>(ekle).onPressed,
      isNull,
      reason: 'ad boşken düğme sönük görünmeli, basılıp susmamalı',
    );

    await tester.enterText(find.byType(TextField).first, 'Organik Kimya');
    await tester.pump();
    expect(tester.widget<FilledButton>(ekle).onPressed, isNotNull);

    await tester.tap(ekle);
    await settle(tester);
    final dersler = await tester.runAsync(() => db.watchSubjects().first) ?? [];
    expect(dersler.map((s) => s.name), ['Organik Kimya']);

    await unmount(tester);
  });

  testWidgets('başlığı boş görev düğmesi tepkisiz değil, sönük', (tester) async {
    await pump(tester, const Scaffold(body: AddTaskSheet()));

    final ekle = find.widgetWithText(FilledButton, 'Ekle');
    expect(
      tester.widget<FilledButton>(ekle).onPressed,
      isNull,
      reason: 'başlık boşken düğme sönük görünmeli, basılıp susmamalı',
    );

    await tester.enterText(find.byType(TextField).first, 'Deneme çöz');
    await tester.pump();
    expect(tester.widget<FilledButton>(ekle).onPressed, isNotNull);

    await tester.tap(ekle);
    await settle(tester);
    final gorevler =
        await tester.runAsync(() => db.watchTasksUpTo(DateTime.now()).first) ??
            [];
    expect(gorevler, hasLength(1));

    await unmount(tester);
  });
}
