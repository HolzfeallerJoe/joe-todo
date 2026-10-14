// Kryptografie der geteilten Listen, WebCrypto-Fassung von
// packages/joe_sync/lib/src/crypto.dart. Beide pruefen dieselben
// Testvektoren (packages/joe_sync/test/vectors/crypto.json).
//
// HKDF-SHA256, Salt = UTF-8 der Listen-ID, 32 Bytes:
//   K = HKDF(S, "joe-v1-key")          AES-256-GCM-Schluessel
//   A = HKDF(S ‖ Code, "joe-v1-access") Zugangstoken (Bearer)
// Block = b64(Nonce(12) ‖ Chiffrat ‖ Tag(16)), AAD = "<Listen-ID>:<Op-ID>".

const enc = new TextEncoder();
const dec = new TextDecoder();

function subtle() {
  const s = globalThis.crypto && globalThis.crypto.subtle;
  if (!s) throw new Error('Kein WebCrypto (nur ueber HTTPS oder localhost)');
  return s;
}

/** base64url ohne Auffuellzeichen. */
export function b64(bytes) {
  let text = '';
  for (const byte of bytes) text += String.fromCharCode(byte);
  return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** Gegenstueck zu b64; wirft bei Unsinn. */
export function unb64(text) {
  const clean = text.replace(/=+$/, '');
  if (!/^[A-Za-z0-9_-]*$/.test(clean) || clean.length % 4 === 1) {
    throw new Error('kein base64url');
  }
  const padded = clean.replace(/-/g, '+').replace(/_/g, '/') +
    '='.repeat((4 - (clean.length % 4)) % 4);
  const raw = atob(padded);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes;
}

/** Neue ID wie newId() in Dart: 16 Zufallsbytes. */
export function newId() {
  return b64(globalThis.crypto.getRandomValues(new Uint8Array(16)));
}

/** Leerzeichen und Bindestriche beim Eintippen zaehlen nicht. */
export function normalizeCode(code) {
  return (code || '').replace(/[\s-]/g, '');
}

async function derive(ikm, listId, info) {
  const key = await subtle().importKey('raw', ikm, 'HKDF', false, ['deriveBits']);
  const bits = await subtle().deriveBits(
    { name: 'HKDF', hash: 'SHA-256', salt: enc.encode(listId), info: enc.encode(info) },
    key, 256);
  return new Uint8Array(bits);
}

/** K als rohe Bytes. */
export function listKeyBytes(listId, secret) {
  return derive(secret, listId, 'joe-v1-key');
}

/** K als CryptoKey fuer AES-GCM. */
export async function listKey(listId, secret) {
  return subtle().importKey('raw', await listKeyBytes(listId, secret), 'AES-GCM',
    false, ['encrypt', 'decrypt']);
}

/** A als base64url. */
export async function accessToken(listId, secret, code) {
  const ikm = new Uint8Array([...secret, ...enc.encode(normalizeCode(code))]);
  return b64(await derive(ikm, listId, 'joe-v1-access'));
}

function aad(listId, opId) {
  return enc.encode(`${listId}:${opId}`);
}

/** Verschluesselt den Klartext einer Operation. */
export async function seal(key, listId, opId, body, nonce) {
  const iv = nonce || globalThis.crypto.getRandomValues(new Uint8Array(12));
  const sealed = new Uint8Array(await subtle().encrypt(
    { name: 'AES-GCM', iv, additionalData: aad(listId, opId) },
    key, enc.encode(JSON.stringify(body))));
  const out = new Uint8Array(iv.length + sealed.length);
  out.set(iv);
  out.set(sealed, iv.length);
  return b64(out);
}

/** Entschluesselt einen Block; wirft, wenn er nicht passt. */
export async function open(key, listId, opId, blob) {
  const bytes = unb64(blob);
  if (bytes.length < 12 + 16) throw new Error('zu kurz');
  const clear = await subtle().decrypt(
    { name: 'AES-GCM', iv: bytes.slice(0, 12), additionalData: aad(listId, opId) },
    key, bytes.slice(12));
  const body = JSON.parse(dec.decode(clear));
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw new Error('kein Objekt');
  }
  return body;
}
