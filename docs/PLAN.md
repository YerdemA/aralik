# Aralık — Proje Planı

> Günlük Türkçe tahmin oyunu: Tek bir sayı tahmin etme, **%90 emin olduğun aralığı** ver.
> Repo: `YerdemA/aralik` · Paket: `com.yerdema.aralik`

## Neden farklı?
- Piyasadaki bilgi yarışmaları "doğru/yanlış" mantığıyla çalışır. Aralık ise **ne kadar emin olduğunu** ölçer.
- Türkçe ve yerel içerik sunar (TÜİK, Türkiye coğrafyası ve tarihi).
- Wordle gibi herkes aynı gün aynı soruları çözer. Bu, arkadaş arasında karşılaştırmayı ve paylaşımı doğal hâle getirir.
- Kalibrasyon skoru, kullanıcının kendini tanımasını sağlayan ve geri dönme sebebi olan bir metriktir.

## Bütçe
- Tek zorunlu masraf: Google Play Console tek seferlik kayıt ücreti (25 $).
- Diğer her şey ücretsiz: Flutter, Wikidata, TÜİK, GitHub, GitHub Pages (gizlilik politikası).

## MVP kapsamı (v1.0)
1. Ana ekran: günün seti butonu, seri, son skor, kalibrasyon özeti
2. Soru ekranı: tahmin girişi, aralık kaydırıcısı, kilitle
3. Sonuç ekranı: cevap, aralığın cevaba göre konumu (görsel çubuk), puan, kaynak, ilginç bilgi
4. Gün özeti ve paylaş (emoji skor kartı)
5. Pratik modu (geçmiş günlerin soruları)
6. İstatistikler: toplam oyun, ortalama puan, kalibrasyon, kategori bazlı isabet
7. Ayarlar: tema (açık/koyu/sistem), nasıl oynanır, gizlilik, hakkında
8. İlk açılışta 3 adımlık "nasıl oynanır" ekranı

**Faz 2 (v1.1, yayından sonra):** günlük bildirim, kategori seçimli pratik, rozetler.

**İnternetten yeni sorular** (not 2026-10-24, uygulandı 2026-10-26: `data/content_sync.dart`, `tools/publish_content.py`)
- Fikir: Ek soru paketleri GitHub Pages'te statik JSON olarak tutulur (ücretsiz, sunucu yok). Uygulama ara sıra indirip cache'ler, internet yoksa gömülü bankayla devam eder.
- Etkiledikleri:
  - INTERNET izni release manifest'e geri eklenmeli.
  - Gizlilik politikası ve Play "Veri güvenliği" formu güncellenmeli. GitHub sunucusu IP adresini görür.
  - CLAUDE.md'deki "tamamen offline" ilkesi esnetilmeli.
  - HTTP için yeni paket gerekmez, `dart:io` `HttpClient` yeterli.
- Kural: İndirilen sorular da `validate_questions.py` ile doğrulanır ve kaynaklıdır. Paketler imzalanmalı ya da en azından sürüm ve sağlama toplamı (hash) ile kontrol edilmeli. Günlük setler gömülü bankadan gelmeye devam eder, böylece herkes aynı soruları görür. İndirilen paketler yalnızca serbest modu besler.

## Açık geri bildirimler (2026-10-26)
Geliştiricinin emülatörde oynadıktan sonra aldığı notlar.

1. **Günlük 5 soru hâlâ çok zor.** *Durum (2026-10-26): ele alındı, izlenecek.* Sorulara tahmini zorluk eklendi ve günlük takvim artık her gün 2 kolay + 2 orta + 1 zor soru veriyor, kolaydan zora sıralı. Banka 456 soruya çıktı, bilim, şirketler ve hayvanlar kategorileri eklendi. Takvim 45 gün. Uzatmak için yeni **kolay** soru kaynakları gerekiyor (SOURCES.md, 3. adım ve sonrası).
   - Banka (213 soru) Türkçe Vikipedi okunma sayısına göre seçildi. Yine de sorular ülke nüfusu/yüzölçümü, köprü uzunluğu, savaş yılı gibi çoğu oyuncunun hiç düşünmediği büyüklükler ağırlıklı.
   - Dağılım dengesiz: coğrafya 95, tarih 52, spor 32, türkiye 30, gündelik 4, bilim 0.
   - Olası yönler: "gündelik" ve "türkiye" gibi sezgiyle tahmin edilebilir soruları artırmak, setin içinde kolaydan zora sıralamak, her güne en az bir kolay soru koymak, okunma eşiğini yükseltmek.
   - Banka yalnızca sona eklenebildiği için kapalı test başlamadan önce karar vermek en ucuzu. O zamana kadar `--fresh` ile baştan kurulabilir.
2. **Serbest moddaki bütün sorular kuş uçuşu mesafe.** *Durum (2026-10-26): çözüldü.* Serbest mod artık takvimin önümüzdeki 60 gününde olmayan banka sorularını kullanıyor (şu an 231 soru) ve turda en fazla 1 mesafe sorusu var.
   - Neden: serbest mod soruların ~1/3'ünü *geçmiş günlerin* banka sorularından alır (`core/free_play.dart`, `bankShare`). Oyun 2026-11-01'de başladığı için bugün geçmiş gün yok (`practiceIndices` boş döner), bu yüzden turun tamamı mesafe üreticisinden geliyor.
   - Yayından sonra da ilk haftalarda geçmiş soru az olacak ve tek üretici mesafe olduğu için çeşit sınırlı kalacak.
   - Olası yönler: yeni cihaz üreticileri (il nüfusu, ülke nüfusu/yüzölçümü karşılaştırması, dağ yükseklikleri gibi kaynaklı tablolardan), günlük sete hiç girmeyecek ayrı bir "serbest mod bankası", tek turda en fazla 1–2 mesafe sorusu sınırı.
3. **Aralık vererek puan almak kolay görünüyor (emin değil).** *Durum: açık.*
   - Rakamlar: kaydırıcının varsayılan konumu (0,3) tahminin ÷2 … ×2 aralığını verir (log2 genişlik 2). İsabette bu 80 puan ve 🟩 eder. En geniş aralık (÷10 … ×10) bile isabette 34 puan alır. Ekran görüntüsünde 240 – 1.000 km (4 kat geniş) aralık 79 puan aldı.
   - Puanlama kuralı dürüst %90 aralığını ödüllendirecek şekilde kurulu (`test/core/scoring_test.dart`). Bu yüzden "kolay" hissi büyük olasılıkla kuraldan değil, ölçekten geliyor: k = 10 ve 🟩 eşiği ≥70.
   - Değiştirilebilecekler: k'yı büyütmek (aynı genişlik daha az puan), 🟩 eşiğini yükseltmek, varsayılan kaydırıcı konumunu daraltmak. k ile −100 tabanı birlikte ayarlanmalı, yoksa dürüst aralığın en iyi strateji olma özelliği bozulur. Değişiklikten sonra test yeniden doğrulanmalı.
   - Karar vermeden önce birkaç gün gerçek oyun verisine (istatistik ekranı) bakmak faydalı olur.

## Takvim (14 gün)
> Kapalı test 14 gün kesintisiz sürmeli ve en az 12 test kullanıcısı gerekiyor. Bu yüzden **5. günde** kapalı teste çıkılır, geliştirme test sürerken devam eder.

| Gün | İş |
|---|---|
| **0 (bugün)** | Play Console hesabı aç (kimlik doğrulaması birkaç gün sürebilir). 12–15 test kullanıcısının Gmail adreslerini topla. |
| **1** | Flutter projesi, klasör yapısı, tema, strings. `tools/` Wikidata scripti, ilk 150 soru. |
| **2** | Model, repository, günlük seçim, puanlama ve unit testleri. |
| **3** | Soru ekranı (tahmin ve aralık girişi). Buradaki his oyunun kalbidir, en çok bu ekrana zaman ayır. |
| **4** | Sonuç ekranı, gün özeti, paylaşım, ana ekran. |
| **5** | İkon, gizlilik politikası, release build, **kapalı teste yükle**. 14 günlük sayaç başlar. |
| **6–7** | Pratik modu, istatistikler. Soru bankasını 450'ye çıkar (TÜİK, mesafeler). |
| **8–9** | Onboarding, ayarlar, koyu tema, boş durumlar, hata durumları. |
| **10–11** | Test kullanıcısı geri bildirimleri, cila (animasyon, titreşim, ses yok). |
| **12–13** | Performans ve boyut ölçümü, store listesi (ekran görüntüleri, açıklama). |
| **14** | Son sürüm kapalı teste. **Gün ~19:** üretim erişimine başvur ve yayınla. |

## Soru bankası hattı
1. `tools/fetch_wikidata.py`: SPARQL ile dağlar, nehirler, şehir nüfusları, yapılar, olay yılları çekilir.
2. `tools/tuik/`: TÜİK'ten elle indirilen CSV'ler ve dönüştürücü.
3. `tools/build_questions.py`: Şablonlar veriyle doldurulur, karıştırılır ve `assets/questions/questions.json` oluşturulur.
4. `tools/validate_questions.py`: Zorunlu alanları, benzersiz id'leri, kaynak linkini ve yinelenen soruları kontrol eder.
5. İnsan kontrolü: belirsiz veya çok kolay sorular elenir.
6. Claude soru metinlerini akıcılaştırmak için kullanılabilir. **Sayılar asla Claude'dan alınmaz.**

Hedef: v1'de 450 soru (90 gün). Her güncellemede yeni sorular eklenir.

## Boyut ve performans hedefleri
- AAB'den üretilen indirme boyutu < 8 MB
- Soğuk açılış < 1 sn (orta seviye cihaz)
- 60 fps kaydırıcı ve animasyonlar
- İnternet izni yok (`INTERNET` permission release manifest'inden kaldırılır)

## Başarı ölçütleri (kapalı test)
- Test kullanıcılarının çoğu 14 günün yarısından fazlasında günlük seti oynuyor mu?
- "Bu soru çok kolay/zor" geri bildirim dağılımı
- Paylaşım metnini kullanan oldu mu?
