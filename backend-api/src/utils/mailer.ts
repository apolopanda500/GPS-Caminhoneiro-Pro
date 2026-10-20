import nodemailer, { Transporter } from 'nodemailer';
import { env } from '../config/env';

let transporter: Transporter | null = null;

if (env.smtpHost && env.smtpUser && env.smtpPass) {
  transporter = nodemailer.createTransport({
    host: env.smtpHost,
    port: env.smtpPort,
    secure: env.smtpSecure,
    auth: { user: env.smtpUser, pass: env.smtpPass },
    connectionTimeout: 8000,
    greetingTimeout: 8000,
    socketTimeout: 15000,
  });
}

interface MailTexto {
  subject: string;
  text: string;
  html: string;
}

async function enviarViaApiBrevo(
  to: string,
  mail: MailTexto
): Promise<boolean> {
  const resp = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': env.brevoApiKey,
      'content-type': 'application/json',
      accept: 'application/json',
    },
    body: JSON.stringify({
      sender: { name: 'GPS Caminhoneiro Pro', email: env.smtpFrom },
      to: [{ email: to }],
      subject: mail.subject,
      textContent: mail.text,
      htmlContent: mail.html,
    }),
    signal: AbortSignal.timeout(10000),
  });
  return resp.status >= 200 && resp.status < 300;
}

export async function sendVerificationCode(
  to: string,
  code: string
): Promise<boolean> {
  const mail: MailTexto = {
    subject: 'GPS Caminhoneiro Pro - codigo de confirmacao',
    text: `Seu codigo de confirmacao e ${code}. Ele expira em 10 minutos.`,
    html: `<div style="font-family:Arial,sans-serif">
      <h2>GPS Caminhoneiro Pro</h2>
      <p>Seu codigo de confirmacao e:</p>
      <p style="font-size:28px;font-weight:bold;letter-spacing:4px">${code}</p>
      <p>O codigo expira em 10 minutos. Se nao foi voce, ignore este e-mail.</p>
    </div>`,
  };

  if (env.brevoApiKey) {
    try {
      return await enviarViaApiBrevo(to, mail);
    } catch (err) {
      console.error('[mailer] falha na API HTTP do Brevo:', err);
    }
  }

  if (!transporter) {
    console.log(`[mailer] SMTP nao configurado. Codigo de ${to}: ${code}`);
    return false;
  }
  await transporter.sendMail({
    from: env.smtpFrom,
    to,
    subject: mail.subject,
    text: mail.text,
    html: mail.html,
  });
  return true;
}

export function mailerConfigured(): boolean {
  return env.brevoApiKey !== '' || transporter !== null;
}
