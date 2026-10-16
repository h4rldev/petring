CREATE TABLE blocked_words (
  scope TEXT PRIMARY KEY,
  enforced_by TEXT NOT NULL,
  patterns TEXT NOT NULL DEFAULT '[]',
  keywords TEXT NOT NULL DEFAULT '[]',
  updated_at INTEGER
);

INSERT OR IGNORE INTO blocked_words (scope, enforced_by, keywords) VALUES
  ('user_url', 'system', '["discord","localhost","127.0.0.1","google","twitter","x.com","reddit","pixiv","tumblr","facebook","instagram","youtube","tiktok","snapchat","pinterest","github","gitlab","bitbucket","medium","linkedin","stackoverflow","stackexchange"]'),
  ('ad_url', 'system', '["discord","localhost","127.0.0.1","catbox","fileditch","imageshack","google","imgbb","gyazo","twitter","reddit","pixiv","tumblr"]'),
  ('global', 'system', '[]');
