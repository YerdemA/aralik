# Kabaca

**%90 emin olduğun aralığı ver.**

Kabaca, 5–10 dakikalık beklemelerde oynanan Türkçe bir günlük tahmin oyunudur (Android, Flutter).
Sayısal bir soruya tek bir sayıyla değil, **%90 emin olduğun bir aralıkla** cevap verirsin:

> Ağrı Dağı kaç metre yüksekliktedir? → **4.500 – 5.500 m**

Aralık cevabı içeriyorsa puan alırsın. Aralık ne kadar darsa puan o kadar yüksek olur. Uzun vadede oyun
**kalibrasyonunu** ölçer: "%90 eminim" dediğinde gerçekten 10 sorunun 9'unu tutturuyor musun?

- Geliştirici: Yusuf Erdem Aykaç ([YerdemA](https://github.com/YerdemA))
- Paket: `com.yerdema.kabaca` · Hedef: Google Play, Android 7.0+ (minSdk 24)

## Neden?
- Bilgi yarışmaları "doğru / yanlış" mantığıyla çalışır. Kabaca ise **ne kadar emin olduğunu** ölçer. Bu ölçüm, bildiğin şeyden çok kendini ne kadar iyi tanıdığını gösterir.
- İçerik Türkçe ve yereldir: Türkiye coğrafyası, tarihi, sporu.
- Wordle gibi herkes aynı gün aynı soruları çözer. Skorunu emoji kartıyla paylaşabilirsin.
- **Sıfır bütçe, neredeyse sıfır backend.** Hesap, reklam ve analytics yok. Oyun internetsiz de eksiksiz çalışır. Tek sunucu, isteğe bağlı **günün liderleri** tablosu, **düello** ve **turnuva** odalarıdır: katılmayan oyuncunun hiçbir verisi cihazdan çıkmaz.

## Nasıl oynanır?
Günün setinde her soru için **15 saniye** var. Süre dolunca ekrandaki aralık kendiliğinden kilitlenir.

1. **Tahmin:** En iyi tahminini uygulamanın kendi sayı klavyesiyle yaz.
2. **Aralık:** Bir kaydırıcıyla aralığın genişliğini ayarla. Ekranda canlı olarak "4.500 – 5.500 m" görünür, isabet edersen kaç puan alacağın da yazar.
3. **Kilitle:** Cevap, aralığın üstünde bir işaretle gösterilir. Yanında puanın, kaynak linki ve ilginç bir bilgi yer alır.

**Puan:** İsabette en fazla 100 puan alırsın, dar aralık daha çok puan getirir. Kıl payı ıska yine puan alabilir, uzak ıska eksi puandır (en düşük −50). Süre dolduğunda hiç tahmin yazılmamışsa da −50 alınır. Kural bilerek dar aralık vermeyi kârsız kılar. En iyi strateji gerçekten %90 emin olduğun aralığı vermektir.
Aralığın ne kadar genişleyebileceği soruya göre değişir: eski bir olayın yılı ya da nüfus gibi geniş bir büyüklük için kaydırıcı daha geniş açılır. Yüzde sorularında aralık tahminin en fazla 20 puan altına ve üstüne açılır, 100'ü geçmez. Kaydırıcının en ucunda isabet her soruda aynı puanı getirir.

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
| **Günün liderleri** | İsteğe bağlı. Giriş yok, Ayarlar'da seçtiğin kullanıcı adıyla katılırsın (düello ve turnuvada da aynı ad). Puanı sunucu hesaplar. Her günün tablosu ayrıdır ve yeni sorularla sıfırlanır. Oyuncu sayısı 100'e ulaşana kadar ilk 10, sonra ilk 50 gösterilir; ilk üç altın, gümüş ve bronz çerçeveli. Ad yalnızca Ayarlar'da, 3 günde bir değiştirilebilir. Tablodan ayrılınca sunucudaki puanların silinir, adın telefonda kalır. |
| **Düello** | Gerçek zamanlı 1v1, iki türü var: **bilgi** (bankadan sorular, soru başına 15 saniye) ve **matematik** (hesapla üretilen sorular, soru başına 30 saniye, eksi puan yok). Lobide türü seç, rastgele bir rakip bul ya da oda kurup kodu arkadaşına gönder. İkiniz aynı 5 soruyu aynı anda cevaplarsınız. Her sorudan sonra iki aralık yan yana gösterilir, toplamı yüksek olan kazanır. Hesap gerekmez; görünen ad Ayarlar'dan seçilir. Bağlantı koparsa uygulama kendiliğinden geri bağlanır ve düello kaldığı yerden sürer (düello boyunca toplam 45 saniye uzak kalma hakkı; açık soru beklemez, böylece bağlantıyı kesip cevap aramak işe yaramaz). Uygulamayı kapatsan bile ana ekrandan düelloya dönebilir ya da teslim olabilirsin. Bitince ikiniz de isterseniz **rövanş**: aynı oda, yeni sorular, kod ya da arama yok. |
| **Turnuva** | 3–8 kişilik oda. Biri kurar, kodu girenler katılır; kurucu (taç ikonlu) 5 ya da 10 soru seçer, istediğini odadan çıkarır, en az 3 kişiyle başlatır. Herkes aynı soruları aynı anda çözer; her sorudan sonra herkesin aralığı puana göre sıralı görünür. Sonda sıralama ve kimin kaç soruda isabet ettiği gösterilir, oda yeniden başlatılabilir. Bağlantısı kopan oyuncu maç bitene kadar geri dönebilir. |
| **Bir tur at** (serbest mod) | Sınırsız, 5'erli turlar, süre sınırı yok. Daha önce cevapladığın hiçbir soru tekrar gelmez. Sorular geçmiş günlerin bankasından ve cihazda üretilen kuş uçuşu mesafe sorularından gelir. Tur sonucu da paylaşılabilir ("Serbest tur"). |
| **Matematik** | Tamamen algoritmayla üretilen sorular; cevap kaynaktan değil hesaptan gelir, havuz tükenmez. **Temel** (çarpma, üs, kök, faktöriyel, kombinasyon, faiz, yüzde, birim, geometri, olasılık, asal sayılar, Fibonacci, kâğıt katlama…) ya da **ileri** (trigonometri, limit, türev, integral, logaritma, üstel büyüme, diziler, istatistik, matris, karmaşık sayılar, vektörler, sayılar teorisi) seçilir; 27 konu, her biri 3 zorlukta. Soru başına 60 saniye. Kaydırıcı en fazla ÷2 … ×2 açılır, isabetli tahmin çok puan getirir, eksi puan yoktur. Sonuçta kaynak yerine çözüm gösterilir; kalibrasyonu ayrı tutulur. |
| **İstatistikler** | Oynanan gün, seri, en uzun seri, ortalama ve en iyi gün. Ayrıca zaman içindeki kalibrasyon grafiği, ıskaların yönü (tahminin fazla mı yüksek, fazla mı düşük), kategori bazında isabet ve ayrı matematik kalibrasyonu. |

**İlk açılış:** Kısa bir tanıtım ana ekrandaki kartları ve ilk sorudaki tahmin, aralık ve kilitleme adımlarını tek tek gösterir (anlatım sürerken süre işlemez). Ayarlar'dan yeniden oynatılabilir.

**Bağlantı testi:** Liderlik ya da düello bir ağda çalışmıyorsa Ayarlar → Bağlantı testi nedenini adım adım bulur (DNS, vekil sunucu, şifreli bağlantı denetimi, WebSocket). Uygulama Android'in vekil sunucu ayarını da kullanır.

**Sesler:** Açılışta kısa bir çan, her dokunuşta hafif bir tık, sayfa geçişlerinde yumuşak bir hışırtı; kilitleme, sonuç, son saniyeler ve düello için ayrı sesler. Hepsi bir betikle sentezlenir (kayıt yok, lisans yok) ve küçük Ogg dosyaları olarak gömülüdür. Telefon sessizdeyken çalmaz, Ayarlar'dan kapatılabilir.

## Veri doğruluğu
Her sorunun cevabı kaynaklıdır ve sayılar asla elle yazılmaz. Kaynak listesi: [tools/sources.json](tools/sources.json), uygulamada gösterilen atıflar: [docs/attributions.md](docs/attributions.md).
- Banka soruları Wikidata'dan çekilir. Kaynak linki her soruda görünür.
- Hangi öğelerin soru olacağına, Türkçe Vikipedi'deki son 12 aylık okunma sayısına bakılarak karar verilir. Böylece oyuncunun duymuş olabileceği şeyler sorulur.
- Mesafe soruları, Wikidata koordinatlarından cihazda hesaplanır.
- Değerleri birbiriyle çelişen öğeler bankaya alınmaz.

- Matematik soruları cihazda tohumlu bir üreteçle hesaplanır; metin gereken her varsayımı söyler (365 günlük yıl, 0,1 mm kâğıt, g = 9,81). Matematik düellosunda sunucu aynı cevapları kendisi hesaplar; iki taraf 3.240 örnekle test edilir.

Yeni sorular uygulama güncellemesi gerekmeden GitHub Pages'ten indirilir. Gizlilik politikası: [docs/privacy-policy.md](docs/privacy-policy.md). Web sitesi: [kabaca.app](https://kabaca.app).

## Proje yapısı
```
lib/
  main.dart, app.dart     # giriş noktası, MaterialApp
  core/                   # saf iş mantığı: puan, aralık, süre, günlük seçim, ruh hâli, takma ad, sayı biçimi, istatistik, tema, metinler
    math/                 # matematik soru üreteçleri (27 konu), tohumlu rastgele sayı üreteci
  data/                   # soru modeli ve deposu, içerik senkronu, istatistik deposu, liderlik, düello ve turnuva istemcileri, sesler, mesafe üreticisi
  features/               # ekranlar: intro, home, game, result, duel, tournament, math, leaderboard, stats, settings
  widgets/                # ortak parçalar: sayı klavyesi, aralık çubuğu, filozof maskotu, tanıtım katmanı, kutucuklar
assets/                   # soru bankası, takvim ve yer verisi (JSON), ses efektleri (Ogg)
server/leaderboard/       # liderlik, düello ve turnuva sunucusu ve kabaca.app sitesi: Cloudflare Worker + D1 + Durable Objects (uygulamaya dahil değil)
tools/                    # Python veri hattı, ikon ve paylaşım kartı çizicileri (uygulamaya dahil değil)
docs/                     # gizlilik politikası, atıflar, mağaza ikonu, yayınlanan içerik (GitHub Pages)
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
Liderlik, düello ve turnuva sunucusu için [server/leaderboard/README.md](server/leaderboard/README.md) belgesine bak.
