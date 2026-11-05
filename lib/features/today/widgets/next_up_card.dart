import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/timeline_node.dart';
import '../../../data/db/database.dart';
import '../../../domain/focus_timer.dart';

/// "Sıradaki": günün ilk bekleyen işi ve tek düğme.
///
/// Liste "bugün ne var" sorusunu cevaplıyor ama "şimdi ne yapayım" sorusunu
/// öğrenciye bırakıyordu; beş satır arasında seçmek de bir erteleme biçimi.
/// Kart seçimi bizim yerimize yapıyor: önce geciken, sonra bugünün ilk işi.
/// "Başla" ekranın birincil eylemi, bu yüzden vurgu rengi burada.
class NextUpCard extends StatelessWidget {
  const NextUpCard({required this.item, required this.onStart, super.key});

  final TaskItem item;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colour = item.subject == null
        ? const SubjectColor(AppColors.textSecondary, AppColors.surfaceMuted)
        : SubjectPalette.at(item.subject!.colorIndex);
    final overdue = item.isOverdue(today());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sıradaki',
            style: text.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              TimelineNode(
                colour: colour,
                letter: item.subject?.name.characters.first,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    if (item.contextLabel != null || overdue) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (item.contextLabel != null) item.contextLabel!,
                          if (overdue) formatOverdue(item.task.dueOn),
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: overdue
                              ? AppColors.overdue
                              : AppColors.textSecondary,
                          fontWeight: overdue ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          FilledButton.icon(
            key: const ValueKey('siradaki-basla'),
            onPressed: onStart,
            icon: const Icon(PhosphorIconsFill.play, size: IconSize.md),
            label: const Text('Başla'),
          ),
        ],
      ),
    );
  }
}

/// Süren odağın ince çubuğu: "Odak sürüyor · 12:34".
///
/// Odak ekranı kapatılsa ya da uygulama yeniden açılsa da sayaç sürüyor;
/// öğrencinin ona dönmesinin yolu bu çubuk. Kartın yerini alıyor, çünkü
/// süren bir odak varken "sıradaki"ni önermek dikkati ikiye bölerdi.
class FocusBar extends StatefulWidget {
  const FocusBar({required this.timer, required this.onTap, super.key});

  final FocusTimer timer;
  final VoidCallback onTap;

  @override
  State<FocusBar> createState() => _FocusBarState();
}

class _FocusBarState extends State<FocusBar> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Süre duvar saatinden hesaplanıyor; saniyelik tetik yalnızca yeniden
    // çizmek için.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = formatElapsed(widget.timer.elapsed(DateTime.now()));
    final label = widget.timer.isPaused ? 'Odak duraklatıldı' : 'Odak sürüyor';

    return AppCard(
      key: const ValueKey('odak-cubugu'),
      onTap: widget.onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.card,
        vertical: Gap.md,
      ),
      child: Row(
        children: [
          Icon(
            widget.timer.isPaused
                ? PhosphorIconsRegular.pause
                : PhosphorIconsFill.timer,
            size: IconSize.md,
            color: AppColors.accent,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              '$label · $elapsed',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Icon(
            PhosphorIconsRegular.caretRight,
            size: IconSize.md,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
