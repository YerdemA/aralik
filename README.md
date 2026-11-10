<p align="center">
  <img src="docs/store/icon-512.png" width="128" alt="Kabaca simgesi">
</p>

<h1 align="center">Kabaca</h1>

<p align="center"><b>Tek bir sayı değil, %90 emin olduğun aralığı tahmin et.</b><br>
Türkçe günlük tahmin oyunu · Flutter · Cloudflare Workers<br>
<a href="https://kabaca.app">kabaca.app</a></p>

---

Kabaca'da sayısal bir soruya tek bir sayıyla değil, **%90 emin olduğun bir aralıkla** cevap verirsin:

> Ağrı Dağı kaç metre yüksekliktedir? → **4.500 – 5.500 m**

Aralık cevabı içeriyorsa puan alırsın; aralık ne kadar darsa puan o kadar yüksektir. Uzun vadede oyun
**kalibrasyonunu** ölçer: "%90 eminim" dediğinde gerçekten 10 sorunun 9'unu tutturuyor musun?

Oyun tasarımından mobil uygulamaya, gerçek zamanlı sunucudan veri hattına ve mağaza yayınına kadar tek
başıma geliştirdiğim, Google Play üzerinden dağıtılan bir uygulama.

## Özellikler
- **Günün seti:** Wordle gibi herkes aynı gün aynı 5 soruyu çözer; soru başına 15 saniye, seri, emoji ve görsel paylaşım kartı.
- **Düello:** Rastgele bir rakiple ya da oda koduyla gerçek zamanlı 1v1; bilgi ya da matematik, rövanş.
- **Turnuva:** 3–8 kişilik odalar, herkes aynı soruları aynı anda.
- **Sıralamalar:** İsteğe bağlı günün liderleri tablosu ve Elo tabanlı **aylık düello sıralaması**; ay sonunda indirilebilir kişisel istatistik kartı.
- **Matematik modu:** 27 konuda algoritmayla üretilen, hiç tükenmeyen sorular.
- **Maskot editörü:** Cinsiyet, ten, saç, saç rengi, sakal, bıyık, göz, gözlük ve şapka; 288.000 kombinasyon, düelloda ve paylaşım kartlarında görünür.
- **İstatistikler:** Zaman içindeki kalibrasyon grafiği, ıskaların yönü, kategori bazında isabet.

## Teknik öne çıkanlar
- **Dürüstlüğü ödüllendiren puanlama.** Puan, Gneiting & Raftery'nin *interval score* kuralına dayanır. Bilerek dar aralık vermek kazandırmaz; en kârlı stratejinin gerçekten %90'lık aralık olduğu, sayısal integralle birim testte doğrulanır.
- **Sunucuya güvenilir sonuç.** Puanları istemci değil sunucu hesaplar. Dart ve JavaScript'teki iki uygulama ortak test vektörleriyle eşit tutulur (puan formülü ve 3.240 matematik sorusu; iki tarafta aynı tohumlu rastgele sayı üreteci).
- **Gerçek zamanlı çok oyunculu oyun, ücretsiz katmanda.** Her düello ve turnuva odası bir Cloudflare Durable Object'tir; WebSocket Hibernation sayesinde boşta maliyetsizdir. Kopan bağlantılar sessizlikten anlaşılır, uygulama kendiliğinden geri bağlanır. Kurallar, "bağlantıyı kes, cevabı ara, geri dön" hilesini kazançsız kılacak biçimde tasarlandı.
- **Çevrimdışı öncelikli.** Oyun internetsiz eksiksiz çalışır. Yeni sorular uygulama güncellemesi olmadan GitHub Pages'ten iner ve yalnızca gömülü verinin birebir devamıysa kabul edilir.
- **Kaynaklı veri hattı.** Python betikleri 15 açık veri kaynağından (Wikidata, Dünya Bankası, Eurostat, NASA, USGS, FAO, İBB…) 2.151 soru üretir. Her cevabın kaynak bağlantısı vardır, sayılar elle yazılmaz. Zorluk, Türkçe Vikipedi okunma sayılarından tahmin edilir; lisans ve atıflar otomatik derlenir.
- **Neredeyse sıfır bağımlılık.** Yalnızca iki paket (`shared_preferences`, `share_plus`). HTTP ve WebSocket `dart:io` ile; uygulama ikonu, maskot ve paylaşım kartları `CustomPaint` ile çizilir; ses efektleri bir Python betiğiyle sentezlenir. Yerel işler küçük Kotlin ve Swift kanallarıyla yapılır (ses, galeri, vekil sunucu, cihaz anahtarı).
- **Gizlilik.** Hesap, reklam ve analitik yok. Tabloya katılmayan oyuncunun verisi cihazdan çıkmaz; katılanlar için hile önlemi, cihaz kimliğinin tek yönlü özetiyle cihaz başına tek hesaptır.
- **Kalite.** 398 Flutter ve 116 sunucu testi; `flutter analyze` sıfır uyarı. iOS sürümü GitHub Actions'ta derlenir.

## Teknolojiler
| Katman | Kullanılan |
|---|---|
| Mobil | Flutter, Dart, Material 3; Android (Kotlin) ve iOS (Swift) kanalları |
| Sunucu | Cloudflare Workers, D1 (SQLite), Durable Objects, WebSocket |
| Veri | Python 3 (yalnızca standart kütüphane), Wikidata SPARQL, açık veri API'leri |
| Yayın | GitHub Pages (içerik ve gizlilik politikası), GitHub Actions (iOS derlemesi), Google Play |

## Proje yapısı
```
lib/                  Flutter uygulaması
  core/               saf iş mantığı: puanlama, aralık, takvim, düello ve turnuva protokolü, matematik üreteçleri
  data/               kalıcılık, içerik senkronu, ağ istemcileri
  features/           ekranlar
  widgets/            ortak bileşenler ve CustomPaint çizimleri
server/leaderboard/   Cloudflare Worker: liderlik, düello, turnuva, aylık sıralama ve kabaca.app sitesi
tools/                Python veri hattı ve görsel üreticiler
test/                 birim ve widget testleri
docs/                 GitHub Pages: yayınlanan içerik, gizlilik politikası, atıflar
```

## Bağlantılar
- Web sitesi: [kabaca.app](https://kabaca.app)
- [Gizlilik politikası](docs/privacy-policy.md) · [Veri kaynakları ve lisanslar](docs/attributions.md)

## Geliştirici
**Yusuf Erdem Aykaç** · [github.com/YerdemA](https://github.com/YerdemA)
