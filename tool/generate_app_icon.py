# -*- coding: utf-8 -*-
"""Ritim uygulama ikonunu üretir.

Koşan bir figür ve arkasında ritim çizgileri. İkon metin taşımaz: 60 pikselde
yazı okunmuyor ve iOS zaten uygulamanın adını ikonun altında yazıyor.

Neden hazır çizim değil: unDraw'ın lisansı ticari kullanıma izin veriyor ama
üzerinde münhasır hak vermiyor — aynı figürü başka bir uygulama da
kullanabilir ve marka olarak tescil edilemez. Bir de unDraw sahneleri ince
çizgili; ikon boyutunda bulanıklaşıyor. Bu yüzden figür kalın, kapalı
şekillerden çiziliyor.

Kullanım: `python3 tool/generate_app_icon.py`
"""
import json
import os

from PIL import Image, ImageDraw

BOYUT = 1024

KIREMIT = (201, 81, 43)
FILDISI = (250, 246, 239)
# Arkadaki ritim çizgileri: zeminden bir ton açık, figürden belirgin şekilde
# soluk. Aynı tonda olsalardı figürün bacaklarıyla karışırlardı.
RITIM = (218, 121, 86)

# İkondaki vurgusuz çubuklar. Zeminden yeterince ayrılması gerekiyor: ilk
# denemede zemine çok yakın bir tondu ve küçük boyutta çubuklar kayboluyordu.
IKINCIL = (240, 185, 160)

IOS_CIKTI = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
ANDROID_CIKTI = 'android/app/src/main/res'

# Android yoğunluk klasörleri ve kenar uzunlukları.
ANDROID_BOYUTLAR = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}


# Bir haftanın çalışma ritmi: pazartesiden pazara, yükseklikler o günün
# çalışma süresi. Rastgele değil — hafta sonu düşük, hafta ortası tepe.
#
# Bu ayrım önemli: eşit aralıklı, simetrik çubuklar ses seviyesi göstergesi
# gibi okunuyor. Düzensiz ama anlamlı bir dizilim "bir haftanın kaydı" diyor,
# ki uygulamanın yaptığı şey tam olarak bu. Aynı motif Bugün ekranındaki
# haftalık grafikte de var; ikon uygulamanın içinden bir parça.
# Beş çubuk, yedi değil. Yedi gün anlamlıydı ama 29 piksellik Ayarlar
# ikonunda çubuklar birbirine giriyor ve ritim tek bir lekeye dönüşüyordu.
# Beş çubuk aynı fikri anlatıyor ve her boyutta ayrık kalıyor.
HAFTA = [0.54, 0.86, 0.38, 1.00, 0.64]

# En yüksek gün fildişi, diğerleri soluk kiremit. Tek vurgu kuralı ikonda da
# geçerli: her şey vurguluysa hiçbir şey vurgulu değildir.
TEPE = 3


def ikon():
    """Ritim çubukları.

    Figür denendi ve bırakıldı: çizgilerle çizilen koşan adam acil çıkış
    tabelasına benziyor, elle çokgen yazarak düz-vektör kalitesi çıkmıyor.
    Çubuklar hem uygulamanın adını doğrudan anlatıyor hem 29 pikselde
    kusursuz okunuyor.
    """
    img = Image.new('RGB', (BOYUT, BOYUT), KIREMIT)
    d = ImageDraw.Draw(img)

    # Çubuklar tuvalin yüzde 64'ünü kaplıyor; kalan pay iOS'un yuvarlattığı
    # köşelere ve nefes alanına gidiyor.
    alan = BOYUT * 0.64
    kalinlik = alan / (len(HAFTA) * 1.55)
    aralik = kalinlik * 0.55
    toplam = len(HAFTA) * kalinlik + (len(HAFTA) - 1) * aralik

    x = (BOYUT - toplam) / 2
    taban = BOYUT * 0.72
    en_yuksek = BOYUT * 0.44

    for i, oran in enumerate(HAFTA):
        yukseklik = max(kalinlik, en_yuksek * oran)
        d.rounded_rectangle(
            (x, taban - yukseklik, x + kalinlik, taban),
            radius=kalinlik / 2,
            fill=FILDISI if i == TEPE else IKINCIL,
        )
        x += kalinlik + aralik

    return img


def yaz():
    img = ikon()

    tanim = json.load(open(os.path.join(IOS_CIKTI, 'Contents.json')))
    ios = 0
    for kayit in tanim['images']:
        dosya = kayit.get('filename')
        if not dosya:
            continue
        kenar = float(kayit['size'].split('x')[0])
        olcek = int(kayit['scale'].rstrip('x'))
        piksel = int(round(kenar * olcek))
        img.resize((piksel, piksel), Image.LANCZOS).save(
            os.path.join(IOS_CIKTI, dosya)
        )
        ios += 1

    android = 0
    for klasor, kenar in ANDROID_BOYUTLAR.items():
        hedef = os.path.join(ANDROID_CIKTI, klasor)
        if not os.path.isdir(hedef):
            continue
        img.resize((kenar, kenar), Image.LANCZOS).save(
            os.path.join(hedef, 'ic_launcher.png')
        )
        android += 1

    # Mağaza listelemesi ve belgeler için tam boy kopya. Depoda duruyor ki
    # README ve mağaza görselleri aynı kaynaktan beslensin.
    img.save('tool/app_icon_1024.png')
    img.resize((512, 512), Image.LANCZOS).save('docs/icon.png')

    print('%d iOS, %d Android ikonu yazıldı' % (ios, android))


if __name__ == '__main__':
    yaz()
