import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/timeline_node.dart';
import '../../../data/db/database.dart';
import '../../../data/db/tables.dart';

/// Günlük listedeki tek satır.
///
/// Tamamlama, satırın tamamına değil yalnızca sağdaki daireye bağlı: satıra
/// dokunmak görev sayfasını açıyor ve iki hareketin çakışmaması gerek.
///
/// Konuya bağlı, bitmemiş bir işin dairesi satırı açar ve dakika rozetleri
/// gösterir; rozete dokunmak işi o süreyle kapatır. Eskiden daire tam bir
/// kayıt sayfası açıyordu (süre, soru, not, Kaydet): günde beş kez yapılan
/// bir iş için yedi dokunuş. Şimdi iki; ayrıntı isteyen "Ayrıntı"ya basıyor.
class TaskTile extends StatefulWidget {
  const TaskTile({
    required this.item,
    required this.onToggle,
    required this.onSnooze,
    required this.onDelete,
    required this.onOpen,
    this.onQuickLog,
    this.onDetails,
    this.isFirst = false,
    this.isLast = false,
    super.key,
  });

  /// Zaman çizgisinde ilk/son satır mı? Düğümün üst/alt çizgisi buna göre
  /// gizlenir; aksi hâlde çizgi listenin dışına taşıyor.
  final bool isFirst;
  final bool isLast;

  final TaskItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSnooze;
  final VoidCallback onDelete;

  /// Satıra dokunulduğunda görev sayfasını açar. Tamamlama yalnızca sağdaki
  /// daireye bağlı; iki hareket çakışmasın diye.
  final VoidCallback onOpen;

  /// Dakika rozetine basıldı: iş o süreyle çalışılmış sayılıp kapanır.
  /// Verilmezse daire her işte doğrudan işaretler.
  final ValueChanged<int>? onQuickLog;

  /// "Ayrıntı": soru sayısı ve not için tam kayıt sayfası.
  final VoidCallback? onDetails;

  /// Satır açıkken gösterilen hazır süreler. Kayıt sayfasındakilerden az:
  /// dar satırda kalabalık etmemeli ve çoğu çalışma bu dördünden birine yakın.
  static const quickMinutes = [15, 30, 45, 60];

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  /// Dakika rozetleri açık mı?
  bool _expanded = false;

  /// Açılan dakika seçeneklerini görünür alana kaydırır.
  ///
  /// Son satırda seçenekler yüzen sekme çubuğunun altında açılıyordu ve
  /// öğrenci "dokundum, bir şey olmadı" sanıyordu. Açılma animasyonu bitince
  /// satır ekranın ortasına kaydırılır.
  void _revealChips() {
    Future.delayed(Motion.base, () {
      if (!mounted || !_expanded) return;
      // Satır zaten çubuğun üstündeyse kaydırma yok: her açılışta listenin
      // zıplaması, ekranın ortasındaki satırda gereksiz bir sarsıntıydı.
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      final limit =
          MediaQuery.sizeOf(context).height - Gap.floatingClearance;
      if (bottom <= limit) return;
      Scrollable.ensureVisible(
        context,
        duration: Motion.base,
        curve: Motion.curve,
        // Görünüm alanının sonu yüzen çubuğun altında kalıyor; "sona hizala"
        // satırı tam çubuğun arkasına koyuyordu. Ortaya hizalamak güvenli.
        alignment: 0.5,
      );
    });
  }

  TaskItem get item => widget.item;

  /// Daire bu satırda rozetleri mi açar, yoksa doğrudan mı işaretler?
  bool get _quick =>
      widget.onQuickLog != null && item.topic != null && !item.task.done;

  void _collapse() {
    if (_expanded) setState(() => _expanded = false);
  }

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
          widget.onSnooze();
          return false;
        }
        widget.onDelete();
        return true;
      },
      // Kart yerine zaman çizgisi: işler ders renginde düğümlerle alt alta
      // diziliyor ve aradaki çizgi günü tek bir akış gibi okutuyor. Kartlı
      // listede her iş ayrı bir kutuydu ve beş işlik gün bile kalabalık
      // duruyordu.
      // Satırın dışına dokunmak açık rozetleri kapatır: rozetler bir karar
      // anı, karar verilmeden başka yere geçildiyse kayıt da yok.
      child: TapRegion(
        onTapOutside: (_) => _collapse(),
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TimelineNode(
                      colour: colour,
                      letter: item.subject?.name.characters.first,
                      done: task.done,
                      isFirst: widget.isFirst,
                      isLast: widget.isLast,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Gap.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
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
                                decoration: task.done
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppColors.textTertiary,
                              ),
                            ),
                            if (_meta.isNotEmpty || overdue) ...[
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: _meta.join(' · ')),
                                    if (overdue)
                                      TextSpan(
                                        text:
                                            '${_meta.isEmpty ? '' : ' · '}'
                                            '${formatOverdue(task.dueOn)}',
                                        style: const TextStyle(
                                          color: AppColors.overdue,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    _Checkbox(
                      // Testlerin satırı bulabilmesi için kararlı anahtar; anlamsal
                      // etiket (Semantics) yalnızca erişilebilirlik açıkken
                      // bulunabiliyor ve testte kırılgan kalıyordu.
                      key: ValueKey('gorev-onay-${task.id}'),
                      done: task.done,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        if (_quick) {
                          setState(() => _expanded = !_expanded);
                          if (_expanded) _revealChips();
                        } else {
                          widget.onToggle(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: Motion.base,
                curve: Motion.curve,
                alignment: Alignment.topCenter,
                child: _expanded && _quick
                    ? _QuickLogRow(
                        taskId: task.id,
                        showLine: !widget.isLast,
                        onPick: (minutes) {
                          setState(() => _expanded = false);
                          widget.onQuickLog!(minutes);
                        },
                        onDetails: () {
                          setState(() => _expanded = false);
                          widget.onDetails?.call();
                        },
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Başlığın altındaki tek satır: bağlam ve kaynak.
  ///
  /// Önce her biri ayrı renkli bir etiketti; zaman çizgisinde ders rengi zaten
  /// düğümde taşındığı için etiketler düz metne indi. Kaynağın ("tekrar",
  /// "plan") yazması hâlâ şart: aynı konu adı ikisi olarak da çıkabiliyor.
  List<String> get _meta => [
    if (item.contextLabel != null) item.contextLabel!,
    if (item.task.source == TaskSource.review) 'tekrar',
    if (item.task.source == TaskSource.plan) 'plan',
    if (item.task.note != null) 'not',
  ];
}

/// Açık satırın dakika rozetleri ve "Ayrıntı".
///
/// Rozetler başlığın hizasında başlıyor; soldaki çizgi zaman çizgisini
/// sürdürüyor, yoksa açık satır listeyi ikiye bölüyormuş gibi duruyordu.
class _QuickLogRow extends StatelessWidget {
  const _QuickLogRow({
    required this.taskId,
    required this.showLine,
    required this.onPick,
    required this.onDetails,
  });

  final int taskId;
  final bool showLine;
  final ValueChanged<int> onPick;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TimelineNode'un çizgisiyle aynı ölçü: 44 genişlik, 2 kalınlık.
          SizedBox(
            width: 44,
            child: Center(
              child: Container(
                width: 2,
                color: showLine ? AppColors.border : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final minutes in TaskTile.quickMinutes)
                    _QuickChip(
                      key: ValueKey('hizli-kayit-$taskId-$minutes'),
                      label: '$minutes dk',
                      onTap: () => onPick(minutes),
                    ),
                  TextButton(
                    onPressed: onDetails,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                    ),
                    child: const Text('Ayrıntı'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dakika rozeti; kayıt sayfasındaki rozetlerin seçilmemiş hâliyle aynı.
class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // 40 piksel yükseklik: rozetler yan yana sık dursa da dokunma hedefi
        // parmak boyunda kalmalı.
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Yuvarlak onay kutusu.
///
/// Material'ın [Checkbox] bileşeni kare ve kendi dokunma alanını dayatıyor;
/// burada hem yuvarlak hem de 44 piksellik iOS dokunma hedefi gerekiyordu.
/// Ders renginde değil, "bitti" renginde bir onay dairesi.
///
/// Önce dersin rengini taşıyordu; her tamamlanan iş başka renkte bir daire
/// üretiyor ve liste rastgele boyanmış gibi duruyordu. Kimlik zaten satırdaki
/// ders etiketinde yazıyor — dairenin işi kimlik değil, durum: yapıldı mı?
class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.done, required this.onChanged, super.key});

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
