import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/date_extensions.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_fab.dart';
import '../../core/widgets/illustration.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import 'weekly_plan_sheet.dart';
import 'widgets/month_calendar.dart';
/// Önümüzdeki iki haftanın planı.
///
/// Bugün ekranı yalnızca bugünü gösteriyor; plan kurulduğunda öğrencinin
/// "ne kurdum ben" diye bakabileceği bir yer gerekiyordu. Boş günler de
/// listede: planın hangi günleri boş bıraktığını görmek, planın kendisi kadar
/// bilgi veriyor.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  /// Takvim görünümü açık mı?
  ///
  /// Varsayılan liste: günlük kullanımda aranan "sırada ne var". Takvim "ay
  /// nasıl dağılmış" sorusuna cevap veriyor ve plan kurarken, boş gün ararken
  /// işe yarıyor. İkisi farklı sorular, bu yüzden biri diğerinin yerine
  /// geçmiyor.
  bool _calendar = false;

  /// Takvimde seçili gün; altındaki liste bu güne ait.
  DateTime _selected = today();

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(upcomingDaysProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: AppFab(
        heroTag: 'plan-kur',
        icon: PhosphorIconsRegular.calendarPlus,
        label: 'Plan kur',
        onPressed: () => _openPlanSheet(context),
      ),
      body: SafeArea(
        bottom: false,
        child: days.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => Center(child: Text('Plan okunamadı: $error')),
          data: (list) {
            final planned = list.where((d) => !d.isEmpty).toList();

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Planın', style: text.headlineMedium),
                            ),
                            _ViewToggle(
                              calendar: _calendar,
                              onChanged: (value) =>
                                  setState(() => _calendar = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(
                          planned.isEmpty
                              ? 'Önümüzdeki iki hafta boş.'
                              : '${planned.length} günde '
                                  '${planned.fold(0, (a, d) => a + d.items.length)} iş var.',
                          style: text.bodySmall,
                        ),
                        if (_calendar) ...[
                          const SizedBox(height: Gap.xl),
                          MonthCalendar(
                            month: _selected,
                            countsByDay: {
                              for (final day in list)
                                if (!day.isEmpty) day.day: day.items.length,
                            },
                            selected: _selected,
                            onSelect: (day) => setState(() => _selected = day),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (planned.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyPlan(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.listBottom),
                    sliver: SliverList.builder(
                      // Takvimdeyken yalnızca seçili gün listeleniyor.
                      // Takvimin altında on dört gün daha sıralamak, takvimi
                      // seçim aracı olmaktan çıkarıp süse çevirirdi.
                      itemCount: _calendar ? 1 : list.length,
                      itemBuilder: (context, index) => _DayRow(
                        day: _calendar
                            ? list.firstWhere(
                                (d) => d.day.isSameDay(_selected),
                                orElse: () =>
                                    PlannedDay(day: _selected, items: const []),
                              )
                            : list[index],
                        alwaysShow: _calendar,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

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

/// Tek bir günün satırı.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, this.alwaysShow = false});

  final PlannedDay day;

  /// Takvimde seçili gün boşsa açık bir mesaj gösterilir; listede boş gün ince
  /// bir ayraç olarak kalır — kart açmak listeyi uzatıp dolu günleri boğuyordu.
  final bool alwaysShow;

  @override
  Widget build(BuildContext context) {
    if (day.isEmpty) {
      return alwaysShow
          ? _SelectedEmptyDay(day: day.day)
          : _EmptyDayRow(day: day.day);
    }

    final text = Theme.of(context).textTheme;
    final isToday = day.day.isSameDay(today());

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              children: [
                Text(
                  isToday
                      ? 'Bugün'
                      : DateFormat('d MMMM EEEE', 'tr_TR').format(day.day),
                  style: text.labelSmall?.copyWith(
                    color: isToday ? AppColors.accent : AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (day.doneCount > 0)
                  Text(
                    '${day.doneCount}/${day.items.length}',
                    style: text.labelSmall,
                  ),
              ],
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final item in day.items) _PlanItemRow(item: item),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanItemRow extends StatelessWidget {
  const _PlanItemRow({required this.item});

  final TaskItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colour = item.subject == null
        ? const SubjectColor(AppColors.textSecondary, AppColors.surfaceMuted)
        : SubjectPalette.at(item.subject!.colorIndex);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.task.done ? AppColors.border : colour.ink,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              item.task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: item.task.done
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
                decoration:
                    item.task.done ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
          _SourceBadge(source: item.task.source),
        ],
      ),
    );
  }
}

/// Görevin nereden geldiğini söyleyen küçük etiket.
///
/// Plan ekranında üç kaynak yan yana duruyor; hangisinin tekrar, hangisinin
/// plan olduğunu ayırt etmek renk tonuyla değil yazıyla yapılıyor.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final TaskSource source;

  @override
  Widget build(BuildContext context) {
    final (label, colour) = switch (source) {
      TaskSource.review => ('tekrar', AppColors.accent),
      TaskSource.plan => ('plan', AppColors.textSecondary),
      TaskSource.manual => ('', AppColors.textTertiary),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: source == TaskSource.review
            ? AppColors.accentSoft
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colour,
        ),
      ),
    );
  }
}

/// Takvimde seçilen gün boşsa gösterilen mesaj.
class _SelectedEmptyDay extends StatelessWidget {
  const _SelectedEmptyDay({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.isSameDay(today())
                ? 'Bugün'
                : DateFormat('d MMMM EEEE', 'tr_TR').format(day),
            style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Gap.sm),
          Text('Bu gün boş.', style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Görünüm değiştirici: liste ya da takvim.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.calendar, required this.onChanged});

  final bool calendar;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: PhosphorIconsRegular.listBullets,
            selected: !calendar,
            onTap: () => onChanged(false),
          ),
          _ToggleButton(
            icon: PhosphorIconsRegular.calendarBlank,
            selected: calendar,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Icon(
          icon,
          size: IconSize.sm,
          color: selected ? AppColors.accent : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _EmptyDayRow extends StatelessWidget {
  const _EmptyDayRow({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 2),
      child: Row(
        children: [
          Text(
            DateFormat('d MMM EEE', 'tr_TR').format(day),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: Gap.md),
          const Expanded(child: Divider(color: AppColors.border)),
          const SizedBox(width: Gap.md),
          const Text(
            'boş',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const IllustrationView(Illustration.reviewTime, height: 150),
          const SizedBox(height: Gap.section),
          Text(
            'Henüz plan kurmadın',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Gap.sm),
          const Text(
            'Hangi günler çalışacağını seç, konuların o günlere dağılsın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
