-- 2026-11-10: monthly ranked duels (src/ranked.js). Run once on a database
-- created before this date (schema.sql already has it for a new one):
--   npx wrangler d1 execute kabaca-leaderboard --remote --file=migrations/0005_ranked.sql

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
