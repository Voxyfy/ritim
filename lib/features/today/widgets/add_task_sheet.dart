import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_extensions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../data/db/database.dart';
/// Görev ekleme sayfası.
///
/// Tek zorunlu alan başlık. Ders ve gün seçimi tek dokunuşluk rozetler:
/// hızlı bir not almak için form doldurma hissi vermemesi gerekiyor.
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
  final _controller = TextEditingController();
  final _focus = FocusNode();
  int? _subjectId;
  int _dayOffset = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Klavye sayfayla birlikte gelsin; ekstra bir dokunuş daha istemiyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _saving) return;

    setState(() => _saving = true);

    // Ders seçildiyse görev, o dersin ilk konusuna bağlanır. Konu seçimi 4.
    // günde geleceği için şimdilik ders rozeti listede rengi taşımaya yarıyor.
    int? topicId;
    if (_subjectId != null) {
      final topics = await ref.read(databaseProvider).watchTopics(_subjectId!).first;
      topicId = topics.isNotEmpty ? topics.first.id : null;
    }

    await ref.read(databaseProvider).addTask(
          title: title,
          dueOn: today().addDays(_dayOffset),
          topicId: topicId,
        );

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const <Subject>[];
    final insets = MediaQuery.viewInsetsOf(context).bottom;

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
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  _ChoiceChip(
                    label: 'Bugün',
                    selected: _dayOffset == 0,
                    onTap: () => setState(() => _dayOffset = 0),
                  ),
                  const SizedBox(width: Gap.sm),
                  _ChoiceChip(
                    label: 'Yarın',
                    selected: _dayOffset == 1,
                    onTap: () => setState(() => _dayOffset = 1),
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
                      final selected = _subjectId == subject.id;
                      return _ChoiceChip(
                        label: subject.name,
                        selected: selected,
                        colour: colour,
                        // İkinci dokunuş seçimi kaldırır: dersi yanlış seçen
                        // kullanıcının sayfayı kapatması gerekmesin.
                        onTap: () => setState(
                          () => _subjectId = selected ? null : subject.id,
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: Gap.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
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
    final ink = colour?.ink ?? AppColors.accent;
    final wash = colour?.wash ?? AppColors.accentSoft;

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
