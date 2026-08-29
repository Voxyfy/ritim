import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/date_extensions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/db/database.dart';
import 'weekly_summary_card.dart';
/// Ana ekranın istatistik bölümü: ders dağılımı ve konu ilerlemesi.
///
/// Haftalık özet kartı "ne kadar çalıştım" der; burası "neye çalıştım" ve
/// "nerede duruyorum" der. İkisi ayrı kart, çünkü biri zamana, diğeri
/// müfredata bakıyor.
class StatsSection extends ConsumerStatefulWidget {
  const StatsSection({super.key});

  @override
  ConsumerState<StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends ConsumerState<StatsSection> {
  /// Varsayılan kapalı.
  ///
  /// Ekranın asıl içeriği günün listesi; üç istatistik kartı açık başlarsa
  /// kullanıcı uygulamayı her açtığında listeye ulaşmak için kaydırmak
  /// zorunda kalıyor. Katlanan taraf listenin değil istatistiğin olmalı.
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final distribution =
        ref.watch(subjectMinutesProvider).valueOrNull ?? const [];
    final progress = ref.watch(topicProgressProvider).valueOrNull;
    final weekly = ref.watch(weeklySummaryProvider).valueOrNull;
    final streak = ref.watch(streakProvider).valueOrNull ?? 0;

    final hasData = distribution.isNotEmpty ||
        (progress != null && progress.total > 0) ||
        (weekly != null && !weekly.isEmpty);
    if (!hasData) return const SizedBox.shrink();

    return Column(
      children: [
        _StatsHeader(
          open: _open,
          minutes: weekly?.minutes ?? 0,
          streak: streak,
          onTap: () => setState(() => _open = !_open),
        ),
        // Yükseklik animasyonu yerine açılıp kapanan bir dal: kartların
        // içindeki grafiklerin kendi animasyonları var, ikisi üst üste
        // binince geçiş dalgalanıyordu.
        if (_open) ...[
          const SizedBox(height: Gap.md),
          const WeeklySummaryCard(),
          if (distribution.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            _SubjectDistributionCard(items: distribution),
          ],
          if (progress != null && progress.total > 0) ...[
            const SizedBox(height: Gap.md),
            _ProgressCard(progress: progress),
          ],
        ],
      ],
    );
  }
}

/// Katlanan istatistik bölümünün başlığı.
///
/// Kapalıyken bile en önemli iki sayıyı gösterir: bu haftaki süre ve seri.
/// Katlamak bilgiyi tamamen saklamak değil, ayrıntıyı istenene kadar
/// bekletmek olmalı.
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.open,
    required this.minutes,
    required this.streak,
    required this.onTap,
  });

  final bool open;
  final int minutes;
  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.chartBar,
            size: IconSize.md,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              'Bu hafta ${formatDuration(minutes)}'
              '${streak > 0 ? ' · $streak günlük seri' : ''}',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          AnimatedRotation(
            turns: open ? 0.5 : 0,
            duration: Motion.base,
            child: const Icon(
              PhosphorIconsRegular.caretDown,
              size: IconSize.md,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ders bazlı çalışma dağılımı: yatay çubuklar.
///
/// Pasta grafik değil yatay çubuk: dilim açılarını karşılaştırmak, uzunlukları
/// karşılaştırmaktan zor. Her çubuk kendi ders adıyla etiketli — renk tek
/// başına kimlik taşımıyor, bu yüzden ayrı bir gösterge (legend) da gerekmiyor.
class _SubjectDistributionCard extends StatelessWidget {
  const _SubjectDistributionCard({required this.items});

  /// En fazla kaç ders gösterilir; gerisi "Diğer" olarak toplanır. Sekiz
  /// çubuktan sonrası kartı bir tabloya çeviriyor.
  static const _maxRows = 5;

  final List<SubjectMinutes> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = items.take(_maxRows).toList();
    final restMinutes =
        items.skip(_maxRows).fold(0, (sum, item) => sum + item.minutes);
    final peak = shown.first.minutes;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bu hafta neye çalıştın', style: text.titleMedium),
          const SizedBox(height: Gap.lg),
          for (final item in shown) ...[
            _Bar(
              label: item.name,
              minutes: item.minutes,
              ratio: peak == 0 ? 0 : item.minutes / peak,
              colour: SubjectPalette.at(item.colorIndex).ink,
            ),
            const SizedBox(height: Gap.md),
          ],
          if (restMinutes > 0)
            _Bar(
              label: 'Diğer',
              minutes: restMinutes,
              ratio: peak == 0 ? 0 : restMinutes / peak,
              colour: AppColors.textTertiary,
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.minutes,
    required this.ratio,
    required this.colour,
  });

  final String label;
  final int minutes;
  final double ratio;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              formatDuration(minutes),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                // Değer metin rengiyle yazılır, ders rengiyle değil: kimliği
                // yanındaki çubuk taşıyor, sayının okunması gerekiyor.
                color: AppColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.progressTrack,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
                duration: Motion.slow,
                curve: Motion.curve,
                builder: (context, value, child) => Container(
                  height: 8,
                  // En kısa çubuk bile görünsün: sıfıra yakın bir değer
                  // çubuğu tamamen yok ediyordu.
                  width: (constraints.maxWidth * value).clamp(6.0, double.infinity),
                  decoration: BoxDecoration(
                    color: colour,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Konu ilerlemesi: bitmiş, çalışılan ve başlanmamış konular.
///
/// Tek yığılmış çubuk: üç değer bir bütünün parçaları, ayrı çubuklar bunu
/// gizlerdi. Parçalar arasında iki piksellik boşluk var, aksi hâlde bitişik
/// renkler tek bir blok gibi okunuyor.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final TopicProgress progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Konu ilerlemen', style: text.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '${progress.total} konudan ${progress.done} tanesi bitti',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '%${(progress.ratio * 100).round()}',
                style: text.displaySmall,
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          _StackedBar(progress: progress),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Legend(
                color: AppColors.accent,
                label: 'Bitti',
                value: progress.done,
              ),
              _Legend(
                color: AppColors.accentSoft,
                label: 'Çalışılıyor',
                value: progress.inProgress,
              ),
              _Legend(
                color: AppColors.progressTrack,
                label: 'Başlanmadı',
                value: progress.notStarted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.progress});

  final TopicProgress progress;

  @override
  Widget build(BuildContext context) {
    final total = progress.total == 0 ? 1 : progress.total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: SizedBox(
        height: 12,
        child: Row(
          // Row varsayılanı dikeyde ortalamak; [ColoredBox] kendi yüksekliğini
          // bilmediği için parçalar sıfır yükseklikte çiziliyor ve çubuk hiç
          // görünmüyordu.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (progress.done > 0)
              Expanded(
                flex: progress.done,
                child: const ColoredBox(color: AppColors.accent),
              ),
            if (progress.done > 0 && progress.inProgress > 0)
              const SizedBox(width: 2),
            if (progress.inProgress > 0)
              Expanded(
                flex: progress.inProgress,
                // Aynı ailenin soluk tonu: "çalışılıyor", "bitti"nin yolunda
                // bir ara durum, ayrı bir kategori değil.
                child: const ColoredBox(color: AppColors.accentSoft),
              ),
            if (progress.notStarted > 0 &&
                (progress.done > 0 || progress.inProgress > 0))
              const SizedBox(width: 2),
            if (progress.notStarted > 0)
              Expanded(
                flex: progress.notStarted,
                child: const ColoredBox(color: AppColors.progressTrack),
              ),
            if (progress.total == 0) Expanded(flex: total, child: const SizedBox()),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label · $value',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
