// Rapport d'audience : node scripts/stats.mjs [jours=14]
// Nécessite GOOGLE_APPLICATION_CREDENTIALS (compte de service du projet afrolooki).
import { createRequire } from 'node:module';
const require = createRequire(new URL('../functions/', import.meta.url));
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp({ projectId: 'afrolooki' });
const db = getFirestore();
const days = Number(process.argv[2]) || 14;
const since = new Date(Date.now() - days * 864e5).toISOString().slice(0, 10);
const snap = await db.collection('SlashAtlasStats').where('day', '>=', since).get();
const rows = snap.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => a.id.localeCompare(b.id));
const sum = (k) => rows.reduce((n, r) => n + (r[k] || 0), 0);
const merge = (k) => { const o = {}; for (const r of rows) for (const [a, v] of Object.entries(r[k] || {})) o[a] = (o[a] || 0) + v; return Object.entries(o).sort((a, b) => b[1] - a[1]); };
console.log(`SlashAtlas — ${days} derniers jours`);
console.log('jour        vues  sess  copies  tests  inscrits');
for (const r of rows) console.log(`${r.id}  ${String(r.pv || 0).padStart(5)} ${String(r.sessions || 0).padStart(5)} ${String(r.copies || 0).padStart(7)} ${String(r.tests || 0).padStart(6)} ${String(r.signups || 0).padStart(9)}`);
console.log(`\nTotal : ${sum('pv')} vues, ${sum('sessions')} sessions, ${sum('returning')} retours, ${sum('copies')} copies, ${sum('tests')} tests, ${sum('signups')} inscrits`);
const pv = sum('pv'), cp = sum('copies');
if (pv) console.log(`Taux de copie : ${(100 * cp / pv).toFixed(1)} % des vues`);
for (const [t, k] of [['Pages', 'pages'], ['Langues', 'lang'], ['Appareils', 'dev'], ['Sources', 'ref'], ['Commandes copiées', 'cmd'], ['Outils testés', 'tool']]) {
  const m = merge(k).slice(0, 10);
  if (m.length) console.log(`\n${t}\n` + m.map(([a, v]) => `  ${String(v).padStart(5)}  ${a}`).join('\n'));
}
const subs = await db.collection('SlashAtlasSubscribers').count().get();
console.log(`\nInscrits (liste) : ${subs.data().count}`);
