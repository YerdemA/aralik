import '../data/question.dart';

/// Every user-facing Turkish string lives here.
abstract final class AppStrings {
  static const appName = 'Kabaca';
  static const tagline = '%90 emin olduğun aralığı ver.';

  // Number formatting
  static const million = 'milyon';
  static const billion = 'milyar';
  static const beforeCommonEra = 'MÖ';

  // Home
  static const playToday = 'Günün setini oyna';
  static String continueToday(int done, int total) =>
      'Devam et ($done / $total)';
  static const todayDone = 'Bugünkü seti bitirdin';
  static const todayPlayedBefore = 'Bugün oynandı';
  static const todayPlayedBeforeHint =
      'Bugünün setini bu cihazda zaten oynadın. Yarın 5 yeni soru var.';
  static const comeBackTomorrow = 'Yarın 5 yeni soru seni bekliyor.';
  static const todayTitle = 'Bugünün 5 sorusu';
  static const todayHint = 'Herkes bugün aynı soruları çözüyor.';
  static String scoreOutOf(int points, int max) => '$points / $max';
  static String streakDays(int days) => '$days gün';
  static String streakPill(int days) => '$days gün seri';
  static const modeStart = 'Başla';
  static const modeMath = 'Matematik modu';
  static const categoryMath = 'Matematik';
  static const mathHomeHint = 'Temel ya da ileri, 30 sn';
  static const mathChoose = 'Hangi matematik?';
  static const mathRules =
      'Soru başına 30 saniye. Kafadan, kabaca tahmin et: aralık en fazla '
      '÷2 … ×2 açılır, isabetli tahmin çok puan getirir. Eksi puan yok.';
  static const mathBasic = 'Temel';
  static const mathBasicHint = 'Çarpma, kök, yüzde, faiz, olasılık, geometri…';
  static const mathAdvanced = 'İleri';
  static const mathAdvancedHint =
      'Trigonometri, limit, türev, integral, matris…';
  static const mathRoundLabel = 'Matematik turu';
  static const mathSource = 'Hesaplama';
  static String mathWorking(String working) => 'Çözüm: $working';
  static const mathCalibration = 'Matematik kalibrasyonu';
  static const modeTournament = 'Turnuva modu';
  static const comingSoon = '(Yakında gelecek)';
  static const noValue = '–';
  static const streak = 'Seri';
  static const lastScore = 'Son skor';
  static const calibration = 'Kalibrasyon';
  static const freePlay = 'Bir tur at';
  static const freePlayHint = '5 yeni soru, sınır yok';
  static const freePlayEmpty =
      'Şimdilik yeni soru kalmadı. Yarın yenileri açılır.';
  static const loadError = 'Sorular yüklenemedi. Tekrar dene.';
  static String roundTotal(int points, int max) => '$points / $max puan';
  static const stats = 'İstatistikler';
  static const settings = 'Ayarlar';

  // Game
  static String questionProgress(int current, int total) =>
      'Soru $current / $total';
  static const yourGuess = 'En iyi tahminin';
  static const typeYourGuess = 'Tahminini yaz';
  static const editGuess = 'Tahmini değiştir';
  static const intervalLabel = '%90 emin olduğun aralık';
  static const intervalWidth = 'Aralığın genişliği';
  static const narrower = 'Dar';
  static const wider = 'Geniş';
  static String potentialPoints(int points) => 'İsabet edersen $points puan';
  static const lock = 'Kilitle';
  static const next = 'Devam';
  static const finish = 'Bitir';
  static const delete = 'Sil';
  static const quit = 'Çık';
  static String secondsLeft(int seconds) => '$seconds sn';
  static String timeLimitHint(int seconds) => 'Soru başına $seconds saniye.';

  // Generated questions
  static String distanceQuestion(String from, String to) =>
      '$from ile $to arası kuş uçuşu kaç kilometredir?';
  static const distanceFunFact =
      'Mesafe, iki şehrin Wikidata koordinatlarından hesaplandı.';
  static const kilometres = 'km';

  // Result
  static const hit = 'İsabet!';
  static const miss = 'Iska';
  static const nearMiss = 'Kıl payı ıska';
  static const timeUp = 'Süre doldu';
  static const autoLocked = 'Süre dolunca aralığın kendiliğinden kilitlendi.';
  static const noGuess = 'Tahmin yok';
  static const answer = 'Cevap';
  static const yourInterval = 'Aralığın';
  static const points = 'puan';
  static const source = 'Kaynak';
  static const daySummary = 'Günün özeti';
  static const roundSummary = 'Tur özeti';
  static const share = 'Paylaş';
  static const newRound = 'Yeni tur';
  static const backHome = 'Ana ekran';
  static const shareSubject = 'Kabaca skorum';
  static const shareImage = 'Görseli paylaş';
  static const shareTextOnly = 'Metni paylaş';
  static const shareCardScoreLabel = 'Bugünkü skorum';
  // A free-play round on the share card and text: no day, no "bugün".
  static const freeRoundLabel = 'Serbest tur';
  static const shareCardRoundLabel = 'Tur skorum';
  static const shareRoundFileName = 'kabaca-serbest-tur.png';
  static const shareCardInvite = 'Sen de dene: Kabaca';
  // Share card moods: the player speaks, since the card is theirs to share.
  static const moodLegend = 'Efsane!';
  static const moodLegendLine = 'Aralıklarım tam isabet, kaslarım yerinde.';
  static const moodGreat = 'Harika!';
  static const moodGreatLine = 'Bugün sayılar benden yanaydı.';
  static const moodProud = 'Fena değil!';
  static const moodProudLine = 'Bıyık altından gülmeye değer.';
  static const moodUnsure = 'İdare eder.';
  static const moodUnsureLine = 'Bazen tuttu, bazen tutmadı.';
  static const moodDown = 'Bugün olmadı.';
  static const moodDownLine = 'Yarın 5 yeni soruyla rövanş.';
  static const moodGreatRoundLine = 'Sayılar benden yanaydı.';
  static const moodDownRound = 'Bu tur olmadı.';
  static const moodDownRoundLine = 'Bir tur daha atarım.';

  // Leaderboard
  static const leaderboard = 'Günün liderleri';
  static String leaderboardPlayers(int n) => '$n oyuncu';
  static const leaderboardResets = 'Tablo her gün yeni sorularla sıfırlanır.';
  static const leaderboardEmpty = 'Henüz kimse yok. İlk sen ol!';
  static const leaderboardJoin = 'Tabloya katıl';
  static String leaderboardRestored(String nickname) =>
      'Bu cihazın tablodaki hesabı geri geldi. Kullanıcı adın: $nickname';
  static const leaderboardJoinTitle = 'Liderlere katıl';
  static String leaderboardJoinBody(String name) =>
      'Tabloda kullanıcı adın ($name) ve günlük puanın görünür. Başka '
      'hiçbir bilgi gönderilmez.';
  static const leaderboardJoinNeedsName =
      "Tabloya katılmak için önce Ayarlar'dan bir kullanıcı adı seç.";
  static const leaderboardNameTaken =
      "Bu ad tabloda başka bir oyuncuda. Ayarlar'dan yeni bir ad seçip "
      'tekrar katıl; beklemeden değiştirebilirsin.';
  static const leaderboardNameBlocked =
      "Bu ad tabloda kullanılamaz. Ayarlar'dan yeni bir ad seçip tekrar "
      'katıl; beklemeden değiştirebilirsin.';
  static const openSettings = "Ayarlar'a git";
  static const leaderboardFinishSet =
      'Günün setini bitirince puanın buraya eklenir.';
  static const leaderboardSendFailed = 'Puanın henüz gönderilemedi.';
  static const leaderboardOffline =
      'Bağlanılamadı. İnternetini kontrol et; sorun sürerse Ayarlar → '
      'Bağlantı testi.';
  static const leaderboardError = 'Bir sorun oldu. Biraz sonra tekrar dene.';
  static const leaderboardMissing =
      'Hesabın sunucuda bulunamadı. Yeniden katılabilirsin.';
  static String hitsOutOf(int hits, int total) => '$hits/$total isabet';
  static const you = 'Sen';
  static const retry = 'Tekrar dene';
  static const userNameLabel = 'Kullanıcı adı';
  static const nicknameHint = '3–16 harf ya da rakam';
  static const nicknameTooShort = 'En az 3 karakter olmalı.';
  static const nicknameTooLong = 'En fazla 16 karakter olabilir.';
  static const nicknameBadCharacters =
      'Harf, rakam, boşluk ve . _ - kullanabilirsin. En az bir harf olmalı.';
  static const nicknameTaken = 'Bu ad tabloda başka bir oyuncuda.';
  static const nicknameBlocked = 'Bu ad kullanılamaz.';
  static const rateLimited = 'Çok fazla deneme oldu. Biraz sonra tekrar dene.';
  static const renameRule = 'Kullanıcı adını 3 günde bir değiştirebilirsin.';
  static String renameWait(DateTime? at) =>
      at == null ? renameRule : '$renameRule Bir sonraki: ${dayLabel(at)}.';
  static const join = 'Katıl';
  static const save = 'Kaydet';
  static const cancel = 'Vazgeç';
  static String joinedAs(String name) => 'Hoş geldin, $name!';
  static const leaderboardSection = 'Liderlik tablosu';
  static const leaveLeaderboard = 'Tablodan ayrıl';
  static const leaveLeaderboardHint =
      'Puanların tablodan silinir, yenileri gönderilmez.';
  static const leaveConfirmTitle = 'Tablodan ayrılsın mı?';
  static const leaveConfirmBody =
      'Gönderdiğin puanlar sunucudan silinir ve yeni puan gönderilmez. '
      'Kullanıcı adın uygulamada kalır, düello ve turnuvada kullanmaya devam '
      'edersin. İstediğin zaman yeniden katılabilirsin; bu cihazdan '
      'gönderilmiş bir günün seti yeniden gönderilemez.';
  static const leave = 'Ayrıl';
  static const leftLeaderboard = 'Tablodan ayrıldın, puanların silindi.';
  static const leaderboardJoined = 'Tabloya katıldın';

  // The player's one name (Settings)
  static const userNameSection = 'Kullanıcı adın';
  static const userNameUnset = 'Henüz seçmedin';
  static const userNameSubtitle =
      'Tabloda, düelloda ve turnuvada bu adla görünürsün';
  static String userNameNextChange(DateTime at) =>
      'Bir sonraki değişiklik: ${dayLabel(at)}';
  static const userNameBody =
      'Liderlik tablosunda, düelloda ve turnuvada bu adla görünürsün. '
      'Adını 3 günde bir değiştirebilirsin.';

  // Calibration feedback
  static const calibrationTooNarrow = 'Aralıkların fazla dar.';
  static const calibrationTooWide = 'Daha cesur ol.';
  static const calibrationGood = 'Harika, tam kıvamında.';
  static const calibrationNoData =
      'Birkaç gün oyna, kalibrasyonun ortaya çıksın.';

  // Stats
  static const gamesPlayed = 'Oynanan gün';
  static const averageScore = 'Ortalama';
  static const bestDay = 'En iyi gün';
  static const longestStreak = 'En uzun seri';
  static const answeredCount = 'Cevaplanan';
  static const byCategory = 'Kategoriye göre';
  static const missDirection = 'Iskaların';
  static const statsEmpty = 'Henüz istatistik yok. İlk soruları oyna.';
  static String calibrationChartCaption(int blockSize) =>
      'Her sütun $blockSize soru. Kesikli çizgi %90 hedefi.';
  static String calibrationChartEmpty(int blockSize) =>
      'Grafik, ilk $blockSize sorudan sonra burada.';
  static String calibrationChartSemantics(String rates) =>
      'Son sütunların isabet oranları: $rates';
  static const missBiasHigh =
      'Iskalarının çoğunda tahminin fazla yüksekti. Aralığı aşağı da aç.';
  static const missBiasLow =
      'Iskalarının çoğunda tahminin fazla düşüktü. Aralığı yukarı da aç.';
  static const missBiasNone = 'Iskaların iki yöne dengeli dağılıyor.';
  static String categoryTally(String percent, int answered) =>
      '$percent · $answered soru';

  // Categories
  static const categoryGeography = 'Coğrafya';
  static const categoryHistory = 'Tarih';
  static const categoryTurkey = 'Türkiye';
  static const categoryScience = 'Bilim';
  static const categorySports = 'Spor';
  static const categoryEveryday = 'Gündelik';
  static const categoryAnimals = 'Hayvanlar';
  static const categoryCompanies = 'Şirketler';
  static const categoryOttoman = 'Osmanlı';
  static const categoryArchitecture = 'Mimari';
  static const categoryArt = 'Sanat';
  static const categoryOther = 'Diğer';

  // Math mode: question texts (lib/core/math/math_problem.dart). Every
  // assumption the answer needs is in the text.
  static String mathMultiply(String expr) => '$expr kaçtır?';
  static String mathPower(String expr) => '$expr kaçtır?';
  static String mathSquareRoot(String n) => '√$n kaçtır?';
  static String mathCubeRoot(String n) => '∛$n (küpkök) kaçtır?';
  static String mathFactorial(int n) => '$n! (1 × 2 × … × $n) kaçtır?';
  static String mathHandshakes(int n) =>
      '$n kişilik bir grupta herkes herkesle bir kez tokalaşırsa kaç '
      'tokalaşma olur?';
  static String mathTeams(int n, int k) =>
      '$n kişilik bir sınıftan $k kişilik bir ekip kaç farklı şekilde '
      'seçilebilir?';
  static String mathLottery(int n, int k) =>
      '1 ile $n arasından $k farklı sayı seçilen bir piyangoda kaç farklı '
      'kupon vardır?';
  static String mathSumTo(String n) => '1 + 2 + 3 + … + $n toplamı kaçtır?';
  static String mathSumSquares(int n) =>
      '1² + 2² + 3² + … + $n² toplamı kaçtır?';
  static String mathDoubling(int rate) =>
      'Yıllık %$rate bileşik faizle para kaç yılda iki katına çıkar?';
  static String mathCompound(String principal, int rate, int years) =>
      '$principal TL, yıllık %$rate bileşik faizle $years yıl sonra kaç TL '
      'olur?';
  static String mathPercentOf(String x, int p) =>
      '$x sayısının %$p kadarı kaçtır?';
  static String mathRaiseThenCut(String x, int up, int down) =>
      '$x TL fiyatlı bir ürüne önce %$up zam, sonra %$down indirim '
      'yapılıyor. Son fiyat kaç TL?';
  static String mathMonthlyRise(int p) =>
      'Fiyatlar her ay %$p artarsa 12 ayda toplam yüzde kaç artar?';
  static String mathKmhToMs(int v) =>
      'Saatte $v km hız, saniyede kaç metredir?';
  static String mathDaysToMinutes(int days) => '$days gün kaç dakikadır?';
  static String mathMilesToKm(int miles) =>
      '$miles mil kaç kilometredir? (1 mil = 1,609344 km)';
  static String mathYearsToSeconds(int years) =>
      '$years yıl kaç saniyedir? (Yıl 365 gün)';
  static String mathLightDays(int days) =>
      'Işık saniyede 299.792,458 km yol alır. $days günde kaç milyar km '
      'yol alır?';
  static String mathCircleArea(int r) =>
      'Yarıçapı $r cm olan bir dairenin alanı kaç cm²?';
  static String mathSphereVolume(int d) =>
      'Çapı $d cm olan bir kürenin hacmi kaç cm³?';
  static String mathTriangleArea(int a, int b, int c) =>
      'Kenarları $a, $b ve $c cm olan bir üçgenin alanı kaç cm²?';
  static String mathAtLeastOneSix(int throws) =>
      'Hilesiz bir zar $throws kez atılıyor. En az bir kez 6 gelme '
      'olasılığı yüzde kaç?';
  static String mathSharedBirthday(int people) =>
      '$people kişilik bir grupta en az iki kişinin doğum gününün aynı '
      'olma olasılığı yüzde kaç? (Yıl 365 gün, her gün eşit olasılıklı)';
  static String mathMyBirthday(int people) =>
      '$people kişiden en az birinin senin doğum gününde doğmuş olma '
      'olasılığı yüzde kaç? (Yıl 365 gün, her gün eşit olasılıklı)';
  static String mathPrimes(String n) =>
      '1 ile $n arasında kaç asal sayı vardır?';
  static String mathPrimesWorking(String n, String count) =>
      'Eratosthenes kalburuyla 1…$n arası sayıldı: $count asal';
  static String mathDigits(String expr) => '$expr kaç basamaklı bir sayıdır?';
  static String mathFibonacci(int n) =>
      'Fibonacci dizisi 1, 1, 2, 3, 5, 8, 13, … diye gider. $n. terimi '
      'kaçtır?';
  static String mathFolding(int folds, String unit) =>
      '0,1 mm kalınlığındaki bir kâğıt $folds kez ikiye katlanabilseydi '
      'kalınlığı kaç $unit olurdu?';
  // Math mode, further on (lib/core/math/advanced.dart).
  static String mathLadder(int length, int angle) =>
      '$length m uzunluğundaki bir merdiven yerle $angle° açı yapacak '
      'şekilde duvara dayanıyor. Merdivenin üst ucu yerden kaç cm '
      'yüksekte?';
  static String mathShadow(int shadow, int angle) =>
      'Güneş ışınları yerle $angle° açı yaparken bir ağacın gölgesi '
      '$shadow m. Ağaç kaç m yüksekliğinde?';
  static String mathLawOfCosines(int a, int b, int angle) =>
      'Bir üçgenin iki kenarı $a cm ve $b cm, aralarındaki açı $angle°. '
      'Üçüncü kenar kaç cm?';
  static String mathProjectile(int speed, int angle) =>
      'Yerden saniyede $speed m hızla, yerle $angle° açı yapacak şekilde '
      'atılan bir top kaç m uzağa düşer? (g = 9,81 m/sn², hava direnci '
      'yok)';
  static String mathLimitAt(int a, String numerator, String denominator) =>
      'lim (x → $a) ($numerator) ÷ ($denominator) kaçtır?';
  static String mathLimitE(int k) => 'lim (n → ∞) (1 + $k/n)ⁿ kaçtır?';
  static String mathLimitCos(int k) =>
      'lim (x → 0) (1 − cos ${k}x) ÷ x² kaçtır? (x radyan)';
  static String mathDerivativeAt(String f, int x) =>
      'f(x) = $f ise f′($x) kaçtır?';
  static String mathIntegral(String expr) => '$expr kaçtır?';
  static String mathLog(String log, String n) => '$log $n kaçtır?';
  static String mathSolvePower(int base, String n) =>
      '$baseˣ = $n ise x kaçtır?';
  static String mathSolveTwoToTen(int e) => '2ˣ = 10 üzeri $e ise x kaçtır?';
  static String mathQuakeEnergy(String small, String big) =>
      'Deprem büyüklüğü 1 arttıkça açığa çıkan enerji 10^1,5 katına '
      'çıkar. $big büyüklüğündeki bir deprem, $small büyüklüğündekinden '
      'kaç kat fazla enerji açığa çıkarır?';
  static String mathBacteria(int every, int hours) =>
      'Bir bakteri her $every dakikada bir ikiye bölünüyor. Tek bir '
      'bakteriden $hours saatte kaç bakteri olur?';
  static String mathHalfLife(int grams, int half, int years) =>
      'Yarı ömrü $half yıl olan bir maddenin $grams gramından $years yıl '
      'sonra kaç mg kalır?';
  static String mathGrowthTimes(int rate, int times) =>
      'Nüfusu her yıl %$rate artan bir şehrin nüfusu kaç yılda $times '
      'katına çıkar?';
  static String mathArithmeticSum(String terms, int n) =>
      '$terms + … dizisinin ilk $n teriminin toplamı kaçtır?';
  static String mathSumCubes(int n) => '1³ + 2³ + 3³ + … + $n³ toplamı kaçtır?';
  static String mathGeometricSum(String terms, int n) =>
      '$terms + … dizisinin ilk $n teriminin toplamı kaçtır?';
  static String mathInfiniteSum(String terms) =>
      '$terms + … sonsuz toplamı kaçtır?';
  static String mathMean(String xs) => '$xs sayılarının ortalaması kaçtır?';
  static String mathStdDev(String xs) =>
      '$xs sayılarının standart sapması kaçtır? (Bölen 5)';
  static String mathNormalBelow(int mean, int sd, int cut) =>
      'Bir okuldaki boylar ortalaması $mean cm, standart sapması $sd cm '
      'olan normal dağılıma uyuyor. Rastgele seçilen bir öğrencinin '
      '$cut cm’den kısa olma olasılığı yüzde kaç?';
  static String mathDeterminant(String matrix) =>
      'Satırları $matrix olan matrisin determinantı kaçtır? (Satırlar ; '
      'ile ayrılmış)';
  static String mathModulus(String z) => '|$z| kaçtır?';
  static String mathArgument(String z) =>
      '$z sayısının argümanı, 0° ile 360° arasında kaç derecedir?';
  static String mathVectorLength(String v) => '$v vektörünün boyu kaçtır?';
  static String mathVectorAngle(String u, String v) =>
      '$u ve $v vektörleri arasındaki açı kaç derecedir?';
  static String mathTriangleVectors(String u, String v) =>
      'Kenarları $u ve $v vektörleri olan üçgenin alanı kaçtır?';
  static String mathLcm(String numbers) =>
      '$numbers sayılarının EKOK’u kaçtır?';
  static String mathDivisors(String n) =>
      '$n sayısının kaç tane pozitif böleni vardır?';
  static String mathDivisorsWorking(String n, int count) =>
      '$n asal çarpanlarına ayrılır, üslerin birer fazlası çarpılır: $count';
  static String mathTotient(String n) =>
      '1 ile $n arasında, $n ile aralarında asal kaç sayı vardır?';
  static const mathByDefinition = 'türevin tanımı';
  static const mathSarrus = 'Sarrus kuralı';
  static const mathTimes = 'kat';
  static const mathYears = 'yıl';
  static const mathMinutes = 'dakika';
  static const mathSeconds = 'saniye';
  static const mathBillionKm = 'milyar km';

  // Settings
  static const appearance = 'Görünüm';
  static const theme = 'Tema';
  static const themeSystem = 'Sistem';
  static const themeLight = 'Açık';
  static const themeDark = 'Koyu';
  static const soundEffects = 'Ses efektleri';
  static const soundEffectsHint = 'Telefon sessizdeyken çalmaz.';
  static const howToPlay = 'Nasıl oynanır?';
  static const privacy = 'Gizlilik';
  static const about = 'Hakkında';
  static const dataSources = 'Veri kaynakları ve lisanslar';
  static const dataSourcesHint = 'Soruların ve cevapların kaynakları';

  // Connection test (Ayarlar → Bağlantı testi)
  static const netTest = 'Bağlantı testi';
  static const netTestHint = 'Liderlik ya da düello bu ağda çalışmıyorsa';
  static const netTestIntro =
      'Kabaca sunucusuna bu ağdan nasıl ulaşıldığını adım adım dener. '
      'Yaklaşık 20 sn sürer.';
  static const netTestRun = 'Testi başlat';
  static const netTestAgain = 'Yeniden dene';
  static const netTestCopy = 'Sonucu kopyala';
  static const netTestCopied = 'Sonuç kopyalandı';
  static const netChecking = 'Deneniyor…';
  static const netCheckProxy = 'Vekil sunucu (proxy)';
  static const netCheckDns = 'Ad çözümleme (DNS)';
  static const netCheckDirect = 'Doğrudan bağlantı';
  static const netCheckHttps = 'Liderlik sunucusu';
  static const netCheckContent = 'Soru güncellemeleri';
  static const netCheckSni = 'Aynı sunucu, başka adla';
  static const netOtherNameOk = 'Bağlandı';
  static const netCertificate = 'Sertifikayı veren';
  static const netCheckSocket = 'Düello bağlantısı';
  static const netNoProxy = 'Yok';
  static String netAddresses(int v4, int v6) => '$v4 IPv4, $v6 IPv6 adres';
  static String netPongs(int answered, int sent, int longest) =>
      '$sent yoklamadan $answered yanıt, en uzun sessizlik $longest sn';
  static const netSocketUnsupported = 'Sunucu bu testi henüz desteklemiyor';
  static const netFailDns = 'Adres bulunamadı';
  static const netFailTimeout = 'Zaman aşımı';
  static const netFailRefused = 'Bağlantı reddedildi';
  static const netFailTls = 'Güvenli bağlantı kurulamadı';
  static const netFailBlocked = 'Araya başka bir şey girdi';
  static const netFailOther = 'Bilinmeyen hata';
  static const netVerdictOk = 'Bu ağda Kabaca sorunsuz çalışmalı.';
  static const netVerdictProxy =
      'Bu ağ bir vekil sunucu kullanıyor. Kabaca artık onun üzerinden '
      'bağlanıyor.';
  static const netVerdictDns =
      'Bu ağ Kabaca sunucusunun adresini vermiyor. Mobil veriyi dene.';
  static const netVerdictTls =
      'Bu ağ şifreli bağlantıları denetliyor, Kabaca bağlanamıyor. Mobil '
      'veriyi dene.';
  static const netVerdictBlocked =
      'Bu ağ Kabaca sunucusunu engelliyor ya da önce bir giriş sayfası '
      'istiyor. Mobil veriyi dene.';
  static const netVerdictName =
      'Bu ağ kabaca.app adını engelliyor (sunucunun kendisini değil). '
      'Liderlik ve düello için mobil veriyi dene.';
  static const netVerdictHttps =
      'Kabaca sunucusuna ulaşılamadı. İnternetini kontrol et ya da mobil '
      'veriyi dene.';
  static const netVerdictSocket =
      'Liderlik tablosu çalışır, ama bu ağ düello bağlantısını geçirmiyor. '
      'Düello için mobil veriyi dene.';
  static const netVerdictUnstable =
      'Bu ağda bağlantı kesik kesik. Düelloda kopmalar olabilir.';
  static const dataSourcesIntro =
      'Sorular ve cevapları aşağıdaki kaynaklara dayanır. Sonuç ekranında '
      'her cevabın görüldüğü sayfa ayrıca gösterilir.';
  static const openSourceLicenses = 'Açık kaynak lisansları';
  static const privacyPolicy = 'Gizlilik politikası';
  static const license = 'Lisans';
  static const copyLink = 'Bağlantıyı kopyala';
  static const linkCopied = 'Bağlantı kopyalandı';
  static const privacyPolicyUrl =
      'https://yerdema.github.io/aralik/privacy-policy.html';

  // Update notice
  static const updateTitle = 'Yeni sürüm var';
  static const updateBody =
      "Kabaca'nın yeni sürümü Google Play'de. Şimdi güncellemek ister misin?";
  static const updateNow = 'Güncelle';
  static const updateLater = 'Sonra';
  static const updateStoreMissing = "Google Play açılamadı.";

  // Duel
  static const duel = 'Düello';
  static const duelHomeHint = 'Canlı rakibe karşı 5 soru';
  static const duelTitle = 'Düello';
  static const duelIntro =
      'Aynı 5 soru, aynı anda. Soru başına 15 saniye. '
      'Kim daha iyi aralık verirse kazanır.';
  static const duelFindOpponent = 'Rakip bul';
  static const duelWithFriend = 'Arkadaşınla oyna';
  static const duelSearching = 'Rakip aranıyor…';
  static const duelSearchingHint = 'Biri aradığı anda düello başlar.';
  static String duelSearchElapsed(Duration d) =>
      'Bekleme ${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  static const duelTipTitle = 'Beklerken';

  /// Short notes shown while looking for an opponent, one every
  /// [duelTipEvery] (core/duel.dart). Rules of the game and well-known
  /// findings about estimating; no numbers that need a source.
  static const duelTips = [
    "%90 emin olduğun aralıklar, 10 sorudan 9'unda cevabı içermeli. "
        'Kalibrasyonun bunu ölçer.',
    'Aralığın darsa puanın yüksek olur. Ama ıskalarsan eksiye düşebilirsin.',
    'Kıl payı ıskalar da puan alabilir. Uzak ıskalar eksi yazar.',
    'Kaydırıcının en geniş ucunda isabet her soruda 30 puan getirir.',
    'Puanlama dürüst %90 aralığını ödüllendirir. Bilerek dar aralık vermek '
        'uzun vadede kazandırmaz.',
    'İnsanlar "%90 eminim" dediği aralıklarda çoğu zaman çok daha az '
        'isabet eder. Aşırı özgüven en yaygın tahmin hatasıdır.',
    'Bilmediğin bir sayıyı bildiğin bir sayıyla karşılaştır. Yakın bir '
        'çapa, tahmini kolaylaştırır.',
    'Büyük bir sayıyı küçük parçalara böl, her parçayı ayrı tahmin et. '
        'Buna Fermi tahmini denir.',
    'Yıl sorularında aralık ± yıl olarak, büyüklüklerde kat olarak genişler.',
    'Yüzde sorularında aralık, tahminin 20 puan altına ve üstüne kadar '
        'açılabilir.',
    'Düelloda soru başına 15 saniyen var. Süre dolarsa ekrandaki aralık '
        'kendiliğinden kilitlenir.',
    'Düelloda iki aralık yan yana açılır. Toplam puanı yüksek olan kazanır.',
    'Önce en iyi tahminini yaz, sonra ne kadar emin olduğuna göre aralığı '
        'genişlet.',
    'Kalibrasyonunu İstatistikler sayfasında görebilirsin. Hedef %90 '
        'civarı.',
  ];
  static const duelFound = 'Rakip bulundu, bağlanıyor…';
  static const duelNoShow = 'Rakibin odaya gelmedi. Tekrar dene.';
  static const duelNameNeeded =
      "Oynamak için önce Ayarlar'dan bir kullanıcı adı seç. Rakiplerin bu "
      'adı görür.';
  static const duelPickName = "Ayarlar'da ad seç";
  static const duelNameInSettings = "Değiştirmek için Ayarlar'a git";
  static const duelCreate = 'Oda kur';
  static const duelOrJoin = 'Arkadaşın oda kurduysa koduyla katıl';
  static const duelCodeLabel = 'Oda kodu';
  static const duelJoin = 'Katıl';
  static const duelBadCode = 'Kod 5 karakter olmalı.';
  static const duelWaiting = 'Arkadaşın bekleniyor…';
  static const duelWaitingHint =
      'Kodu arkadaşına gönder. Katıldığı anda düello başlar.';
  static const duelShareCode = 'Kodu paylaş';
  static String duelInvite(String code) =>
      "Kabaca'da düelloya var mısın? Uygulamada Düello'ya dokun, "
      'oda kodu: $code';
  static const duelConnecting = 'Bağlanıyor…';
  static const duelOpponentLocked = 'Rakibin kilitledi';
  static const duelOpponentThinking = 'Rakibin düşünüyor';
  static const duelWaitingOpponent = 'Kilitledin. Rakibin bekleniyor…';
  static const duelTimeUp = 'Süre doldu';
  static const duelAnswer = 'Cevap';
  static const duelYou = 'Sen';
  static const duelNoInterval = 'Aralık yok';
  static const duelHit = 'İsabet';
  static const duelMiss = 'Iska';
  static const duelUnavailable =
      'Düello şu an kullanılamıyor. Biraz sonra tekrar dene.';
  static const duelSeeResult = 'Sonucu gör';
  static const duelWaitingOther = 'Karşı taraf bekleniyor…';
  static String duelNextIn(int seconds) => seconds <= 0
      ? 'Sonraki soru geliyor…'
      : 'Sonraki soru $seconds sn içinde';
  static const duelWin = 'Kazandın!';
  static const duelLoss = 'Kaybettin';
  static const duelDraw = 'Berabere';
  static String duelMargin(int points) =>
      points == 0 ? 'Puanlar eşit' : 'Fark: $points puan';
  static const duelOpponentLeft = 'Rakibin ayrıldı.';
  static const reconnecting = 'Bağlantın koptu. Yeniden bağlanılıyor…';
  static const duelReconnectingHint =
      'Açık sorunun süresi işlemeye devam ediyor. Dönünce kaldığın yerden '
      'sürer.';
  static String duelOpponentAway(String name) => '$name bağlantısını kaybetti.';
  static String duelOpponentAwayHint(int seconds) =>
      'Sonraki soru onu bekliyor. $seconds sn içinde dönmezse düelloyu sen '
      'kazanırsın.';
  static String duelOpponentAwayQuestion(String name) =>
      '$name bağlantısını kaybetti. Soru sürüyor, cevabını ver.';
  static const tournamentReconnectingHint =
      'Oyun sürüyor. Dönünce kaldığı yerden katılırsın.';
  static const duelPlayAgain = 'Yeni düello';
  static const duelRematch = 'Rövanş';
  static const duelRematchSent = 'Rövanş isteği gönderildi';
  static const duelRematchCancel = 'Vazgeç';
  static String duelRematchOffer(String name) => '$name rövanş istiyor!';
  static const duelRematchAccept = 'Kabul et';
  static const duelRematchDecline = 'Reddet';
  static const duelRematchStarting = 'Rövanş başlıyor…';
  static String duelRematchDeclined(String name) => '$name rövanş istemedi.';
  static String duelRematchGone(String name) => '$name ayrıldı.';
  static const duelRematchExpired = 'Rövanş için süre doldu.';
  static const duelRematchNoQuestions = 'Rövanş için yeni soru kalmadı.';
  static const duelHome = 'Ana ekran';
  static const duelQuitTitle = 'Düellodan çıkılsın mı?';
  static const duelQuitBody =
      'Düello boyunca toplam 45 saniye uzak kalabilirsin; bu sürede ana '
      'ekrandan dönebilirsin. Açık sorunun süresi bu sırada işler. '
      'Dönmezsen rakibin kazanır. Teslim olursan düello hemen biter.';
  static const duelStay = 'Kal';
  static const duelResign = 'Teslim ol';

  // Going back to a match left behind (home screen)
  static const pendingDuelTitle = 'Devam eden bir düellon var';
  static String pendingDuelBody(String code, int seconds) =>
      'Oda $code · bağlanmak ister misin? $seconds sn içinde '
      'dönmezsen rakibin kazanır.';
  static const pendingTournamentTitle = 'Devam eden bir turnuvan var';
  static String pendingTournamentBody(String code) =>
      'Oda $code · oyun sürüyor, bağlanırsan kaldığı yerden katılırsın.';
  static const pendingJoin = 'Bağlan';
  static const pendingLeaveTournament = 'Bırak';
  static const duelEnded = 'Bu düello sona erdi.';
  static const tournamentEnded = 'Bu turnuva maçı sona erdi.';
  static const pendingDuelExpired = 'Yarım kalan düellonun dönüş süresi doldu.';
  static const duelOffline =
      'Bağlanılamadı. Sorun sürerse Ayarlar → Bağlantı testi.';
  static const duelServerError = 'Oda açılamadı. Biraz sonra tekrar dene.';
  static const duelMissingQuestions =
      'Bu düellonun soruları uygulamanda yok. Uygulamayı güncelle.';
  static String duelErrorText(String code) => switch (code) {
    'no_room' || 'expired' => 'Bu kodla açık bir oda yok.',
    'room_full' || 'room_closed' => 'Bu odada düello başlamış.',
    'invalid_name' => nicknameBadCharacters,
    'blocked_name' => 'Bu ad kullanılamaz.',
    'version' => 'Düello için uygulamayı güncelle.',
    'connection_lost' => 'Bağlantı koptu.',
    'rejoin_over' => 'Bu maç bitti.',
    'no_opponent' => 'Şu an rakip bulunamadı. Biraz sonra tekrar dene.',
    'offline' => duelOffline,
    'unavailable' => duelUnavailable,
    _ => 'Bir sorun oldu. Biraz sonra tekrar dene.',
  };

  // Tournament
  static const tournament = 'Turnuva';
  static const tournamentHomeHint = '3–8 kişi, aynı sorular';
  static const tournamentIntro =
      'Arkadaşlarınla aynı anda aynı soruları çöz. En az 3, en fazla 8 kişi.';
  static const tournamentCreate = 'Turnuva kur';
  static const tournamentJoinTitle = 'Kodla katıl';
  static const tournamentRoomCode = 'Oda kodu';
  static String tournamentPlayers(int n, int max) => 'Oyuncular $n / $max';
  static const tournamentHost = 'Kurucu';
  static const tournamentQuestions = 'Soru sayısı';
  static String tournamentQuestionCount(int n) => '$n soru';
  static const tournamentStart = 'Başlat';
  static String tournamentNeedPlayers(int min) =>
      'Başlatmak için en az $min oyuncu gerekli.';
  static const tournamentWaitHost = 'Kurucunun başlatması bekleniyor…';
  static const tournamentKick = 'Odadan çıkar';
  static String tournamentKickTitle(String name) =>
      '$name odadan çıkarılsın mı?';
  static const tournamentKickBody = 'Bu odaya tekrar giremez.';
  static const tournamentKicked = 'Kurucu seni odadan çıkardı.';
  static String tournamentInvite(String code) =>
      'Kabaca turnuvasına gel! Oda kodu: $code';
  static const tournamentLocked = 'Kilitledin. Diğerleri bekleniyor…';
  static String tournamentLockedCount(int n, int of) => '$n / $of kilitledi';
  static const tournamentSeeStandings = 'Sonuçları gör';
  static const tournamentStandings = 'Sonuçlar';
  static String tournamentHits(int hits, int of) => '$hits / $of isabet';
  static const tournamentLeft = 'ayrıldı';
  static const tournamentBackToRoom = 'Odaya dön';
  static const tournamentQuitTitle = 'Turnuvadan çıkılsın mı?';
  static const tournamentQuitBody =
      'Kaçırdığın sorulardan taban puan alırsın, listede kalırsın. Maç '
      'bitene kadar ana ekrandan geri dönebilirsin.';
  static String tournamentErrorText(String code) => switch (code) {
    'no_room' || 'expired' => 'Bu kodla açık bir oda yok.',
    'in_progress' => 'Bu odada turnuva sürüyor. Bitince tekrar dene.',
    'room_full' => 'Oda dolu.',
    'name_taken' => "Odada bu adla biri var. Ayarlar'dan adını değiştir.",
    'kicked' => 'Kurucu seni bu odadan çıkardığı için tekrar katılamazsın.',
    'rejoin_over' => 'Turnuva bitti; sonuçlar odadakilerde.',
    'too_few' => tournamentNeedPlayers(3),
    _ => duelErrorText(code),
  };

  // Onboarding
  static const onboarding1 =
      'Her gün 5 sayısal soru. Tek bir sayı değil, bir aralık tahmin et.';
  static const onboarding2 =
      'Aralığın cevabı içeriyorsa puan alırsın. Dar aralık daha çok puan getirir.';
  static const onboarding3 =
      '%90 emin olduğun aralığı ver. Uzun vadede 10 sorunun 9\'unu tutturmalısın.';
  static const start = 'Başla';
}

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const _weekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

/// "4 Kasım": names a daily set in the share text, card and leaderboard.
String dayLabel(DateTime date) => '${date.day} ${_months[date.month - 1]}';

/// "4 Kasım Çarşamba", on today's card.
String dayLabelWithWeekday(DateTime date) =>
    '${dayLabel(date)} ${_weekdays[date.weekday - 1]}';

/// Display name of a question category.
String categoryName(QuestionCategory c) => switch (c) {
  QuestionCategory.geography => AppStrings.categoryGeography,
  QuestionCategory.history => AppStrings.categoryHistory,
  QuestionCategory.turkey => AppStrings.categoryTurkey,
  QuestionCategory.science => AppStrings.categoryScience,
  QuestionCategory.sports => AppStrings.categorySports,
  QuestionCategory.everyday => AppStrings.categoryEveryday,
  QuestionCategory.animals => AppStrings.categoryAnimals,
  QuestionCategory.companies => AppStrings.categoryCompanies,
  QuestionCategory.ottoman => AppStrings.categoryOttoman,
  QuestionCategory.architecture => AppStrings.categoryArchitecture,
  QuestionCategory.art => AppStrings.categoryArt,
  QuestionCategory.math => AppStrings.categoryMath,
  QuestionCategory.other => AppStrings.categoryOther,
};
