import dotenv from 'dotenv';
dotenv.config();

const requiresSsl = /sslmode=require/i.test(process.env.DATABASE_URL || '');

export const env = {
  port: parseInt(process.env.PORT || '3000', 10),
  databaseUrl: process.env.DATABASE_URL || '',
  frontendUrl: process.env.FRONTEND_URL || '*',
  jwtSecret: process.env.JWT_SECRET || 'ROBO_DARK_SECRET_2026',
  isProduction: process.env.NODE_ENV === 'production',
  requiresSsl,
};
