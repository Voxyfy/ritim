import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_metrics.dart';
/// Konuya fotoğraf ekleme akışı.
///
/// Hem konu ekranından hem görev sayfasından çağrılıyor: fotoğraf her zaman
/// **konuya** kaydediliyor. Göreve iliştirilen bir görsel iş tamamlanınca
/// kaybolurdu; konuya iliştirilen tekrar günü geri geliyor.
abstract final class PhotoActions {
  /// Kaynak seçtirir, fotoğrafı alır ve konuya bağlar.
  ///
  /// İzin reddedilirse sessizce başarısız olmuyor: kullanıcıya ne olduğunu ve
  /// nereden açacağını söylüyoruz. İzin isteğini işletim sistemi yapıyor,
  /// ama reddedildiğinde kullanıcıyı çıkmazda bırakmak bize kalıyor.
  static Future<void> add(
    BuildContext context,
    WidgetRef ref,
    int topicId,
  ) async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.sm),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.camera),
              title: const Text('Fotoğraf çek'),
              subtitle: const Text('Kitaptan bir sayfa, çözdüğün bir soru'),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.images),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
    if (fromCamera == null || !context.mounted) return;

    try {
      final path =
          await ref.read(photoStoreProvider).pick(fromCamera: fromCamera);
      if (path == null) return;
      await ref.read(databaseProvider).addPhoto(
            topicId: topicId,
            relativePath: path,
          );
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      // image_picker izin reddini kod olarak bildiriyor; mesajı ayırt edip
      // kullanıcıya doğru yolu göstermek için kodlara bakıyoruz.
      final izinSorunu = error.code == 'camera_access_denied' ||
          error.code == 'photo_access_denied';
      _showError(
        context,
        izinSorunu
            ? (fromCamera
                ? 'Kamera izni kapalı. Telefonun Ayarlar > Ritim bölümünden '
                    'kameraya izin verebilirsin.'
                : 'Fotoğraf izni kapalı. Telefonun Ayarlar > Ritim bölümünden '
                    'fotoğraflara izin verebilirsin.')
            : 'Fotoğraf eklenemedi.',
      );
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }
}
