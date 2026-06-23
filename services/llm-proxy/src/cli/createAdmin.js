// Operator CLI: create or update an admin account directly against the database.
// Usage: node src/cli/createAdmin.js <username> <password> [role]
import { isValidRole } from '../auth/adminAuth.js';
import { hashPassword } from '../auth/passwords.js';
import { loadConfig } from '../config.js';
import { SqliteStore } from '../store.js';

try {
  process.loadEnvFile();
} catch {
  // no .env
}

const [, , username, password, role = 'admin'] = process.argv;

if (!username || !password) {
  console.error('usage: node src/cli/createAdmin.js <username> <password> [role]');
  console.error('role: viewer | admin | owner (default: admin)');
  process.exit(1);
}
if (password.length < 8) {
  console.error('error: password must be at least 8 characters');
  process.exit(1);
}
if (!isValidRole(role)) {
  console.error(`error: invalid role '${role}' (use viewer | admin | owner)`);
  process.exit(1);
}

const config = loadConfig();
const store = new SqliteStore(config.dataFile);
try {
  const existing = await store.getAdminByUsername(username);
  if (existing) {
    await store.updateAdminPassword(existing.id, hashPassword(password));
    console.log(`updated password for admin '${username}'`);
  } else {
    await store.createAdmin({ username, passwordHash: hashPassword(password), role });
    console.log(`created admin '${username}' (${role})`);
  }
} finally {
  store.close();
}
