import dotenv from 'dotenv';
dotenv.config();

const requiresSsl = /sslmode=require/i.test(process.env.DATABASE_URL || '');

export const env = {
  port: parseInt(process.env.PORT || '3000', 10),
  databaseUrl: process.env.DATABASE_URL || '',
  frontendUrl: process.env.FRONTEND_URL || '*',
  jwtSecret: process.env.JWT_SECRET || 'ROBO_DARK_SECRET_2026',
  adminToken: process.env.ADMIN_TOKEN || '',
  isProduction: process.env.NODE_ENV === 'production',
  requiresSsl,

  // PIX (recebimento direto na conta do desenvolvedor, BR Code estatico).
  pixKey: process.env.PIX_KEY || '',
  pixName: process.env.PIX_NAME || 'HENRIQUE DE CARVALHO',
  pixCity: process.env.PIX_CITY || 'RIO DE JANEIRO',
  pixAmount: parseFloat(process.env.PIX_AMOUNT || '4.99'),
  pixDescription: process.env.PIX_DESCRIPTION || 'Assinatura Premium GPS Caminhoneiro Pro',

  // E-mail (codigos de verificacao de conta).
  smtpHost: process.env.SMTP_HOST || '',
  smtpPort: parseInt(process.env.SMTP_PORT || '587', 10),
  smtpUser: process.env.SMTP_USER || '',
  smtpPass: process.env.SMTP_PASS || '',
  smtpFrom: process.env.SMTP_FROM || process.env.SMTP_USER || '',
  smtpSecure: process.env.SMTP_SECURE === 'true',
  brevoApiKey: process.env.BREVO_API_KEY || '',

  // IA do assistente (opcional: sem chave, o assistente responde localmente).
  openaiApiKey: process.env.OPENAI_API_KEY || '',
  anthropicApiKey: process.env.ANTHROPIC_API_KEY || '',
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  geminiModel: process.env.GEMINI_MODEL || 'gemini-3-flash-preview',
};
