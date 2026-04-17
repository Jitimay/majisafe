import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { body, validationResult } from 'express-validator';
import { simulateTopup, simulateHistory, simulateAdminAll } from '../controllers/simulateController.js';
import { authMiddleware } from '../middleware/auth.js';
import { adminOnly } from '../middleware/adminOnly.js';
import { apiError } from '../utils/errors.js';

const router = Router();

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json(apiError('VALIDATION_ERROR', errors.array()[0].msg));
  }
  return next();
}

// Allow max 10 simulated top-ups per minute per user
const simLimiter = rateLimit({
  windowMs: 60_000,
  max: 10,
  keyGenerator: (req) => String(req.user?.id ?? req.ip),
});

router.use(authMiddleware);

// POST /api/simulate/topup — instantly credit coins (sandbox payment)
router.post(
  '/topup',
  simLimiter,
  [
    body('amount_bif')
      .isFloat({ min: 10, max: 100_000 })
      .withMessage('amount_bif must be between 10 and 100,000 BIF'),
    body('method')
      .optional()
      .trim()
      .isIn(['simulate', 'lumicash', 'ecocash', 'bank', 'cash'])
      .withMessage('Invalid method'),
    body('note').optional().trim().isLength({ max: 200 }),
  ],
  validate,
  simulateTopup
);

// GET /api/simulate/history — current user's simulated payments
router.get('/history', simulateHistory);

// GET /api/simulate/admin/all — admin only
router.get('/admin/all', adminOnly, simulateAdminAll);

export default router;
