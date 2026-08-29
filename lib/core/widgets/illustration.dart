import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
/// Uygulamadaki illüstrasyonlar.
///
/// unDraw çizimleri (Katerina Limpitsouni). Dosyalar indirildikten sonra
/// **tamamen** paletimize oturtuldu: her renk tonuna ve açıklığına göre en
/// yakın palet değerine çevrildi (açık olanlar soluk zeminleri, koyu olanlar
/// mürekkepleri aldı; böylece çizimin ışık-gölge yapısı korundu).
///
/// Önce yalnızca unDraw'ın birincil moru değiştirilmişti; geriye kalan neon
/// turkuaz, parlak pembe ve mor griler fildişi zeminle çatışıyor, çizimler
/// uygulamadan kopuk duruyordu. Şimdi altı çizim toplam 27 renk kullanıyor ve
/// hepsi paletten geliyor.
///
/// Çalışma anında renk geçirmeye gerek yok; SVG'ler zaten doğru renkte.
enum Illustration {
  /// Bugün için planlanmış iş yok.
  emptyDay('bos_gun'),

  /// Henüz ders eklenmemiş.
  firstSubject('ilk_ders'),

  /// Konuya çalışma daveti.
  studying('calisma'),

  /// Tekrar zamanı geldi.
  reviewTime('tekrar_zamani'),

  /// Kutlama: hepsi bitti.
  allDone('tamamlandi'),

  /// Karşılama ekranı: çalışmayı düzene sokmak.
  welcome('duzen');

  const Illustration(this.file);

  final String file;

  String get path => 'assets/illustrations/$file.svg';
}

/// Bir illüstrasyonu çizer.
class IllustrationView extends StatelessWidget {
  const IllustrationView(this.illustration, {this.height = 150, super.key});

  final Illustration illustration;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      illustration.path,
      height: height,
      // Çizimler ekranın yıldızı değil; boş durumun üstünde durur ve metnin
      // önüne geçmemeleri gerekir.
      fit: BoxFit.contain,
      semanticsLabel: '',
      excludeFromSemantics: true,
    );
  }
}
