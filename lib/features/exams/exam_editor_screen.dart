import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../data/db/database.dart';
import '../../domain/exam_scoring.dart';

/// Deneme girişi: ders ders doğru, yanlış ve boş.
///
/// Tek ekran, tek kaydırma. Ders başına ayrı sayfa açmak, sekiz derslik bir
/// denemeyi girmeyi sekiz ekranlık bir işe çeviriyordu — öğrenci denemeyi
/// çözdükten sonra bunu yapmaz.
class ExamEditorScreen extends ConsumerStatefulWidget {
  const ExamEditorScreen({super.key});

  @override
  ConsumerState<ExamEditorScreen> createState() => _ExamEditorScreenState();
}

class _ExamEditorScreenState extends ConsumerState<ExamEditorScreen> {
  final _name = TextEditingController();
  final _controllers = <int, ({
    TextEditingController correct,
    TextEditingController wrong,
    TextEditingController blank,
  })>{};

  DateTime _takenOn = DateTime.now();
  WrongPenalty? _penalty;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPenaltyDefault();
  }

  /// Yanlış götürme kuralının varsayılanı, kurulumda seçilen şablondan
  /// türetiliyor: LGS öğrencisine "kaç yanlış bir doğru götürür" diye sormak
  /// gereksiz, cevabı zaten biliyoruz.
  Future<void> _loadPenaltyDefault() async {
    final templateId =
        await ref.read(databaseProvider).readSetting(SettingKeys.templateId);
    if (mounted) {
      setState(() => _penalty = WrongPenalty.forTemplate(templateId));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in _controllers.values) {
      c.correct.dispose();
      c.wrong.dispose();
      c.blank.dispose();
    }
    super.dispose();
  }

  int _read(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  /// Boş bırakılan ada tarihten bir karşılık üretiliyor.
  ///
  /// Ad alanı ekranın en üstünde; ders sonuçlarını girmek için aşağı kaydıran
  /// öğrenci onu hiç görmüyor. Önceden ad boşsa `_save` sessizce geri
  /// dönüyordu: düğme basılıyor, hiçbir şey olmuyor, hiçbir şey de
  /// söylenmiyordu. App Review'un "Kaydet tepkisiz" diye reddettiği davranış
  /// buydu. Ad artık zorunlu değil ve üretilen karşılık alanın ipucunda
  /// yazılı, yani kaydedilecek ad basmadan önce görünüyor.
  String get _fallbackName =>
      '${DateFormat('d MMMM', 'tr_TR').format(_takenOn)} denemesi';

  Future<void> _save() async {
    if (_saving) return;
    final typed = _name.text.trim();
    final name = typed.isEmpty ? _fallbackName : typed;

    setState(() => _saving = true);

    final results = <int, ({int correct, int wrong, int blank})>{};
    _controllers.forEach((subjectId, c) {
      results[subjectId] = (
        correct: _read(c.correct),
        wrong: _read(c.wrong),
        blank: _read(c.blank),
      );
    });

    try {
      final examId = await ref.read(databaseProvider).saveMockExam(
            name: name,
            takenOn: _takenOn,
            penalty: _penalty ?? WrongPenalty.none,
            results: results,
          );

      if (mounted) context.go('${Routes.exams}/$examId');
    } catch (error) {
      // Yazma başarısız olursa düğme kilitli kalmamalı: bir daha basılamayan
      // Kaydet, kullanıcının gözünde tepkisiz Kaydet'tir.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deneme kaydedilemedi. Tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const <Subject>[];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni deneme'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: ListView(
        // Alt boşluk hem yüzen sekme çubuğunu hem klavyeyi hesaba katıyor.
        // Yalnızca sabit bir pay verildiğinde son ders çubuğun altında
        // kalıyor ve klavye açıkken hiç ulaşılamıyordu.
        padding: EdgeInsets.fromLTRB(
          Gap.page,
          Gap.sm,
          Gap.page,
          Gap.listBottom + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              // İpucu, alan boş bırakılırsa kaydedilecek adın kendisi.
              hintText: _fallbackName,
              border: InputBorder.none,
              hintStyle: const TextStyle(color: AppColors.textTertiary),
            ),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: Gap.lg),
          _DateRow(
            date: _takenOn,
            onPick: (date) => setState(() => _takenOn = date),
          ),
          const SizedBox(height: Gap.xxl),
          Text('Yanlış götürme', style: text.titleMedium),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              for (final penalty in WrongPenalty.values) ...[
                if (penalty != WrongPenalty.values.first)
                  const SizedBox(width: Gap.sm),
                Expanded(
                  child: _PenaltyChip(
                    penalty: penalty,
                    selected: _penalty == penalty,
                    onTap: () => setState(() => _penalty = penalty),
                  ),
                ),
              ],
            ],
          ),
          if (_penalty != null) ...[
            const SizedBox(height: Gap.md),
            Text(
              '${_penalty!.label} · ${_penalty!.examples}',
              style: text.bodySmall,
            ),
          ],
          const SizedBox(height: Gap.xxl),
          Text('Ders sonuçları', style: text.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            'Girmediğin dersler kaydedilmez.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Gap.md),
          for (final subject in subjects) ...[
            _SubjectRow(
              subject: subject,
              controllers: _controllers.putIfAbsent(
                subject.id,
                () => (
                  correct: TextEditingController(),
                  wrong: TextEditingController(),
                  blank: TextEditingController(),
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onPick});

  final DateTime date;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          // Deneme geçmişe ait bir olay; ileri tarih seçmek anlamsız.
          firstDate: DateTime(DateTime.now().year - 2),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPick(picked);
      },
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      child: Row(
        children: [
          Text('Tarih', style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            DateFormat('d MMMM yyyy', 'tr_TR').format(date),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _PenaltyChip extends StatelessWidget {
  const _PenaltyChip({
    required this.penalty,
    required this.selected,
    required this.onTap,
  });

  final WrongPenalty penalty;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          penalty.shortLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject, required this.controllers});

  final Subject subject;
  final ({
    TextEditingController correct,
    TextEditingController wrong,
    TextEditingController blank,
  }) controllers;

  @override
  Widget build(BuildContext context) {
    final colour = SubjectPalette.at(subject.colorIndex);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colour.ink,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                subject.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: _CountField(
                  controller: controllers.correct,
                  label: 'Doğru',
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _CountField(
                  controller: controllers.wrong,
                  label: 'Yanlış',
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _CountField(
                  controller: controllers.blank,
                  label: 'Boş',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountField extends StatelessWidget {
  const _CountField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        // Üç haneden fazla soru olan bir ders yok; yanlış basılan bir tuş
        // neti anlamsız hâle getiriyordu.
        LengthLimitingTextInputFormatter(3),
      ],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        labelStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
      ),
    );
  }
}
