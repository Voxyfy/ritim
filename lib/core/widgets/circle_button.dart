import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// Daire içinde tek ikon: geri, üç nokta, zil, kartın köşesindeki ok.
///
/// Üç görünüm var ve üçü de aynı ölçüyü paylaşıyor:
/// - [CircleButton.light]  beyaz daire, koyu ikon — başlık satırındaki
///   ikincil eylemler.
/// - [CircleButton.dark]   sıcak siyah daire, beyaz ikon — "buraya git"
///   diyen tek birincil işaret (ders kartının köşesi, karşılama ekranı).
/// - [CircleButton.accent] kiremit daire — yalnızca yüzen ekleme düğmesi.
///
/// Material'ın [IconButton] bileşeni 40 piksellik kendi dokunma alanını
/// dayatıyor ve dolgu rengini tema üzerinden veriyor; burada hem 44'lük iOS
/// hedefi hem de üç sabit görünüm gerekiyordu.
class CircleButton extends StatelessWidget {
  const CircleButton.light({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.tooltip,
    super.key,
  }) : _fill = AppColors.surface,
       _ink = AppColors.textPrimary;

  const CircleButton.dark({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.tooltip,
    super.key,
  }) : _fill = AppColors.selection,
       _ink = AppColors.onSelection;

  const CircleButton.accent({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.tooltip,
    super.key,
  }) : _fill = AppColors.accent,
       _ink = AppColors.onAccent;

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final Color _fill;
  final Color _ink;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: _fill,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Icon(icon, size: IconSize.md, color: _ink),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
