/**
 * Builds a standard API error payload for clients.
 * @param {string} code Machine-readable error code (e.g. INSUFFICIENT_COINS).
 * @param {string} message Human-readable explanation.
 * @returns {{ success: false, error: string, message: string }}
 */
export function apiError(code, message) {
  return { success: false, error: code, message };
}

import { log } from './logger.js';

/**
 * Express error handler middleware: maps thrown errors to HTTP responses.
 */
export function errorHandler(err, req, res, next) {
  if (res.headersSent) {
    return next(err);
  }
  const status = err.statusCode || err.status || 500;
  const code = err.code || 'INTERNAL_ERROR';
  const message = err.message || 'An unexpected error occurred';
  if (status >= 500) {
    log('error', 'request failed', { path: req.path, err: String(err) });
  }
  res.status(status).json(apiError(code, message));
}
