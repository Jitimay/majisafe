import { Router } from 'express';
import { body, param, validationResult } from 'express-validator';
import * as stations from '../controllers/stationsController.js';
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

router.get('/', stations.listStations);

router.get('/:id', [param('id').trim().notEmpty()], validate, stations.getStation);

router.post(
  '/heartbeat',
  stationAuthMiddleware,
  [
    body('station_id').trim().notEmpty(),
    body('status').optional().trim().isLength({ max: 40 }),
    body('tank_level').optional().isFloat({ min: 0, max: 100 }),
    body('uptime_seconds').optional().isInt({ min: 0 }),
    body('firmware_version').optional().trim().isLength({ max: 40 }),
    body('pump_1_active').optional().isBoolean(),
    body('pump_2_active').optional().isBoolean(),
    body('pump_1_runtime_seconds').optional().isFloat({ min: 0 }),
    body('pump_2_runtime_seconds').optional().isFloat({ min: 0 }),
  ],
  validate,
  stations.heartbeat
);

export default router;
