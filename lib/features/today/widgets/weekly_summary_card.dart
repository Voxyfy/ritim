import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/date_extensions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/db/database.dart';
/// Haftalık özet: seri, toplam süre ve yedi günlük çubuklar.
///
/// Bugün ekranının başında değil sonunda duruyor. Günün işi listedir; özet
/// geriye bakmak içindir ve ekranı açan öğrencinin ilk gördüğü şey olmamalı.
class WeeklySummaryCard extends ConsumerWidget {
  const WeeklySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider).valueOrNull ?? 0;
    final summary = ref.watch(weeklySummaryProvider).valueOrNull;
    final daily = ref.watch(dailyMinutesProvider).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    // Hiç çalışma kaydı yokken kart boş bir kutu olarak durmasın.
    if (summary == null || (summary.isEmpty && streak == 0)) {
      return const SizedBox.shrink();
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Bu hafta', style: text.titleMedium),
              const Spacer(),
              if (streak > 0) _StreakBadge(days: streak),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              _Stat(value: formatDuration(summary.minutes), label: 'çalışma'),
              if (summary.solved > 0)
                _Stat(value: '${summary.solved}', label: 'soru'),
            ],
          ),
          const SizedBox(height: Gap.xl),
          _WeekBars(days: daily),
        ],
      ),
    );
  }
}

/// Seri rozeti.
///
/// Alev ikonu ve sayı; "3 gün" değil "3" yazıyor çünkü rozetin yanındaki
/// ikon zaten ne sayıldığını söylüyor ve rozet dar.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.progressTrack,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(PhosphorIconsFill.flame, size: IconSize.sm, color: Color(0xFFE07B39)),
          const SizedBox(width: 5),
          Text(
            '$days',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yedi günlük çubuk grafiği.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  static const _labels = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  /// Çubuk kalınlığı. Boş günün izi de aynı kalınlıkta bir nokta olarak
  /// duruyor; hafta boyunca kaç gün çalışıldığı bir bakışta okunuyor.
  static const _barWidth = 10.0;

  final List<DailyMinutes> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    // Ölçek en yüksek güne göre. Sabit bir tavan (ör. 120 dk) az çalışan
    // haftalarda bütün çubukları görünmez yapıyordu.
    final peak = days.map((d) => d.minutes).fold(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final ratio = peak == 0 ? 0.0 : day.minutes / peak;
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: Motion.slow,
                              curve: Motion.curve,
                              // Çubuk genişliği sabit: tek dolu günü olan bir
                              // hafta, sütunun tamamını kaplayan devasa bir
                              // kare üretiyordu. İnce çubuklar hem grafik gibi
                              // okunuyor hem de günler arasındaki farkı
                              // uzunlukla anlatıyor.
                              width: _barWidth,
                              height: (constraints.maxHeight * ratio)
                                  .clamp(_barWidth, constraints.maxHeight),
                              decoration: BoxDecoration(
                                color: day.minutes == 0
                                    ? AppColors.progressTrack
                                    : AppColors.accent,
                                borderRadius:
                                    BorderRadius.circular(_barWidth / 2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _labels[day.day.weekday - 1],
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
