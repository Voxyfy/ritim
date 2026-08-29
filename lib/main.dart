import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/notifications.dart';
import 'core/providers.dart';
import 'core/reminder_sync.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
/// Uygulamanın tek yerel ayarı. Ritim yalnızca Türkçe; dil seçimi yok, çünkü
/// hedef kitle Türkiye'de sınava hazırlanan öğrenciler.
const appLocale = Locale('tr', 'TR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tarih adları (ay, gün) bu veri yüklenmeden biçimlendirilemez; ilk kare
  // çizilmeden önce hazır olmalı, yoksa Bugün ekranı başlıksız açılır.
  Intl.defaultLocale = appLocale.toString();
  await initializeDateFormatting(appLocale.toString());

  // Servis burada uyandırılıyor; testler main()'i çağırmadığı için orada
  // sessiz kalıyor ve eklenti kanalı olmayan ortamda hata üretmiyor.
  final notifications = NotificationService();
  await notifications.initialize();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const RitimApp(),
    ),
  );
}

class RitimApp extends ConsumerStatefulWidget {
  const RitimApp({super.key});

  @override
  ConsumerState<RitimApp> createState() => _RitimAppState();
}

class _RitimAppState extends ConsumerState<RitimApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Telefon arka plandayken zamanlayıcılar askıya alınabiliyor; gece yarısı
    // zamanlayıcısı hiç tetiklenmeden sabah olabiliyor. Uygulama öne
    // geldiğinde günü bir kez daha kontrol ediyoruz.
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          ref.read(currentDayProvider.notifier).refreshIfDayChanged(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ritim',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: appLocale,
      supportedLocales: const [appLocale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => ReminderSync(child: child ?? const SizedBox()),
    );
  }
}
