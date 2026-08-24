CREATE TABLE IF NOT EXISTS machines (
    os TEXT PRIMARY KEY CHECK (os IN ('macos', 'linux', 'windows')),
    last_seen INTEGER NOT NULL
);
