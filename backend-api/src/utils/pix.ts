function tlv(id: string, value: string): string {
  const len = value.length.toString().padStart(2, '0');
  return `${id}${len}${value}`;
}

export function crc16(payload: string): string {
  let crc = 0xffff;
  for (let i = 0; i < payload.length; i++) {
    crc ^= payload.charCodeAt(i) << 8;
    for (let j = 0; j < 8; j++) {
      crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

function sanitize(text: string, max: number): string {
  return text
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^A-Za-z0-9 .-]/g, '')
    .toUpperCase()
    .slice(0, max);
}

export interface PixParams {
  key: string;
  name: string;
  city: string;
  amount: number;
  txid?: string;
  description?: string;
}

// Gera um BR Code (PIX estatico) no padrao EMV, sem necessidade de PSP.
export function buildPixPayload(params: PixParams): string {
  const txid = sanitize(params.txid || '***', 25) || '***';

  const gui = tlv('00', 'br.gov.bcb.pix');
  const key = tlv('01', params.key);
  const desc = params.description
    ? tlv('02', sanitize(params.description, 40))
    : '';
  const merchantAccount = tlv('26', `${gui}${key}${desc}`);

  const payload = [
    tlv('00', '01'),
    merchantAccount,
    tlv('52', '0000'),
    tlv('53', '986'),
    tlv('54', params.amount.toFixed(2)),
    tlv('58', 'BR'),
    tlv('59', sanitize(params.name, 25)),
    tlv('60', sanitize(params.city, 15)),
    tlv('62', tlv('05', txid)),
  ].join('');

  const withCrcId = `${payload}6304`;
  return `${withCrcId}${crc16(withCrcId)}`;
}
