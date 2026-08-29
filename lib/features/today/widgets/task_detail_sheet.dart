import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/date_extensions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../data/db/database.dart';
import '../../subjects/widgets/note_list.dart';
import '../../subjects/widgets/photo_actions.dart';
/// Bir görevin ayrıntı sayfası.
///
/// Bilerek bir defter değil: başlık, gün, tek satırlık not ve iki eylem.
/// Uzun not ile fotoğraf konuya ait, göreve değil — görev tamamlanınca
/// kapanıyor, konu ise tekrar günü geri geliyor. Buraya bir defter koymak,
/// öğrencinin bilgisini kapanacak bir kutuya yazdırmak olurdu.
///
/// Daha önce görev satırına dokunmak hiçbir şey yapmıyordu; kullanıcı için
/// görünür ama tepkisiz bir yüzeydi.
class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({required this.item, super.key});

  final TaskItem item;

  /// Konuya gidilmek istendiğinde konu kimliğini döndürür.
  static Future<int?> show(BuildContext context, TaskItem item) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => TaskDetailSheet(item: item),
    );
  }

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.item.task.title);
  late final TextEditingController _note =
      TextEditingController(text: widget.item.task.note ?? '');
  late DateTime _dueOn = widget.item.task.dueOn;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Kaydet düğmesi yok: alanlar kapanışta yazılıyor.
  ///
  /// Tek satırlık bir not ve bir tarih için ayrı bir kaydetme kararı,
  /// kullanıcıya "kaydettim mi acaba" sorusunu sordurup sayfayı ağırlaştırıyor.
  Future<void> _save() async {
    final title = _title.text.trim();
    await ref.read(databaseProvider).updateTask(
          widget.item.task.id,
          title: title.isEmpty ? widget.item.task.title : title,
          dueOn: _dueOn,
          note: _note.text,
        );
  }

  Future<void> _delete() async {
    await ref.read(databaseProvider).deleteTask(widget.item.task.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final item = widget.item;

    return PopScope(
      // Sayfa hangi yolla kapanırsa kapansın (düğme, kaydırma, geri) alanlar
      // yazılsın.
      onPopInvokedWithResult: (didPop, result) => _save(),
      child: Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: SafeArea(
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
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (item.contextLabel != null) ...[
                  const SizedBox(height: Gap.sm),
                  Text(item.contextLabel!, style: text.bodySmall),
                ],
                const SizedBox(height: Gap.xl),
                Text('Ne zaman?', style: text.bodyMedium),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    for (final offset in [0, 1, 2, 7]) ...[
                      if (offset > 0) const SizedBox(width: Gap.sm),
                      Expanded(
                        child: _DayChip(
                          label: switch (offset) {
                            0 => 'Bugün',
                            1 => 'Yarın',
                            2 => '2 gün',
                            _ => 'Hafta',
                          },
                          selected: _dueOn.isSameDay(today().addDays(offset)),
                          onTap: () =>
                              setState(() => _dueOn = today().addDays(offset)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Gap.xl),
                TextField(
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Kısa not — "kitap s. 42-58"',
                  helperText: 'Bu not göreve ait; görev bitince kapanır.',
                  helperStyle: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                if (item.topic != null) ...[
                  // Not da fotoğraf gibi buradan yazılıyor ama **konuya**
                  // kaydediliyor. Yukarıdaki tek satır bir etiket ("kitap
                  // s. 42-58") ve görev kapanınca onunla birlikte gidiyor;
                  // gerçek not konuda yaşamalı, çünkü tekrar günü orada
                  // karşına çıkıyor.
                  _ActionRow(
                    icon: PhosphorIconsRegular.notePencil,
                    label: 'Konuya not ekle',
                    onTap: () async {
                      final body = await NoteEditorSheet.show(context);
                      if (body == null) return;
                      await ref
                          .read(databaseProvider)
                          .addTopicNote(item.topic!.id, body);
                    },
                  ),
                  const Divider(height: 1, color: AppColors.hairline),
                  _ActionRow(
                    icon: PhosphorIconsRegular.camera,
                    label: 'Fotoğraf ekle',
                    onTap: () =>
                        PhotoActions.add(context, ref, item.topic!.id),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  // Bilginin yaşadığı yere çıkış: uzun not, çalışma geçmişi ve
                  // fotoğraflar konuda duruyor.
                  _ActionRow(
                    icon: PhosphorIconsRegular.bookOpen,
                    label: 'Konuya git',
                    onTap: () async {
                      await _save();
                      if (context.mounted) {
                        Navigator.of(context).pop(item.topic!.id);
                      }
                    },
                  ),
                  const Divider(height: 1, color: AppColors.border),
                ],
                _ActionRow(
                  icon: PhosphorIconsRegular.trash,
                  label: 'Görevi sil',
                  colour: AppColors.overdue,
                  onTap: _delete,
                ),
              ],
            ),
          ),
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
          color: selected ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.colour = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: IconSize.md, color: colour),
            const SizedBox(width: Gap.md),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
