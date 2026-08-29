# Ekran görüntüleri

App Store için hazır kareler. Elle çekilmiyor, `test/screenshot_capture_test.dart`
üretiyor:

```
RITIM_SHOTS=1 flutter test test/screenshot_capture_test.dart --tags screenshots
python3 tool/flatten_screenshots.py
```

İkinci adım zorunlu. `RepaintBoundary.toImage` her zaman RGBA üretiyor ve
App Store Connect alfa kanalı taşıyan ekran görüntülerini reddediyor —
üstelik bunu bazen ölçüyle ilgiliymiş gibi genel bir mesajla bildiriyor.

Araç olağan `flutter test` koşusunda atlanır; `RITIM_SHOTS=1` verilmediği sürece
çalışmaz.

## Neden test düzeneği

Simülatörde programatik dokunma yok, `flutter drive` ise tek iş için ağır
kalıyor. Widget testi gerçek ağacı tam çözünürlükte kurabildiği için kareler
uygulamanın kendisinden çıkıyor — montaj ya da tasarım dosyası değil.

Görüntü `RepaintBoundary.toImage` ile alınıyor, `matchesGoldenFile` ile değil:
golden karşılaştırıcısı görüntüyü 1x piksel oranıyla yakalıyor ve mağazanın
istediğinden çok küçük bir dosya üretiyor.

## Boyutlar

| Klasör | Piksel | App Store Connect yuvası | Cihazlar |
|---|---|---|---|
| `ios-6.9/` | 1320 × 2868 | 6.9" — **zorunlu** | iPhone 16/17 Pro Max |
| `ios-6.7/` | 1290 × 2796 | 6.7" | iPhone 14/15 Pro Max, 15/16 Plus |
| `ios-6.5/` | 1242 × 2688 | 6.5" | iPhone 11 Pro Max, XS Max, 11, XR |

Klasör adı doğrudan yuvanın adı. İlk üretimde 1290 × 2796 yanlışlıkla "6.9"
diye etiketlenmişti; o ölçü 6.7" sınıfına ait ve 6.9" yuvasına yüklenince
mağaza *"The dimensions of one or more screenshots are wrong"* veriyor.
Yükleme yaparken klasör adıyla yuva adı birebir eşleşmeli.

## Kareler

| Dosya | Ekran | Önerilen alt yazı |
|---|---|---|
| `01-bugun` | Bugün | Bugün ne çalışacağın belli. |
| `02-ozet` | Bugün · özet açık | Haftanı tek bakışta gör. |
| `03-plan` | Plan | Haftalık planını bir kere kur. |
| `04-dersler` | Derslerin | Her ders, her konu tek yerde. |
| `05-deneme` | Denemelerin | Netin nereye gidiyor? |
| `06-deneme-analiz` | Deneme analizi | Hangi ders seni düşürdü, konu konu gör. |

## Yüklerken

Yalnızca `ios-6.9/` klasörünü, "iPhone 6.9" Display" yuvasına yükleyin.
Bugün iPhone tarafında zorunlu olan tek yuva bu; daha küçük ekranları Apple
kendisi ölçekliyor. `ios-6.7/` ve `ios-6.5/` yalnızca ilgili yuva
görünüyorsa kullanılmalı — görünmeyen bir yuva için yükleme denemesi
"dimensions are wrong" hatası veriyor.

## Verinin gerçekliği

Kareler LGS 8. sınıf şablonundan kurulmuş gerçek kayıtlarla üretiliyor:
oturumlar `logStudySession` ile yazılıyor, tekrarlar 1-3-7-21 merdiveninden
çıkıyor, denemelerin netleri `ExamScoring` ile hesaplanıyor. Apple ekran
görüntülerinin uygulamayı dürüst temsil etmesini istiyor; uydurma ekran yok.
