import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// Yan yana hap seçici: seçili parça sıcak siyah, diğerleri beyaz.
///
/// Material'ın [SegmentedButton] bileşeni kenar çizgili ve köşeleri
/// birbirine yapışık; burada her parça ayrı bir hap ve seçim dolguyla
/// anlatılıyor. Plan ekranındaki liste/takvim geçişi ve ileride konu
/// filtreleri bunu kullanır.
class PillTabs extends StatelessWidget {
  const PillTabs({
    required this.items,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<PillTab> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: Gap.sm),
          _Pill(
            item: items[i],
            selected: i == selected,
            onTap: () {
              if (i == selected) return;
              HapticFeedback.selectionClick();
              onSelect(i);
            },
          ),
        ],
      ],
    );
  }
}

class PillTab {
  const PillTab({this.label, this.icon, this.key})
    : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;

  /// Testlerin parçayı bulması için.
  final Key? key;
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PillTab item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? AppColors.onSelection : AppColors.textPrimary;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: GestureDetector(
        key: item.key,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.curve,
          height: 40,
          padding: EdgeInsets.symmetric(
            horizontal: item.label == null ? Gap.md : Gap.xl,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.selection : AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null)
                Icon(item.icon, size: IconSize.sm, color: ink),
              if (item.icon != null && item.label != null)
                const SizedBox(width: 6),
              if (item.label != null)
                Text(
                  item.label!,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: ink,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
