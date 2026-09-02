import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';

/// Günün başlığı: tarih, kalan iş, sağda seri rozeti ve ilerleme çubuğu.
///
/// Sayı "3/8 tamamlandı" değil "5 iş kaldı" diye okunuyor: öğrenciye kalan yükü
/// göstermek, tamamlanan oranı göstermekten daha çok harekete geçiriyor.
///
/// Seri, başlığın sağında beyaz bir daire içinde. 1.0'da yalnızca katlanmış
/// özet kartının içindeydi ve öğrenci seriyi görmek için kartı açmak zorunda
/// kalıyordu; oysa seri, ekranı her açışta görülmesi gereken tek sayı.
class DayHeader extends StatelessWidget {
  const DayHeader({
    required this.total,
    required this.done,
    this.streak = 0,
    super.key,
  });

  final int total;
  final int done;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = total - done;
    final ratio = total == 0 ? 0.0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatLongDate(today()),
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(switch ((total, remaining)) {
                    (0, _) => 'Bugün planın boş',
                    (_, 0) => 'Bugünü bitirdin',
                    (_, final left) => '$left iş kaldı',
                  }, style: text.headlineMedium),
                ],
              ),
            ),
            if (streak > 0) _StreakBadge(days: streak),
          ],
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
                // İlerleme sıcak siyah: kiremit yalnızca eylem. Yeşil yalnızca
                // tamamlanmış tekil işaretlerde (onay dairesi).
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.selection),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Seri rozeti: beyaz daire, alev ve gün sayısı.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$days günlük seri',
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(Radii.full)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsFill.flame,
              size: IconSize.md,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              '$days',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                fontFeatures: [FontFeature.tabularFigures()],
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
