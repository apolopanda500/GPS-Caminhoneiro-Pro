const https = require('https');

https.get('https://gps-truck-backend.onrender.com/status', (r) => {
  let d = '';
  r.on('data', (c) => d += c);
  r.on('end', () => console.log('Backend status:', d));
}).on('error', (e) => console.log('ERRO backend:', e.message));
