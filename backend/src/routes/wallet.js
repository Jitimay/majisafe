import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import * as wallet from '../controllers/walletController.js';
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

router.use(authMiddleware);

router.get('/balance', wallet.getBalanceAndRecent);

router.post(
  '/topup',
  [
    body('amount_bif').isFloat({ min: 1 }).withMessage('Invalid amount_bif'),
    body('method').optional().trim().isIn(['sms', 'app', 'bank', 'lumicash', 'ecocash']).withMessage('Invalid method'),
  ],
  validate,
  wallet.topup
);

router.get('/history', wallet.history);

export default router;
