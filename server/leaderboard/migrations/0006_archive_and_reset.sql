-- 2026-11-11: run once on a database created before this date:
--   npx wrangler d1 execute kabaca-leaderboard --remote --file=migrations/0006_archive_and_reset.sql
--
-- 1. The mascot sent with a daily score, for the archive tab (archive.js).
-- 2. Ranked duels now start at 0 instead of 1000 (ranked.js START): the
--    month's ratings so far are wiped, everyone starts again from 0.
ALTER TABLE scores ADD COLUMN look TEXT;
DELETE FROM duel_ratings;
