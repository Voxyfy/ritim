import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../data/db/database.dart';
import '../../data/templates/study_template.dart';
import '../plan/weekly_plan_sheet.dart';

/// Kurulumun ikinci ve son adımı: neye çalıştığını seç.
///
/// Seçim dokunuşta uygulanmaz. On beş şablonun en büyüğü 130 satır yazıyor ve
/// yanlış bir dokunuşun kullanıcının derslerini sessizce yeniden yazması kötü
/// bir ilk izlenim olurdu; bu yüzden dokunmak yalnızca seçer, tek bir düğme
/// kesinleştirir.
class TemplatePickerScreen extends ConsumerStatefulWidget {
  const TemplatePickerScreen({super.key});

  @override
  ConsumerState<TemplatePickerScreen> createState() =>
      _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends ConsumerState<TemplatePickerScreen> {
  StudyTemplate? _selected;
  bool _applying = false;

  Future<void> _apply() async {
    final template = _selected;
    if (template == null || _applying) return;

    setState(() => _applying = true);
    try {
      // Veritabanı baştan alınıyor: kurulum bayrağı yazılınca yönlendirici
      // bu ekranı söküyor ve sonrasında `ref` kullanılamıyor.
      final db = ref.read(databaseProvider);
      await db.applyTemplate(template);
      // Burada bilerek gezinme yok: yönlendirici kurulum bayrağını izliyor ve
      // işlem tamamlanır tamamlanmaz bizi taşıyor.
      if (template.subjects.isNotEmpty) await _buildFirstPlan(db);
    } catch (error) {
      if (!mounted) return;
      setState(() => _applying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şablon uygulanamadı, tekrar deneyin.')),
      );
    }
  }

  /// İlk açılışta Bugün boş gelmesin diye iki haftalık plan kurulur.
  ///
  /// Boş bir liste "şimdi ne yapacağım?" sorusunu öğrenciye bırakıyordu;
  /// dolu bir liste ilk görevi gösteriyor. Bugünün günü her zaman eklenir:
  /// hafta sonu kuran öğrenci de ilk ekranda iş görsün. "Kendin kur"da konu
  /// olmadığı için atlanıyor. Tercihler kaydedildiğinden "Plan kur" bu
  /// düzenle açılır ve öğrenci değiştirebilir.
  static Future<void> _buildFirstPlan(RitimDatabase db) => db.buildWeeklyPlan(
    weekdays: {...WeeklyPlanSheet.defaultWeekdays, DateTime.now().weekday},
    perDay: WeeklyPlanSheet.defaultPerDay,
    weeks: 2,
  );

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(templatesProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neye çalışıyorsun?'),
        // Geri oku elle konuyor: kurulum akışı `go` ile ilerliyor ve yığında
        // pop edilecek bir sayfa bırakmıyor, bu yüzden Flutter'ın kendiliğinden
        // koyduğu ok görünmüyordu. Karşılamaya dönebilmek gerekiyor.
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.caretLeft),
          onPressed: () => context.go(Routes.welcome),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: templates.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _ErrorState(
                  onRetry: () => ref.invalidate(templatesProvider),
                ),
                data: (list) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.sm,
                    Gap.page,
                    Gap.xxl,
                  ),
                  children: [
                    Text(
                      'Hedefini seç, dersler ve konular hazır gelsin. '
                      'Hepsini sonradan değiştirebilirsin.',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: Gap.xxl),
                    for (final group in StudyTemplate.byGroup(
                      list,
                    ).entries) ...[
                      _GroupHeader(group.key),
                      for (final template in group.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Gap.sm),
                          child: _TemplateCard(
                            template: template,
                            selected: _selected?.id == template.id,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selected = template);
                            },
                          ),
                        ),
                      const SizedBox(height: Gap.lg),
                    ],
                  ],
                ),
              ),
            ),
            _CommitBar(
              enabled: _selected != null && !_applying,
              busy: _applying,
              onPressed: _apply,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek kesinleştirme eylemini taşıyan sabit alt çubuk.
///
/// Kaydırma alanının dışında durur; böylece düğmeye ulaşmak için on beş
/// kartlık listenin sonuna geri kaydırmak gerekmez.
class _CommitBar extends StatelessWidget {
  const _CommitBar({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: FilledButton(
        // Kaydederken düğme devre dışı ama rengi korunuyor: Material'ın devre
        // dışı grisi üzerinde beyaz gösterge, düğmenin ortasındaki bir toz
        // zerresi gibi görünüyordu.
        style: busy
            ? FilledButton.styleFrom(
                disabledBackgroundColor: AppColors.accent,
                disabledForegroundColor: AppColors.onAccent,
              )
            : null,
        onPressed: enabled ? onPressed : null,
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.onAccent,
                ),
              )
            : const Text('Devam et'),
      ),
    );
  }
}

/// Şablon satırı: solda kısa adlı düğüm, yanında ad ve tek satır künye.
///
/// Eskiden her şablon ders rozetli büyük bir karttı ve on beş kart ekranı
/// kutu yığınına çeviriyordu. Bugün ve Plan'daki zaman çizgisi diliyle aynı
/// sade satır; seçili satır, satın alma ekranındaki plan kutuları gibi koyu
/// kenarla ayrılıyor.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final StudyTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isBlank = template.subjects.isEmpty;

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.all(Gap.md),
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
              _TemplateNode(template: template, selected: selected),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name, style: text.titleMedium),
                    const SizedBox(height: Gap.xs),
                    Text(
                      template.description,
                      style: text.bodySmall?.copyWith(height: 1.4),
                    ),
                    if (!isBlank) ...[
                      const SizedBox(height: Gap.xs),
                      Text(
                        '${template.subjects.length} ders · '
                        '${template.topicCount} konu',
                        style: text.labelSmall,
                      ),
                    ],
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

/// Şablonun kısa adını taşıyan yuvarlatılmış kare düğüm.
///
/// Seçilince koyu dolguya ve onay işaretine geçiyor; ayrı bir seçim noktası
/// satıra ikinci bir odak ekliyordu.
class _TemplateNode extends StatelessWidget {
  const _TemplateNode({required this.template, required this.selected});

  static const _size = 48.0;

  final StudyTemplate template;
  final bool selected;

  /// "LGS · 8. Sınıf" → LGS, "10. Sınıf" → 10, "YKS · TYT" → TYT.
  ///
  /// YKS altındaki beş şablonun hepsine "YKS" yazmak düğümü anlamsız
  /// kılardı; orada ayırt eden ikinci parça.
  static String shortLabel(String name) {
    final grade = RegExp(r'^(\d+)\.').firstMatch(name);
    if (grade != null) return grade.group(1)!;
    final parts = name.split(' · ');
    final head = parts.length > 1 && parts.first == 'YKS' ? parts[1] : parts[0];
    return head.split(RegExp('[ -]')).first;
  }

  @override
  Widget build(BuildContext context) {
    final isBlank = template.subjects.isEmpty;
    final ink = selected ? AppColors.onSelection : AppColors.textPrimary;
    final label = shortLabel(template.name);

    return AnimatedContainer(
      duration: Motion.quick,
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.selection : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: selected
          ? Icon(PhosphorIconsRegular.check, size: IconSize.md, color: ink)
          : isBlank
          ? Icon(PhosphorIconsRegular.plus, size: IconSize.md, color: ink)
          // Text değil RichText: testler şablonu `textContaining('LGS')`
          // ile buluyor; düğümdeki kısa ad ikinci bir eşleşme olmamalı.
          : ExcludeSemantics(
              child: RichText(
                text: TextSpan(
                  text: label,
                  style: TextStyle(
                    color: ink,
                    fontSize: label.length > 3 ? 12 : 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md, left: Gap.xs),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsRegular.warningCircle,
              size: IconSize.xl,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: Gap.lg),
            Text(
              'Şablonlar yüklenemedi.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.xl),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
