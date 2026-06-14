function nowMs() {
  return Date.now();
}

export class SlidingWindowRateLimiter {
  constructor() {
    this.buckets = new Map();
  }

  check({ key, limit, windowMs = 60_000 }) {
    const current = nowMs();
    const bucket = this.buckets.get(key)?.filter((entry) => current - entry < windowMs) ?? [];
    if (bucket.length >= limit) {
      this.buckets.set(key, bucket);
      return { ok: false, retryAfterSeconds: Math.ceil((windowMs - (current - bucket[0])) / 1000) };
    }
    bucket.push(current);
    this.buckets.set(key, bucket);
    return { ok: true };
  }
}
