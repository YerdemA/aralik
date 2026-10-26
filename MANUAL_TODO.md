# Manuel yapılacaklar

Claude'un yapamadığı ya da senin kararını bekleyen işler. Bitenleri sil.

## 3. Soru bankasına göz at (31 Ekim'e kadar, isteğe bağlı)
Banka 2026-10-26'da Türkçe Vikipedi okunma sayılarına göre yeniden kuruldu (213 soru).
`python tools/build_questions.py --fresh --dry-run --report` her veri setinde seçilenleri ve sınırda kalanları okunma sayılarıyla listeler.
Çıkarmak istediğin soruları id'leriyle Claude'a söylemen yeterli.

## 3b. (Ertelendi) TÜİK il nüfusu verisi
Portalda JSON indirme yolu bulunamadı (2026-10-26). Zorunlu değil, il nüfusu soruları olmadan banka yeterli.
TÜİK veri portalında "nüfus yoğunluğu" değil, il bazında **toplam nüfus** veren ADNKS göstergesini bul ve **JSON** olarak indir
(JSON uygun, dönüştürücüyü Claude yazar). Dosyayı `tools\tuik\` altına koy.

## 4. (İsteğe bağlı) Wikidata'daki hataları düzelt
Veri çekerken görülen hatalar. Wikidata'da düzeltilirse bir sonraki çekimde uygulamaya da gelir:
- Konya ilinin plaka kodu 53, Uşak'ın 62 girilmiş (doğrusu 42 ve 64).
- Bingöl ilinin "başkent" (P36) bilgisi yok, bu yüzden mesafe sorularında Bingöl yok.
- Çankırı şehrinin birbirinden >5 km farklı iki koordinatı var, bu yüzden Çankırı da şimdilik dışarıda.

## 5. Kapalı teste yükle (5. gün)
İmzalı paket hazır: `build\app\outputs\bundle\release\app-release.aab` (upload anahtarıyla imzalı, 2026-10-26 doğrulandı).
1. Play Console → uygulama oluştur (`com.yerdema.aralik`) → Test → Kapalı test → yeni sürüm → AAB'yi yükle.
2. `build\symbols` klasörünü sakla (çökme raporlarını çözmek için gerekli, git'e girmez).
3. Test kullanıcılarının (en az 12) e-postalarını listeye ekle. 14 günlük sayaç yayınlandığı an başlar.
4. Gizlilik politikası URL'si: GitHub Pages'teki `privacy-policy` sayfası. Veri güvenliği formu: veri toplanmıyor.
5. `android/key.properties` ve `aralik-upload.jks` dosyalarını güvenli bir yere yedekle. Kaybolursa güncelleme yüklenemez.
