import { apiError } from '../utils/errors.js';

/**
 * Ensures req.user.role === 'admin' (run after authMiddleware).
 */
export function adminOnly(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json(apiError('FORBIDDEN', 'Admin access required'));
  }
  return next();
}
