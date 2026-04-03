import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { getDb } from './models/db.js';
import { errorHandler } from './utils/errors.js';
import { log } from './utils/logger.js';

import authRoutes from './routes/auth.js';
import walletRoutes from './routes/wallet.js';
import dispenseRoutes from './routes/dispense.js';
import stationsRoutes from './routes/stations.js';
import adminRoutes from './routes/admin.js';
import smsRoutes from './routes/sms.js';

/**
 * Creates and configures the Express application.
 */
function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '256kb' }));

  app.get('/health', (req, res) => {
    res.json({ success: true, service: 'majisafe-backend' });
  });

  app.use('/api/auth', authRoutes);
  app.use('/api/wallet', walletRoutes);
  app.use('/api/dispense', dispenseRoutes);
  app.use('/api/stations', stationsRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api/sms', smsRoutes);

  app.use(errorHandler);
  return app;
}

const app = createApp();
getDb();

const port = Number(process.env.PORT) || 3000;
app.listen(port, () => {
  log('info', 'MajiSafe API listening', { port });
});

export { createApp };
