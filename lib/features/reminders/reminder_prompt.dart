import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../data/db/database.dart';
/// Bildirim iznini istemeden önce gösterilen açıklama.
///
/// Sistem uyarısı doğrudan gösterilmiyor: iOS'ta bu uyarı ömürde bir kez
/// çıkıyor ve "neden?" sorusunun cevabını bilmeden reddeden kullanıcı bir daha
/// geri dönemiyor. Önce ne için istendiğini anlatıyoruz; "şimdi değil" diyen
/// kullanıcıya sistem uyarısı hiç gösterilmiyor, yani izin hakkı yanmıyor.
abstract final class ReminderPrompt {
  /// İlk tekrar planlandığında bir kez çağrılır; daha önce sorulduysa hiçbir
  /// şey yapmaz.
  static Future<void> askIfNeeded(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final current = ref.read(reminderSettingsProvider).valueOrNull ??
        ReminderSettings.initial;
    if (current.asked) return;

    final wants = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => const _ReminderDialog(),
    );

    // Sistem uyarısı yalnızca kullanıcı burada "evet" dediyse gösterilir.
    final granted = wants == true &&
        await ref.read(notificationServiceProvider).requestPermission();

    await db.saveReminderSettings(
      current.copyWith(asked: true, enabled: granted),
    );
  }
}

class _ReminderDialog extends StatelessWidget {
  const _ReminderDialog();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      title: Row(
        children: [
          const Icon(PhosphorIconsFill.bell, color: AppColors.selection, size: 22),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text('Tekrar günü haber verelim mi?', style: text.titleMedium),
          ),
        ],
      ),
      content: Text(
        'Çalıştığın konu 1, 3, 7 ve 21 gün sonra tekrara düşer. '
        'O gün akşam sana kısa bir hatırlatma göndeririz. '
        'İstemezsen sonradan da açabilirsin.',
        style: text.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Şimdi değil',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Hatırlat'),
        ),
      ],
    );
  }
}
