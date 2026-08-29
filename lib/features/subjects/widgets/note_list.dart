import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/db/database.dart';

/// Bir konunun notları.
///
/// Tek metin alanı değil liste: haftalarca aynı konuya çalışan öğrenci farklı
/// zamanlarda farklı şeyler fark ediyor ve bunlar ayrı ayrı silinebilmeli,
/// tarihleriyle görünebilmeli. Tek alan hepsini tek yığına yazmaya zorluyordu.
class NoteList extends ConsumerWidget {
  const NoteList({required this.topicId, super.key});

  final int topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(topicNotesProvider(topicId)).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notes.isEmpty)
          Text(
            'Henüz not yok. Konuyu çalışırken aklında kalanı yaz; tekrar günü '
            'karşına çıkacak.',
            style: text.bodySmall,
          )
        else
          for (final note in notes) ...[
            _NoteCard(note: note),
            const SizedBox(height: Gap.sm),
          ],
        const SizedBox(height: Gap.sm),
        _AddNoteButton(topicId: topicId),
      ],
    );
  }
}

class _AddNoteButton extends ConsumerWidget {
  const _AddNoteButton({required this.topicId});

  final int topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.border),
        foregroundColor: AppColors.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      icon: const Icon(PhosphorIconsRegular.plus, size: IconSize.sm),
      label: const Text('Not ekle'),
      onPressed: () async {
        final body = await NoteEditorSheet.show(context);
        if (body == null) return;
        await ref.read(databaseProvider).addTopicNote(topicId, body);
      },
    );
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note});

  final TopicNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      onTap: () async {
        final body = await NoteEditorSheet.show(context, existing: note.body);
        if (body == null) return;
        // Boşaltılan not siliniyor; boş bir kart listede yer kaplamamalı.
        await ref.read(databaseProvider).updateTopicNote(note.id, body);
      },
      onLongPress: () => ref.read(databaseProvider).deleteTopicNote(note.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.body, style: text.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: Gap.sm),
          Text(
            DateFormat('d MMMM', 'tr_TR').format(note.createdAt),
            style: text.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Not yazma sayfası.
///
/// Kaydetme ayrı bir karar değil: "Kaydet" düğmesi sayfayı kapatıyor ve yazdığı
/// metni döndürüyor. Vazgeçen kullanıcı sayfayı kapatıyor ve hiçbir şey
/// yazılmıyor — iki yol da açık ve ikisi de tek dokunuş.
class NoteEditorSheet extends StatefulWidget {
  const NoteEditorSheet({this.existing, super.key});

  final String? existing;

  static Future<String?> show(BuildContext context, {String? existing}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => NoteEditorSheet(existing: existing),
    );
  }

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.existing ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final isNew = widget.existing == null;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                ),
              ),
              const SizedBox(height: Gap.xl),
              Text(
                isNew ? 'Yeni not' : 'Notu düzenle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Gap.md),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Neyi karıştırıyorsun, neyi unutuyorsun?',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: Gap.xl),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_controller.text),
                child: Text(isNew ? 'Kaydet' : 'Güncelle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
