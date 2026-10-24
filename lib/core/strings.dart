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
  static const todayDone = 'Bugünkü seti bitirdin';
  static const comeBackTomorrow = 'Yarın 5 yeni soru seni bekliyor.';
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
  static String placeWithCountry(String city, String country) =>
      '$city ($country)';
  static const distanceFunFact =
      'Mesafe, iki şehrin Wikidata koordinatlarından hesaplandı.';
  static const kilometres = 'km';

  // Result
  static const hit = 'İsabet!';
  static const miss = 'Iska';
  static const answer = 'Cevap';
  static const yourInterval = 'Aralığın';
  static const points = 'puan';
  static const source = 'Kaynak';
  static const daySummary = 'Günün özeti';
  static const share = 'Paylaş';

  // Calibration feedback
  static const calibrationTooNarrow = 'Aralıkların fazla dar.';
  static const calibrationTooWide = 'Daha cesur ol.';
  static const calibrationGood = 'Harika, tam kıvamında.';
  static const calibrationNoData =
      'Birkaç gün oyna, kalibrasyonun ortaya çıksın.';

  // Stats
  static const gamesPlayed = 'Oynanan gün';
  static const averageScore = 'Ortalama puan';
  static const hitRate = 'İsabet oranı';
  static const byCategory = 'Kategoriye göre';

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
