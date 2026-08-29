"""Ekran görüntülerindeki alfa kanalını kaldırır.

App Store Connect saydamlık içeren ekran görüntülerini kabul etmiyor.
Flutter'ın `RepaintBoundary.toImage` çağrısı her zaman RGBA üretiyor; kareler
görsel olarak tamamen opak olsa bile kanal dosyada duruyor ve yükleme
reddediliyor.

Kanalı düşürürken zemin rengi altına konuyor (tema zemini #FAF6EF). Doğrudan
`convert("RGB")` çağırmak saydam pikselleri siyaha çeviriyor; bizde tümüyle
opak kareler için sonuç aynı olsa da, ileride yarı saydam bir öğe eklenirse
siyah leke bırakırdı.

Kullanım:  python3 tool/flatten_screenshots.py
"""

from pathlib import Path

from PIL import Image

ZEMIN = (250, 246, 239)  # AppColors.background
KOK = Path(__file__).resolve().parent.parent / "screenshots"


def duzlestir(yol: Path) -> bool:
    with Image.open(yol) as gorsel:
        if gorsel.mode != "RGBA":
            return False
        zemin = Image.new("RGB", gorsel.size, ZEMIN)
        zemin.paste(gorsel, mask=gorsel.split()[3])
        zemin.save(yol, "PNG", optimize=True)
    return True


def main() -> None:
    degisen = 0
    for yol in sorted(KOK.glob("ios-*/*.png")):
        if duzlestir(yol):
            degisen += 1
            print(f"  alfa kaldırıldı: {yol.relative_to(KOK.parent)}")
    print(f"{degisen} dosya düzleştirildi.")


if __name__ == "__main__":
    main()
