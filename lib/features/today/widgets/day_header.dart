import 'package:flutter/material.dart';

import '../../../core/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
/// Günün başlığı: tarih, kalan iş ve ilerleme çubuğu.
///
/// Sayı "3/8 tamamlandı" değil "5 iş kaldı" diye okunuyor: öğrenciye kalan yükü
/// göstermek, tamamlanan oranı göstermekten daha çok harekete geçiriyor.
class DayHeader extends StatelessWidget {
  const DayHeader({required this.total, required this.done, super.key});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = total - done;
    final ratio = total == 0 ? 0.0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatLongDate(today()),
          style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: 6),
        Text(
          switch ((total, remaining)) {
            (0, _) => 'Bugün planın boş',
            (_, 0) => 'Bugünü bitirdin',
            (_, final left) => '$left iş kaldı',
          },
          style: text.headlineMedium,
        ),
        if (total > 0) ...[
          const SizedBox(height: Gap.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: Motion.slow,
              curve: Motion.curve,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.progressTrack,
                // İlerleme rengi kiremit: yeşil yalnızca tamamlanmış tekil
                // işaretlerde (onay dairesi) kullanılıyor.
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
