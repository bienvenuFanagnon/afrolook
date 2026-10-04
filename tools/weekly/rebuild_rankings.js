// Recalcule les classements Top Posts / Top Créateurs d'une série de semaines (sans récompense).
// Usage : GOOGLE_APPLICATION_CREDENTIALS=... node rebuild_rankings.js 2026-W30 2026-W39
// (nécessite `npm run build` dans functions/). Les semaines sans classement ne sont pas conservées.
const r = require('../../functions/lib/posts/weeklyRankings.js');
const { db } = require('../../functions/lib/shared/firebase.js');
const [from, to] = process.argv.slice(2);
const parse = (id) => { const [y, w] = id.split('-W').map(Number); return { y, w }; };
(async () => {
  let { y, w } = parse(from); const end = parse(to);
  for (;;) {
    const id = `${y}-W${String(w).padStart(2, '0')}`;
    const posts = await r.computeTopPosts(id);
    const creators = await r.computeTopCreators(id);
    if (posts === 0) await db.collection('WeeklyTopPosts').doc(id).delete();
    if (creators === 0) await db.collection('WeeklyTopCreators').doc(id).delete();
    console.log(id, { posts, creators });
    if (y === end.y && w === end.w) break;
    w++; if (w > 52) { w = 1; y++; }
  }
})().catch((e) => { console.error(e); process.exit(1); });
