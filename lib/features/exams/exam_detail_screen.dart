import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../domain/exam_scoring.dart';

/// Bir denemenin analizi.
///
/// Ekranın işi net göstermek değil, **ne yapılacağını söylemek**: netler
/// yukarıda, altında en zayıf üç ders ve doğrudan onlara plan kuran bir düğme.
/// Sayıyı gösterip öğrenciyi kendi başına bırakan bir analiz ekranı, karneden
/// farksız olurdu.
class ExamDetailScreen extends ConsumerWidget {
  const ExamDetailScreen({required this.examId, super.key});

  final int examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(mockExamsProvider).valueOrNull ?? const [];
    final scores = ref.watch(examScoresProvider(examId)).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    final exam = exams.where((e) => e.id == examId).firstOrNull;
    if (exam == null) return const Scaffold(body: SizedBox.shrink());

    final penalty = WrongPenalty.values[exam.penalty];
    final total = ExamScoring.totalNet(scores, penalty);
    final weakest = ExamScoring.weakest(scores, penalty);
    final analyses = scores.map((s) => ExamScoring.analyse(s, penalty)).toList();
    final peak = analyses.fold<double>(
      0,
      (max, a) => a.net > max ? a.net : max,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(exam.name),
        actions: [
          IconButton(
            tooltip: 'Denemeyi sil',
            icon: const Icon(PhosphorIconsRegular.trash),
            onPressed: () async {
              await ref.read(databaseProvider).deleteMockExam(examId);
              if (context.mounted) context.go(Routes.exams);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.page,
          Gap.sm,
          Gap.page,
          Gap.listBottom,
        ),
        children: [
          _TotalCard(
            total: total,
            date: exam.takenOn,
            penalty: penalty,
            subjectCount: scores.length,
          ),
          const SizedBox(height: Gap.xxl),
          Text('Ders netleri', style: text.titleMedium),
          const SizedBox(height: Gap.md),
          for (final analysis in analyses) ...[
            _SubjectNetRow(analysis: analysis, peak: peak),
            const SizedBox(height: Gap.md),
          ],
          if (weakest.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text('En zayıf dersler', style: text.titleMedium),
            const SizedBox(height: Gap.xs),
            Text(
              'Sıralama nete göre değil doğru oranına göre: az soruda çok net, '
              'çok soruda az net olabilir.',
              style: text.bodySmall,
            ),
            const SizedBox(height: Gap.md),
            for (final analysis in weakest) ...[
              _WeakRow(analysis: analysis),
              const SizedBox(height: Gap.sm),
            ],
            const SizedBox(height: Gap.lg),
            FilledButton(
              onPressed: () => _planForWeakest(context, ref, weakest),
              child: const Text('Bu derslere plan kur'),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Bu derslerin bitmemiş konuları haftaya dağıtılır. '
              'Mevcut plan yenilenir.',
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  /// Zayıf derslere odaklanan bir haftalık plan kurar.
  ///
  /// Kullanıcının seçtiği gün ve yoğunluk tercihleri korunuyor; değişen tek
  /// şey hangi derslerin plana gireceği. Deneme sonucu planı ele geçirmemeli,
  /// yalnızca yönlendirmeli.
  static Future<void> _planForWeakest(
    BuildContext context,
    WidgetRef ref,
    List<SubjectAnalysis> weakest,
  ) async {
    final db = ref.read(databaseProvider);
    final saved = await db.readPlanSettings();

    final count = await db.buildWeeklyPlan(
      weekdays: saved?.weekdays ??
          {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          },
      perDay: saved?.perDay ?? 2,
      onlySubjects: weakest.map((a) => a.score.subjectId).toSet(),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'Bu derslerde planlanacak bitmemiş konu kalmamış.'
              : '$count konu planlandı.',
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.total,
    required this.date,
    required this.penalty,
    required this.subjectCount,
  });

  final double total;
  final DateTime date;
  final WrongPenalty penalty;
  final int subjectCount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(Gap.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Toplam net', style: text.bodySmall),
                const SizedBox(height: Gap.xs),
                Text(
                  formatNet(total),
                  style: text.headlineLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('d MMM yyyy', 'tr_TR').format(date),
                style: text.bodySmall,
              ),
              const SizedBox(height: Gap.xs),
              Text(
                '$subjectCount ders · ${penalty.shortLabel}',
                style: text.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Net yazımı: tam sayıysa ondalık gösterilmiyor.
String formatNet(double net) {
  final rounded = (net * 100).round() / 100;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : NumberFormat('0.00', 'tr_TR').format(rounded);
}

class _SubjectNetRow extends StatelessWidget {
  const _SubjectNetRow({required this.analysis, required this.peak});

  final SubjectAnalysis analysis;
  final double peak;

  @override
  Widget build(BuildContext context) {
    final score = analysis.score;
    final colour = SubjectPalette.at(score.colorIndex).ink;
    // Negatif net çubuk olarak çizilemez; sıfıra indiriliyor ama sayı
    // olduğu gibi yazılıyor.
    final ratio = peak <= 0 ? 0.0 : (analysis.net.clamp(0, peak) / peak);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                score.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${score.correct}D · ${score.wrong}Y · ${score.blank}B',
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(width: Gap.md),
            SizedBox(
              width: 48,
              child: Text(
                formatNet(analysis.net),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.progressTrack,
                  borderRadius: BorderRadius.circular(Radii.xs),
                ),
              ),
              Container(
                height: 8,
                width: (constraints.maxWidth * ratio).clamp(6, double.infinity),
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: BorderRadius.circular(Radii.xs),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeakRow extends StatelessWidget {
  const _WeakRow({required this.analysis});

  final SubjectAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final colour = SubjectPalette.at(analysis.score.colorIndex);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colour.ink),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              analysis.score.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '%${((analysis.accuracy ?? 0) * 100).round()} doğru',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.overdue,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
