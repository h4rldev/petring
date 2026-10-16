CREATE TABLE ads (
  id INTEGER PRIMARY KEY,
  username TEXT UNIQUE NOT NULL REFERENCES users(username) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  ad_url TEXT UNIQUE NOT NULL,
  verified INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  edited_at INTEGER,
  verified_at INTEGER
);

CREATE INDEX idx_ads_verified ON ads(verified);
CREATE INDEX idx_ads_created_at ON ads(created_at);
