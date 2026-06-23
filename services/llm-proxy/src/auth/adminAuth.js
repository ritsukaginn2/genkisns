import { hashPassword, verifyPassword } from './passwords.js';
import { generateToken, hashToken } from './tokens.js';

const ROLE_RANK = { viewer: 1, admin: 2, owner: 3 };
export const ADMIN_ROLES = Object.keys(ROLE_RANK);

// A real (but throwaway) hash so login does the same scrypt work whether or not
// the username exists, avoiding a user-enumeration timing side channel.
const DUMMY_HASH = hashPassword(generateToken());

export function roleAtLeast(role, minRole) {
  return (ROLE_RANK[role] ?? 0) >= (ROLE_RANK[minRole] ?? Infinity);
}

export function isValidRole(role) {
  return Object.prototype.hasOwnProperty.call(ROLE_RANK, role);
}

/**
 * Validates credentials and, on success, creates a session. Returns
 * { token, expiresAt, admin } or null. The raw token is returned once.
 */
export async function loginAdmin({ store, config, username, password }) {
  const admin = username ? await store.getAdminByUsername(username) : null;
  // Always run a verification to keep timing uniform.
  const ok = verifyPassword(password ?? '', admin?.password_hash ?? DUMMY_HASH);
  if (!admin || admin.disabled || !ok) return null;

  const token = generateToken();
  const expiresAt = new Date(
    Date.now() + config.sessionTtlHours * 3600 * 1000,
  ).toISOString();
  await store.createSession({
    adminId: admin.id,
    tokenHash: hashToken(token),
    expiresAt,
  });
  return { token, expiresAt, admin };
}

/**
 * Resolves a bearer token to an active admin, or null. Expired sessions are
 * deleted lazily. Returns { admin, tokenHash } on success.
 */
export async function authenticateAdmin({ store, token }) {
  if (!token) return null;
  const tokenHash = hashToken(token);
  const session = await store.getSessionByTokenHash(tokenHash);
  if (!session) return null;
  if (new Date(session.expires_at).getTime() < Date.now()) {
    await store.deleteSession(tokenHash);
    return null;
  }
  const admin = await store.getAdminById(session.admin_id);
  if (!admin || admin.disabled) return null;
  await store.touchSession(tokenHash);
  return { admin, tokenHash };
}

export function publicAdmin(admin) {
  return {
    id: admin.id,
    username: admin.username,
    role: admin.role,
    disabled: Boolean(admin.disabled),
    created_at: admin.created_at,
    updated_at: admin.updated_at,
  };
}
