function nowMs() {
  return Date.now();
}

export class SlidingWindowRateLimiter {
  constructor() {
    this.buckets = new Map();
    this._ops = 0;
  }

  check({ key, limit, windowMs = 60_000 }) {
    const current = nowMs();
    this._maybeSweep(current, windowMs);
    const bucket = this.buckets.get(key)?.filter((entry) => current - entry < windowMs) ?? [];
    if (bucket.length >= limit) {
      this.buckets.set(key, bucket);
      return { ok: false, retryAfterSeconds: Math.ceil((windowMs - (current - bucket[0])) / 1000) };
    }
    bucket.push(current);
    this.buckets.set(key, bucket);
    return { ok: true };
  }

  // Periodically drop fully-stale buckets so the map can't grow without bound
  // (distinct installation/IP keys accumulate otherwise).
  _maybeSweep(current, windowMs) {
    if ((this._ops = (this._ops + 1) % 1000) !== 0) return;
    for (const [key, entries] of this.buckets) {
      const fresh = entries.filter((entry) => current - entry < windowMs);
      if (fresh.length === 0) this.buckets.delete(key);
      else this.buckets.set(key, fresh);
    }
  }
}
