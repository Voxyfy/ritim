import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
/// İki sekmeyi taşıyan kabuk.
///
/// Sekme çubuğu ekranın altına yapışık değil, yüzüyor: iOS'ta ekranın en
/// altındaki şerit sistem çubuğuyla karışıyor ve kartlarla aynı yarıçapı
/// paylaşan yüzen bir çubuk arayüzün geri kalanıyla aynı dili konuşuyor.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (icon: PhosphorIconsRegular.sun, active: PhosphorIconsFill.sun, label: 'Bugün'),
    (
      icon: PhosphorIconsRegular.calendarBlank,
      active: PhosphorIconsFill.calendarBlank,
      label: 'Plan',
    ),
    (
      icon: PhosphorIconsRegular.books,
      active: PhosphorIconsFill.books,
      label: 'Dersler',
    ),
    (
      icon: PhosphorIconsRegular.chartLineUp,
      active: PhosphorIconsFill.chartLineUp,
      // "Denemeler" 68 piksellik sekmeye sığmıyor ve taşıyordu. Etiketi
      // küçültmek yerine kısalttım: yazıyı sekmeden sekmeye farklı boyutta
      // göstermek, çubuğun tek ritmini bozar.
      label: 'Deneme',
    ),
    // Ayarlar ayda bir açılan bir ekran ve ana gezinmenin dörtte birini
    // kaplıyor. Yine de sekmede: önce Dersler başlığındaki dişli ikonunun
    // arkasındaydı ve kullanıcı arayıp bulamadı. Bulunamayan bir ayar ekranı
    // hiç yok demek.
    (
      icon: PhosphorIconsRegular.gear,
      active: PhosphorIconsFill.gear,
      label: 'Ayarlar',
    ),
  ];

  /// Sekme başına genişlik.
  ///
  /// Çubuk önce ekranın tamamına yayılıyordu; dört sekme arasında geniş
  /// boşluklar kalıyor ve çubuk yüzen bir öğeden çok bir şerit gibi
  /// duruyordu. Sabit genişlik, çubuğu içeriği kadar tutuyor.
  /// Beş sekme dar bir çubuğa sığmalı; 68 piksel, en küçük iPhone'da bile
  /// kenar payı bırakıyor.
  static const _tabWidth = 68.0;
  static const _barHeight = 58.0;

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
          // de ortalıyor; çubuk ekranın ortasında asılı kalıyordu. Değer 1
          // olunca yükseklik içerikten geliyor, ortalama yalnızca yatayda
          // kalıyor.
          child: Center(
            heightFactor: 1,
            child: Container(
              height: _barHeight,
              width: _tabWidth * _tabs.length,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(Radii.full),
                boxShadow: AppColors.floatingShadow,
                border: Border.all(color: AppColors.hairline),
              ),
              // Genişlik LayoutBuilder'dan okunuyor, elle hesaplanmıyor:
              // kutunun bir piksellik kenarı iç genişliği daraltıyor ve sabit
              // sayı iki piksel taşma üretiyordu.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = constraints.maxWidth / _tabs.length;

                  return Stack(
                    children: [
                      // Seçili sekmenin arkasında kayan vurgu. Sekme
                      // değişimini anlatan asıl işaret bu: ikonun rengi anında
                      // değişiyor, ama gözün takip ettiği şey hareket eden
                      // yüzey.
                      AnimatedPositioned(
                        duration: Motion.base,
                        curve: Motion.curve,
                        left: slot * index,
                        top: 0,
                        bottom: 0,
                        width: slot,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(Radii.full),
                            ),
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

  final ({IconData icon, IconData active, String label}) tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = selected ? AppColors.accent : AppColors.textTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // Yükseklik çubuğun tamamı kadar: içerik kendi boyunda kalınca dikeyde
      // yukarı kayıyor ve etiketin alt boşluğu yüzünden ortalanmamış
      // görünüyordu.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          // İkon seçilince hafifçe büyüyor. Dokunuşun karşılığını görmek,
          // sekmenin gerçekten değiştiğini anlatan en ucuz işaret.
          AnimatedScale(
            scale: selected ? 1.1 : 1,
            duration: Motion.quick,
            curve: Motion.curve,
            child: Icon(
              selected ? tab.active : tab.icon,
              size: IconSize.md,
              color: colour,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: Motion.quick,
            curve: Motion.curve,
            // Tema metin biçeminden türetiliyor, sıfırdan kurulmuyor.
            // Çıplak bir `TextStyle` fontFamily taşımadığı için etiketler
            // uygulamadaki tek Jakarta olmayan metin hâline geliyor ve
            // cihazda sistem yazı tipiyle çiziliyordu; ekran görüntüsü
            // çekerken fark ettik.
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  fontSize: 10.5,
                  height: 1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: colour,
                ),
            // Uzun bir etiket eklenirse taşmak yerine kırpılsın; çubuğun
            // düzeni tek bir kelimeye bağlı kalmamalı.
            child: Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
