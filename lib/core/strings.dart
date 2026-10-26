/// Every user-facing Turkish string lives here.
abstract final class AppStrings {
  static const appName = 'Aralık';
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
  static const comeBackTomorrow = 'Yarın 5 yeni soru seni bekliyor.';
  static const previewEdition = '(deneme)';
  static String streakDays(int days) => '$days gün';
  static const noValue = '–';
  static const streak = 'Seri';
  static const lastScore = 'Son skor';
  static const calibration = 'Kalibrasyon';
  static const freePlay = 'Serbest mod';
  static const freePlayHint = 'Sınırsız tur, hep yeni sorular';
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
  static const answer = 'Cevap';
  static const yourInterval = 'Aralığın';
  static const points = 'puan';
  static const source = 'Kaynak';
  static const daySummary = 'Günün özeti';
  static const roundSummary = 'Tur özeti';
  static const share = 'Paylaş';
  static const newRound = 'Yeni tur';
  static const backHome = 'Ana ekran';
  static const shareSubject = 'Aralık skorum';

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

  // Settings
  static const theme = 'Tema';
  static const themeSystem = 'Sistem';
  static const themeLight = 'Açık';
  static const themeDark = 'Koyu';
  static const howToPlay = 'Nasıl oynanır?';
  static const privacy = 'Gizlilik';
  static const about = 'Hakkında';

  // Onboarding
  static const onboarding1 =
      'Her gün 5 sayısal soru. Tek bir sayı değil, bir aralık tahmin et.';
  static const onboarding2 =
      'Aralığın cevabı içeriyorsa puan alırsın. Dar aralık daha çok puan getirir.';
  static const onboarding3 =
      '%90 emin olduğun aralığı ver. Uzun vadede 10 sorunun 9\'unu tutturmalısın.';
  static const start = 'Başla';
}
