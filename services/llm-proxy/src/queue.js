import { setTimeout as delay } from 'node:timers/promises';

import { validateJobResult } from './resultValidation.js';

// Assign a staggered delivery delay to each comment so the client reveals them
// gradually (real-person pacing) instead of all at once. delay[i] grows linearly
// and is capped, all driven by config so the pacing is tunable.
export function assignDeliveryDelays(comments, config) {
  const first = config.commentFirstDelaySeconds ?? 4;
  const gap = config.commentDelayGapSeconds ?? 18;
  const max = config.commentMaxDelaySeconds ?? 600;
  comments.forEach((comment, index) => {
    comment.delay_seconds = Math.min(max, first + index * gap);
  });
  return comments;
}

export class JobQueue {
  constructor({ store, provider, config }) {
    this.store = store;
    this.provider = provider;
    this.config = config;
    this.queue = [];
    this.active = 0;
    this.idleResolvers = [];
  }

  enqueue(job) {
    this.queue.push(job.job_id);
    this._drain();
  }

  onIdle() {
    if (this.active === 0 && this.queue.length === 0) {
      return Promise.resolve();
    }
    return new Promise((resolve) => {
      this.idleResolvers.push(resolve);
    });
  }

  _drain() {
    while (this.active < this.config.workerConcurrency && this.queue.length > 0) {
      const jobId = this.queue.shift();
      this.active += 1;
      this._process(jobId)
        .catch((error) => {
          // _process handles its own provider/validation errors and records them
          // on the job. Reaching here means an unexpected failure (e.g. store I/O);
          // log it so it is not silently lost.
          // eslint-disable-next-line no-console
          console.error(`[queue] unexpected error processing ${jobId}:`, error);
        })
        .finally(() => {
          this.active -= 1;
          this._drain();
          this._resolveIdleIfNeeded();
        });
    }
  }

  _resolveIdleIfNeeded() {
    if (this.active !== 0 || this.queue.length !== 0) return;
    const resolvers = this.idleResolvers.splice(0);
    for (const resolve of resolvers) resolve();
  }

  async _process(jobId) {
    const job = await this.store.getJob(jobId);
    if (!job || job.status !== 'queued') return;
    await this.store.updateJob(jobId, { status: 'processing', started_at: new Date().toISOString() });
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.config.jobTimeoutMs);
    try {
      // Let the HTTP response for job creation leave the process before a fast
      // provider updates the job to completed.
      await delay(0);
      const rawResult = await this.provider.generate({
        request: job.request,
        signal: controller.signal,
      });
      const result = validateJobResult(rawResult, {
        friendIds: job.request.friend_ids,
        maxComments: this.config.maxComments,
        maxCommentLength: this.config.maxCommentLength,
      });
      assignDeliveryDelays(result.comments, this.config);
      await this.store.updateJob(jobId, {
        status: 'completed',
        result,
        completed_at: new Date().toISOString(),
      });
    } catch (error) {
      await this.store.updateJob(jobId, {
        status: 'failed',
        reason: error.name === 'AbortError' ? 'job_timeout' : error.message,
        fallback_required: true,
        completed_at: new Date().toISOString(),
      });
    } finally {
      clearTimeout(timeout);
    }
  }
}
