import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../data/db/database.dart';
/// Hatırlatma ayarları: açık mı, saat kaçta.
class ReminderSheet extends ConsumerWidget {
  const ReminderSheet({super.key});

  /// Seçilebilir saatler. Serbest saat seçici yerine kısa bir liste: akşam
  /// etüdü dışında bir saat isteyen kullanıcı azınlıkta ve seçici bir ekran
  /// daha açmaya değmiyor.
  static const _hours = [8, 12, 17, 19, 21];

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => const ReminderSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(reminderSettingsProvider).valueOrNull ??
        ReminderSettings.initial;
    final db = ref.read(databaseProvider);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tekrar hatırlatmaları', style: text.titleMedium),
                      const SizedBox(height: Gap.xs),
                      Text(
                        'Tekrar günü geldiğinde bildirim gönderelim.',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.enabled,
                  activeThumbColor: AppColors.surface,
                  activeTrackColor: AppColors.selection,
                  onChanged: (value) async {
                    // Açarken izin gerekebilir; kapatırken sormaya gerek yok.
                    var granted = true;
                    if (value) {
                      granted = await ref
                          .read(notificationServiceProvider)
                          .requestPermission();
                    }
                    await db.saveReminderSettings(
                      settings.copyWith(asked: true, enabled: value && granted),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: Gap.xxl),
            Text('Saat', style: text.titleMedium),
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hour in _hours)
                  GestureDetector(
                    onTap: () =>
                        db.saveReminderSettings(settings.copyWith(hour: hour)),
                    child: AnimatedContainer(
                      duration: Motion.quick,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: settings.hour == hour
                            ? AppColors.selection : AppColors.surface,
                        borderRadius: BorderRadius.circular(Radii.full),
                        border: Border.all(
                          color: settings.hour == hour
                              ? AppColors.selection : AppColors.border,
                          width: settings.hour == hour ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        NotificationService.formatHour(hour),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: settings.hour == hour
                              ? AppColors.onSelection : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (settings.asked && !settings.enabled) ...[
              const SizedBox(height: Gap.xl),
              Text(
                'Bildirim izni kapalı görünüyor. Açmak için telefonun '
                'Ayarlar > Bildirimler bölümünden Ritim\'e izin vermen gerek.',
                style: text.bodySmall?.copyWith(height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
