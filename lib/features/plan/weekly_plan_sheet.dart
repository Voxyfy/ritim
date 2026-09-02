import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../domain/weekly_planner.dart';
/// Haftalık plan kurma sayfası.
///
/// İki soru soruyor: hangi günler, günde kaç konu. Daha fazlası (ders bazlı
/// ağırlık, saat aralığı) planı kurmayı çalışmaktan daha zor hâle getirirdi;
/// bu ekranın işi öğrenciyi bir an önce çalışmaya sokmak.
class WeeklyPlanSheet extends ConsumerStatefulWidget {
  const WeeklyPlanSheet({super.key});

  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => const WeeklyPlanSheet(),
    );
  }

  @override
  ConsumerState<WeeklyPlanSheet> createState() => _WeeklyPlanSheetState();
}

class _WeeklyPlanSheetState extends ConsumerState<WeeklyPlanSheet> {
  static const _dayLabels = {
    DateTime.monday: 'Pzt',
    DateTime.tuesday: 'Sal',
    DateTime.wednesday: 'Çar',
    DateTime.thursday: 'Per',
    DateTime.friday: 'Cum',
    DateTime.saturday: 'Cmt',
    DateTime.sunday: 'Paz',
  };

  /// Varsayılan: hafta içi her gün, günde iki konu. Ortaokul öğrencisinin
  /// akşam etüdüne oturttuğumuz gerçekçi bir yük.
  Set<int> _weekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };
  int _perDay = 2;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  /// Daha önce plan kurulduysa aynı tercihlerle açılır: plan yenilemek
  /// çoğunlukla aynı düzeni tekrarlamak demek.
  Future<void> _loadSaved() async {
    final saved = await ref.read(databaseProvider).readPlanSettings();
    if (saved != null && mounted) {
      setState(() {
        _weekdays = saved.weekdays;
        _perDay = saved.perDay;
      });
    }
  }

  Future<void> _build() async {
    if (_weekdays.isEmpty || _saving) return;
    setState(() => _saving = true);

    final count = await ref.read(databaseProvider).buildWeeklyPlan(
          weekdays: _weekdays,
          perDay: _perDay,
        );

    if (mounted) Navigator.of(context).pop(count);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final slots = _weekdays.length * _perDay;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
            ),
            const SizedBox(height: Gap.xl),
            Text('Haftalık plan', style: text.titleMedium),
            const SizedBox(height: Gap.xs),
            Text(
              'Bitmemiş konuların seçtiğin günlere dağıtılsın.',
              style: text.bodySmall,
            ),
            const SizedBox(height: Gap.xl),
            Text('Hangi günler?', style: text.bodyMedium),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                for (final entry in _dayLabels.entries)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _DayChip(
                        label: entry.value,
                        selected: _weekdays.contains(entry.key),
                        onTap: () => setState(() {
                          _weekdays.contains(entry.key)
                              ? _weekdays.remove(entry.key)
                              : _weekdays.add(entry.key);
                        }),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Gap.xxl),
            Text('Günde kaç konu?', style: text.bodyMedium),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                for (var i = 1; i <= WeeklyPlanner.maxPerDay; i++) ...[
                  if (i > 1) const SizedBox(width: Gap.sm),
                  Expanded(
                    child: _CountChip(
                      count: i,
                      selected: _perDay == i,
                      onTap: () => setState(() => _perDay = i),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Gap.xl),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Text(
                _weekdays.isEmpty
                    ? 'En az bir gün seç.'
                    : 'Bu hafta $slots konu planlanacak.',
                style: text.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
            FilledButton(
              onPressed: _weekdays.isEmpty || _saving ? null : _build,
              child: const Text('Planı kur'),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Yeni plan kurmak, tamamlanmamış eski plan işlerini siler. '
              'Bitirdiklerin ve kendi eklediğin işler kalır.',
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.selection : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(
            color: selected ? AppColors.selection : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.onSelection : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.selection : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: selected ? AppColors.selection : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.onSelection : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
