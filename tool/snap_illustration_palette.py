# -*- coding: utf-8 -*-
"""unDraw çizimlerini Ritim paletine oturtur.

unDraw'ın kendi renk çeşitliliği (neon turkuaz, parlak pembe, mor griler)
fildişi zemin ve kiremit vurguyla çatışıyor; çizimler uygulamadan kopuk
duruyordu.

İki kural:

1. **Renkler yalnızca renk taşıyan yerlerde değiştirilir.** İlk sürüm dosyadaki
   her 6 haneli onaltılık diziyi değiştiriyordu; unDraw'ın kimlikleri de
   onaltılık göründüğü için (`id="9c7f1c1e-55bc-..."`) kimlikler bozuluyor,
   degrade referansları kopuyor ve `flutter_svg` çözemediği degradede
   **çizimin tamamını** atıyordu. Ekranda hiçbir şey görünmüyor, hata yalnızca
   kayıtlara düşüyordu.

2. **Degradeler düz renge çevrilir.** Hem paletimize aykırılar hem de
   `flutter_svg` tarafında en kırılgan yapı onlar.

Kullanım: `python3 tool/snap_illustration_palette.py`
"""
import colorsys
import glob
import os
import re

NOTRLER = [  # (açıklık, hex) — sıcak gri rampası
    (1.00, 'FFFFFF'), (0.96, 'FAF6EF'), (0.92, 'F2EDE4'), (0.86, 'EAE3D8'),
    (0.65, 'A09B92'), (0.45, '6E6A63'), (0.30, '4A453D'), (0.20, '3A3630'),
    (0.11, '1F1D1A'),
]

# Çizimler tek renk ailesinde kalıyor: kiremit ve tonları.
#
# Önce ders paletinin tamamı hedefti ve "en yakın ton" kuralıyla eşleniyordu;
# sonuç, illüstrasyonda mavi ve mor lekelerdi. Ders renkleri **etikete** ait —
# kimlik taşırlar; çizimde kimlik taşıyacak bir şey yok, orada renk yalnızca
# derinlik veriyor. Tek aile hem uygulamayla aynı dili konuşuyor hem de
# çizimler birbirinin devamı gibi duruyor.
#
# Üç kademe: koyu mürekkep, orta ton, soluk zemin. İkiden azı figürleri
# düzleştiriyor, üçten fazlası kademeler arası farkı gözle ayırt edilemez
# yapıyor.
KIREMIT_KOYU = 'A33F20'
KIREMIT = 'C9512B'
KIREMIT_ORTA = 'DA7956'
KIREMIT_ACIK = 'F0C4B0'
KIREMIT_ZEMIN = 'F9E9E1'

# Renk taşıyan öznitelikler. Bunların dışında hiçbir yere dokunulmuyor.
RENK_OZNITELIKLERI = ('fill', 'stroke', 'stop-color', 'flood-color', 'color')


def hsl(hexcode):
    r, g, b = (int(hexcode[i:i + 2], 16) / 255 for i in (0, 2, 4))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360, s, l


def snap(hexcode):
    h, s, l = hsl(hexcode)
    if s < 0.16:
        return min(NOTRLER, key=lambda n: abs(n[0] - l))[1]
    # Renkli her şey kiremit ailesine, açıklığına göre yerleşiyor. Ton bilgisi
    # bilerek atılıyor: çizimde mavi bir gömlek ile kırmızı bir çiçek farklı
    # şeyler anlatmıyor, ikisi de sadece birer yüzey.
    if l > 0.86:
        return KIREMIT_ZEMIN
    if l > 0.72:
        return KIREMIT_ACIK
    if l > 0.55:
        return KIREMIT_ORTA
    if l > 0.34:
        return KIREMIT
    return KIREMIT_KOYU


def degrade_renkleri(icerik):
    """Her degradenin ilk durak rengini, `xlink:href` zincirini çözerek verir."""
    ham = {}
    href = {}

    # Hem gövdeli hem kendini kapatan etiketler: unDraw, durakları tek bir
    # degradede tanımlayıp diğerlerini `xlink:href` ile ona bağlıyor ve o
    # bağlı olanlar kendini kapatan etiketler oluyor.
    desen = (
        r'<(?:linear|radial)Gradient\b([^>]*?)'
        r'(?:/>|>(.*?)</(?:linear|radial)Gradient>)'
    )
    for m in re.finditer(desen, icerik, re.S):
        oznitelik = m.group(1)
        govde = m.group(2) or ''
        kimlik = re.search(r'id="([^"]+)"', oznitelik)
        if not kimlik:
            continue
        durak = re.search(r'stop-color="(#[0-9a-fA-F]{6})"', govde)
        if durak:
            ham[kimlik.group(1)] = durak.group(1)
        else:
            bagli = re.search(r'xlink:href="#([^"]+)"', oznitelik)
            if bagli:
                href[kimlik.group(1)] = bagli.group(1)

    # Kendi durağı olmayan degradeler başkasına bağlı; zinciri çözüyoruz.
    for kimlik, hedef in href.items():
        gorulen = set()
        while hedef in href and hedef not in gorulen:
            gorulen.add(hedef)
            hedef = href[hedef]
        if hedef in ham:
            ham[kimlik] = ham[hedef]
    return ham


def duzlestir(icerik):
    renkler = degrade_renkleri(icerik)
    for kimlik, renk in renkler.items():
        icerik = icerik.replace('url(#%s)' % kimlik, renk)
    icerik = re.sub(
        r'<(linear|radial)Gradient\b.*?</\1Gradient>', '', icerik, flags=re.S
    )
    icerik = re.sub(r'<(?:linear|radial)Gradient\b[^>]*/>', '', icerik)
    # Çözülemeyen degrade kalmışsa düz bir nötre çekiliyor: çözümsüz bir
    # referans, flutter_svg tarafında çizimin tamamını düşürüyor.
    icerik = re.sub(r'url\(#[^)]*\)', '#EAE3D8', icerik)
    return icerik, len(renkler)


def oturt(icerik):
    sayac = [0]

    def degistir(m):
        oznitelik, renk = m.group(1), m.group(2)
        yeni = snap(renk.lstrip('#').lower())
        if '#' + yeni.lower() == renk.lower():
            return m.group(0)
        sayac[0] += 1
        return '%s="#%s"' % (oznitelik, yeni)

    desen = r'(%s)="(#[0-9a-fA-F]{6})"' % '|'.join(RENK_OZNITELIKLERI)
    icerik = re.sub(desen, degistir, icerik)
    return icerik, sayac[0]


def main():
    toplam_renk = 0
    toplam_degrade = 0
    for path in sorted(glob.glob('assets/illustrations/*.svg')):
        icerik = open(path, encoding='utf-8').read()
        icerik, degrade = duzlestir(icerik)
        icerik, renk = oturt(icerik)
        open(path, 'w', encoding='utf-8').write(icerik)
        toplam_renk += renk
        toplam_degrade += degrade
        print('%-22s %3d renk, %d degrade' % (os.path.basename(path), renk, degrade))
    print('toplam %d renk, %d degrade düzleştirildi' % (toplam_renk, toplam_degrade))


if __name__ == '__main__':
    main()
