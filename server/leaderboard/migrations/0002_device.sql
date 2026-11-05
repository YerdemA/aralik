-- 2026-11-05: one account per device. Run once on a database created
-- before this date (schema.sql already has all of it for a new one):
--   npx wrangler d1 execute kabaca-leaderboard --remote --file=migrations/0002_device.sql

ALTER TABLE players ADD COLUMN device_hash TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS players_device
  ON players (device_hash) WHERE device_hash IS NOT NULL;
CREATE TABLE IF NOT EXISTS device_days (
  device_hash TEXT NOT NULL,
  day INTEGER NOT NULL,
  PRIMARY KEY (device_hash, day)
);
