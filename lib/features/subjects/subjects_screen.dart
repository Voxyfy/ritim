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
import '../../core/widgets/circle_button.dart';
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
                    // İki sütunlu renkli ızgara. Liste hâlinde her ders aynı
                    // beyaz kartın içinde bir satırdı ve dersin rengi yalnızca
                    // sekiz piksellik bir noktada yaşıyordu. Renk artık kartın
                    // kendisinde: öğrenci Matematik'i adını okumadan bulur.
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        0,
                        Gap.page,
                        Gap.listBottom,
                      ),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: Gap.md,
                              crossAxisSpacing: Gap.md,
                              childAspectRatio: 0.92,
                            ),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final subject = list[index];
                          return SubjectCard(
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
  /// Kaydırma hareketi yerine uzun basma: ders kartı bir listeye değil bir
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

/// Izgaradaki ders kartı.
///
/// Zemin dersin soluk tonu, başlık dersin mürekkep rengi: kart bir rozetin
/// büyütülmüş hâli gibi okunuyor ve etiketlerle aynı çifti paylaşıyor. Sol
/// üstte beyaz daire içinde ilerleme halkası (her derste kiremit; dersler
/// arası karşılaştırma için tek renk), sağ altta koyu daire içinde ok:
/// "buraya git" işareti. Sağ üstteki büyük soluk halka süs değil, kartın
/// köşesini boş bırakmamak için; referans aldığımız düzendeki karalama
/// dokusunun sessiz karşılığı.
class SubjectCard extends StatelessWidget {
  const SubjectCard({
    required this.subject,
    required this.completed,
    required this.total,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final Subject subject;
  final int completed;
  final int total;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colour = SubjectPalette.at(subject.colorIndex);
    final text = Theme.of(context).textTheme;

    return AppCard(
      tint: colour.wash,
      radius: Radii.lg,
      padding: EdgeInsets.zero,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Stack(
          children: [
            Positioned(
              top: -36,
              right: -36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colour.ink.withValues(alpha: 0.10),
                    width: 22,
                  ),
                ),
                child: const SizedBox.square(dimension: 128),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ProgressRing(
                        completed: completed,
                        total: total,
                        size: 42,
                        color: colour.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    subject.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      fontSize: 17,
                      height: 1.15,
                      color: colour.ink,
                    ),
                  ),
                  const SizedBox(height: Gap.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '$completed / $total konu',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      // Ok düğmesi kartın kendisine dokunmakla aynı işi yapar;
                      // ayrı bir hedef değil, kartın dokunulabilir olduğunu
                      // söyleyen işaret. Bu yüzden onTap yok — dokunuş kartın
                      // InkWell'ine düşüyor.
                      const IgnorePointer(
                        child: CircleButton.dark(
                          icon: PhosphorIconsRegular.arrowUpRight,
                          onTap: null,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
