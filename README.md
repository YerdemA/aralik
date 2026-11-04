# Kabaca

**%90 emin olduğun aralığı ver.**

Kabaca, 5–10 dakikalık beklemelerde oynanan Türkçe bir günlük tahmin oyunudur (Android, Flutter).
Sayısal bir soruya tek bir sayıyla değil, **%90 emin olduğun bir aralıkla** cevap verirsin:

> Ağrı Dağı kaç metre yüksekliktedir? → **4.500 – 5.500 m**

Aralık cevabı içeriyorsa puan alırsın. Aralık ne kadar darsa puan o kadar yüksek olur. Uzun vadede oyun
**kalibrasyonunu** ölçer: "%90 eminim" dediğinde gerçekten 10 sorunun 9'unu tutturuyor musun?

- Geliştirici: Yusuf Erdem Aykaç ([YerdemA](https://github.com/YerdemA))
- Paket: `com.yerdema.kabaca` · Hedef: Google Play, Android 7.0+ (minSdk 24)
- Teknik belge: [TECHNICAL.md](TECHNICAL.md) · Yol haritası: [docs/PLAN.md](docs/PLAN.md)

## Neden?
- Bilgi yarışmaları "doğru / yanlış" mantığıyla çalışır. Kabaca ise **ne kadar emin olduğunu** ölçer. Bu ölçüm, bildiğin şeyden çok kendini ne kadar iyi tanıdığını gösterir.
- İçerik Türkçe ve yereldir: Türkiye coğrafyası, tarihi, sporu.
- Wordle gibi herkes aynı gün aynı soruları çözer. Skorunu emoji kartıyla paylaşabilirsin.
- **Sıfır bütçe, neredeyse sıfır backend.** Hesap, reklam ve analytics yok. Oyun internetsiz de eksiksiz çalışır. Tek sunucu, isteğe bağlı **günün liderleri** tablosudur: katılmayan oyuncunun hiçbir verisi cihazdan çıkmaz.

## Nasıl oynanır?
Günün setinde her soru için **15 saniye** var. Süre dolunca ekrandaki aralık kendiliğinden kilitlenir.

1. **Tahmin:** En iyi tahminini uygulamanın kendi sayı klavyesiyle yaz.
2. **Aralık:** Bir kaydırıcıyla aralığın genişliğini ayarla. Ekranda canlı olarak "4.500 – 5.500 m" görünür, isabet edersen kaç puan alacağın da yazar.
3. **Kilitle:** Cevap, aralığın üstünde bir işaretle gösterilir. Yanında puanın, kaynak linki ve ilginç bir bilgi yer alır.

**Puan:** İsabette en fazla 100 puan alırsın, dar aralık daha çok puan getirir. Kıl payı ıska yine puan alabilir, uzak ıska eksi puandır (en düşük −50). Süre dolduğunda hiç tahmin yazılmamışsa da −50 alınır. Kural bilerek dar aralık vermeyi kârsız kılar. En iyi strateji gerçekten %90 emin olduğun aralığı vermektir.

**Paylaşım:** Gün bitince sonuç iki şekilde paylaşılabilir:
- **Görsel:** Instagram hikâyesi ve WhatsApp durumu için 1080 × 1920'lik bir kart. Kartta günün tarihi, skoru, renkli kareler ve kalibrasyon var. Filozof maskotu skora göre beş hâlden birine bürünür: kahkahayla kas gösteren "Efsane!"den yağmur bulutu altındaki "Bugün olmadı."ya kadar. Metin de açıklama olarak eklenir.
- **Metin (Wordle tarzı):**
```
Kabaca · 4 Kasım · 380/500
🟩🟩🟨⬛🟩
Kalibrasyon %80
```
🟩 isabet ve ≥70 puan · 🟨 isabet ve <70 puan · ⬛ ıska

## Modlar
| Mod | Açıklama |
|---|---|
| **Günün seti** | Her gün 5 soru, soru başına 15 saniye. Herkes aynı gün aynı soruları görür. Yarıda bırakılırsa kaldığı yerden devam eder, ama başlamış bir sorunun süresi işlemeye devam eder. Tamamlanan ardışık günler **seriyi** oluşturur. |
| **Günün liderleri** | İsteğe bağlı. Giriş yok, bir takma adla katılırsın. Puanı sunucu hesaplar. Her günün tablosu ayrıdır ve yeni sorularla sıfırlanır. Oyuncu sayısı 100'e ulaşana kadar ilk 10, sonra ilk 50 gösterilir. Ayarlar'dan ayrılınca verin silinir. |
| **Bir tur at** (serbest mod) | Sınırsız, 5'erli turlar, süre sınırı yok. Daha önce cevapladığın hiçbir soru tekrar gelmez. Sorular geçmiş günlerin bankasından ve cihazda üretilen kuş uçuşu mesafe sorularından gelir. |
| **İstatistikler** | Oynanan gün, seri, en uzun seri, ortalama ve en iyi gün. Ayrıca zaman içindeki kalibrasyon grafiği, ıskaların yönü (tahminin fazla mı yüksek, fazla mı düşük) ve kategori bazında isabet. |

## Veri doğruluğu
Her sorunun cevabı kaynaklıdır ve sayılar asla elle yazılmaz. Kaynaklar ve lisansları: [docs/SOURCES.md](docs/SOURCES.md), uygulamada gösterilen atıflar: [docs/attributions.md](docs/attributions.md).
- Banka soruları Wikidata'dan çekilir. Kaynak linki her soruda görünür.
- Hangi öğelerin soru olacağına, Türkçe Vikipedi'deki son 12 aylık okunma sayısına bakılarak karar verilir. Böylece oyuncunun duymuş olabileceği şeyler sorulur.
- Mesafe soruları, Wikidata koordinatlarından cihazda hesaplanır.
- Değerleri birbiriyle çelişen öğeler bankaya alınmaz.

Yeni sorular uygulama güncellemesi gerekmeden GitHub Pages'ten indirilir. Gizlilik politikası: [docs/privacy-policy.md](docs/privacy-policy.md).

## Gelinen nokta (2026-11-04)
Uygulama Google Play'de **kapalı testte**. Test sürerken geliştirme devam ediyor.

**Tamamlananlar**
- Proje iskeleti, Türkçe sayı biçimi, tema (açık/koyu, sisteme göre)
- Wikidata veri hattı ve 1001 soruluk banka: coğrafya, tarih, Osmanlı, mimari, sanat, spor, Türkiye, gündelik, bilim (elementler, Nobel), şirketler, hayvanlar
- Zorluk tahmini (kolay/orta/zor) ve dengeli günlük takvim: her gün 2 kolay + 2 orta + 1 zor, en az 3 kategori (45 gün)
- Atıf altyapısı: tek kaynak listesi (`tools/sources.json`), Ayarlar → Veri kaynakları ve lisanslar ekranı, `docs/attributions.md`
- Soru ekranı: kendi sayı klavyesi, logaritmik/yıl kaydırıcısı, kilitleme, günün setinde 15 saniyelik geri sayım
- Puanlama: interval score, −50 tabanı, birim testleriyle doğrulanmış
- Sonuç ekranı, gün/tur özeti, yarıda kalan seti sürdürme
- Paylaşım: skora göre beş farklı maskotlu görsel kart (önizlemeli) ya da Wordle tarzı metin; günler tarihle anılır ("4 Kasım")
- Serbest mod: takvimin önümüzdeki 60 gününde olmayan banka soruları ve turda en fazla 1 mesafe sorusu (79 Türkiye şehri, 40 başkent)
- İnternetten içerik güncelleme (GitHub Pages, 6 saatte bir kontrol)
- Günün liderleri: isteğe bağlı takma adla katılım, Cloudflare Workers + D1 sunucusu (`server/leaderboard/`), puanı sunucu hesaplar
- İstatistik ekranı: kalibrasyon grafiği, ıska yönü, kategori bazında isabet
- Görsel kimlik: uygulama ikonundan türetilen renkler, kategori renkleri ve hafif animasyonlar
- Ayarlar: tema seçimi, liderlik tablosu (takma ad, ayrılma), veri kaynakları ve lisanslar, gizlilik politikası
- Uygulama ikonu (uyarlanabilir, yuvarlak, Android 13 tek renkli), gizlilik politikası
- İmzalı release paketi (AAB), kapalı test yayını
- 197 uygulama testi (birim ve widget) ve 22 sunucu testi, `flutter analyze` sıfır uyarı

**Sıradakiler**
- Liderlik sunucusunu Cloudflare'de yayına almak ve 1.0.2 sürümünü kapalı teste yüklemek
- Takvimi 15 Aralık 2026'dan önce uzatmak: yeni kolay sorular gerekiyor ([docs/SOURCES.md](docs/SOURCES.md), 3. adım ve sonrası)
- "Nasıl oynanır" ekranı
- Boyut ölçümü (hedef: indirme boyutu < 8 MB)
- Faz 2: günlük hatırlatma bildirimi, kategori seçimli pratik, rozetler

## Proje yapısı
```
lib/
  main.dart, app.dart     # giriş noktası, MaterialApp
  core/                   # saf iş mantığı: puan, aralık, süre, günlük seçim, ruh hâli, takma ad, sayı biçimi, istatistik, tema, metinler
  data/                   # soru modeli ve deposu, içerik senkronu, istatistik deposu, liderlik istemcisi, mesafe üreticisi
  features/               # ekranlar: intro, home, game, result, leaderboard, stats, settings
  widgets/                # ortak parçalar: sayı klavyesi, aralık çubuğu, filozof maskotu, kutucuklar
assets/                   # soru bankası, takvim ve yer verisi (JSON)
server/leaderboard/       # günün liderleri sunucusu: Cloudflare Worker + D1 (uygulamaya dahil değil)
tools/                    # Python veri hattı, ikon ve paylaşım kartı çizicileri (uygulamaya dahil değil)
docs/                     # plan, gizlilik politikası, mağaza ikonu, yayınlanan içerik (GitHub Pages)
test/                     # birim ve widget testleri
```

## Hızlı başlangıç
Windows'ta PowerShell ile:
```powershell
flutter pub get
flutter run            # bağlı cihaz veya emülatörde çalıştırır
flutter test           # tüm testler
flutter analyze        # statik analiz, sıfır uyarı beklenir
```
Veri hattı, release build ve diğer komutlar için [TECHNICAL.md](TECHNICAL.md), liderlik sunucusu için
[server/leaderboard/README.md](server/leaderboard/README.md) belgesine bak.
