import { randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

// scrypt parameters. N=2^15 is a reasonable interactive-login cost.
const N = 32768;
const R = 8;
const P = 1;
const KEYLEN = 32;
const SALT_BYTES = 16;
// 128 * N * r bytes of memory are needed; give scrypt enough headroom.
const MAXMEM = 128 * N * R * 2;

/**
 * Hashes a password with scrypt and a random salt. Returns a self-describing
 * string `scrypt$N$r$p$saltB64$hashB64` so parameters can evolve over time.
 */
export function hashPassword(password) {
  const salt = randomBytes(SALT_BYTES);
  const hash = scryptSync(password, salt, KEYLEN, { N, r: R, p: P, maxmem: MAXMEM });
  return `scrypt$${N}$${R}$${P}$${salt.toString('base64')}$${hash.toString('base64')}`;
}

/**
 * Verifies a password against a stored hash in constant time. Returns false on
 * any malformed input rather than throwing.
 */
export function verifyPassword(password, stored) {
  try {
    if (typeof stored !== 'string') return false;
    const parts = stored.split('$');
    if (parts.length !== 6 || parts[0] !== 'scrypt') return false;
    const n = Number(parts[1]);
    const r = Number(parts[2]);
    const p = Number(parts[3]);
    const salt = Buffer.from(parts[4], 'base64');
    const expected = Buffer.from(parts[5], 'base64');
    const actual = scryptSync(password, salt, expected.length, {
      N: n,
      r,
      p,
      maxmem: 128 * n * r * 2,
    });
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  } catch {
    return false;
  }
}
