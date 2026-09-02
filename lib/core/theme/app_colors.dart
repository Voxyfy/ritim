import 'package:flutter/material.dart';

/// Ritim'in renk token'ları.
///
/// Açık tema öncelikli ve sıcak: kâğıt hissi veren fildişi bir zemin, üzerinde
/// yüzen beyaz kartlar — referans aldığımız uygulamaların (Todoist, Things)
/// yaptığı gibi. Önce soğuk gri bir #FFFFFF sayfa denendi ve klinik duruyordu;
/// öğrenci buna akşam dokuzda bakıyor ve ödev yazılımı hissini kıran şey bu
/// sıcaklık.
///
/// Karanlık tema aynı token adlarını yeniden kullanacak; bu dosya ile
/// [AppTheme] dışında hiçbir yer renk sabiti bilmemeli.
abstract final class AppColors {
  /// Sayfa zemini. Sıcak fildişi, asla saf beyaz değil — kartların üzerinden
  /// kalkacağı bir zemine ihtiyacı var.
  static const background = Color(0xFFFAF6EF);

  /// Kartlar, sayfalar, liste kapsayıcıları.
  static const surface = Color(0xFFFFFFFF);

  /// Bir yüzeyin basılı/seçili hâli ve gruplanmış liste ayraçlarının dolgusu.
  static const surfaceMuted = Color(0xFFF2EDE4);
  static const border = Color(0xFFE8E1D6);

  /// Birincil vurgu: kiremit. **Yalnızca birincil eylem**: yüzen düğme ve
  /// "Plan kur". 1.1'de ilerleme, rozet ve takvim yoğunluğundan çekildi;
  /// bir ekranda tek yerde görünür.
  ///
  /// Önce mor denendi (Todoist'in kırmızısını ödünç almamak için) ama fildişi
  /// zeminde soğuk duruyordu, sayfanın geri kalanıyla aynı dili konuşmuyordu.
  /// Kiremit zeminle aynı sıcak aileden geliyor; kırmızı kadar bağırmıyor ama
  /// hem beyaz kartta hem fildişi zeminde okunuyor.
  static const accent = Color(0xFFC9512B);
  static const onAccent = Color(0xFFFFFFFF);

  /// Seçili rozetler ve vurgu zeminleri için soluk kiremit.
  static const accentSoft = Color(0xFFF9E9E1);

  /// Yalnızca **tamamlandı** işareti için: onay daireleri ve konu durum
  /// noktası.
  ///
  /// Renklerin işi bölüşüldü. Sıcak siyah ([selection]) ilerlemeyi ve seçimi
  /// anlatır (halkalar, çubuklar, takvim); kiremit yalnızca eylem; yeşil
  /// yalnızca "bu bitti" der. Önce
  /// ikisi karışıktı: ders halkası kiremit, aynı veriyi gösteren yığılmış
  /// çubuk yeşildi ve aynı şeyin iki rengi vardı.
  ///
  /// Yüksek doygunluktaki yeşil fildişi üzerinde metin olarak okunmaz; sadece
  /// dolgu rengidir — asla yazı, asla ikon.
  static const progress = Color(0xFF7CB518);
  static const progressTrack = Color(0xFFECE6DA);

  /// Sıcak, siyaha yakın ton. Sıcak zeminde saf siyah baskı hatası gibi
  /// duruyor.
  static const textPrimary = Color(0xFF1F1D1A);
  static const textSecondary = Color(0xFF6E6A63);
  static const textTertiary = Color(0xFFA09B92);

  /// Geciken iş.
  ///
  /// Vurgu kiremide dönünce eski mercan onunla karışır hâle geldi; ahududuya
  /// çekildi. Hâlâ alarm kırmızısı değil — uygulama dürter, azarlamaz — ama
  /// hem kiremitten hem ders paletinin mercanından net ayrılıyor.
  static const overdue = Color(0xFFC2185B);
  static const overdueSoft = Color(0xFFFCE4EC);

  /// İnce ayraç çizgisi: yalnızca bir kartın **içindeki** satırları ayırır.
  ///
  /// Kartların kendisi artık kenar çizgisi taşımıyor. 1.0'da bir piksellik
  /// çizgiyle ayrılıyorlardı; 1.1'de kart zeminden yalnızca renk farkıyla
  /// (beyaz ya da ders tonu) kalkıyor. Çizgi, geniş yarıçaplı yüzeylerde
  /// köşede kırılıyor ve arayüzü "çerçeveli" gösteriyordu. Gölge de yalnızca
  /// **gerçekten yüzen** şeylerde (sekme çubuğu, yüzen düğme, alttan açılan
  /// sayfa): "bu katman üstte".
  static const hairline = Color(0xFFEAE3D8);

  /// Seçili / gezinme rengi: sıcak siyah.
  ///
  /// Sekme çubuğunda seçili daire, hap seçicide seçili parça, takvimde bugün.
  /// Önce bunlar da kiremitti ve vurgu rengi her ekranda üç dört yerde
  /// görünüyordu; "bir ekranda tek yerde" kuralı fiilen bozuktu. Koyu seçim,
  /// kiremidi yalnızca **eylem ve ilerlemeye** bırakıyor.
  static const selection = textPrimary;
  static const onSelection = Color(0xFFFFFFFF);

  /// Seçimin/ilerlemenin soluk tonu: "çalışılıyor" dilimi, ara yoğunluk.
  static const selectionSoft = Color(0xFFCFC8BC);

  /// Yalnızca yüzen katmanlar için. Kartlarda kullanılmaz.
  static const floatingShadow = <BoxShadow>[
    BoxShadow(color: Color(0x1F312A1F), blurRadius: 28, offset: Offset(0, 8)),
  ];
}

/// Derslere atanan palet; `Subjects.colorIndex` bu listeye işaret eder.
///
/// Her giriş bir çifttir: nokta, ikon ve etiket için doygun [ink]; arkasındaki
/// rozet için soluk [wash]. İkisini birlikte tutmak, her bileşenin elle
/// saydamlık karıştırmasına gerek kalmadan ders etiketini okunaklı tutuyor.
///
/// Yorumlar, paketlenmiş şablonlarda her sıranın hangi ders için kullanıldığını
/// söyler. Bu yalnızca bir alışkanlık — kullanıcı istediği rengi seçer — ama
/// iki sınava birden hazırlanan öğrenci Matematik'i ikisinde de aynı renkte
/// görüyor.
///
/// Yalnızca sona eklenir; sıra değiştirilmez, giriş silinmez. Aksi hâlde
/// mevcut kullanıcıların dersleri sessizce renk değiştirir.
///
/// Palet renk körlüğüne karşı doğrulandı (OKLab ΔE, komşu çiftler, protan ve
/// tritan). İlk sürümde iki kusur vardı, ikisi de düzeltildi: gri okunan bir
/// gri-mavi ve protan görüşte ayırt edilemeyen fıstık/amber çifti. Değer
/// değiştirmeden önce paleti yeniden doğrulayın — renk hem etiketlerde hem
/// dağılım grafiğinde kimlik taşıyor.
///
/// Turuncunun beyaz üstünde kontrastı 3:1'in altında kalıyor; bu yüzden renk
/// hiçbir yerde tek başına kimlik taşımaz, yanında her zaman ders adı yazar.
class SubjectColor {
  const SubjectColor(this.ink, this.wash);

  final Color ink;
  final Color wash;
}

abstract final class SubjectPalette {
  static const colors = <SubjectColor>[
    SubjectColor(Color(0xFF6B4EE8), Color(0xFFEDE8FF)), // mor      · Türkçe
    SubjectColor(Color(0xFF0E9F8E), Color(0xFFDFF5F1)), // turkuaz  · Matematik
    SubjectColor(
      Color(0xFF2C7BE5),
      Color(0xFFE3EFFD),
    ), // mavi     · Fen / Fizik
    SubjectColor(Color(0xFFE0567F), Color(0xFFFCE7EE)), // mercan   · Tarih
    SubjectColor(Color(0xFFB8860B), Color(0xFFFAF0D8)), // hardal   · İngilizce
    SubjectColor(
      Color(0xFF3F7A1E),
      Color(0xFFE7F2DC),
    ), // yaprak   · Din Kültürü
    SubjectColor(Color(0xFFE07B39), Color(0xFFFDEDE1)), // turuncu  · Geometri
    SubjectColor(Color(0xFF9B51E0), Color(0xFFF4E9FD)), // lila     · Kimya
    SubjectColor(Color(0xFF2E8B57), Color(0xFFE4F3EA)), // yeşil    · Biyoloji
    SubjectColor(Color(0xFF4557C7), Color(0xFFE7EAFB)), // çivit    · Coğrafya
    SubjectColor(
      Color(0xFFB24C63),
      Color(0xFFF7E7EB),
    ), // bordo    · Felsefe grubu
    SubjectColor(
      Color(0xFF0F6FA8),
      Color(0xFFE1EFF7),
    ), // petrol   · Vatandaşlık
  ];

  /// Güvenli erişim: ileride uzayan bir paletten yazılmış indeks, eski bir
  /// sürümde hata fırlatmak yerine başa sarar.
  static SubjectColor at(int index) => colors[index % colors.length];
}
