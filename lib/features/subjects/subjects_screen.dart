import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_fab.dart';
import '../../core/widgets/illustration.dart';
import '../../core/widgets/timeline_node.dart';
import '../../data/db/database.dart';
import 'widgets/subject_editor_sheet.dart';

/// Derslerin listesi ve ilerleme durumu.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider);
    final totals = ref.watch(topicCountsProvider).valueOrNull ?? const {};
    final completed =
        ref.watch(completedTopicCountsProvider).valueOrNull ?? const {};
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: subjects.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) =>
              Center(child: Text('Dersler okunamadı: $error')),
          data: (list) => list.isEmpty
              ? _EmptySubjects(onAdd: () => SubjectEditorSheet.show(context))
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        Gap.xl,
                        Gap.page,
                        Gap.xxl,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Derslerin', style: text.headlineMedium),
                            const SizedBox(height: 6),
                            Text(
                              '${list.length} ders · '
                              '${totals.values.fold(0, (a, b) => a + b)} konu',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Izgara yerine alt alta satırlar. Pastel kartlarda renk
                    // bütün yüzeyi kaplıyordu ve altı ders yan yana bir
                    // yama işi gibi duruyordu; renk artık yalnızca düğümde ve
                    // ince ilerleme çubuğunda, satırlar sayfanın zemininde.
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        0,
                        Gap.page,
                        Gap.listBottom,
                      ),
                      sliver: SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final subject = list[index];
                          return _SubjectRow(
                            subject: subject,
                            completed: completed[subject.id] ?? 0,
                            total: totals[subject.id] ?? 0,
                            onTap: () => context.go(
                              '${Routes.subjects}/${subject.id}',
                              extra: subject.name,
                            ),
                            onLongPress: () =>
                                _showSubjectActions(context, ref, subject),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: AppFab(
        heroTag: 'ders-ekle',
        onPressed: () => SubjectEditorSheet.show(context),
      ),
    );
  }

  /// Uzun basıldığında ders düzenleme ve silme.
  ///
  /// Kaydırma hareketi yerine uzun basma: ders satırı bir listeye değil bir
  /// ekrana götürüyor, kaydırmalı silme burada yanlışlıkla tetiklenmeye çok
  /// açık olurdu.
  void _showSubjectActions(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(PhosphorIconsRegular.pencilSimple),
              title: const Text('Dersi düzenle'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                SubjectEditorSheet.show(context, existing: subject);
              },
            ),
            ListTile(
              leading: const Icon(
                PhosphorIconsRegular.trash,
                color: AppColors.overdue,
              ),
              title: const Text(
                'Dersi sil',
                style: TextStyle(color: AppColors.overdue),
              ),
              subtitle: const Text('Konuları ve çalışma kayıtları da silinir.'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final onaylandi = await _confirmDelete(context, subject.name);
                if (onaylandi) {
                  await ref.read(databaseProvider).deleteSubject(subject.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text('$name silinsin mi?'),
        content: const Text(
          'Bu dersin konuları, notları ve çalışma kayıtları da silinir. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.overdue,
              minimumSize: const Size(100, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Ders listesindeki tek satır.
///
/// Solda ders renginde düğüm ve baş harf, ortada ad, tek satırlık özet ve
/// ince ilerleme çubuğu. Renk yalnızca düğümde ve çubukta: kimliği ad
/// taşıyor, renk onu yalnızca hızlandırıyor. Çubuk her derste kendi
/// mürekkebinde; dersler arası karşılaştırmayı uzunluk yapıyor, renk değil.
class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.completed,
    required this.total,
    required this.onTap,
    required this.onLongPress,
  });

  final Subject subject;
  final int completed;
  final int total;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colour = SubjectPalette.at(subject.colorIndex);
    final text = Theme.of(context).textTheme;
    final ratio = total == 0 ? 0.0 : completed / total;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Row(
          children: [
            // Çizgisiz düğüm: dersler bir sıra değil, yan yana duran ayrı
            // işler; aralarına zaman çizgisi çekmek yanlış bir sıra ima eder.
            SizedBox(
              height: 52,
              child: TimelineNode(
                colour: colour,
                letter: subject.name.characters.first,
                done: false,
                isFirst: true,
                isLast: true,
                size: 52,
              ),
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$completed/$total konu · %${(ratio * 100).round()}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: ratio),
                    duration: Motion.slow,
                    curve: Motion.curve,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      color: colour.ink,
                      backgroundColor: AppColors.progressTrack,
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.md),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: IconSize.md,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hiç ders yokken görünen ekran.
class _EmptySubjects extends StatelessWidget {
  const _EmptySubjects({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IllustrationView(Illustration.firstSubject, height: 170),
            const SizedBox(height: Gap.section),
            Text('İlk dersini ekle', style: text.titleMedium),
            const SizedBox(height: Gap.sm),
            const Text(
              'Çalıştığın dersleri ekle, konularını yaz. '
              'Ritim gerisini takip etsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: Gap.xxl),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
              onPressed: onAdd,
              child: const Text('Ders ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
