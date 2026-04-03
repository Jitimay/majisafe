import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import * as auth from '../controllers/authController.js';
import { authMiddleware } from '../middleware/auth.js';
import { apiError } from '../utils/errors.js';

const router = Router();

/**
 * Express-validator result handler middleware.
 */
function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json(apiError('VALIDATION_ERROR', errors.array()[0].msg));
  }
  return next();
}

router.post(
  '/register',
  [
    body('phone').trim().isLength({ min: 8, max: 20 }).withMessage('Invalid phone'),
    body('name').optional().trim().isLength({ max: 120 }),
    body('password').isLength({ min: 6, max: 128 }).withMessage('Password too short'),
    body('avatar_base64').optional().isString().isLength({ max: 700000 }).withMessage('Avatar too large'),
    body('avatar_mime').optional().trim().isLength({ max: 40 }),
  ],
  validate,
  auth.register
);

router.post(
  '/login',
  [
    body('phone').trim().notEmpty().withMessage('Phone required'),
    body('password').notEmpty().withMessage('Password required'),
  ],
  validate,
  auth.login
);

router.post(
  '/refresh',
  [body('refresh_token').notEmpty().withMessage('refresh_token required')],
  validate,
  auth.refresh
);

router.get('/me', authMiddleware, auth.me);

router.get('/avatar', authMiddleware, auth.serveAvatar);

export default router;
