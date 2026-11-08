// The page at kabaca.app and www.kabaca.app: what the game is, so that a
// person (or a web filter's reviewer) who opens the domain sees a real
// site, not an empty or parked domain. Static, nothing stored, no scripts.

/** Hosts that get this page instead of the API. */
export const LANDING_HOSTS = new Set(['kabaca.app', 'www.kabaca.app']);

const PAGE = `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kabaca · Günlük tahmin oyunu</title>
<meta name="description" content="Kabaca, Türkçe bir günlük tahmin oyunudur (Android). Sayısal sorulara %90 emin olduğun bir aralıkla cevap verirsin.">
<style>
  :root { --bg: #1f2559; --panel: #fff8e7; --ink: #1f2559; --sun: #ffc53d; }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--ink);
    font: 17px/1.55 system-ui, -apple-system, Roboto, sans-serif; }
  main { max-width: 640px; margin: 0 auto; padding: 40px 16px 56px; }
  h1 { color: var(--sun); font-size: 44px; margin: 0 0 4px; }
  .lead { color: #fff; font-size: 20px; margin: 0 0 28px; }
  section { background: var(--panel); border-radius: 18px; padding: 20px 22px; margin-bottom: 16px; }
  h2 { font-size: 19px; margin: 0 0 8px; }
  p, ul { margin: 0 0 10px; }
  .q { font-weight: 600; }
  a { color: var(--ink); }
  footer { color: #c9cdf2; font-size: 14px; margin-top: 24px; }
  footer a { color: #fff; }
</style>
</head>
<body>
<main>
  <h1>Kabaca</h1>
  <p class="lead">%90 emin olduğun aralığı ver.</p>
  <section>
    <h2>Nasıl bir oyun?</h2>
    <p>Kabaca, 5–10 dakikalık beklemelerde oynanan Türkçe bir günlük tahmin oyunudur (Android).
    Sayısal bir soruya tek bir sayıyla değil, %90 emin olduğun bir aralıkla cevap verirsin:</p>
    <p class="q">Ağrı Dağı kaç metre yüksekliktedir? → 4.500 – 5.500 m</p>
    <p>Aralık cevabı içeriyorsa puan alırsın, aralık ne kadar darsa o kadar çok. Uzun vadede oyun
    kalibrasyonunu ölçer: "%90 eminim" dediğinde gerçekten 10 sorunun 9'unu tutturuyor musun?</p>
  </section>
  <section>
    <h2>Modlar</h2>
    <ul>
      <li>Günün seti: herkes aynı gün aynı 5 soruyu çözer.</li>
      <li>Bir tur at: sınırsız serbest oyun.</li>
      <li>Düello ve turnuva: arkadaşlarınla aynı soruları aynı anda cevapla.</li>
      <li>Günün liderleri (isteğe bağlı).</li>
    </ul>
    <p>Her sorunun cevabı kaynaklıdır (Wikidata, Dünya Bankası, NASA ve diğerleri). Reklam ve hesap yoktur.</p>
  </section>
  <section lang="en">
    <h2>In English</h2>
    <p>Kabaca is a Turkish daily estimation game for Android: answer numeric trivia questions with a
    range you are 90% sure of. This domain hosts the game's website and its optional leaderboard and
    multiplayer server (api.kabaca.app).</p>
  </section>
  <footer>
    <a href="https://github.com/YerdemA/aralik">Kaynak kodu</a> ·
    <a href="https://yerdema.github.io/aralik/privacy-policy.html">Gizlilik politikası</a> ·
    Geliştirici: Yusuf Erdem Aykaç
  </footer>
</main>
</body>
</html>
`;

/** The answer for a request to one of LANDING_HOSTS. */
export function landing(request) {
  const url = new URL(request.url);
  if (url.hostname === 'www.kabaca.app') {
    return Response.redirect(`https://kabaca.app${url.pathname}`, 301);
  }
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return new Response('Method not allowed', { status: 405 });
  }
  const path = url.pathname;
  if (path === '/robots.txt') {
    return new Response('User-agent: *\nAllow: /\n', {
      headers: { 'content-type': 'text/plain; charset=utf-8' },
    });
  }
  const found = path === '/' || path === '/index.html';
  return new Response(found ? PAGE : PAGE.replace('<main>', '<main><p class="lead">Sayfa bulunamadı.</p>'), {
    status: found ? 200 : 404,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'public, max-age=3600',
    },
  });
}
