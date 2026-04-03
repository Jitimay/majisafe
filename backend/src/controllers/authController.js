import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { getDb } from '../models/db.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';

const BCRYPT_ROUNDS = 12;

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
 * Registers a new user with hashed password.
 */
export function register(req, res) {
  const { phone, name, password } = req.body;
  const db = getDb();
  try {
    const exists = db.prepare(`SELECT id FROM users WHERE phone = ?`).get(phone);
    if (exists) {
      return res.status(409).json(apiError('PHONE_TAKEN', 'This phone is already registered'));
    }
    const password_hash = bcrypt.hashSync(password, BCRYPT_ROUNDS);
    const info = db
      .prepare(`INSERT INTO users (phone, name, password_hash) VALUES (?, ?, ?)`)
      .run(phone, name || null, password_hash);
    const user = db
      .prepare(`SELECT id, phone, name, role, coin_balance, created_at FROM users WHERE id = ?`)
      .get(info.lastInsertRowid);
    const tokens = signTokens(user.id);
    return res.status(201).json({
      success: true,
      token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      user,
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
    const user = {
      id: row.id,
      phone: row.phone,
      name: row.name,
      role: row.role,
      coin_balance: row.coin_balance,
      created_at: row.created_at,
    };
    const tokens = signTokens(user.id);
    return res.json({
      success: true,
      token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      user,
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
  const u = req.user;
  return res.json({
    success: true,
    user: {
      id: u.id,
      phone: u.phone,
      name: u.name,
      role: u.role,
      coin_balance: u.coin_balance,
      created_at: u.created_at,
    },
  });
}
