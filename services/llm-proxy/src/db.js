import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

// Ordered schema migrations. Each entry's index+1 is its target user_version, so
// the array order is the migration order. Never edit an applied migration in
// place — append a new one.
const MIGRATIONS = [
  // v1: device users (installations) + moderation audit + jobs + daily usage.
  (db) => {
    db.exec(`
      CREATE TABLE installations (
        installation_id   TEXT PRIMARY KEY,
        platform          TEXT NOT NULL DEFAULT 'unknown',
        app_version       TEXT NOT NULL DEFAULT '',
        device_model      TEXT NOT NULL DEFAULT '',
        status            TEXT NOT NULL DEFAULT 'allowed',
        status_reason     TEXT NOT NULL DEFAULT 'auto_registered',
        device_token_hash TEXT,
        created_at        TEXT NOT NULL,
        updated_at        TEXT NOT NULL,
        last_seen_at      TEXT
      );
      CREATE INDEX idx_installations_status ON installations(status);

      CREATE TABLE installation_audit (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        installation_id TEXT NOT NULL,
        status          TEXT NOT NULL,
        reason          TEXT NOT NULL DEFAULT '',
        source          TEXT NOT NULL DEFAULT '',
        changed_at      TEXT NOT NULL
      );
      CREATE INDEX idx_audit_installation ON installation_audit(installation_id, id);

      CREATE TABLE jobs (
        job_id            TEXT PRIMARY KEY,
        installation_id   TEXT NOT NULL,
        post_id           TEXT,
        status            TEXT NOT NULL,
        request_json      TEXT NOT NULL DEFAULT '{}',
        result_json       TEXT,
        reason            TEXT,
        fallback_required INTEGER NOT NULL DEFAULT 0,
        created_at        TEXT NOT NULL,
        updated_at        TEXT NOT NULL,
        started_at        TEXT,
        completed_at      TEXT
      );
      CREATE INDEX idx_jobs_installation ON jobs(installation_id, created_at);
      CREATE INDEX idx_jobs_status ON jobs(status);

      CREATE TABLE usage_daily (
        day         TEXT PRIMARY KEY,
        jobs        INTEGER NOT NULL DEFAULT 0,
        budget_cents INTEGER NOT NULL DEFAULT 0
      );
    `);
  },
  // v2: admin operators + role-based sessions for the management API.
  (db) => {
    db.exec(`
      CREATE TABLE admins (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        username      TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role          TEXT NOT NULL DEFAULT 'admin',
        disabled      INTEGER NOT NULL DEFAULT 0,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL
      );

      CREATE TABLE admin_sessions (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        admin_id     INTEGER NOT NULL,
        token_hash   TEXT NOT NULL UNIQUE,
        created_at   TEXT NOT NULL,
        expires_at   TEXT NOT NULL,
        last_used_at TEXT NOT NULL,
        FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
      );
      CREATE INDEX idx_sessions_admin ON admin_sessions(admin_id);
      CREATE INDEX idx_sessions_expires ON admin_sessions(expires_at);
    `);
  },
];

/**
 * Opens the SQLite database, applies pragmas and pending migrations, and returns
 * the connection. `:memory:` is supported for tests. Synchronous by design
 * (node:sqlite is sync); callers wrap in async store methods.
 */
export function openDatabase(path) {
  if (path !== ':memory:') {
    mkdirSync(dirname(path), { recursive: true });
  }
  const db = new DatabaseSync(path);
  db.exec('PRAGMA foreign_keys = ON');
  if (path !== ':memory:') {
    try {
      db.exec('PRAGMA journal_mode = WAL');
    } catch {
      // WAL may be unavailable on some filesystems; default journal is fine.
    }
  }
  migrate(db);
  return db;
}

function migrate(db) {
  const current = db.prepare('PRAGMA user_version').get().user_version;
  for (let version = current; version < MIGRATIONS.length; version += 1) {
    db.exec('BEGIN');
    try {
      MIGRATIONS[version](db);
      // user_version only takes a literal, not a bound param.
      db.exec(`PRAGMA user_version = ${version + 1}`);
      db.exec('COMMIT');
    } catch (error) {
      db.exec('ROLLBACK');
      throw error;
    }
  }
}
