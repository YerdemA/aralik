# Manuel yapılacaklar

Claude'un yapamadığı ya da senin kararını bekleyen işler. Bitenleri sil.

## 1. Klasörü ASCII adla yeniden adlandır (`Aralık` → `Aralik`)
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

## 4. Karar: başlangıç tarihi ve kapalı test
`lib/core/daily.dart` içinde `epoch = 2026-11-01`. Plana göre kapalı test 5. günde başlıyor (~2026-10-29).
Epoch'tan önceki günlerde gün indeksi negatif oluyor ve set bankanın sonundan geliyor
(örn. 31 Ekim, son 5 soru). Seçenekler:
- (a) Epoch'u kapalı testin başladığı güne çek. Testçiler "#1"den başlar.
- (b) Böyle bırak. Testçiler son setleri görür, ama o sorular ileride bir gün tekrar gelir.

## 5. Paket onayı: `shared_preferences`
CLAUDE.md'de izinli ama "eklemeden önce sor" kuralı var. Seri, istatistik ve ayarlar
(`data/stats_store.dart`, 4. gün) için gerekli. Onay verirsen eklenir.

## 6. Git ve GitHub
Klasör henüz bir git deposu değil. Klasör adı değiştikten sonra `git init` ve ilk commit yapılabilir,
ardından GitHub'da `YerdemA/aralik` reposu açılıp push edilir (push'u sen onaylarsın).

## 7. (5. gün) Release imzası
Play'e yüklemek için upload keystore gerekiyor. Şifreleri sen belirlemelisin:
`keytool -genkey -v -keystore $env:USERPROFILE\aralik-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
Sonra `android/key.properties` oluşturulur (git'e girmez). Gradle tarafını Claude bağlar.
