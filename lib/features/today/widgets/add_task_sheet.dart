import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/date_extensions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../data/db/database.dart';
import '../../../domain/quick_add_parser.dart';

/// Görev ekleme sayfası.
///
/// Tek zorunlu alan başlık. Satır akıllı: "yarın mat türev" yazan öğrenci
/// gün, ders ve konuyu rozetlerde görür, Enter'a basıp geçer. Alttaki ders
/// ve gün rozetleri elle düzeltme için duruyor; dokunulan rozet çözümlemenin
/// o kısmını geçersiz kılar.
class AddTaskSheet extends ConsumerStatefulWidget {
  const AddTaskSheet({super.key});

  /// Sayfayı açar; görev eklendiyse `true` döner.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Kök gezgin: sekme çubuğu kabuğun Scaffold'una ait olduğu için, dal
      // gezginine açılan bir sayfa çubuğun ALTINDA kalıyor ve çubuk sayfanın
      // üstünde asılı duruyordu.
      useRootNavigator: true,
      builder: (context) => const AddTaskSheet(),
    );
  }

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  final _controller = _QuickAddController();
  final _focus = FocusNode();

  /// Elle seçilen ders; [_subjectPinned] yanlışken çözümleme geçerli.
  int? _subjectId;
  bool _subjectPinned = false;
  int _dayOffset = 0;
  bool _dayPinned = false;

  /// Kullanıcının rozetine dokunarak kaldırdığı yorumlar.
  final _ignored = <QuickAddPart>{};
  bool _saving = false;

  QuickAddResult _parsed = const QuickAddResult(title: '');

  /// Başlıksız bir görev kaydedilemez. Bunu basıldığında sessizce geri dönerek
  /// anlatmak yerine düğmenin görünüşüne taşıdık: başlık boşken düğme sönük.
  bool get _canSave => !_saving && _parsed.title.trim().isNotEmpty;

  int? get _effectiveSubjectId =>
      _subjectPinned ? _subjectId : _parsed.subjectId;
  int get _effectiveDay => _dayPinned ? _dayOffset : _parsed.dayOffset ?? 0;

  /// Her çizimde yeniden çözümlenir: dersler/konular akıştan geç gelebilir
  /// ve elle seçim değiştiğinde aynı metnin yorumu da değişmeli.
  QuickAddResult _parse(List<Subject> subjects) {
    final pool = _subjectPinned
        ? subjects.where((s) => s.id == _subjectId)
        : subjects;
    final result = QuickAddParser.parse(
      _controller.text,
      today: today(),
      ignore: {..._ignored, if (_dayPinned) QuickAddPart.day},
      subjects: [
        for (final s in pool)
          QuickAddSubject(
            id: s.id,
            name: s.name,
            topics: [
              for (final t
                  in ref.watch(topicsProvider(s.id)).valueOrNull ??
                      const <Topic>[])
                QuickAddTopic(id: t.id, name: t.name),
            ],
          ),
      ],
    );
    _controller.spans = result.spans;
    return result;
  }

  @override
  void initState() {
    super.initState();
    // Düğmenin etkinliği yazılan başlığa bağlı; her tuşta yeniden çizilmeli.
    _controller.addListener(_onTitleChanged);
    // Klavye sayfayla birlikte gelsin; ekstra bir dokunuş daha istemiyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onTitleChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTitleChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final title = _parsed.title.trim();
    final subjectId = _effectiveSubjectId;
    final dayOffset = _effectiveDay;

    setState(() => _saving = true);

    // Konu çözümlendiyse görev ona bağlanır. Yalnız ders varsa dersin ilk
    // konusuna: görev satırı rengini konunun dersinden alıyor.
    var topicId = _parsed.topicId;
    if (topicId == null && subjectId != null) {
      final topics = await ref
          .read(databaseProvider)
          .watchTopics(subjectId)
          .first;
      topicId = topics.isNotEmpty ? topics.first.id : null;
    }

    try {
      await ref
          .read(databaseProvider)
          .addTask(
            title: title,
            dueOn: today().addDays(dayOffset),
            topicId: topicId,
          );

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      // Kalıcı olarak kilitli kalan bir düğme, tepkisiz bir düğmedir.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görev eklenemedi. Tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects =
        ref.watch(subjectsProvider).valueOrNull ?? const <Subject>[];
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    _parsed = _parse(subjects);
    final parsedSubject = _parsed.subjectId == null
        ? null
        : subjects.where((s) => s.id == _parsed.subjectId).firstOrNull;
    final parsedColour = parsedSubject == null
        ? null
        : SubjectPalette.at(parsedSubject.colorIndex);

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
              TextField(
                controller: _controller,
                focusNode: _focus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  hintText: 'Ne yapacaksın?',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_parsed.spans.isNotEmpty ||
                  (!_subjectPinned && parsedSubject != null)) ...[
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    if (!_subjectPinned && parsedSubject != null)
                      _ParsedChip(
                        label: parsedSubject.name,
                        colour: parsedColour,
                        // Konu dersi ima ettiği için onunla birlikte gider;
                        // yoksa konu, kaldırılan dersi geri getiriyordu.
                        onRemove: () => setState(() {
                          _ignored
                            ..add(QuickAddPart.subject)
                            ..add(QuickAddPart.topic);
                        }),
                      ),
                    if (_parsed.topicName != null)
                      _ParsedChip(
                        label: _parsed.topicName!,
                        colour: parsedColour,
                        onRemove: () =>
                            setState(() => _ignored.add(QuickAddPart.topic)),
                      ),
                    if (_parsed.dayLabel != null)
                      _ParsedChip(
                        label: _parsed.dayLabel!,
                        onRemove: () =>
                            setState(() => _ignored.add(QuickAddPart.day)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  _ChoiceChip(
                    label: 'Bugün',
                    selected: _effectiveDay == 0,
                    onTap: () => setState(() {
                      _dayPinned = true;
                      _dayOffset = 0;
                    }),
                  ),
                  const SizedBox(width: Gap.sm),
                  _ChoiceChip(
                    label: 'Yarın',
                    selected: _effectiveDay == 1,
                    onTap: () => setState(() {
                      _dayPinned = true;
                      _dayOffset = 1;
                    }),
                  ),
                ],
              ),
              if (subjects.isNotEmpty) ...[
                const SizedBox(height: Gap.md),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: subjects.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      final colour = SubjectPalette.at(subject.colorIndex);
                      final selected = _effectiveSubjectId == subject.id;
                      return _ChoiceChip(
                        label: subject.name,
                        selected: selected,
                        colour: colour,
                        // İkinci dokunuş seçimi kaldırır: dersi yanlış seçen
                        // kullanıcının sayfayı kapatması gerekmesin.
                        onTap: () => setState(() {
                          _subjectPinned = true;
                          _subjectId = selected ? null : subject.id;
                        }),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: Gap.xl),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: const Text('Ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.colour,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final SubjectColor? colour;

  @override
  Widget build(BuildContext context) {
    final ink = colour?.ink ?? AppColors.selection;
    final wash = colour?.wash ?? AppColors.surfaceMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? wash : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(
            color: selected ? ink : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? ink : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

/// Çözümlemenin bulduğu tek bir yorum; dokununca o yorum kaldırılır.
///
/// Yanlış yorumu düzeltmek için metni silip yeniden yazmak gerekmesin diye
/// rozetin tamamı dokunma alanı, çarpı yalnızca işaret.
class _ParsedChip extends StatelessWidget {
  const _ParsedChip({required this.label, required this.onRemove, this.colour});

  final String label;
  final VoidCallback onRemove;
  final SubjectColor? colour;

  @override
  Widget build(BuildContext context) {
    final ink = colour?.ink ?? AppColors.textPrimary;
    return Semantics(
      button: true,
      label: '$label yorumunu kaldır',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
          decoration: BoxDecoration(
            color: colour?.wash ?? AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: Gap.xs),
              Icon(PhosphorIconsRegular.x, size: 12, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yorumlanan kelimeleri soluk çizen metin denetleyicisi: öğrenci hangi
/// kelimenin rozete dönüştüğünü, başlıkta neyin kaldığını yazarken görür.
class _QuickAddController extends TextEditingController {
  List<QuickAddSpan> spans = const [];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Klavye kelime birleştirirken (composing) altını çizdiği aralığı
    // bozmamak için Flutter'ın kendi çizimine bırakılıyor.
    final composing = withComposing && value.isComposingRangeValid;
    if (spans.isEmpty || composing) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final faded = style?.copyWith(color: AppColors.textTertiary);
    final children = <TextSpan>[];
    var cursor = 0;
    for (final span in spans) {
      if (span.end > text.length) break;
      if (span.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, span.start)));
      }
      children.add(
        TextSpan(text: text.substring(span.start, span.end), style: faded),
      );
      cursor = span.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }
}
