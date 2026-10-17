'use strict';
// Notifications d'actualité « qui font cliquer » : on repère, parmi les articles lus par syncNews, ceux qui parlent des stars,
// des pépites et des grands rendez-vous du football (classicos, derbys), de la vie des vedettes, des transferts et des records.
// Rien n'est inventé : la notification renvoie vers NOTRE page de l'actualité (qui cite la source et son lien). Le texte accrocheur est écrit par
// l'IA à partir du titre et de l'extrait seulement, puis vérifié (noms, chiffres, promesses, reprise du titre) ; sinon un texte modèle prend le relais.
// Sujets sensibles écartés d'office : décès, maladie, drames, violences, affaires judiciaires, et tout ce qui touche un mineur de façon négative.

const { strip } = require('../news/match');
const { hedges } = require('../news/facts');
const V = require('../ai/validate');
const { unknownNames, copiedRun } = require('../recap/validate');

const norm = (s) => ` ${strip(s)} `;
const list = (names) => names.map((n) => ({ nom: n, key: norm(n) }));

// Grandes vedettes : stars mondiales et africaines, valeurs montantes. La liste se complète depuis l'admin (config/push.vedettes).
const STARS = list(['Mbappé', 'Yamal', 'Lamine Yamal', 'Haaland', 'Vinícius', 'Vini Jr', 'Bellingham', 'Messi', 'Lionel Messi', 'Cristiano Ronaldo', 'Cristiano', 'Ronaldo', 'Neymar', 'Salah', 'Mohamed Salah', 'Lewandowski', 'Harry Kane', 'De Bruyne', 'Modrić', 'Benzema', 'Griezmann', 'Dembélé', 'Raphinha', 'Pedri', 'Gavi', 'Rodri', 'Saka', 'Foden', 'Musiala', 'Wirtz', 'Osimhen', 'Lookman', 'Hakimi', 'Achraf Hakimi', 'Mahrez', 'Sadio Mané', 'Aubameyang', 'Koulibaly', 'Kessié', 'Mbeumo', 'Wissa', 'Onana', 'Drogba', "Eto'o", 'Ibrahimović', 'Pogba', 'Kanté', 'Camavinga', 'Tchouaméni', 'Olise', 'Kolo Muani', 'Doué', 'Barcola', 'Ben Yedder', 'Ansu Fati', 'Endrick', 'Garnacho', 'Mainoo', 'Kvaratskhelia', 'Rafael Leão', 'Lautaro']);
// Grands clubs
const CLUBS = list(['Real Madrid', 'FC Barcelone', 'Barça', 'PSG', 'Paris Saint-Germain', 'Manchester City', 'Manchester United', 'Liverpool', 'Arsenal', 'Chelsea', 'Bayern', 'Juventus', 'Inter', 'AC Milan', 'Olympique de Marseille', 'OM', 'Atlético', 'Tottenham', 'Al Nassr', 'Inter Miami']);
// Rendez-vous : mots du texte et couples de clubs
const DERBY = /(?<![\p{L}\p{N}])(?:cl[aá]sico|derby|choc|olympico|klassiker|superclasico|super clasico)(?![\p{L}\p{N}])/iu;
const CLASSICOS = [['real madrid', 'barcelone'], ['real madrid', 'barcelona'], ['paris', 'marseille'], ['manchester united', 'liverpool'], ['manchester city', 'manchester united'], ['arsenal', 'tottenham'], ['inter', 'milan'], ['real madrid', 'atletico'], ['liverpool', 'everton'], ['boca', 'river']];

const re = (src) => new RegExp(`(?<![\\p{L}\\p{N}])(?:${src})(?![\\p{L}\\p{N}])`, 'iu');
const TALENT = re("p[ée]pite|prodige|jeune talent|wonder ?kid|ph[ée]nom[eè]ne|r[ée]v[ée]lation|futur(?:e)? (?:messi|ronaldo|mbapp[ée]|ballon d'or|star|crack|l[ée]gende)|nouveau (?:messi|ronaldo|mbapp[ée]|pel[ée])|next (?:messi|ronaldo|mbapp[ée])|acad[ée]mie|centre de formation|la relève|rising star|wonderkid|future (?:messi|ronaldo|star|ballon d'or)|young talent|teen(?:ager)?");
const KID = re("(?:fils|fille|enfant|h[ée]ritier|junior) (?:de |d')?(?:cristiano|ronaldo|messi|neymar|mbapp[ée]|beckham|maradona)|cristiano (?:jr|junior)|cristianinho|thiago messi|mateo messi|ciro messi|son of (?:messi|ronaldo|cristiano|neymar)");
const THEMES = {
  transfert: re("transfert|mercato|recrue|prolong\\p{L}*|clause|offre|pr[êe]t|signe|signature|transfer|signing|deal|bid"),
  record: re("record|historique|ballon d'or|soulier d'or|troph[ée]e|tripl[ée]|quadrupl[ée]|hat-?trick|meilleur buteur|but de la saison|golden boot|record-breaking"),
  vie: re("vie priv[ée]e|mariage|mari[ée]e?s?|fian[cç]ailles|compagne|[ée]pouse|b[ée]b[ée]|naissance|vacances|villa|fortune|salaire|yacht|collection|style de vie|lifestyle|fondation|g[ée]n[ée]rosit[ée]|humanitaire|documentaire|autobiographie|wedding|girlfriend|wife|net worth|charity|documentary"),
  scandale: re("scandale|pol[ée]mique|clash|dispute|tension|bagarre|sanction|amende|[ée]cart[ée]|mis [àa] l'[ée]cart|col[èe]re|insulte\\p{L}*|vestiaire|rupture|conflit|divorce|row|controversy|fine[sd]?|furious|fallout"),
};
// Jamais en notification : deuil, santé grave, drames, violences, justice, mineurs. Le texte est jugé sur le titre et l'extrait.
const SENSIBLE = re("d[ée]c[èe]s|d[ée]c[ée]d[ée]\\p{L}*|mort|meurt|d[ée]c[ée]der|deuil|d[ée]funt\\p{L}*|suicide|viol\\p{L}*|agression sexuelle|abus\\p{L}*|p[ée]dophil\\p{L}*|cancer|tumeur|maladie grave|hospitalis\\p{L}*|coma|drogue\\p{L}*|stup[ée]fiant\\p{L}*|arr[êe]t[ée]\\p{L}*|garde [àa] vue|prison|condamn\\p{L}*|incarc\\p{L}*|accident mortel|crash|fusillade|meurtre|assassin\\p{L}*|terroris\\p{L}*|dies|died|death|dead|suicide|rape|abuse|cancer|hospitali[sz]ed|arrested|jailed|convicted|murder|killed|tragedy|tragédie|drame");
const MINEUR = re("mineur\\p{L}*|enfant|b[ée]b[ée]|fils|fille|ado\\p{L}*|(?:1[0-7]) ans|child|baby|daughter|teen\\p{L}*");

const MAX_AGE_H = 30;
const SEUIL = 7;       // score à partir duquel l'actu part chez tous les abonnés
const SEUIL_EQUIPE = 3; // score à partir duquel elle part chez ceux qui suivent l'équipe citée

const hits = (items, text) => items.filter((x) => text.includes(x.key));
const dedupNames = (found) => {
  // « Messi » et « Lionel Messi » ne comptent qu'une fois : on garde le nom le plus long qui contient les autres
  const out = [];
  for (const f of found.slice().sort((a, b) => b.key.length - a.key.length)) if (!out.some((o) => o.key.includes(f.key))) out.push(f);
  return out;
};

/**
 * Évalue un article { titre, resume, date, image, teamIds } à l'instant `now`.
 * Renvoie { score, themes[], star, club, sensible, age } (star = nom de la vedette principale ou null).
 */
function assess(n, now, extra) {
  const raw = `${n.titre || ''} . ${n.resume || ''}`;
  const text = norm(raw);
  const stars = dedupNames(hits(STARS.concat(list(extra || [])), text));
  const clubs = dedupNames(hits(CLUBS, text));
  const age = (now.getTime() - new Date(n.date).getTime()) / 3600e3;
  const themes = [];
  let score = 0;
  if (stars.length) { score += 4 + Math.min(2, stars.length - 1); themes.push('star'); }
  if (clubs.length) { score += 2; themes.push('club'); }
  if (KID.test(raw)) { score += 3; themes.push('enfant'); }
  if (TALENT.test(raw)) { score += 3; themes.push('talent'); }
  if (DERBY.test(raw) || clubs.length >= 2 && CLASSICOS.some((p) => p.every((x) => text.includes(` ${x} `)))) { score += 3; themes.push('classico'); }
  for (const [k, rx] of Object.entries(THEMES)) if (rx.test(raw)) { score += k === 'transfert' ? 1 : 2; themes.push(k); }
  if (age <= 3) score += 3; else if (age <= 8) score += 2; else if (age <= 16) score += 1;
  if (n.image) score += 1;
  let sensible = SENSIBLE.test(raw);
  // aucun sujet « polémique » ou « vie privée » quand un mineur est cité
  if (!sensible && MINEUR.test(raw) && (themes.includes('scandale') || themes.includes('vie'))) sensible = true;
  if (age > MAX_AGE_H || age < -1) sensible = true;
  return { score, themes, star: stars.length ? stars[0].nom : null, club: clubs.length ? clubs[0].nom : null, sensible, age: Math.round(age * 10) / 10 };
}

const KICKER = {
  fr: { classico: 'Choc à suivre', talent: 'Pépite à suivre', enfant: 'La relève des légendes', transfert: 'Mercato', record: 'Record', vie: 'Vie de star', scandale: 'Ça fait parler', star: 'À la une', club: 'À la une' },
  en: { classico: 'Big match', talent: 'Talent to watch', enfant: 'Next generation', transfert: 'Transfers', record: 'Record', vie: 'Star life', scandale: 'Everyone is talking', star: 'Top story', club: 'Top story' },
};
const EMOJI = { classico: '⚔️', talent: '🌟', enfant: '🌟', transfert: '🔁', record: '🏆', vie: '👀', scandale: '👀', star: '🔥', club: '🔥' };
const mainTheme = (a) => ['classico', 'enfant', 'talent', 'record', 'transfert', 'scandale', 'vie', 'star', 'club'].find((t) => a.themes.includes(t)) || 'star';

/** Consigne donnée à l'IA : un titre et un corps de notification, rien d'autre. */
function hookMessages(n, a, lang) {
  const en = lang === 'en';
  const system = en
    ? 'You write push notifications for PronoFlash IA, a free football site. Use ONLY the headline and excerpt provided: never add a fact, number, name, quote or detail that is not in them. Never copy the headline: rephrase it in your own words. Always credit the source ("according to <site>"). Be catchy and curious, never alarming, no all-caps, no betting advice, no promise. Answer with strict JSON only.'
    : "Tu écris des notifications pour PronoFlash IA, un site gratuit de football. Utilise UNIQUEMENT le titre et l'extrait fournis : n'ajoute jamais un fait, un chiffre, un nom, une citation ni un détail absent. Ne recopie jamais le titre : reformule avec tes mots. Cite toujours la source (« selon <site> »). Sois accrocheur et donne envie de savoir, sans alarmer, sans majuscules criardes, sans conseil de pari, sans promesse. Réponds uniquement avec un JSON strict.";
  const user = en
    ? `Source: ${n.source}\nHeadline: ${n.titre}\nExcerpt: ${n.resume || '(none)'}\nTopic: ${a.themes.join(', ')}\n\nReturn {"titre": notification title, max 55 characters, starts with one fitting emoji, "corps": max 110 characters, makes people want to open it, mentions the source}.`
    : `Source : ${n.source}\nTitre : ${n.titre}\nExtrait : ${n.resume || '(aucun)'}\nSujet : ${a.themes.join(', ')}\n\nRéponds {"titre": titre de notification, 55 caractères au plus, commence par un emoji adapté, "corps": 110 caractères au plus, donne envie d'ouvrir, cite la source}.`;
  return [{ role: 'system', content: system }, { role: 'user', content: user }];
}

/** Valide la réponse de l'IA. Renvoie { titre, corps } ou null. */
function validateHook(raw, n, lang) {
  const j = V.extractJson(raw);
  if (!j || typeof j !== 'object') return null;
  const titre = typeof j.titre === 'string' ? j.titre.trim() : '';
  const corps = typeof j.corps === 'string' ? j.corps.trim() : '';
  if (titre.length < 12 || titre.length > 62 || corps.length < 25 || corps.length > 125) return null;
  const all = `${titre} . ${corps}`;
  const en = lang === 'en';
  const w = (all.match(en ? V.EN_WORDS : V.FR_WORDS) || []).length, o = (all.match(en ? V.FR_WORDS : V.EN_WORDS) || []).length;
  if (w < 4 || o > w) return null;
  if ((en ? V.FORBIDDEN_EN : V.FORBIDDEN).some((r) => r.test(all)) || V.hasUnnegatedPromise(all, lang)) return null;
  if (/(?<!\p{L})(?:pariez|parie|misez|bet now|place your bet)(?!\p{L})/iu.test(all)) return null;
  const given = `${n.titre} ${n.resume || ''}`;
  if (V.checkNumbers(all, V.allowedNumbers([given])).length) return null;
  if (unknownNames(all, norm(`${given} ${n.source}`)).length) return null;
  if (copiedRun(all, [n.titre], 6)) return null;
  if (all === all.toUpperCase()) return null;
  // la source doit être citée dans le corps (nom du site, « selon » ou « according to »)
  if (!norm(corps).includes(norm(n.source)) && !/(?<!\p{L})(?:selon|d'apr[èe]s|according to|per)(?!\p{L})/iu.test(corps)) return null;
  return { titre, corps };
}

/** Texte modèle quand l'IA est indisponible ou refusée : rien d'inventé, la source est citée. */
function hookFallback(n, a, lang) {
  const en = lang === 'en';
  const t = mainTheme(a);
  const who = a.star || a.club;
  const head = {
    fr: { classico: `${EMOJI[t]} Un choc qui fait parler`, talent: `${EMOJI[t]} Une pépite fait parler`, enfant: `${EMOJI[t]} La relève fait parler`, transfert: `${EMOJI[t]} Mercato : ${who || "ça bouge"}`, record: `${EMOJI[t]} Record : ${who || "à lire"}`, vie: `${EMOJI[t]} ${who ? `${who} : ` : ''}ce qu'on raconte`, scandale: `${EMOJI[t]} ${who ? `${who} : ` : ''}ça fait parler`, star: `${EMOJI[t]} ${who || 'Une star'} fait l'actu`, club: `${EMOJI[t]} ${who || 'Un grand club'} fait l'actu` },
    en: { classico: `${EMOJI[t]} A big match is making noise`, talent: `${EMOJI[t]} A rising talent is making noise`, enfant: `${EMOJI[t]} The next generation is talking`, transfert: `${EMOJI[t]} Transfers: ${who || 'news'}`, record: `${EMOJI[t]} Record: ${who || 'read more'}`, vie: `${EMOJI[t]} ${who ? `${who}: ` : ''}what is being said`, scandale: `${EMOJI[t]} ${who ? `${who}: ` : ''}everyone is talking`, star: `${EMOJI[t]} ${who || 'A star'} is in the news`, club: `${EMOJI[t]} ${who || 'A big club'} is in the news` },
  }[en ? 'en' : 'fr'][t];
  const hedged = hedges(`${n.titre} ${n.resume || ''}`);
  const corps = en
    ? `${hedged ? 'Unconfirmed: ' : ''}${n.source} reports it. Our summary and the source link are inside.`
    : `${hedged ? 'À confirmer : ' : ''}${n.source} en parle. Notre résumé et le lien de la source sont à l'intérieur.`;
  return { titre: head.slice(0, 62), corps };
}

/**
 * Notification d'une actu. providers : fournisseurs d'IA (peut être vide). Renvoie { titre, corps, carte, tag, themes, methode }.
 * `url` est ajoutée par l'appelant (elle dépend de la langue).
 */
async function buildHook(n, a, lang, providers) {
  let hook = null;
  let methode = 'modele';
  for (const p of providers || []) {
    try {
      hook = validateHook(await p.call(hookMessages(n, a, lang)), n, lang);
    } catch { hook = null; }
    if (hook) { methode = 'ia'; break; }
  }
  if (!hook) hook = hookFallback(n, a, lang);
  const t = mainTheme(a);
  const carte = { badge: KICKER[lang === 'en' ? 'en' : 'fr'][t], titre: hook.titre.replace(/^[^\p{L}\p{N}]+/u, ''), lignes: [], pied: n.source };
  return { titre: hook.titre, corps: hook.corps, carte, tag: 'pf-actu', themes: a.themes, methode };
}

/**
 * Gros match du jour (classico, derby, deux grands clubs) parmi les matchs à venir dans les `hours` prochaines heures.
 * Renvoie le match le plus relevant ou null.
 */
function grosMatch(matches, now, hours = 12) {
  const limit = now.getTime() + hours * 3600e3;
  const scored = [];
  for (const m of matches) {
    if (m.statut !== 'prevu' || !m.domicile || !m.exterieur) continue;
    const t = new Date(m.coupDEnvoi).getTime();
    if (!(t > now.getTime() + 30 * 60e3 && t <= limit)) continue;
    const a = norm(m.domicile.nom || m.domicile.nomCourt), b = norm(m.exterieur.nom || m.exterieur.nomCourt);
    const isCl = CLASSICOS.some((p) => (a.includes(` ${p[0]} `) && b.includes(` ${p[1]} `)) || (a.includes(` ${p[1]} `) && b.includes(` ${p[0]} `)));
    const nClubs = CLUBS.filter((c) => a.includes(c.key) || b.includes(c.key)).length;
    const bothBig = CLUBS.some((c) => a.includes(c.key)) && CLUBS.some((c) => b.includes(c.key));
    const s = isCl ? 10 : bothBig ? 6 : 0;
    if (s) scored.push({ m, s: s + nClubs, classico: isCl });
  }
  scored.sort((x, y) => y.s - x.s || new Date(x.m.coupDEnvoi) - new Date(y.m.coupDEnvoi));
  return scored.length ? scored[0] : null;
}

module.exports = { assess, buildHook, hookMessages, validateHook, hookFallback, grosMatch, mainTheme, STARS, CLUBS, SEUIL, SEUIL_EQUIPE, MAX_AGE_H, KICKER, EMOJI };
