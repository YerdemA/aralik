-- Kabaca leaderboard (Cloudflare D1). Safe to run again.

CREATE TABLE IF NOT EXISTS players (
  id TEXT PRIMARY KEY,           -- random UUID
  token_hash TEXT NOT NULL,      -- SHA-256 of the app's secret token
  nickname TEXT NOT NULL,
  nickname_key TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL    -- ms since epoch
);

-- One row per player and day: each day is its own board.
CREATE TABLE IF NOT EXISTS scores (
  day INTEGER NOT NULL,          -- day index, 0 = 2026-11-01
  player_id TEXT NOT NULL,
  points INTEGER NOT NULL,
  hits INTEGER NOT NULL,
  submitted_at INTEGER NOT NULL,
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
