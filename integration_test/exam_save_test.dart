import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritim/main.dart' as app;

/// App Review'un iPad'de karşılaştığı hatanın birebir tekrarı.
///
/// Rapor: "The Save button was unresponsive." — iPad Air 11-inch (M3),
/// iPadOS 26.6.1. Ekran görüntüsünde "Yeni deneme" ekranı, ders sonuçları
/// girilmiş ve deneme adı boş. Adsız kaydetmeye çalışıldığında `_save`
/// sessizce geri dönüyordu.
///
/// Bu dosya widget testinin yerine geçmiyor; onun doğruladığı davranışı
/// **gerçek cihazda** bir kez daha görmek için:
///
///     flutter test integration_test/exam_save_test.dart -d <UDID>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> bekle(WidgetTester tester, [int ms = 700]) async {
    await tester.pumpAndSettle();
    await Future<void>.delayed(Duration(milliseconds: ms));
    await tester.pumpAndSettle();
  }

  Future<void> dokun(WidgetTester tester, Finder hedef, [int ms = 700]) async {
    await tester.tap(hedef.first);
    await bekle(tester, ms);
  }

  testWidgets('adsiz deneme iPad de Kaydet ile kaydediliyor', (tester) async {
    unawaited(Future<void>.sync(app.main));
    await bekle(tester, 2500);

    // Kurulum: incelemeci de buradan geçiyor.
    if (find.text('Başlayalım').evaluate().isNotEmpty) {
      await dokun(tester, find.text('Başlayalım'));
      await bekle(tester, 1200);

      final sablon = find.textContaining('LGS');
      if (sablon.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          sablon,
          220,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 12,
        );
        await bekle(tester, 500);
      }
      await dokun(tester, sablon);
      final devam = find.widgetWithText(FilledButton, 'Devam et');
      if (devam.evaluate().isNotEmpty) await dokun(tester, devam, 1500);

      if (find.text('Atla').evaluate().isNotEmpty) {
        await dokun(tester, find.text('Atla'), 1200);
      }
    }

    // Deneme sekmesi > yeni deneme.
    await dokun(tester, find.byKey(const Key('sekme-deneme')), 1200);
    await dokun(tester, find.text('Deneme ekle'), 1500);
    expect(find.text('Yeni deneme'), findsOneWidget);

    // İncelemecinin yaptığı: ada hiç dokunmadan sonuçları gir.
    await tester.enterText(find.widgetWithText(TextField, 'Doğru').first, '2');
    await bekle(tester, 300);
    await tester.enterText(find.widgetWithText(TextField, 'Yanlış').first, '1');
    await bekle(tester, 300);

    // Ve Kaydet'e bas. Eskiden burada hiçbir şey olmuyordu.
    await dokun(tester, find.widgetWithText(TextButton, 'Kaydet'), 2000);

    expect(
      find.text('Yeni deneme'),
      findsNothing,
      reason: 'adsız denemede Kaydet ekranı kapatmalı',
    );
    debugPrint('[IPAD] adsiz deneme kaydedildi, ekran kapandi');
  });
}
