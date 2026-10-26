# Aralık: Teknik Belge

Bu belge uygulamanın nasıl kurulduğunu, hangi teknolojilerin neden seçildiğini ve geliştirme sırasında
karşılaşılan sorunların nasıl çözüldüğünü anlatır. Oyunun ne olduğu için [README.md](README.md),
yol haritası ve açık konular için [docs/PLAN.md](docs/PLAN.md) belgesine bak.

*Son güncelleme: 2026-10-26*

## 1. Tasarım ilkeleri
Her teknik karar şu beş ilkeye göre verildi:

1. **Sıfır bütçe, sıfır backend.** Sunucu, Firebase, reklam SDK'sı ve analytics yok. Tek ağ trafiği, GitHub Pages'teki statik içerik dosyalarının indirilmesi.
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
| HTTP | `dart:io` `HttpClient` | Paket yok |
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
- `http`: tek bir GET isteği için `HttpClient` yeterli.
- Grafik kütüphaneleri: kalibrasyon grafiği ve aralık çubuğu birkaç düzine satırlık `CustomPaint` ile çiziliyor.

## 3. Mimari
```
lib/
  main.dart                 # prefs, depo ve içerik senkronunu kurar, runApp
  app.dart                  # MaterialApp, açık/koyu tema
  core/                     # Flutter'a bağımlı olmayan saf iş mantığı (hepsi birim testli)
    scoring.dart            # interval score, puan, sonuç kademesi, kalibrasyon geri bildirimi
    interval.dart           # kaydırıcı konumu → aralık sınırları
    daily.dart              # gün indeksi, takvim (Schedule), seri
    free_play.dart          # serbest mod turu oluşturma
    stats.dart              # istatistik hesapları (blok isabet, kategori, ıska yönü)
    number_format.dart      # Türkçe sayı biçimi
    share_text.dart         # Wordle tarzı paylaşım metni
    geo.dart                # haversine mesafe
    theme.dart              # Palette, tema, GameColors, kategori renk ve ikonları
    strings.dart            # kullanıcıya görünen tüm Türkçe metinler
  data/
    question.dart           # Question modeli + fromJson doğrulaması
    question_repository.dart# banka, takvim ve yer verisinin tek seferlik yüklenmesi, önbellek
    attributions.dart       # atıf listesi (assets/data/attributions.json)
    content_sync.dart       # GitHub Pages'ten içerik güncellemesi
    stats_store.dart        # shared_preferences sarmalayıcısı (ChangeNotifier)
    settings_store.dart     # ayarlar (tema), shared_preferences
    distance_questions.dart # cihazda mesafe sorusu üreticisi
    place.dart              # yer modeli
  features/                 # ekranlar: home, game (+ GameController), result, stats, settings
  widgets/                  # ortak parçalar (sayı klavyesi, aralık çubuğu, kategori etiketi, ...)
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
- Kategoriler: `coğrafya`, `tarih`, `türkiye`, `bilim`, `spor`, `gündelik`, `hayvanlar`, `şirketler`.
- Opsiyonel alanlar:
  - `difficulty`: 1 kolay, 2 orta, 3 zor (bkz. 7. bölüm).
  - `dataset`: sorunun geldiği veri seti. `tools/sources.json` içinde kullanımdaki bir kaynağa bağlı olmalıdır, böylece her sorunun atfı uygulamada görünür.
  - `anchor`: `{text, value, unit, source}`, oyuncuya ölçek veren kaynaklı bir çapa değer. Model ve doğrulama hazır, henüz doldurulmuyor ve gösterilmiyor.
- `Question.fromJson` alan tiplerini, bilinen `kind` değerini, büyüklüğün pozitif ve yılın tam sayı olduğunu denetler.
- **Bilinmeyen kategori:** Uygulama tanımadığı bir kategoriyi reddetmez, `diğer` (`QuestionCategory.other`) altında gösterir. Böylece içerik güncellemesiyle yeni bir kategori eklendiğinde eski sürümdeki oyuncular yeni soruları kaybetmez. `diğer` bankaya asla yazılmaz, doğrulayıcı bunu reddeder. Bilinmeyen bir `kind` ise kurtarılamaz, çünkü puanlama türe bağlıdır.
- Mevcut banka 456 sorudan oluşur: 254 büyüklük, 202 yıl. Kategorilere göre coğrafya 150, tarih 96, spor 51, türkiye 49, şirketler 37, bilim 36, hayvanlar 23, gündelik 14.

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
- Kapalı test sırasında (`dayIndex < 0`) ana ekranda gün numarası gösterilmez, paylaşım metninde "(deneme)" yazar.

### 5.2 Aralık girişi (`core/interval.dart`)
- **Büyüklük:** logaritmik kaydırıcı. `t ∈ [0,1]` için aralık `tahmin ÷ f … tahmin × f`, burada `f = 10^t`. Sınırlar dışa doğru "güzel" adımlara (1, 2, 5 × 10ⁿ) yuvarlanır. Bu yüzden ekranda `4.545 – 5.500` yerine `4.500 – 5.500` görünür. Ekranda görünen sınırlar puanlanan sınırların ta kendisidir.
- **Yıl:** ±yıl. Yarı genişlik `round(50·t²)` olduğu için kaydırıcının dar ucunda ince ayar yapılabilir.
- Varsayılan konum `t = 0,3`.

### 5.3 Puanlama (`core/scoring.dart`)
Gneiting & Raftery (2007) **interval score**, α = 0,1 (merkezi %90 aralık):

```
S = genişlik + (2/α) · (cevabın aralık dışındaki mesafesi)      2/α = 20
puan = round(100 − k·S), −100 … 100 arasında kırpılır
```
- **Büyüklük:** eksen log2'dir, yani ×2 fazla tahmin ile ÷2 eksik tahmin aynı cezayı alır. k = 10.
- **Yıl:** eksen yıl cinsindendir. k = 1.
- Bu kuralın beklenen değeri, sınırlar oyuncunun kendi %5 ve %95 yüzdelikleri olduğunda en iyidir. Yani **dürüst %90 aralığı en iyi stratejidir.**
- **Taban neden −100?** Taban 0 olursa uzak ıskalar bedava olur ve bilerek dar aralık vermek yeniden kârlı hâle gelir. Örneğin ×2 belirsizlikteki bir oyuncu için en iyi oyun, cevabın yalnızca ~%74'ünü kapsayan bir aralık olurdu. −100 tabanıyla dürüst aralık, büyüklükte ~×2,8, yılda ~±25 yıl belirsizliğe kadar en iyi strateji olarak kalır.
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
| `completed_days` | Tamamlanan gün indeksleri (seri) |
| `answer_log` | Her cevap için `"geography:85:h"` (kategori:puan:sonuç). Sonuç kodları: `h` isabet, `o` fazla yüksek, `u` fazla düşük |

- Cevap günlüğü, istatistik ekranındaki 10'arlı blok grafiği, kategori kırılımı ve ıska yönü analizi için tutulur.
- Okunamayan bir kayıt atlanır, uygulamayı çökertmez.
- Günlük kaydı eklenmeden önce verilen cevaplar yalnızca toplamlara yansır.

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

## 8. Arayüz
- **Tema:** `core/theme.dart` içindeki `Palette`, uygulama ikonunun renklerinden türetilmiştir: gökyüzü, dağlar, kiremit rengi kule, yeşil ova, pembe beyin. Material 3 şeması `DynamicSchemeVariant.fidelity` ile lacivert tohum renginden üretilir, tertiary renk kule tonuna ayarlanır. Açık ve koyu tema sisteme göre seçilir.
- **`GameColors`:** sonuç kademesi renkleri (🟩🟨⬛ ile eşleşir) ve seri rengi için bir ThemeExtension.
- **Kategori stili:** Her kategorinin bir Material ikonu ve açık/koyu tema için birer rengi vardır.
- **Çizimler:**
  - `widgets/range_mark.dart`: logonun altındaki aralık işareti.
  - `widgets/interval_bar.dart`: sonuçtaki aralık çubuğu.
  - `features/stats/calibration_chart.dart`: kalibrasyon grafiği.
  - Hepsi `CustomPaint` ile çizilir.
- **Animasyonlar:** Yalnızca implicit animasyonlar kullanılır (`TweenAnimationBuilder`, `AnimatedContainer`, `AnimatedSwitcher`). Rozet zıplaması, sayarak artan puan, sırayla beliren kareler ve logonun açılan aralık işareti bunlarla yapılır. AnimationController ya da paket yok.
- **Titreşim:** Tuşlarda `selectionClick`, kilitlemede `mediumImpact`. Ses yok.
- **Ayarlar:** "Görünüm" bölümünde tema seçimi var: sistem, açık ya da koyu. Seçim `data/settings_store.dart` ile `shared_preferences`'ta saklanır, uygulama anında geçer. "Hakkında" bölümünde veri kaynakları ve lisanslar ekranı, Flutter'ın yerleşik açık kaynak lisansları sayfası (`showLicensePage`) ve gizlilik politikası. Linkler tarayıcıda açılmaz, çünkü bunun için `url_launcher` paketi gerekir. Bunun yerine seçilebilir metin olarak gösterilir ve yanlarında bir kopyalama düğmesi bulunur (`widgets/link_text.dart`).
- **Erişilebilirlik:** Grafik bir `Semantics` etiketiyle oranları okutur. Sayarak artan metin ekran okuyucuya son değeri söyler. Süs çizimleri `ExcludeSemantics` içindedir.

## 9. Test
- `flutter test` 139 test çalıştırır:
  - `test/core`: puanlama (dürüstlük özelliği dahil), aralık, takvim, serbest mod turu, sayı biçimi, paylaşım metni, istatistik, coğrafya
  - `test/data`: soru modeli (yeni alanlar ve "diğer" geri düşüşü dahil), içerik senkronu (sahte HTTP ve saatle, takvim reddi senaryolarıyla), gömülü takvim-banka tutarlılığı, istatistik deposu, mesafe üreticisi
  - `test/features`: ana ekran, soru ekranı, istatistik ekranı, ayarlar ve kaynaklar ekranları
- `flutter analyze` sıfır uyarı vermelidir. Commit öncesi `dart format .` çalıştırılır.
- Saf iş mantığı için birim test zorunludur.

## 10. Build ve yayın
- **Release:** `android/app/build.gradle.kts` (Kotlin DSL) içinde `isMinifyEnabled = true` ve `isShrinkResources = true`.
  ```powershell
  flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
  ```
  `build/symbols` çökme raporlarını çözmek için saklanmalıdır.
- **İmza:** Release, `android/key.properties` içindeki upload anahtarıyla imzalanır. Bu dosya ve `.jks` git'e girmez. Dosya yoksa build debug anahtarına düşer.
- **İzin:** INTERNET izni ana manifest'tedir ve yalnızca içerik güncellemesi için kullanılır.
- **Uygulama ikonu:** `flutter test tools/icon/render_icon_test.dart` ikonu Flutter'ın kendi çizim motoruyla üretir, paket gerekmez. Çıktılar: klasik, yuvarlak, uyarlanabilir (ön ve arka plan) ve Android 13 tek renkli katmanlar her yoğunlukta, ayrıca Play için `docs/store/icon-512.png`.
- **Gizlilik politikası:** `docs/privacy-policy.md`, GitHub Pages ile yayınlanır.
- **Boyut:** Yüklenen AAB tüm işlemci mimarilerini içerdiği için büyüktür (~45 MB). Asıl hedef, Play'in cihaza özel ürettiği indirme boyutudur (< 8 MB). Bu ölçüm henüz yapılmadı.

## 11. Karşılaşılan sorunlar ve çözümleri
| Sorun | Çözüm |
|---|---|
| Proje klasörü `Aralık` (ı harfi) Windows'ta Android Gradle build'ini ("non-ASCII path") ve `flutter analyze`'ı bozdu | Geçici olarak `subst A:` ile ASCII sürücü takma adı kullanıldı. Kalıcı çözüm: klasör `Aralik` olarak yeniden adlandırıldı. |
| Tek büyük SPARQL sorgusu Wikidata'nın herkese açık uç noktasında zaman aşımına uğradı | Önce aday taraması, sonra `VALUES` ile ayrıntı çekimi |
| Wikidata'da aynı öğe için birden çok, birbiriyle çelişen değer | Rütbe çözümlemesi uygulandı. Çelişki %1'i ya da yıl farkını aşarsa öğe atlandı. Hatalı veriler (Konya ve Uşak plaka kodları, Bingöl'ün başkenti, Çankırı'nın koordinatları) dışarıda bırakıldı ve Wikidata'da düzeltilmek üzere not edildi. |
| Sitelink sayısı Türk oyuncunun ne bildiğini iyi göstermiyordu, sorular yabancı geldi | Seçim ölçüsü Türkçe Vikipedi okunma sayısına çevrildi |
| İlk puan kuralı (0 tabanı) bilerek dar aralık vermeyi ödüllendiriyordu | Interval score ve −100 tabanı benimsendi. Dürüstlük özelliği testle kilitlendi. |
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
| İçeriği yayına hazırla | `python tools/publish_content.py [--reset]` (sonra `docs/` commit ve push) |
| Uygulama ikonu | `flutter test tools/icon/render_icon_test.dart` |
| Release paketi | `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols` |
