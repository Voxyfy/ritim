import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// Zaman çizgisindeki düğüm: ders renginde yuvarlatılmış kare ve baş harf,
/// üstünde ve altında komşu işlere uzanan çizgi.
///
/// Baş harf rengin yanında kimliği ikinci kez taşıyor: palette turuncu 3:1
/// kontrastın altında ve renk hiçbir yerde tek başına kimlik olmamalı.
///
/// Uygulamanın bütün listeleri (Bugün, Plan, konular, denemeler, çalışma
/// geçmişi) bu tek düğümü kullanıyor. Önce her ekran kendi kopyasını
/// yazıyordu; çizgi kalınlığı ve köşe yarıçapı ekranlar arasında kaymaya
/// başlamıştı.
class TimelineNode extends StatelessWidget {
  const TimelineNode({
    super.key,
    required this.colour,
    this.letter,
    this.child,
    this.done = false,
    this.filled = false,
    this.isFirst = true,
    this.isLast = true,
    this.size = 44,
  });

  final SubjectColor colour;

  /// Düğümün içindeki harf ya da kısa yazı. [child] verilirse kullanılmaz.
  final String? letter;

  /// Harf yetmediğinde özel içerik: denemenin tarihi, bitmiş konunun onayı.
  final Widget? child;

  /// Soluk gösterilir: tamamlanmış iş listede kalıyor ama geri çekiliyor.
  final bool done;

  /// Zemin ders renginin kendisi, yazı beyaz. Konu listesinde "bitti"
  /// durumunu soluk zeminden ayırmak için.
  final bool filled;

  /// Komşu satır yoksa o taraftaki çizgi çizilmez. İkisi de `true` ise düğüm
  /// çizgisiz, tek başına bir rozet olur ve kendi yüksekliğini taşır —
  /// [Expanded] çizgiler sınırsız yükseklikte satırı kırıyordu.
  final bool isFirst;
  final bool isLast;

  /// Düğümün kenarı. Sık satırlı listelerde küçük.
  final double size;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : colour.ink;
    final node = AnimatedOpacity(
      duration: Motion.base,
      opacity: done ? 0.45 : 1,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? colour.ink : colour.wash,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground, size: size * 0.45),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: foreground,
              fontSize: size * 0.38,
              fontWeight: FontWeight.w800,
            ),
            child: child ?? Text(letter ?? '•'),
          ),
        ),
      ),
    );

    if (isFirst && isLast) return node;

    Widget line(bool visible) => Expanded(
          child: Center(
            child: Container(
              width: 2,
              color: visible ? AppColors.border : Colors.transparent,
            ),
          ),
        );

    return SizedBox(
      width: size,
      child: Column(children: [line(!isFirst), node, line(!isLast)]),
    );
  }
}
