-- Kabaca leaderboard (Cloudflare D1). Safe to run again.

CREATE TABLE IF NOT EXISTS players (
  id TEXT PRIMARY KEY,           -- random UUID
  token_hash TEXT NOT NULL,      -- SHA-256 of the app's secret token
  nickname TEXT NOT NULL,
  nickname_key TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL,   -- ms since epoch
  device_hash TEXT,              -- SHA-256 of the app's device key; null for old apps
  renamed_at INTEGER,            -- last nickname change (ms); null = never
  hidden INTEGER NOT NULL DEFAULT 0  -- 1: left off the board for everyone else
);
CREATE UNIQUE INDEX IF NOT EXISTS players_device
  ON players (device_hash) WHERE device_hash IS NOT NULL;

-- One row per player and day: each day is its own board.
CREATE TABLE IF NOT EXISTS scores (
  day INTEGER NOT NULL,          -- day index, 0 = 2026-11-01
  player_id TEXT NOT NULL,
  points INTEGER NOT NULL,
  hits INTEGER NOT NULL,
  submitted_at INTEGER NOT NULL,
  suspect INTEGER NOT NULL DEFAULT 0,  -- 1: points at or above SUSPECT_POINTS
  PRIMARY KEY (day, player_id)
);
CREATE INDEX IF NOT EXISTS scores_rank
  ON scores (day, points DESC, submitted_at, player_id);
CREATE INDEX IF NOT EXISTS scores_player ON scores (player_id);

-- Registrations per hashed IP, for the rate limit; kept one day.
CREATE TABLE IF NOT EXISTS register_log (
  ip_hash TEXT NOT NULL,
  at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS register_log_ip ON register_log (ip_hash, at);

-- Days a device sent a score for, under any account: a reinstalled app
-- cannot send the same day again. Not linked to a nickname; kept 3 days
-- (scores are accepted for yesterday, today and tomorrow only).
CREATE TABLE IF NOT EXISTS device_days (
  device_hash TEXT NOT NULL,
  day INTEGER NOT NULL,
  PRIMARY KEY (device_hash, day)
);

-- Reports of names other players see (App Store guideline 1.2). One row
-- per name and reporter (a salted hash of the IP, not linked to anything
-- else); kept 7 days. Reviewed with scripts/admin.mjs.
CREATE TABLE IF NOT EXISTS reports (
  name_key TEXT NOT NULL,
  nickname TEXT NOT NULL,
  place TEXT NOT NULL,           -- board, duel or tournament
  reporter TEXT NOT NULL,
  at INTEGER NOT NULL,
  PRIMARY KEY (name_key, reporter)
);
CREATE INDEX IF NOT EXISTS reports_at ON reports (at);

-- Names the moderator banned: they cannot be taken, nor used in duels or
-- tournaments.
CREATE TABLE IF NOT EXISTS banned_names (
  name_key TEXT PRIMARY KEY,
  at INTEGER NOT NULL
);

-- Monthly ranked duels (src/ranked.js): one row per month, mode and
-- player who joined the leaderboard; two months kept.
CREATE TABLE IF NOT EXISTS duel_ratings (
  month INTEGER NOT NULL,        -- YYYYMM in Turkey time
  mode TEXT NOT NULL,            -- 'bank' (knowledge) or 'math'
  player_id TEXT NOT NULL,
  rating INTEGER NOT NULL,
  played INTEGER NOT NULL,
  won INTEGER NOT NULL,
  drawn INTEGER NOT NULL,
  points INTEGER NOT NULL,       -- sum of the player's match totals
  hits INTEGER NOT NULL,
  answered INTEGER NOT NULL,
  look TEXT,                     -- mascot code last used, for the card
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (month, mode, player_id)
);
CREATE INDEX IF NOT EXISTS duel_ratings_rank
  ON duel_ratings (month, mode, rating DESC, updated_at, player_id);
CREATE INDEX IF NOT EXISTS duel_ratings_player ON duel_ratings (player_id);
