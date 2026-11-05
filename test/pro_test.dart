import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/pro.dart';
import 'package:ritim/features/pro/paywall_screen.dart';

void main() {
  group('deneme süresi', () {
    final start = DateTime(2026, 11, 2, 23, 59);

    test('başladığı gün 7 gün kalır', () {
      expect(trialDaysLeft(start, DateTime(2026, 11, 2, 23, 59)), 7);
    });

    test('gece yarısını geçince bir gün düşer, saat bazlı değil', () {
      expect(trialDaysLeft(start, DateTime(2026, 11, 3, 0, 1)), 6);
    });

    test('yedinci gün sonunda kilitlenir', () {
      expect(trialDaysLeft(start, DateTime(2026, 11, 8, 12)), 1);
      final left = trialDaysLeft(start, DateTime(2026, 11, 9, 0, 1));
      expect(left, 0);
      expect(Access(pro: false, daysLeft: left).locked, isTrue);
    });

    test('abone kullanıcı süre bitse de kilitlenmez', () {
      expect(const Access(pro: true, daysLeft: -30).locked, isFalse);
    });
  });

  test('tasarruf oranı aşağı yuvarlanır', () {
    // ₺749,99 / (₺49,99 × 52) = 0,2885 → %71,15 → %71
    expect(savingPercent(weekly: 49.99, annual: 749.99), 71);
    expect(savingPercent(weekly: 0, annual: 749.99), 0);
  });
}
