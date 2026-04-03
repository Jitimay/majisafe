import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { getDb } from '../models/db.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';

const BCRYPT_ROUNDS = 12;
const AVATAR_MAX_BYTES = 400 * 1024;
const ALLOWED_AVATAR_MIME = new Set(['image/jpeg', 'image/png', 'image/webp']);

/**
 * Builds public user JSON (never includes password or blob).
 * @param {object} row
 */
function userPublicJson(row) {
  return {
    id: row.id,
    phone: row.phone,
    name: row.name,
    role: row.role,
    coin_balance: row.coin_balance,
    created_at: row.created_at,
    has_avatar: Boolean(Number(row.has_avatar ?? 0)),
  };
}

/**
 * Parses optional base64 avatar from register body.
 * @param {object} body
 * @returns {{ blob: Buffer|null, mime: string|null }}
 */
function parseOptionalAvatar(body) {
  let b64 = body.avatar_base64;
  if (b64 == null || b64 === '') {
    return { blob: null, mime: null };
  }
  if (typeof b64 !== 'string') {
    const err = new Error('avatar_base64 must be a string');
    err.statusCode = 400;
    err.code = 'VALIDATION_ERROR';
    throw err;
  }
  let mime = typeof body.avatar_mime === 'string' ? body.avatar_mime.trim() : 'image/jpeg';
  const dataUrl = /^data:([^;]+);base64,(.+)$/s.exec(b64);
  if (dataUrl) {
    mime = dataUrl[1].trim();
    b64 = dataUrl[2].replace(/\s/g, '');
  } else {
    b64 = b64.replace(/\s/g, '');
  }
  if (!ALLOWED_AVATAR_MIME.has(mime)) {
    const err = new Error('Use image/jpeg, image/png, or image/webp');
    err.statusCode = 400;
    err.code = 'VALIDATION_ERROR';
    throw err;
  }
  let buf;
  try {
    buf = Buffer.from(b64, 'base64');
  } catch {
    const err = new Error('Invalid avatar_base64');
    err.statusCode = 400;
    err.code = 'VALIDATION_ERROR';
    throw err;
  }
  if (!buf.length || buf.length > AVATAR_MAX_BYTES) {
    const err = new Error(`Photo must be under ${AVATAR_MAX_BYTES / 1024} KB`);
    err.statusCode = 400;
    err.code = 'AVATAR_TOO_LARGE';
    throw err;
  }
  return { blob: buf, mime };
}

/**
 * Issues access and refresh JWTs for a user id.
 * @param {number} userId
 */
function signTokens(userId) {
  const accessSecret = process.env.JWT_SECRET;
  const refreshSecret = process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET;
  if (!accessSecret || !refreshSecret) {
    throw Object.assign(new Error('JWT not configured'), { statusCode: 500, code: 'SERVER_MISCONFIGURED' });
  }
  const accessToken = jwt.sign({ sub: userId, type: 'access' }, accessSecret, { expiresIn: '24h' });
  const refreshToken = jwt.sign({ sub: userId, type: 'refresh' }, refreshSecret, { expiresIn: '7d' });
  return { accessToken, refreshToken };
}

/**
 * Registers a new user with hashed password and optional profile photo.
 */
export function register(req, res) {
  const { phone, name, password } = req.body;
  const db = getDb();
  let avatarBlob = null;
  let avatarMime = null;
  try {
    const parsed = parseOptionalAvatar(req.body);
    avatarBlob = parsed.blob;
    avatarMime = parsed.mime;
  } catch (e) {
    if (e.statusCode) {
      return res.status(e.statusCode).json(apiError(e.code || 'VALIDATION_ERROR', e.message));
    }
    throw e;
  }
  try {
    const exists = db.prepare(`SELECT id FROM users WHERE phone = ?`).get(phone);
    if (exists) {
      return res.status(409).json(apiError('PHONE_TAKEN', 'This phone is already registered'));
    }
    const password_hash = bcrypt.hashSync(password, BCRYPT_ROUNDS);
    const info = db
      .prepare(
        `INSERT INTO users (phone, name, password_hash, avatar_blob, avatar_mime) VALUES (?, ?, ?, ?, ?)`
      )
      .run(phone, name || null, password_hash, avatarBlob, avatarMime);
    const user = db
      .prepare(
        `SELECT id, phone, name, role, coin_balance, created_at,
         CASE WHEN avatar_blob IS NOT NULL AND length(avatar_blob) > 0 THEN 1 ELSE 0 END AS has_avatar
         FROM users WHERE id = ?`
      )
      .get(info.lastInsertRowid);
    const tokens = signTokens(user.id);
    return res.status(201).json({
      success: true,
      token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      user: userPublicJson(user),
    });
  } catch (e) {
    log('error', 'register failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Registration failed'));
  }
}

/**
 * Authenticates user by phone and password, returns JWTs.
 */
export function login(req, res) {
  const { phone, password } = req.body;
  const db = getDb();
  try {
    const row = db.prepare(`SELECT * FROM users WHERE phone = ?`).get(phone);
    if (!row || !row.password_hash) {
      return res.status(401).json(apiError('INVALID_CREDENTIALS', 'Invalid phone or password'));
    }
    const ok = bcrypt.compareSync(password, row.password_hash);
    if (!ok) {
      return res.status(401).json(apiError('INVALID_CREDENTIALS', 'Invalid phone or password'));
    }
    const user = db
      .prepare(
        `SELECT id, phone, name, role, coin_balance, created_at,
         CASE WHEN avatar_blob IS NOT NULL AND length(avatar_blob) > 0 THEN 1 ELSE 0 END AS has_avatar
         FROM users WHERE id = ?`
      )
      .get(row.id);
    const tokens = signTokens(user.id);
    return res.json({
      success: true,
      token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      user: userPublicJson(user),
    });
  } catch (e) {
    log('error', 'login failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Login failed'));
  }
}

/**
 * Exchanges a valid refresh token for new access and refresh tokens.
 */
export function refresh(req, res) {
  const refreshToken = req.body.refresh_token;
  const refreshSecret = process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET;
  if (!refreshSecret) {
    return res.status(500).json(apiError('SERVER_MISCONFIGURED', 'JWT not configured'));
  }
  try {
    const payload = jwt.verify(refreshToken, refreshSecret);
    if (payload.type !== 'refresh') {
      return res.status(401).json(apiError('UNAUTHORIZED', 'Invalid refresh token'));
    }
    const db = getDb();
    const user = db.prepare(`SELECT id FROM users WHERE id = ?`).get(payload.sub);
    if (!user) {
      return res.status(401).json(apiError('UNAUTHORIZED', 'User no longer exists'));
    }
    const tokens = signTokens(user.id);
    return res.json({
      success: true,
      token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
    });
  } catch {
    return res.status(401).json(apiError('UNAUTHORIZED', 'Invalid or expired refresh token'));
  }
}

/**
 * Returns the authenticated user's profile.
 */
export function me(req, res) {
  return res.json({
    success: true,
    user: userPublicJson(req.user),
  });
}

/**
 * Streams the authenticated user's profile image (Bearer required).
 */
export function serveAvatar(req, res) {
  const db = getDb();
  try {
    const row = db.prepare(`SELECT avatar_blob, avatar_mime FROM users WHERE id = ?`).get(req.user.id);
    if (!row?.avatar_blob || row.avatar_blob.length === 0) {
      return res.status(404).json(apiError('NOT_FOUND', 'No profile photo'));
    }
    const mime = row.avatar_mime && ALLOWED_AVATAR_MIME.has(row.avatar_mime) ? row.avatar_mime : 'image/jpeg';
    res.setHeader('Content-Type', mime);
    res.setHeader('Cache-Control', 'private, max-age=300');
    return res.send(Buffer.from(row.avatar_blob));
  } catch (e) {
    log('error', 'serveAvatar failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not load photo'));
  }
}
