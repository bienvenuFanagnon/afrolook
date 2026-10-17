'use strict';
// Firestore factice en mémoire : juste ce qu'utilisent les tâches (get, set avec fusion, requêtes simples, lots, transactions).

function deepMerge(a, b) {
  const out = Object.assign({}, a);
  for (const [k, v] of Object.entries(b)) {
    if (v && typeof v === 'object' && !Array.isArray(v) && a && a[k] && typeof a[k] === 'object' && !Array.isArray(a[k])) out[k] = deepMerge(a[k], v);
    else out[k] = v && typeof v === 'object' && v.__inc != null ? (typeof a[k] === 'number' ? a[k] : 0) + v.__inc : v; // FieldValue.increment
  }
  return out;
}
const clone = (x) => (x === undefined ? undefined : JSON.parse(JSON.stringify(x)));
const getPath = (o, p) => p.split('.').reduce((x, k) => (x == null ? undefined : x[k]), o);

class Doc {
  constructor(db, col, id) { this.db = db; this.col = col; this.id = id; this.ref = this; }
  get path() { return `${this.col}/${this.id}`; }
  async get() {
    const d = this.db.data.get(this.col) && this.db.data.get(this.col).get(this.id);
    return { id: this.id, exists: d !== undefined, data: () => clone(d), ref: this };
  }
  async set(data, opts) {
    if (!this.db.data.has(this.col)) this.db.data.set(this.col, new Map());
    const m = this.db.data.get(this.col);
    m.set(this.id, opts && opts.merge ? deepMerge(m.get(this.id) || {}, clone(data)) : clone(data));
    this.db.writes++;
  }
  async update(data) {
    const m = this.db.data.get(this.col);
    if (!m || !m.has(this.id)) throw Object.assign(new Error('NOT_FOUND'), { code: 5 });
    const cur = m.get(this.id);
    for (const [k, v] of Object.entries(clone(data))) {
      const parts = k.split('.');
      let o = cur;
      for (let i = 0; i < parts.length - 1; i++) { o[parts[i]] = o[parts[i]] || {}; o = o[parts[i]]; }
      const last = parts[parts.length - 1];
      o[last] = v && typeof v === 'object' && v.__inc != null ? (o[last] || 0) + v.__inc : v;
    }
    this.db.writes++;
  }
  async delete() { this.db.data.get(this.col) && this.db.data.get(this.col).delete(this.id); }
}

class Query {
  constructor(db, col, filters = [], order = null, lim = null) { this.db = db; this.col = col; this.filters = filters; this.order = order; this.lim = lim; }
  where(f, op, v) { return new Query(this.db, this.col, [...this.filters, [f, op, v]], this.order, this.lim); }
  orderBy(f, dir = 'asc') { return new Query(this.db, this.col, this.filters, [f, dir], this.lim); }
  limit(n) { return new Query(this.db, this.col, this.filters, this.order, n); }
  async get() {
    const m = this.db.data.get(this.col) || new Map();
    let rows = [...m.entries()].map(([id, d]) => ({ id, d }));
    for (const [f, op, v] of this.filters) {
      rows = rows.filter(({ d }) => {
        const x = getPath(d, f);
        if (op === '==') return x === v;
        if (op === '!=') return x !== v;
        if (op === 'in') return v.includes(x);
        if (x === undefined || x === null) return false;
        if (op === '<') return x < v;
        if (op === '<=') return x <= v;
        if (op === '>') return x > v;
        if (op === '>=') return x >= v;
        throw new Error('opérateur non géré ' + op);
      });
    }
    if (this.order) {
      const [f, dir] = this.order;
      rows.sort((a, b) => { const x = getPath(a.d, f), y = getPath(b.d, f); return (x < y ? -1 : x > y ? 1 : 0) * (dir === 'desc' ? -1 : 1); });
    }
    if (this.lim != null) rows = rows.slice(0, this.lim);
    const docs = rows.map(({ id, d }) => ({ id, exists: true, data: () => clone(d), ref: new Doc(this.db, this.col, id) }));
    return { docs, empty: docs.length === 0, size: docs.length, forEach: (fn) => docs.forEach(fn) };
  }
}

class FakeDb {
  constructor() { this.data = new Map(); this.writes = 0; }
  collection(name) {
    const db = this;
    const q = new Query(db, name);
    q.doc = (id) => new Doc(db, name, id);
    return q;
  }
  batch() {
    const ops = [];
    return {
      set: (ref, data, opts) => ops.push(() => ref.set(data, opts)),
      update: (ref, data) => ops.push(() => ref.update(data)),
      commit: async () => { for (const o of ops) await o(); },
    };
  }
  // Firestore rejoue une transaction en conflit : ici on les exécute l'une après l'autre, ce qui donne le même résultat
  runTransaction(fn) {
    const run = () => this._transaction(fn);
    const p = (this._txQueue || Promise.resolve()).then(run, run);
    this._txQueue = p.catch(() => {});
    return p;
  }
  async _transaction(fn) {
    const writes = [];
    const tx = { get: (ref) => ref.get(), set: (ref, data, opts) => { writes.push(() => ref.set(data, opts)); return tx; }, update: (ref, data) => { writes.push(() => ref.update(data)); return tx; } };
    const r = await fn(tx);
    for (const w of writes) await w();
    return r;
  }
  /** Raccourci de test : écrit un document. */
  seed(col, id, data) { return this.collection(col).doc(id).set(data); }
  read(col, id) { const m = this.data.get(col); return m && m.get(id) ? clone(m.get(id)) : null; }
  all(col) { return [...(this.data.get(col) || new Map()).entries()].map(([id, d]) => Object.assign({ _id: id }, clone(d))); }
}

module.exports = { FakeDb };
