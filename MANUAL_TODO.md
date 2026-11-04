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

## 5b. Yeni sürümü yükle (1.0.1+2)
**Henüz yüklemediysen bunu atla:** 1.0.2+3 (7. madde) bu sürümün her şeyini içerir. Mağaza girişi güncellemesi yine geçerli.
Ana ekran ve renkler değişti, serbest modun adı "Bir tur at" oldu, yeni kategoriler geldi (Osmanlı, Mimari, Sanat). Sorular yayında; eski sürümde yeni kategoriler "Diğer" görünür.
- Yükle: `play-store/release/kabaca-1.0.1+2.aab`, mapping ve symbols dosyaları; sürüm notu `play-store/listing/play-console-rehberi.md` içinde.
- Mağaza girişini güncelle: `magaza-metinleri.md` uzun açıklaması, `play-store/graphics/`, `play-store/screenshots/play/`.

## 6. Takvimi 15 Aralık 2026'dan önce uzat
Takvim 45 gün (1 Kasım – 15 Aralık). Uzatılmazsa 16 Aralık'ta günlük sorular başa sarar.
Yeni kolay sorular gerekiyor (SOURCES.md 3. adım ve sonrası), sonra `build_schedule.py` + `publish_content.py` + push. Uygulama güncellemesi gerekmez.

## 7. Süre sınırı + Günün liderleri (1.0.2+3) — sırayla
Kod, testler, sunucu ve paket hazır. Kalan her adım senin hesaplarınla ilgili. Ayrıntılı komutlar: `server/leaderboard/README.md`.

**a) Kaydet.** Değişiklikler commit edilmedi (CLAUDE.md, SOURCES.md, `soru-adaylari/` gibi senin önceki değişikliklerin de duruyor). İstersen Claude'a "commit et" de.

**b) Cloudflare hesabı aç** (ücretsiz, kart istemez): https://dash.cloudflare.com/sign-up
Workers bölümüne ilk girişte bir `workers.dev` alt alan adı seçmen istenir (ör. `yerdema`). Sunucu adresi `https://kabaca-leaderboard.<alt-alan>.workers.dev` olur.

**c) Sunucuyu kur ve yayına al** (PowerShell, `server\leaderboard` klasöründe):
```powershell
npm install
npx wrangler login
npx wrangler d1 create kabaca-leaderboard     # çıkan database_id'yi wrangler.toml'daki REPLACE_WITH_DATABASE_ID yerine yaz
npm run db:init
npx wrangler secret put IP_SALT               # rastgele uzun bir metin gir, bir yere not etmen gerekmez
npm run deploy
```
Kontrol: tarayıcıda `https://kabaca-leaderboard.<alt-alan>.workers.dev/v1` adresi `{"ok":true}` göstermeli.
(İstersen bu adımı Claude'a da yaptırabilirsin: `npx wrangler login` sonrası "deploy et" demen yeterli.)

**d) Adresi uygulamalara duyur** (depo kökünde):
```powershell
python tools/publish_content.py --leaderboard https://kabaca-leaderboard.<alt-alan>.workers.dev/
git add docs; git commit -m "Leaderboard URL, privacy policy"; git push
```
Bu push, güncellenen gizlilik politikasını da (`docs/privacy-policy.md`) yayınlar. **Paketi yüklemeden önce yap**, çünkü Play inceleme sırasında politikaya bakabilir.
Uygulama, manifest'e en fazla 6 saatte bir baktığı için kupa simgesi ilk açılışta görünmeyebilir. Hemen denemek için: Ayarlar → Uygulamalar → Kabaca → Verileri temizle.

**e) Play Console → Uygulama içeriği → Veri güvenliği formunu güncelle.** Artık "veri toplanıyor: Evet":
- *Kişisel bilgiler → Kullanıcı kimlikleri* (takma ad + rastgele kimlik): toplanıyor, paylaşılmıyor, **isteğe bağlı**, amaç *Uygulama işlevselliği*.
- *Uygulama etkinliği → Diğer kullanıcı işlemleri* (günlük cevaplar ve puan): toplanıyor, paylaşılmıyor, isteğe bağlı, amaç *Uygulama işlevselliği*.
- Aktarım sırasında şifreleniyor: **Evet** (https). Kullanıcı silme isteğinde bulunabilir: **Evet** (uygulama içinde Ayarlar → Liderlik tablosu → Tablodan ayrıl).
- Formda "hesap oluşturma" sorulursa **Evet (kullanıcı adıyla)** de. Hesap silme bağlantısı olarak gizlilik politikasının adresini ver: https://yerdema.github.io/aralik/privacy-policy.html (silme yolu "Günün liderleri" bölümünde yazıyor).

**f) Yeni sürümü kapalı teste yükle:** `play-store/release/kabaca-1.0.2+3.aab`, mapping ve symbols dosyaları da aynı klasörde. Sürüm notu önerisi:
```
<tr-TR>
• Günün setinde her soru için 15 saniye süre var.
• Yeni: Günün liderleri! Bir takma adla katıl, günlük puanınla sıralamaya gir. Katılım isteğe bağlı, tablo her gün sıfırlanır.
• Iskaların cezası yarıya indi: bir soruda en fazla −50.
• Yenilenen paylaşım kartı: filozof skoruna göre seviniyor ya da üzülüyor.
• Günler artık numarayla değil tarihle: "4 Kasım".
</tr-TR>
```

**g) Telefonda dene:** Kupa simgesi → Tabloya katıl → takma ad seç → günün setini bitir. Puanın tabloda görünmeli. Sonra Ayarlar → Liderlik tablosu → Tablodan ayrıl ile verinin silindiğini kontrol et.

Ayarlanabilir değerler: soru süresi `lib/core/question_timer.dart` (`dailyTimeLimit`, şu an 15 sn). Tablonun ilk 10'dan ilk 50'ye geçtiği katılımcı sayısı `server/leaderboard/wrangler.toml` (`FULL_BOARD_AT`, şu an 100; değiştirince `npm run deploy`).
