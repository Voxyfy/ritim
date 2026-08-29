import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'date_extensions.dart';

/// Uygulamanın "bugün" dediği gün.
///
/// Sağlayıcılar tarihi kurulduklarında bir kez hesaplıyordu; uygulama açıkken
/// gece yarısı geçince liste dünde kalıyor, öğrenci sabah kalktığında dünkü
/// işleri görüyordu. Tarih artık tek bir yerden geliyor ve iki durumda
/// tazeleniyor:
///
/// - **Gece yarısında**, kurulan bir zamanlayıcıyla. Uygulama açık kalmışsa
///   liste kendiliğinden dönüyor.
/// - **Uygulama öne geldiğinde**, çünkü telefon arka plandayken zamanlayıcılar
///   çalışmayabiliyor; iOS uzun süre arka planda kalan uygulamayı askıya
///   alıyor ve gece yarısı zamanlayıcısı hiç tetiklenmiyor.
class DayTracker extends StateNotifier<DateTime> {
  DayTracker() : super(today()) {
    _scheduleNextMidnight();
  }

  Timer? _timer;

  /// Bir sonraki gece yarısına zamanlayıcı kurar.
  ///
  /// Bir saniyelik pay var: tam gece yarısına kurulan zamanlayıcı bazen
  /// milisaniyeler erken tetikleniyor ve hâlâ dünü hesaplıyor, sonra bir gün
  /// boyunca yanlış kalıyor.
  void _scheduleNextMidnight() {
    _timer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        state = today();
        _scheduleNextMidnight();
      },
    );
  }

  /// Uygulama öne geldiğinde çağrılır; gün değiştiyse tazeler.
  ///
  /// Gün değişmediyse durum yazılmıyor: aynı değeri yazmak bütün dinleyicileri
  /// gereksiz yere yeniden çizdirirdi.
  void refreshIfDayChanged() {
    final now = today();
    if (!state.isSameDay(now)) {
      state = now;
      _scheduleNextMidnight();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
