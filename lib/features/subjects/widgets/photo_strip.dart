import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../data/db/database.dart';
import 'photo_actions.dart';
/// Konunun fotoğrafları: yatay bir şerit ve sonunda ekleme karesi.
///
/// Izgara değil şerit: fotoğraflar ekranın konusu değil, notun eki. Izgara
/// dört fotoğrafta ekranın yarısını kaplıyor ve çalışma geçmişini aşağı
/// itiyordu.
class PhotoStrip extends ConsumerWidget {
  const PhotoStrip({required this.topicId, super.key});

  static const _size = 84.0;

  final int topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photosProvider(topicId)).valueOrNull ?? const [];

    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.md),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return _AddTile(
              onTap: () => PhotoActions.add(context, ref, topicId),
            );
          }
          return _PhotoTile(photo: photos[index]);
        },
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: PhotoStrip._size,
        height: PhotoStrip._size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          PhosphorIconsRegular.plus,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.photo});

  final TopicPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<File>(
      future: ref.read(photoStoreProvider).fileFor(photo.relativePath),
      builder: (context, snapshot) {
        final file = snapshot.data;

        return GestureDetector(
          onTap: file == null ? null : () => _openFull(context, file),
          onLongPress: () => _confirmDelete(context, ref),
          child: Container(
            width: PhotoStrip._size,
            height: PhotoStrip._size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: file != null && file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                // Dosya kaybolmuşsa (yedekten dönüş, elle silme) satır duruyor
                // ama görsel yok; kırık bir kutu yerine açık bir işaret.
                : const Icon(
                    PhosphorIconsRegular.imageBroken,
                    color: AppColors.textTertiary,
                  ),
          ),
        );
      },
    );
  }

  void _openFull(BuildContext context, File file) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            // Kitap sayfası fotoğrafı okunabilsin diye yakınlaştırma şart.
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final onay = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        title: const Text('Fotoğraf silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.overdue,
              minimumSize: const Size(100, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay != true) return;

    // Önce satır, sonra dosya: ters sırada, dosya silinip satır kalırsa
    // kullanıcı kırık bir kutu görüyor.
    final path = await ref.read(databaseProvider).removePhoto(photo.id);
    if (path != null) await ref.read(photoStoreProvider).delete(path);
  }
}
