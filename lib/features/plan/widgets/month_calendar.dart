import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';

/// Ay görünümü.
///
/// Liste "sırada ne var" sorusuna cevap veriyor; takvim "ay nasıl dağılmış"
/// sorusuna. İkisi farklı sorular, bu yüzden liste kaldırılmadı — takvim
/// onun üstünde bir katman.
///
/// Günler yoğunluğa göre boyanıyor, sayı yazılmıyor: otuz hücreye sayı
/// sığdırmak ızgarayı okunmaz yapıyor ve zaten aranan şey tek bir günün
/// sayısı değil, ayın dağılımı.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: Gap.xs,
            crossAxisSpacing: Gap.xs,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();

            final day = DateTime(month.year, month.month, index - leading + 1);

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

    final fill = switch (level) {
      3 => AppColors.accent,
      2 => AppColors.accent.withValues(alpha: 0.55),
      1 => AppColors.accentSoft,
      _ => Colors.transparent,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : isToday
                    ? AppColors.accent
                    : AppColors.hairline,
            width: isSelected || isToday ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          DateFormat('d').format(day),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            // Koyu dolgunun üstünde koyu yazı okunmuyor; eşik seviye 2.
            color: level >= 2 ? AppColors.onAccent : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
