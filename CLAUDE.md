# CLAUDE.md — Aralık

## Proje
**Aralık**, 5–10 dakikalık beklemelerde oynanan Türkçe bir günlük tahmin oyunu (Android, Flutter).
Kullanıcı sayısal bir soruya tek bir sayıyla değil, **%90 emin olduğu bir aralıkla** cevap verir
("Ağrı Dağı kaç metre?" → 4.500 – 5.500 m). Aralık cevabı içeriyorsa puan alır. Aralık ne kadar
darsa puan o kadar yüksek olur. Uzun vadede kullanıcının **kalibrasyonunu**, yani "%90 emin"
dediğinde gerçekten %90 isabet edip etmediğini ölçer.

- Geliştirici: Yusuf Erdem Aykaç (GitHub: YerdemA)
- Paket adı: `com.yerdema.aralik`
- Hedef: Google Play, Android (minSdk 24, Flutter 3.47'nin desteklediği en düşük sürüm)
- Ayrıntılı yol haritası: `docs/PLAN.md`

## Temel ilkeler (her kararda bunlara uy)
1. **Sıfır bütçe, sıfır backend.** Sunucu, Firebase, reklam SDK'sı, analytics yok. Uygulama internetsiz de eksiksiz çalışır.
   Yeni sorular, uygulama güncellemesi gerekmeden GitHub Pages'teki statik dosyalardan indirilir (`data/content_sync.dart`). Hiçbir kişisel veri gönderilmez.
2. **Küçük boyut.** Hedef: Play indirme boyutu < 8 MB. Yeni bir paket eklemeden önce gerekçesini yaz ve bana sor.
3. **Net arayüz.** Her ekranda tek bir ana eylem olur. Büyük dokunma alanları kullan. Metin kısa olsun. Animasyonlar hafif tutulur (implicit animations).
4. **Hız.** Soğuk açılış < 1 sn hissi. Soru bankası lazy değil ama tek seferde parse edilir ve cache'lenir.
5. **Veri doğruluğu.** Her sorunun cevabı kaynaklıdır (`source` alanı zorunlu). Asla sayı uydurma.

## Teknoloji yığını
- Flutter 3.47 (stable), Dart 3.13, Material 3
- State: Flutter'ın yerleşik `ChangeNotifier` / `ValueNotifier` yapıları. Riverpod, Bloc veya GetX kullanılmaz.
- Navigasyon: `Navigator` 2.0 değil, basit `Navigator.push` / named routes yeterli.
- İzinli paketler:
  - `shared_preferences`: seri, istatistik, ayarlar, görülen sorular (eklendi)
  - `share_plus`: skor kartını metin olarak paylaşma
  - `flutter_local_notifications`: günlük hatırlatma (Faz 2)
- Kullanılmayacaklar: `google_fonts` (çalışma anında indirir), `intl` (sayı biçimlendirme için kendi yardımcımız var), görsel/Lottie asset'leri, ikon paketleri (Material Icons yeterli).
- Font: sistem fontu (Roboto). Gerekirse tek bir font, Latin+Türkçe subset olarak eklenir.
- Veri üretimi: `tools/` altında Python 3 scriptleri (uygulamaya dahil edilmez).

## Klasör yapısı
```
lib/
  main.dart
  app.dart                  # MaterialApp, tema, route'lar
  core/
    theme.dart              # renkler, tipografi (açık/koyu tema)
    strings.dart            # TÜM Türkçe arayüz metinleri burada
    number_format.dart      # Türkçe sayı biçimi: 1.234.567 / 3,5
    scoring.dart            # puanlama formülleri (saf fonksiyonlar)
    daily.dart              # günün indeksi ve günlük set seçimi
  data/
    question.dart           # model + fromJson
    question_repository.dart
    stats_store.dart        # shared_preferences sarmalayıcısı
  features/
    home/                   # ana ekran: günün seti, seri, kalibrasyon
    game/                   # soru ekranı + tahmin/aralık girişi
    result/                 # soru sonucu + gün özeti + paylaş
    practice/               # serbest mod (kişiye özel, tekrar etmeyen)
    stats/                  # istatistikler, kalibrasyon grafiği
    settings/
  widgets/                  # ortak küçük widget'lar
assets/questions/questions.json
assets/data/places.json     # il merkezi + başkent koordinatları (mesafe soruları)
tools/                      # Python veri hattı (Wikidata, TÜİK CSV)
docs/                       # PLAN.md, privacy-policy.md (GitHub Pages)
test/
```

## Soru veri formatı
```json
{
  "id": "q0142",
  "text": "Ağrı Dağı kaç metre yüksekliktedir?",
  "answer": 5137,
  "unit": "m",
  "kind": "magnitude",
  "category": "coğrafya",
  "source": "https://www.wikidata.org/wiki/Q93323",
  "data_year": 2024,
  "fun_fact": "Türkiye'nin en yüksek noktası."
}
```
- `kind`: `magnitude` (pozitif büyüklük: nüfus, km, m, adet) veya `year` (tarih/yıl).
- Kategoriler: `coğrafya`, `tarih`, `türkiye`, `bilim`, `spor`, `gündelik`.
- `questions.json` build zamanında **sabit seed ile karıştırılmış** sırada tutulur. Sıra değiştirilmez, yeni sorular sona eklenir.

## Oyun kuralları
- **Günlük set:** Her gün 5 soru. `dayIndex = gün(yerel saat) − 2026-11-01`. Günün soruları `questions[5*dayIndex .. 5*dayIndex+4]` olur. Herkes aynı gün aynı soruları görür ve backend gerekmez. Banka biterse başa sarılır.
- **Serbest mod** (eski adıyla pratik modu): Sınırsız, 5'erli turlar. Kişiye özeldir ve oyuncunun daha önce kilitlediği hiçbir soru (hiçbir modda) tekrar gelmez (`StatsStore.seenIds`).
  Soruların ~1/3'ü **geçmiş günlerin** banka sorularından gelir (gelecek günler spoil olmaz), kalanı cihazda üretilir. Bir şehir bir turda en fazla bir kez geçer.
- **Cihazda üretilen sorular:** Kaynaklı küçük veri tablolarından hesaplanır, sayı asla elle yazılmaz. İlk üretici: il merkezleri / başkentler arası kuş uçuşu mesafe (`data/distance_questions.dart`, id `dist:Q1:Q2`).
  Yeni üreticiler aynı kurala uyar: veri `tools/` ile Wikidata'dan çekilir, `assets/data/` altına gömülür, `source` iki öğenin de linkini içerir.
- **Yeni soru akışı:** Günlük set herkes için aynı kalır (Wordle paylaşımı için). Serbest mod, üreticiler sayesinde tükenmez.
- **İnternetten içerik:** `python tools/publish_content.py` bankayı ve yer verisini `docs/content/` altına kopyalar ve `manifest.json` sürümünü artırır. Push edilince GitHub Pages'ten yayınlanır.
  Uygulama en fazla 6 saatte bir manifest'e bakar. Yeni sürümü indirir, doğrular ve sonraki açılışta kullanır.
  İndirilen banka, uygulamadaki bankanın birebir devamı olmak zorundadır (aynı id'ler, aynı sıra). Değilse reddedilir. Bu yüzden sorular yalnızca sona eklenir, asla silinmez veya yer değiştirmez.
- **Giriş akışı:** (1) Kullanıcı en iyi tahminini kendi sayı klavyemizle girer. (2) Bir kaydırıcıyla aralığın genişliğini ayarlar. `magnitude` için kaydırıcı logaritmiktir, `year` için ±yıl olarak çalışır. Ekranda canlı olarak "4.500 – 5.500 m" gösterilir. (3) "Kilitle" butonu.
- **Puan (`scoring.dart`), interval score (α = 0,1):**
  - Ceza `S = genişlik + 20 × (cevabın aralık dışında kalan mesafesi)`. `magnitude` için log2 ekseninde, `year` için yıl cinsinden.
  - Puan `round(100 − k·S)`, −100…100 arasında kırpılır. `magnitude` için k = 10, `year` için k = 1.
  - Bu kural matematiksel olarak dürüst %90 aralığı ödüllendirir. Bilerek dar aralık vermek kazandırmaz. Taban bu yüzden 0 değil, −100'dür: 0 tabanı uzak ıskaları bedava yapar ve dar aralığı yeniden kârlı kılar. Bu özellik `test/core/scoring_test.dart` içinde test edilir.
  - Kıl payı ıska da puan alabilir. Uzak ıska eksi puandır.
  - Günlük maksimum 500.
- **Kalibrasyon:** Tüm zamanlarda isabet eden aralıkların oranı. Hedef ~%90. Ekranda "%62, aralıkların fazla dar" ya da "%100, daha cesur ol" gibi geri bildirim gösterilir.
- **Seri:** Günlük set tamamlanan ardışık günler.
- **Paylaşım metni (Wordle tarzı):**
  ```
  Aralık #42 · 380/500
  🟩🟩🟨⬛🟩
  Kalibrasyon %80
  ```
  🟩 isabet ve ≥70 puan, 🟨 isabet ve <70 puan, ⬛ ıska (puanı ne olursa olsun).

## Kod kuralları
- Kod, değişken ve dosya adları İngilizce. Kullanıcıya görünen her metin Türkçe ve `core/strings.dart` içinde olur.
- Widget'lar küçük ve `const` olmalı. Gereksiz rebuild'lerden kaçın.
- İş mantığı (puanlama, günlük seçim, sayı biçimi) saf Dart fonksiyonlarıdır ve **unit test zorunludur**.
- `flutter analyze` sıfır uyarı vermeli. Commit öncesi `dart format .` çalıştır.
- Bir görev bitince kısa özet ver ve bir sonraki adımı öner. Büyük mimari değişiklik öncesi onay iste.
- Ortam: Windows 11, PowerShell. Komutları buna göre yaz.

## Release yapılandırması
- `android/app/build.gradle.kts` (Kotlin DSL): `isMinifyEnabled = true`, `isShrinkResources = true`.
- INTERNET izni ana manifest'tedir. Yalnızca içerik güncellemesi için kullanılır.
- Build: `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`
- Uygulama ikonu: `tools/icon/render_icon_test.dart` Flutter'ın kendi çizim motoruyla üretir (paket yok). Uyarlanabilir, yuvarlak ve tek renkli (Android 13) sürümleri vardır. Play ikonu `docs/store/icon-512.png`.
- Gizlilik politikası: `docs/privacy-policy.md`, GitHub Pages ile yayınlanır. Özü: kişisel veri toplanmaz, oyun verileri cihazda kalır, yalnızca soru güncellemeleri GitHub Pages'ten indirilir.

## Komutlar
- Çalıştır: `flutter run`
- Test: `flutter test`
- Analiz: `flutter analyze`
- Wikidata ham verisini çek: `python tools/fetch_wikidata.py [veri_seti ...]`
- Soru bankası üret: `python tools/build_questions.py`
- Yer verisini üret: `python tools/build_places.py`
- Soru bankasını doğrula: `python tools/validate_questions.py`
- İçeriği yayına hazırla: `python tools/publish_content.py` (sonra `docs/` commit + push)
- Uygulama ikonunu üret: `flutter test tools/icon/render_icon_test.dart`
