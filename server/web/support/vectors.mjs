import { readFileSync } from 'node:fs';

const dir = new URL('../../../packages/joe_sync/test/vectors/', import.meta.url);

export const cryptoCases = JSON.parse(readFileSync(new URL('crypto.json', dir), 'utf8')).cases;
export const mergeCases = JSON.parse(readFileSync(new URL('merge.json', dir), 'utf8')).cases;
