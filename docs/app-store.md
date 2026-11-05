# App Store listelemesi

Bu dosya App Store Connect'e kopyalanacak metinleri tutar. Karakter sınırları
Apple'ın dayattığı sınırlardır; parantez içindeki sayı mevcut uzunluktur.

## Ad ve alt başlık

**Ad** (en fazla 30) — 20
```
Ritim: Çalışma Planı
```

Telefonun ana ekranında görünen ad bu değil: orası `CFBundleDisplayName`, yani
**Ritim**. Mağaza adına açıklayıcı bir kuyruk eklemek hem benzersizlik şartını
karşılıyor hem aramada bulunurluğu artırıyor.

**Alt başlık** (en fazla 30) — 30
```
Konu takibi ve aralıklı tekrar
```

## Anahtar kelimeler

Virgülle ayrılır, boşluk kullanılmaz (boşluk da karakter sayılıyor). Addaki ve
alt başlıktaki kelimeler zaten indeksleniyor; burada onları tekrarlamak yer
israfı. Bu yüzden liste sınav adları ve eş anlamlılardan oluşuyor.

(en fazla 100) — 99
```
LGS,YKS,TYT,AYT,KPSS,DGS,deneme,net,ders,program,etüt,öğrenci,sınav,tekrar,konu,plan,ödev,ajanda
```

## Tanıtım metni

Sürüm göndermeden değiştirilebilen tek alan. (en fazla 170)
```
Çalıştığın konu 1, 3, 7 ve 21 gün sonra kendiliğinden karşına çıkar. Çok yanlış yaptığın konu daha sık gelir. Hesap yok, reklam yok, verilerin telefonunda kalır.
```

## Açıklama

```
Ritim düz bir yapılacaklar listesi değil. Öğrencinin gerçek birimi görev değil KONU.

Bir konuya çalışırsın, ne kadar süre verdiğini ve kaç soru çözdüğünü kaydedersin. Ritim o konuyu 1-3-7-21 gün merdivenine koyar ve tekrar günü geldiğinde notlarınla birlikte önüne getirir. Çok yanlış yaptığın konu daha sık, iyi bildiğin konu daha seyrek gelir.

HAZIR MÜFREDAT
Kurulumda hedefini seç, dersler ve konular hazır gelsin: 5, 6, 7 ve 8. sınıf (LGS), 9, 10 ve 11. sınıf, TYT, AYT Sayısal / Eşit Ağırlık / Sözel, YDT, KPSS Lisans, MEB-AGS ve DGS. On beş şablon, bin konudan fazla. Hepsi düzenlenebilir; istersen sıfırdan kendin de kurabilirsin.

HAFTALIK PLAN
Hangi günler çalışacağını ve günde kaç konu istediğini söyle. Ritim bitmemiş konuları o günlere dağıtır. Bir güne aynı dersten üç konu düşmez.

DENEME ANALİZİ
Denemenin ders ders doğru ve yanlışlarını gir. Ritim netini hesaplar (LGS, YKS ve yanlışın götürmediği sınavlar için ayrı ayrı) ve en zayıf derslerini çıkarır. Tek dokunuşla o derslere odaklı plan kurar.

NOTLAR VE FOTOĞRAFLAR
Konuya not yaz, kitaptan sayfa ya da çözdüğün soruyu fotoğrafla. Tekrar günü geldiğinde hepsi karşında olur.

HESAP YOK, REKLAM YOK
Kayıt olmuyorsun. Sunucumuz yok. Verilerin telefonundan çıkmıyor.

Ortaokuldan üniversiteye, LGS'den KPSS'ye çalışan herkes için.
```

## Destek ve gizlilik bağlantıları

| Alan | Değer |
|---|---|
| Destek URL'si | `https://voxyfy.github.io/ritim/destek.html` |
| Pazarlama URL'si (isteğe bağlı) | `https://voxyfy.github.io/ritim/` |
| Gizlilik politikası URL'si | `https://voxyfy.github.io/ritim/gizlilik.html` |

Sayfaların kaynağı `docs/` klasöründe: `index.html`, `destek.html`,
`gizlilik.html`.

### Bu bağlantılar niçin böyle

İnceleme sırasında Apple iki URL'yi de gerçekten açıyor. Üç ayrı şart var:

1. **Destek URL'si bir iletişim yolu içermeli.** Kılavuz 1.5, destek
   sayfasında kullanıcının ulaşabileceği bir kanal arıyor. Çıplak bir GitHub
   deposu bunu her zaman karşılamıyor — depoda e-posta görünmez, Issues
   açmak GitHub hesabı ister ve bir öğrenci velisinin oraya yazması
   beklenemez. Bu yüzden e-posta ve SSS içeren ayrı bir destek sayfası var;
   GitHub bağlantısı sayfanın içinde duruyor.
2. **Her iki sayfa da giriş yapmadan açılabilmeli.** GitHub Pages bunu
   sağlıyor, ama depo **herkese açık** olmalı ve Pages ayarı açılmalı.
3. **Gizlilik metni App Privacy anketiyle çelişmemeli.** Ankette "Data Not
   Collected" işaretliyoruz; `gizlilik.html` de hiçbir veri toplanmadığını
   söylüyor. İkisi tutuyor.

### Yayına almadan önce (bu adımlar atlanırsa inceleme reddi gelir)

- [ ] `Voxyfy/ritim` deposu herkese açık olsun.
- [ ] Settings → Pages → Source: `main` dalı, `/docs` klasörü.
- [ ] Yayınlandıktan sonra üç bağlantı da tarayıcıda **gizli sekmede**
      açılarak doğrulansın — özellikle `gizlilik.html`.
- [ ] Bağlantılar açıldığında App Store Connect'e girilsin. Boş ya da 404
      veren bir URL, incelemenin en sık takıldığı yerlerden biri.

## Ekran görüntüleri

`screenshots/` klasöründe, App Store'un istediği ölçülerde hazır. Klasör adı
yükleneceği yuvanın adıyla birebir aynı:

| Klasör | Piksel | Yuva |
|---|---|---|
| `ios-6.9/` | 1320 × 2868 | 6.9" — zorunlu olan tek iPhone yuvası |
| `ios-6.7/` | 1290 × 2796 | 6.7" |
| `ios-6.5/` | 1242 × 2688 | 6.5" |

Yedi kare ve önerilen alt yazılar için `screenshots/README.md`.

Yeniden üretmek için:

```
RITIM_SHOTS=1 flutter test test/screenshot_capture_test.dart --tags screenshots
python3 tool/flatten_screenshots.py
```

İkinci adım atlanamaz: yakalanan PNG'ler alfa kanalı taşıyor ve App Store
Connect saydamlık içeren ekran görüntülerini reddediyor.

## TestFlight metinleri

Mağaza açıklamasından ayrı alanlar. Testçi uygulamayı zaten indirmiş
durumda; buradaki iş onu ikna etmek değil, **ne deneyeceğini** söylemek.

**Beta App Description** (en fazla 4000) — 839
```
Ritim, öğrenciler için konu takibi ve aralıklı tekrar uygulaması. Yapılacaklar listesi değil: birim görev değil KONU.

Bir konuya çalışıp süreni ve çözdüğün soru sayısını kaydediyorsun. Ritim o konuyu 1-3-7-21 gün merdivenine koyuyor ve tekrar günü geldiğinde notlarınla birlikte önüne getiriyor. Çok yanlış yaptığın konu daha sık, iyi bildiğin konu daha seyrek geliyor.

Kurulumda LGS, YKS, KPSS, DGS ve ortaokul-lise sınıfları için 15 hazır müfredattan birini seçebilir ya da kendi derslerini kurabilirsin.

Hesap açman gerekmiyor, internet bağlantısı istemiyor. Bütün veriler telefonunda kalıyor; bu yüzden uygulamayı silersen kayıtların da gider.

Bu ilk sürüm. Kafanı karıştıran, beklediğin yerde bulamadığın ya da yanlış çalıştığını düşündüğün her şeyi yaz — özellikle "burada ne yapmam gerekiyordu?" dediğin anları duymak istiyorum.
```

**What to Test** (en fazla 4000) — 1286
```
Bu sürümde şunları denemenizi rica ediyorum:

1. KURULUM
Uygulamayı ilk açtığında sana uygun şablonu bulabildin mi? Kendi dersini kurmak isteseydin nereye basardın?

2. ÇALIŞMA KAYDI
Bugün sekmesindeki bir işe dokunup çalışma kaydet. Süre ve soru sayısı girmek zorunda hissettin mi, yoksa geçebildin mi? "Bu konuyu bitirdim" seçeneğini fark ettin mi?

3. TEKRARLAR
Bir konuyu çalıştıktan sonra ertesi gün uygulamayı aç. Tekrarın karşına çıktı mı? Yanlış oranını yüksek girdiğin bir konu daha sık geliyor mu?

4. HAFTALIK PLAN
Plan sekmesinden plan kur. Seçtiğin günlere ve günlük konu sayısına uydu mu? Kurduğun planı sonradan görebiliyor musun?

5. DENEME ANALİZİ
Deneme sekmesinden bir deneme gir. Netler doğru hesaplandı mı? "En zayıf dersler" listesi sana mantıklı geldi mi?

6. NOTLAR VE FOTOĞRAFLAR
Bir konuya not ve fotoğraf ekle. Tekrar günü geldiğinde karşına çıkıyor mu?

7. BİLDİRİMLER
İzin verdiysen hatırlatma geldi mi, saati doğru muydu?

ÖZELLİKLE MERAK ETTİKLERİM
- Herhangi bir yerde ne yapman gerektiğini anlamadığın oldu mu?
- Bir yazı ekrandan taştı, bir düğme menünün altında kaldı mı?
- Uygulamayı kapatıp açtığında kaybolan bir şey oldu mu?

BİLİNEN SINIRLAR
- Veriler yalnızca telefonda; yedekleme ve cihaz değiştirme henüz yok.
- Türkçe dışında dil desteği yok.
```

**Beta App Review bilgisi.** Dahili testçiler için gerekmiyor. Harici test
açılırsa iletişim bilgisi ve şu not istenir: uygulama hesap açmıyor, giriş
gerektirmiyor, sunucuya bağlanmıyor — inceleme için demo hesap yok.

## Sürüm gönderme

### Numaralandırma

`pubspec.yaml`'daki tek satır her şeyi belirliyor:

```
version: 1.0.0+2
        └─┬─┘ └┬┘
          │    └── build numarası → CFBundleVersion
          └────── pazarlama sürümü → CFBundleShortVersionString
```

İki kural:

- **Build numarası her yüklemede artmak zorunda.** Apple aynı numarayı ikinci
  kez kabul etmiyor; `1.0.0+2`'yi yükledikten sonra düzeltme yaparsanız
  `1.0.0+3` olur. Bir yükleme reddedilse bile o numara harcanmış sayılır.
- **Pazarlama sürümü yalnızca App Store'a yeni sürüm çıkarken artar.**
  TestFlight'a arka arkaya on build atarken `1.0.0` sabit kalabilir.

### TestFlight'a yeni build (test sürümü)

```
# 1. pubspec.yaml'da build numarasını artır: 1.0.0+2 → 1.0.0+3
# 2. Testler ve statik analiz temiz olsun
flutter test && flutter analyze
# 3. Arşivi üret. RevenueCat anahtarı ŞART: unutulursa uygulama satın alma
#    ekranını hiç göstermez ve herkese ücretsiz açılır.
flutter build ipa --release --dart-define-from-file=config/revenuecat.json
# 4. Organizer'dan yükle
open build/ios/archive/Runner.xcarchive
```

Organizer → Distribute App → App Store Connect → Upload. İşlenmesi bittiğinde
dahili test grubuna atayın; dahili testte Beta App Review yok, anında düşer.

### App Store'a yeni sürüm

1. `pubspec.yaml`'da pazarlama sürümünü artır (`1.0.0+2` → `1.1.0+3`).
2. Yukarıdaki derleme ve yükleme adımlarını uygula.
3. App Store Connect → uygulama → sol üstte **+ Version or Platform** →
   yeni sürüm numarasını gir.
4. **What's New in This Version** alanını doldur (en fazla 4000 karakter).
   Zorunlu ve kullanıcıya görünen tek güncelleme metni bu; "hata düzeltmeleri"
   yazıp geçmek yerine ne değiştiğini yaz.
5. İşlenmesi biten build'i seç, Submit for Review.

İnceleme genellikle bir-iki gün sürüyor. Ekran görüntüleri ve açıklama
değişmediyse yeniden yüklemeye gerek yok, önceki sürümden devralınır.

### Sürüm göndermeden değiştirilebilenler

Bu alanlar inceleme beklemeden anında güncellenir:

- **Promotional Text** (170 karakter)
- Fiyatlandırma ve satış bölgeleri
- App Privacy yanıtları

Açıklama, anahtar kelimeler, ekran görüntüleri ve uygulama adı ise yalnızca
yeni bir sürümle birlikte değişir.

## App Privacy anketi

**Data Not Collected.** Uygulama hiçbir veri toplamıyor, hiçbir ağ isteği
yapmıyor. Ankette tek tek "hayır" işaretlenecek.

## Yaş sınırı

4+ bekleniyor: şiddet, kumar, kullanıcı üretimi içerik paylaşımı, web tarayıcı
ve sosyal özellik yok.

## Bu sürümdeki yenilikler (What's New)

### 1.1.0

```
Ritim yenilendi.

• Dersler artık renkli kartlar hâlinde: her ders kendi renginde, ilerlemesi
  kartın üstünde.
• Plan takvimi yeniden çizildi: planlı günler bir bakışta görünür.
• Daha yumuşak köşeler, daha sakin bir sekme çubuğu.
• Seri sayısı artık ana ekranın başında.

Bir şey ters giderse: haymana.batuhan@gmail.com
```

### 1.0.0

```
İlk sürüm.
```

## Sürüm bilgisi

| Alan | Değer |
|---|---|
| Sürüm | 1.1.0 |
| Telif | 2026 Batuhan Haymana |
| Kategori (birincil) | Eğitim |
| Kategori (ikincil) | Verimlilik |

## 1.2.0 (6) — yeni tasarım, hız güncellemesi, Ritim Pro

### Yenilikler (What's New, TR)

```
Ritim baştan yenilendi: daha hızlı, daha az dokunuş.

• Tek dokunuşla kayıt: işin dairesine dokun, süreyi seç, bitti. Yanlışlıkla mı oldu? "Geri al".
• Odak zamanlayıcısı: Sıradaki işte "Başla" de; bitirince süre kendiliğinden yazılır.
• Akıllı ekleme: "yarın mat türev" yaz, ders, konu ve gün kendiliğinden eşleşsin.
• Hızlı deneme girişi: ekrandaki sayı tuşlarıyla, klavye açmadan.
• Konuyu sağa kaydırarak bitir, uzun basarak toplu seç.
• Yeni görünüm: hafta şeridi ve ders renginde zaman çizgisi.
• Ritim Pro: 7 gün ücretsiz dene, sonra haftalık, aylık ya da yıllık plan seç.
```

### İncelemeci notu (App Review Information → Notes, EN)

```
Ritim is a study planner for Turkish students. No account, no server: all study data stays on the device.

Subscriptions (new in 1.2): "Ritim Pro" auto-renewable group with weekly, monthly and yearly plans.
- Every user gets a 7-day free period handled inside the app (no payment method required, not an App Store introductory offer). The countdown starts the first time 1.2 is opened.
- During those 7 days everything is available; Settings → Abonelik → Ritim Pro shows the days left and opens the purchase screen.
- After the 7 days the app shows the purchase screen until a plan is purchased or restored. The screen shows each plan's billed price, auto-renewal terms, Restore Purchases, Terms of Use (Apple standard EULA) and Privacy Policy links.
- To reach the purchase screen during review: Settings tab (gear icon) → Abonelik → Ritim Pro.
- Purchases are processed by Apple; subscription status is verified with RevenueCat using a random anonymous app user ID. No personal data is collected.

Notifications are local only. The camera/photo permission is requested only when the user attaches a photo to a topic.
```

### Gönderim adımları

1. `flutter build ipa --release --dart-define-from-file=config/revenuecat.json`
2. Organizer → Distribute App → App Store Connect → Upload.
3. TestFlight'ta sandbox hesabıyla üç planı da satın al / geri yükle dene.
4. App Store Connect → yeni sürüm 1.2.0 → build 6'yı seç → "In-App Purchases and Subscriptions" bölümünden üç aboneliği ekle → her aboneliğe `review-assets/paywall.png` inceleme görselini yükle.
5. App Privacy: Purchases (Purchase History) + Identifiers (Device ID) — "not linked to user", "not used for tracking", amaç App Functionality.
