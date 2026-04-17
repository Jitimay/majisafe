import { Router } from 'express';
import { param, validationResult } from 'express-validator';
import * as analytics from '../controllers/analyticsController.js';
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

// All analytics endpoints require admin JWT
router.use(authMiddleware, adminOnly);

router.get(
  '/:stationId/recommendation',
  [param('stationId').trim().notEmpty()],
  validate,
  analytics.getRecommendation
);

router.get(
  '/:stationId/tank-history',
  [param('stationId').trim().notEmpty()],
  validate,
  analytics.getTankHistory
);

router.get(
  '/:stationId/daily-usage',
  [param('stationId').trim().notEmpty()],
  validate,
  analytics.getDailyUsage
);

router.get(
  '/:stationId/hourly-heatmap',
  [param('stationId').trim().notEmpty()],
  validate,
  analytics.getHourlyHeatmap
);

router.get(
  '/:stationId/depletion-rate',
  [param('stationId').trim().notEmpty()],
  validate,
  analytics.getDepletionRate
);

router.get(
  '/:stationId/time-to-empty',
  [param('stationId').trim().notEmpty()],
  validate,
  analytics.getTimeToEmpty
);

export default router;
