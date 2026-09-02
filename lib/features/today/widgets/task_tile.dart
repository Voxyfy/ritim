import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/db/database.dart';
import '../../../data/db/tables.dart';
/// Günlük listedeki tek satır.
///
/// Tamamlama, satırın tamamına değil yalnızca sol daireye bağlı: satıra
/// dokunmak ileride görev detayını açacak ve iki hareketin çakışmaması gerek.
class TaskTile extends StatelessWidget {
  const TaskTile({
    required this.item,
    required this.onToggle,
    required this.onSnooze,
    required this.onDelete,
    required this.onOpen,
    super.key,
  });

  final TaskItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSnooze;
  final VoidCallback onDelete;

  /// Satıra dokunulduğunda görev sayfasını açar. Tamamlama yalnızca soldaki
  /// daireye bağlı; iki hareket çakışmasın diye.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final task = item.task;
    final colour = item.subject == null
        ? const SubjectColor(AppColors.textSecondary, AppColors.surfaceMuted)
        : SubjectPalette.at(item.subject!.colorIndex);
    final overdue = item.isOverdue(today());

    return Dismissible(
      key: ValueKey(task.id),
      background: const _SwipeAction(
        alignment: Alignment.centerLeft,
        icon: PhosphorIconsRegular.clock,
        label: 'Ertele',
        color: AppColors.selection,
      ),
      secondaryBackground: const _SwipeAction(
        alignment: Alignment.centerRight,
        icon: PhosphorIconsRegular.trash,
        label: 'Sil',
        color: AppColors.overdue,
      ),
      confirmDismiss: (direction) async {
        // Erteleme satırı listede bırakır (yarına taşır), silme kaldırır.
        // Bu yüzden yalnızca silmede gerçek bir dismiss yapılıyor.
        if (direction == DismissDirection.startToEnd) {
          onSnooze();
          return false;
        }
        onDelete();
        return true;
      },
      child: AppCard(
        onTap: onOpen,
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Checkbox(
              // Testlerin satırı bulabilmesi için kararlı anahtar; anlamsal
              // etiket (Semantics) yalnızca erişilebilirlik açıkken
              // bulunabiliyor ve testte kırılgan kalıyordu.
              key: ValueKey('gorev-onay-${task.id}'),
              done: task.done,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                onToggle(value);
              },
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      // Tamamlanan iş silinmiyor, soluyor: gün sonunda ne
                      // yaptığını görmek motivasyonun yarısı.
                      color: task.done
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      decoration:
                          task.done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textTertiary,
                    ),
                  ),
                  if (item.subject != null || overdue) ...[
                    const SizedBox(height: Gap.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (item.contextLabel != null)
                          _Tag(label: item.contextLabel!, colour: colour),
                        // Görevin nereden geldiği listede de yazıyor: aynı
                        // konu adı hem tekrar hem plan olarak çıkabiliyor ve
                        // öğrenci hangisi olduğunu anlayamıyordu.
                        // Kaynak etiketleri (tekrar/plan/not) tek nötr tonda:
                        // kimlik ders etiketinde, uyarı ahudududa; kaynağın
                        // kendi rengi olması üçüncü bir sistem kuruyordu.
                        if (item.task.source == TaskSource.review)
                          const _Tag(
                            label: 'tekrar',
                            colour: SubjectColor(
                              AppColors.textSecondary,
                              AppColors.surfaceMuted,
                            ),
                          ),
                        if (item.task.source == TaskSource.plan)
                          const _Tag(
                            label: 'plan',
                            colour: SubjectColor(
                              AppColors.textSecondary,
                              AppColors.surfaceMuted,
                            ),
                          ),
                        if (task.note != null)
                          const _Tag(
                            label: 'not',
                            colour: SubjectColor(
                              AppColors.textSecondary,
                              AppColors.surfaceMuted,
                            ),
                          ),
                        if (overdue)
                          _Tag(
                            label: formatOverdue(task.dueOn),
                            colour: const SubjectColor(
                              AppColors.overdue,
                              AppColors.overdueSoft,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ders rengini taşıyan yuvarlak onay kutusu.
///
/// Material'ın [Checkbox] bileşeni kare ve kendi dokunma alanını dayatıyor;
/// burada hem yuvarlak hem de 44 piksellik iOS dokunma hedefi gerekiyordu.
/// Ders renginde değil, "bitti" renginde bir onay dairesi.
///
/// Önce dersin rengini taşıyordu; her tamamlanan iş başka renkte bir daire
/// üretiyor ve liste rastgele boyanmış gibi duruyordu. Kimlik zaten satırdaki
/// ders etiketinde yazıyor — dairenin işi kimlik değil, durum: yapıldı mı?
class _Checkbox extends StatelessWidget {
  const _Checkbox({
    required this.done,
    required this.onChanged,
    super.key,
  });

  final bool done;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      label: 'Görevi tamamla',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!done),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.quick,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.progress : Colors.transparent,
                // Boş dairenin kenarı kart çizgisinden koyu: dokunulabilir bir
                // hedefin, ayraç çizgisiyle aynı ağırlıkta olmaması gerek.
                border: Border.all(
                  color: done ? AppColors.progress : AppColors.border,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(
                      PhosphorIconsRegular.check,
                      size: IconSize.sm,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.colour});

  final String label;
  final SubjectColor colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colour.wash,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colour.ink,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: IconSize.md, color: color),
          const SizedBox(width: Gap.sm),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
