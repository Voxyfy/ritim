import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/illustration.dart';
import '../../data/db/database.dart';
/// Kurulumdan sonra bir kez gösterilen üç adımlık tanıtım.
///
/// Uygulamanın keşfedilmesi zor tek yanı çekirdek döngüsü: konuya çalış →
/// "Çalıştım" de → tekrar kendiliğinden planlansın. Görev listesi ve ders
/// listesi kendini anlatıyor, o döngü anlatmazsan görünmüyor.
///
/// Widget'lara tutturulan ipucu balonları (coach marks) yerine tam ekran
/// adımlar tercih edildi: balonlar ekran boyutuna, klavyeye ve listedeki
/// öğe sayısına göre kayıyor, üç ekranda kırılgan bir yapı kuruyordu.
class IntroTourScreen extends ConsumerStatefulWidget {
  const IntroTourScreen({super.key});

  @override
  ConsumerState<IntroTourScreen> createState() => _IntroTourScreenState();
}

class _IntroTourScreenState extends ConsumerState<IntroTourScreen> {
  static const _steps = <_Step>[
    _Step(
      illustration: Illustration.studying,
      title: 'Konularını takip et',
      body: 'Her dersin altında konular var. Hangisine başladın, hangisini '
          'bitirdin — hepsi tek ekranda.',
    ),
    _Step(
      illustration: Illustration.reviewTime,
      title: 'Çalıştıkça kaydet',
      body: 'Bir konuya çalıştıktan sonra "Çalıştım" de. Süreyi, çözdüğün '
          'soruyu ve aklında kalan notu yaz — üç dokunuş.',
    ),
    _Step(
      illustration: Illustration.allDone,
      title: 'Tekrarı Ritim planlasın',
      body: 'Çalıştığın konu 1, 3, 7 ve 21 gün sonra kendiliğinden karşına '
          'çıkar. Çok yanlış yaptığın konu daha sık gelir.',
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(databaseProvider).writeSetting(SettingKeys.tourSeen, 'true');
  }

  void _next() {
    if (_index == _steps.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: Motion.base,
      curve: Motion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isLast = _index == _steps.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: TextButton(
                  // Atlamak her adımda mümkün: öğreticiyi zorunlu tutmak,
                  // uygulamayı zaten anlamış kullanıcıyı cezalandırmak olur.
                  onPressed: _finish,
                  child: const Text(
                    'Atla',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IllustrationView(step.illustration, height: 200),
                        const SizedBox(height: Gap.block),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: text.headlineMedium,
                        ),
                        const SizedBox(height: Gap.md),
                        Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  AnimatedContainer(
                    duration: Motion.base,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.accent : AppColors.border,
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: FilledButton(
                onPressed: _next,
                child: Text(isLast ? 'Hadi başlayalım' : 'Devam'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final Illustration illustration;
  final String title;
  final String body;
}
