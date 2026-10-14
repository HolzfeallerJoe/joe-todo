// Operationen und Zusammenfuehrung, JS-Fassung von
// packages/joe_sync/lib/src/op.dart und merge.dart. Beide pruefen dieselben
// Faelle (packages/joe_sync/test/vectors/merge.json); wer hier etwas
// aendert, aendert es dort mit.

export const OP_VERSION = 1;
export const MAX_TEXT = 500;
const CONFLICT_LIFETIME_MS = 30 * 24 * 60 * 60 * 1000;
const TYPES = new Set(['list.name', 'item.add', 'item.title', 'item.done',
  'item.delete', 'conflict.resolve']);

export class UnsupportedOp extends Error {}

/** Liest einen Klartext wie Op.fromBody; wirft bei Unsinn. */
export function parseOp(id, body) {
  if (!Number.isInteger(body.v)) throw new Error('v fehlt');
  if (body.v > OP_VERSION || !TYPES.has(body.op)) throw new UnsupportedOp();
  const text = (key, required = false) => {
    const value = body[key];
    if ((value === undefined || value === null) && !required) return null;
    if (typeof value !== 'string' || value.length > MAX_TEXT) {
      throw new Error(`${key} ungueltig`);
    }
    return value;
  };
  const device = text('device', true);
  const base = {};
  if (body.base !== undefined && body.base !== null) {
    if (typeof body.base !== 'object' || Array.isArray(body.base)) {
      throw new Error('base ungueltig');
    }
    for (const [key, value] of Object.entries(body.base)) {
      if (typeof value === 'string') base[key] = value;
    }
  }
  const done = body.done === undefined ? null : body.done;
  if (done !== null && typeof done !== 'boolean') throw new Error('done ungueltig');
  const created = text('createdAt');
  let createdAt = null;
  if (created !== null) {
    createdAt = new Date(created);
    if (Number.isNaN(createdAt.getTime())) throw new Error('createdAt ungueltig');
  }
  const keep = text('keep');
  const op = {
    id, type: body.op, device, base,
    item: text('item'), title: text('title'), done, name: text('name'),
    createdAt, conflict: text('conflict'),
    keepMine: keep === null ? null : keep === 'mine',
  };
  const ok = {
    'list.name': op.name !== null,
    'item.add': op.item !== null && op.title !== null && op.createdAt !== null,
    'item.title': op.item !== null && op.title !== null,
    'item.done': op.item !== null && op.done !== null,
    'item.delete': op.item !== null,
    'conflict.resolve': op.conflict !== null && op.keepMine !== null,
  }[op.type];
  if (!ok) throw new Error(`${op.type} unvollstaendig`);
  return op;
}

/** Der Klartext zum Verschluesseln, wie Op.toBody. */
export function toBody(op) {
  const body = { v: OP_VERSION, op: op.type, device: op.device };
  if (op.item != null) body.item = op.item;
  if (op.title != null) body.title = op.title;
  if (op.done != null) body.done = op.done;
  if (op.name != null) body.name = op.name;
  if (op.createdAt != null) body.createdAt = op.createdAt.toISOString();
  if (op.conflict != null) body.conflict = op.conflict;
  if (op.keepMine != null) body.keep = op.keepMine ? 'mine' : 'theirs';
  if (op.base && Object.keys(op.base).length > 0) body.base = op.base;
  return body;
}

const cap = (text) => (text.length > MAX_TEXT ? text.slice(0, MAX_TEXT) : text);

/** Operationen aus dem sichtbaren Stand bauen, wie die Fabriken in Op. */
export const ops = {
  rename: (id, device, view, name) => ({
    id, type: 'list.name', device, name: cap(name),
    base: view.name ? { name: view.name.setter } : {},
  }),
  add: (id, device, item, title, createdAt) => ({
    id, type: 'item.add', device, item, title: cap(title), done: false,
    createdAt, base: {},
  }),
  title: (id, device, view, item, title) => ({
    id, type: 'item.title', device, item, title: cap(title), base: view.baseOf(item),
  }),
  done: (id, device, view, item, done) => ({
    id, type: 'item.done', device, item, done, base: view.baseOf(item),
  }),
  remove: (id, device, view, item) => ({
    id, type: 'item.delete', device, item, base: view.baseOf(item),
  }),
  resolve: (id, device, conflict, keepMine) => ({
    id, type: 'conflict.resolve', device, conflict, keepMine, base: {},
  }),
};

function field(value, setter) {
  return { value, setter, seen: [setter] };
}

function setField(f, value, opId) {
  f.value = value;
  f.setter = opId;
  f.seen = [opId];
}

function absorb(f, opId) {
  if (!f.seen.includes(opId)) f.seen.push(opId);
}

/** Wie SharedListState: Schritt fuer Schritt ueber apply. */
export class SharedListState {
  constructor() {
    this.name = null;
    this.items = new Map();
    this.conflicts = new Map();
    this.clock = null;
  }

  clone() {
    const copy = new SharedListState();
    copy.name = this.name ? structuredClone(this.name) : null;
    for (const [id, item] of this.items) copy.items.set(id, structuredClone(item));
    for (const [id, c] of this.conflicts) copy.conflicts.set(id, structuredClone(c));
    copy.clock = this.clock;
    return copy;
  }

  get nameValue() {
    return this.name ? this.name.value : null;
  }

  get visibleItems() {
    return [...this.items.values()].filter((item) => item.deleted.value !== true);
  }

  baseOf(itemId) {
    const item = this.items.get(itemId);
    if (!item) return {};
    return { title: item.title.setter, done: item.done.setter, deleted: item.deleted.setter };
  }

  conflictsOf(itemId) {
    return [...this.conflicts.values()].filter((c) => c.item === itemId);
  }

  /** at: Serverzeit (Date) oder null fuer lokale Operationen. */
  apply(op, at = null) {
    if (at) this.advance(at);
    switch (op.type) {
      case 'list.name': return this.#name(op, at);
      case 'item.add': return this.#add(op);
      case 'item.title': return this.#title(op, at);
      case 'item.done': return this.#done(op, at);
      case 'item.delete': return this.#delete(op, at);
      case 'conflict.resolve': return this.#resolve(op);
    }
  }

  advance(now) {
    if (this.clock === null || now.getTime() > this.clock.getTime()) this.clock = now;
    const limit = this.clock.getTime() - CONFLICT_LIFETIME_MS;
    for (const [id, c] of this.conflicts) {
      if (c.at !== null && c.at.getTime() <= limit) this.conflicts.delete(id);
    }
  }

  #name(op, at) {
    if (this.name === null) {
      this.name = field(op.name, op.id);
      return;
    }
    this.#change(op, at, null, 'name', this.name, op.name);
  }

  #add(op) {
    if (this.items.has(op.item)) return;
    this.items.set(op.item, {
      id: op.item,
      createdAt: op.createdAt,
      title: field(op.title, op.id),
      done: field(op.done ?? false, op.id),
      deleted: field(false, op.id),
    });
  }

  #title(op, at) {
    const item = this.items.get(op.item);
    if (!item) return;
    if (item.deleted.value !== true) {
      this.#change(op, at, item.id, 'title', item.title, op.title);
      return;
    }
    if (item.deleted.seen.includes(op.base.deleted)) return;
    const chained = this.#chained(item.id, 'title', op.base.title);
    if (chained) {
      chained.value = op.title;
      chained.chain.push(op.id);
      return;
    }
    this.#dropOwn(op.device, item.id, 'title');
    this.#open(op, at, 'deleted', item.id, 'title', op.title);
  }

  #done(op, at) {
    const item = this.items.get(op.item);
    if (!item || item.deleted.value === true) return;
    this.#change(op, at, item.id, 'done', item.done, op.done);
  }

  #delete(op, at) {
    const item = this.items.get(op.item);
    if (!item) return;
    if (item.deleted.value === true) {
      absorb(item.deleted, op.id);
      this.#dropOwn(op.device, item.id, 'deleted');
      return;
    }
    if (item.title.seen.includes(op.base.title)) {
      setField(item.deleted, true, op.id);
      this.#dropAll(item.id);
      return;
    }
    for (const [id, c] of this.conflicts) {
      if (c.device === op.device && c.item === item.id) this.conflicts.delete(id);
    }
    this.#open(op, at, 'edited', item.id, 'deleted', true);
  }

  #resolve(op) {
    const conflict = this.conflicts.get(op.conflict);
    if (!conflict) return;
    this.conflicts.delete(op.conflict);
    if (op.keepMine !== true) return;
    if (conflict.item === null) {
      this.#set(null, 'name', this.name, conflict.value, op.id);
      return;
    }
    const item = this.items.get(conflict.item);
    switch (conflict.kind) {
      case 'field':
        this.#set(item.id, conflict.field, item[conflict.field], conflict.value, op.id);
        break;
      case 'deleted':
        setField(item.deleted, false, op.id);
        this.#set(item.id, 'title', item.title, conflict.value, op.id);
        for (const [id, c] of this.conflicts) {
          if (c.item === item.id && c.kind === 'deleted') this.conflicts.delete(id);
        }
        break;
      case 'edited':
        setField(item.deleted, true, op.id);
        this.#dropAll(item.id);
        break;
    }
  }

  #change(op, at, itemId, fieldName, f, value) {
    if (value === f.value) {
      absorb(f, op.id);
      this.#dropOwn(op.device, itemId, fieldName);
      return;
    }
    if (f.seen.includes(op.base[fieldName])) {
      this.#set(itemId, fieldName, f, value, op.id);
      this.#dropOwn(op.device, itemId, fieldName);
      return;
    }
    const chained = this.#chained(itemId, fieldName, op.base[fieldName]);
    if (chained) {
      chained.value = value;
      chained.chain.push(op.id);
      return;
    }
    this.#dropOwn(op.device, itemId, fieldName);
    this.#open(op, at, 'field', itemId, fieldName, value);
  }

  #set(itemId, fieldName, f, value, opId) {
    setField(f, value, opId);
    for (const [id, c] of this.conflicts) {
      if (c.kind === 'field' && c.item === itemId && c.field === fieldName &&
          c.value === value) {
        this.conflicts.delete(id);
      }
    }
  }

  #open(op, at, kind, itemId, fieldName, value) {
    this.conflicts.set(op.id, {
      id: op.id, kind, item: itemId, field: fieldName, value,
      device: op.device, at, chain: [op.id],
    });
  }

  #chained(itemId, fieldName, base) {
    if (base === undefined || base === null) return null;
    for (const c of this.conflicts.values()) {
      if (c.item === itemId && c.field === fieldName && c.chain.includes(base)) return c;
    }
    return null;
  }

  #dropOwn(device, itemId, fieldName) {
    for (const [id, c] of this.conflicts) {
      if (c.device === device && c.item === itemId && c.field === fieldName) {
        this.conflicts.delete(id);
      }
    }
  }

  #dropAll(itemId) {
    for (const [id, c] of this.conflicts) {
      if (c.item === itemId) this.conflicts.delete(id);
    }
  }
}

/** Anzeigereihenfolge wie in Joe: offene zuerst, darin aelteste oben. */
export function sortedItems(view) {
  return view.visibleItems
    .map((item, index) => ({ item, index }))
    .sort((a, b) => {
      const done = (a.item.done.value ? 1 : 0) - (b.item.done.value ? 1 : 0);
      if (done !== 0) return done;
      const time = a.item.createdAt.getTime() - b.item.createdAt.getTime();
      if (time !== 0) return time;
      return a.index - b.index;
    })
    .map((entry) => entry.item);
}
