# Kabaca – Günün liderleri, düello ve turnuva sunucusu

Cloudflare Worker + D1 (SQLite) + Durable Objects (düello ve turnuva odaları). Ücretsiz katman yeterli (günde 100.000 istek, 5 GB veritabanı).
Uygulamaya dahil değildir.

## Uç noktalar
| | | |
|---|---|---|
| `POST /v1/register` | `{nickname, device}` | `{id, token, nickname, restored}` (201; aynı cihazın hesabı geri gelirse 200) |
| `POST /v1/rename` | `{id, token, nickname}` | `{nickname}` |
| `POST /v1/submit` | `{id, token, day, answers: [{q, low, high}] × 5, device}` | `{day, points, hits, rank, players}` |
| `GET /v1/day/{n}?player={id}` | | `{day, players, limit, top: [...], me}` |
| `POST /v1/delete` | `{id, token}` | `{deleted: true}` |
| `POST /v1/duel/rooms` | | `{code}` (201) |
| `GET /v1/duel/rooms/{code}?v=1&name=…&bank=N` | WebSocket | odanın mesajları |
| `GET /v1/duel/random?v=1&name=…&bank=N` | WebSocket | `searching`, sonra `matched` (oda kodu) |
| `POST /v1/tournament/rooms` | | `{code}` (201) |
| `GET /v1/tournament/rooms/{code}?v=1&name=…&bank=N` | WebSocket | turnuva odasının mesajları |

Düello ve turnuva bağlantılarına `&rejoin=ANAHTAR` eklenirse kopan oyuncu oyuna geri döner (anahtar `start` / `welcome` mesajında gelir).

Puanlar uygulamayla aynı formülle hesaplanır (taban −50). `test/scoring_vectors.json` iki tarafta da test edilir.
Her günün tablosu ayrıdır (gün indeksi, 0 = 1 Kasım 2026, Türkiye saati), yeni sorularla sıfırlanır.

Hatalar `{error: "..."}`: `invalid_nickname`, `blocked_nickname`, `nickname_taken` (409),
`rate_limited` / `rename_wait` (429; `rename_wait` ile `retry_at` ms), `unauthorized` (401), `day_closed` / `wrong_questions` / `already_played` (422), `bad_answers` / `bad_device` (400),
`update_required` (426).

## İlk kurulum (bir kez)
PowerShell, bu klasörde (`server\leaderboard`):

```powershell
npm install
npx wrangler login                              # tarayıcıda Cloudflare hesabına izin ver
npx wrangler d1 create kabaca-leaderboard       # config'e eklemeyi sorarsa hayır de; database_id'yi wrangler.toml'a yaz
npm run db:init                                 # tabloları kur
npm run deploy                                  # adresi yazar: https://kabaca-leaderboard.<hesap>.workers.dev
npx wrangler secret put IP_SALT                 # rastgele uzun bir metin yapıştır (IP özetleri için)
```
**Kendi alan adı (zorunlu):** Türk operatörleri (Turkcell, Türk Telekom) `*.workers.dev` adreslerini keser. Yayındaki
adres `https://api.kabaca.app` (`wrangler.toml` → `routes`, `custom_domain = true`; `kabaca.app` aynı Cloudflare
hesabında). DNS kaydını ve sertifikayı Cloudflare kendisi kurar. `workers_dev = true` eski manifest'ler için açık kalır.

Sonra adresi uygulamalara duyur (depo kökünde):

```powershell
python tools/publish_content.py --leaderboard https://api.kabaca.app/
git add docs/content/manifest.json; git commit -m "Leaderboard URL"; git push
```

Uygulamalar manifest'e en fazla 6 saatte bir baktığı için tablo, bir sonraki açılışlarda görünür.

## Kopan bağlantı
Düello: oyun sırasında bağlantı kopunca rakibe `away` gider. Her oyuncunun düello boyunca toplam `AWAY_BUDGET_MS` (45 sn)
uzak kalma hakkı vardır, her kopmada kaldığı yerden azalır. Açık soru kimse için durmaz (kopan geç kalırsa −50; cevap
aramak için bağlantıyı kesmek bir şey kazandırmaz), açılan soru ise kopan dönene kadar bekler. Oyuncu aynı oda adresine
`rejoin` anahtarıyla bağlanırsa `resume` ile oyunun tüm durumunu ve kalan hakkını alır, rakibe `back` gider. Hakkı bitince
rakip kazanır; ikisinin de biterse oda silinir. Sessiz bağlantılar `src/liveness.js` ile 10 sn'de fark edilir. Aynı oyuncunun eski, ölü bağlantısı
yenisi gelince kapatılır. Turnuva: oyun durmaz; kopan oyuncu maç bitene kadar anahtarla döner (`resume`), dönmezse `left`.

## Düello odaları
Her oda kodundan türetilen bir Durable Object'tir (`src/duel_room.js`, SQLite tabanlı, ücretsiz katmanda çalışır).
Rastgele rakip arayanlar önce tek bir lobiye bağlanır (`src/duel_lobby.js`): lobi bekleyen iki oyuncu için oda açar,
ikisine de kodu gönderir; uygulamalar sonra odaya arkadaş gibi katılır. 2 dakikada rakip çıkmazsa arama `no_opponent` ile biter.
Kurallar `src/duel.js` içinde saf fonksiyonlardır; protokol dosyanın başında yazar. Giriş noktası `src/worker.js`.
`npm run deploy`, `wrangler.toml` içindeki göçlerle (`v1-duel`, `v2-duel-lobby`) sınıfları oluşturur. Ek kurulum gerekmez.
Yerel deneme: `npm run dev`, sonra `ws://127.0.0.1:8787/v1/duel/rooms/KOD?v=1&name=Ayse&bank=1000`.

## Turnuva odaları
`POST /v1/tournament/rooms` bir oda açar ve kodu döner; `GET /v1/tournament/rooms/KOD?v=1&name=…&bank=N` WebSocket ile katılır.
3–8 oyuncu; ilk katılan kurucudur, soru sayısını (5/10) seçer, oyuncu atar, başlatır. Kurallar ve protokol `src/tournament.js`
başında, oda nesnesi `src/tournament_room.js`. `npm run deploy`, `wrangler.toml` içindeki `v3-tournament` göçüyle sınıfı oluşturur.

## Güncelleme
`npm test`, sonra `npm run deploy`. Şema değişirse `schema.sql`'i güncelle (yeni veritabanı için) ve var olan veritabanına
`migrations/` altındaki dosyayı bir kez uygula, **kodu yayınlamadan önce**:
```powershell
npx wrangler d1 execute kabaca-leaderboard --remote --file=migrations/0002_device.sql
npx wrangler d1 execute kabaca-leaderboard --remote --file=migrations/0003_moderation.sql
```

## Kötüye kullanıma karşı
- **Düello sınırı:** oda açma, odaya bağlanma ve rakip arama IP başına dakikada 20 istekle sınırlı (Cloudflare rate limiting
  bağlaması `DUEL_LIMITER`, `wrangler.toml`). Aşınca `429 rate_limited`.
- **Ad değişikliği:** `RENAME_DAYS` (3) günde bir; erken denemede `429 rename_wait` ve `retry_at` (ms). Kayıttaki ilk ad sayılmaz.
- **Kuşkulu puan:** günün puanı `SUSPECT_POINTS` (470) ve üstüyse `scores.suspect = 1`. Bakmak ve gerekirse gizlemek için:
  ```powershell
  npm run admin -- suspects 3      # son 3 günün kuşkulu puanları
  npm run admin -- hide Kaplan     # başkalarının tablosundan çıkar (kendisi fark etmez)
  npm run admin -- unhide Kaplan
  ```
  Gizli oyuncu kendi tablosunda kendini görür, görünür oyuncular arasında sıralanır; oyuncu sayısına yalnızca kendisi için sayılır.
- **Tablo önbelleği:** bir günün tablosu `BOARD_CACHE_SECONDS` (30) saniye kenar önbellekte tutulur; yeni puan gelince silinir.

## Cihaz başına tek hesap
Uygulama (1.0.3+) kayıtta ve gönderimde `device` alanında Android cihaz kimliğinin SHA-256 özetini yollar; sunucu bunu
tuzlayıp bir kez daha özetler (`players.device_hash`). Aynı cihazdan kayıt eski hesabı yeni anahtarla geri verir
(`200`, `restored: true`). `device_days` tablosu bir cihazın hangi günleri gönderdiğini adla bağsız tutar (cron 3 günden
eskisini siler); başka hesapla aynı gün `422 already_played` döner. Anahtar göndermeyen eski uygulamalar
`REQUIRE_DEVICE = "1"` yapılana kadar kabul edilir (sonra `426 update_required`). İsteğe bağlı gizli tuz:
`npx wrangler secret put DEVICE_SALT` (yoksa `IP_SALT` kullanılır; sonradan değiştirilirse cihazlar tanınmaz).

## Ayarlar (`wrangler.toml` → `[vars]`)
- `FULL_BOARD_AT`: toplam katılımcı bu sayıya ulaşana kadar ilk `SMALL_BOARD` (10), sonra ilk `FULL_BOARD` (50) gösterilir.
- `REGISTER_LIMIT`: bir IP adresinden saatte en fazla kaç yeni takma ad.
- `CONTENT_BASE`: puanlamada kullanılan yayınlanmış banka ve takvim.
- `REQUIRE_DEVICE`: `"1"` cihaz anahtarı göndermeyen (1.0.3'ten eski) uygulamaların kaydını ve gönderimini reddeder.

## Elle müdahale
```powershell
# Bugünün tablosu
npx wrangler d1 execute kabaca-leaderboard --remote --command "SELECT p.nickname, s.points FROM scores s JOIN players p ON p.id = s.player_id WHERE s.day = 3 ORDER BY s.points DESC"
# Uygunsuz bir takma adı sil (puanlarıyla)
npx wrangler d1 execute kabaca-leaderboard --remote --command "DELETE FROM scores WHERE player_id = (SELECT id FROM players WHERE nickname = 'X'); DELETE FROM players WHERE nickname = 'X'"
```

## Testler
`npm test`: Node'un yerleşik test aracı ve `node:sqlite` ile (Node 22.5+, ek paket yok), 40 test.
Gerçek Workers ortamında yerel deneme: `npx wrangler d1 execute kabaca-leaderboard --local --file=schema.sql`, sonra `npm run dev`.
`test/scoring_vectors.json`, uygulamanın `test/core/scoring_vectors_test.dart` testiyle ortaktır: puan formülü
iki tarafta birlikte değişmelidir.
