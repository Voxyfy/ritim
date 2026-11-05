import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/timeline_node.dart';
import '../../data/db/database.dart';
import '../../domain/exam_scoring.dart';
import 'exam_entry.dart';

/// Deneme girişi: ders ders doğru, yanlış ve boş.
///
/// Sayılar sistem klavyesiyle değil ekrana gömülü tuş takımıyla giriliyor:
/// odak kutudan kutuya kendiliğinden geçtiği için altı derslik bir LGS
/// denemesi yirmi beş dokunuştan rakam sayısı kadar dokunuşa iniyor.
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
  final _pad = ExamEntryPad();

  /// Ders satırlarının anahtarları; odak kaydırılınca satır görünür olsun diye.
  final _rowKeys = <int, GlobalKey>{};

  /// İlk ders yüklenince odak bir kez ona veriliyor: ekran açılır açılmaz
  /// yazmaya başlamak, ilk kutuya dokunma adımını siliyor.
  bool _focusStarted = false;

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
    final templateId = await ref
        .read(databaseProvider)
        .readSetting(SettingKeys.templateId);
    if (mounted) {
      setState(() => _penalty = WrongPenalty.forTemplate(templateId));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

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

  List<int> get _order => [
    for (final s in ref.read(subjectsProvider).valueOrNull ?? const <Subject>[])
      s.id,
  ];

  /// Tuş takımı eylemini uygular; odak başka derse geçtiyse o satırı
  /// görünür alana kaydırır — tuş takımı ekranın altını kapladığı için
  /// aşağıdaki dersler yoksa onun arkasında kalırdı.
  void _onPad(void Function() action) {
    final before = _pad.focus?.subjectId;
    setState(action);
    final after = _pad.focus?.subjectId;
    if (after == null || after == before) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _rowKeys[after]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: Motion.base,
          curve: Motion.curve,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  void _focusCell(CountCell cell) {
    // Ad alanında açık kalan sistem klavyesi tuş takımıyla üst üste binmesin.
    FocusScope.of(context).unfocus();
    _onPad(() => _pad.focus = cell);
  }

  Future<void> _save() async {
    if (_saving) return;
    final typed = _name.text.trim();
    final name = typed.isEmpty ? _fallbackName : typed;

    setState(() => _saving = true);

    try {
      final examId = await ref
          .read(databaseProvider)
          .saveMockExam(
            name: name,
            takenOn: _takenOn,
            penalty: _penalty ?? WrongPenalty.none,
            results: _pad.results(_order),
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
    final subjects =
        ref.watch(subjectsProvider).valueOrNull ?? const <Subject>[];
    final text = Theme.of(context).textTheme;
    if (!_focusStarted && subjects.isNotEmpty) {
      _focusStarted = true;
      _pad.focus = (subjectId: subjects.first.id, field: CountField.correct);
    }
    final padOpen = _pad.focus != null;

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
      // Tuş takımı alt çubuk olarak duruyor: liste onun üstünde bitiyor ve
      // son ders tuşların arkasında kalmıyor.
      bottomNavigationBar: padOpen
          ? _NumberPad(
              onDigit: (d) => _onPad(() => _pad.typeDigit(d, _order)),
              onBackspace: () => _onPad(_pad.backspace),
              onNext: () => _onPad(() => _pad.advance(_order)),
            )
          : null,
      body: ListView(
        // Tuş takımı kapalıyken alt boşluk hem yüzen sekme çubuğunu hem
        // klavyeyi hesaba katıyor. Yalnızca sabit bir pay verildiğinde son
        // ders çubuğun altında kalıyor ve klavye açıkken hiç ulaşılamıyordu.
        padding: EdgeInsets.fromLTRB(
          Gap.page,
          Gap.sm,
          Gap.page,
          padOpen
              ? Gap.xl
              : Gap.listBottom + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            // Ada yazarken tuş takımı iniyor; iki klavye aynı anda açık kalmaz.
            onTap: () => setState(() => _pad.focus = null),
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
          Text('Girmediğin dersler kaydedilmez.', style: text.bodySmall),
          const SizedBox(height: Gap.md),
          for (final subject in subjects) ...[
            _SubjectRow(
              key: _rowKeys.putIfAbsent(subject.id, GlobalKey.new),
              subject: subject,
              pad: _pad,
              onFocus: _focusCell,
            ),
            const SizedBox(height: Gap.xl),
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
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Text('Tarih', style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            DateFormat('d MMMM yyyy', 'tr_TR').format(date),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.selection,
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
          color: selected ? AppColors.selection : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(
            color: selected ? AppColors.selection : AppColors.hairline,
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
            color: selected ? AppColors.onSelection : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.pad,
    required this.onFocus,
    super.key,
  });

  final Subject subject;
  final ExamEntryPad pad;
  final ValueChanged<CountCell> onFocus;

  @override
  Widget build(BuildContext context) {
    Widget cell(CountField field, String label) {
      final ref = (subjectId: subject.id, field: field);
      return Expanded(
        child: _CountCell(
          label: label,
          value: pad.valueOf(ref),
          focused: pad.focus == ref,
          onTap: () => onFocus(ref),
        ),
      );
    }

    // Kart yok: satır sayfa zemininde, kimlik ders düğümünde. Kutular adın
    // altında, düğümün sağında hizalanıyor; göz önce dersi, sonra kutuları
    // görüyor.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: TimelineNode(
            colour: SubjectPalette.at(subject.colorIndex),
            letter: subject.name.characters.firstOrNull,
            done: false,
            isFirst: true,
            isLast: true,
            size: 36,
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subject.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  cell(CountField.correct, 'Doğru'),
                  const SizedBox(width: Gap.sm),
                  cell(CountField.wrong, 'Yanlış'),
                  const SizedBox(width: Gap.sm),
                  cell(CountField.blank, 'Boş'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tek sayı kutusu. Metin alanı değil: dokununca sistem klavyesi açılmasın,
/// odak tuş takımına geçsin diye.
class _CountCell extends StatelessWidget {
  const _CountCell({
    required this.label,
    required this.value,
    required this.focused,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: focused,
      label: label,
      value: value,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.quick,
          height: 56,
          decoration: BoxDecoration(
            // Satır zeminde; kutuyu zeminden beyaz ayırıyor.
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(
              color: focused ? AppColors.selection : AppColors.hairline,
              width: focused ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                value.isEmpty ? '–' : value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: value.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ekranın altına sabit sayı tuş takımı.
///
/// Telefon tuş takımının dört satırı yerine üç satır, dört sütun: yüzen
/// sekme çubuğunun üstünde dört satır, küçük ekranda listeye neredeyse hiç
/// yer bırakmıyordu. Göz alışkın sıralamayı bulsun diye 1-9 yine soldan
/// sağa, yukarıdan aşağıya; sıfır, sil ve "Sonraki" sağ sütunda.
class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.onDigit,
    required this.onBackspace,
    required this.onNext,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    Widget key({
      required Key key,
      required Widget child,
      required VoidCallback onTap,
      String? label,
    }) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xs),
          child: Semantics(
            button: true,
            label: label,
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              child: InkWell(
                key: key,
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
                child: SizedBox(height: 56, child: Center(child: child)),
              ),
            ),
          ),
        ),
      );
    }

    Widget digit(int d) => key(
      key: Key('tus-$d'),
      onTap: () => onDigit(d),
      child: Text(
        '$d',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );

    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Gap.page - Gap.xs,
            Gap.sm,
            Gap.page - Gap.xs,
            Gap.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [digit(1), digit(2), digit(3), digit(0)]),
              Row(
                children: [
                  digit(4),
                  digit(5),
                  digit(6),
                  key(
                    key: const Key('tus-sil'),
                    label: 'Sil',
                    onTap: onBackspace,
                    child: const Icon(
                      PhosphorIconsRegular.backspace,
                      size: IconSize.lg,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  digit(7),
                  digit(8),
                  digit(9),
                  key(
                    key: const Key('tus-sonraki'),
                    onTap: onNext,
                    child: const Text(
                      'Sonraki',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
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
