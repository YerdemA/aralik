-- 2026-11-07: nickname change cool-down and moderation. Run once on a
-- database created before this date (schema.sql already has all of it for
-- a new one), before deploying the code:
--   npx wrangler d1 execute kabaca-leaderboard --remote --file=migrations/0003_moderation.sql

ALTER TABLE players ADD COLUMN renamed_at INTEGER;
ALTER TABLE players ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0;
ALTER TABLE scores ADD COLUMN suspect INTEGER NOT NULL DEFAULT 0;
