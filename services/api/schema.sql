-- Fungible API metadata schema (Cloudflare D1 / SQLite).
-- Apply with: npx wrangler d1 execute fungible --file=schema.sql

CREATE TABLE IF NOT EXISTS sets (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  point_count INTEGER NOT NULL DEFAULT 0,
  bounds_json TEXT,
  blob_key    TEXT
);

CREATE TABLE IF NOT EXISTS shares (
  token      TEXT PRIMARY KEY,
  set_id     TEXT NOT NULL REFERENCES sets(id),
  expires_at TEXT,                       -- ISO-8601; NULL = never expires
  revoked    INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_shares_set ON shares(set_id);

-- Migration for databases created before expiry/revocation existed:
--   ALTER TABLE shares ADD COLUMN expires_at TEXT;
--   ALTER TABLE shares ADD COLUMN revoked INTEGER NOT NULL DEFAULT 0;
