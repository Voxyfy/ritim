import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/illustration.dart';

/// İlk açılış. Tek vaat, tek düğme.
///
/// Tanıtım karuseli yok: çalışma uygulaması indiren bir öğrenciye çalışmanın
/// ne olduğunu anlatan üç slayt gerekmiyor ve buradaki her fazladan dokunuş,
/// derslerini görmeden kaybettiğimiz bir kullanıcı demek.
///
/// Sahne iki tonlu: üst yarı soluk kiremit bir pano, illüstrasyon onun
/// üstünde; alt yarı fildişi zemin ve metin. Pano, uygulamanın geri
/// kalanındaki kartlarla aynı yarıçapı taşıyor — karşılama ekranı ayrı bir
/// dil konuşmuyor, içerinin ilk kartı.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pano esnek, metin bloğu doğal yüksekliğinde. Sabit 11/9
              // oranı büyük yazı boyutunda alt bloğu taşırıyordu; panonun
              // küçülmesi metnin kesilmesinden iyidir.
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.all(Radius.circular(Radii.lg)),
                  ),
                  child: Stack(
                    children: [
                      // Panonun köşesindeki soluk halka, ders kartlarındakiyle
                      // aynı motif.
                      Positioned(
                        top: -60,
                        right: -60,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.10),
                              width: 32,
                            ),
                          ),
                          child: const SizedBox.square(dimension: 220),
                        ),
                      ),
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(Gap.section),
                          child: IllustrationView(
                            Illustration.welcome,
                            height: 240,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.md,
                  Gap.section,
                  Gap.md,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ritim', style: text.headlineLarge),
                    const SizedBox(height: Gap.sm),
                    Text(
                      'Çalışmanı düzene sok.',
                      style: text.headlineMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    Text(
                      'Konularını takip et, çalıştığını kaydet. '
                      'Tekrar zamanı geldiğinde Ritim sana hatırlatır.',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: Gap.section),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Hesap gerekmez\nVerilerin telefonunda kalır',
                            style: text.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        // Düğme metin + koyu daire. Metin "Başlayalım"
                        // olarak kaldı: hem testler hem kullanıcı ok
                        // işaretini tek başına "ileri" diye okumayabilir.
                        _StartButton(
                          onTap: () => context.go(Routes.templatePicker),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.selection,
      borderRadius: BorderRadius.circular(Radii.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.full),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xxl, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Başlayalım',
                style: TextStyle(
                  color: AppColors.onSelection,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: Gap.md),
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.onSelection,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Icon(
                      PhosphorIconsRegular.arrowRight,
                      size: IconSize.md,
                      color: AppColors.selection,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
