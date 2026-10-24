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

## 2. Soru bankasını gözden geçir
`assets/questions/questions.json` (154 soru). Sayıları Wikidata'dan geliyor ama metinlere bir insan bakmalı:
- Az bilinen yapılar: "Atatürk Maskı (Buca/Kepez)", "Hilton İzmir", "Mistral Ofis Kulesi"...
- Sıradağlar tek sayıyla sorulmuş: "Bingöl Dağları", "Bozdağlar" ("en yüksek noktası" demek daha doğru).
- `fun_fact` alanları şimdilik sade ("Konum: Kayseri.").
- Çıkarılacak soru varsa QID'sini `tools/build_questions.py` içindeki `EXCLUDED` listesine ekle.
  **Not:** 2026-11-01'den sonra sıra değişmemeli. O tarihten sonra yalnızca sona soru eklenir.
  Çıkarma işini şimdi, `--fresh` ile yap.

## 3. TÜİK il nüfusu verisi
Wikidata'daki il nüfusları TÜİK ile uyuşmuyor, bu yüzden bu sorular bankaya alınmadı.
TÜİK veri portalından "Adrese Dayalı Nüfus Kayıt Sistemi, il nüfusları" tablosunun en güncel yılını
CSV/XLSX olarak indir ve `tools/tuik/` altına koy. Dönüştürücüyü Claude yazar.

## 4. (İsteğe bağlı) Wikidata'daki hataları düzelt
Veri çekerken görülen hatalar. Wikidata'da düzeltilirse bir sonraki çekimde uygulamaya da gelir:
- Konya ilinin plaka kodu 53, Uşak'ın 62 girilmiş (doğrusu 42 ve 64).
- Bingöl ilinin "başkent" (P36) bilgisi yok, bu yüzden mesafe sorularında Bingöl yok.
- Çankırı şehrinin birbirinden >5 km farklı iki koordinatı var, bu yüzden Çankırı da şimdilik dışarıda.

## 5. (5. gün) Release imzası
Play'e yüklemek için upload keystore gerekiyor. Şifreleri sen belirlemelisin:
`keytool -genkey -v -keystore $env:USERPROFILE\aralik-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
Sonra `android/key.properties` oluşturulur (git'e girmez). Gradle tarafını Claude bağlar.
