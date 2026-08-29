import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
/// "Çalıştım" akışı: süre, isteğe bağlı soru sayıları ve not.
///
/// Üç dokunuşta bitmesi gerekiyor; bu yüzden süre serbest metin değil hazır
/// rozetler. Soru alanları sınava hazırlanmayanlar için görünür ama zorunlu
/// değil — veri yoksa tekrar motoru sabit aralıklara düşüyor.
class LogSessionSheet extends ConsumerStatefulWidget {
  const LogSessionSheet({required this.topicId, this.taskId, super.key});

  final int topicId;

  /// Bu kayıt bir görevin tamamlanmasıyla açıldıysa o görevin kimliği.
  /// Kayıt yazıldığında görev de kapanır.
  final int? taskId;

  static Future<bool?> show(
    BuildContext context,
    int topicId, {
    int? taskId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => LogSessionSheet(topicId: topicId, taskId: taskId),
    );
  }

  @override
  ConsumerState<LogSessionSheet> createState() => _LogSessionSheetState();
}

class _LogSessionSheetState extends ConsumerState<LogSessionSheet> {
  /// Dakika seçenekleri. Bir ders saati (40) ve pomodoro (25) bilerek listede.
  static const _presets = [15, 25, 40, 60, 90, 120];

  int _minutes = 40;

  /// "Bu konuyu bitirdim" işaretli mi?
  ///
  /// Bir konuyu bitmiş saymanın tek yolu konu detayındaki anahtardı; günlük
  /// listeden çalışan ve buradan kayıt giren öğrenci oraya hiç girmiyor,
  /// ilerlemesi sonsuza kadar %0 kalıyordu. Doğru soru anı burası: çalışmayı
  /// yeni bitirdin, konunun bittiğini de en iyi şimdi biliyorsun.
  bool _markDone = false;
  final _solved = TextEditingController();
  final _wrong = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _solved.dispose();
    _wrong.dispose();
    _note.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    return value == null || value < 0 ? null : value;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final solved = _parse(_solved);
    var wrong = _parse(_wrong);
    // Yanlış sayısı çözülenden büyük olamaz; kullanıcıyı hata mesajıyla
    // durdurmak yerine sessizce kırpıyoruz, çünkü bu alan zaten isteğe bağlı.
    if (solved != null && wrong != null && wrong > solved) wrong = solved;

    final db = ref.read(databaseProvider);
    if (_markDone) await db.setTopicDone(widget.topicId, done: true);
    final taskId = widget.taskId;
    if (taskId == null) {
      await db.logStudySession(
        topicId: widget.topicId,
        minutes: _minutes,
        questionsSolved: solved,
        questionsWrong: solved == null ? null : (wrong ?? 0),
        note: _note.text,
      );
    } else {
      await db.completeTaskAsStudied(
        taskId,
        minutes: _minutes,
        questionsSolved: solved,
        questionsWrong: solved == null ? null : (wrong ?? 0),
        note: _note.text,
      );
    }

    if (mounted) {
      unawaited(HapticFeedback.mediumImpact());
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                ),
              ),
              const SizedBox(height: Gap.xl),
              Text('Ne kadar çalıştın?', style: text.titleMedium),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in _presets)
                    _MinuteChip(
                      minutes: minutes,
                      selected: _minutes == minutes,
                      onTap: () => setState(() => _minutes = minutes),
                    ),
                ],
              ),
              const SizedBox(height: Gap.xxl),
              Text('Soru çözdün mü?', style: text.titleMedium),
              const SizedBox(height: Gap.xs),
              Text('İstersen boş bırak.', style: text.bodySmall),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _solved,
                      label: 'Çözülen',
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: _NumberField(
                      controller: _wrong,
                      label: 'Yanlış',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xxl),
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Not: neyi karıştırdın?',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: Gap.xl),
              _DoneCheck(
                value: _markDone,
                onChanged: (value) => setState(() => _markDone = value),
              ),
              const SizedBox(height: Gap.lg),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinuteChip extends StatelessWidget {
  const _MinuteChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          minutes < 60 ? '$minutes dk' : '${minutes ~/ 60} sa',
          style: TextStyle(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

/// "Bu konuyu bitirdim" seçeneği.
///
/// Varsayılan kapalı: çalışmak bitirmek değil. Ama seçenek burada olmalı,
/// çünkü konunun bittiğini anlayan kişi tam bu anda çalışmayı bırakan kişidir.
class _DoneCheck extends StatelessWidget {
  const _DoneCheck({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          AnimatedContainer(
            duration: Motion.quick,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? AppColors.progress : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.xs + 2),
              border: Border.all(
                color: value ? AppColors.progress : AppColors.border,
                width: 2,
              ),
            ),
            child: value
                ? const Icon(
                    PhosphorIconsRegular.check,
                    size: 14,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: Gap.md),
          Text(
            'Bu konuyu bitirdim',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
