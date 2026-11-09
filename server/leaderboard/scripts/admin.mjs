// Moderation of the live leaderboard (Cloudflare D1, through wrangler).
//
//   npm run admin -- suspects [days]   suspect scores of the last days (default 3)
//   npm run admin -- hide <nickname>   leave a player off everyone else's board
//   npm run admin -- unhide <nickname>
//   npm run admin -- reports           names reported in the last 7 days
//   npm run admin -- ban <nickname>    no one may use the name; its player is hidden
//   npm run admin -- unban <nickname>  lifts the ban, shows the player, clears reports
//
// Reports come from the apps (Bildir); a name with REPORT_HIDE_AT reporters
// is hidden by the server until reviewed. Look at `reports` every day or
// two: App Store guideline 1.2 expects reports to be acted on promptly.
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

function reports() {
  const rows = sql(
    `SELECT r.nickname, COUNT(*) AS n, GROUP_CONCAT(DISTINCT r.place) AS places,
            MAX(r.at) AS last, p.hidden,
            EXISTS (SELECT 1 FROM banned_names b WHERE b.name_key = r.name_key) AS banned
       FROM reports r LEFT JOIN players p ON p.nickname_key = r.name_key
      GROUP BY r.name_key ORDER BY n DESC, last DESC`,
  );
  if (rows.length === 0) {
    console.log('Bildirim yok.');
    return;
  }
  console.table(
    rows.map((r) => ({
      ad: r.nickname,
      bildirim: r.n,
      yer: r.places,
      son: new Date(r.last).toISOString().slice(0, 16).replace('T', ' '),
      gizli: r.hidden ? 'evet' : '',
      yasaklı: r.banned ? 'evet' : '',
    })),
  );
}

function setBanned(raw, banned) {
  const key = keyOf(raw);
  if (banned) {
    sql(
      `INSERT OR IGNORE INTO banned_names (name_key, at) VALUES (${quote(key)}, ${Date.now()})`,
    );
    sql(`UPDATE players SET hidden = 1 WHERE nickname_key = ${quote(key)}`);
    console.log(`${raw}: yasaklandı (tabloda gizli, düello ve turnuvaya giremez)`);
  } else {
    sql(`DELETE FROM banned_names WHERE name_key = ${quote(key)}`);
    sql(`DELETE FROM reports WHERE name_key = ${quote(key)}`);
    sql(`UPDATE players SET hidden = 0 WHERE nickname_key = ${quote(key)}`);
    console.log(`${raw}: yasak kalktı, bildirimler silindi`);
  }
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
  case 'reports':
    reports();
    break;
  case 'ban':
  case 'unban':
    if (!arg) throw new Error('Takma ad gerekli.');
    setBanned(arg, command === 'ban');
    break;
  default:
    console.log(
      'Kullanım: npm run admin -- suspects [gün] | hide <ad> | unhide <ad> | reports | ban <ad> | unban <ad>',
    );
}
