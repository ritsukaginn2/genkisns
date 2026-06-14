import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

function nowIso() {
  return new Date().toISOString();
}

function emptyData() {
  return {
    schema_version: 1,
    installations: {},
    jobs: {},
    usage: {
      day: new Date().toISOString().slice(0, 10),
      jobs: 0,
      budget_cents: 0,
    },
  };
}

export class JsonFileStore {
  constructor(filePath) {
    this.filePath = filePath;
    this.data = emptyData();
    this.loaded = false;
    this._writeQueue = Promise.resolve();
  }

  async load() {
    if (this.loaded) return;
    try {
      const raw = await readFile(this.filePath, 'utf8');
      this.data = {
        ...emptyData(),
        ...JSON.parse(raw),
      };
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      await this.flush();
    }
    this.loaded = true;
    this._resetUsageIfNeeded();
  }

  async flush() {
    const body = `${JSON.stringify(this.data, null, 2)}\n`;
    this._writeQueue = this._writeQueue.then(() => this._writeBody(body));
    await this._writeQueue;
  }

  async _writeBody(body) {
    await mkdir(dirname(this.filePath), { recursive: true });
    const tmpFile = `${this.filePath}.tmp`;
    await writeFile(tmpFile, body, 'utf8');
    await rename(tmpFile, this.filePath);
  }

  _resetUsageIfNeeded() {
    const today = new Date().toISOString().slice(0, 10);
    if (this.data.usage?.day === today) return;
    this.data.usage = { day: today, jobs: 0, budget_cents: 0 };
  }

  async getInstallation(installationId) {
    await this.load();
    return this.data.installations[installationId] ?? null;
  }

  async upsertInstallation(installation) {
    await this.load();
    const previous = this.data.installations[installation.installation_id];
    const next = {
      ...previous,
      ...installation,
      status: previous?.status ?? installation.status,
      status_reason: previous?.status_reason ?? installation.status_reason,
      updated_at: nowIso(),
      created_at: previous?.created_at ?? installation.created_at ?? nowIso(),
      audit_log: previous?.audit_log ?? installation.audit_log ?? [],
    };
    this.data.installations[next.installation_id] = next;
    await this.flush();
    return next;
  }

  async setInstallationStatus({ installationId, status, reason, source }) {
    await this.load();
    const current =
      this.data.installations[installationId] ??
      makeInstallation({ installationId, platform: 'unknown' });
    const auditEntry = {
      status,
      reason: reason || 'manual update',
      source: source || 'internal',
      changed_at: nowIso(),
    };
    const next = {
      ...current,
      status,
      status_reason: auditEntry.reason,
      updated_at: auditEntry.changed_at,
      audit_log: [...(current.audit_log ?? []), auditEntry],
    };
    this.data.installations[installationId] = next;
    await this.flush();
    return next;
  }

  async createJob(job) {
    await this.load();
    this.data.jobs[job.job_id] = job;
    await this.flush();
    return job;
  }

  async createJobIfBudgetAvailable(job, config) {
    await this.load();
    let result;
    this._writeQueue = this._writeQueue.then(async () => {
      this._resetUsageIfNeeded();
      const usage = this.data.usage;
      if (usage.jobs + 1 > config.dailyJobLimit) {
        result = { ok: false, reason: 'daily_job_limit' };
        return;
      }
      if (usage.budget_cents + config.estimatedJobCostCents > config.dailyBudgetCents) {
        result = { ok: false, reason: 'daily_budget_limit' };
        return;
      }

      this.data.jobs[job.job_id] = job;
      usage.jobs += 1;
      usage.budget_cents += config.estimatedJobCostCents;
      const body = `${JSON.stringify(this.data, null, 2)}\n`;
      await this._writeBody(body);
      result = { ok: true, job };
    });
    await this._writeQueue;
    return result;
  }

  async getJob(jobId) {
    await this.load();
    return this.data.jobs[jobId] ?? null;
  }

  async updateJob(jobId, updates) {
    await this.load();
    const current = this.data.jobs[jobId];
    if (!current) return null;
    const next = { ...current, ...updates, updated_at: nowIso() };
    this.data.jobs[jobId] = next;
    await this.flush();
    return next;
  }

  async markStaleJobsFailed() {
    await this.load();
    let touched = false;
    for (const job of Object.values(this.data.jobs)) {
      if (job.status === 'queued' || job.status === 'processing') {
        job.status = 'failed';
        job.reason = 'server_restarted';
        job.fallback_required = true;
        job.updated_at = nowIso();
        touched = true;
      }
    }
    if (touched) await this.flush();
  }
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
    audit_log: [
      {
        status: 'allowed',
        reason: 'auto_registered',
        source: 'system',
        changed_at: now,
      },
    ],
  };
}
