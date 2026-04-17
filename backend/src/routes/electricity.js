import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { body, validationResult } from 'express-validator';
import { buyElectricity, electricityHistory } from '../controllers/electricityController.js';
import { authMiddleware } from '../middleware/auth.js';
import { apiError } from '../utils/errors.js';

const router = Router();

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json(apiError('VALIDATION_ERROR', errors.array()[0].msg));
  }
  return next();
}

const buyLimiter = rateLimit({
  windowMs: 10_000,
  max: 1,
  keyGenerator: (req) => String(req.user?.id ?? req.ip),
});

router.use(authMiddleware);

router.post(
  '/buy',
  buyLimiter,
  [
    body('meter_number')
      .trim()
      .notEmpty()
      .withMessage('meter_number required')
      .isLength({ min: 6, max: 20 })
      .withMessage('meter_number must be 6–20 characters'),
    body('coins')
      .isFloat({ min: 1, max: 500 })
      .withMessage('coins must be between 1 and 500'),
  ],
  validate,
  buyElectricity
);

router.get('/history', electricityHistory);

export default router;
