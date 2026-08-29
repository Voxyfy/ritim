import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/date_extensions.dart';
import 'package:ritim/core/day_tracker.dart';

/// Gün takibi: uygulama açıkken gece yarısı geçince liste dünde kalmamalı.
void main() {
  test('başlangıçta bugünü verir', () {
    final tracker = DayTracker();
    addTearDown(tracker.dispose);

    expect(tracker.state, today());
  });

  test('gün değişmediyse durum yeniden yazılmaz', () {
    final tracker = DayTracker();
    addTearDown(tracker.dispose);

    var bildirim = 0;
    tracker.addListener((_) => bildirim++, fireImmediately: false);

    tracker.refreshIfDayChanged();

    // Aynı değeri yazmak bütün dinleyicileri gereksiz yere yeniden çizdirirdi.
    expect(bildirim, 0);
  });

  test('gün geriye alındığında tazeleme durumu bugüne çeker', () {
    final tracker = DayTracker();
    addTearDown(tracker.dispose);

    // Uygulama dün açılmış gibi davranıyoruz.
    tracker.state = today().addDays(-1);

    var bildirim = 0;
    tracker.addListener((_) => bildirim++, fireImmediately: false);
    tracker.refreshIfDayChanged();

    expect(tracker.state, today());
    expect(bildirim, 1);
  });

  test('atıldıktan sonra zamanlayıcı kalmaz', () {
    final tracker = DayTracker()..dispose();

    // Zamanlayıcı sökülmezse uygulama kapandıktan sonra tetiklenip
    // atılmış bir duruma yazmaya çalışıyor.
    expect(tracker.mounted, isFalse);
  });
}
