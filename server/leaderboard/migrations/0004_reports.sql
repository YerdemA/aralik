-- 2026-11-09: reports and banned names (App Store guideline 1.2). Run once
-- on the live database before deploying the code:
--   npx wrangler d1 execute kabaca-leaderboard --remote --file=migrations/0004_reports.sql

CREATE TABLE IF NOT EXISTS reports (
  name_key TEXT NOT NULL,
  nickname TEXT NOT NULL,
  place TEXT NOT NULL,
  reporter TEXT NOT NULL,
  at INTEGER NOT NULL,
  PRIMARY KEY (name_key, reporter)
);
CREATE INDEX IF NOT EXISTS reports_at ON reports (at);

CREATE TABLE IF NOT EXISTS banned_names (
  name_key TEXT PRIMARY KEY,
  at INTEGER NOT NULL
);
