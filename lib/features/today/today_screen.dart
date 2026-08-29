import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/date_extensions.dart';
import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_fab.dart';
import '../../core/widgets/illustration.dart';
import '../../data/db/database.dart';
import '../plan/weekly_plan_sheet.dart';
import '../subjects/widgets/log_session_sheet.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/day_header.dart';
import 'widgets/stats_section.dart';
import 'widgets/task_detail_sheet.dart';
import 'widgets/task_tile.dart';
/// Uygulamanın ana ekranı: bugün yapılacaklar.
///
/// Liste yalnızca bugünü ve gecikmişleri gösterir; ileri tarihli işler burada
/// görünmez. Amaç bir ajanda değil, bugün ne yapılacağına dair tek bir cevap.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// Bitenler bölümü açık mı?
  ///
  /// Varsayılan kapalı. Tamamlanan işler listeden silinmiyor — gün sonunda ne
  /// yaptığını görmek motivasyonun yarısı — ama gün ilerledikçe kalan işleri
  /// aşağı itiyorlardı. Katlanan taraf yapılmış olan; ekranın üstü hep
  /// yapılacak işlere ait kalıyor.
  bool _doneOpen = false;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(todayTasksProvider);
    final db = ref.read(databaseProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: tasks.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => _ErrorState(error: error),
          data: (items) {
            final overdue = items
                .where((i) => i.isOverdue(today()) && !i.task.done)
                .toList();
            final pending = items
                .where((i) => !i.task.done && !i.isOverdue(today()))
                .toList();
            final finished = items.where((i) => i.task.done).toList();
            final done = finished.length;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: DayHeader(total: items.length, done: done),
                  ),
                ),
                // Özet başlığın hemen altında: ana ekran önce "nerede
                // duruyorum" sorusuna cevap versin, sonra "bugün ne var"
                // desin. Günün listesi zaten hemen altında.
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverToBoxAdapter(child: StatsSection()),
                ),
                if (items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else ...[
                  if (overdue.isNotEmpty)
                    _TaskSliver(
                      title: 'Geciken',
                      items: overdue,
                      db: db,
                      onOpen: _openTask,
                    ),
                  _TaskSliver(
                    title: overdue.isEmpty ? null : 'Bugün',
                    items: pending,
                    db: db,
                    onOpen: _openTask,
                  ),
                  if (finished.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        Gap.sm,
                        Gap.page,
                        Gap.md,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _DoneHeader(
                          count: finished.length,
                          open: _doneOpen,
                          onTap: () =>
                              setState(() => _doneOpen = !_doneOpen),
                        ),
                      ),
                    ),
                    if (_doneOpen)
                      _TaskSliver(
                        title: null,
                        items: finished,
                        db: db,
                        onOpen: _openTask,
                      ),
                  ],
                ],
                // Yüzen düğmenin ve sekme çubuğunun son satırı kapatmaması
                // için alt boşluk.
                const SliverToBoxAdapter(child: SizedBox(height: Gap.listBottom)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: AppFab(
        heroTag: 'gorev-ekle',
        onPressed: () => AddTaskSheet.show(context),
      ),
    );
  }
}

/// Başlıklı bir görev bloğu.
class _TaskSliver extends StatelessWidget {
  const _TaskSliver({
    required this.title,
    required this.items,
    required this.db,
    required this.onOpen,
  });

  final String? title;
  final List<TaskItem> items;
  final RitimDatabase db;
  final Future<void> Function(BuildContext, TaskItem) onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      sliver: SliverList.builder(
        itemCount: items.length + (title == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (title != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                title!.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          final item = items[index - (title == null ? 0 : 1)];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TaskTile(
              item: item,
              onToggle: (done) => _toggleTask(context, db, item, done: done),
              onSnooze: () => db.snoozeTask(item.task.id),
              onDelete: () => db.deleteTask(item.task.id),
              onOpen: () => onOpen(context, item),
            ),
          );
        },
      ),
    );
  }
}

/// Liste boşken görünen ekran.
///
/// Boş gün bir hata değil, bu yüzden uyarı tonu yok: marka işareti, tek satır
/// ve tek bir yönlendirme.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const IllustrationView(Illustration.emptyDay, height: 150),
          const SizedBox(height: Gap.section),
          Text(
            'Bugün için bir şey planlamadın',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Gap.sm),
          const Text(
            'Haftalık plan kur, konuların günlere kendiliğinden dağılsın. '
            'Ya da sağ alttaki düğmeyle tek bir iş ekle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: Gap.xxl),
          // Boş ekranın çıkışı plan kurmak: tek tek iş eklemek yerine
          // öğrenciyi bir düzene sokmak istiyoruz.
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
            onPressed: () => _openPlanSheet(context),
            child: const Text('Haftalık plan kur'),
          ),
        ],
      ),
    );
  }
}

/// Bir görevi işaretler.
///
/// Konuya bağlı bir görevi tamamlamak, "Çalıştım" sayfasını açar: öğrenci
/// listede konuyu görüp çalışıyor ve işaretliyor; uygulama bunu çalışma
/// saymazsa tekrar hiç planlanmıyor ve vaadimiz sessizce kırılıyor. Sayfayı
/// kapatırsa görev işaretlenmemiş kalıyor — yanlışlıkla dokunma cezasız.
///
/// Konusu olmayan işler ("kalem al") doğrudan kapanır.
Future<void> _toggleTask(
  BuildContext context,
  RitimDatabase db,
  TaskItem item, {
  required bool done,
}) async {
  if (!done || item.topic == null) {
    await db.setTaskDone(item.task.id, done: done);
    return;
  }

  final logged = await LogSessionSheet.show(
    context,
    item.topic!.id,
    taskId: item.task.id,
  );
  if (logged != true) return;
}

/// Katlanan "Bitenler" başlığı.
class _DoneHeader extends StatelessWidget {
  const _DoneHeader({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Text(
            'BİTENLER · $count',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: Gap.sm),
          AnimatedRotation(
            turns: open ? 0.5 : 0,
            duration: Motion.base,
            child: const Icon(
              PhosphorIconsRegular.caretDown,
              size: IconSize.sm,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Görev sayfasını açar; "Konuya git" seçilirse konuya yönlendirir.
Future<void> _openTask(BuildContext context, TaskItem item) async {
  final topicId = await TaskDetailSheet.show(context, item);
  if (topicId == null || !context.mounted) return;

  final subjectId = item.subject?.id;
  if (subjectId == null) return;
  context.go(
    '${Routes.subjects}/$subjectId/$topicId',
    extra: item.subject!.name,
  );
}

/// Plan sayfasını açar ve sonucu kısa bir bildirimle özetler.
Future<void> _openPlanSheet(BuildContext context) async {
  final count = await WeeklyPlanSheet.show(context);
  if (count == null || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        count == 0
            ? 'Planlanacak bitmemiş konu kalmamış.'
            : '$count konu planlandı.',
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Görevler okunamadı: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
