import { openDatabase } from './db.js';

function nowIso() {
  return new Date().toISOString();
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

/**
 * SQLite-backed store for device users (installations), moderation audit, jobs,
 * daily usage, admin operators, and admin sessions. node:sqlite is synchronous
 * and single-threaded, so each method is atomic with respect to other methods;
 * multi-statement mutations additionally use explicit transactions.
 *
 * Methods are async to preserve the original store interface and to keep the
 * door open for an async driver later.
 */
export class SqliteStore {
  constructor(pathOrDb) {
    this.db = typeof pathOrDb === 'string' ? openDatabase(pathOrDb) : pathOrDb;
  }

  // Schema is applied at open(); kept for interface compatibility.
  async load() {}

  close() {
    this.db.close();
  }

  // --- Installations (device users) ---

  async getInstallation(installationId) {
    const row = this.db
      .prepare('SELECT * FROM installations WHERE installation_id = ?')
      .get(installationId);
    return row ?? null;
  }

  async upsertInstallation(installation) {
    const existing = await this.getInstallation(installation.installation_id);
    const now = nowIso();
    if (existing) {
      this.db
        .prepare(
          `UPDATE installations
             SET platform = ?, app_version = ?, device_model = ?,
                 updated_at = ?, last_seen_at = ?
           WHERE installation_id = ?`,
        )
        .run(
          installation.platform ?? existing.platform,
          installation.app_version ?? existing.app_version,
          installation.device_model ?? existing.device_model,
          now,
          now,
          installation.installation_id,
        );
    } else {
      this.db
        .prepare(
          `INSERT INTO installations
             (installation_id, platform, app_version, device_model, status,
              status_reason, device_token_hash, created_at, updated_at, last_seen_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .run(
          installation.installation_id,
          installation.platform ?? 'unknown',
          installation.app_version ?? '',
          installation.device_model ?? '',
          installation.status ?? 'allowed',
          installation.status_reason ?? 'auto_registered',
          installation.device_token_hash ?? null,
          installation.created_at ?? now,
          now,
          now,
        );
      this._appendAudit({
        installationId: installation.installation_id,
        status: installation.status ?? 'allowed',
        reason: installation.status_reason ?? 'auto_registered',
        source: 'system',
        changedAt: now,
      });
    }
    return this.getInstallation(installation.installation_id);
  }

  async setInstallationStatus({ installationId, status, reason, source }) {
    const now = nowIso();
    const existing = await this.getInstallation(installationId);
    if (!existing) {
      await this.upsertInstallation(makeInstallation({ installationId, platform: 'unknown' }));
    }
    const auditReason = reason || 'manual update';
    this.db
      .prepare(
        `UPDATE installations
           SET status = ?, status_reason = ?, updated_at = ?
         WHERE installation_id = ?`,
      )
      .run(status, auditReason, now, installationId);
    this._appendAudit({
      installationId,
      status,
      reason: auditReason,
      source: source || 'internal',
      changedAt: now,
    });
    return this.getInstallation(installationId);
  }

  async setDeviceTokenHash(installationId, tokenHash) {
    this.db
      .prepare(
        'UPDATE installations SET device_token_hash = ?, updated_at = ? WHERE installation_id = ?',
      )
      .run(tokenHash, nowIso(), installationId);
    return this.getInstallation(installationId);
  }

  _appendAudit({ installationId, status, reason, source, changedAt }) {
    this.db
      .prepare(
        `INSERT INTO installation_audit (installation_id, status, reason, source, changed_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(installationId, status, reason, source, changedAt);
  }

  async getInstallationAudit(installationId, limit = 50) {
    return this.db
      .prepare(
        'SELECT status, reason, source, changed_at FROM installation_audit WHERE installation_id = ? ORDER BY id DESC LIMIT ?',
      )
      .all(installationId, limit);
  }

  async listInstallations({ status, limit = 50, offset = 0 } = {}) {
    const where = status ? 'WHERE status = ?' : '';
    const args = status ? [status, limit, offset] : [limit, offset];
    return this.db
      .prepare(
        `SELECT installation_id, platform, app_version, status, status_reason,
                created_at, updated_at, last_seen_at
           FROM installations ${where}
          ORDER BY updated_at DESC LIMIT ? OFFSET ?`,
      )
      .all(...args);
  }

  async countInstallations({ status } = {}) {
    if (status) {
      return this.db
        .prepare('SELECT COUNT(*) AS n FROM installations WHERE status = ?')
        .get(status).n;
    }
    return this.db.prepare('SELECT COUNT(*) AS n FROM installations').get().n;
  }

  // --- Jobs ---

  async createJob(job) {
    this._insertJob(job);
    return job;
  }

  async createJobIfBudgetAvailable(job, config) {
    const day = today();
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const usage = this._usageRow(day);
      if (usage.jobs + 1 > config.dailyJobLimit) {
        this.db.exec('ROLLBACK');
        return { ok: false, reason: 'daily_job_limit' };
      }
      if (usage.budget_cents + config.estimatedJobCostCents > config.dailyBudgetCents) {
        this.db.exec('ROLLBACK');
        return { ok: false, reason: 'daily_budget_limit' };
      }
      this._insertJob(job);
      this.db
        .prepare(
          `INSERT INTO usage_daily (day, jobs, budget_cents) VALUES (?, 1, ?)
             ON CONFLICT(day) DO UPDATE SET jobs = jobs + 1, budget_cents = budget_cents + ?`,
        )
        .run(day, config.estimatedJobCostCents, config.estimatedJobCostCents);
      this.db.exec('COMMIT');
      return { ok: true, job };
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }

  _insertJob(job) {
    this.db
      .prepare(
        `INSERT INTO jobs
           (job_id, installation_id, post_id, status, request_json, result_json,
            reason, fallback_required, created_at, updated_at, started_at, completed_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        job.job_id,
        job.installation_id,
        job.post_id ?? null,
        job.status,
        JSON.stringify(job.request ?? {}),
        job.result ? JSON.stringify(job.result) : null,
        job.reason ?? null,
        job.fallback_required ? 1 : 0,
        job.created_at ?? nowIso(),
        job.updated_at ?? nowIso(),
        job.started_at ?? null,
        job.completed_at ?? null,
      );
  }

  async getJob(jobId) {
    const row = this.db.prepare('SELECT * FROM jobs WHERE job_id = ?').get(jobId);
    return row ? toJob(row) : null;
  }

  async updateJob(jobId, updates) {
    const current = await this.getJob(jobId);
    if (!current) return null;
    const next = { ...current, ...updates, updated_at: nowIso() };
    this.db
      .prepare(
        `UPDATE jobs
           SET status = ?, result_json = ?, reason = ?, fallback_required = ?,
               updated_at = ?, started_at = ?, completed_at = ?
         WHERE job_id = ?`,
      )
      .run(
        next.status,
        next.result ? JSON.stringify(next.result) : null,
        next.reason ?? null,
        next.fallback_required ? 1 : 0,
        next.updated_at,
        next.started_at ?? null,
        next.completed_at ?? null,
        jobId,
      );
    return next;
  }

  async markStaleJobsFailed() {
    this.db
      .prepare(
        `UPDATE jobs
           SET status = 'failed', reason = 'server_restarted',
               fallback_required = 1, updated_at = ?
         WHERE status IN ('queued', 'processing')`,
      )
      .run(nowIso());
  }

  async listJobs({ installationId, status, limit = 50, offset = 0 } = {}) {
    const clauses = [];
    const args = [];
    if (installationId) {
      clauses.push('installation_id = ?');
      args.push(installationId);
    }
    if (status) {
      clauses.push('status = ?');
      args.push(status);
    }
    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
    args.push(limit, offset);
    const rows = this.db
      .prepare(
        `SELECT job_id, installation_id, post_id, status, reason, fallback_required,
                created_at, updated_at, completed_at
           FROM jobs ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      )
      .all(...args);
    return rows.map((row) => ({
      ...row,
      fallback_required: Boolean(row.fallback_required),
    }));
  }

  // --- Usage / stats ---

  _usageRow(day) {
    return (
      this.db.prepare('SELECT jobs, budget_cents FROM usage_daily WHERE day = ?').get(day) ?? {
        jobs: 0,
        budget_cents: 0,
      }
    );
  }

  async getUsage(day = today()) {
    const usage = this._usageRow(day);
    return { day, jobs: usage.jobs, budget_cents: usage.budget_cents };
  }

  async getStats() {
    const installations = await this.countInstallations();
    const byStatus = this.db
      .prepare('SELECT status, COUNT(*) AS n FROM installations GROUP BY status')
      .all();
    const jobs = this.db.prepare('SELECT COUNT(*) AS n FROM jobs').get().n;
    return {
      installations,
      installations_by_status: Object.fromEntries(byStatus.map((r) => [r.status, r.n])),
      jobs_total: jobs,
      usage_today: await this.getUsage(),
    };
  }

  // --- Admin operators ---

  async createAdmin({ username, passwordHash, role }) {
    const now = nowIso();
    const info = this.db
      .prepare(
        `INSERT INTO admins (username, password_hash, role, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(username, passwordHash, role, now, now);
    return this.getAdminById(Number(info.lastInsertRowid));
  }

  async getAdminByUsername(username) {
    return this.db.prepare('SELECT * FROM admins WHERE username = ?').get(username) ?? null;
  }

  async getAdminById(id) {
    return this.db.prepare('SELECT * FROM admins WHERE id = ?').get(id) ?? null;
  }

  async listAdmins() {
    return this.db
      .prepare('SELECT id, username, role, disabled, created_at, updated_at FROM admins ORDER BY id')
      .all();
  }

  async countAdmins() {
    return this.db.prepare('SELECT COUNT(*) AS n FROM admins').get().n;
  }

  async setAdminDisabled(id, disabled) {
    this.db
      .prepare('UPDATE admins SET disabled = ?, updated_at = ? WHERE id = ?')
      .run(disabled ? 1 : 0, nowIso(), id);
    return this.getAdminById(id);
  }

  async updateAdminPassword(id, passwordHash) {
    this.db
      .prepare('UPDATE admins SET password_hash = ?, updated_at = ? WHERE id = ?')
      .run(passwordHash, nowIso(), id);
  }

  // --- Admin sessions ---

  async createSession({ adminId, tokenHash, expiresAt }) {
    const now = nowIso();
    this.db
      .prepare(
        `INSERT INTO admin_sessions (admin_id, token_hash, created_at, expires_at, last_used_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(adminId, tokenHash, now, expiresAt, now);
  }

  async getSessionByTokenHash(tokenHash) {
    return (
      this.db.prepare('SELECT * FROM admin_sessions WHERE token_hash = ?').get(tokenHash) ?? null
    );
  }

  async touchSession(tokenHash) {
    this.db
      .prepare('UPDATE admin_sessions SET last_used_at = ? WHERE token_hash = ?')
      .run(nowIso(), tokenHash);
  }

  async deleteSession(tokenHash) {
    this.db.prepare('DELETE FROM admin_sessions WHERE token_hash = ?').run(tokenHash);
  }

  async deleteSessionsForAdmin(adminId) {
    this.db.prepare('DELETE FROM admin_sessions WHERE admin_id = ?').run(adminId);
  }

  async deleteExpiredSessions() {
    this.db.prepare('DELETE FROM admin_sessions WHERE expires_at < ?').run(nowIso());
  }
}

function toJob(row) {
  return {
    job_id: row.job_id,
    installation_id: row.installation_id,
    post_id: row.post_id,
    status: row.status,
    request: row.request_json ? JSON.parse(row.request_json) : {},
    result: row.result_json ? JSON.parse(row.result_json) : null,
    reason: row.reason,
    fallback_required: Boolean(row.fallback_required),
    created_at: row.created_at,
    updated_at: row.updated_at,
    started_at: row.started_at,
    completed_at: row.completed_at,
  };
}

export function makeInstallation({
  installationId,
  platform,
  appVersion = '',
  deviceModel = '',
}) {
  const now = nowIso();
  return {
    installation_id: installationId,
    platform,
    app_version: appVersion,
    device_model: deviceModel,
    status: 'allowed',
    status_reason: 'auto_registered',
    created_at: now,
    updated_at: now,
  };
}
