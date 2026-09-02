import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
/// Liste bölümü başlığı: solda başlık, yanında sayı rozeti, sağda isteğe
/// bağlı bir eylem.
///
/// 1.0'da bölüm başlıkları küçük, harf aralıklı büyük harflerdi ("GECİKEN").
/// Büyük kartlar ve geniş yarıçapın yanında o etiketler bir form etiketi gibi
/// kalıyordu. Şimdi normal yazımlı bir başlık ve sayı; referans arayüzlerdeki
/// "Last lessons · See all" satırının karşılığı.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.count,
    this.trailing,
    super.key,
  });

  final String title;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(title, style: text.titleMedium),
        if (count != null) ...[
          const SizedBox(width: Gap.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.all(Radius.circular(Radii.full)),
            ),
            child: Text(
              '$count',
              style: text.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
        const Spacer(),
        ?trailing,
      ],
    );
  }
}
