import 'package:flutter_test/flutter_test.dart';
import 'package:ritim/core/date_extensions.dart';
/// Süre biçimlendirme üç ekranda kullanılıyor; kopyaları birbirinden
/// ayrılmaya başladığı için tek yere alındı.
void main() {
  test('bir saatin altı dakika olarak yazılır', () {
    expect(formatDuration(0), '0 dk');
    expect(formatDuration(45), '45 dk');
    expect(formatDuration(59), '59 dk');
  });

  test('tam saatler dakikasız yazılır', () {
    expect(formatDuration(60), '1 sa');
    expect(formatDuration(120), '2 sa');
  });

  test('artan dakikalar saatin yanında yazılır', () {
    expect(formatDuration(80), '1 sa 20 dk');
    expect(formatDuration(455), '7 sa 35 dk');
  });

  test('gecikme metni gün sayısına göre değişir', () {
    final bugun = today();
    expect(formatOverdue(bugun, now: bugun), '');
    expect(formatOverdue(bugun.addDays(-1), now: bugun), 'Dün');
    expect(formatOverdue(bugun.addDays(-3), now: bugun), '3 gün gecikti');
  });
}
