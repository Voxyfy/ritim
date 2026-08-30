<img src="docs/icon.png" width="96" alt="Ritim" align="left" hspace="16" vspace="4">

# Ritim

**Çalışmanı düzene sok.**
Öğrenciler için konu takibi, çalışma kaydı ve aralıklı tekrar uygulaması.

<br clear="left">

![Flutter](https://img.shields.io/badge/Flutter-3.41-0468D7?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/platform-iOS%20%C2%B7%20Android-lightgrey)
![Tests](https://img.shields.io/badge/tests-149%20passing-7CB518)
![License](https://img.shields.io/badge/license-MIT-C9512B)

Ritim düz bir yapılacaklar listesi değil. Öğrencinin gerçek birimi görev değil **konu**: bir konuya çalışırsın, uygulama o konuyu 1-3-7-21 gün merdiveninde tekrara koyar, tekrar günü geldiğinde notlarını ve yanlış kayıtlarını önüne getirir.

Ortaokuldan üniversiteye kadar çalışır: müfredat koda gömülü değil, şablon olarak gelir ve tamamen düzenlenebilir.

> **Durum:** geliştirme aşamasında, henüz mağazada değil. İlk yayın hedefi App Store.

## İçindekiler

[Neden](#neden) · [Özellikler](#özellikler) · [Hazır şablonlar](#hazır-şablonlar) ·
[Tekrar motoru](#tekrar-motoru) · [Deneme analizi](#deneme-sınavı-analizi) ·
[Kurulum](#kurulum) · [Proje yapısı](#proje-yapısı) · [Testler](#testler) ·
[Ekran görüntüleri](#ekran-görüntüleri) · [Yayın](#yayın) · [Katkı](#katkı)

## Neden

Piyasadaki not ve görev uygulamaları genel amaçlı; öğrencinin ihtiyacı olan üç şeyi bir arada vermiyorlar:

1. **Konu bazlı ilerleme** — "Matematik" değil, "Çarpanlar ve Katlar" seviyesinde takip.
2. **Aralıklı tekrar** — çalıştığın konu kendiliğinden tekrara düşsün, sen hatırlamak zorunda kalma.
3. **Bağlamına yapışık not** — not ayrı bir deftere değil, konuya ait. Tekrar günü geldiğinde zaten elinin altında.

## Özellikler

| Durum | Özellik |
|---|---|
| ✅ | Ders / konu veri modeli, çevrimdışı SQLite deposu |
| ✅ | 15 hazır şablon (1.000+ konu) + "boş başla" seçeneği |
| ✅ | Kurulum akışı: karşılama, şablon seçimi, üç adımlık tanıtım |
| ✅ | Ders ve konu yönetimi: ekleme, düzenleme, silme, renk seçimi |
| ✅ | Haftalık plan: bitmemiş konuları seçilen günlere dağıtır |
| ✅ | Plan sekmesi: iki haftalık görünüm, boş günler dahil |
| ✅ | Görev sayfası: başlık, gün, kısa not, konuya git |
| ✅ | Konuya fotoğraf ekleme (kamera ve galeri) |
| ✅ | Ana ekran istatistikleri: ders dağılımı, konu ilerlemesi |
| ✅ | Deneme sınavı analizi: net hesabı, zayıf ders çıkarımı, odaklı plan |
| ✅ | Konuya çoklu not ve fotoğraf |
| ✅ | Plan takvimi, ayarlar ve kademeli sıfırlama |
| ✅ | Bugün ekranı: görev ekleme, tamamlama, erteleme, geciken işler |
| ✅ | Dersler ve konular: ilerleme halkaları, üç durumlu konu takibi |
| ✅ | Çalışma kaydı: süre, çözülen/yanlış soru, konuya bağlı not |
| ✅ | Aralıklı tekrar motoru: 1-3-7-21 merdiveni, yanlış oranına göre uyarlanır |
| ✅ | Tekrar bildirimleri ve izin akışı |
| ✅ | Haftalık özet, seri takibi, paketlenmiş yazı tipi ve illüstrasyonlar |

## Hazır şablonlar

Kurulumda öğrenci kendi hedefini seçer; şablon, düzenlenebilir ders ve konu satırları oluşturur.

| Grup | Şablon | Kapsam |
|---|---|---|
| Ortaokul | 5, 6, 7. Sınıf | Türkiye Yüzyılı Maarif Modeli temaları |
| Ortaokul | LGS · 8. Sınıf | 6 ders, 67 konu |
| Lise ve YKS | 9, 10, 11. Sınıf | 9-10 ders, 73-104 konu |
| Lise ve YKS | TYT | 10 ders, 130 konu |
| Lise ve YKS | AYT Sayısal / Eşit Ağırlık / Sözel | 5-7 ders, 78-112 konu |
| Lise ve YKS | YDT İngilizce | Dil bilgisi, kelime, okuma |
| Kamu sınavları | KPSS Lisans (GY-GK) | 7 ders, 87 konu |
| Kamu sınavları | MEB-AGS | Öğretmen adayları için; KPSS'nin yerini aldı |
| Kamu sınavları | DGS | Sayısal ve sözel muhakeme |

Konu listeleri 2026-2027 dönemi MEB ve ÖSYM konu dağılımlarına göre hazırlandı.

Ortaokul şablonları Türkiye Yüzyılı Maarif Modeli'nin tema adlarını kullanır. Lise şablonlarında ise konular ders kitabı bölümü seviyesinde yazıldı: Maarif Modeli'nin lise temaları takip birimi olarak fazla geniş kalıyor (11. sınıf biyolojinin tamamı "Tepki" ve "Homeostazi" olmak üzere iki temadır) ve bir yılı iki satırla takip etmek uygulamanın amacına aykırı.

Müfredat her yıl değişebildiği için şablonlar sürüm başına gözden geçirilir; hatalı gördüğünüz bir konu listesi için issue açın.

## Notlar ve fotoğraflar nereye ait?

Uygulamadaki en belirleyici ayrım: **görev lojistiktir, konu bilgidir.**

| | Görev | Konu |
|---|---|---|
| Ömür | Tamamlanınca kapanır | Kalıcı, tekrar günü geri gelir |
| Not | Tek satır ("kitap s. 42-58") | Serbest metin |
| Fotoğraf | Yok | Var |

Fotoğraf **görev sayfasından da eklenebilir** ama her zaman konuya kaydedilir:
kullanıcı kolaylığı görevde, bilginin yeri konuda. Göreve iliştirilen bir görsel
iş tamamlanınca kaybolurdu.

Bu ayrım yüzünden görev içi alt görev listesi ve ses kaydı bilinçli olarak
eklenmedi — ikisi de ürünü genel amaçlı bir yapılacaklar uygulamasına çevirir.

## Tekrar motoru

Çalışma kaydı girildiği anda konu merdivene girer. Aralıklar **1 - 3 - 7 - 21 gün**, sonrasında aylık ritim. Dizi bir hafıza modelinden değil, sınav hazırlığının ritminden geliyor: ertesi gün, hafta içi, hafta sonu, ay başı.

Soru verisi girilmişse aralık doğru oranına göre uyarlanır:

| Doğru oranı | Sonuç |
|---|---|
| %85 ve üstü | Bir üst basamak, aralık uzar |
| %60 - %85 | Aynı basamak tekrarlanır, aralık uzamaz |
| %60 altı | Bir basamak geri, aralık kısalır |

Soru girilmemişse merdiven sabit ilerler — soru çözmeyen bir üniversite öğrencisi de motordan faydalanabilsin diye. Karar mantığının tamamı `lib/domain/review_ladder.dart` içinde saf bir fonksiyondur; veritabanı yalnızca sonucu uygular.

Bir konunun aynı anda tek bekleyen tekrarı olur. Üst üste çalışmak yeni tekrar açmaz, var olanın tarihini yeniler.

## Haftalık plan

Şablon 41 konu getiriyor ama öğrencinin sorusu "bugün ne yapacağım". Haftalık
plan bu boşluğu kapatır: iki soru sorar (hangi günler, günde kaç konu) ve
bitmemiş konuları o günlere dağıtır.

- Dersler sırayla dolaşılır; bir güne aynı dersten üç konu düşmez. Bir
  öğrenciye "bugün 3 matematik" demek, planı ilk gün terk ettiren şeydir.
- Ders içinde müfredat sırası korunur; planlayıcı konu seçmez, sıradakileri
  güne dağıtır.
- Üretim belirlenimcidir: aynı girdi hep aynı planı verir, "planı yenile"
  sürpriz üretmez.
- Yenileme yalnızca **tamamlanmamış** plan işlerini siler. Bitirdikleriniz ve
  kendi eklediğiniz işler kalır.

Karar mantığı `lib/domain/weekly_planner.dart` içinde saf bir fonksiyondur.

## Deneme sınavı analizi

Denemenin ders ders doğru/yanlış/boş sayıları giriliyor; uygulama neti hesaplıyor
ve en zayıf dersleri çıkarıyor.

Yanlışın doğruyu götürme kuralı sınavla birlikte saklanıyor, uygulama genelinde
sabit değil: LGS'de 3 yanlış, YKS'de 4 yanlış bir doğruyu götürüyor, KPSS/AGS/DGS'de
götürmüyor. Varsayılan kurulumda seçilen şablondan türetiliyor.

İki karar analizin tamamını belirliyor:

- **Doğru oranında boşlar sayılmıyor.** Boş bir bilgi eksiği, yanlış ise bir
  yanılgı; ikisini karıştırmak, hiç dokunulmamış soruyu "çok yanlış yapılıyor"
  diye göstermek olurdu.
- **Zayıf ders sıralaması nete göre değil doğru oranına göre.** 40 soruda 20 net,
  10 soruda 8 netten iyi *görünür* ama oran tersini söyler.

Analiz ekranı sayı gösterip bırakmıyor: en zayıf derslere doğrudan plan kuran bir
düğme var. Sayıyı gösterip öğrenciyi kendi başına bırakan bir ekran karneden
farksız olurdu.

## Bildirimler

Tekrar günü akşamı tek bir hatırlatma. Saat seçilebilir (varsayılan 19:00), tamamen kapatılabilir.

İzin, kurulum sırasında değil **ilk çalışma kaydından sonra** isteniyor: hatırlatmanın ne işe yaradığı en anlaşılır olduğu an orası. Sistem uyarısından önce ne için istendiğini anlatan bir adım var; "şimdi değil" diyen kullanıcıya sistem uyarısı hiç gösterilmiyor, yani iOS'ta ömürde bir kez çıkan o hak yanmıyor.

## Tasarım ilkeleri

- **Çevrimdışı öncelikli, hesapsız.** Sunucu yok, kayıt yok, veri toplama yok. Her şey cihazda kalır.
- **Sıcak ve açık arayüz.** Kâğıt hissi veren fildişi zemin, üzerinde yüzen beyaz kartlar, geniş köşe yarıçapı ve bol boşluk. Arayüzün samimiyeti renkten değil, yarıçap ve boşluktan gelir.
- **Tek vurgu rengi.** Kiremit (`AppColors.accent`) eylem rengidir; ilerleme ve seri için ayrı bir yeşil dolgu vardır ve o renk asla metinde kullanılmaz. Vurgu rengi bir ekranda birden fazla yerde görünüyorsa anlamını yitirmiştir.
- **Ders renkleri etiket gibidir.** Her ders koyu bir mürekkep ve soluk bir zemin çiftine sahiptir (`SubjectPalette`); rozetler bu çiftle çizilir, opaklıkla değil.
- **Uygulama dürter, azarlamaz.** Geciken iş alarm kırmızısı değil yumuşak mercandır.
- **Şablon müfredat değildir.** Şablon uygulamak sıradan kullanıcı satırları yazar; hepsi silinebilir, düzenlenebilir.

## Teknoloji

- **Flutter / Dart** — ilk yayın **iOS / App Store**, Android ikinci aşamada
- **Drift + SQLite** — çevrimdışı depo, tip güvenli sorgular
- **Riverpod** — durum yönetimi
- **go_router** — yönlendirme
- **Phosphor Icons** — tek ikon ailesi
- **intl / flutter_localizations** — arayüz tek dilli: Türkçe (`tr_TR`)

## Kurulum

```bash
git clone https://github.com/Voxyfy/ritim.git
cd ritim
flutter pub get
dart run build_runner build      # Drift kod üretimi
flutter run
```

Şemaya (`lib/data/db/tables.dart`) her dokunuşta `build_runner`'ı yeniden çalıştırın.

Üretilen dosyalar (`*.g.dart`) depoda tutulmaz; `build_runner` olmadan proje derlenmez. Bu bilinçli bir tercih: üretilen kod tamamen yeniden oluşturulabilir ve depoda tutulduğunda her şema değişikliği binlerce satırlık gürültü ve birleştirme çakışması üretir.

iOS için ek adım:

```bash
cd ios && pod install && cd ..
open ios/Runner.xcworkspace   # imzalama ayarları Xcode'da yapılır
```

## Proje yapısı

```
lib/
├── core/
│   ├── router.dart             # go_router; kurulum bir ekran değil, yönlendirme
│   ├── notifications.dart      # Yerel bildirim servisi
│   ├── reminder_sync.dart      # Tekrarları bildirimlerle eşler
│   ├── providers.dart          # Riverpod sağlayıcıları
│   ├── date_extensions.dart    # Gün bazlı tarih yardımcıları
│   ├── theme/                  # Renk token'ları, tema, geometri
│   └── widgets/                # Ekranlar arası ortak bileşenler
├── data/
│   ├── db/                     # Drift tabloları ve veritabanı
│   ├── photo_store.dart        # Konu fotoğraflarının dosya tarafı
│   └── templates/              # Şablon modeli ve varlık yükleyicisi
├── domain/                     # Saf iş mantığı (tekrar merdiveni)
├── features/
│   ├── onboarding/             # Karşılama, şablon seçimi, tanıtım
│   ├── exams/                  # Deneme girişi ve analizi
│   ├── plan/                   # Haftalık plan, takvim ve plan sekmesi
│   ├── settings/               # Ayarlar ve sıfırlama
│   ├── reminders/              # Bildirim izni ve hatırlatma ayarları
│   ├── shell/                  # Yüzen sekme çubuğu
│   ├── subjects/               # Dersler, konular, çalışma kaydı
│   └── today/                  # Bugün ekranı
└── main.dart
assets/templates/               # Şablonlar (JSON)
assets/fonts/                   # Plus Jakarta Sans (400-800)
assets/illustrations/           # unDraw çizimleri, palete boyanmış
test/                           # Veri katmanı ve akış testleri
tool/                           # İkon, illüstrasyon ve ekran görüntüsü araçları
docs/                           # GitHub Pages sayfaları + mağaza metinleri
screenshots/                    # App Store kareleri, boyut sınıfına göre
```

Mimari kuralları:

- **Renk sabiti yalnızca `core/theme` içinde bulunur.** Bir ekranda `Color(0x…)` görürseniz o bir hatadır.
- **Sorgular `RitimDatabase` içinde durur.** Yüzey bir ekranı aştığında özellik bazlı DAO'ya taşınır.
- **Ekranlar veritabanını doğrudan tanımaz**, sağlayıcılar üzerinden okur; testlerde bellek içi bir veritabanıyla değiştirilebilmesinin sebebi budur.
- **Bileşen temalarındaki `TextStyle`'a `fontFamily` elle yazılır.** `ThemeData.fontFamily` yalnızca `textTheme`e uygulanıyor; `appBarTheme`, `filledButtonTheme` ve `snackBarTheme` kapsam dışında kalıyor. Bu üçü bir süre uygulamadaki tek sistem yazı tipiyle çizilen metinlerdi ve ancak ekran görüntüsü çekerken fark edildi. Aynı tuzak `AnimatedDefaultTextStyle` ve `DefaultTextStyle` için de geçerli: biçemi sıfırdan kurmak yerine temadan türetin.

## Yeni şablon eklemek

Kod yazmadan sınav/sınıf şablonu eklenebilir:

1. `assets/templates/<id>.json` dosyasını oluşturun (mevcut birini örnek alın).
2. `<id>` değerini `TemplateRepository.assetIds` listesine, doğru sırada ekleyin.
3. `flutter test` çalıştırın — biçim, renk ve konu tekrarları otomatik doğrulanır.

Alanlar:

| Alan | Açıklama |
|---|---|
| `id` | Dosya adıyla aynı olmalı; yayımlandıktan sonra değişmez (ayarlarda saklanır) |
| `name` | Kurulumda görünen Türkçe ad |
| `group` | Bölüm başlığı: `Ortaokul`, `Lise ve YKS`, `Kamu sınavları` |
| `description` | Tek cümlelik açıklama |
| `subjects[].colorIndex` | `SubjectPalette` içindeki sıra (0-11) |

Aynı şablonda iki ders aynı rengi kullanamaz; test bunu engeller. Palet **yalnızca sona eklenerek** büyütülür, sıra değişirse mevcut kullanıcıların dersleri renk değiştirir.

## Testler

```bash
flutter test
```

Veritabanı testleri bellek içi SQLite kullanır, cihaz gerekmez. Kapsam:

| Dosya | Ne doğruluyor |
|---|---|
| `study_template_test.dart` | Paketlenen 15 şablonun biçimi, renk çakışması, konu tekrarı |
| `database_test.dart` | Şablon uygulama, sıra korunumu, cascade silme |
| `tasks_test.dart` | Bugün listesinin kuralları: gecikme, tamamlama, erteleme |
| `study_session_test.dart` | Çalışma kaydı, konu durumu, toplamlar, not temizliği |
| `subject_crud_test.dart` | Ders/konu ekleme, güncelleme, silme, sıra korunumu |
| `summary_test.dart` | Seri hesabı ve haftalık özet |
| `weekly_planner_test.dart` | Plan dağıtımının saf mantığı |
| `weekly_plan_db_test.dart` | Plan üretimi, yenileme, korunan işler |
| `task_detail_test.dart` | Görev güncelleme, etiketin başlığı tekrar etmemesi |
| `photo_test.dart` | Fotoğraf ekleme, silme, sıralama |
| `stats_test.dart` | Ders dağılımı ve konu ilerlemesi |
| `exam_scoring_test.dart` | Net hesabı ve zayıf ders çıkarımı |
| `mock_exam_test.dart` | Deneme kaydı, sıralama, cascade silme |
| `reset_test.dart` | Sıfırlama seçeneklerinin neyi silip neyi koruduğu |
| `day_tracker_test.dart` | Gece yarısı ve uygulama öne gelince tazeleme |
| `student_journey_test.dart` | İlk açılıştan ilk tekrara tam yolculuk |
| `student_confusion_test.dart` | Kullanıcıyı yanıltabilecek durumlar |
| `review_ladder_test.dart` | Tekrar merdiveninin saf karar mantığı |
| `review_engine_test.dart` | Çalışma → tekrar zinciri, hatırlatma ayarları |
| `onboarding_flow_test.dart` | Kurulum akışı ve yönlendirme (widget testi) |
| `screenshot_capture_test.dart` | Test değil, **çekim aracı** — bkz. [Ekran görüntüleri](#ekran-görüntüleri). Olağan koşuda atlanır. |

Widget testlerinde drift akışlarına abone olup ilk değeri beklemeyin
(`watchX().first`); sahte saat altında ilerlemez ve test kilitlenir. Tek
seferlik okuma (`select(...).get()`) kullanın.

## Ekran görüntüleri

Mağaza kareleri elle çekilmiyor; gerçek widget ağacından üretiliyor:

```bash
RITIM_SHOTS=1 flutter test test/screenshot_capture_test.dart --tags screenshots
python3 tool/flatten_screenshots.py
```

İkinci adım zorunlu. `RepaintBoundary.toImage` her zaman RGBA üretiyor ve
App Store Connect alfa kanalı taşıyan görselleri reddediyor — üstelik bunu
ölçüyle ilgiliymiş gibi genel bir mesajla bildiriyor.

**Neden widget testi.** Simülatörde programatik dokunma yok, `flutter drive`
tek iş için ağır kalıyor. Widget testi gerçek ağacı tam çözünürlükte
kurabildiği için kareler uygulamanın kendisinden çıkıyor — montaj değil.
Görüntü `matchesGoldenFile` ile değil `toImage` ile alınıyor: golden
karşılaştırıcısı 1x piksel oranıyla yakalıyor ve mağazanın istediğinden dört
kat küçük dosya üretiyor.

Karelerdeki veri de uydurma değil: LGS 8 şablonu uygulanıyor, oturumlar
gerçek `logStudySession` çağrılarıyla haftaya yayılıyor, netler
`ExamScoring` ile hesaplanıyor.

| Klasör | Piksel | App Store yuvası |
|---|---|---|
| `screenshots/ios-6.9/` | 1320 × 2868 | 6.9" — zorunlu olan tek iPhone yuvası |
| `screenshots/ios-6.7/` | 1290 × 2796 | 6.7" |
| `screenshots/ios-6.5/` | 1242 × 2688 | 6.5" |

Klasör adı doğrudan yuvanın adıdır. 1290 × 2796'yı "6.9" sanmak yükleme
reddine yol açar; o ölçü 6.7" sınıfına aittir.

## Yayın

Mağaza metinleri, TestFlight metinleri, gizlilik/destek bağlantıları ve sürüm
gönderme süreci tek dosyada: [`docs/app-store.md`](docs/app-store.md).

| | |
|---|---|
| Bundle ID | `com.batuhanhaymana.ritim` |
| Mağaza adı | Ritim: Çalışma Planı |
| Ana ekran adı | Ritim (`CFBundleDisplayName`) |
| En düşük iOS | 15.0 |

Sürüm numarası `pubspec.yaml`'daki tek satırdan geliyor:

```
version: 1.0.0+2
        └─┬─┘ └┬┘
          │    └── build numarası  → CFBundleVersion
          └────── pazarlama sürümü → CFBundleShortVersionString
```

Build numarası **her yüklemede** artmak zorunda; Apple aynı numarayı ikinci
kez kabul etmiyor, yükleme reddedilse bile o numara harcanmış sayılıyor.
Pazarlama sürümü yalnızca App Store'a yeni sürüm çıkarken artar.

```bash
flutter test && flutter analyze
flutter build ipa --release
open build/ios/archive/Runner.xcarchive   # Distribute App → App Store Connect
```

`docs/` klasörü GitHub Pages ile yayınlanır (`main` dalı, `/docs` klasörü) ve
App Store'un istediği destek ile gizlilik bağlantılarını karşılar. Apple bu
adresleri inceleme sırasında gerçekten açıyor; 404 veren bir gizlilik
bağlantısı red sebebidir.

## Katkı

Issue ve pull request'lere açığız. Kod standardı:

- **Tanımlayıcılar İngilizce** (sınıf, alan, değişken adları), **yorumlar ve dartdoc Türkçe**, kullanıcıya görünen tüm metinler Türkçe. Adların İngilizce olması Dart ekosistemiyle uyum içindir; açıklamaların Türkçe olması, ürünün alan diliyle (ders, konu, net, tekrar) aynı dilde kalmasını sağlar.
- Yorum satırı *ne* yaptığını değil *neden* öyle yapıldığını anlatır; elenen alternatif de yazılır.
- Gerçek belirsizlikler `NOT:` / `TODO:` ile açıkça işaretlenir; sessizce geçilmez.
- `flutter analyze` temiz ve testler yeşil olmadan PR açılmaz.

## Destek

| | |
|---|---|
| Destek sayfası | https://voxyfy.github.io/ritim/destek.html |
| Gizlilik politikası | https://voxyfy.github.io/ritim/gizlilik.html |
| E-posta | haymana.batuhan@gmail.com |

Sayfaların kaynağı `docs/` klasöründedir ve GitHub Pages ile yayınlanır.

## Yol haritası

| Durum | İş |
|---|---|
| ✅ | Uygulama ikonu (iOS + Android) |
| ✅ | Gizlilik, destek ve tanıtım sayfaları (`docs/`) |
| ✅ | App Store metinleri (`docs/app-store.md`) |
| ✅ | App Store ekran görüntüleri (`screenshots/`) |
| ✅ | TestFlight'a ilk yükleme |
| 🔜 | Kapalı test geri bildirimleri |
| 🔜 | App Store incelemesine gönderim |
| 💭 | Yedekleme / dışa aktarma |
| 💭 | Veli için paylaşılabilir haftalık özet |
| 💭 | Odak zamanlayıcısı (pomodoro) |

Bilinçli olarak **yapılmayacaklar**: ses kaydı (aranamayan kayıt geri
dinlenmiyor), görev içi alt görev listesi, sosyal özellikler. Üçü de ürünü
genel amaçlı bir yapılacaklar uygulamasına çevirir; farkımız "konu + tekrar"
ekseninde duruyor.

## Uygulama ikonu

Bir haftanın çalışma ritmi: beş çubuk, yükseklikleri o günün süresi, en yüksek
gün fildişi. Metin yok — 29 pikselde yazı okunmuyor ve iOS zaten uygulama adını
ikonun altında yazıyor.

Aynı motif Bugün ekranındaki haftalık grafikte de var; ikon uygulamanın
içinden bir parça, üstüne yapıştırılmış bir amblem değil.

```bash
python3 tool/generate_app_icon.py   # 19 iOS + 5 Android boyutu
```

**Neden figür değil.** Önce koşan bir figür denendi. Çizgilerle çizilen hâli
acil çıkış tabelasına benziyordu; elle çokgen yazarak düz-vektör kalitesi ise
hiç çıkmadı (üç deneme, üçü de daha kötü). Çubuklar hem uygulamanın adını
doğrudan anlatıyor hem her boyutta ayrık kalıyor.

**Neden hazır çizim değil.** Serbest lisanslı illüstrasyonlar ticari kullanıma
izin veriyor ama **münhasır hak vermiyor**: aynı görseli başka bir uygulama da
kullanabilir ve marka olarak tescil edilemez. İkon, uygulamanın kimliği.

**Neden beş çubuk.** Yedi gün anlamlıydı ama 29 piksellik Ayarlar ikonunda
çubuklar birbirine girip tek bir lekeye dönüşüyordu. Beş çubuk aynı fikri
anlatıyor ve her boyutta okunuyor. Yükseklikler de rastgele değil: eşit
aralıklı simetrik çubuklar ses seviyesi göstergesi gibi okunuyor, düzensiz ama
anlamlı bir dizilim "bir haftanın kaydı" diyor.

## Üçüncü taraf varlıklar

| Varlık | Kaynak | Lisans |
|---|---|---|
| Plus Jakarta Sans | [tokotype/PlusJakartaSans](https://github.com/tokotype/PlusJakartaSans) | SIL OFL 1.1 |
| İllüstrasyonlar | [unDraw](https://undraw.co) — Katerina Limpitsouni | unDraw lisansı (ücretsiz, ticari kullanım serbest) |
| Phosphor Icons | [phosphor-icons](https://phosphoricons.com) | MIT |

Uygulama ikonu bu listede yok: koddan üretiliyor ve tamamen projeye ait.

İllüstrasyonlar indirildikten sonra tek renk ailesine indirildi — kiremit ve
tonları:

```bash
python3 tool/snap_illustration_palette.py
```

Ders renkleri **etikete** ait; kimlik taşırlar. Çizimde kimlik taşıyacak bir şey
yok, orada renk yalnızca derinlik veriyor. Tek aile hem uygulamayla aynı dili
konuşuyor hem de altı çizim birbirinin devamı gibi duruyor.

Betik ayrıca degradeleri düz renge çeviriyor: `flutter_svg` çözemediği bir
degradeyle karşılaşınca **çizimin tamamını** atıyor — ekranda hiçbir şey
görünmüyor, hata yalnızca kayıtlara düşüyor.

## Lisans

Kodun tamamı MIT — ayrıntılar için [LICENSE](LICENSE). Üçüncü taraf varlıklar
kendi lisanslarına tabidir.
