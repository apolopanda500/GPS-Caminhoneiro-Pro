// Simulador de uso real do app GPS Caminhoneiro Pro
// Uso: node tools/simular-app.js --ciclos 3 --aparelho ambos
const { execFile } = require('child_process');
const fs = require('fs');
const path = require('path');

const ADB = 'C:\\Program Files\\platform-tools\\adb.exe';
const PACOTE = 'com.gpscamioneiro.gps_camioneiro_pro';
const ATIVIDADE = 'com.gpscamioneiro.gps_camioneiro_pro/.MainActivity';
const OUT = 'C:\\Users\\Micro\\AppData\\Local\\Temp\\opencode\\sim-app';

const arg = (nome, padr) => {
  const i = process.argv.indexOf('--' + nome);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : padr;
};
const ciclos = parseInt(arg('ciclos', '3'), 10);
const qualAparelho = arg('aparelho', 'ambos');

function adb(args, timeout = 30000) {
  return new Promise((resolve) => {
    execFile(ADB, args, { timeout }, (erro, stdout, stderr) =>
      resolve({ ok: !erro, saida: String(stdout || ''), erro: String(stderr || erro || '') }));
  });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const rotaRJ = [
  [-43.538143, -22.845021],
  [-43.36, -22.87],
  [-43.21, -22.89],
  [-43.114, -22.9055],
  [-43.05, -22.93],
  [-42.95, -22.97],
  [-43.538143, -22.845021],
];

let contador = 0;
async function simularAparelho(aparelho, ciclo) {
  console.log(`--- ciclo ${ciclo}/${ciclos} em ${aparelho} ---`);
  const nomeLog = `${OUT}\\${aparelho.replace(/[^a-zA-Z0-9]/g, '_')}_${ciclo}`;
  const logFile = `${nomeLog}_logcat.txt`;

  const inst = await adb(['-s', aparelho, 'install', '-r',
    path.join(__dirname, '..', 'frontend-flutter', 'build', 'app', 'outputs', 'flutter-apk', 'app-debug.apk')], 420000);
  const abriu = await adb(['-s', aparelho, 'shell', 'am', 'start', '-n', ATIVIDADE]);
  if (!abriu.ok) {
    console.log(`  FALHA abrir app em ${aparelho}: ${abriu.erro}`);
    return { aparelho, ciclo, ok: false, motivo: 'am start' };
  }

  await adb(['-s', aparelho, 'logcat', '-c']);
  // Permissoes se ainda nao estiverem concedidas (silencioso)
  for (const perm of ['android.permission.ACCESS_FINE_LOCATION', 'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.POST_NOTIFICATIONS', 'android.permission.ACCESS_BACKGROUND_LOCATION']) {
    await adb(['-s', aparelho, 'shell', 'pm', 'grant', PACOTE, perm]);
  }

  for (let p = 0; p < rotaRJ.length; p++) {
    const [lon, lat] = rotaRJ[p];
    if (aparelho === 'emulator-5554') {
      await adb(['-s', aparelho, 'emu', 'geo', 'fix', String(lon), String(lat)]);
    }
    await sleep(2200);
  }

  const pid = await adb(['-s', aparelho, 'shell', 'pidof', PACOTE]);
  const printShot = `${nomeLog}_tela.png`;
  await adb(['-s', aparelho, 'exec-out', 'screencap', '-p'], 60000).then((r) => {
    if (r.ok && r.saida && r.saida.length) {
      const buf = Buffer.from(r.saida, 'binary');
      if (buf.length > 10000) fs.writeFileSync(printShot, buf);
      else console.log(`  print pequeno demais em ${aparelho} (${buf.length} bytes)`);
    }
  });

  const log = await adb(['-s', aparelho, 'logcat', '-d',
    `${PACOTE}:E`, '*:F'], 60000);
  fs.writeFileSync(logFile, log.saida || log);
  const erros = (log.saida || '').split('\n').filter((linha) =>
    /FATAL EXCEPTION|ANR in com\.gpscamioneiro|Process com\.gpscamioneiro.*(died|crashed)/i.test(linha));

  const vivo = pid.ok && pid.saida && pid.saida.trim() !== '';
  contador++;
  return {
    aparelho, ciclo, ok: vivo && erros.length === 0,
    pid: (vivo && pid.saida) || 'sem process',
    fatais: erros.slice(0, 3),
    print: fs.existsSync(printShot) ? printShot : null,
    logFile,
  };
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const lista = [];
  if (qualAparelho === 'ambos' || qualAparelho === 'celular') lista.push('R9XY1016R6V');
  if (qualAparelho === 'ambos' || qualAparelho === 'emulador') lista.push('emulator-5554');

  console.log('SIMULADOR APP USO REAL - ' + ciclos + ' ciclos em: ' + lista.join(', '));
  const resultados = [];
  for (const aparelho of lista) {
    for (let c = 1; c <= ciclos; c++) {
      const r = await simularAparelho(aparelho, c);
      resultados.push(r);
      console.log(`  ${r.ok ? 'OK' : 'FALHA'} ${aparelho} c${c} pid=${r.pid}${r.print ? ' print=' + path.basename(r.print) : ''}`);
    }
  }
  const bons = resultados.filter((r) => r.ok).length;
  console.log('='.repeat(50));
  console.log(`SIMULACAO: ${bons}/${resultados.length} ciclos ok`);
  resultados.filter((r) => !r.ok).forEach((r) =>
    console.log(`  pressa ${r.aparelho} c${r.ciclo}: ${r.motivo || ''}${r.fatais ? ' fatais: ' + r.fatais.join(' | ') : ''}`));
})();
