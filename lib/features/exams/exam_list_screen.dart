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
import 'exam_detail_screen.dart' show formatNet;

/// Çözülen denemelerin listesi: yeniden eskiye bir zaman çizgisi.
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
                            if (list.length >= 2) ...[
                              const SizedBox(height: Gap.xl),
                              _Summary(exams: list),
                            ],
                          ],
                        ),
                      );
                    }
                    final i = index - 1;
                    return _ExamRow(
                      exam: list[i],
                      // Liste yeniden eskiye sıralı: bir önceki deneme bir
                      // sonraki satır.
                      previous: i + 1 < list.length ? list[i + 1] : null,
                      isFirst: i == 0,
                      isLast: i == list.length - 1,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// Başlığın altındaki özet: son net ve netlerin zaman içindeki şekli.
///
/// Tek deneme varken eğri anlamsız, bu yüzden özet ancak iki denemeden sonra
/// görünüyor. Grafik kütüphanesi yok: on çubuk için bir bağımlılık fazla.
class _Summary extends ConsumerWidget {
  const _Summary({required this.exams});

  /// Yeniden eskiye sıralı denemeler.
  final List<MockExam> exams;

  static const _maxBars = 10;
  static const _barHeight = 40.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    // Çubuklar soldan sağa eskiden yeniye okunur.
    final recent = exams.take(_maxBars).toList().reversed.toList();
    // Satırlar aynı akışları zaten dinliyor; burada yeni sorgu açılmıyor.
    final nets = [
      for (final exam in recent)
        ExamScoring.totalNet(
          ref.watch(examScoresProvider(exam.id)).valueOrNull ?? const [],
          WrongPenalty.values[exam.penalty],
        ),
    ];
    final peak = nets.fold<double>(0, (max, n) => n > max ? n : max);

    return AppCard(
      padding: const EdgeInsets.all(Gap.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Son net', style: text.bodySmall),
              const SizedBox(height: Gap.xs),
              Text(
                formatNet(nets.last),
                style: text.headlineLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(width: Gap.xl),
          Expanded(
            child: SizedBox(
              height: _barHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < nets.length; i++) ...[
                    if (i > 0) const SizedBox(width: Gap.xs),
                    Container(
                      width: 8,
                      // Negatif ya da sıfır net de görünür bir iz bırakıyor.
                      height: peak <= 0
                          ? 4
                          : (nets[i].clamp(0, peak) / peak * _barHeight)
                                .clamp(4, _barHeight)
                                .toDouble(),
                      decoration: BoxDecoration(
                        // Vurgu yalnız son denemede; öncekiler bağlam.
                        color: i == nets.length - 1
                            ? AppColors.selection
                            : AppColors.selectionSoft,
                        borderRadius: BorderRadius.circular(Radii.xs),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zaman çizgisinde bir deneme: tarih düğümü, ad, kısa bilgi ve net.
///
/// Denemeler kronolojik bir dizi; kutulu kartlar yerine çizgiye dizilmeleri
/// "ne zaman, ne kadar" sorusunu tek sütunda okutuyor. Bir denemenin tek bir
/// dersi olmadığı için düğüm ders rengi değil, tarihin kendisini taşıyor.
class _ExamRow extends ConsumerWidget {
  const _ExamRow({
    required this.exam,
    required this.previous,
    required this.isFirst,
    required this.isLast,
  });

  final MockExam exam;
  final MockExam? previous;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores =
        ref.watch(examScoresProvider(exam.id)).valueOrNull ?? const [];
    final net = ExamScoring.totalNet(scores, WrongPenalty.values[exam.penalty]);
    final wrong = scores.fold<int>(0, (sum, s) => sum + s.wrong);
    final prev = previous;
    final delta = prev == null
        ? null
        : net -
              ExamScoring.totalNet(
                ref.watch(examScoresProvider(prev.id)).valueOrNull ?? const [],
                WrongPenalty.values[prev.penalty],
              );
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => context.go('${Routes.exams}/${exam.id}'),
      borderRadius: BorderRadius.circular(Radii.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateNode(date: exam.takenOn, isFirst: isFirst, isLast: isLast),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      exam.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${scores.length} ders · $wrong yanlış',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(
                    text: formatNet(net),
                    style: text.titleMedium?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    children: const [
                      TextSpan(
                        text: ' net',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Fark yalnızca bilgi: düşüş kırmızıyla bağırmıyor, çünkü
                // denemeler aynı zorlukta değil.
                if (delta != null && formatNet(delta.abs()) != '0')
                  Text(
                    '${delta > 0 ? '+' : '−'}${formatNet(delta.abs())}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarih düğümü: büyük gün, küçük ay; üstünde ve altında çizgi.
class _DateNode extends StatelessWidget {
  const _DateNode({
    required this.date,
    required this.isFirst,
    required this.isLast,
  });

  final DateTime date;
  final bool isFirst;
  final bool isLast;

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    Widget line(bool visible) => Expanded(
      child: Center(
        child: Container(
          width: 2,
          color: visible ? AppColors.border : Colors.transparent,
        ),
      ),
    );

    return SizedBox(
      width: _size,
      child: Column(
        children: [
          line(!isFirst),
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  DateFormat('MMM', 'tr_TR').format(date),
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          line(!isLast),
        ],
      ),
    );
  }
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
