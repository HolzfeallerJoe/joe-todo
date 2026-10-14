// Dieselben Faelle wie packages/joe_sync/test/merge_test.dart.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { SharedListState, ops, parseOp, sortedItems, toBody } from '../merge.js';
import { mergeCases } from '../support/vectors.mjs';

function replay(raw, now) {
  const state = new SharedListState();
  for (const entry of raw) {
    let op;
    try {
      op = parseOp(entry.id, entry.op);
    } catch {
      continue;
    }
    state.apply(op, new Date(entry.at));
  }
  if (now) state.advance(new Date(now));
  return state;
}

function summary(state) {
  return {
    name: state.nameValue,
    items: state.visibleItems.map((item) => ({
      id: item.id, title: item.title.value, done: item.done.value,
    })),
    conflicts: [...state.conflicts.values()].map((c) => ({
      id: c.id, kind: c.kind, item: c.item, field: c.field, value: c.value, device: c.device,
    })),
  };
}

for (const c of mergeCases) {
  test(c.name, () => {
    assert.deepEqual(summary(replay(c.ops, c.now)), c.expect);
  });
}

test('base zeigt auf die letzte, auch lokale Aenderung; Klartext hin und zurueck', () => {
  const view = new SharedListState();
  const created = new Date('2026-10-14T08:00:00.000Z');
  view.apply(ops.add('a1', 'A', 'i1', 'Milch', created));
  const first = ops.title('b1', 'B', view, 'i1', 'Hafer');
  assert.deepEqual(first.base, { title: 'a1', done: 'a1', deleted: 'a1' });
  view.apply(first);
  const second = ops.title('b2', 'B', view, 'i1', 'Hafermilch');
  assert.equal(second.base.title, 'b1');
  const back = parseOp('b2', JSON.parse(JSON.stringify(toBody(second))));
  assert.deepEqual(toBody(back), toBody(second));
  view.apply(back);
  assert.equal(view.items.get('i1').title.value, 'Hafermilch');
  assert.equal(view.conflicts.size, 0);
});

test('clone ist unabhaengig', () => {
  const state = new SharedListState();
  state.apply(ops.add('a1', 'A', 'i1', 'Milch', new Date()));
  const copy = state.clone();
  copy.apply(ops.done('a2', 'A', copy, 'i1', true));
  assert.equal(state.items.get('i1').done.value, false);
  assert.equal(copy.items.get('i1').done.value, true);
});

test('Reihenfolge wie in Joe', () => {
  const state = new SharedListState();
  const t = (m) => new Date(Date.UTC(2026, 9, 14, 8, m));
  state.apply(ops.add('a1', 'A', 'i1', 'Milch', t(2)));
  state.apply(ops.add('a2', 'A', 'i2', 'Brot', t(1)));
  state.apply(ops.add('a3', 'A', 'i3', 'Kaese', t(3)));
  state.apply(ops.done('a4', 'A', state, 'i2', true));
  assert.deepEqual(sortedItems(state).map((i) => i.title.value), ['Milch', 'Kaese', 'Brot']);
});
