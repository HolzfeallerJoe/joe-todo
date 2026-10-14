// Die Webseite einer geteilten Liste (Konzept 7.2): fuer alle ohne Joe.
//
// Ablauf: Geheimnis aus dem # lesen, meta fragen, bei Bedarf den Code,
// Schluessel ableiten, Operationen laden, Liste zeigen. Aenderungen gehen
// als verschluesselte Operationen hoch; abgeglichen wird alle 10 Sekunden,
// solange der Tab sichtbar ist. Die Seite speichert nichts dauerhaft.
//
// Inhalte kommen nur ueber textContent ins DOM, nie als HTML.

import { accessToken, listKey, newId, normalizeCode, open, seal, unb64 } from './crypto.js';
import { SharedListState, ops, parseOp, sortedItems, toBody } from './merge.js';

const SYNC_EVERY_MS = 10_000;
const AFTER_CHANGE_MS = 1_000;
const MAX_OPS = 500;

const $ = (id) => document.getElementById(id);

const share = {
  listId: null,
  secret: null,
  key: null,
  token: null,
  // Ein Tab ist ein Geraet. Konflikte, die er ausloest, beantwortet er
  // selbst; schliesst er vorher, bleiben sie offen und verfallen (5.4).
  device: 'web-' + newId(),
  confirmed: new SharedListState(),
  lastSeq: 0,
  epoch: null,
  outbox: [],
  acked: new Set(),
  view: null,
  lastSync: null,
  problem: null,
  stopped: false,
  syncing: null,
  timer: null,
  soon: null,
};

// ------------------------------------------------------------------ Start

function parseLocation() {
  const match = location.pathname.match(/\/l\/([A-Za-z0-9_-]{22})\/?$/);
  const secret = location.hash.replace(/^#/, '');
  if (!match || !/^[A-Za-z0-9_-]{43}$/.test(secret)) return null;
  const bytes = unb64(secret);
  if (bytes.length !== 32) return null;
  return { listId: match[1], secret: bytes };
}

function api(path) {
  // Relativ zur Seite (/l/<id>), damit ein Server unter einem Unterpfad
  // genauso geht.
  return new URL(`../api/lists/${share.listId}${path}`, location.href);
}

async function request(method, path, json) {
  const headers = {};
  if (share.token) headers.authorization = `Bearer ${share.token}`;
  if (json !== undefined) headers['content-type'] = 'application/json';
  let response;
  try {
    response = await fetch(api(path), {
      method,
      headers,
      body: json === undefined ? undefined : JSON.stringify(json),
      cache: 'no-store',
      credentials: 'omit',
      referrerPolicy: 'no-referrer',
    });
  } catch {
    return { status: 0, body: {} };
  }
  let body = {};
  try {
    body = await response.json();
  } catch {
    // Kein JSON (Proxy-Fehlerseite): nur der Status zaehlt.
  }
  return { status: response.status, body };
}

function gate(text, { big = false } = {}) {
  $('gate').hidden = false;
  $('list').hidden = true;
  $('gate-text').textContent = text;
  $('gate-text').classList.toggle('big', big);
}

function goneText(reason) {
  return reason === 'expired'
    ? 'Diese Liste wird nicht mehr geteilt. Sie war lange nicht in Benutzung.'
    : 'Diese Liste wurde von der Person, die sie geteilt hat, gelöscht.';
}

async function start() {
  if (!globalThis.crypto || !globalThis.crypto.subtle) {
    // WebCrypto gibt es nur in einem sicheren Kontext: https:// oder
    // localhost. Ueber http://<Adresse> (etwa 10.0.2.2 im Emulator) fehlt es.
    gate(location.protocol === 'http:'
      ? 'Über http:// kann der Browser die Liste nicht entschlüsseln. Bitte die Seite über https:// öffnen – oder beim Ausprobieren über localhost.'
      : 'Dieser Browser kann die Liste nicht entschlüsseln. Bitte einen aktuellen Browser nehmen.', { big: true });
    return;
  }
  const parsed = parseLocation();
  if (!parsed) {
    gate('Der Link ist unvollständig. Bitte den ganzen Link öffnen, mit dem Teil hinter dem #.', { big: true });
    return;
  }
  share.listId = parsed.listId;
  share.secret = parsed.secret;

  const meta = await request('GET', '/meta');
  if (meta.status === 0) {
    gate('Der Server ist gerade nicht erreichbar. Später noch einmal versuchen.', { big: true });
    return;
  }
  if (meta.status === 404) {
    gate('Diese Liste gibt es nicht (mehr).', { big: true });
    return;
  }
  if (meta.status === 410) {
    gate(goneText(meta.body.reason), { big: true });
    return;
  }
  if (meta.status !== 200) {
    gate('Etwas ist schiefgegangen. Später noch einmal versuchen.', { big: true });
    return;
  }
  share.key = await listKey(share.listId, share.secret);
  if (meta.body.code) {
    askCode();
  } else {
    await enter(null);
  }
}

function askCode(message) {
  gate('');
  $('gate-text').hidden = true;
  $('code-form').hidden = false;
  $('code-error').hidden = !message;
  $('code-error').textContent = message || '';
  $('code-input').focus();
}

$('code-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const code = normalizeCode($('code-input').value);
  if (!/^\d{4,12}$/.test(code)) {
    askCode('Bitte die Ziffern des Codes eingeben.');
    return;
  }
  await enter(code);
});

async function enter(code) {
  share.token = await accessToken(share.listId, share.secret, code);
  const result = await fetchOps();
  if (result === 401) {
    if (code === null) {
      gate('Der Link passt nicht zu dieser Liste.', { big: true });
    } else {
      $('code-input').value = '';
      askCode('Der Code stimmt nicht.');
    }
    return;
  }
  if (result === 429) {
    askCode('Zu viele Versuche. Bitte in einer Stunde noch einmal.');
    return;
  }
  if (result !== 200) {
    if (share.stopped) return;
    gate('Die Liste ließ sich gerade nicht laden. Später noch einmal versuchen.', { big: true });
    return;
  }
  $('gate').hidden = true;
  $('list').hidden = false;
  render();
  schedule();
}

// --------------------------------------------------------------- Abgleich

function view() {
  if (!share.view) {
    const v = share.confirmed.clone();
    for (const op of share.outbox) v.apply(op);
    share.view = v;
  }
  return share.view;
}

function record(op) {
  share.outbox.push(op);
  view().apply(op);
  render();
  clearTimeout(share.soon);
  share.soon = setTimeout(sync, AFTER_CHANGE_MS);
}

/** Laedt die Warteschlange hoch. Status 200 oder der Fehlerstatus. */
async function upload() {
  const pending = share.outbox.filter((op) => !share.acked.has(op.id));
  for (let i = 0; i < pending.length; i += MAX_OPS) {
    const chunk = pending.slice(i, i + MAX_OPS);
    const sealed = [];
    for (const op of chunk) {
      sealed.push({ id: op.id, blob: await seal(share.key, share.listId, op.id, toBody(op)) });
    }
    const reply = await request('POST', '/ops', { ops: sealed });
    if (reply.status !== 200) return reply;
    for (const op of chunk) share.acked.add(op.id);
  }
  return { status: 200, body: {} };
}

/** Holt alles Neue; liefert den Status (200 bei Erfolg). */
async function fetchOps() {
  let rebased = null;
  for (;;) {
    const reply = await request('GET', `/ops?after=${share.lastSeq}`);
    if (reply.status !== 200) return handleProblem(reply);
    const body = reply.body;
    // Neue Epoche oder weniger als gelesen: der Server hat die Liste
    // verloren oder ein Backup eingespielt. Neu aufbauen, dann nachreichen,
    // was hier bekannt war (wie im Dart-Client).
    if (rebased === null && share.lastSeq > 0 &&
        (body.epoch !== share.epoch || (body.head ?? 0) < share.lastSeq)) {
      rebased = view();
      share.confirmed = new SharedListState();
      share.lastSeq = 0;
      share.outbox = [];
      share.acked = new Set();
      share.view = null;
      share.epoch = body.epoch;
      continue;
    }
    share.epoch = body.epoch;
    for (const wire of body.ops || []) {
      try {
        const clear = await open(share.key, share.listId, wire.id, wire.blob);
        share.confirmed.apply(parseOp(wire.id, clear), new Date(wire.at));
      } catch {
        // Nicht lesbar (neuere Version, kaputt): ueberspringen.
      }
      share.lastSeq = wire.seq;
      share.acked.delete(wire.id);
      share.outbox = share.outbox.filter((op) => op.id !== wire.id);
    }
    if (body.now) share.confirmed.advance(new Date(body.now));
    share.view = null;
    if (!body.more) break;
  }
  if (rebased) restore(rebased);
  share.problem = null;
  share.lastSync = new Date();
  return 200;
}

function restore(old) {
  const current = view();
  if (current.name === null && old.nameValue !== null) {
    share.outbox.push(ops.rename(newId(), share.device, current, old.nameValue));
  }
  for (const item of old.visibleItems) {
    if (current.items.has(item.id)) continue;
    share.outbox.push({
      id: newId(), type: 'item.add', device: share.device, item: item.id,
      title: item.title.value, done: item.done.value, createdAt: item.createdAt, base: {},
    });
  }
  share.view = null;
}

function handleProblem(reply) {
  switch (reply.status) {
    case 0:
    case 502:
    case 503:
    case 504:
      share.problem = 'offline';
      break;
    case 401:
      share.problem = 'unauthorized';
      break;
    case 404:
      // Joe legt eine verlorene Liste neu an (Konzept 6.4); bis dahin warten.
      share.problem = 'missing';
      break;
    case 410:
      share.stopped = true;
      gate(goneText(reply.body.reason), { big: true });
      break;
    case 429:
      share.problem = 'limited';
      break;
    default:
      share.problem = 'failed';
  }
  return reply.status;
}

async function sync() {
  if (share.stopped || !share.token) return;
  if (share.syncing) return share.syncing;
  share.syncing = (async () => {
    const up = await upload();
    if (up.status !== 200) {
      handleProblem(up);
    } else {
      await fetchOps();
      // Was der Neuaufbau nachgereicht hat, gleich hinterher.
      if (share.outbox.some((op) => !share.acked.has(op.id)) && !share.problem) {
        const again = await upload();
        if (again.status === 200) await fetchOps();
      }
    }
    if (!share.stopped) render();
  })().finally(() => {
    share.syncing = null;
  });
  return share.syncing;
}

function schedule() {
  clearInterval(share.timer);
  share.timer = setInterval(() => {
    if (document.visibilityState === 'visible') sync();
  }, SYNC_EVERY_MS);
}

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') sync();
});

window.addEventListener('online', () => sync());

window.addEventListener('beforeunload', (event) => {
  if (!share.stopped && share.outbox.some((op) => !share.acked.has(op.id))) {
    event.preventDefault();
  }
});

// ---------------------------------------------------------------- Anzeige

let editing = null;

function ago(date) {
  const seconds = Math.round((Date.now() - date.getTime()) / 1000);
  if (seconds < 60) return 'gerade eben';
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `vor ${minutes} Min.`;
  return `um ${date.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })} Uhr`;
}

function statusText(v) {
  const mine = [...v.conflicts.values()].filter((c) => c.device === share.device).length;
  const unsent = share.outbox.filter((op) => !share.acked.has(op.id)).length;
  const parts = [];
  switch (share.problem) {
    case 'offline':
      parts.push(unsent > 0 ? 'Offline – Änderungen gehen raus, sobald es wieder geht' : 'Offline');
      break;
    case 'unauthorized':
      parts.push('Kein Zugriff mehr – wurde der Link erneuert?');
      break;
    case 'missing':
      parts.push('Liste auf dem Server gerade nicht gefunden');
      break;
    case 'limited':
      parts.push('Gebremst – später geht es weiter');
      break;
    case 'failed':
      parts.push('Abgleich gerade nicht möglich');
      break;
    default:
      if (share.lastSync) parts.push(`Abgeglichen ${ago(share.lastSync)}`);
  }
  if (mine > 0) parts.push(mine === 1 ? '1 Konflikt zu klären' : `${mine} Konflikte zu klären`);
  return { text: parts.join(' · '), warn: share.problem !== null || mine > 0 };
}

function render() {
  const v = view();
  const name = v.nameValue || 'Geteilte Liste';
  document.title = `${name} · Joe`;
  $('list-name').textContent = name;
  const nameConflict = v.conflictsOf(null).find((c) => c.device === share.device);
  $('rename').textContent = nameConflict ? '!' : '✎';
  $('rename').setAttribute('aria-label', nameConflict ? 'Konflikt beim Namen klären' : 'Liste umbenennen');

  const status = statusText(v);
  $('status').textContent = status.text;
  $('status').classList.toggle('warn', status.warn);

  const list = $('items');
  const items = sortedItems(v);
  list.replaceChildren(...items.map((item) => row(v, item)));
  $('empty').hidden = items.length > 0;
}

function row(v, item) {
  const li = document.createElement('li');
  li.className = 'item' + (item.done.value ? ' done' : '');

  const check = document.createElement('input');
  check.type = 'checkbox';
  check.className = 'check';
  check.checked = item.done.value === true;
  check.setAttribute('aria-label', `${item.title.value} abhaken`);
  check.addEventListener('change', () => {
    record(ops.done(newId(), share.device, view(), item.id, check.checked));
  });
  li.append(check);

  if (editing === item.id) {
    li.append(editForm(item));
  } else {
    const title = document.createElement('button');
    title.type = 'button';
    title.className = 'title';
    title.textContent = item.title.value;
    title.title = 'Ändern';
    title.addEventListener('click', () => {
      editing = item.id;
      render();
    });
    li.append(title);
  }

  const conflicts = v.conflictsOf(item.id);
  const mine = conflicts.find((c) => c.device === share.device);
  if (mine) {
    const badge = document.createElement('button');
    badge.type = 'button';
    badge.className = 'badge';
    badge.textContent = 'Klären';
    badge.addEventListener('click', () => resolve(mine));
    li.append(badge);
  } else if (conflicts.length > 0) {
    const badge = document.createElement('span');
    badge.className = 'badge';
    badge.textContent = 'wird geklärt';
    li.append(badge);
  }

  const remove = document.createElement('button');
  remove.type = 'button';
  remove.className = 'icon-button';
  remove.textContent = '✕';
  remove.setAttribute('aria-label', `${item.title.value} löschen`);
  remove.addEventListener('click', async () => {
    const answer = await ask(`„${item.title.value}“ löschen?`, 'Löschen', 'Abbrechen');
    if (answer === 'first') record(ops.remove(newId(), share.device, view(), item.id));
  });
  li.append(remove);
  return li;
}

function editForm(item) {
  const form = document.createElement('form');
  form.className = 'edit-form';
  const input = document.createElement('input');
  input.value = item.title.value;
  input.maxLength = 500;
  input.setAttribute('aria-label', 'Eintrag ändern');
  form.append(input);
  let done = false;
  const finish = (save) => {
    if (done) return;
    done = true;
    editing = null;
    const title = input.value.trim();
    if (save && title && title !== item.title.value) {
      record(ops.title(newId(), share.device, view(), item.id, title));
    } else {
      render();
    }
  };
  form.addEventListener('submit', (event) => {
    event.preventDefault();
    finish(true);
  });
  input.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') finish(false);
  });
  input.addEventListener('blur', () => finish(true));
  queueMicrotask(() => {
    input.focus();
    input.select();
  });
  return form;
}

$('add-form').addEventListener('submit', (event) => {
  event.preventDefault();
  const input = $('add-input');
  const title = input.value.trim();
  if (!title) return;
  input.value = '';
  record(ops.add(newId(), share.device, newId(), title, new Date()));
  input.focus();
});

$('rename').addEventListener('click', () => {
  const conflict = view().conflictsOf(null).find((c) => c.device === share.device);
  if (conflict) {
    resolve(conflict);
    return;
  }
  $('rename-form').hidden = false;
  $('rename-input').value = view().nameValue || '';
  $('rename-input').focus();
});

$('rename-form').addEventListener('submit', (event) => {
  event.preventDefault();
  const name = $('rename-input').value.trim();
  $('rename-form').hidden = true;
  if (name && name !== view().nameValue) {
    record(ops.rename(newId(), share.device, view(), name));
  }
});

$('rename-cancel').addEventListener('click', () => {
  $('rename-form').hidden = true;
});

// ------------------------------------------------------- Rueckfragen

function ask(text, first, second) {
  const dialog = $('dialog');
  $('dialog-text').textContent = text;
  $('dialog-first').textContent = first;
  $('dialog-second').textContent = second;
  return new Promise((resolveAnswer) => {
    dialog.addEventListener('close', () => resolveAnswer(dialog.returnValue), { once: true });
    dialog.returnValue = '';
    dialog.showModal();
  });
}

/** Die Fragen aus Konzept 5.4, je nach Art des Konflikts. */
async function resolve(conflict) {
  const v = view();
  const item = conflict.item === null ? null : v.items.get(conflict.item);
  let text;
  let mine;
  let theirs;
  if (conflict.kind === 'deleted') {
    text = `Jemand hat „${item.title.value}“ gelöscht, du hattest den Eintrag in „${conflict.value}“ geändert.`;
    mine = 'Mit meiner Änderung behalten';
    theirs = 'Löschen lassen';
  } else if (conflict.kind === 'edited') {
    text = `„${item.title.value}“ wurde inzwischen geändert. Trotzdem löschen?`;
    mine = 'Löschen';
    theirs = 'Behalten';
  } else if (conflict.field === 'done') {
    const now = item.done.value ? 'abgehakt' : 'offen';
    const wanted = conflict.value ? 'abgehakt' : 'offen';
    text = `„${item.title.value}“ ist inzwischen ${now}, du wolltest ihn ${wanted}.`;
    mine = `Meins: ${wanted}`;
    theirs = `Das andere: ${now}`;
  } else {
    const current = conflict.item === null ? v.nameValue : item.title.value;
    text = `„${conflict.value}“ (von dir) oder „${current}“ (inzwischen von jemand anderem)?`;
    mine = 'Meins';
    theirs = 'Das andere';
  }
  const answer = await ask(text, mine, theirs);
  if (answer === 'first' || answer === 'second') {
    record(ops.resolve(newId(), share.device, conflict.id, answer === 'first'));
  }
}

setInterval(() => {
  // „Abgeglichen vor …“ altert auch ohne Abgleich.
  if (!share.stopped && !$('list').hidden && document.visibilityState === 'visible') {
    const status = statusText(view());
    $('status').textContent = status.text;
  }
}, 30_000);

start();
