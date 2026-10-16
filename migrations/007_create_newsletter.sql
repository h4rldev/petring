CREATE TABLE newsletter (
  id INTEGER PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  content_markdown TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'published',
  authors TEXT NOT NULL DEFAULT '[]',
  posted_at INTEGER NOT NULL,
  edited_at INTEGER
);

CREATE INDEX idx_newsletter_posted_at ON newsletter(posted_at DESC);
CREATE INDEX idx_newsletter_slug ON newsletter(slug);
