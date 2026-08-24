-- Migration 0002: Add 'windows' to machines check constraint
CREATE TABLE machines_new (
    os TEXT PRIMARY KEY CHECK (os IN ('macos', 'linux', 'windows')),
    last_seen INTEGER NOT NULL
);

INSERT INTO machines_new (os, last_seen) SELECT os, last_seen FROM machines;
DROP TABLE machines;
ALTER TABLE machines_new RENAME TO machines;
