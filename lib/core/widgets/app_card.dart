import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
/// Uygulamanın tek kartı: fildişi zemin üzerinde beyaz bir yüzey, bir
/// piksellik sıcak bir çizgiyle ayrılmış.
///
/// Önce gölgeyle yüzüyordu. Gölge davetkârdı ama liste hâlinde bakınca her
/// kartın kenarı bulanıklaşıyor, ekran yumuşak lekeler topluluğuna dönüyordu.
/// Kesin çizgi hem daha sessiz hem daha okunaklı. Gölge artık yalnızca gerçek
/// anlamda üstte duran katmanlarda — sekme çubuğu, yüzen düğme, alttan açılan
/// sayfa — ve orada bir bilgi taşıyor.
///
/// Ritim'de karta benzeyen her şey buradan geçer; yarıçapın, payın ve kenarın
/// bütün ekranlarda aynı kalmasının sebebi budur.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(Gap.card),
    this.selected = false,
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

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.md);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.hairline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
