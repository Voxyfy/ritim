import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
/// Ders kartlarındaki ilerleme halkası.
///
/// Yalnızca oran gösterir; içinde sayı yoktur. Önce ortada tamamlanan konu
/// sayısı yazıyordu ama hemen yanında zaten "1 / 13 konu bitti" yazıyor ve
/// aynı bilgi iki kez söyleniyordu. Halkanın işi oran, metnin işi kesin değer:
/// her işaretin tek bir işi olmalı.
///
/// Boş halka dürüst bir işarettir — ilerleme yoksa gösterilecek bir şey de
/// yoktur.
///
/// Halka ilerleme oranını çizer, ortasındaki sayı da oranı yüzde olarak yazar.
///
/// Yüzde ile yanındaki "1 / 13 konu bitti" aynı bilgi değil: kesir tek dersin
/// kesin durumunu verir, yüzde ise **dersler arası karşılaştırmayı** mümkün
/// kılar — 1/13 ile 3/22'yi kafadan kıyaslamak zor, %8 ile %14'ü değil.
///
/// Renk [color] ile gelir. 1.0'da her derste kiremitti: kartlar beyazdı ve
/// tek renk halka dersleri karşılaştırılabilir kılıyordu. 1.1'de kart zaten
/// dersin renginde; kiremit halka orada üçüncü bir renk oluyordu.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.completed,
    required this.total,
    this.size = 48,
    this.color = AppColors.selection,
    super.key,
  });

  final int completed;
  final int total;
  final double size;

  /// Yay rengi. Varsayılan sıcak siyah; renkli ders kartında dersin
  /// mürekkebi verilir — kartın zemini zaten kimliği taşıyor, halka ona uyar.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;

    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio),
        duration: Motion.slow,
        curve: Motion.curve,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(ratio: value, color: color),
          child: Center(
            child: Text(
              // Yüzde işareti sayıdan önce: Türkçe yazımda "%10" doğru,
              // "10%" değil.
              '%${(value * 100).round()}',
              style: TextStyle(
                fontSize: size * 0.28,
                fontWeight: FontWeight.w700,
                height: 1,
                // Rakam genişliği sabit: 8 ile 14 arasında gidip gelen bir
                // sayı, halkanın içinde titriyordu.
                fontFeatures: const [FontFeature.tabularFigures()],
                color: completed == 0
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.progressTrack;
    canvas.drawCircle(center, radius, track);

    if (ratio <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.color != color;
}
