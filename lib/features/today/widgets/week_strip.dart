import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';

const _dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Bugünden başlayan yedi günlük şerit; her günün altında o günün dersleri.
///
/// Öğrenci ana ekranda yalnızca bugünü değil, haftanın yükünü de bir bakışta
/// görsün diye. Noktalar ders renginde: "perşembe Matematik ağırlıklı" bilgisi
/// sayı okumadan çıkıyor. Takvim haftası değil bugünden başlayan yedi gün —
/// geçmiş günlerin noktası yapılmış iş, burada sorulan şey ise önümüzdeki yük.
/// Bir güne dokunmak Plan sekmesini açar; ayrıntı orada.
class WeekStrip extends ConsumerWidget {
  const WeekStrip({super.key});

  /// Bir günün altında en fazla kaç nokta: fazlası şeridi taşırıyor ve
  /// renkler okunmaz hâle geliyor.
  static const _maxDots = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(upcomingDaysProvider).valueOrNull;
    if (days == null || days.isEmpty) return const SizedBox(height: 64);

    return Row(
      children: [
        for (final (i, day) in days.take(7).indexed)
          Expanded(
            child: _DayCell(
              name: _dayNames[day.day.weekday - 1],
              number: day.day.day,
              selected: i == 0,
              // Aynı dersin iki işi tek nokta: nokta yük değil, çeşit gösteriyor.
              colors: {
                for (final item in day.items)
                  if (item.subject != null && !item.task.done)
                    item.subject!.colorIndex,
              }.take(_maxDots).map((c) => SubjectPalette.at(c).ink).toList(),
              onTap: () => context.go(Routes.plan),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.name,
    required this.number,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String name;
  final int number;
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$name $number, ${colors.length} ders',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.selection : Colors.transparent,
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: selected
                      ? AppColors.onSelection
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final c in colors)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
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
