const fs = require('fs');
const https = require('https');
const j = JSON.parse(fs.readFileSync('keys.json', 'utf8').replace(/^\uFEFF/, ''));
const key = j.TOMTOM_TRAFFIC_KEY;

const lat = -22.9068;
const lon = -43.1729;
const z = 15;
const n = Math.pow(2, z);
const x = Math.floor(((lon + 180) / 360) * n);
const y = Math.floor(
  ((1 - Math.asinh(Math.tan((lat * Math.PI) / 180)) / Math.PI) / 2) * n,
);

const url = `https://api.tomtom.com/maps/orbis/traffic/flow/vector/tile/${z}/${x}/${y}?apiVersion=2&key=${key}`;

https.get(url, { headers: { 'User-Agent': 'gps-camioneiro-pro/1.0' } }, (res) => {
  const cs = [];
  res.on('data', (c) => cs.push(c));
  res.on('end', () => {
    const b = Buffer.concat(cs);
    console.log('status', res.statusCode, 'bytes', b.length);
    // Nomes de campos e valores enum ficam como strings no tile.
    const s = b.toString('latin1');
    const nomes = s.match(/[a-z_]{4,40}/g) || [];
    const unicos = [...new Set(nomes)].filter(
      (x) => !/^[a-z]{40,}$/.test(x) && x.length > 4,
    );
    console.log('strings encontradas:');
    console.log(unicos.join('\n'));
  });
});
