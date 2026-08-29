import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/illustration.dart';
/// İlk açılış. Tek vaat, tek düğme.
///
/// Tanıtım karuseli yok: çalışma uygulaması indiren bir öğrenciye çalışmanın
/// ne olduğunu anlatan üç slayt gerekmiyor ve buradaki her fazladan dokunuş,
/// derslerini görmeden kaybettiğimiz bir kullanıcı demek.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Center(
                child: IllustrationView(Illustration.welcome, height: 220),
              ),
              const SizedBox(height: Gap.block),
              // Marka işareti buradan kaldırıldı: illüstrasyonun altında
              // küçültülmüş hâliyle ne işaret ne süs olarak okunuyordu, bir
              // arıza gibi duruyordu. Sahneyi illüstrasyon taşıyor, kimliği
              // adın kendisi taşıyor. İşaret uygulama ikonunda yaşayacak.
              Text('Ritim', style: text.headlineMedium?.copyWith(fontSize: 40)),
              const SizedBox(height: Gap.md),
              Text(
                'Çalışmanı düzene sok.',
                style: text.headlineMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Gap.xl),
              Text(
                'Konularını takip et, çalıştığını kaydet. '
                'Tekrar zamanı geldiğinde Ritim sana hatırlatır.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: () => context.go(Routes.templatePicker),
                child: const Text('Başlayalım'),
              ),
              const SizedBox(height: Gap.md),
              Center(
                child: Text(
                  'Hesap gerekmez · Verilerin telefonunda kalır',
                  style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
