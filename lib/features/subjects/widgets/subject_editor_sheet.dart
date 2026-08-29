import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../data/db/database.dart';
/// Ders ekleme ve düzenleme sayfası.
///
/// Şablon kullanmayan ("Kendin kur") öğrenci için bu ekran zorunlu: onsuz
/// uygulama çıkmaz sokak. Şablon kullanan için de gerekli, çünkü şablon
/// müfredat değil başlangıç noktası.
class SubjectEditorSheet extends ConsumerStatefulWidget {
  const SubjectEditorSheet({this.existing, super.key});

  /// Düzenlenen ders; yeni ders eklenirken `null`.
  final Subject? existing;

  static Future<bool?> show(BuildContext context, {Subject? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => SubjectEditorSheet(existing: existing),
    );
  }

  @override
  ConsumerState<SubjectEditorSheet> createState() => _SubjectEditorSheetState();
}

class _SubjectEditorSheetState extends ConsumerState<SubjectEditorSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  final _focus = FocusNode();
  late int _colorIndex = widget.existing?.colorIndex ?? 0;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    if (_isNew) {
      await db.addSubject(name: name, colorIndex: _colorIndex);
    } else {
      await db.updateSubject(
        widget.existing!.id,
        name: name,
        colorIndex: _colorIndex,
      );
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        child: Padding(
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
              Text(_isNew ? 'Yeni ders' : 'Dersi düzenle', style: text.titleMedium),
              const SizedBox(height: Gap.md),
              TextField(
                controller: _name,
                focusNode: _focus,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  hintText: 'Ders adı',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: Gap.lg),
              Text('Renk', style: text.bodySmall),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < SubjectPalette.colors.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: AnimatedContainer(
                        duration: Motion.quick,
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: SubjectPalette.at(i).ink,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorIndex == i
                                ? AppColors.textPrimary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Gap.xxl),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_isNew ? 'Dersi ekle' : 'Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
