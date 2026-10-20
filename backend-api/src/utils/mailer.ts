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
  try {
    await transporter.sendMail({
      from: env.smtpFrom,
      to,
      subject: mail.subject,
      text: mail.text,
      html: mail.html,
    });
    return true;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('[mailer] falha ao enviar o e-mail:', msg);
    if (/unauthor|not authorized|blocked|401|403|ip/i.test(msg)) {
      console.error(
        '[mailer] O provedor recusou o envio. Se a Brevo esta com bloqueio por IP ' +
          'ativado, libere as faixas de saida do Render (74.220.48.0/24 e ' +
          '74.220.56.0/24) em Seguranca > IPs autorizados.',
      );
    }
    return false;
  }
}

export async function sendPasswordResetCode(
  to: string,
  code: string
): Promise<boolean> {
  const mail: MailTexto = {
    subject: 'GPS Caminhoneiro Pro - codigo para redefinir a senha',
    text: `Seu codigo para redefinir a senha e ${code}. Ele expira em 10 minutos. Se nao foi voce, ignore este e-mail: sua senha nao muda.`,
    html: `<div style="font-family:Arial,sans-serif">
      <h2>GPS Caminhoneiro Pro</h2>
      <p>Você pediu para redefinir a sua senha. Use o código abaixo:</p>
      <p style="font-size:28px;font-weight:bold;letter-spacing:4px">${code}</p>
      <p>O código expira em 10 minutos. Se não foi você, ignore este e-mail: sua senha não muda.</p>
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
    console.log(`[mailer] SMTP nao configurado. Codigo de reset para ${to}: ${code}`);
    return false;
  }
  try {
    await transporter.sendMail({
      from: env.smtpFrom,
      to,
      subject: mail.subject,
      text: mail.text,
      html: mail.html,
    });
    return true;
  } catch (err) {
    console.error('[mailer] falha ao enviar o e-mail de reset:',
      err instanceof Error ? err.message : String(err));
    return false;
  }
}

export function mailerConfigured(): boolean {
  return env.brevoApiKey !== '' || transporter !== null;
}
