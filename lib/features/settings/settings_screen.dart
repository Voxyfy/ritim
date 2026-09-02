import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/notifications.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../data/db/database.dart';
import '../reminders/reminder_sheet.dart';

/// Ayarlar.
///
/// Hatırlatmalar daha önce Dersler başlığındaki zil ikonunun arkasında
/// saklıydı; sıfırlama ise hiç yoktu. İkisi de burada, tek bir yerde.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.watch(reminderSettingsProvider).valueOrNull ??
        ReminderSettings.initial;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.page,
          Gap.xl,
          Gap.page,
          Gap.listBottom,
        ),
        children: [
          Text('Ayarlar', style: text.headlineMedium),
          const SizedBox(height: Gap.xxl),
          _SectionTitle('Hatırlatma'),
          AppCard(
            padding: EdgeInsets.zero,
            child: _Row(
              icon: PhosphorIconsRegular.bell,
              title: 'Tekrar hatırlatmaları',
              subtitle: reminder.enabled
                  ? 'Açık · her gün ${NotificationService.formatHour(reminder.hour)}'
                  : 'Kapalı',
              onTap: () => ReminderSheet.show(context),
            ),
          ),
          const SizedBox(height: Gap.section),

          _SectionTitle('Sıfırlama'),
          Text(
            'Hangisinin neyi sildiğini altında yazıyor. Silinen veri geri '
            'gelmiyor.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Gap.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Row(
                  icon: PhosphorIconsRegular.arrowCounterClockwise,
                  title: 'Konu ilerlemesini sıfırla',
                  subtitle: 'Tüm konular "başlanmadı" olur. Notlar, '
                      'fotoğraflar ve çalışma geçmişi kalır.',
                  onTap: () => _confirm(
                    context,
                    title: 'Konu ilerlemesi sıfırlansın mı?',
                    body: 'Bütün konular "başlanmadı" durumuna döner. '
                        'Notların, fotoğrafların ve çalışma kayıtların '
                        'olduğu gibi kalır.',
                    action: 'Sıfırla',
                    onConfirm: () =>
                        ref.read(databaseProvider).resetTopicProgress(),
                    done: 'Konu ilerlemesi sıfırlandı.',
                  ),
                ),
                const Divider(height: 1, color: AppColors.hairline),
                _Row(
                  icon: PhosphorIconsRegular.clockCounterClockwise,
                  title: 'Çalışma geçmişini sil',
                  subtitle: 'Çalışma kayıtları, görevler ve bekleyen '
                      'tekrarlar silinir. Dersler, konular ve notlar kalır.',
                  onTap: () => _confirm(
                    context,
                    title: 'Çalışma geçmişi silinsin mi?',
                    body: 'Bütün çalışma kayıtların, görevlerin ve bekleyen '
                        'tekrarların silinir. Derslerin, konuların, notların '
                        've fotoğrafların kalır.',
                    action: 'Sil',
                    destructive: true,
                    onConfirm: () =>
                        ref.read(databaseProvider).resetStudyHistory(),
                    done: 'Çalışma geçmişi silindi.',
                  ),
                ),
                const Divider(height: 1, color: AppColors.hairline),
                _Row(
                  icon: PhosphorIconsRegular.trash,
                  title: 'Her şeyi sil ve baştan başla',
                  subtitle: 'Dersler, konular, notlar, fotoğraflar — hepsi '
                      'gider. Uygulama ilk açılış hâline döner.',
                  colour: AppColors.overdue,
                  onTap: () => _confirm(
                    context,
                    title: 'Her şey silinsin mi?',
                    body: 'Derslerin, konuların, notların, fotoğrafların ve '
                        'bütün geçmişin silinir. Uygulama ilk açılış hâline '
                        'döner. Bu işlem geri alınamaz.',
                    action: 'Her şeyi sil',
                    destructive: true,
                    onConfirm: () async {
                      final paths =
                          await ref.read(databaseProvider).clearAll();
                      await ref.read(photoStoreProvider).deleteAll(paths);
                      // Yönlendirici kurulum bayrağını izliyor; bayrak
                      // silinince karşılama ekranına kendiliğinden dönüyoruz.
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// Yıkıcı işlemler için onay.
  ///
  /// Ne silineceği hem satırda hem onay kutusunda yazıyor: kullanıcı
  /// "sıfırla" derken neyi kaybettiğini bilmeli, sonradan öğrenmemeli.
  static Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    required Future<void> Function() onConfirm,
    String? done,
    bool destructive = false,
  }) async {
    final onay = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text(title),
        content: Text(body),
        actionsPadding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
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
              backgroundColor:
                  destructive ? AppColors.overdue : AppColors.accent,
              minimumSize: const Size(120, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (onay != true) return;

    await onConfirm();
    if (done != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done)));
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md, left: Gap.xs),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.colour = AppColors.textPrimary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colour == AppColors.overdue
                    ? AppColors.overdueSoft
                    : AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Center(
                  child: Icon(icon, size: IconSize.md, color: colour),
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colour,
                    ),
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
