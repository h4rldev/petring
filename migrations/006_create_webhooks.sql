CREATE TABLE webhooks (
  id INTEGER PRIMARY KEY,
  url TEXT NOT NULL,
  format TEXT NOT NULL DEFAULT 'generic',
  events TEXT NOT NULL DEFAULT '["*"]',
  enabled INTEGER NOT NULL DEFAULT 1,
  secret TEXT,
  last_status INTEGER,
  last_error TEXT,
  last_delivered_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER
);
