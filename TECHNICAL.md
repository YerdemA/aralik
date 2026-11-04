# Kabaca: Teknik Belge

Bu belge uygulamanın nasıl kurulduğunu, hangi teknolojilerin neden seçildiğini ve geliştirme sırasında
karşılaşılan sorunların nasıl çözüldüğünü anlatır. Oyunun ne olduğu için [README.md](README.md),
yol haritası ve açık konular için [docs/PLAN.md](docs/PLAN.md) belgesine bak.

*Son güncelleme: 2026-11-04*

## 1. Tasarım ilkeleri
Her teknik karar şu beş ilkeye göre verildi:

1. **Sıfır bütçe, neredeyse sıfır backend.** Firebase, reklam SDK'sı ve analytics yok. Ağ trafiği iki tanedir: GitHub Pages'teki statik içerik dosyalarının indirilmesi ve isteğe bağlı günün liderleri tablosu (Cloudflare Workers + D1 ücretsiz katman, bkz. 7b. bölüm). Tabloya katılmayan oyuncudan hiçbir veri gönderilmez.
2. **Küçük boyut.** Hedef: Play indirme boyutu < 8 MB. Her yeni paket gerekçelendirilir.
3. **Net arayüz.** Her ekranda tek bir ana eylem, büyük dokunma alanları, hafif implicit animasyonlar.
4. **Hız.** Soğuk açılışta < 1 sn hissi. Banka tek seferde parse edilir ve bellekte tutulur.
5. **Veri doğruluğu.** Her cevabın kaynağı vardır. Sayı asla elle yazılmaz ya da uydurulmaz.

## 2. Teknoloji yığını
| Katman | Seçim | Not |
|---|---|---|
| Çatı | Flutter 3.47 (stable), Dart 3.13 | Material 3 |
| Platform | Android, minSdk 24 | Flutter 3.47'nin desteklediği en düşük sürüm |
| Durum yönetimi | `ChangeNotifier`, `ListenableBuilder` | Riverpod, Bloc veya GetX yok. Uygulama küçük, yerleşik yapılar yetiyor. |
| Navigasyon | `Navigator.push` | Navigator 2.0 gereksiz |
| Kalıcı veri | `shared_preferences` | İstatistik, seri, görülen sorular, indirilen içerik |
| Paylaşım | `share_plus` | Skor kartı düz metin olarak paylaşılır |
| HTTP | `dart:io` `HttpClient` | Paket yok (içerik indirme ve liderlik isteği) |
| Liderlik sunucusu | Cloudflare Workers + D1 (SQLite) | `server/leaderboard/`, JavaScript, ek çalışma zamanı paketi yok |
| Sayı biçimi | Kendi yardımcımız (`core/number_format.dart`) | `intl` yok |
| Yazı tipi | Sistem fontu (Roboto) | `google_fonts` yok, çünkü çalışma anında indirir |
| İkonlar | Material Icons | İkon paketi yok |
| Grafik ve çizimler | `CustomPaint` | Görsel, Lottie ya da grafik paketi yok |
| Veri hattı | Python 3, yalnızca standart kütüphane | `tools/`, uygulamaya dahil değil |

### Bağımlılıklar
```yaml
dependencies:
  share_plus          # skor kartını paylaşma
  shared_preferences  # cihazdaki tüm oyun verisi
dev_dependencies:
  flutter_test
  flutter_lints
```
İzinli ama henüz eklenmemiş paket: `flutter_local_notifications` (Faz 2, günlük hatırlatma).

**Bilerek kullanılmayanlar:**
- `intl`: Türkçe ayraçlar (`1.234.567`, `3,5`) ve "milyon/milyar" ölçek kelimeleri için ~100 satırlık saf fonksiyon yeterli.
- `google_fonts`: font dosyasını çalışma anında indirir. Bu hem çevrimdışı ilkesini hem de gizlilik ilkesini bozar.
- `http`: birkaç GET ve JSON POST isteği için `HttpClient` yeterli.
- Grafik kütüphaneleri: kalibrasyon grafiği ve aralık çubuğu birkaç düzine satırlık `CustomPaint` ile çiziliyor.

## 3. Mimari
```
lib/
  main.dart                 # prefs, depo ve içerik senkronunu kurar, runApp
  app.dart                  # MaterialApp, açık/koyu tema
  core/                     # Flutter'a bağımlı olmayan saf iş mantığı (hepsi birim testli)
    scoring.dart            # interval score, puan, sonuç kademesi, kalibrasyon geri bildirimi
    interval.dart           # kaydırıcı konumu → aralık sınırları
    question_timer.dart     # günlük sorunun süre sınırı (15 sn) ve kalan süre
    daily.dart              # gün indeksi, gün → tarih, takvim (Schedule), seri
    day_mood.dart           # günün toplamından paylaşım kartındaki ruh hâli (5 bant)
    nickname.dart           # liderlik takma adı kuralları
    free_play.dart          # serbest mod turu oluşturma
    stats.dart              # istatistik hesapları (blok isabet, kategori, ıska yönü)
    number_format.dart      # Türkçe sayı biçimi
    share_text.dart         # Wordle tarzı paylaşım metni (görsel kart: features/result/share_card.dart)
    geo.dart                # haversine mesafe
    theme.dart              # Palette, tema, GameColors, kategori renk ve ikonları
    strings.dart            # kullanıcıya görünen tüm Türkçe metinler
  data/
    question.dart           # Question modeli + fromJson doğrulaması
    question_repository.dart# banka, takvim ve yer verisinin tek seferlik yüklenmesi, önbellek
    attributions.dart       # atıf listesi (assets/data/attributions.json)
    content_sync.dart       # GitHub Pages'ten içerik güncellemesi ve liderlik sunucusu adresi
    leaderboard.dart        # liderlik istemcisi ve deposu (hesap, bekleyen gönderimler)
    stats_store.dart        # shared_preferences sarmalayıcısı (ChangeNotifier)
    settings_store.dart     # ayarlar (tema), shared_preferences
    distance_questions.dart # cihazda mesafe sorusu üreticisi
    place.dart              # yer modeli
  features/                 # ekranlar: intro, home, game (+ GameController), result, leaderboard, stats, settings
  widgets/                  # ortak parçalar (sayı klavyesi, aralık çubuğu, kategori etiketi, filozof maskotu, ...)
```
- **Katmanlar:** `core` saf Dart'tır ve Flutter widget'larını bilmez. Böylece iş mantığı hızlı birim testleriyle doğrulanır. `data` kalıcılık ve G/Ç işlerini yapar. `features` yalnızca bunları çağırır ve çizer.
- **Metinler:** Kod, değişken ve dosya adları İngilizcedir. Kullanıcıya görünen her metin `core/strings.dart` içindedir.

## 4. Veri modeli
`assets/questions/questions.json`:
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
- `kind`: `magnitude` (pozitif büyüklük) veya `year` (yıl, MÖ için negatif).
- Kategoriler: `coğrafya`, `tarih`, `türkiye`, `bilim`, `spor`, `gündelik`, `hayvanlar`, `şirketler`, `osmanlı`, `mimari`, `sanat`.
- Opsiyonel alanlar:
  - `difficulty`: 1 kolay, 2 orta, 3 zor (bkz. 7. bölüm).
  - `dataset`: sorunun geldiği veri seti. `tools/sources.json` içinde kullanımdaki bir kaynağa bağlı olmalıdır, böylece her sorunun atfı uygulamada görünür.
  - `anchor`: `{text, value, unit, source}`, oyuncuya ölçek veren kaynaklı bir çapa değer. Model ve doğrulama hazır, henüz doldurulmuyor ve gösterilmiyor.
- `Question.fromJson` alan tiplerini, bilinen `kind` değerini, büyüklüğün pozitif ve yılın tam sayı olduğunu denetler.
- **Bilinmeyen kategori:** Uygulama tanımadığı bir kategoriyi reddetmez, `diğer` (`QuestionCategory.other`) altında gösterir. Böylece içerik güncellemesiyle yeni bir kategori eklendiğinde eski sürümdeki oyuncular yeni soruları kaybetmez. `diğer` bankaya asla yazılmaz, doğrulayıcı bunu reddeder. Bilinmeyen bir `kind` ise kurtarılamaz, çünkü puanlama türe bağlıdır.
- Mevcut banka 1001 sorudan oluşur: 282 büyüklük, 719 yıl. Kategorilere göre tarih 269, coğrafya 150, osmanlı 132, türkiye 120, mimari 91, sanat 55, spor 51, bilim 49, şirketler 41, hayvanlar 29, gündelik 14.

`assets/questions/schedule.json`: günlük takvim, `{"days": [[5 id], ...]}`. Dizideki sıra gün indeksidir.

`assets/data/places.json`: 79 Türkiye il merkezi ve 40 dünya başkentinin Wikidata kimliği, adı ve koordinatı. Mesafe soruları bu tablodan üretilir.

## 5. Oyun mantığı

### 5.1 Günlük set
- `dayIndex = yerel takvim günü − 2026-11-01`. Gün farkı UTC takvim tarihleri üzerinden hesaplanır, böylece yaz saati geçişleri ve günün saati sonucu etkilemez.
- Günün soruları takvimdeki `days[dayIndex]` id'leridir (`Schedule.idsFor`). Takvim bitince başa sarılır, kapalı testteki negatif günler sondan sayılır.
- Takvim bankanın sırasından bağımsızdır. Bu sayede günler zorluk ve kategoriye göre dengelenebilir. `tools/build_schedule.py` her gün için şunları uygular:
  - 2 kolay + 2 orta + 1 zor soru, oyunda kolaydan zora sıralı
  - en az 3 kategori
  - aynı veri setinden en fazla 1 soru
  - aynı öğe hakkında en fazla 1 soru (ör. bir şirketin kuruluş yılı ve çalışan sayısı aynı güne düşmez)
- Herkes aynı gün aynı soruları görür ve bunun için sunucu gerekmez. Bunun bedeli şudur: **takvim ve banka yalnızca sona eklenebilir.** Bir günü ya da soruyu değiştirmek, farklı oyunculara aynı gün farklı sorular gösterir.
- Mevcut takvim 45 gündür. Uzatmak için yeni kolay sorular gerekir (bkz. PLAN.md).
- Günler numarayla değil tarihle anılır (`dateOfDay`, `dayLabel`): paylaşımda ve liderlik tablosunda "4 Kasım", ana ekranda "4 Kasım Çarşamba".
- **Süre sınırı (`core/question_timer.dart`):** Günün setinde her soru için 15 saniye var, soru ilk göründüğü andan başlar. Başlangıç anı `daily_started_<gün>` anahtarında saklanır (`StatsStore.startDailyQuestion`), bu yüzden çıkıp geri gelmek süreyi sıfırlamaz. Süresi geçmiş bir soruya dönülürse hemen süre dolmuş sayılır. Süre dolunca ekrandaki aralık (ya da yalnızca yazılmış tahmin, varsayılan genişlikle) kendiliğinden kilitlenir (`GameController.timeOut`). Hiç tahmin yoksa soru taban puanı (−50) alır, ⬛ sayılır ve kalibrasyona girmez. Geri sayım duvar saatinden hesaplanır, uygulama arka plandayken de işler. Serbest modda süre yoktur.

### 5.2 Aralık girişi (`core/interval.dart`)
- **Büyüklük:** logaritmik kaydırıcı. `t ∈ [0,1]` için aralık `tahmin ÷ f … tahmin × f`, burada `f = 10^t`. Sınırlar dışa doğru "güzel" adımlara (1, 2, 5 × 10ⁿ) yuvarlanır. Bu yüzden ekranda `4.545 – 5.500` yerine `4.500 – 5.500` görünür. Ekranda görünen sınırlar puanlanan sınırların ta kendisidir.
- **Yıl:** ±yıl. Yarı genişlik `round(50·t²)` olduğu için kaydırıcının dar ucunda ince ayar yapılabilir.
- Varsayılan konum `t = 0,3`.

### 5.3 Puanlama (`core/scoring.dart`)
Gneiting & Raftery (2007) **interval score**, α = 0,1 (merkezi %90 aralık):

```
S = genişlik + (2/α) · (cevabın aralık dışındaki mesafesi)      2/α = 20
puan = round(100 − k·S), −50 … 100 arasında kırpılır
```
- **Büyüklük:** eksen log2'dir, yani ×2 fazla tahmin ile ÷2 eksik tahmin aynı cezayı alır. k = 10.
- **Yıl:** eksen yıl cinsindendir. k = 1.
- Bu kuralın beklenen değeri, sınırlar oyuncunun kendi %5 ve %95 yüzdelikleri olduğunda en iyidir. Yani **dürüst %90 aralığı en iyi stratejidir.**
- **Taban neden −50?** Taban 0 olursa uzak ıskalar bedava olur ve bilerek dar aralık vermek yeniden kârlı hâle gelir. Örneğin ×2 belirsizlikteki bir oyuncu için en iyi oyun, cevabın yalnızca ~%74'ünü kapsayan bir aralık olurdu. Taban önce −100'dü. Kapalı testte turların çoğu eksiyle bittiği için 2026-11-04'te −50'ye çekildi. Bedeli küçük: en kârlı aralık ×2 belirsizlikte %87'yi (−100 ile %89), ×2,8'de ~%82'yi (−100 ile %86) kapsar.
- Aynı formül liderlik sunucusunda JavaScript ile tekrar yazılmıştır (`server/leaderboard/src/scoring.js`). `server/leaderboard/test/scoring_vectors.json` iki tarafta da test edilir: formül değişirse ikisi birlikte değişmelidir.
- `test/core/scoring_test.dart` bu özelliği sayısal olarak doğrular. Test, log-normal hata varsayımıyla beklenen puanı en yüksek yapan aralığın kapsamını sayısal integralle hesaplar. Kapsam, log2 σ = 0,3 … 1,0 için %86–93, σ = 1,5 (≈ ×2,8) için %82–93 aralığında kalmalıdır.
- **Sonuç kademesi:** 🟩 isabet ve ≥70, 🟨 isabet ve <70, ⬛ ıska. Günlük en yüksek puan 500.
- **Kalibrasyon:** tüm zamanların isabet oranı. 10 cevaptan önce yorum yapılmaz. %80–95 aralığı "iyi", altı "fazla dar", üstü "daha cesur ol" sayılır.

### 5.4 Serbest mod (`core/free_play.dart`)
- Tur 5 sorudan oluşur. Oyuncunun herhangi bir modda kilitlediği hiçbir soru tekrar gelmez (`StatsStore.seenIds`).
- Banka soruları, takvimin **önümüzdeki 60 gününde olmayan** sorulardan gelir (`freePlayPool`): geçmiş günler ve takvime hiç girmemiş sorular. Takvim 60 günden kısaysa tamamı dışarıda tutulur.
- Turda her üreticiden en fazla 1, toplamda en fazla 2 üretilmiş soru olur. Şu an tek üretici mesafe olduğu için turda en fazla 1 mesafe sorusu bulunur.
- Banka havuzu biterse tur kısalır. Hiç soru kalmamışsa ana ekranda kısa bir mesaj çıkar.
- **Bilinen sınır:** 60. günden sonraki bir takvim sorusunu serbest modda gören oyuncu, o gün geldiğinde aynı soruyu günlük sette tekrar görür. Günlük set herkes için aynı kalmak zorunda olduğu için görülen soruları atlayamaz.

### 5.5 Cihazda üretilen sorular (`data/distance_questions.dart`)
- Kuş uçuşu mesafe, haversine formülüyle hesaplanır. Üç türde çift üretilir:
  - il merkezi – il merkezi
  - başkent – başkent
  - büyük Türkiye şehri – başkent
- 30 km'den yakın çiftler atlanır, çünkü fazla kolay olurlar.
- Kimlik biçimi `dist:Q1:Q2`. `source` alanı iki öğenin de Wikidata linkini içerir.
- Birkaç KB'lık kaynaklı koordinattan binlerce soru çıkar ve sayı yine hiçbir zaman elle yazılmaz.
- Statüsü tartışmalı başkentler için yalnızca şehir adı kullanılır, ülke adı geçmez.

### 5.6 İstatistikler (`data/stats_store.dart`, `core/stats.dart`)
`shared_preferences` anahtarları:

| Anahtar | İçerik |
|---|---|
| `answered`, `hits` | Tüm zamanların toplamları (kalibrasyon) |
| `seen_ids` | Kilitlenen tüm soru kimlikleri |
| `daily_results_<gün>` | O günün sonuçları, `"85:1"` (puan:isabet) |
| `daily_started_<gün>` | O günün açık sorusunun ilk gösterildiği an, `"2:1762240000000"` (sıra:ms) |
| `completed_days` | Tamamlanan gün indeksleri (seri) |
| `answer_log` | Her cevap için `"geography:85:h"` (kategori:puan:sonuç). Sonuç kodları: `h` isabet, `o` fazla yüksek, `u` fazla düşük |

- Cevap günlüğü, istatistik ekranındaki 10'arlı blok grafiği, kategori kırılımı ve ıska yönü analizi için tutulur.
- Okunamayan bir kayıt atlanır, uygulamayı çökertmez.
- Günlük kaydı eklenmeden önce verilen cevaplar yalnızca toplamlara yansır.
- Süresi dolan ve tahmin yazılmamış bir soru `seen_ids` ve `daily_results` içine girer, ama `answered`, `hits` ve `answer_log` içine girmez.

## 6. İnternetten içerik güncelleme (`data/content_sync.dart`)
1. `python tools/publish_content.py` bankayı, takvimi ve yer verisini `docs/content/` altına kopyalar. Bir şey değiştiyse `manifest.json` sürümünü artırır. `docs/` push edilince GitHub Pages yayınlar (`https://yerdema.github.io/aralik/content/`). `--reset` bayrağı "yayındakinin devamı" kontrolünü atlar ve yalnızca ilk oyuncudan önce kullanılır.
2. Uygulama açılışta arka planda, **en fazla 6 saatte bir** manifest'e bakar. Sürüm yeniyse dosyaları indirir.
3. Üç dosya birlikte doğrulanır (`QuestionRepository.acceptsContent`). Biri geçmezse hiçbiri kaydedilmez:
   - banka parse edilebilmeli ve gömülü bankanın **birebir devamı** olmalı (aynı id'ler, aynı sıra, yalnızca sonda ekleme)
   - takvim parse edilebilmeli, gömülü takvimin birebir devamı olmalı ve yalnızca yeni bankadaki soruları içermeli
   - yer verisi parse edilebilmeli ve kullanılabilir olmalı
4. Geçen içerik `shared_preferences`'a yazılır ve **bir sonraki açılışta** kullanılır. Böylece oynanan bir oyun ortasında değişmez.
5. İnternet yoksa, zaman aşımı olursa ya da JSON bozuksa hiçbir şey olmaz, sonra yeniden denenir.

- HTTP için `HttpClient` kullanılır. Zaman aşımları: bağlantı 8 sn, yanıt 15 sn, gövde 30 sn.
- `manifest.json` içinde dosyaların SHA-256 değerleri de var, ancak uygulama şu an bunları **denetlemiyor**. Güvence, yukarıdaki yapısal doğrulamadan geliyor.
- **Gizlilik:** GitHub sunucusu istek yapan IP adresini görür. Bunun dışında hiçbir veri gönderilmez. Bu durum `docs/privacy-policy.md` içinde belirtilir.
- Manifest'teki isteğe bağlı `leaderboard` alanı liderlik sunucusunun https adresidir. İçerik sürümünden bağımsız olarak her manifest okumasında güncellenir. Alan yoksa ya da https değilse liderlik arayüzü gizlenir. Adres `python tools/publish_content.py --leaderboard URL` ile yazılır, bunun için içerik sürümünü artırmak gerekmez.

## 7. Veri hattı (`tools/`)
Python 3, yalnızca standart kütüphane:

```
fetch_wikidata.py → tools/raw/wikidata/*.json → build_questions.py → assets/questions/questions.json
                                                                   → build_schedule.py  → assets/questions/schedule.json
                                              → build_places.py    → assets/data/places.json
tools/sources.json → build_attributions.py → assets/data/attributions.json, docs/attributions.md
validate_questions.py (banka + takvim)        publish_content.py → docs/content/ (yayın)
```

- **Kaynak listesi (`tools/sources.json`):** `docs/SOURCES.md` içindeki her kaynak lisansı, lisans linki, atıf satırı, durumu (`in_use`, `planned`, `reference_only`, `do_not_use`) ve kullandığı veri setleriyle burada durur. Uygulama ve `docs/attributions.md` yalnızca `in_use` kaynakları listeler.
- **Ham dökümler:** `tools/raw/<kaynak>/` altında durur. Her klasördeki `_meta.json` kaynağın adresini, lisansını ve her veri setinin indirme tarihini kaydeder.

- **`fetch_wikidata.py`:** Wikidata SPARQL'den veri çeker. Tek büyük sorgu herkese açık uç noktada zaman aşımına uğradığı için iki aşamada çalışır:
  1. Türkçe Vikipedi maddesi olan adaylar tür bazında taranır ve sitelink sayısına göre sıralanır.
  2. En iyi adayların ayrıntıları `VALUES` ile alınır: Türkçe etiket, rütbesiyle birlikte her geçerli değer ve Vikipedi madde adı.
  - Sonra Wikimedia REST API'den maddenin son 12 aylık **okunma sayısı** eklenir.
  - Veri setleri: Türkiye ve dünya dağları, nehirler, göller, köprüler, yapılar ve gökdelenler, tarihi yapılar, depremler, ülke nüfusu ve yüzölçümü, kulüp ve üniversite kuruluş yılları, muharebeler ve savaşlar, stadyumlar, şirketler (kuruluş yılı, çalışan sayısı), elementler (erime ve kaynama noktası, keşif yılı), Nobel ödülleri, hayvanlar (yetişkin kütle, ömür), iller, yer koordinatları.
  - Property ve sınıf kimlikleri kullanılmadan önce wikidata.org'da doğrulanır, doğrulanan kimlikler betiğin başında listelenir.
  - Gelişmiş özellikler:
    - Niteleyici yılı: Nobel'de ödülün P585 tarihi.
    - Niteleyici süzgeçleri: hayvan kütlesinde cinsiyet (P21) ve rol (P3831: yetişkin ağırlığı), şirket çalışan sayısında P585 yılı.
    - Özel aday sorgusu (`candidates`): genel taramanın zaman aşımına uğradığı veri setleri için.
- **`build_questions.py`:** Şablonları veriyle doldurur.
  - Hangi öğenin soru olacağına okunma sayısıyla karar verilir, çünkü bu ölçü sitelink sayısından çok daha iyi biçimde "Türk oyuncunun duyduğu şey"i gösterir.
  - Değerleri çelişen öğeler, rütbe çözümlemesinden sonra bile %1'den fazla farklıysa ya da yılları farklıysa atlanır.
  - Yanıltıcı öğeler gerekçesiyle dışarıda bırakılır.
  - Yeni sorular sabit seed ile karıştırılıp sona eklenir. `--fresh` bankayı baştan kurar (yalnızca ilk oyuncudan önce kullanılmalı). `--report` her veri setinde seçilenleri, zorluklarını ve sınırda kalanları okunma sayılarıyla listeler.
  - **Zorluk tahmini:** `ease = log10(okunma) + kategori düzeltmesi + tür düzeltmesi + birim düzeltmesi`. Nüfus ve yüzölçümü gibi kimsenin sezgisi olmayan büyüklükler ceza alır. Sabit eşiklerle 1/2/3'e bölünür. `tools/difficulty_overrides.json` (`{"q0012": 1}`) tek tek düzeltir.
  - **Bilinen zaaf:** Okunma sayısı oyuncunun öğeyi ne kadar tanıdığını ölçer, sayıyı değil. Üniversite kuruluş yılları bu yüzden olduğundan kolay görünebilir.
  - Kelvin cinsinden gelen sıcaklıklar °C'ye çevrilir. Kaydırıcı logaritmik olduğu için yalnızca ≥ 100 °C olanlar sorulur.
  - Hayvan soruları yalnızca Türkçe adı olan türlerden üretilir: etiketi bilimsel adla (P225) aynı olan tür elenir.
- **`build_schedule.py`:** Takvimi kurar (bkz. 5.1). Sabit seed ile deterministiktir, varsayılan olarak mevcut günleri korur ve sona gün ekler. Bir zorluk kademesinde soru tükenirse durur ve eksiği raporlar.
- **`build_places.py`:** Koordinat ifadeleri birbirinden çok farklı olan yerleri ve birden çok başkenti olan ülkeleri eler.
- **`validate_questions.py`:** Bankada zorunlu alanları ve tipleri, `q0001` biçimini, id'lerin artan sırada ve benzersiz olmasını, metnin `?` ile bitmesini, kaynak linkini, opsiyonel alanları ve her veri setinin kullanımdaki bir kaynağa bağlı olmasını denetler. Takvimde gün biçimini, tekrarları ve id'lerin bankada bulunmasını denetler. Günlük kurallara ve dağılım hedeflerine (kategori ≤ %25, veri seti ≤ %10) uymayanları uyarı olarak bildirir. Hata varsa çıkış kodu 1 olur.
- **Kural:** Sayılar yalnızca ham Wikidata dökümlerinden gelir. Bir dil modeli en fazla soru metnini akıcılaştırmak için kullanılabilir. **Sayılar asla dil modelinden alınmaz.**

## 7b. Günün liderleri (`server/leaderboard/`, `data/leaderboard.dart`)
- **Sunucu:** Cloudflare Worker ve D1 (SQLite), ücretsiz katman. Uç noktalar: `POST /v1/register`, `/v1/rename`, `/v1/submit`, `/v1/delete` ve `GET /v1/day/{n}`. Ayrıntılar ve kurulum: [server/leaderboard/README.md](server/leaderboard/README.md).
- **Kimlik:** Giriş yoktur. Katılan oyuncuya sunucu rastgele bir kimlik ve gizli bir anahtar verir. Sunucu anahtarın yalnızca SHA-256 özetini saklar. Uygulama silinirse hesap da kaybolur.
- **Takma ad:** 3–16 karakter: harf, rakam, boşluk ve `. _ -`. Benzersizdir. Karşılaştırma Türkçe küçük harfe çevrilmiş, aksansız ve ayraçsız anahtarla yapılır, böylece "Şeyma" ile "s.e.y.m.a" aynı sayılır. Sunucuda küfür filtresi ve IP başına saatte 5 kayıt sınırı vardır. IP adresi saklanmaz, yalnızca tuzlu özeti 24 saat tutulur ve günlük bir cron ile silinir.
- **Gönderim:** Günün setindeki her kilitlenen aralık, katılmadan da cihazda tutulur (`lb_answers_<gün>`). Set bitince ve oyuncu katılmışsa 5 aralık gönderilir. Puanı sunucu, yayınlanmış banka ve takvimden kendisi hesaplar. Bir günün ilk gönderimi geçerlidir. Çevrimdışıyken gönderim bekler, sonraki açılışta tekrar denenir.
- **Tablo:** Her gün ayrıdır, yeni sorularla tablo sıfırlanır. Gönderim yalnızca dün, bugün ve yarın için kabul edilir (Türkiye saati). Eşitlikte önce gönderen öndedir. Toplam katılımcı `FULL_BOARD_AT` (100) olana kadar ilk 10, sonra ilk 50 gösterilir.
- **Arayüz:** Ana ekrandaki kupa simgesi ve gün özetindeki "Günün liderleri" düğmesi tabloyu açar. Ayarlar → Liderlik tablosu bölümünde takma ad değiştirilir ve "Tablodan ayrıl" ile sunucudaki veri silinir.
- **Bilinen sınırlar:** Cevaplar APK'da olduğu için kararlı biri sahte gönderim yapabilir. Sunucu 15 saniye kuralını doğrulayamaz.

## 8. Arayüz
- **Tema:** Material 3 şeması `DynamicSchemeVariant.fidelity` ile çivit tohum renginden (`Palette.indigo`) üretilir, tertiary renk filozofun togasıyla aynı kiremit tonuna ayarlanır. Zemin açık temada krem, koyu temada gece mavisidir. Açık ve koyu tema sisteme göre seçilir. Uygulama ikonu ve açılış ekranı lacivert kalır. Paylaşım kartı ana ekranın çivit renginde.
- **Ana ekran:** Üstte küçük "Kabaca" yazısı ve slogan, altında boş alanı dolduran çivit "bugün" kartı (tarih ve gün adı, ilerleme çizgileri, düğmenin arkasından bakan maskot, güneş sarısı ana düğme). Onun altında serbest modu başlatan mercan "Bir tur at" kartı, en altta seri, son skor ve kalibrasyon. Maskot, kartın içindeki boşluk ayrılarak yerleştirilir, küçük ekranda da metnin üstüne binmez. Günün seti bitince "bugün" kartı skor, ilerleme çizgileri ve paylaş düğmesinden oluşan ince bir şeride döner; maskotlu büyük kart "Bir tur at" olur.
- **`GameColors`:** sonuç kademesi renkleri (🟩🟨⬛ ile eşleşir) ve seri rengi için bir ThemeExtension.
- **Kategori stili:** Her kategorinin bir Material ikonu ve açık/koyu tema için birer rengi vardır.
- **Çizimler:**
  - `widgets/philosopher.dart`: filozof maskotu. Uygulama ikonu (`tools/icon/render_icon_test.dart`), paylaşım kartı ve `widgets/mascot.dart` aynı kodu kullanır, bu yüzden hepsi aynı karakteri çizer. Bir `DayMood` verilince yüz, kollar ve küçük bir sahne öğesi değişir (bkz. paylaşım kartı). Verilmezse ikondaki düşünen filozof çizilir.
  - `widgets/mascot.dart`: maskotun ekrandaki hâli (ana ekran ve açılış), balonu bir kez sallanır.
  - `widgets/interval_bar.dart`: sonuçtaki aralık çubuğu.
  - `features/stats/calibration_chart.dart`: kalibrasyon grafiği.
  - Hepsi `CustomPaint` ile çizilir.
- **Animasyonlar:** Yalnızca implicit animasyonlar kullanılır (`TweenAnimationBuilder`, `AnimatedContainer`, `AnimatedSwitcher`). Rozet zıplaması, sayarak artan puan, sırayla beliren kareler ve maskotun sallanan balonu bunlarla yapılır. AnimationController ya da paket yok.
- **Açılış:**
  - Android'in açılış ekranı ikonun laciverdinde (`#2B3B6C`), ortasında filozof var.
    - Android 12 ve üstü: `values-v31` ve `values-night-v31` içindeki `windowSplashScreen*` ayarları.
    - Daha eski sürümler: `drawable/launch_background.xml` (288 dp).
    - Görünen alan her sürümde 192 dp.
  - Flutter penceresinin zemini (`NormalTheme`) de aynı lacivert. Böylece açılış ekranı kalkarken araya beyaz ya da siyah bir kare girmez.
  - `features/intro/intro_screen.dart` aynı karede devam eder. Filozof piksel piksel aynı yerde kalır (ölçüldü):
    - balon hafifçe sallanır
    - altında yumuşak açık mavi, kalın "Kabaca" yazısı belirir
    - ana ekrana kısa bir geçiş olur
  - Süre: 0,65 sn animasyon + 0,25 sn geçiş. Dokununca atlanır, yalnızca soğuk açılışta oynar.
  - Toplam açılış süresinin asıl belirleyicisi Flutter motorunun başlangıcıdır (Android ekranı bu sürede görünür). Bu, GPU'suz emülatörde ~3 sn, gerçek telefonlarda tipik olarak 1 sn'nin altındadır.
  - Tek bir `TweenAnimationBuilder` kullanılır, AnimationController yok.
- **Paylaşım kartı (`features/result/share_card.dart`):**
  - 1080 × 1920 (9:16) PNG, doğrudan canvas'a çizilir. Hikâye ve durum boyutudur.
  - İçerik: ana ekrandaki çivit geçişli zemin, yumuşak ışık halkaları ve hafif "≈" süsleri. Üstte "Kabaca" yazısı, slogan ve tarih rozeti ("4 Kasım"). Ortada ruh hâline göre başlık ve paylaşanın ağzından bir satır, altında skor panelinin arkasına uzanan filozof. Krem panelde skor, kalibrasyon (en az 10 cevaptan sonra), renkli kareler ve her sorunun puanı. En altta güneş sarısı "Sen de dene: Kabaca" düğmesi.
  - Ruh hâli günün toplamından gelir (`core/day_mood.dart`):

    | Toplam | Başlık | Filozof |
    |---|---|---|
    | ≥ 450 | Efsane! | kahkaha, iki kolla kas gösterme, konfeti ve parıltı |
    | 350–449 | Harika! | gülüş, havada zafer yumruğu, konfeti |
    | 200–349 | Fena değil! | kabarık göğüs, eller belde, bıyık altından gülüş |
    | 0–199 | İdare eder. | kafa kaşıma, şaşkın gözler, ter damlası |
    | < 0 | Bugün olmadı. | düşük omuzlar, üzgün kaşlar, yağmur bulutu |

  - Kart paylaşanın kartıdır, bu yüzden üstündeki satırlar birinci tekil kişiyle yazılır ("Bugün sayılar benden yanaydı.").
  - Kartları gözle kontrol etmek için `flutter test tools/share/render_share_cards_test.dart` beş örneği gerçek Roboto fontuyla `build/share_cards/` içine çizer.
  - Gün özetindeki "Paylaş" bir alt sayfa açar. Kartın önizlemesi gösterilir; "Görseli paylaş" görseli ve Wordle metnini birlikte, "Metni paylaş" yalnızca metni gönderir.
  - Görsel `XFile.fromData` ile bellekten verilir; `share_plus` onu geçici bir dosyaya kendisi yazar. Ek paket gerekmez.
- **Titreşim:** Tuşlarda `selectionClick`, kilitlemede `mediumImpact`. Ses yok.
- **Ayarlar:** "Görünüm" bölümünde tema seçimi var: sistem, açık ya da koyu. Seçim `data/settings_store.dart` ile `shared_preferences`'ta saklanır, uygulama anında geçer. Liderlik tablosuna katılınca "Liderlik tablosu" bölümü çıkar: takma ad değiştirme ve tablodan ayrılma. "Hakkında" bölümünde veri kaynakları ve lisanslar ekranı, Flutter'ın yerleşik açık kaynak lisansları sayfası (`showLicensePage`) ve gizlilik politikası. Linkler tarayıcıda açılmaz, çünkü bunun için `url_launcher` paketi gerekir. Bunun yerine seçilebilir metin olarak gösterilir ve yanlarında bir kopyalama düğmesi bulunur (`widgets/link_text.dart`).
- **Erişilebilirlik:** Grafik bir `Semantics` etiketiyle oranları okutur. Sayarak artan metin ekran okuyucuya son değeri söyler. Süs çizimleri `ExcludeSemantics` içindedir.

## 9. Test
- `flutter test` 197 test çalıştırır:
  - `test/core`: puanlama (dürüstlük özelliği ve sunucuyla ortak vektörler dahil), aralık, süre sınırı, takvim ve tarih, ruh hâli bantları, takma ad kuralları, serbest mod turu, sayı biçimi, paylaşım metni, istatistik, coğrafya
  - `test/data`: soru modeli (yeni alanlar ve "diğer" geri düşüşü dahil), içerik senkronu (sahte HTTP ve saatle, takvim reddi ve liderlik adresi senaryolarıyla), gömülü takvim-banka tutarlılığı, istatistik deposu (süre başlangıcı dahil), liderlik deposu (sahte sunucuyla), mesafe üreticisi
  - `test/features`: ana ekran, soru ekranı (geri sayım ve süre dolması dahil), liderlik ekranı, istatistik ekranı, ayarlar ve kaynaklar ekranları, açılış animasyonu, paylaşım kartı (beş ruh hâli) ve paylaşım sayfası
- Sunucu: `cd server/leaderboard; npm test` 22 test çalıştırır (Node'un yerleşik test aracı, D1 yerine `node:sqlite`). Puanlama vektörleri, takma ad kuralları, uç noktalar uçtan uca (kayıt sınırı, sıralama, ilk 10 / ilk 50, günlük sıfırlanma, silme), günlük temizlik.
- `flutter analyze` sıfır uyarı vermelidir. Commit öncesi `dart format .` çalıştırılır.
- Saf iş mantığı için birim test zorunludur.

## 10. Build ve yayın
- **Release:** `android/app/build.gradle.kts` (Kotlin DSL) içinde `isMinifyEnabled = true` ve `isShrinkResources = true`.
  ```powershell
  flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
  ```
  `build/symbols` çökme raporlarını çözmek için saklanmalıdır.
- **İmza:** Release, `android/key.properties` içindeki upload anahtarıyla imzalanır. Bu dosya ve `.jks` git'e girmez. Dosya yoksa build debug anahtarına düşer.
- **İzin:** INTERNET izni ana manifest'tedir. İçerik güncellemesi ve isteğe bağlı liderlik tablosu için kullanılır.
- **Uygulama ikonu:** `flutter test tools/icon/render_icon_test.dart` ikonu Flutter'ın kendi çizim motoruyla üretir, paket gerekmez. Tasarım: lacivert zemin üzerinde düşünen bir filozof (kel, beyaz sakallı, gözleri kapalı, kiremit rengi toga) ve içinde "?" olan bir düşünce balonu. Çıktılar: klasik, yuvarlak, uyarlanabilir (ön ve arka plan) ve Android 13 tek renkli katmanlar her yoğunlukta, ayrıca Play için `docs/store/icon-512.png`. Tek renkli katmanda çizgiler oyulur, böylece tema renginde de yüz okunur.
- **Gizlilik politikası:** `docs/privacy-policy.md`, GitHub Pages ile yayınlanır. Liderlik tablosunun hangi veriyi tuttuğu ve nasıl silindiği orada yazar.
- **Liderlik sunucusu:** `cd server/leaderboard; npm run deploy` (ilk kurulum: [server/leaderboard/README.md](server/leaderboard/README.md)).
- **Boyut:** Yüklenen AAB tüm işlemci mimarilerini içerdiği için büyüktür (~45 MB). Asıl hedef, Play'in cihaza özel ürettiği indirme boyutudur (< 8 MB). Bu ölçüm henüz yapılmadı.

## 11. Karşılaşılan sorunlar ve çözümleri
| Sorun | Çözüm |
|---|---|
| Proje klasörü `Aralık` (ı harfi) Windows'ta Android Gradle build'ini ("non-ASCII path") ve `flutter analyze`'ı bozdu | Geçici olarak `subst A:` ile ASCII sürücü takma adı kullanıldı. Kalıcı çözüm: klasör `Aralik` olarak yeniden adlandırıldı. |
| Tek büyük SPARQL sorgusu Wikidata'nın herkese açık uç noktasında zaman aşımına uğradı | Önce aday taraması, sonra `VALUES` ile ayrıntı çekimi |
| Wikidata'da aynı öğe için birden çok, birbiriyle çelişen değer | Rütbe çözümlemesi uygulandı. Çelişki %1'i ya da yıl farkını aşarsa öğe atlandı. Hatalı veriler (Konya ve Uşak plaka kodları, Bingöl'ün başkenti, Çankırı'nın koordinatları) dışarıda bırakıldı ve Wikidata'da düzeltilmek üzere not edildi. |
| Sitelink sayısı Türk oyuncunun ne bildiğini iyi göstermiyordu, sorular yabancı geldi | Seçim ölçüsü Türkçe Vikipedi okunma sayısına çevrildi |
| İlk puan kuralı (0 tabanı) bilerek dar aralık vermeyi ödüllendiriyordu | Interval score ve −100 tabanı benimsendi. Dürüstlük özelliği testle kilitlendi. |
| Kapalı testte turların çoğu eksiyle bitiyordu | Taban −50'ye çekildi. Dürüstlük testinin sınırları yeni değere göre doğrulandı. |
| Oyuncu soruyu görüp çıkarak, düşünüp geri dönerek süreyi atlatabilirdi | Sorunun ilk gösterildiği an saklanıyor. Geri dönüldüğünde süre kaldığı yerden işliyor. |
| Liderlik tablosunda istemcinin bildirdiği puana güvenilemez | Sunucu aralıkları alıp puanı yayınlanmış banka ve takvimden kendisi hesaplıyor. İki taraftaki formül ortak test vektörleriyle eşit tutuluyor. |
| Sunucu adresi ancak yayından sonra belli olacaktı, paket ise önceden hazırlanmalıydı | Adres uygulamaya gömülmedi, manifest'teki `leaderboard` alanından okunuyor |
| Paylaşım kartındaki başparmak hareketi küçük boyutta kaba bir el hareketi gibi okunuyordu | Zafer yumruğuyla değiştirildi |
| Yeni sorular güncelleme beklemeden gelmeli ama günlük setler herkes için aynı kalmalı | Yalnızca sona eklenen banka ve indirilenin gömülü bankanın birebir devamı olma şartı |
| Serbest modun bitmemesi gerekiyordu | Kaynaklı küçük tablolardan cihazda soru üretimi (ilk üretici: mesafe) |
| Statüsü tartışmalı başkentler | Sorularda ülke değil, yalnızca şehir adı geçiyor |
| Bankanın sırasına bağlı günlük setler zorluk ve kategori dengesi kurmaya izin vermiyordu | Ayrı, yalnızca sona eklenen takvim dosyası ve `build_schedule.py` |
| Yeni veri setlerinde (şirketler, hayvanlar) aday sorgusu zaman aşımına uğradı | Veri setine özel aday sorgusu: şirketlerde çalışan sayısı bilinenler, hayvan kütlesinde "yetişkin ağırlığı" niteleyicisinden başlayan sorgu |
| Q80061'in (Nobel Tıp) Türkçe etiketi Wikidata'da "… sahipleri listesi" olarak girilmiş | Nobel ödül adları etiketten değil, betikteki sabit Türkçe listeden gelir |
| Hayvan kütlesi aynı türde cinsiyete ve role göre birden çok değer taşıyor (aslan: 188, 126, 1,65 kg) | Yalnızca "yetişkin ağırlığı" rolündeki değerler alınır; cinsiyete ayrılmışsa erkek değeri sorulur ve metinde belirtilir |
| İçerik güncellemesiyle gelen yeni bir kategori eski sürümlerde tüm bankayı reddettirecekti | Bilinmeyen kategori `diğer` altında gösterilir |
| Yaz saati geçişinde gün indeksinin kayması riski | Gün farkı, UTC takvim tarihleri üzerinden hesaplanıyor |
| Uzun metin ve küçük ekranlarda taşma | Ana ve sonuç ekranları sığmadığında kayıyor, büyük sayılar `FittedBox` ile küçülüyor |

## 12. Komutlar
| İş | Komut |
|---|---|
| Çalıştır | `flutter run` |
| Test | `flutter test` |
| Analiz | `flutter analyze` |
| Biçimlendir | `dart format .` |
| Wikidata ham verisi | `python tools/fetch_wikidata.py [veri_seti ...]` |
| Soru bankası | `python tools/build_questions.py [--fresh] [--dry-run] [--report]` |
| Günlük takvim | `python tools/build_schedule.py [--days N] [--fresh] [--dry-run]` |
| Atıf listesi | `python tools/build_attributions.py` |
| Yer verisi | `python tools/build_places.py` |
| Bankayı ve takvimi doğrula | `python tools/validate_questions.py` |
| İçeriği yayına hazırla | `python tools/publish_content.py [--reset] [--leaderboard URL]` (sonra `docs/` commit ve push) |
| Uygulama ikonu | `flutter test tools/icon/render_icon_test.dart` |
| Paylaşım kartı örnekleri | `flutter test tools/share/render_share_cards_test.dart` (çıktı `build/share_cards/`) |
| Liderlik sunucusu testleri | `cd server/leaderboard; npm test` |
| Liderlik sunucusunu yayınla | `cd server/leaderboard; npm run deploy` |
| Release paketi | `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols` |
