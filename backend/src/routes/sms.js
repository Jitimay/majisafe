import { Router } from 'express';
import * as sms from '../controllers/smsController.js';
import { authMiddleware } from '../middleware/auth.js';
import { adminOnly } from '../middleware/adminOnly.js';
import { apiError } from '../utils/errors.js';

const router = Router();

/**
 * Ensures SMS webhook has sender and message body fields.
 */
function webhookBody(req, res, next) {
  const from = req.body.from || req.body.from_number;
  const message = req.body.message || req.body.text;
  if (!from || !message) {
    return res.status(400).json(apiError('VALIDATION_ERROR', 'from and message (or text) are required'));
  }
  return next();
}

router.post('/webhook', webhookBody, sms.smsWebhook);

router.get('/pending', authMiddleware, adminOnly, sms.smsPending);

export default router;
