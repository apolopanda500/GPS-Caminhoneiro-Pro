import nodemailer, { Transporter } from 'nodemailer';
import { env } from '../config/env';

let transporter: Transporter | null = null;

if (env.smtpHost && env.smtpUser && env.smtpPass) {
  transporter = nodemailer.createTransport({
    host: env.smtpHost,
    port: env.smtpPort,
    secure: env.smtpSecure,
    auth: { user: env.smtpUser, pass: env.smtpPass },
  });
}

export async function sendVerificationCode(
  to: string,
  code: string
): Promise<boolean> {
  if (!transporter) {
    console.log(`[mailer] SMTP nao configurado. Codigo de ${to}: ${code}`);
    return false;
  }
  await transporter.sendMail({
    from: env.smtpFrom,
    to,
    subject: 'GPS Caminhoneiro Pro - codigo de confirmacao',
    text: `Seu codigo de confirmacao e ${code}. Ele expira em 10 minutos.`,
    html: `<div style="font-family:Arial,sans-serif">
      <h2>GPS Caminhoneiro Pro</h2>
      <p>Seu codigo de confirmacao e:</p>
      <p style="font-size:28px;font-weight:bold;letter-spacing:4px">${code}</p>
      <p>O codigo expira em 10 minutos. Se nao foi voce, ignore este e-mail.</p>
    </div>`,
  });
  return true;
}

export function mailerConfigured(): boolean {
  return transporter !== null;
}
