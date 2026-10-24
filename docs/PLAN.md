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
