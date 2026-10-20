require('dotenv').config();
const nodemailer = require('nodemailer');
const t = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT) || 587,
  secure: process.env.SMTP_SECURE === 'true',
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
});
t.sendMail({
  from: process.env.SMTP_FROM,
  to: 'rickjax1234@gmail.com',
  subject: 'GPS Caminhoneiro Pro - teste SMTP Brevo',
  text: 'Teste de conexao do backend. Se voce recebeu, o codigo de confirmacao real ja funciona!',
  html: '<h2>GPS Caminhoneiro Pro</h2><p>SMTP Brevo <b>OK</b> — codigos de confirmacao chegando de verdade.</p>',
}).then(() => console.log('ENVIADO OK')).catch((e) => { console.error('ERRO:', e.message); process.exit(1); });
