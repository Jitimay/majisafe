import { Router } from 'express';
import { body, param, validationResult } from 'express-validator';
import * as pumps from '../controllers/pumpsController.js';
import { authMiddleware } from '../middleware/auth.js';
import { adminOnly } from '../middleware/adminOnly.js';
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

// POST /api/pumps/:stationId/command — admin only
router.post(
  '/:stationId/command',
  authMiddleware,
  adminOnly,
  [
    param('stationId').trim().notEmpty().withMessage('stationId required'),
    body('pump_number').isInt({ min: 1, max: 2 }).withMessage('pump_number must be 1 or 2').toInt(),
    body('action').isIn(['activate', 'deactivate']).withMessage('action must be activate or deactivate'),
  ],
  validate,
  pumps.sendPumpCommand
);

// GET /api/pumps/:stationId/pending — station auth
router.get(
  '/:stationId/pending',
  stationAuthMiddleware,
  [param('stationId').trim().notEmpty()],
  validate,
  pumps.getPendingPumpCommand
);

// POST /api/pumps/:stationId/ack — station auth
router.post(
  '/:stationId/ack',
  stationAuthMiddleware,
  [
    param('stationId').trim().notEmpty(),
    body('command_id').isInt({ min: 1 }).withMessage('command_id required').toInt(),
    body('pump_status_1').isBoolean().withMessage('pump_status_1 required').toBoolean(),
    body('pump_status_2').isBoolean().withMessage('pump_status_2 required').toBoolean(),
  ],
  validate,
  pumps.ackPumpCommand
);

// GET /api/pumps/:stationId/status — admin only
router.get(
  '/:stationId/status',
  authMiddleware,
  adminOnly,
  [param('stationId').trim().notEmpty()],
  validate,
  pumps.getPumpStatus
);

export default router;
