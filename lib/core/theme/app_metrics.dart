import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Boşluk ölçeği — 4 piksellik ızgara.
///
/// Her ekranın kendi payını uydurması, aynı işi yapan iki kartın farklı
/// hizalanmasına yol açıyordu. Ara değer yok: bir boşluk buradaki adımlardan
/// biri olmak zorunda.
abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const section = 32.0;
  static const block = 40.0;

  /// Sayfanın sol/sağ kenar payı. Ekranlar arası hizanın tek kaynağı.
  static const page = 20.0;

  /// Kart içi pay. Tek değer: iki kartın metin başlangıcı aynı düşey çizgiye
  /// oturmalı, aksi hâlde liste tarak gibi okunuyor.
  static const card = 16.0;

  /// Yüzen sekme çubuğunun üstünde bırakılan pay.
  static const floatingClearance = 116.0;

  /// Kaydırılabilir listelerin alt boşluğu.
  ///
  /// Çubuk payı + yüzen düğmenin yüksekliği + nefes payı.
  ///
  /// **Sekme kabuğunun içindeki her kaydırılabilir liste bunu kullanmalı.**
  /// Kendi payını yazan iki ekran, son satırı yüzen çubuğun altında bıraktı ve
  /// kullanıcı oraya hiç ulaşamadı. Metin alanı içeren listelerde ayrıca
  /// `MediaQuery.viewInsetsOf(context).bottom` eklenir; aksi hâlde klavye
  /// açıkken son alan erişilemez kalıyor.
  static const listBottom = floatingClearance + 56 + xxl;
}

/// Köşe yarıçapı. Üç değer ve bir tam yuvarlak; fazlası tutarsızlık.
///
/// 1.1 ile hepsi büyüdü. Önceki değerler (12/18/28) kartları "kutu" gibi
/// gösteriyordu; geniş yarıçap ve kenarsız yüzey, kartın zeminden renk
/// farkıyla ayrılmasını sağlıyor ve sayfa tek parça bir yüzey gibi okunuyor.
abstract final class Radii {
  /// Veri çubukları gibi ince yüzeyler.
  static const xs = 4.0;

  /// Rozet, gün seçici, küçük yüzeyler.
  static const sm = 14.0;

  /// Kart, düğme, giriş alanı.
  static const md = 24.0;

  /// Büyük kartlar (takvim, ders kartı) ve alttan açılan sayfalar.
  static const lg = 32.0;

  static const full = 999.0;
}

/// Hareket. Üç süre ve tek eğri.
///
/// On farklı süre ve dört eğri vardı; aynı anda görünen iki animasyon farklı
/// hızlarda bittiği için arayüz dalgalanıyordu. Tek eğri, tek his.
abstract final class Motion {
  /// Dokunma geri bildirimi: onay kutusu, rozet seçimi.
  static const quick = Duration(milliseconds: 120);

  /// Durum değişimi: açılıp kapanan bölüm, renk geçişi.
  static const base = Duration(milliseconds: 200);

  /// Veri hareketi: ilerleme çubukları, grafik büyümesi.
  static const slow = Duration(milliseconds: 320);

  /// Açılış sıralaması; yalnızca marka işareti kullanıyor.
  static const entrance = Duration(milliseconds: 720);

  static const curve = Curves.easeOutCubic;
}

/// İkon boyutları ve ağırlık kuralı.
///
/// Uygulama tek ikon ağırlığı kullanır: [PhosphorIconsRegular]. Dolu biçim
/// yalnızca **seçili ya da tamamlanmış** bir durumu göstermek için var; kalın
/// biçim hiç kullanılmıyor. Üç ağırlığın karışması, aynı ekrandaki ikonları
/// farklı ailelerden gelmiş gibi gösteriyordu.
abstract final class IconSize {
  /// Rozet içi, satır içi işaretler.
  static const sm = 16.0;

  /// Varsayılan: düğmeler, liste satırları, sekmeler.
  static const md = 20.0;

  /// Vurgulu eylemler.
  static const lg = 24.0;

  /// Boş durum ve hata ekranları.
  static const xl = 40.0;
}
