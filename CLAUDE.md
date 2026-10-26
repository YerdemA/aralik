# CLAUDE.md — Kabaca

## Proje
**Kabaca**, 5–10 dakikalık beklemelerde oynanan Türkçe bir günlük tahmin oyunu (Android, Flutter).
Kullanıcı sayısal bir soruya tek bir sayıyla değil, **%90 emin olduğu bir aralıkla** cevap verir
("Ağrı Dağı kaç metre?" → 4.500 – 5.500 m). Aralık cevabı içeriyorsa puan alır. Aralık ne kadar
darsa puan o kadar yüksek olur. Uzun vadede kullanıcının **kalibrasyonunu**, yani "%90 emin"
dediğinde gerçekten %90 isabet edip etmediğini ölçer.

- Geliştirici: Yusuf Erdem Aykaç (GitHub: YerdemA)
- Paket adı: `com.yerdema.aralik` (uygulamanın ilk adından kalma; kullanıcıya görünmez, depo adı ve GitHub Pages adresleri de `aralik`)
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
    settings_store.dart     # ayarlar (tema)
  features/
    intro/                  # soğuk açılışta kısa giriş animasyonu (atlanabilir)
    home/                   # ana ekran: günün seti, seri, kalibrasyon
    game/                   # soru ekranı + tahmin/aralık girişi
    result/                 # soru sonucu + gün özeti + paylaş
    stats/                  # istatistikler, kalibrasyon grafiği
    settings/               # ayarlar → hakkında: veri kaynakları, lisanslar, gizlilik
  widgets/                  # ortak küçük widget'lar
assets/questions/questions.json
assets/questions/schedule.json  # günlük takvim: gün → 5 soru id'si (yalnızca sona eklenir)
assets/data/places.json     # il merkezi + başkent koordinatları (mesafe soruları)
assets/data/attributions.json   # atıf listesi (tools/sources.json'dan üretilir)
tools/                      # Python veri hattı; ham dökümler tools/raw/<kaynak>/ (+ _meta.json)
tools/sources.json          # tüm veri kaynakları: lisans, atıf, durum, veri setleri
docs/                       # PLAN.md, SOURCES.md, privacy-policy.md, attributions.md (GitHub Pages)
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
  "fun_fact": "Türkiye'nin en yüksek noktası.",
  "difficulty": 1,
  "dataset": "mountains_tr"
}
```
- `kind`: `magnitude` (pozitif büyüklük: nüfus, km, m, adet) veya `year` (tarih/yıl).
- Kategoriler: `coğrafya`, `tarih`, `türkiye`, `bilim`, `spor`, `gündelik`, `hayvanlar`, `şirketler`.
  Uygulama bilmediği bir kategoriyi (içerik güncellemesiyle gelen yeni bir kategori) `diğer` altında gösterir. `diğer` bankaya asla yazılmaz.
- Opsiyonel alanlar: `difficulty` (1 kolay, 2 orta, 3 zor; `build_questions.py` okunma sayısı, kategori ve türden tahmin eder, `tools/difficulty_overrides.json` elle düzeltir), `dataset` (veri seti adı; `tools/sources.json` içinde kullanımdaki bir kaynağa bağlı olmalı), `anchor` (`{text, value, unit, source}`, kaynaklı çapa değer; henüz doldurulmuyor).
- `questions.json` yalnızca sona eklenir: id'ler asla silinmez, yer değiştirmez. Hangi sorunun hangi gün geleceğine takvim karar verir.

## Oyun kuralları
- **Günlük set:** Her gün 5 soru. `dayIndex = gün(yerel saat) − 2026-11-01`. Günün soruları `schedule.json` içindeki `days[dayIndex]` id'leridir (`core/daily.dart`, `Schedule`). Herkes aynı gün aynı soruları görür ve backend gerekmez. Takvim biterse başa sarılır, kapalı testteki negatif günler sondan sayılır.
  Takvimi `tools/build_schedule.py` kurar: her gün 2 kolay + 2 orta + 1 zor, en az 3 kategori, aynı veri setinden en fazla 1 soru, kolaydan zora sıralı. Takvim yalnızca sona gün eklenerek uzar.
- **Serbest mod** (eski adıyla pratik modu): Sınırsız, 5'erli turlar. Kişiye özeldir ve oyuncunun daha önce kilitlediği hiçbir soru (hiçbir modda) tekrar gelmez (`StatsStore.seenIds`).
  Banka soruları takvimin önümüzdeki 60 gününde olmayanlardan gelir (geçmiş günler ve takvime girmemiş sorular dahil). Turda her üreticiden en fazla 1, toplamda en fazla 2 üretilmiş soru olur. Banka havuzu biterse tur kısalır.
- **Cihazda üretilen sorular:** Kaynaklı küçük veri tablolarından hesaplanır, sayı asla elle yazılmaz. İlk üretici: il merkezleri / başkentler arası kuş uçuşu mesafe (`data/distance_questions.dart`, id `dist:Q1:Q2`).
  Yeni üreticiler aynı kurala uyar: veri `tools/` ile Wikidata'dan çekilir, `assets/data/` altına gömülür, `source` iki öğenin de linkini içerir.
- **Yeni soru akışı:** Günlük set herkes için aynı kalır (Wordle paylaşımı için). Serbest mod, üreticiler sayesinde tükenmez.
- **İnternetten içerik:** `python tools/publish_content.py` bankayı, takvimi ve yer verisini `docs/content/` altına kopyalar ve `manifest.json` sürümünü artırır. Push edilince GitHub Pages'ten yayınlanır.
  Uygulama en fazla 6 saatte bir manifest'e bakar. Yeni sürümü indirir, üç dosyayı birlikte doğrular ve sonraki açılışta kullanır.
  İndirilen banka ve takvim, uygulamadakilerin birebir devamı olmak zorundadır (aynı id'ler ve günler, aynı sıra), takvimdeki her id bankada bulunmalıdır. Değilse üçü birden reddedilir.
- **Veri kaynakları ve atıf:** Her kaynak `tools/sources.json` içinde lisansı ve atıf satırıyla durur (ayrıntı: `docs/SOURCES.md`). `python tools/build_attributions.py` kullanımdaki kaynakları `assets/data/attributions.json` ve `docs/attributions.md` olarak yazar. Uygulamada Ayarlar → Veri kaynakları ve lisanslar ekranında gösterilir.
- **Giriş akışı:** (1) Kullanıcı en iyi tahminini kendi sayı klavyemizle girer. (2) Bir kaydırıcıyla aralığın genişliğini ayarlar. `magnitude` için kaydırıcı logaritmiktir, `year` için ±yıl olarak çalışır. Ekranda canlı olarak "4.500 – 5.500 m" gösterilir. (3) "Kilitle" butonu.
- **Puan (`scoring.dart`), interval score (α = 0,1):**
  - Ceza `S = genişlik + 20 × (cevabın aralık dışında kalan mesafesi)`. `magnitude` için log2 ekseninde, `year` için yıl cinsinden.
  - Puan `round(100 − k·S)`, −100…100 arasında kırpılır. `magnitude` için k = 10, `year` için k = 1.
  - Bu kural matematiksel olarak dürüst %90 aralığı ödüllendirir. Bilerek dar aralık vermek kazandırmaz. Taban bu yüzden 0 değil, −100'dür: 0 tabanı uzak ıskaları bedava yapar ve dar aralığı yeniden kârlı kılar. Bu özellik `test/core/scoring_test.dart` içinde test edilir.
  - Kıl payı ıska da puan alabilir. Uzak ıska eksi puandır.
  - Günlük maksimum 500.
- **Kalibrasyon:** Tüm zamanlarda isabet eden aralıkların oranı. Hedef ~%90. Ekranda "%62, aralıkların fazla dar" ya da "%100, daha cesur ol" gibi geri bildirim gösterilir.
- **Seri:** Günlük set tamamlanan ardışık günler.
- **Paylaşım:** Gün özetindeki "Paylaş" bir önizleme açar. İki seçenek var: görsel kart (`features/result/share_card.dart`, 1080 × 1920, hikâye/durum için; metin açıklama olarak eklenir) ya da yalnızca metin. Görsel `share_plus` ile bellekten paylaşılır, ek paket yok.
- **Paylaşım metni (Wordle tarzı):**
  ```
  Kabaca #42 · 380/500
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
- Soru bankası üret: `python tools/build_questions.py [--fresh] [--dry-run] [--report]`
- Günlük takvimi üret: `python tools/build_schedule.py [--days N] [--fresh] [--dry-run]`
- Atıf listesini üret: `python tools/build_attributions.py`
- Yer verisini üret: `python tools/build_places.py`
- Bankayı ve takvimi doğrula: `python tools/validate_questions.py`
- İçeriği yayına hazırla: `python tools/publish_content.py [--reset]` (sonra `docs/` commit + push; `--reset` yalnızca ilk oyuncudan önce)
- Uygulama ikonunu üret: `flutter test tools/icon/render_icon_test.dart`
