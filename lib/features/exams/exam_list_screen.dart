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
import '../../core/widgets/app_fab.dart';
import '../../core/widgets/illustration.dart';
import '../../data/db/database.dart';
import '../../domain/exam_scoring.dart';

/// Çözülen denemelerin listesi.
class ExamListScreen extends ConsumerWidget {
  const ExamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(mockExamsProvider);

    return Scaffold(
      floatingActionButton: AppFab(
        heroTag: 'deneme-ekle',
        icon: PhosphorIconsRegular.plus,
        label: 'Deneme ekle',
        onPressed: () => context.go('${Routes.exams}/yeni'),
      ),
      body: SafeArea(
        bottom: false,
        child: exams.when(
        loading: () => const SizedBox.shrink(),
        error: (error, stack) =>
            Center(child: Text('Denemeler okunamadı: $error')),
        data: (list) => list.isEmpty
            ? const _EmptyExams()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.xl,
                  Gap.page,
                  Gap.listBottom,
                ),
                itemCount: list.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Gap.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Denemelerin',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: Gap.xs),
                          Text(
                            '${list.length} deneme',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Gap.md),
                    child: _ExamCard(exam: list[index - 1]),
                  );
                },
              ),
        ),
      ),
    );
  }
}

class _ExamCard extends ConsumerWidget {
  const _ExamCard({required this.exam});

  final MockExam exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(examScoresProvider(exam.id)).valueOrNull ?? const [];
    final penalty = WrongPenalty.values[exam.penalty];
    final net = ExamScoring.totalNet(scores, penalty);
    final text = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.go('${Routes.exams}/${exam.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exam.name, style: text.titleMedium),
                const SizedBox(height: Gap.xs),
                Text(
                  '${DateFormat('d MMMM yyyy', 'tr_TR').format(exam.takenOn)}'
                  ' · ${scores.length} ders',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatNet(net), style: text.displaySmall),
              Text('net', style: text.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// Net yazımı: tam sayıysa ondalık gösterilmiyor.
///
/// "42,00 net" gereksiz bir kesinlik iddiası; "42 net" yeter. Ondalık ancak
/// gerçekten varsa görünüyor.
String _formatNet(double net) {
  final rounded = (net * 100).round() / 100;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : NumberFormat('0.00', 'tr_TR').format(rounded);
}

class _EmptyExams extends StatelessWidget {
  const _EmptyExams();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.section, 0, Gap.section, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IllustrationView(Illustration.allDone, height: 160),
            const SizedBox(height: Gap.section),
            Text(
              'Henüz deneme eklemedin',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.sm),
            const Text(
              'Çözdüğün denemenin ders ders doğru ve yanlışlarını gir; '
              'Ritim netini hesaplasın ve en zayıf derslerini çıkarsın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
