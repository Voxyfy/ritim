import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';

/// Sekmeleri taşıyan kabuk.
///
/// Sekme çubuğu ekranın altına yapışık değil, yüzüyor: iOS'ta ekranın en
/// altındaki şerit sistem çubuğuyla karışıyor ve kartlarla aynı yarıçapı
/// paylaşan yüzen bir çubuk arayüzün geri kalanıyla aynı dili konuşuyor.
///
/// Sekmeler yalnızca ikon, etiket yok. 1.0'da etiket vardı; beş sekmeye 10.5
/// puntoluk yazı sıkıştırınca çubuk bir hap değil bir şerit gibi okunuyordu.
/// Seçili sekme koyu bir daireyle işaretleniyor ve daire sekmeler arasında
/// kayıyor: gözün takip ettiği şey ikonun rengi değil, hareket eden yüzey.
/// Erişilebilirlik için her sekmenin adı [Semantics] etiketinde duruyor.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (
      icon: PhosphorIconsRegular.sun,
      active: PhosphorIconsFill.sun,
      label: 'Bugün',
      key: Key('sekme-bugun'),
    ),
    (
      icon: PhosphorIconsRegular.calendarBlank,
      active: PhosphorIconsFill.calendarBlank,
      label: 'Plan',
      key: Key('sekme-plan'),
    ),
    (
      icon: PhosphorIconsRegular.books,
      active: PhosphorIconsFill.books,
      label: 'Dersler',
      key: Key('sekme-dersler'),
    ),
    (
      icon: PhosphorIconsRegular.chartLineUp,
      active: PhosphorIconsFill.chartLineUp,
      label: 'Denemeler',
      key: Key('sekme-deneme'),
    ),
    // Ayarlar ayda bir açılan bir ekran ve ana gezinmenin beşte birini
    // kaplıyor. Yine de sekmede: önce Dersler başlığındaki dişli ikonunun
    // arkasındaydı ve kullanıcı arayıp bulamadı. Bulunamayan bir ayar ekranı
    // hiç yok demek.
    (
      icon: PhosphorIconsRegular.gear,
      active: PhosphorIconsFill.gear,
      label: 'Ayarlar',
      key: Key('sekme-ayarlar'),
    ),
  ];

  /// Sekme başına genişlik ve çubuk yüksekliği.
  ///
  /// Çubuk içeriği kadar geniş; ekrana yayılmıyor. Seçili daire çubuğun
  /// yüksekliğinden 12 piksel küçük, yani her yanda 6 piksel beyaz pay var.
  static const _tabWidth = 60.0;
  static const _barHeight = 64.0;
  static const _inset = 6.0;

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Gap.md),
          // heightFactor olmadan Center bütün boşluğu kaplayıp çubuğu dikeyde
          // de ortalıyor; çubuk ekranın ortasında asılı kalıyordu.
          child: Center(
            heightFactor: 1,
            child: Container(
              height: _barHeight,
              width: _tabWidth * _tabs.length + _inset * 2,
              padding: const EdgeInsets.all(_inset),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.all(Radius.circular(Radii.full)),
                boxShadow: AppColors.floatingShadow,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = constraints.maxWidth / _tabs.length;
                  final dot = constraints.maxHeight;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: Motion.base,
                        curve: Motion.curve,
                        left: slot * index + (slot - dot) / 2,
                        top: 0,
                        width: dot,
                        height: dot,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.selection,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < _tabs.length; i++)
                            Expanded(
                              child: _TabButton(
                                tab: _tabs[i],
                                selected: index == i,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  navigationShell.goBranch(
                                    i,
                                    // Seçili sekmeye tekrar dokunmak o sekmeyi
                                    // köküne döndürür; iOS'ta beklenen
                                    // davranış bu.
                                    initialLocation: i == index,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData active, String label, Key key}) tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tab.label,
      selected: selected,
      button: true,
      child: GestureDetector(
        key: tab.key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          // İkon seçilince hafifçe büyüyor. Dokunuşun karşılığını görmek,
          // sekmenin gerçekten değiştiğini anlatan en ucuz işaret.
          child: AnimatedScale(
            scale: selected ? 1.08 : 1,
            duration: Motion.quick,
            curve: Motion.curve,
            child: Icon(
              selected ? tab.active : tab.icon,
              size: IconSize.lg,
              color: selected ? AppColors.onSelection : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
