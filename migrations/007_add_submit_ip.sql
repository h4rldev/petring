ALTER TABLE users ADD COLUMN submit_ip TEXT;
CREATE UNIQUE INDEX idx_users_submit_ip ON users(submit_ip);
