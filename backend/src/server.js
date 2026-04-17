import 'dotenv/config';
import http from 'http';
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
import electricityRoutes from './routes/electricity.js';
import simulateRoutes from './routes/simulate.js';
import pumpsRoutes from './routes/pumps.js';
import analyticsRoutes from './routes/analytics.js';

/**
 * Creates and configures the Express application.
 */
function createApp() {
  const app = express();
  // No middleware: fastest possible response for LAN / device probes.
  app.get('/health', (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.json({ success: true, service: 'majisafe-backend' });
  });

  app.use(cors());
  app.use(express.json({ limit: '256kb' }));

  app.use('/api/auth', authRoutes);
  app.use('/api/wallet', walletRoutes);
  app.use('/api/dispense', dispenseRoutes);
  app.use('/api/stations', stationsRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api/sms', smsRoutes);
  app.use('/api/electricity', electricityRoutes);
  app.use('/api/simulate', simulateRoutes);
  app.use('/api/pumps', pumpsRoutes);
  app.use('/api/analytics', analyticsRoutes);

  app.use(errorHandler);
  return app;
}

const app = createApp();

if (!String(process.env.JWT_SECRET || '').trim()) {
  log(
    'error',
    'JWT_SECRET is not set. In the backend folder: cp .env.example .env then edit .env and set JWT_SECRET (long random string).'
  );
  process.exit(1);
}

getDb();

const port = Number(process.env.PORT) || 3000;
const host = process.env.HOST || '0.0.0.0';
const server = http.createServer(app);
server.on('connection', (socket) => {
  socket.setNoDelay(true);
});
server.listen(port, host, () => {
  log('info', 'MajiSafe API listening', { port, host });
});

export { createApp };
