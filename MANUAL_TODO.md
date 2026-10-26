# Manuel yapılacaklar

Claude'un yapamadığı ya da senin kararını bekleyen işler. Bitenleri sil.

## 1. Klasörü ASCII adla yeniden adlandır (`Aralık` → `Aralik`, i noktalı)
"ı" harfi yüzünden Windows'ta Android Gradle build'i ve `flutter analyze` çalışmıyor.
Şimdilik `subst A: "D:\Yazilim\Mobil\Aralık"` ile `A:\` üzerinden çalıştırılıyor.
Açık oturum klasörü kullandığı için yeniden adlandırma oturum içinden yapılamadı.

1. Claude Code, VS Code / Android Studio ve açık terminalleri kapat.
2. `D:\Yazilim\Mobil\Aralık` klasörünü `Aralik` olarak yeniden adlandır.
3. Yeni klasörde: `flutter clean; flutter pub get; flutter build apk --release`
4. Claude Code'u yeni klasörde aç. (Claude'un proje hafızası eski yola bağlı. İstersen
   `C:\Users\yusuf\.claude\projects\D--Yazilim-Mobil-Aral-k\memory\` içeriğini yeni projenin klasörüne kopyala.)

## 2. GitHub Pages'i aç (internetten soru güncellemesi bunun üzerinden çalışır)
1. https://github.com/YerdemA/aralik/settings/pages adresine git.
2. "Build and deployment" altında **Source: Deploy from a branch**, **Branch: main**, klasör **/docs** seç ve kaydet.
3. Birkaç dakika sonra şu adresler açılmalı:
   - https://yerdema.github.io/aralik/content/manifest.json (uygulamanın baktığı dosya)
   - https://yerdema.github.io/aralik/privacy-policy (Play Console'a girilecek gizlilik linki)

## 3. Soru bankasına göz at (31 Ekim'e kadar, isteğe bağlı)
Banka 2026-10-26'da Türkçe Vikipedi okunma sayılarına göre yeniden kuruldu (213 soru).
`python tools/build_questions.py --fresh --dry-run --report` her veri setinde seçilenleri ve sınırda kalanları okunma sayılarıyla listeler.
Çıkarmak istediğin soruları id'leriyle Claude'a söylemen yeterli.

## 3b. TÜİK il nüfusu verisi
TÜİK veri portalında "nüfus yoğunluğu" değil, il bazında **toplam nüfus** veren ADNKS göstergesini bul ve **JSON** olarak indir
(JSON uygun, dönüştürücüyü Claude yazar). Dosyayı `tools\tuik\` altına koy.

## 4. (İsteğe bağlı) Wikidata'daki hataları düzelt
Veri çekerken görülen hatalar. Wikidata'da düzeltilirse bir sonraki çekimde uygulamaya da gelir:
- Konya ilinin plaka kodu 53, Uşak'ın 62 girilmiş (doğrusu 42 ve 64).
- Bingöl ilinin "başkent" (P36) bilgisi yok, bu yüzden mesafe sorularında Bingöl yok.
- Çankırı şehrinin birbirinden >5 km farklı iki koordinatı var, bu yüzden Çankırı da şimdilik dışarıda.

## 5. (5. gün) Release imzası
Play'e yüklemek için upload keystore gerekiyor. Şifreleri sen belirlemelisin:
`keytool -genkey -v -keystore $env:USERPROFILE\aralik-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
Sonra `android/key.properties` oluşturulur (git'e girmez). Gradle tarafını Claude bağlar.
