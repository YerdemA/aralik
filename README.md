# Aralık

**%90 emin olduğun aralığı ver.**

Aralık, 5–10 dakikalık beklemelerde oynanan Türkçe bir günlük tahmin oyunudur (Android, Flutter).
Sayısal bir soruya tek bir sayıyla değil, **%90 emin olduğun bir aralıkla** cevap verirsin:

> Ağrı Dağı kaç metre yüksekliktedir? → **4.500 – 5.500 m**

Aralık cevabı içeriyorsa puan alırsın. Aralık ne kadar darsa puan o kadar yüksek olur. Uzun vadede oyun
**kalibrasyonunu** ölçer: "%90 eminim" dediğinde gerçekten 10 sorunun 9'unu tutturuyor musun?

- Geliştirici: Yusuf Erdem Aykaç ([YerdemA](https://github.com/YerdemA))
- Paket: `com.yerdema.aralik` · Hedef: Google Play, Android 7.0+ (minSdk 24)
- Teknik belge: [TECHNICAL.md](TECHNICAL.md) · Yol haritası: [docs/PLAN.md](docs/PLAN.md)

## Neden?
- Bilgi yarışmaları "doğru / yanlış" mantığıyla çalışır. Aralık ise **ne kadar emin olduğunu** ölçer. Bu ölçüm, bildiğin şeyden çok kendini ne kadar iyi tanıdığını gösterir.
- İçerik Türkçe ve yereldir: Türkiye coğrafyası, tarihi, sporu.
- Wordle gibi herkes aynı gün aynı soruları çözer. Skorunu emoji kartıyla paylaşabilirsin.
- **Sıfır bütçe, sıfır backend.** Sunucu, hesap, reklam ve analytics yok. Oyun internetsiz de eksiksiz çalışır ve hiçbir kişisel veri cihazdan çıkmaz.

## Nasıl oynanır?
1. **Tahmin:** En iyi tahminini uygulamanın kendi sayı klavyesiyle yaz.
2. **Aralık:** Bir kaydırıcıyla aralığın genişliğini ayarla. Ekranda canlı olarak "4.500 – 5.500 m" görünür, isabet edersen kaç puan alacağın da yazar.
3. **Kilitle:** Cevap, aralığın üstünde bir işaretle gösterilir. Yanında puanın, kaynak linki ve ilginç bir bilgi yer alır.

**Puan:** İsabette en fazla 100 puan alırsın, dar aralık daha çok puan getirir. Kıl payı ıska yine puan alabilir, uzak ıska eksi puandır (en düşük −100). Kural bilerek dar aralık vermeyi kârsız kılar. En iyi strateji gerçekten %90 emin olduğun aralığı vermektir.

**Paylaşım kartı:**
```
Aralık #42 · 380/500
🟩🟩🟨⬛🟩
Kalibrasyon %80
```
🟩 isabet ve ≥70 puan · 🟨 isabet ve <70 puan · ⬛ ıska

## Modlar
| Mod | Açıklama |
|---|---|
| **Günün seti** | Her gün 5 soru. Herkes aynı gün aynı soruları görür. Yarıda bırakılırsa kaldığı yerden devam eder. Tamamlanan ardışık günler **seriyi** oluşturur. |
| **Serbest mod** | Sınırsız, 5'erli turlar. Daha önce cevapladığın hiçbir soru tekrar gelmez. Sorular geçmiş günlerin bankasından ve cihazda üretilen kuş uçuşu mesafe sorularından gelir. |
| **İstatistikler** | Oynanan gün, seri, en uzun seri, ortalama ve en iyi gün. Ayrıca zaman içindeki kalibrasyon grafiği, ıskaların yönü (tahminin fazla mı yüksek, fazla mı düşük) ve kategori bazında isabet. |

## Veri doğruluğu
Her sorunun cevabı kaynaklıdır ve sayılar asla elle yazılmaz:
- Banka soruları Wikidata'dan çekilir. Kaynak linki her soruda görünür.
- Hangi öğelerin soru olacağına, Türkçe Vikipedi'deki son 12 aylık okunma sayısına bakılarak karar verilir. Böylece oyuncunun duymuş olabileceği şeyler sorulur.
- Mesafe soruları, Wikidata koordinatlarından cihazda hesaplanır.
- Değerleri birbiriyle çelişen öğeler bankaya alınmaz.

Yeni sorular uygulama güncellemesi gerekmeden GitHub Pages'ten indirilir. Gizlilik politikası: [docs/privacy-policy.md](docs/privacy-policy.md).

## Gelinen nokta (2026-10-26)
**Tamamlananlar**
- Proje iskeleti, Türkçe sayı biçimi, tema (açık/koyu, sisteme göre)
- Wikidata veri hattı ve 213 soruluk banka (coğrafya, tarih, spor, Türkiye, gündelik)
- Soru ekranı: kendi sayı klavyesi, logaritmik/yıl kaydırıcısı, kilitleme
- Puanlama: interval score, birim testleriyle doğrulanmış
- Sonuç ekranı, gün/tur özeti, paylaşım, yarıda kalan seti sürdürme
- Serbest mod ve cihazda üretilen mesafe soruları (79 Türkiye şehri, 40 başkent)
- İnternetten içerik güncelleme (GitHub Pages, 6 saatte bir kontrol)
- İstatistik ekranı: kalibrasyon grafiği, ıska yönü, kategori bazında isabet
- Görsel kimlik: ikondaki manzaradan türetilen renkler, kodla çizilen manzara, kategori renkleri ve hafif animasyonlar
- Uygulama ikonu (uyarlanabilir, yuvarlak, Android 13 tek renkli), gizlilik politikası
- İmzalı release paketi (AAB)
- 127 birim ve widget testi, `flutter analyze` sıfır uyarı

**Sıradakiler**
- Google Play kapalı teste yükleme (14 gün, en az 12 test kullanıcısı)
- Açık geri bildirimler: günlük sorular çok zor, serbest mod hep mesafe soruyor, puanlama kolay görünüyor. Ayrıntılar [docs/PLAN.md](docs/PLAN.md) içinde.
- Soru bankasını 450 soruya çıkarmak (≈ 90 gün)
- Ayarlar ekranı (tema seçimi, nasıl oynanır, gizlilik, hakkında) ve ilk açılış tanıtımı
- Boyut ölçümü (hedef: indirme boyutu < 8 MB) ve mağaza sayfası
- Faz 2: günlük hatırlatma bildirimi, kategori seçimli pratik, rozetler

## Proje yapısı
```
lib/
  main.dart, app.dart     # giriş noktası, MaterialApp
  core/                   # saf iş mantığı: puan, aralık, günlük seçim, sayı biçimi, istatistik, tema, metinler
  data/                   # soru modeli, soru deposu, içerik senkronu, istatistik deposu, mesafe üreticisi
  features/               # ekranlar: home, game, result, stats
  widgets/                # ortak parçalar: sayı klavyesi, aralık çubuğu, manzara, kutucuklar
assets/                   # soru bankası ve yer verisi (JSON)
tools/                    # Python veri hattı ve ikon üretici (uygulamaya dahil değil)
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
Veri hattı, release build ve diğer komutlar için [TECHNICAL.md](TECHNICAL.md) belgesine bak.
