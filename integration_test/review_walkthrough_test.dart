import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritim/main.dart' as app;

/// App Store incelemesi için tanıtım videosu sürücüsü.
///
/// Bu bir test değil; simülatörde **gerçek uygulamayı** açıp bir öğrencinin
/// izleyeceği yolu insan hızında gezen bir gösteri. Ekran kaydı `simctl` ile
/// dışarıdan alınıyor, bu dosya yalnızca dokunuşları yapıyor.
///
/// NOT: Apple "gerçek cihazda çekilmiş kayıt" istiyor. Bu kayıt onun yerine
/// değil, yanında gönderilmek üzere üretiliyor — akışı ve ekranları
/// eksiksiz gösteriyor.
///
///     flutter test integration_test/review_walkthrough_test.dart -d <UDID>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// İzleyicinin okuyabilmesi için her adımda bekleme.
  ///
  /// `pumpAndSettle` kareyi hemen ilerletiyor; video hızlanıp anlaşılmaz
  /// oluyordu. Gerçek zamanlı beklemek için `Future.delayed` gerekiyor.
  Future<void> bekle(WidgetTester tester, [int ms = 1600]) async {
    await tester.pumpAndSettle();
    await Future<void>.delayed(Duration(milliseconds: ms));
    await tester.pumpAndSettle();
  }

  Future<void> dokun(WidgetTester tester, Finder hedef, [int ms = 1600]) async {
    debugPrint('[GEZINTI] dokun: $hedef');
    await tester.tap(hedef.first);
    await bekle(tester, ms);
  }

  /// Ekranda ne olduğunu günlüğe basar; hangi dalın atlandığını görmek için.
  void raporla(String etiket) => debugPrint('[GEZINTI] adim: $etiket');

  testWidgets('inceleme icin tanitim gezintisi', (tester) async {
    // Uygulama kendi zamanlamasıyla açılsın; beklemeden devam ediyoruz ki
    // açılış animasyonu da kayda girsin.
    unawaited(Future<void>.sync(app.main));
    await bekle(tester, 2500);

    // 1. Karşılama.
    if (find.text('Başlayalım').evaluate().isNotEmpty) {
      await dokun(tester, find.text('Başlayalım'));

      // 2. Şablon seçimi: hazır müfredat.
      //
      // Liste tembel çiziliyor; LGS kartı ilk ekranda değil. Önce görünür
      // hâle getiriyoruz, yoksa `find.text` boş dönüyor ve akış kurulum
      // ekranında takılı kalıyordu.
      await bekle(tester, 2000);
      final sablon = find.textContaining('LGS');
      if (sablon.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          sablon,
          220,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 12,
        );
        await bekle(tester, 800);
      }
      raporla('sablon bulundu: ${sablon.evaluate().length}');
      if (sablon.evaluate().isNotEmpty) {
        await dokun(tester, sablon, 1800);
        final devam = find.widgetWithText(FilledButton, 'Devam et');
        if (devam.evaluate().isNotEmpty) {
          await dokun(tester, devam, 2200);
        }
      }

      // 3. Tanıtım adımları.
      for (var i = 0; i < 3; i++) {
        if (find.text('Devam').evaluate().isNotEmpty) {
          await dokun(tester, find.text('Devam'));
        } else if (find.text('Başla').evaluate().isNotEmpty) {
          await dokun(tester, find.text('Başla'));
        }
      }
      if (find.text('Atla').evaluate().isNotEmpty) {
        await dokun(tester, find.text('Atla'));
      }
    }

    raporla('bugun ekranina gelindi');
    // 4. Bugün ekranı biraz dursun: incelemeci ne gördüğünü anlasın.
    await bekle(tester, 3000);

    // 5. Haftalık özeti aç: grafikler ve konu ilerlemesi görünsün.
    if (find.textContaining('Bu hafta').evaluate().isNotEmpty) {
      await dokun(tester, find.textContaining('Bu hafta'), 3000);
      await dokun(tester, find.textContaining('Bu hafta'), 1200);
    }

    // 6. Dersler > konu > konu detayı > çalışma kaydı.
    //    Uygulamanın çekirdek akışı bu: konuya çalışılır, kaydedilir,
    //    tekrar kendiliğinden planlanır.
    raporla('dersler sekmesi aranıyor');
    if (find.byKey(const Key('sekme-dersler')).evaluate().isNotEmpty) {
      await dokun(tester, find.byKey(const Key('sekme-dersler')), 2200);

      raporla('matematik aranıyor');
      if (find.text('Matematik').evaluate().isNotEmpty) {
        await dokun(tester, find.text('Matematik'), 2200);

        // İlk konuya gir.
        final konu = find.byType(ListTile).evaluate().isNotEmpty
            ? find.byType(ListTile)
            : find.byType(InkWell);
        if (konu.evaluate().isNotEmpty) {
          await dokun(tester, konu, 2400);
        }

        // Çalışma kaydı sayfasını aç ve göster.
        raporla('calistim aranıyor');
        if (find.text('Çalıştım').evaluate().isNotEmpty) {
          await dokun(tester, find.text('Çalıştım'), 3000);
          // Sayfa görünsün, sonra kapat.
          if (find.text('Kaydet').evaluate().isNotEmpty) {
            await dokun(tester, find.text('Kaydet'), 2600);
          }
        }
      }
    }

    // 7. Plan sekmesi ve plan kurma sayfası.
    if (find.byKey(const Key('sekme-plan')).evaluate().isNotEmpty) {
      await dokun(tester, find.byKey(const Key('sekme-plan')), 2400);
      if (find.text('Plan kur').evaluate().isNotEmpty) {
        await dokun(tester, find.text('Plan kur'), 3000);
      }
    }

    // 8. Deneme ve ayarlar ekranları.
    for (final sekme in ['Deneme', 'Ayarlar', 'Bugün']) {
      if (find.text(sekme).evaluate().isNotEmpty) {
        await dokun(tester, find.text(sekme), 2600);
      }
    }

    await bekle(tester, 2500);
  });
}
