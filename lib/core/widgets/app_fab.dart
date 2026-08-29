import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
/// Yüzen ekleme düğmesi.
///
/// Sekme çubuğu da yüzdüğü için düğme, Scaffold'un varsayılan yerinde çubuğun
/// üstüne biniyordu. Yükseklik burada tek noktadan veriliyor; her ekranın
/// kendi payını hesaplaması, ilk kaçırılan ekranda hizayı bozardı.
class AppFab extends StatelessWidget {
  const AppFab({
    required this.onPressed,
    this.icon = PhosphorIconsRegular.plus,
    this.label,
    this.heroTag,
    super.key,
  });

  /// Yüzen sekme çubuğunun üstünde bırakılan pay. Ölçü [Gap] içinde tanımlı:
  /// listelerin alt boşluğu da aynı değerden türüyor, ikisi ayrı yerlerde
  /// tutulunca hiza kaçıyordu.
  static const barClearance = Gap.floatingClearance;

  /// Sağ kenar payı. Scaffold'un varsayılan 16'sı, sekme çubuğunun 48'lik
  /// kenar boşluğunun yanında hizasız duruyordu.
  static const edgeInset = Gap.md;

  final VoidCallback onPressed;
  final IconData icon;

  /// Verilirse geniş düğme çizilir.
  final String? label;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    // Gölge düğmenin kendisinden değil kapsayıcıdan geliyor: Material'ın
    // yükseklik gölgesi rengi de tonluyor ve kiremidi soluklaştırıyordu.
    // Geniş düğmede biçim stadyum, dar düğmede daire — kapsayıcı da aynı
    // biçimi almalı, yoksa gölge köşelerden taşıyor.
    return Padding(
      padding: const EdgeInsets.only(bottom: barClearance, right: edgeInset),
      child: label == null
          ? DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppColors.floatingShadow,
              ),
              child: FloatingActionButton(
                heroTag: heroTag,
                onPressed: onPressed,
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                elevation: 0,
                // Material 3 varsayılanı yuvarlak kare; uygulamanın dili
                // dairelerden kurulu (onay daireleri, ilerleme halkaları,
                // sekme çubuğu), düğme de daire olmalı.
                shape: const CircleBorder(),
                child: Icon(icon, size: IconSize.lg),
              ),
            )
          : DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(Radii.full)),
                boxShadow: AppColors.floatingShadow,
              ),
              child: FloatingActionButton.extended(
                heroTag: heroTag,
                onPressed: onPressed,
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                elevation: 0,
                shape: const StadiumBorder(),
                icon: Icon(icon, size: IconSize.md),
                label: Text(label!),
              ),
            ),
    );
  }
}
