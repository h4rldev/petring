CREATE TABLE notifications (
  id INTEGER PRIMARY KEY,
  kind TEXT NOT NULL,
  action TEXT NOT NULL,
  username TEXT,
  content TEXT,
  ref_id TEXT,
  target TEXT,
  read INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_notification_created_at ON notifications(created_at);
