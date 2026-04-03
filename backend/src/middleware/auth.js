import jwt from 'jsonwebtoken';
import { getDb } from '../models/db.js';
import { apiError } from '../utils/errors.js';

/**
 * Verifies Bearer JWT and attaches the user row to req.user.
 */
export function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json(apiError('UNAUTHORIZED', 'Missing or invalid authorization header'));
  }
  const token = header.slice(7);
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    return res.status(500).json(apiError('SERVER_MISCONFIGURED', 'JWT_SECRET is not set'));
  }
  try {
    const payload = jwt.verify(token, secret);
    if (payload.type !== 'access') {
      return res.status(401).json(apiError('UNAUTHORIZED', 'Invalid token type'));
    }
    const db = getDb();
    const user = db.prepare(`SELECT id, phone, name, role, coin_balance, created_at FROM users WHERE id = ?`).get(payload.sub);
    if (!user) {
      return res.status(401).json(apiError('UNAUTHORIZED', 'User no longer exists'));
    }
    req.user = user;
    return next();
  } catch {
    return res.status(401).json(apiError('UNAUTHORIZED', 'Invalid or expired token'));
  }
}

/**
 * Optional auth: sets req.user if valid Bearer token present; otherwise continues.
 */
export function optionalAuthMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return next();
  }
  return authMiddleware(req, res, next);
}
