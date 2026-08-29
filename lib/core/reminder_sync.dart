import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import 'providers.dart';
/// Bekleyen tekrarları bildirimlerle eşleyen görünmez katman.
///
/// Ayrı bir bileşen olmasının sebebi: bildirim kurma işi hiçbir ekranın
/// sorumluluğu değil. Görev listesi ya da hatırlatma ayarı her değiştiğinde
/// burada tek noktadan yeniden kuruluyor; bir ekranın "bildirimi güncellemeyi
/// unutması" mümkün olmuyor.
class ReminderSync extends ConsumerWidget {
  const ReminderSync({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(reminderSettingsProvider).valueOrNull;
    final upcoming = ref.watch(upcomingReviewsProvider).valueOrNull;

    if (settings != null && upcoming != null) {
      _sync(ref, settings, upcoming);
    }

    return child;
  }

  void _sync(
    WidgetRef ref,
    ReminderSettings settings,
    List<TaskItem> upcoming,
  ) {
    final service = ref.read(notificationServiceProvider);
    if (!service.isReady) return;

    // Çizim sırasında eklenti çağrısı yapılmaz; kareyi bekletir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (settings.enabled) {
        service.syncReminders(upcoming, hour: settings.hour);
      } else {
        service.cancelAll();
      }
    });
  }
}
