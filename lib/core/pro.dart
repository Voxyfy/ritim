import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'providers.dart';

/// Ücretsiz kullanım süresi.
const trialDays = 7;

/// RevenueCat'te Pro erişimini veren yetkinin kimliği.
const proEntitlement = 'pro';

/// RevenueCat'in iOS genel SDK anahtarı; derlemede `--dart-define` ile gelir.
///
/// Genel anahtar gizli değil ama depoda durmuyor: uygulama açık kaynak ve
/// depoyu derleyen herkes bizim projemize satın alma yazmamalı.
const _revenueCatKey = String.fromEnvironment('RC_IOS_KEY');

/// Denemenin kaç günü kaldı? Sıfır ya da altı "bitti" demek.
///
/// Gün sayımı takvim gününe göre: deneme pazartesi 23.59'da başladıysa
/// salı ikinci gün sayılıyor. Saat bazlı sayım öğrenciye "7 gün" dediğimiz
/// süreyi gece yarısında bir gün eksik gösteriyordu.
int trialDaysLeft(DateTime start, DateTime now) {
  final startDay = DateTime(start.year, start.month, start.day);
  final today = DateTime(now.year, now.month, now.day);
  return trialDays - today.difference(startDay).inDays;
}

/// Kullanıcının erişim durumu.
class Access {
  const Access({required this.pro, required this.daysLeft});

  /// Derlemede RevenueCat anahtarı yoksa (testler, depodan kendi derleyen
  /// geliştirici) satın alma yapılamaz; uygulama kilitlenmez.
  static const unlocked = Access(pro: true, daysLeft: trialDays);

  final bool pro;
  final int daysLeft;

  bool get inTrial => !pro && daysLeft > 0;

  /// Deneme bitti ve abonelik yok: uygulama satın alma ekranına kilitlenir.
  bool get locked => !pro && daysLeft <= 0;
}

/// RevenueCat ile konuşan tek yer.
class ProService {
  bool get enabled => _revenueCatKey.isNotEmpty;

  Future<void> configure() async {
    if (!enabled) return;
    await Purchases.configure(PurchasesConfiguration(_revenueCatKey));
  }

  /// Pro durumu; satın alma, geri yükleme ve yenilemede güncellenir.
  Stream<bool> watchPro() async* {
    if (!enabled) {
      yield true;
      return;
    }
    bool active(CustomerInfo info) =>
        info.entitlements.active.containsKey(proEntitlement);

    // Ağ yoksa RevenueCat önbelleğe aldığı son durumu döndürüyor; hiç
    // önbellek yoksa hata fırlatıyor. Çevrimdışı öncelikli bir uygulamada
    // bu yüzden kilitlemiyoruz: denemesi bitmiş ama ağı olmayan kullanıcı
    // abone olabilir, emin olmadan kapıyı kapatmak ondan çalmak olur.
    try {
      yield active(await Purchases.getCustomerInfo());
    } on PlatformException {
      yield true;
    }

    final controller = StreamController<bool>();
    void listener(CustomerInfo info) => controller.add(active(info));
    Purchases.addCustomerInfoUpdateListener(listener);
    try {
      yield* controller.stream;
    } finally {
      Purchases.removeCustomerInfoUpdateListener(listener);
      await controller.close();
    }
  }

  Future<List<Package>> packages() async {
    final offerings = await Purchases.getOfferings();
    return offerings.current?.availablePackages ?? const [];
  }

  /// Satın alır; kullanıcı vazgeçtiyse `false` döner, diğer hatalar fırlar.
  Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo.entitlements.active
          .containsKey(proEntitlement);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> restore() async {
    final info = await Purchases.restorePurchases();
    return info.entitlements.active.containsKey(proEntitlement);
  }
}

final proServiceProvider = Provider<ProService>((ref) => ProService());

final _proProvider = StreamProvider<bool>(
  (ref) => ref.watch(proServiceProvider).watchPro(),
);

final _trialStartProvider = FutureProvider<DateTime>(
  (ref) => ref.watch(databaseProvider).ensureTrialStart(),
);

/// Erişim durumu. Yüklenirken `null`: yönlendirici o arada kilitlemez.
final accessProvider = Provider<Access?>((ref) {
  if (!ref.watch(proServiceProvider).enabled) return Access.unlocked;
  final pro = ref.watch(_proProvider).valueOrNull;
  final start = ref.watch(_trialStartProvider).valueOrNull;
  if (pro == null || start == null) return null;
  // Gün değişince kalan gün de değişmeli.
  final now = ref.watch(currentDayProvider);
  return Access(pro: pro, daysLeft: trialDaysLeft(start, now));
});
