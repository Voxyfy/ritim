import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/db/database.dart';
/// Tekrar hatırlatmalarını kuran servis.
///
/// Servis, [initialize] çağrılmadan tamamen sessizdir. Sebebi test ortamı:
/// eklenti kanalı olmayan bir ortamda her çağrı `MissingPluginException`
/// fırlatırdı ve widget testleri uygulamayı kuramazdı. Yalnızca `main()`
/// tarafından uyandırılıyor.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// iOS'ta aynı anda bekleyebilecek bildirim sayısı 64 ile sınırlı ve bu
  /// sınır uygulama geneli. Yakın tarihli tekrarlar yeterli; gerisi zaten
  /// kullanıcı uygulamayı açtıkça yeniden planlanıyor.
  static const maxScheduled = 24;

  static const _channelId = 'ritim_tekrar';
  static const _channelName = 'Tekrar hatırlatmaları';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  bool get isReady => _ready;

  /// Eklentiyi ve saat dilimi verisini hazırlar. Başarısız olursa servis
  /// sessiz kalmaya devam eder; bildirim yokluğu uygulamayı çalışmaz hâle
  /// getirmemeli.
  Future<void> initialize() async {
    try {
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));

      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            // İzin, kurulum biter bitmez değil, ilk tekrar planlandığında
            // isteniyor: kullanıcı neye izin verdiğini bilsin.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (error, stack) {
      debugPrint('Bildirim servisi başlatılamadı: $error\n$stack');
      _ready = false;
    }
  }

  /// Kullanıcıdan bildirim izni ister; izin verildiyse `true` döner.
  Future<bool> requestPermission() async {
    if (!_ready) return false;

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Bekleyen tüm hatırlatmaları verilen görevlere göre yeniden kurar.
  ///
  /// Fark hesaplamak yerine hepsini silip yeniden kuruyoruz: yirmi bildirimlik
  /// bir liste için karşılaştırma mantığı yazmak, kazandırdığından fazla hata
  /// yüzeyi açardı.
  Future<void> syncReminders(List<TaskItem> upcoming, {required int hour}) async {
    if (!_ready) return;

    try {
      await _plugin.cancelAll();

      final now = tz.TZDateTime.now(tz.local);
      final scheduled = upcoming.where((item) => !item.task.done).take(maxScheduled);

      for (final item in scheduled) {
        final due = item.task.dueOn;
        final when = tz.TZDateTime(tz.local, due.year, due.month, due.day, hour);
        // Saati geçmiş bir gün için bildirim kurulamaz; o görev zaten
        // uygulamanın listesinde görünüyor.
        if (!when.isAfter(now)) continue;

        await _plugin.zonedSchedule(
          id: item.task.id,
          scheduledDate: when,
          title: 'Tekrar zamanı',
          body: item.topic == null
              ? item.task.title
              : '${item.topic!.name} · bugün tekrar edilecek',
          notificationDetails: const NotificationDetails(
            iOS: DarwinNotificationDetails(),
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.defaultImportance,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (error) {
      debugPrint('Hatırlatmalar kurulamadı: $error');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Hatırlatmalar silinemedi: $error');
    }
  }

  /// "19:00" gibi bir saat metni.
  static String formatHour(int hour) =>
      DateFormat('HH:mm').format(DateTime(2000, 1, 1, hour));
}
