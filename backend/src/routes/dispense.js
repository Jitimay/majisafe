import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { body, param, validationResult } from 'express-validator';
import * as dispense from '../controllers/dispenseController.js';
import { authMiddleware } from '../middleware/auth.js';
import { stationAuthMiddleware } from '../middleware/stationAuth.js';
import { apiError } from '../utils/errors.js';

const router = Router();

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json(apiError('VALIDATION_ERROR', errors.array()[0].msg));
  }
  return next();
}

const dispenseRequestLimiter = rateLimit({
  windowMs: 10_000,
  max: 1,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => String(req.user?.id ?? req.ip),
});

router.post(
  '/request',
  authMiddleware,
  dispenseRequestLimiter,
  [
    body('station_id').trim().notEmpty().withMessage('station_id required'),
    body('litres').isFloat({ min: 0.1, max: 50 }).withMessage('litres must be between 0.1 and 50'),
  ],
  validate,
  (req, res, next) => {
    dispense.requestDispense(req, res).catch(next);
  }
);

router.get(
  '/status/:txId',
  authMiddleware,
  [param('txId').trim().notEmpty().withMessage('txId required')],
  validate,
  dispense.dispenseStatus
);

const deviceRouter = Router();
deviceRouter.use(stationAuthMiddleware);

deviceRouter.get('/pending', dispense.getPendingDeviceCommand);

deviceRouter.post(
  '/progress',
  [
    body('tx_id').trim().notEmpty(),
    body('current_litres').isFloat({ min: 0 }).withMessage('current_litres required'),
  ],
  validate,
  dispense.progressDispense
);

router.use('/device', deviceRouter);

router.post(
  '/confirm',
  stationAuthMiddleware,
  [
    body('station_id').trim().notEmpty(),
    body('tx_id').trim().notEmpty(),
    body('actual_litres').isFloat({ min: 0 }).withMessage('actual_litres required'),
  ],
  validate,
  dispense.confirmDispense
);

router.post(
  '/abort',
  stationAuthMiddleware,
  [
    body('station_id').trim().notEmpty(),
    body('tx_id').trim().notEmpty(),
    body('reason').optional().trim().isLength({ max: 500 }),
  ],
  validate,
  dispense.abortDispense
);

export default router;
