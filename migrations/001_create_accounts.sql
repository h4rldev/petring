CREATE TABLE accounts (
  id INTEGER PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT CHECK(role IN ('superadmin', 'admin')) NOT NULL,
  auth_version INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER /* Only updated on name or password change */
);

CREATE INDEX idx_accounts_username ON accounts(username);
CREATE UNIQUE INDEX idx_one_superadmin ON accounts(role) WHERE role = 'superadmin';
