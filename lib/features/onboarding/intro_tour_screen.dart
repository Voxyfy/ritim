import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/timeline_node.dart';
import '../../data/db/database.dart';
import 'widgets/demo_rows.dart';

/// Kurulumdan sonra bir kez gösterilen tek ekranlık tanıtım.
///
/// Uygulamanın hızlı yolları keşfedilmeden kalıyordu: daireye dokunup süre
/// seçmek, "Başla" ile odaklanmak, tek satırla iş eklemek. Bunlar menüde
/// durmuyor, hareketin kendisinde saklı; anlatmazsan görünmüyor.
///
/// Her adım düz metin değil, o hareketin uygulamadaki küçük görünümüyle
/// birlikte. Öğrenci "daireye dokun" cümlesini okumaktan çok, dokunacağı
/// daireyi ve ardından çıkan dakika seçeneklerini görünce hatırlıyor.
///
/// Adımlar uygulamanın zaman çizgisi diliyle dizili: içeride göreceği
/// düğümler ve çizgi burada da var.
///
/// Eskiden üç sayfaydı; ikinci ve üçüncü "Devam" çoğu kullanıcının hiç
/// okumadan geçtiği iki dokunuştu. Tek ekran kaydırılarak okunuyor, tek
/// düğmeyle geçiliyor.
class IntroTourScreen extends ConsumerWidget {
  const IntroTourScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.section,
                  Gap.page,
                  Gap.xl,
                ),
                children: [
                  Text('Ritim böyle çalışır', style: text.headlineMedium),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'Dört hareket, hepsi bir iki dokunuş.',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Gap.xxl),
                  const _Step(
                    number: 1,
                    title: 'Daireye dokun, süreyi seç',
                    body: 'Çalıştığın işin dairesine dokun, kaç dakika '
                        'çalıştığını seç. Kayıt bu kadar.',
                    demo: _QuickLogDemo(),
                    isFirst: true,
                  ),
                  const _Step(
                    number: 2,
                    title: 'Başla de, odaklan',
                    body: 'Sıradaki işi zamanlayıcıyla çalış. Bitirince süre '
                        'kendiliğinden yazılır.',
                    demo: _FocusDemo(),
                  ),
                  const _Step(
                    number: 3,
                    title: 'Yaz, Ritim anlasın',
                    body: 'İş eklerken ders, konu ve günü tek satıra yaz.',
                    demo: _QuickAddDemo(),
                  ),
                  const _Step(
                    number: 4,
                    title: 'Tekrarı Ritim planlasın',
                    body: 'Çalıştığın konu 1, 3, 7 ve 21 gün sonra '
                        'kendiliğinden geri gelir.',
                    demo: _LadderDemo(),
                    isLast: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.md,
                Gap.page,
                Gap.xxl,
              ),
              child: FilledButton(
                // Yönlendirici bu bayrağı izliyor; gezinmeyi o yapar.
                onPressed: () => ref
                    .read(databaseProvider)
                    .writeSetting(SettingKeys.tourSeen, 'true'),
                child: const Text('Başla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Numaralı düğüm, başlık, kısa açıklama ve hareketin küçük görünümü.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    required this.demo,
    this.isFirst = false,
    this.isLast = false,
  });

  /// Adım düğümleri nötr: ders rengi içerideki gerçek dersler için ayrılmış,
  /// tanıtım bir derse ait değil.
  static const _neutral =
      SubjectColor(AppColors.textPrimary, AppColors.surfaceMuted);

  final int number;
  final String title;
  final String body;
  final Widget demo;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Düğüm başlık hizasında dursun diye çizgi üstte kısa kalıyor;
          // ortalanmış düğüm uzun gösterimli adımlarda başlıktan kopuyordu.
          SizedBox(
            width: 32,
            child: Column(
              children: [
                SizedBox(
                  height: Gap.xs,
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isFirst ? Colors.transparent : AppColors.border,
                    ),
                  ),
                ),
                TimelineNode(
                  colour: _neutral,
                  letter: '$number',
                  size: 32,
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : AppColors.border,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Gap.section),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Gap.xs),
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  ExcludeSemantics(child: _DemoFrame(child: demo)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gösterimlerin beyaz çerçevesi: içerideki kartlarla aynı yüzey.
class _DemoFrame extends StatelessWidget {
  const _DemoFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: child,
    );
  }
}

class _QuickLogDemo extends StatelessWidget {
  const _QuickLogDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DemoTaskRow(
          colour: DemoSubjects.matematik,
          letter: 'M',
          title: 'Üslü İfadeler',
          meta: 'Matematik · plan',
          trailing: _PointingCheck(),
          isFirst: true,
          isLast: true,
        ),
        SizedBox(height: Gap.sm),
        // Satırın içinde açılan şerit; 30 dk seçilmiş hâli.
        Padding(
          padding: EdgeInsets.only(left: 36 + Gap.md),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              DemoChip('15 dk'),
              DemoChip('30 dk', selected: true),
              DemoChip('45 dk'),
              DemoChip('60 dk'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dokunulacak daire: kiremit halkayla işaretli.
class _PointingCheck extends StatelessWidget {
  const _PointingCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: const DemoCheck(),
    );
  }
}

class _FocusDemo extends StatelessWidget {
  const _FocusDemo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: DemoTaskRow(
            colour: DemoSubjects.turkce,
            letter: 'T',
            title: 'Sözcükte Anlam',
            meta: 'Sıradaki · Türkçe',
            isFirst: true,
            isLast: true,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            // Soluk ton: ekranın asıl "Başla" düğmesi de kiremit ve iki dolu
            // kiremit düğme yan yana "hangisine basayım" sorusu doğuruyordu.
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          // RichText: düz Text olsaydı testlerdeki find.text('Başla') hem
          // bunu hem asıl düğmeyi bulup iki eşleşmeyle kırılırdı.
          child: RichText(
            text: const TextSpan(
              text: 'Başla',
              style: TextStyle(
                fontFamily: 'Jakarta',
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAddDemo extends StatelessWidget {
  const _QuickAddDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(color: AppColors.hairline),
          ),
          child: const Text(
            'yarın mat türev',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Parsed('Matematik', DemoSubjects.matematik),
            _Parsed('Türev', DemoSubjects.matematik),
            const _Parsed(
              'Yarın',
              SubjectColor(AppColors.textSecondary, AppColors.surfaceMuted),
            ),
          ],
        ),
      ],
    );
  }
}

/// Ayrıştırılmış parça: ders rengindeki küçük etiket.
class _Parsed extends StatelessWidget {
  const _Parsed(this.label, this.colour);

  final String label;
  final SubjectColor colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colour.wash,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: colour.ink,
        ),
      ),
    );
  }
}

/// 1-3-7-21 tekrar merdiveni: düğümler yatay çizgiyle bağlı, ilk basamak
/// tamamlanmış.
class _LadderDemo extends StatelessWidget {
  const _LadderDemo();

  static const _steps = [1, 3, 7, 21];

  @override
  Widget build(BuildContext context) {
    // Çizgi düğümlerin ortasından geçsin: satır üstten hizalı, çizgi düğüm
    // yüksekliğinin yarısı kadar aşağıda.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 15),
                height: 2,
                color: i == 1
                    ? DemoSubjects.matematik.ink
                    : AppColors.border,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TimelineNode(
                colour: DemoSubjects.matematik,
                filled: i == 0,
                size: 32,
                child: i == 0
                    ? const Icon(PhosphorIconsRegular.check)
                    : Text('${_steps[i]}'),
              ),
              const SizedBox(height: 4),
              Text(
                '${_steps[i]}. gün',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
