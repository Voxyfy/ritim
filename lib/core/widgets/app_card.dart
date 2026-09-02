import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// Uygulamanın tek kartı: fildişi zemin üzerinde kenarsız, geniş yarıçaplı bir
/// yüzey.
///
/// 1.0'da kartlar bir piksellik sıcak bir çizgiyle ayrılıyordu. Çizgi, geniş
/// yarıçapla birlikte köşelerde kırılmaya başladı ve her kart çerçeveli bir
/// kutu gibi durdu. Şimdi kart zeminden yalnızca renk farkıyla kalkıyor:
/// varsayılan beyaz, istenirse [tint] ile bir ders tonu. Gölge yalnızca gerçek
/// anlamda üstte duran katmanlarda — sekme çubuğu, yüzen düğme, alttan açılan
/// sayfa — ve orada bir bilgi taşıyor.
///
/// Ritim'de karta benzeyen her şey buradan geçer; yarıçapın ve payın bütün
/// ekranlarda aynı kalmasının sebebi budur.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(Gap.card),
    this.selected = false,
    this.tint,
    this.radius = Radii.md,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Düzenle/sil gibi ikincil eylemler için.
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  /// Seçim halkası. Seçim dolguyla değil kenarla gösterilir: dolgulu bir kart,
  /// içindeki ders renkleriyle çatışır.
  final bool selected;

  /// Kart zemini. Boşsa beyaz. Ders kartları dersin soluk tonunu, vurgu
  /// kartları soluk kiremidi verir; renk kartın **kendisinde**, içindeki
  /// rozette değil.
  final Color? tint;

  /// Köşe yarıçapı. Varsayılan kart; ızgara kartları ve takvim [Radii.lg].
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint ?? AppColors.surface,
        borderRadius: shape,
        border: selected
            ? Border.all(color: AppColors.selection, width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: shape,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: shape,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
