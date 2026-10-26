# Manuel yapılacaklar

Claude'un yapamadığı ya da senin kararını bekleyen işler. Bitenleri sil.

## 3. Soru bankasına göz at (kapalı test başlamadan, isteğe bağlı)
Banka 2026-10-26'da yeniden kuruldu: 456 soru, 45 günlük takvim. Kapalı test başladıktan sonra
takvimdeki günler değiştirilemez (yalnızca sona eklenir), o yüzden gözden geçirmek için en iyi zaman şimdi.
`python tools/build_questions.py --fresh --dry-run --report` her veri setinde seçilenleri, zorluklarını ve sınırda kalanları listeler.
Çıkarmak istediğin ya da zorluğunu yanlış bulduğun soruları id'leriyle Claude'a söylemen yeterli
(zorluk düzeltmeleri `tools/difficulty_overrides.json`).

## 3b. (Ertelendi) TÜİK il nüfusu verisi
Portalda JSON indirme yolu bulunamadı (2026-10-26). Zorunlu değil, il nüfusu soruları olmadan banka yeterli.
TÜİK veri portalında "nüfus yoğunluğu" değil, il bazında **toplam nüfus** veren ADNKS göstergesini bul ve **JSON** olarak indir
(JSON uygun, dönüştürücüyü Claude yazar). Dosyayı `tools\tuik\` altına koy.

## 4. (İsteğe bağlı) Wikidata'daki hataları düzelt
Veri çekerken görülen hatalar. Wikidata'da düzeltilirse bir sonraki çekimde uygulamaya da gelir:
- Konya ilinin plaka kodu 53, Uşak'ın 62 girilmiş (doğrusu 42 ve 64).
- Bingöl ilinin "başkent" (P36) bilgisi yok, bu yüzden mesafe sorularında Bingöl yok.
- Çankırı şehrinin birbirinden >5 km farklı iki koordinatı var, bu yüzden Çankırı da şimdilik dışarıda.

## 5. Kapalı teste yükle (öncelikli: 14 günlük sayaç ancak yayınla başlar)
Her şey `play-store/` klasöründe hazır (git'e girmez):
- Adım adım rehber: `play-store/listing/play-console-rehberi.md` (uygulama oluşturma, içerik derecelendirmesi, veri güvenliği, kapalı test, 14 gün)
- Mağaza metinleri: `play-store/listing/magaza-metinleri.md`
- Paket: `play-store/release/kabaca-1.0.0+1.aab` (upload anahtarıyla imzalı) ve `kabaca-1.0.0+1-mapping.txt`
- Görseller: `play-store/graphics/` (simge, öne çıkan görsel), `play-store/screenshots/play/` (8 ekran görüntüsü)
- Test davet mesajı: `play-store/listing/test-daveti.md`
- Video (isteğe bağlı): `play-store/video/video-taslagi.md`
Upload anahtarını (`aralik-upload.jks`) ve `android/key.properties` dosyasını yedeklemeyi unutma.

## 6. Takvimi 15 Aralık 2026'dan önce uzat
Takvim 45 gün (1 Kasım – 15 Aralık). Uzatılmazsa 16 Aralık'ta günlük sorular başa sarar.
Yeni kolay sorular gerekiyor (SOURCES.md 3. adım ve sonrası), sonra `build_schedule.py` + `publish_content.py` + push. Uygulama güncellemesi gerekmez.
