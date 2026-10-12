CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  url TEXT UNIQUE NOT NULL,
  contact TEXT NOT NULL DEFAULT '',
  manage_token_hash TEXT, /* hashed Mullvad-style manage token, one per user */
  verified INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  edited_at INTEGER, /* Changes on url changes, etc. */
  verified_at INTEGER
);

CREATE INDEX idx_users_verified ON users(verified);
CREATE INDEX idx_users_created_at ON users(created_at);
