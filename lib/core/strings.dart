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
  static const comeBackTomorrow = 'Yarın 5 yeni soru seni bekliyor.';
  static const todayTitle = 'Bugünün 5 sorusu';
  static const todayHint = 'Herkes bugün aynı soruları çözüyor.';
  static String scoreOutOf(int points, int max) => '$points / $max';
  static String streakDays(int days) => '$days gün';
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

  // Leaderboard
  static const leaderboard = 'Günün liderleri';
  static String leaderboardPlayers(int n) => '$n oyuncu';
  static const leaderboardResets = 'Tablo her gün yeni sorularla sıfırlanır.';
  static const leaderboardEmpty = 'Henüz kimse yok. İlk sen ol!';
  static const leaderboardJoin = 'Tabloya katıl';
  static const leaderboardJoinTitle = 'Liderlere katıl';
  static const leaderboardJoinBody =
      'Bir takma ad seç. Tabloda yalnızca takma adın ve günlük puanın '
      'görünür. Başka hiçbir bilgi gönderilmez.';
  static const leaderboardFinishSet =
      'Günün setini bitirince puanın buraya eklenir.';
  static const leaderboardSendFailed = 'Puanın henüz gönderilemedi.';
  static const leaderboardOffline =
      'Bağlanılamadı. İnternetini kontrol edip tekrar dene.';
  static const leaderboardError = 'Bir sorun oldu. Biraz sonra tekrar dene.';
  static const leaderboardMissing =
      'Hesabın sunucuda bulunamadı. Yeniden katılabilirsin.';
  static String hitsOutOf(int hits, int total) => '$hits/$total isabet';
  static const you = 'Sen';
  static const retry = 'Tekrar dene';
  static const nicknameLabel = 'Takma ad';
  static const nicknameHint = '3–16 harf ya da rakam';
  static const nicknameTooShort = 'En az 3 karakter olmalı.';
  static const nicknameTooLong = 'En fazla 16 karakter olabilir.';
  static const nicknameBadCharacters =
      'Harf, rakam, boşluk ve . _ - kullanabilirsin. En az bir harf olmalı.';
  static const nicknameTaken = 'Bu takma ad alınmış.';
  static const nicknameBlocked = 'Bu takma ad kullanılamaz.';
  static const rateLimited = 'Çok fazla deneme oldu. Biraz sonra tekrar dene.';
  static const join = 'Katıl';
  static const save = 'Kaydet';
  static const cancel = 'Vazgeç';
  static String joinedAs(String name) => 'Hoş geldin, $name!';
  static const leaderboardSection = 'Liderlik tablosu';
  static const nicknameSubtitle = 'Takma adın, değiştirmek için dokun';
  static const changeNickname = 'Takma adı değiştir';
  static const leaveLeaderboard = 'Tablodan ayrıl';
  static const leaveLeaderboardHint =
      'Takma adın ve puanların sunucudan silinir.';
  static const leaveConfirmTitle = 'Tablodan ayrılsın mı?';
  static const leaveConfirmBody =
      'Takma adın ve gönderdiğin tüm puanlar sunucudan silinir. İstediğin '
      'zaman yeniden katılabilirsin.';
  static const leave = 'Ayrıl';
  static const leftLeaderboard = 'Tablodan ayrıldın, verilerin silindi.';

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

  // Settings
  static const appearance = 'Görünüm';
  static const theme = 'Tema';
  static const themeSystem = 'Sistem';
  static const themeLight = 'Açık';
  static const themeDark = 'Koyu';
  static const howToPlay = 'Nasıl oynanır?';
  static const privacy = 'Gizlilik';
  static const about = 'Hakkında';
  static const dataSources = 'Veri kaynakları ve lisanslar';
  static const dataSourcesHint = 'Soruların ve cevapların kaynakları';
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
  QuestionCategory.other => AppStrings.categoryOther,
};
