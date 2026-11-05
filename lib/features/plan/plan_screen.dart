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
import '../../core/widgets/pill_tabs.dart';
import '../../core/widgets/timeline_node.dart';
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

  /// Hafta sütunlarından bir güne atlamak için her günün satır anahtarı.
  final _dayKeys = <DateTime, GlobalKey>{};

  GlobalKey _keyFor(DateTime day) => _dayKeys.putIfAbsent(day, GlobalKey.new);

  void _jumpTo(DateTime day) {
    final target = _dayKeys[day]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: Motion.slow,
      curve: Motion.curve,
      alignment: 0.05,
    );
  }

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
          error: (error, stack) =>
              Center(child: Text('Plan okunamadı: $error')),
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
                            // Liste/takvim geçişi. Seçili parça koyu: kiremit
                            // bu ekranda yalnızca "Plan kur" düğmesinde
                            // kalıyor.
                            PillTabs(
                              items: const [
                                PillTab(
                                  icon: PhosphorIconsRegular.listBullets,
                                  key: Key('plan-liste'),
                                ),
                                PillTab(
                                  icon: PhosphorIconsRegular.calendarBlank,
                                  key: Key('plan-takvim'),
                                ),
                              ],
                              selected: _calendar ? 1 : 0,
                              onSelect: (i) =>
                                  setState(() => _calendar = i == 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(
                          planned.isEmpty
                              ? 'Önümüzdeki iki hafta boş.'
                              // "İki hafta" açıkça yazıyor: altındaki sütunlar
                              // yalnızca ilk yedi günü gösteriyor ve "7 günde"
                              // sayısı sütunlarla karıştırılıyordu.
                              : 'Önümüzdeki iki haftada '
                                    '${planned.fold(0, (a, d) => a + d.items.length)} iş var.',
                          style: text.bodySmall,
                        ),
                        if (!_calendar && planned.isNotEmpty) ...[
                          const SizedBox(height: Gap.xl),
                          _WeekColumns(
                            days: list.take(7).toList(),
                            onTap: _jumpTo,
                          ),
                        ],
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
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      0,
                      Gap.page,
                      Gap.listBottom,
                    ),
                    sliver: SliverList.builder(
                      // Takvimdeyken yalnızca seçili gün listeleniyor.
                      // Takvimin altında on dört gün daha sıralamak, takvimi
                      // seçim aracı olmaktan çıkarıp süse çevirirdi.
                      itemCount: _calendar ? 1 : list.length,
                      itemBuilder: (context, index) => _DayRow(
                        key: _calendar ? null : _keyFor(list[index].day),
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
  const _DayRow({required this.day, this.alwaysShow = false, super.key});

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
                    color: isToday
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
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
          // Kart yerine Bugün ekranıyla aynı zaman çizgisi: iki ekranda aynı
          // iş aynı biçimde görünsün, öğrenci Plan'dan Bugün'e geçince
          // yeniden okumayı öğrenmesin.
          for (final (i, item) in day.items.indexed)
            _PlanItemRow(
              item: item,
              isFirst: i == 0,
              isLast: i == day.items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _PlanItemRow extends StatelessWidget {
  const _PlanItemRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  final TaskItem item;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colour = item.subject == null
        ? const SubjectColor(AppColors.textSecondary, AppColors.surfaceMuted)
        : SubjectPalette.at(item.subject!.colorIndex);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TimelineNode(
            colour: colour,
            letter: item.subject?.name.characters.first,
            done: item.task.done,
            isFirst: isFirst,
            isLast: isLast,
            size: 36,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
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
                  if (item.subject != null)
                    Text(
                      item.subject!.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Center(child: _SourceBadge(source: item.task.source)),
        ],
      ),
    );
  }
}

/// Haftanın sütun görünümü: her gün bir sütun, her iş ders renginde bir
/// kapsül.
///
/// Liste "hangi gün ne var"ı sırayla okutuyor; sütunlar ise yükün haftaya
/// nasıl dağıldığını tek bakışta gösteriyor — perşembe dolu, cumartesi boş.
/// Kapsüller sayılmak için değil şekil vermek için: bu yüzden üst sınırlı
/// ve sayının kendisi altta yazıyor.
class _WeekColumns extends StatelessWidget {
  const _WeekColumns({required this.days, required this.onTap});

  final List<PlannedDay> days;
  final ValueChanged<DateTime> onTap;

  static const _maxPills = 6;
  static const _dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final day in days)
            Expanded(
              child: Semantics(
                button: true,
                label: '${_dayNames[day.day.weekday - 1]} '
                    '${day.day.day}, ${day.items.length} iş',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: day.isEmpty ? null : () => onTap(day.day),
                  child: _Column(day: day, name: _dayNames[day.day.weekday - 1]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.day, required this.name});

  final PlannedDay day;
  final String name;

  @override
  Widget build(BuildContext context) {
    final isToday = day.day.isSameDay(today());
    final shown = day.items.take(_WeekColumns._maxPills).toList();

    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isToday ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: Gap.sm),
        // Sabit yükseklik: sütunlar aynı tabandan başlasın, dolu gün boş
        // günün yanında uzun dursun.
        SizedBox(
          height: _WeekColumns._maxPills * 16.0,
          child: Column(
            children: [
              for (final item in shown)
                Container(
                  width: 22,
                  height: 12,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: item.task.done
                        ? AppColors.progressTrack
                        : (item.subject == null
                            ? AppColors.selectionSoft
                            : SubjectPalette.at(item.subject!.colorIndex).ink),
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday ? AppColors.selection : Colors.transparent,
          ),
          child: Text(
            '${day.day.day}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isToday ? AppColors.onSelection : AppColors.textPrimary,
            ),
          ),
        ),
      ],
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
      TaskSource.review => ('tekrar', AppColors.textSecondary),
      TaskSource.plan => ('plan', AppColors.textSecondary),
      TaskSource.manual => ('', AppColors.textTertiary),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
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
