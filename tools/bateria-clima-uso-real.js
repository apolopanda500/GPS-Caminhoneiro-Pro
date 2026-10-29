// BATERIA CLIMA USO REAL — camadas de clima e radar com PROVA visual
// - HTTP: mesmos endpoints que o app usa (RainViewer weather-maps.json, tiles
//   radar/infravermelho, Open-Meteo em grade) e Overpass (limites de velocidade
//   usados pelo alerta de radar).
// - Aparelhos: toques REAIS via adb nos botoes do painel (Mapa e graficos) e
//   comparacao de pixels entre screenshots antes/depois/animando (prova de
//   nuvens passando e areas de precipitacao desenhadas).
// Uso: node tools/bateria-clima-uso-real.js
const { execFile } = require('child_process');
const zlib = require('zlib');
const path = require('path');

const ADB = 'C:\\Program Files\\platform-tools\\adb.exe';
const SITE = 'com.gpscamioneiro.gps_camioneiro_pro';
const ACT = SITE + '/.MainActivity';
const APELIDOS = { 'R9XY1016R6V': 'celular', 'emulator-5554': 'emulador' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function adb(args, opts = {}) {
  const argv = args[0] === 'devices' ? args : ['-s'].concat(args);
  return new Promise((resolve) => {
    execFile(ADB, argv, { timeout: 45000, maxBuffer: 64 * 1024 * 1024, ...opts },
      (e, o, er) => resolve({ ok: !e, saida: o, erro: String(er || e || '') }));
  });
}

// -------- PNG minimo (RGBA8 do screencap) para comparar pixels --------
function lerPng(buffer) {
  let p = 8;
  let w = 0, h = 0, cor = 0;
  const chunks = [];
  while (p < buffer.length - 8) {
    const len = buffer.readUInt32BE(p);
    const tipo = buffer.toString('latin1', p + 4, p + 8);
    const dado = buffer.slice(p + 8, p + 8 + len);
    if (tipo === 'IHDR') { w = dado.readUInt32BE(0); h = dado.readUInt32BE(4); cor = dado[9]; }
    if (tipo === 'IDAT') chunks.push(dado);
    if (tipo === 'IEND') break;
    p += 12 + len;
  }
  if (cor !== 6 && cor !== 2) throw new Error('png cor=' + cor);
  const raw = zlib.inflateSync(Buffer.concat(chunks));
  const bpp = cor === 6 ? 4 : 3;
  const stride = w * bpp;
  const out = Buffer.alloc(h * stride);
  let pos = 0;
  for (let y = 0; y < h; y++) {
    const filtro = raw[pos++];
    const linha = raw.slice(pos, pos + stride); pos += stride;
    const dest = y * stride;
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[dest + x - bpp] : 0;
      const b = y > 0 ? out[dest + x - stride] : 0;
      const c = (x >= bpp && y > 0) ? out[dest + x - bpp - stride] : 0;
      let v = linha[x];
      if (filtro === 1) v += a;
      else if (filtro === 2) v += b;
      else if (filtro === 3) v += (a + b) >> 1;
      else if (filtro === 4) {
        const pa = Math.abs(b - c), pb = Math.abs(a - c), pc = Math.abs(a + b - 2 * c);
        const pr = (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
        v += pr;
      }
      out[dest + x] = v & 0xff;
    }
  }
  return { w, h, bpp, dados: out };
}
function diferenca(a, b, yInicial) {
  const ea = lerPng(a), eb = lerPng(b);
  if (ea.w !== eb.w || ea.h !== eb.h) return { px: -1, total: -1 };
  let dif = 0, total = 0;
  const y0 = Math.max(0, Math.floor(yInicial)) * ea.stride0;
  const stride = ea.w * ea.bpp;
  for (let y = Math.max(0, Math.floor(yInicial)); y < Math.min(ea.h, eb.h); y++) {
    for (let x = 0; x < ea.w; x += 2) {
      const off = y * stride + x * ea.bpp;
      const db = Math.abs(ea.dados[off] - eb.dados[off]);
      const dg = Math.abs(ea.dados[off + 1] - eb.dados[off + 1]);
      if (db > 24 || dg > 24) dif++;
      total++;
    }
  }
  return { px: dif, total };
}

// -------- utils de UI --------
async function dumpXml(s) {
  for (let i = 0; i < 4; i++) {
    const out = await adb([s, 'shell', 'uiautomator', 'dump']);
    if (!/null root|ERROR/i.test(out.saida || '') && /uiautomator|dumped/i.test(out.saida || '')) {
      const cat = await adb([s, 'shell', 'cat', '/sdcard/window_dump.xml']);
      if ((cat.saida || '').includes('<node')) return cat.saida;
    }
    await sleep(2000);
  }
  return '';
}
function acharNo(xml, texto) {
  const re = /text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/g;
  let m;
  const alvo = texto.toLowerCase();
  while ((m = re.exec(xml)) !== null) {
    if (m[1].toLowerCase().includes(alvo)) {
      const x1 = +m[2], y1 = +m[3], x2 = +m[4], y2 = +m[5];
      if (x2 > x1 && y2 > y1) return { x: (x1 + x2) >> 1, y: (y1 + y2) >> 1, x2, x1 };
    }
  }
  return null;
}
async function tocarTexto(s, texto, tentativas = 3) {
  for (let i = 0; i < tentativas; i++) {
    const xml = await dumpXml(s);
    const n = acharNo(xml, texto);
    if (n) {
      await adb([s, 'shell', 'input', 'tap', String(n.x), String(n.y)]);
      return n;
    }
    await adb([s, 'shell', 'input', 'swipe', '540', '1500', '540', '900']);
    await sleep(900);
  }
  return null;
}
async function tamanhoTela(s) {
  const out = await adb([s, 'shell', 'wm', 'size']);
  const m = /(\d+)x(\d+)/.exec(out.saida || '');
  return m ? { w: +m[1], h: +m[2] } : { w: 1080, h: 2400 };
}
async function tocarPonto(s, fx, fy) {
  const t = await tamanhoTela(s);
  await adb([s, 'shell', 'input', 'tap', String(Math.round(t.w * fx)), String(Math.round(t.h * fy))]);
}
const Y_CAMADA = {
  'Radar de chuva': 0.383,
  'Precipitação': 0.450,
  'Vento': 0.517,
  'Temperatura': 0.584,
  'Nuvens': 0.652,
};
async function screenshot(s, nome) {
  let cap = await adb([s, 'exec-out', 'screencap', '-p'], { timeout: 60000, encoding: 'buffer' });
  let buf = Buffer.from(cap.saida || '');
  const completo = (b) => b.length > 20000 && b.includes(Buffer.from('IEND', 'latin1'));
  if (!completo(buf)) {
    await adb([s, 'shell', 'screencap', '-p', '/sdcard/scr_tmp.png']);
    await adb([s, 'pull', '/sdcard/scr_tmp.png', path.join(OUT, 'tmp_' + (APELIDOS[s] || s) + '.png')], { timeout: 60000 });
    try { buf = fs.readFileSync(path.join(OUT, 'tmp_' + (APELIDOS[s] || s) + '.png')); } catch { buf = Buffer.alloc(0); }
  }
  if (completo(buf)) return buf;
  return null;
}
const OUT = 'C:\\Users\\Micro\\AppData\\Local\\Temp\\opencode\\clima-uso-real';
const fs = require('fs');

// -------- HTTP (mesmos endpoints do app) --------
async function get(url) {
  const r = await fetch(url, { headers: { 'User-Agent': 'gps-camioneiro-pro/1.0' } });
  return { status: r.status, buf: Buffer.from(await r.arrayBuffer()) };
}
function mercator(lon, lat, z) {
  const n = 2 ** z;
  return {
    x: Math.floor(((lon + 180) / 360) * n),
    y: Math.floor((1 - Math.log(Math.tan(lat * Math.PI / 180) + 1 / Math.cos(lat * Math.PI / 180)) / Math.PI) / 2 * n),
  };
}

async function parteHttp(res) {
  const w = await get('https://api.rainviewer.com/public/weather-maps.json');
  if (w.status !== 200) throw new Error('weather-maps ' + w.status);
  const data = JSON.parse(w.buf.toString('utf8'));
  const host = data.host || '';
  const past = data.radar?.past || [];
  const nowcast = data.radar?.nowcast || [];
  const ir = data.satellite?.infrared || [];
  res.framesPassados = past.length;
  res.framesNowcast = nowcast.length;
  res.framesInfravermelho = ir.length;
  if (past.length < 10) throw new Error('radar passado insuficiente');

  // duas horas do Rio no mesmo zoom: frames diferentes => nuvens passando
  const frameA = past[past.length - 2], frameB = past[past.length - 1];
  const { x, y } = mercator(-43.17, -22.9, 6);
  const tA = await get(`${host}${frameA.path}/256/6/${x}/${y}/2/1_1.png`);
  const tB = await get(`${host}${frameB.path}/256/6/${x}/${y}/2/1_1.png`);
  res.radarTiles = tA.status === 200 && tA.buf.length > 400;
  res.framesDivergem = tA.status === 200 && tB.status === 200 && !tA.buf.equals(tB.buf);
  res.irTile = null;
  if (res.framesPassados && res.framesInfravermelho === null) res.framesInfravermelho = ir.length;
  if (ir.length) {
    const tC = await get(`${host}${ir[ir.length - 1].path}/256/6/${x}/${y}/0/0_0.png`);
    res.irTile = tC.status === 200 && tC.buf.length > 400;
  }

  // grade Open-Meteo: vento/precipitacao/temperatura variando (areas reais)
  const lats = [], lons = [];
  for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
    lats.push(((-22.9) + (i - 2) * 0.22).toFixed(4));
    lons.push(((-43.2) + (j - 2) * 0.22).toFixed(4));
  }
  const met = await get(`https://api.open-meteo.com/v1/forecast?latitude=${lats.join(',')}&longitude=${lons.join(',')}&hourly=wind_speed_10m,precipitation_probability,temperature_2m,cloud_cover&forecast_days=2&timezone=auto`);
  if (met.status !== 200) throw new Error('open-meteo ' + met.status);
  const locs = JSON.parse(met.buf.toString('utf8'));
  const arr = Array.isArray(locs) ? locs : [locs];
  const ventos = [], probs = [], temps = [], nuvens = [];
  for (const l of arr) {
    const horas = l.hourly?.time || [];
    let idx = 0, menor = 1e12;
    const agora = Date.now();
    for (let t = 0; t < horas.length; t++) {
      const d = Math.abs(new Date(horas[t]).getTime() - agora);
      if (d < menor) { menor = d; idx = t; }
    }
    const v = l.hourly?.wind_speed_10m?.[idx], p = l.hourly?.precipitation_probability?.[idx], te = l.hourly?.temperature_2m?.[idx];
    const nu = l.hourly?.cloud_cover?.[idx];
    if (typeof v === 'number') ventos.push(v);
    if (typeof p === 'number') probs.push(p);
    if (typeof te === 'number') temps.push(te);
    if (typeof nu === 'number') nuvens.push(nu);
  }
  res.grade16 = arr.length >= 16;
  res.ventoVariando = ventos.length >= 12 && ventos.reduce((a, b) => a + Math.abs(b)) / ventos.length > 2;
  res.ventoFaixa = ventos.length > 0 && Math.max(...ventos) <= 150;
  res.precipProbOk = probs.length >= 12 && probs.every((p) => p >= 0 && p <= 100);
  res.tempVariando = temps.length >= 12 && (Math.max(...temps) - Math.min(...temps) > 0.1);
  res.nuvensPrevistasOk = nuvens.length >= 12 && nuvens.every((n) => n >= 0 && n <= 100);

  // Overpass: limites de velocidade reais perto (base do alerta de radar)
  const q = `[out:json][timeout:15];way(around:2000,-22.9068,-43.1729)["maxspeed"];out tags 3;`;
  res.radaresOverpass = false;
  for (let tentativa = 1; tentativa <= 3 && !res.radaresOverpass; tentativa++) {
    const ov = await get('https://overpass-api.de/api/interpreter?data=' + encodeURIComponent(q));
    res.overpassStatus = ov.status;
    try {
      const oj = JSON.parse(ov.buf.toString('utf8'));
      const tags = (oj.elements || []).map((e) => e.tags || {}).filter((t) => t.maxspeed);
      res.radaresOverpass = tags.length >= 1;
      res.exemploMaxspeed = tags[0]?.maxspeed;
    } catch {
      if (tentativa < 3) await sleep(3000);
    }
  }
}

// -------- parte dos aparelhods --------
async function parteAparelho(ap, res) {
  const s = ap;
  await adb([s, 'shell', 'am', 'start', '-n', ACT]);
  await sleep(8000);
  const placa = await screenshot(s, 'base');
  if (!placa) throw new Error('screencap falhou');
  fs.writeFileSync(path.join(OUT, `${APELIDOS[s]}_base.png`), placa);

  const xml = await dumpXml(s);
  const	txtTextos = (xml.match(/text="[^"]{2,60}"/g) || []).slice(0, 40).join(' ');
  res.textosTela = txtTextos;
  res.modo = /text="[^"]{2,}/.test(xml) ? 'texto' : 'coordenadas';

  // abre o painel "Mapa e graficos"
  let abriu;
  if (res.modo === 'coordenadas') {
    await tocarPonto(s, 0.278, 0.165);
    await sleep(2500);
    const painel = await screenshot(s, 'painel');
    if (painel) fs.writeFileSync(path.join(OUT, `${APELIDOS[s]}_painel.png`), painel);
    abriu = painel ? diferenca(placa, painel, 110).px > 50 : false;
  } else {
    abriu = await tocarTexto(s, 'Mapa e graficos');
  }
  if (!abriu) { res.falha = 'botao Mapa e graficos nao encontrado (app nao logado?)'; return; }
  await sleep(1500);

  const camadas = ['Radar de chuva', 'Precipitação', 'Vento', 'Temperatura', 'Nuvens'];
  const prints = {};
  for (const nome of camadas) {
    let n;
    if (res.modo === 'coordenadas') {
      await tocarPonto(s, 0.76, Y_CAMADA[nome]);
      n = true;
    } else {
      n = await tocarTexto(s, nome);
    }
    if (!n) { res['botao_' + nome] = false; continue; }
    await sleep(2500);
    const p = await screenshot(s, nome);
    if (p) {
      const arquivo = path.join(OUT, `${APELIDOS[s]}_${nome.replace(/[^a-zA-Z]/g, '')}.png`);
      fs.writeFileSync(arquivo, p);
      prints[nome] = p;
    }
    res['botao_' + nome] = true;
    if (nome !== 'Vento' && nome !== 'Temperatura') await sleep(2500);
  }

  // radar animando: pausa/remover para comparar com o mapa base
  const xml2 = await dumpXml(s);
  const nosSubs = /text="(Animando[^"]*|1200\+ radares[^"]*)"/.exec(xml2);
  res.radarSubtitulo = nosSubs ? nosSubs[1].slice(0, 70) : null;
  // fecha o painel (botao fora / voltar)
  await adb([s, 'shell', 'input', 'keyevent', '4']);
  await sleep(1200);

  const mapaAtivo = await screenshot(s, 'mapa ativo');
  if (mapaAtivo) fs.writeFileSync(path.join(OUT, `${APELIDOS[s]}_mapa_com_camadas.png`), mapaAtivo);
  res.mapaDiferencaPx = diferenca(placa, mapaAtivo, 110).px;
  if (prints['Radar de chuva']) {
    const d2 = diferenca(prints['Radar de chuva'], mapaAtivo, 110);
    res.radarPaineisDif = d2.px;
  }
  if (prints['Precipitação'] && prints['Nuvens']) {
    res.camadasEntreSiDif = diferenca(prints['Precipitação'], prints['Nuvens'], 110).px;
  }
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const http = {}, aparelhos = {};
  const lista = [];
  {
    const devs = await adb(['devices']);
    for (const line of devs.saida.split('\n').slice(1)) {
      if (line.includes('\tdevice')) lista.push(line.split('\t')[0]);
    }
  }
  console.log('aparelhos:', lista.map((x) => x + ' (' + (APELIDOS[x] || x) + ')').join(', '));

  try { await parteHttp(http); } catch (e) { http.erro = String(e).slice(0, 300); }
  if (http.erro) console.log('HTTP erro: ' + http.erro);
  for (const ap of lista) {
    try { aparelhos[ap] = {}; await parteAparelho(ap, aparelhos[ap]); }
    catch (e) { aparelhos[ap] = { erro: String(e).slice(0, 180) }; }
  }

  console.log('======== HTTP (provedores que o app usa) ========');
  console.log(`radar passado: ${http.framesPassados ?? '?'} frames | nowcast no momento: ${http.framesNowcast ?? '?'} | infravermelho no momento: ${http.framesInfravermelho ?? '?'}`);
  console.log(`tiles radar reais: ${http.radarTiles ? 'OK' : 'FALHA'} | frames divergem (nuvens passando: sim) ${http.framesDivergem ? 'OK' : 'FALHA'}`);
  console.log(`ir tile: ${http.irTile === null ? 'fornecedor sem frame agora (app cai p/ previsto)' : (http.irTile ? 'OK' : 'FALHA')}`);
  console.log(`grade 16+ ${http.grade16 ? 'ok,' : 'falha'} vento variando: ${http.ventoVariando ? 'OK' : 'FALHA'} | prob. precipitação 0-100: ${http.precipProbOk ? 'OK' : 'FALHA'} | temp variando: ${http.tempVariando ? 'OK' : 'FALHA'} | nuvens previstas 0-100: ${http.nuvensPrevistasOk ? 'OK' : 'FALHA'}`);
  console.log(`radares/maxspeed via Overpass: ${http.radaresOverpass ? 'OK (' + http.exemploMaxspeed + ')' : 'FALHA'}${http.overpassStatus ? ' [http ' + http.overpassStatus + ']' : ''}`);
  console.log('======== APARELHOS (toques reais nos botões) ========');
  for (const [ap, r] of Object.entries(aparelhos)) {
    const nome = APELIDOS[ap] || ap;
    if (r.falha || r.erro) { console.log(`${nome}: PROBLEMA ${r.falha || r.erro} | modo ${r.modo || '?'}`); console.log('  textos da tela: ' + (r.textosTela || 'sem dump')); continue; }
    const botoes = ['Radar de chuva', 'Precipitação', 'Vento', 'Temperatura', 'Nuvens']
      .map((t) => `${t}=${r['botao_' + t] ? 'tocou' : 'não achou'}`).join(' | ');
    console.log(`${nome} (${r.modo || '?'}): ${botoes}`);
    console.log(`  radar subtitulo: ${r.radarSubtitulo || '(não leu)'} | mapa mudou vs base: ${r.mapaDiferencaPx} px em ${0 + 1000} amostras`);
    console.log(`  radar vs nuvens diferentes: ${r.camadasEntreSiDif ?? '?'} px`);
  }
  console.log('prints em ' + OUT);
})();
