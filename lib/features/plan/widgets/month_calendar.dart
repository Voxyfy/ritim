import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';

/// Ay görünümü.
///
/// Liste "sırada ne var" sorusuna cevap veriyor; takvim "ay nasıl dağılmış"
/// sorusuna. İkisi farklı sorular, bu yüzden liste kaldırılmadı — takvim
/// onun üstünde bir katman.
///
/// Hücreler daire. Boş günler ince çizgili beyaz, planlı günler sıcak
/// siyahın soluk tonları, en yoğun günler koyu, seçili gün tam koyu daire. Bugün seçili değilse ince koyu halka: "sen
/// buradasın" işareti, ama seçimle karışmayacak kadar hafif. Ayın dışındaki
/// boş hücreler çizilmiyor; ızgara ayın ilk gününden başlıyor.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    required this.month,
    required this.countsByDay,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final DateTime month;

  /// Gün başına iş sayısı.
  final Map<DateTime, int> countsByDay;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  static const _weekdayLabels = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // Ayın ilk gününden önceki boş hücreler. Hafta pazartesi başlıyor, bu
    // yüzden weekday'den pazartesi çıkarılıyor (DateTime.monday == 1).
    final leading = first.weekday - DateTime.monday;
    final peak = countsByDay.values.fold(0, (a, b) => a > b ? a : b);

    return AppCard(
      radius: Radii.lg,
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: Icon(
                      PhosphorIconsRegular.calendarDots,
                      size: IconSize.md,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Gap.md),
              Text(
                DateFormat('MMMM yyyy', 'tr_TR').format(month),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: Gap.sm,
              crossAxisSpacing: Gap.sm,
            ),
            itemCount: leading + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();

              final day = DateTime(
                month.year,
                month.month,
                index - leading + 1,
              );

              return _DayCell(
                day: day,
                count: countsByDay[day] ?? 0,
                peak: peak,
                isToday: day.isSameDay(today()),
                isSelected: day.isSameDay(selected),
                onTap: () => onSelect(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.peak,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final int count;
  final int peak;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Yoğunluk üç kademeye indiriliyor. Sürekli bir ölçek, bitişik günler
    // arasındaki farkı gözle ayırt edilemez yapıyordu.
    final level = switch (count) {
      0 => 0,
      _ when peak <= 2 => 2,
      _ when count >= peak => 3,
      _ when count >= peak / 2 => 2,
      _ => 1,
    };

    // Yoğunluk sıcak siyahın tonlarıyla, kiremitle değil: kiremit eylem
    // rengi, takvimde "burası dolu" demek onun işi değil.
    final fill = isSelected
        ? AppColors.selection
        : switch (level) {
            3 => AppColors.selection.withValues(alpha: 0.72),
            2 => AppColors.selectionSoft,
            1 => AppColors.surfaceMuted,
            _ => AppColors.surface,
          };
    final onDark = isSelected || level == 3;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: isToday && !isSelected
              ? Border.all(color: AppColors.selection, width: 1.5)
              : level == 0 && !isSelected
                  ? Border.all(color: AppColors.hairline)
                  : null,
        ),
        alignment: Alignment.center,
        child: Text(
          DateFormat('d').format(day),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isToday || isSelected
                ? FontWeight.w800
                : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: onDark ? AppColors.onSelection : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
