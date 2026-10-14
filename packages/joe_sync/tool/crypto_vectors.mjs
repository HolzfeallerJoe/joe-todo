// Erzeugt test/vectors/crypto.json mit WebCrypto (Node), also mit derselben
// Schnittstelle, die die Webseite im Browser benutzt. Die Dart-Tests pruefen
// dagegen; so ist sicher, dass App und Webseite dieselben Bytes rechnen.
//
// Aufruf (nur noetig, wenn sich das Format aendert):
//   node tool/crypto_vectors.mjs > test/vectors/crypto.json
const subtle = globalThis.crypto.subtle;
const enc = new TextEncoder();

const b64 = (bytes) =>
  Buffer.from(bytes).toString('base64url');
const seq = (n, start) => Uint8Array.from({ length: n }, (_, i) => (start + i * 7) & 0xff);

async function hkdf(ikm, listId, info) {
  const key = await subtle.importKey('raw', ikm, 'HKDF', false, ['deriveBits']);
  const bits = await subtle.deriveBits(
    { name: 'HKDF', hash: 'SHA-256', salt: enc.encode(listId), info: enc.encode(info) },
    key, 256);
  return new Uint8Array(bits);
}

async function sha256(bytes) {
  return new Uint8Array(await subtle.digest('SHA-256', bytes));
}

const cases = [];
const inputs = [
  { listId: 'AAECAwQFBgcICQoLDA0ODw', secret: seq(32, 1), owner: seq(32, 100), code: '' },
  { listId: 'q83vASNFZ4mrze8BI0VniQ', secret: seq(32, 200), owner: seq(32, 3), code: '042317' },
];
for (const input of inputs) {
  const key = await hkdf(input.secret, input.listId, 'joe-v1-key');
  const access = await hkdf(
    Uint8Array.from([...input.secret, ...enc.encode(input.code)]), input.listId, 'joe-v1-access');
  const owner = await hkdf(input.owner, input.listId, 'joe-v1-owner');
  const opId = 'op_' + input.listId.slice(0, 19);
  const nonce = seq(12, 50);
  const body = { v: 1, op: 'item.add', device: 'dev1', item: 'item1', title: 'Hafermilch – 2× 1 l', done: false, createdAt: '2026-10-14T08:00:00.000Z' };
  const plain = JSON.stringify(body);
  const aesKey = await subtle.importKey('raw', key, 'AES-GCM', false, ['encrypt']);
  const sealed = new Uint8Array(await subtle.encrypt(
    { name: 'AES-GCM', iv: nonce, additionalData: enc.encode(`${input.listId}:${opId}`) },
    aesKey, enc.encode(plain)));
  cases.push({
    listId: input.listId,
    secret: b64(input.secret),
    code: input.code,
    ownerSecret: b64(input.owner),
    key: b64(key),
    accessToken: b64(access),
    accessHash: b64(await sha256(access)),
    ownerToken: b64(owner),
    ownerHash: b64(await sha256(owner)),
    opId,
    nonce: b64(nonce),
    plain,
    blob: b64(Uint8Array.from([...nonce, ...sealed])),
  });
}
console.log(JSON.stringify({ cases }, null, 2));
