// Dieselben Testvektoren wie packages/joe_sync/test/crypto_test.dart.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { accessToken, b64, listKey, listKeyBytes, open, seal, unb64 } from '../crypto.js';
import { cryptoCases } from '../support/vectors.mjs';

for (const v of cryptoCases) {
  test(`Testvektor ${v.listId}`, async () => {
    const secret = unb64(v.secret);
    assert.equal(b64(await listKeyBytes(v.listId, secret)), v.key);
    assert.equal(await accessToken(v.listId, secret, v.code), v.accessToken);
    const key = await listKey(v.listId, secret);
    const body = JSON.parse(v.plain);
    assert.equal(await seal(key, v.listId, v.opId, body, unb64(v.nonce)), v.blob);
    assert.deepEqual(await open(key, v.listId, v.opId, v.blob), body);
  });
}

test('fremde ID oder veraendertes Byte schlagen fehl', async () => {
  const v = cryptoCases[0];
  const key = await listKey(v.listId, unb64(v.secret));
  await assert.rejects(open(key, v.listId, 'andere-id', v.blob));
  const bytes = unb64(v.blob);
  bytes[20] ^= 1;
  await assert.rejects(open(key, v.listId, v.opId, b64(bytes)));
});

test('Code: Leerzeichen und Bindestriche zaehlen nicht', async () => {
  const v = cryptoCases[1];
  const secret = unb64(v.secret);
  const spaced = v.code.slice(0, 3) + ' - ' + v.code.slice(3);
  assert.equal(await accessToken(v.listId, secret, spaced), v.accessToken);
});
