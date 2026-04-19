import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import * as admin from '../controllers/adminController.js';
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

router.use(authMiddleware, adminOnly);

router.get('/users', admin.listUsers);

router.post(
  '/topup',
  [
    body('user_id').isInt({ min: 1 }).withMessage('user_id required'),
    body('coins').isFloat({ min: 0.01 }).withMessage('coins required'),
    body('note').optional().trim().isLength({ max: 500 }),
  ],
  validate,
  admin.adminTopup
);

router.get('/audit', admin.auditLedger);

router.get('/stations', admin.adminStations);

router.patch(
  '/stations/:id',
  [
    body('status').optional().isIn(['online', 'offline', 'dispensing', 'error']).withMessage('Invalid status'),
    body('tank_level').optional().isFloat({ min: 0, max: 100 }).withMessage('tank_level must be 0–100'),
  ],
  validate,
  admin.adminUpdateStation
);

export default router;
