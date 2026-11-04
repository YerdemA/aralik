# CLAUDE.md — Kabaca

## Proje
**Kabaca**, 5–10 dakikalık beklemelerde oynanan Türkçe bir günlük tahmin oyunu (Android, Flutter).
Kullanıcı sayısal bir soruya tek bir sayıyla değil, **%90 emin olduğu bir aralıkla** cevap verir
("Ağrı Dağı kaç metre?" → 4.500 – 5.500 m). Aralık cevabı içeriyorsa puan alır. Aralık ne kadar
darsa puan o kadar yüksek olur. Uzun vadede kullanıcının **kalibrasyonunu**, yani "%90 emin"
dediğinde gerçekten %90 isabet edip etmediğini ölçer.

- Geliştirici: Yusuf Erdem Aykaç (GitHub: YerdemA)
- Paket adı: `com.yerdema.kabaca`. Depo adı, GitHub Pages adresleri ve Dart paket adı (`package:aralik/...`) uygulamanın ilk adından kalma `aralik`; kullanıcıya görünmezler.
- Hedef: Google Play, Android (minSdk 24, Flutter 3.47'nin desteklediği en düşük sürüm)
- Ayrıntılı yol haritası: `docs/PLAN.md`

## Temel ilkeler (her kararda bunlara uy)
1. **Sıfır bütçe, neredeyse sıfır backend.** Firebase, reklam SDK'sı, analytics yok. Uygulama internetsiz de eksiksiz çalışır.
   Yeni sorular, uygulama güncellemesi gerekmeden GitHub Pages'teki statik dosyalardan indirilir (`data/content_sync.dart`).
   Tek sunucu, **isteğe bağlı** günün liderleri tablosudur (`server/leaderboard/`, Cloudflare Workers + D1 ücretsiz katman). Katılmayan oyuncudan hiçbir veri gönderilmez. Katılandan yalnızca takma ad, rastgele kimlik ve günlük setin aralıkları gider. Başka bir sunucu ya da veri toplama eklenmez.
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
- Kategoriler: `coğrafya`, `tarih`, `türkiye`, `bilim`, `spor`, `gündelik`, `hayvanlar`, `şirketler`, `osmanlı`, `mimari`, `sanat`.
  Uygulama bilmediği bir kategoriyi (içerik güncellemesiyle gelen yeni bir kategori) `diğer` altında gösterir. `diğer` bankaya asla yazılmaz.
- Opsiyonel alanlar: `difficulty` (1 kolay, 2 orta, 3 zor; `build_questions.py` okunma sayısı, kategori ve türden tahmin eder, `tools/difficulty_overrides.json` elle düzeltir), `dataset` (veri seti adı; `tools/sources.json` içinde kullanımdaki bir kaynağa bağlı olmalı), `anchor` (`{text, value, unit, source}`, kaynaklı çapa değer; henüz doldurulmuyor).
- `questions.json` yalnızca sona eklenir: id'ler asla silinmez, yer değiştirmez. Hangi sorunun hangi gün geleceğine takvim karar verir.

## Oyun kuralları
- **Günlük set:** Her gün 5 soru. `dayIndex = gün(yerel saat) − 2026-11-01`. Günün soruları `schedule.json` içindeki `days[dayIndex]` id'leridir (`core/daily.dart`, `Schedule`). Herkes aynı gün aynı soruları görür ve backend gerekmez. Takvim biterse başa sarılır, kapalı testteki negatif günler sondan sayılır.
  Takvimi `tools/build_schedule.py` kurar: her gün 2 kolay + 2 orta + 1 zor, en az 3 kategori, aynı veri setinden en fazla 1 soru, kolaydan zora sıralı. Takvim yalnızca sona gün eklenerek uzar.
- **Serbest mod** (arayüzde "Bir tur at", eski adıyla pratik modu): Sınırsız, 5'erli turlar. Kişiye özeldir ve oyuncunun daha önce kilitlediği hiçbir soru (hiçbir modda) tekrar gelmez (`StatsStore.seenIds`).
  Banka soruları takvimin önümüzdeki 60 gününde olmayanlardan gelir (geçmiş günler ve takvime girmemiş sorular dahil). Turda her üreticiden en fazla 1, toplamda en fazla 2 üretilmiş soru olur. Banka havuzu biterse tur kısalır.
- **Cihazda üretilen sorular:** Kaynaklı küçük veri tablolarından hesaplanır, sayı asla elle yazılmaz. İlk üretici: il merkezleri / başkentler arası kuş uçuşu mesafe (`data/distance_questions.dart`, id `dist:Q1:Q2`).
  Yeni üreticiler aynı kurala uyar: veri `tools/` ile Wikidata'dan çekilir, `assets/data/` altına gömülür, `source` iki öğenin de linkini içerir.
- **Yeni soru akışı:** Günlük set herkes için aynı kalır (Wordle paylaşımı için). Serbest mod, üreticiler sayesinde tükenmez.
- **İnternetten içerik:** `python tools/publish_content.py` bankayı, takvimi ve yer verisini `docs/content/` altına kopyalar ve `manifest.json` sürümünü artırır. Push edilince GitHub Pages'ten yayınlanır.
  Uygulama en fazla 6 saatte bir manifest'e bakar. Yeni sürümü indirir, üç dosyayı birlikte doğrular ve sonraki açılışta kullanır.
  İndirilen banka ve takvim, uygulamadakilerin birebir devamı olmak zorundadır (aynı id'ler ve günler, aynı sıra), takvimdeki her id bankada bulunmalıdır. Değilse üçü birden reddedilir.
- **Veri kaynakları ve atıf:** Her kaynak `tools/sources.json` içinde lisansı ve atıf satırıyla durur (ayrıntı: `docs/SOURCES.md`). `python tools/build_attributions.py` kullanımdaki kaynakları `assets/data/attributions.json` ve `docs/attributions.md` olarak yazar. Uygulamada Ayarlar → Veri kaynakları ve lisanslar ekranında gösterilir.
- **Giriş akışı:** (1) Kullanıcı en iyi tahminini kendi sayı klavyemizle girer. (2) Bir kaydırıcıyla aralığın genişliğini ayarlar. `magnitude` için kaydırıcı logaritmiktir, `year` için ±yıl olarak çalışır. Ekranda canlı olarak "4.500 – 5.500 m" gösterilir. (3) "Kilitle" butonu.
- **Süre sınırı (yalnızca günlük set):** Soru başına 15 sn (`core/question_timer.dart`, `dailyTimeLimit`), soru ilk göründüğü andan başlar. Başlangıç anı kaydedilir (`StatsStore.startDailyQuestion`), çıkıp geri gelmek süreyi sıfırlamaz.
  Süre dolunca ekrandaki aralık (ya da yazılı tahmin varsayılan genişlikle) kendiliğinden kilitlenir. Hiç tahmin yoksa soru taban puanı (−50) alır ve ⬛ olur, kalibrasyona sayılmaz. Taban puan, süreyi bilerek doldurmanın hiçbir cevaptan kârlı olmamasını sağlar. Serbest modda süre yoktur.
- **Puan (`scoring.dart`), interval score (α = 0,1):**
  - Ceza `S = genişlik + 20 × (cevabın aralık dışında kalan mesafesi)`. `magnitude` için log2 ekseninde, `year` için yıl cinsinden.
  - Puan `round(100 − k·S)`, −50…100 arasında kırpılır. `magnitude` için k = 10, `year` için k = 1.
  - Bu kural matematiksel olarak dürüst %90 aralığı ödüllendirir. Bilerek dar aralık vermek kazandırmaz. Taban bu yüzden 0 değil, −50'dir: 0 tabanı uzak ıskaları bedava yapar ve dar aralığı yeniden kârlı kılar. (Taban 2026-11-04'te, turlar çok sık eksiyle bittiği için −100'den −50'ye çekildi. Bedeli: ×2,8 belirsizlikte en kârlı aralık %86 yerine ~%82'yi kapsar.) Bu özellik `test/core/scoring_test.dart` içinde test edilir. Taban değişirse `server/leaderboard/src/scoring.js` de değişir.
  - Kıl payı ıska da puan alabilir. Uzak ıska eksi puandır.
  - Günlük maksimum 500.
- **Kalibrasyon:** Tüm zamanlarda isabet eden aralıkların oranı. Hedef ~%90. Ekranda "%62, aralıkların fazla dar" ya da "%100, daha cesur ol" gibi geri bildirim gösterilir.
- **Seri:** Günlük set tamamlanan ardışık günler.
- **Günün liderleri (isteğe bağlı):** Giriş yok. Oyuncu bir takma adla katılır (3–16 karakter, benzersiz, sunucuda kelime filtresi; kural `core/nickname.dart` ve `server/leaderboard/src/nickname.js`). Uygulama rastgele kimlik ve gizli anahtarı saklar (`data/leaderboard.dart`).
  Günlük setin 5 aralığı (katılmadan da) cihazda tutulur. Set bitince ve oyuncu katılmışsa gönderilir. Puanı sunucu, yayınlanmış banka ve takvimden **kendisi hesaplar** (`src/scoring.js`, `scoring.dart` ile aynı: `server/leaderboard/test/scoring_vectors.json` iki tarafta da test edilir; formül değişirse ikisi birlikte değişir).
  Her günün ayrı tablosu vardır, yeni sorularla tablo sıfırlanır. Gönderim yalnızca dün, bugün ve yarın için kabul edilir (Türkiye saati). Eşitlikte önce gönderen öndedir. Toplam oyuncu `FULL_BOARD_AT` (100) olana kadar ilk 10, sonra ilk 50 gösterilir (`wrangler.toml`).
  Sunucu adresi uygulamaya gömülü değildir: manifest'teki `leaderboard` alanından okunur (`python tools/publish_content.py --leaderboard URL`). Adres yoksa liderlik arayüzü görünmez.
- **Paylaşım:** Gün özetindeki "Paylaş" bir önizleme açar. İki seçenek var: görsel kart (`features/result/share_card.dart`, 1080 × 1920, hikâye/durum için; metin açıklama olarak eklenir) ya da yalnızca metin. Görsel `share_plus` ile bellekten paylaşılır, ek paket yok.
  Kart ana ekranın temasındadır (indigo, güneş sarısı, krem panel). Filozof günün toplamına göre 5 ruh hâlinden birindedir (`core/day_mood.dart`, çizim `widgets/philosopher.dart`): ≥450 efsane (kahkaha, kaslar), ≥350 harika (zafer yumruğu), ≥200 fena değil (göğüs kabarık, bıyık altından gülüş), ≥0 idare eder (kafa kaşıma, ter), <0 olmadı (yağmur bulutu). Ruh hâli olmadan çizilen düşünen filozof uygulama ikonudur, değişmez.
  Kartları gözle kontrol etmek için: `flutter test tools/share/render_share_cards_test.dart` (çıktı `build/share_cards/`).
- **Gün adı:** Günler numarayla değil tarihle anılır: paylaşımda ve tabloda "4 Kasım", ana ekranda "4 Kasım Çarşamba" (`dayLabel`, `dateOfDay`).
- **Paylaşım metni (Wordle tarzı):**
  ```
  Kabaca · 4 Kasım · 380/500
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

## Komutlar
- Wikidata ham verisini çek: `python tools/fetch_wikidata.py [veri_seti ...]`
- Soru bankası üret: `python tools/build_questions.py [--fresh] [--dry-run] [--report]`
- Elle seçilmiş soruları Vikipedi'den doğrulayıp ekle: `python tools/import_curated.py [--dry-run] [--report DOSYA]` (liste: `tools/curated/selection.txt`; `build_questions.py --fresh` bu soruları siler)
- Günlük takvimi üret: `python tools/build_schedule.py [--days N] [--fresh] [--dry-run]`
- Atıf listesini üret: `python tools/build_attributions.py`
- Yer verisini üret: `python tools/build_places.py`
- Bankayı ve takvimi doğrula: `python tools/validate_questions.py`
- Liderlik sunucusu testleri: `cd server/leaderboard; npm test` (Node 22.5+). Yayın: `npm run deploy` (ayrıntı: `server/leaderboard/README.md`)
- İçeriği yayına hazırla: `python tools/publish_content.py [--reset] [--leaderboard URL]` (sonra `docs/` commit + push; `--reset` yalnızca ilk oyuncudan önce)
- Uygulama ikonunu üret: `flutter test tools/icon/render_icon_test.dart`
- Mağaza görsellerini üret: `flutter test tools/store/render_store_test.dart` (`play-store/screenshots/` içindeki ham ekran görüntülerinden)
