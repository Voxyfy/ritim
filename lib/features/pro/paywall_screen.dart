import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/pro.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';

final _packagesProvider = FutureProvider<List<Package>>(
  (ref) => ref.watch(proServiceProvider).packages(),
);

final _terms = Uri.parse(
  'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
);
final _privacy = Uri.parse('https://voxyfy.github.io/ritim/gizlilik.html');

/// Ritim Pro satın alma ekranı.
///
/// İki hâli var: deneme sürerken Ayarlar'dan açılır ve kapatılabilir; deneme
/// bitince yönlendirici uygulamayı buraya kilitler ve kapatma düğmesi yok.
/// Yıllık plan seçili açılıyor ve haftalık fiyat yanında duruyor: haftalık
/// planın asıl işi yıllığın ne kadar ucuz olduğunu göstermek.
///
/// Apple'ın kuralı gereği her planın **fatura edilen** tutarı en büyük
/// yazı; hesaplanmış aylık karşılık altta küçük duruyor.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  PackageType _selected = PackageType.annual;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final access = ref.watch(accessProvider);
    final locked = access?.locked ?? false;
    final packages = ref.watch(_packagesProvider);

    return PopScope(
      canPop: !locked,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: locked
                    ? const SizedBox(height: 48)
                    : IconButton(
                        tooltip: 'Kapat',
                        icon: const Icon(PhosphorIconsRegular.x),
                        onPressed: () => context.pop(),
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                  children: [
                    Text(
                      locked
                          ? 'Deneme süren doldu'
                          : 'Ritim Pro ile ritmini koru',
                      style: text.headlineMedium,
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      locked
                          ? 'Konuların, notların ve planın yerinde duruyor. '
                                'Kaldığın yerden devam etmek için bir plan seç.'
                          : access != null && access.inTrial
                          ? 'Ücretsiz denemenin bitmesine '
                                '${access.daysLeft} gün var.'
                          : 'Bütün özellikler, tek abonelik.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: Gap.xxl),
                    const _Benefit(
                      PhosphorIconsRegular.calendarCheck,
                      'Konuların günlere kendiliğinden dağıldığı haftalık plan',
                    ),
                    const _Benefit(
                      PhosphorIconsRegular.arrowsClockwise,
                      '1-3-7-21 gün tekrar merdiveni ve hatırlatmalar',
                    ),
                    const _Benefit(
                      PhosphorIconsRegular.chartLineUp,
                      'Deneme analizi ve zayıf derse özel plan',
                    ),
                    const SizedBox(height: Gap.xxl),
                    packages.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(Gap.section),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => _LoadError(
                        onRetry: () => ref.invalidate(_packagesProvider),
                      ),
                      data: (list) => _Plans(
                        packages: list,
                        selected: _selected,
                        onSelect: (t) => setState(() => _selected = t),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.md,
                  Gap.page,
                  Gap.sm,
                ),
                child: Column(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: _busy ? null : () => _buy(packages),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.onAccent,
                              ),
                            )
                          : const Text('Devam et'),
                    ),
                    const SizedBox(height: Gap.sm),
                    const Text(
                      'Abonelik, dönem bitmeden en az 24 saat önce iptal '
                      'edilmezse aynı ücretle otomatik yenilenir. İptal '
                      'etmek için Ayarlar → Apple Kimliği → Abonelikler. '
                      'Abonelik durumu RevenueCat ile doğrulanır; '
                      'çalışma verilerin telefonundan çıkmaz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                        height: 1.4,
                      ),
                    ),
                    // Wrap: dar telefonda üç bağlantı tek satıra sığmayıp
                    // taşıyordu; Apple bu bağlantıların görünür olmasını şart
                    // koşuyor.
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        _Link('Geri yükle', _busy ? null : _restore),
                        _Link('Kullanım şartları', () => launchUrl(_terms)),
                        _Link('Gizlilik', () => launchUrl(_privacy)),
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

  Future<void> _buy(AsyncValue<List<Package>> packages) async {
    final list = packages.valueOrNull ?? const <Package>[];
    final package = list.where((p) => p.packageType == _selected).firstOrNull;
    if (package == null) return;
    await _run(() => ref.read(proServiceProvider).purchase(package));
  }

  Future<void> _restore() => _run(
    () => ref.read(proServiceProvider).restore(),
    notFound: 'Bu Apple Kimliği ile etkin bir abonelik bulunamadı.',
  );

  /// Satın alma ya da geri yükleme. Başarılıysa ekran kapanır; kilitliyse
  /// yönlendirici zaten Bugün'e geçiriyor.
  Future<void> _run(Future<bool> Function() action, {String? notFound}) async {
    setState(() => _busy = true);
    try {
      final ok = await action();
      if (!mounted) return;
      if (ok) {
        unawaited(HapticFeedback.mediumImpact());
        if (context.canPop()) context.pop();
      } else if (notFound != null) {
        _snack(notFound);
      }
    } on PlatformException catch (e) {
      if (mounted) _snack('İşlem tamamlanamadı: ${e.message ?? e.code}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _Plans extends StatelessWidget {
  const _Plans({
    required this.packages,
    required this.selected,
    required this.onSelect,
  });

  final List<Package> packages;
  final PackageType selected;
  final ValueChanged<PackageType> onSelect;

  static const _order = [
    PackageType.annual,
    PackageType.monthly,
    PackageType.weekly,
  ];

  @override
  Widget build(BuildContext context) {
    Package? of(PackageType t) =>
        packages.where((p) => p.packageType == t).firstOrNull;
    final weekly = of(PackageType.weekly)?.storeProduct.price;
    final annual = of(PackageType.annual)?.storeProduct;

    return Column(
      children: [
        for (final type in _order)
          if (of(type) case final package?)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: _PlanTile(
                package: package,
                selected: selected == type,
                badge: type == PackageType.annual && weekly != null
                    ? _savingBadge(weekly, annual!.price)
                    : null,
                onTap: () => onSelect(type),
              ),
            ),
      ],
    );
  }
}

/// "%71 tasarruf": yıllık fiyatın 52 haftalık fiyata oranı.
String? _savingBadge(double weekly, double annual) {
  final saving = savingPercent(weekly: weekly, annual: annual);
  return saving <= 0 ? null : 'En avantajlı · %$saving tasarruf';
}

/// Yıllık planın haftalığa göre yüzde kaç ucuz olduğu, aşağı yuvarlanmış.
///
/// Aşağı yuvarlama bilerek: rozetteki iddia hiçbir zaman gerçek tasarruftan
/// büyük olmamalı.
int savingPercent({required double weekly, required double annual}) {
  if (weekly <= 0) return 0;
  return ((1 - annual / (weekly * 52)) * 100).floor();
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.package,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final Package package;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    final (title, period, perMonth) = switch (package.packageType) {
      PackageType.annual => (
        'Yıllık',
        '/yıl',
        '${_money(product, product.price / 12)} / ay karşılığı',
      ),
      PackageType.monthly => ('Aylık', '/ay', null),
      _ => ('Haftalık', '/hafta', null),
    };

    return Semantics(
      selected: selected,
      button: true,
      label: '$title, ${product.priceString}$period',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.all(Gap.card),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? AppColors.selection : AppColors.hairline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Daire yerine yuvarlatılmış kare: şablon seçimi ve zaman
              // çizgisi düğümleriyle aynı seçim işareti.
              AnimatedContainer(
                duration: Motion.quick,
                width: IconSize.lg,
                height: IconSize.lg,
                decoration: BoxDecoration(
                  color: selected ? AppColors.selection : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.xs),
                  border: Border.all(
                    color: selected ? AppColors.selection : AppColors.border,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        PhosphorIconsRegular.check,
                        size: IconSize.sm,
                        color: AppColors.onSelection,
                      )
                    : null,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: Gap.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.priceString}$period',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (perMonth != null)
                    Text(
                      perMonth,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ürünün para biriminde tutar.
String _money(StoreProduct product, double amount) =>
    '${product.currencyCode == 'TRY' ? '₺' : '${product.currencyCode} '}'
    '${amount.toStringAsFixed(2).replaceAll('.', ',')}';

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        children: [
          // Ayarlar satırlarındaki düğümün aynısı: ikon soluk zeminli
          // yuvarlatılmış karede.
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: SizedBox.square(
              dimension: 40,
              child: Icon(
                icon,
                size: IconSize.md,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.onTap);

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: const TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      ),
      child: Text(label),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Planlar yüklenemedi. İnternet bağlantını kontrol et.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
      ],
    );
  }
}
