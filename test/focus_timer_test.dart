import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/domain/focus_timer.dart';

void main() {
  final t0 = DateTime(2026, 11, 5, 10);
  DateTime at(int minutes, [int seconds = 0]) =>
      t0.add(Duration(minutes: minutes, seconds: seconds));

  test('süre duvar saatinden hesaplanır', () {
    final timer = FocusTimer(taskId: 1, startedAt: t0);
    expect(timer.elapsed(at(12, 34)), const Duration(minutes: 12, seconds: 34));
    expect(formatElapsed(timer.elapsed(at(12, 34))), '12:34');
  });

  test('duraklama süreden düşülür, duraklatılmışken süre ilerlemez', () {
    var timer = FocusTimer(taskId: 1, startedAt: t0).pause(at(10));
    expect(timer.elapsed(at(30)), const Duration(minutes: 10));

    timer = timer.resume(at(15));
    expect(timer.isPaused, isFalse);
    expect(timer.elapsed(at(20)), const Duration(minutes: 15));
  });

  test('dakika yuvarlanır ve en az 1', () {
    final timer = FocusTimer(taskId: 1, startedAt: t0);
    expect(timer.minutes(at(0, 10)), 1);
    expect(timer.minutes(at(24, 29)), 24);
    expect(timer.minutes(at(24, 31)), 25);
  });

  test('saat geri alınırsa süre eksiye inmez', () {
    final timer = FocusTimer(taskId: 1, startedAt: t0);
    expect(timer.elapsed(at(-5)), Duration.zero);
  });

  test('kayıt biçimi gidip gelir; bozuk kayıt yok sayılır', () {
    final timer = FocusTimer(
      taskId: 7,
      startedAt: t0,
      pausedMs: 1500,
    ).pause(at(3));
    final back = FocusTimer.decode(timer.encode())!;
    expect(back.taskId, 7);
    expect(back.elapsed(at(9)), timer.elapsed(at(9)));
    expect(back.isPaused, isTrue);

    expect(FocusTimer.decode(null), isNull);
    expect(FocusTimer.decode('{bozuk'), isNull);
  });

  test('bir saati aşan süre saatle yazılır', () {
    expect(
      formatElapsed(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
