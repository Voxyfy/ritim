import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_fab.dart';
import '../../core/widgets/illustration.dart';
import '../../core/widgets/progress_ring.dart';
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
          error: (error, stack) => Center(child: Text('Dersler okunamadı: $error')),
          data: (list) => list.isEmpty
              ? _EmptySubjects(onAdd: () => SubjectEditorSheet.show(context))
              : ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, Gap.listBottom),
            children: [
              Text('Derslerin', style: text.headlineMedium),
              const SizedBox(height: 6),
              Text(
                list.isEmpty
                    ? 'Henüz ders eklemedin.'
                    : '${list.length} ders · ${totals.values.fold(0, (a, b) => a + b)} konu',
                style: text.bodySmall,
              ),
              const SizedBox(height: Gap.xxl),
              for (final subject in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    onTap: () => context.go(
                      '${Routes.subjects}/${subject.id}',
                      extra: subject.name,
                    ),
                    onLongPress: () => _showSubjectActions(context, ref, subject),
                    child: Row(
                      children: [
                        ProgressRing(
                          completed: completed[subject.id] ?? 0,
                          total: totals[subject.id] ?? 0,
                        ),
                        const SizedBox(width: Gap.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(subject.name, style: text.titleMedium),
                              const SizedBox(height: 3),
                              Text(
                                '${completed[subject.id] ?? 0} / '
                                '${totals[subject.id] ?? 0} konu bitti',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          PhosphorIconsRegular.caretRight,
                          size: IconSize.md,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
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
  /// Kaydırma hareketi yerine uzun basma: ders kartı bir listeye değil bir
  /// ekrana götürüyor, kaydırmalı silme burada yanlışlıkla tetiklenmeye çok
  /// açık olurdu.
  void _showSubjectActions(BuildContext context, WidgetRef ref, Subject subject) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
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
