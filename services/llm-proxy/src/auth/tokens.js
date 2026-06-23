import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * Generates a high-entropy opaque token (URL-safe). The raw token is shown to
 * the client once; only its hash is stored server-side.
 */
export function generateToken(bytes = 32) {
  return randomBytes(bytes).toString('base64url');
}

/** SHA-256 hex digest of a token, used as the stored/lookup key. */
export function hashToken(token) {
  return createHash('sha256').update(String(token)).digest('hex');
}

/** Constant-time comparison of two hex digests of equal length. */
export function safeEqualHex(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) {
    return false;
  }
  return timingSafeEqual(Buffer.from(a, 'hex'), Buffer.from(b, 'hex'));
}
