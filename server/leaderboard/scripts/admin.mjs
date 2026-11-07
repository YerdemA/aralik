// Moderation of the live leaderboard (Cloudflare D1, through wrangler).
//
//   npm run admin -- suspects [days]   suspect scores of the last days (default 3)
//   npm run admin -- hide <nickname>   leave a player off everyone else's board
//   npm run admin -- unhide <nickname>
//
// A hidden player is not told: their own board still shows them, ranked
// among the visible players. Scores at or above SUSPECT_POINTS (wrangler.toml)
// are marked suspect when sent; look at them before hiding anyone.
import { execFileSync } from 'node:child_process';
import { cleanNickname, nicknameKey } from '../src/nickname.js';
import { turkeyDayIndex } from '../src/days.js';

const DATABASE = 'kabaca-leaderboard';

function sql(command) {
  const out = execFileSync(
    'npx',
    ['wrangler', 'd1', 'execute', DATABASE, '--remote', '--json', '--command', command],
    { encoding: 'utf8', shell: process.platform === 'win32' },
  );
  return JSON.parse(out)[0]?.results ?? [];
}

/** A string literal for SQL; the only input is a nickname from the CLI. */
function quote(text) {
  return `'${String(text).replaceAll("'", "''")}'`;
}

function keyOf(raw) {
  const name = cleanNickname(raw);
  if (!name) throw new Error(`Geçersiz takma ad: ${raw}`);
  return nicknameKey(name);
}

function setHidden(raw, hidden) {
  const key = keyOf(raw);
  const found = sql(
    `SELECT id, nickname, hidden FROM players WHERE nickname_key = ${quote(key)}`,
  );
  if (found.length === 0) {
    console.log(`Oyuncu yok: ${raw}`);
    return;
  }
  sql(
    `UPDATE players SET hidden = ${hidden ? 1 : 0} WHERE nickname_key = ${quote(key)}`,
  );
  console.log(`${found[0].nickname}: ${hidden ? 'gizlendi' : 'yeniden görünür'}`);
}

function suspects(days) {
  const from = turkeyDayIndex(Date.now()) - Math.max(0, days - 1);
  const rows = sql(
    `SELECT s.day, p.nickname, s.points, s.hits, p.hidden
       FROM scores s JOIN players p ON p.id = s.player_id
      WHERE s.suspect = 1 AND s.day >= ${Number(from)}
      ORDER BY s.day DESC, s.points DESC`,
  );
  if (rows.length === 0) {
    console.log('Kuşkulu puan yok.');
    return;
  }
  console.table(
    rows.map((r) => ({
      gün: r.day,
      ad: r.nickname,
      puan: r.points,
      isabet: r.hits,
      gizli: r.hidden ? 'evet' : '',
    })),
  );
}

const [command, arg] = process.argv.slice(2);
switch (command) {
  case 'suspects':
    suspects(Number(arg ?? 3));
    break;
  case 'hide':
  case 'unhide':
    if (!arg) throw new Error('Takma ad gerekli.');
    setHidden(arg, command === 'hide');
    break;
  default:
    console.log('Kullanım: npm run admin -- suspects [gün] | hide <ad> | unhide <ad>');
}
