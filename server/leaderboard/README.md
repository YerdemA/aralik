# Kabaca – Günün liderleri sunucusu

Cloudflare Worker + D1 (SQLite). Ücretsiz katman yeterli (günde 100.000 istek, 5 GB veritabanı).
Uygulamaya dahil değildir. Ayrıntılı kurallar CLAUDE.md "Günün liderleri" maddesinde.

## Uç noktalar
| | | |
|---|---|---|
| `POST /v1/register` | `{nickname}` | `{id, token, nickname}` (201) |
| `POST /v1/rename` | `{id, token, nickname}` | `{nickname}` |
| `POST /v1/submit` | `{id, token, day, answers: [{q, low, high}] × 5}` | `{day, points, hits, rank, players}` |
| `GET /v1/day/{n}?player={id}` | | `{day, players, limit, top: [...], me}` |
| `POST /v1/delete` | `{id, token}` | `{deleted: true}` |

Puanlar uygulamayla aynı formülle hesaplanır (taban −50). `test/scoring_vectors.json` iki tarafta da test edilir.
Her günün tablosu ayrıdır (gün indeksi, 0 = 1 Kasım 2026, Türkiye saati), yeni sorularla sıfırlanır.

Hatalar `{error: "..."}`: `invalid_nickname`, `blocked_nickname`, `nickname_taken` (409),
`rate_limited` (429), `unauthorized` (401), `day_closed` / `wrong_questions` (422), `bad_answers` (400).

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
Kendi alan adını kullanmak için (alanın DNS'i aynı hesapta olmalı) `wrangler.toml`'daki `routes` satırını aç ve
yeniden `npm run deploy` çalıştır. DNS kaydını ve sertifikayı Cloudflare kendisi kurar.

Sonra adresi uygulamalara duyur (depo kökünde):

```powershell
python tools/publish_content.py --leaderboard https://kabaca-leaderboard.<hesap>.workers.dev/
git add docs/content/manifest.json; git commit -m "Leaderboard URL"; git push
```

Uygulamalar manifest'e en fazla 6 saatte bir baktığı için tablo, bir sonraki açılışlarda görünür.

## Güncelleme
`npm test`, sonra `npm run deploy`. Şema değişirse `schema.sql`'i güncelle ve `npm run db:init`.

## Ayarlar (`wrangler.toml` → `[vars]`)
- `FULL_BOARD_AT`: toplam katılımcı bu sayıya ulaşana kadar ilk `SMALL_BOARD` (10), sonra ilk `FULL_BOARD` (50) gösterilir.
- `REGISTER_LIMIT`: bir IP adresinden saatte en fazla kaç yeni takma ad.
- `CONTENT_BASE`: puanlamada kullanılan yayınlanmış banka ve takvim.

## Elle müdahale
```powershell
# Bugünün tablosu
npx wrangler d1 execute kabaca-leaderboard --remote --command "SELECT p.nickname, s.points FROM scores s JOIN players p ON p.id = s.player_id WHERE s.day = 3 ORDER BY s.points DESC"
# Uygunsuz bir takma adı sil (puanlarıyla)
npx wrangler d1 execute kabaca-leaderboard --remote --command "DELETE FROM scores WHERE player_id = (SELECT id FROM players WHERE nickname = 'X'); DELETE FROM players WHERE nickname = 'X'"
```

## Testler
`npm test`: Node'un yerleşik test aracı ve `node:sqlite` ile (Node 22.5+, ek paket yok), 22 test.
Gerçek Workers ortamında yerel deneme: `npx wrangler d1 execute kabaca-leaderboard --local --file=schema.sql`, sonra `npm run dev`.
`test/scoring_vectors.json`, uygulamanın `test/core/scoring_vectors_test.dart` testiyle ortaktır: puan formülü
iki tarafta birlikte değişmelidir.
