import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../data/templates/study_template.dart';
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
      await ref.read(databaseProvider).applyTemplate(template);
      // Burada bilerek gezinme yok: yönlendirici kurulum bayrağını izliyor ve
      // işlem tamamlanır tamamlanmaz bizi taşıyor.
    } catch (error) {
      if (!mounted) return;
      setState(() => _applying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şablon uygulanamadı, tekrar deneyin.')),
      );
    }
  }

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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                    for (final group in StudyTemplate.byGroup(list).entries) ...[
                      _GroupHeader(group.key),
                      for (final template in group.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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

    return AppCard(
      onTap: onTap,
      selected: selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(template.name, style: text.titleMedium),
              ),
              _SelectionDot(selected: selected),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            template.description,
            style: text.bodySmall?.copyWith(height: 1.4),
          ),
          if (!isBlank) ...[
            const SizedBox(height: Gap.lg),
            _SubjectChips(subjects: template.subjects),
            const SizedBox(height: Gap.md),
            Text(
              '${template.subjects.length} ders · ${template.topicCount} konu',
              style: text.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Şablonun oluşturacağı dersler, renk kodlu rozetler hâlinde.
///
/// En fazla dördünü gösterir, kalanı sayar: tam liste TYT kartını diğerlerinin
/// üç katı yükseklikte yapar ve kesinleştirme düğmesini gömerdi.
class _SubjectChips extends StatelessWidget {
  const _SubjectChips({required this.subjects});

  static const _visible = 4;

  final List<TemplateSubject> subjects;

  @override
  Widget build(BuildContext context) {
    final shown = subjects.take(_visible).toList();
    final hidden = subjects.length - shown.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final subject in shown)
          _Chip(
            label: subject.name,
            color: SubjectPalette.at(subject.colorIndex),
          ),
        if (hidden > 0)
          _Chip(
            label: '+$hidden',
            color: const SubjectColor(
              AppColors.textSecondary,
              AppColors.surfaceMuted,
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final SubjectColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.wash,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.ink,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.quick,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.accent : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(
              PhosphorIconsRegular.check,
              size: IconSize.sm,
              color: AppColors.onAccent,
            )
          : null,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
