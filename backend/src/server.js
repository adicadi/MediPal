import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import { createRemoteJWKSet, jwtVerify } from 'jose';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const dbPath = path.join(__dirname, '..', 'data', 'db.json');

const PORT = Number(process.env.PORT || 8080);
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';
const SUPABASE_URL = String(process.env.SUPABASE_URL || '').trim().replace(/\/$/, '');
const SUPABASE_JWKS_URL = process.env.SUPABASE_JWKS_URL || `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`;

if (!SUPABASE_URL) {
  throw new Error('SUPABASE_URL is required in backend .env');
}

const jwks = createRemoteJWKSet(new URL(SUPABASE_JWKS_URL), {
  timeoutDuration: 4000,
});

const app = express();
app.use(cors({ origin: CORS_ORIGIN }));
app.use(express.json({ limit: '1mb' }));
app.use((req, _res, next) => {
  // eslint-disable-next-line no-console
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

async function readDb() {
  const raw = await fs.readFile(dbPath, 'utf8');
  return JSON.parse(raw);
}

async function writeDb(db) {
  await fs.writeFile(dbPath, `${JSON.stringify(db, null, 2)}\n`, 'utf8');
}

function getBearerToken(req) {
  const authHeader = req.header('authorization') || '';
  const [scheme, token] = authHeader.split(' ');
  if (scheme?.toLowerCase() !== 'bearer' || !token) return null;
  return token;
}

function ensureUserRecords(db, authUser) {
  let user = db.users.find((item) => item.id === authUser.userId);
  if (!user) {
    user = {
      id: authUser.userId,
      email: authUser.email,
      createdAt: new Date().toISOString(),
    };
    db.users.push(user);
  } else if (authUser.email && user.email !== authUser.email) {
    user.email = authUser.email;
  }

  let profile = db.profiles.find((item) => item.userId === authUser.userId);
  if (!profile) {
    profile = {
      userId: authUser.userId,
      name: '',
      age: null,
      gender: '',
      updatedAt: new Date().toISOString(),
    };
    db.profiles.push(profile);
  }

  let quota = db.quotas.find((item) => item.userId === authUser.userId);
  if (!quota) {
    quota = {
      userId: authUser.userId,
      plan: 'free',
      tokensRemaining: 20000,
      periodType: 'daily',
      resetAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
    db.quotas.push(quota);
  }

  return { user, profile, quota };
}

async function requireAuth(req, res, next) {
  const token = getBearerToken(req);
  if (!token) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }

  try {
    const { payload } = await jwtVerify(token, jwks, {
      issuer: `${SUPABASE_URL}/auth/v1`,
      audience: 'authenticated',
    });

    if (!payload.sub) {
      return res.status(401).json({ error: 'Invalid token subject' });
    }

    req.auth = {
      userId: String(payload.sub),
      email: String(payload.email || ''),
    };
    next();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Auth verification failed:', error?.message || error);
    return res.status(401).json({ error: 'Invalid or expired Supabase token' });
  }
}

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'medipal-backend', now: new Date().toISOString() });
});

app.get('/me', requireAuth, async (req, res) => {
  const db = await readDb();
  const { user, profile, quota } = ensureUserRecords(db, req.auth);
  await writeDb(db);

  return res.json({
    user,
    profile,
    plan: quota?.plan || 'free',
    quota,
  });
});

app.patch('/me/profile', requireAuth, async (req, res) => {
  const db = await readDb();
  const { profile } = ensureUserRecords(db, req.auth);

  const name = req.body?.name;
  const age = req.body?.age;
  const gender = req.body?.gender;

  if (name != null) profile.name = String(name).trim();
  if (age != null) {
    const parsedAge = Number(age);
    profile.age = Number.isFinite(parsedAge) ? parsedAge : null;
  }
  if (gender != null) profile.gender = String(gender).trim();
  profile.updatedAt = new Date().toISOString();

  await writeDb(db);
  return res.json({ profile });
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`MediPal backend listening on :${PORT}`);
  // eslint-disable-next-line no-console
  console.log(`Using JWKS: ${SUPABASE_JWKS_URL}`);
});
