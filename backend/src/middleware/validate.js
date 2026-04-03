import { validationResult } from 'express-validator';
import { apiError } from '../utils/errors.js';

/**
 * Sends 400 if express-validator found errors on the request.
 */
export function validateRequest(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const first = errors.array()[0];
    return res.status(400).json(apiError('VALIDATION_ERROR', first.msg || 'Invalid input'));
  }
  return next();
}
