import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/timeline_node.dart';

/// Kurulum ekranlarındaki ürün önizlemesinin parçaları.
///
/// Çizim yerine uygulamanın kendi bileşenleri: öğrenci daha derslerini
/// görmeden Bugün ekranının neye benzediğini görüyor ve içeri girdiğinde
/// aynı satırları tanıyor. Önizleme etkileşimsiz; yalnızca gösterir.
///
/// Ders renkleri paletteki sabit sıralar (Türkçe mor, Matematik turkuaz,
/// Fen mavi): şablonların çoğu dersleri bu sırayla yazıyor, öğrenci
/// içeride de aynı renkleri görecek.
abstract final class DemoSubjects {
  static const turkce = SubjectColor(Color(0xFF6B4EE8), Color(0xFFEDE8FF));
  static const matematik = SubjectColor(Color(0xFF0E9F8E), Color(0xFFDFF5F1));
  static const fen = SubjectColor(Color(0xFF2C7BE5), Color(0xFFE3EFFD));
}

/// Bugün ekranındaki satırın etkileşimsiz kopyası.
class DemoTaskRow extends StatelessWidget {
  const DemoTaskRow({
    required this.colour,
    required this.letter,
    required this.title,
    required this.meta,
    this.trailing,
    this.done = false,
    this.isFirst = false,
    this.isLast = false,
    this.size = 36,
    super.key,
  });

  final SubjectColor colour;
  final String letter;
  final String title;
  final String meta;
  final Widget? trailing;
  final bool done;
  final bool isFirst;
  final bool isLast;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TimelineNode(
            colour: colour,
            letter: letter,
            done: done,
            isFirst: isFirst,
            isLast: isLast,
            size: size,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: done
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Gap.sm),
            Center(child: trailing),
          ],
        ],
      ),
    );
  }
}

/// Boş ya da tamamlanmış onay dairesi.
class DemoCheck extends StatelessWidget {
  const DemoCheck({this.done = false, super.key});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.progress : Colors.transparent,
        border: Border.all(
          color: done ? AppColors.progress : AppColors.border,
          width: 2,
        ),
      ),
      child: done
          ? const Icon(
              PhosphorIconsRegular.check,
              size: 13,
              color: Colors.white,
            )
          : null,
    );
  }
}

/// Hızlı kayıt şeridindeki dakika seçeneği; [selected] koyu.
class DemoChip extends StatelessWidget {
  const DemoChip(this.label, {this.selected = false, super.key});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.selection : AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(
          color: selected ? AppColors.selection : AppColors.hairline,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.onSelection : AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Bugün ekranındaki hafta şeridinin küçük kopyası.
class DemoWeekStrip extends StatelessWidget {
  const DemoWeekStrip({super.key});

  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const _dots = <List<SubjectColor>>[
    [DemoSubjects.matematik, DemoSubjects.turkce, DemoSubjects.fen],
    [DemoSubjects.turkce, DemoSubjects.fen],
    [DemoSubjects.matematik, DemoSubjects.fen],
    [DemoSubjects.turkce, DemoSubjects.matematik],
    [DemoSubjects.fen],
    [DemoSubjects.matematik],
    [],
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _days.length; i++)
          Expanded(
            child: Column(
              children: [
                Text(
                  _days[i],
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 0 ? AppColors.selection : Colors.transparent,
                  ),
                  child: Text(
                    '${i + 10}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: i == 0
                          ? AppColors.onSelection
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final c in _dots[i])
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: c.ink,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
