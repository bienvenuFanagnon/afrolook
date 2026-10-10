// Compte Google (facultatif). Chargé à la demande : le SDK n'arrive qu'au clic sur « Connexion »
// ou si la personne s'est déjà connectée. Aucun cookie : la session reste dans le navigateur (IndexedDB).
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import { getAuth, GoogleAuthProvider, signInWithPopup, onAuthStateChanged, signOut } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';

const lang = document.body.dataset.lang === 'en' ? 'en' : 'fr';
const TXT = {
  fr: { login: 'Connexion', signing: 'Connexion…', err: 'Connexion impossible pour le moment. Réessayez dans un instant.', closed: 'Fenêtre fermée avant la fin de la connexion.', domain: 'Cette adresse du site n’est pas encore autorisée pour la connexion Google.', off: 'La connexion Google n’est pas encore activée sur ce site.' },
  en: { login: 'Sign in', signing: 'Signing in…', err: 'Sign-in failed for now. Please try again in a moment.', closed: 'Window closed before sign-in finished.', domain: 'This site address is not yet authorised for Google sign-in.', off: 'Google sign-in is not enabled on this site yet.' },
}[lang];

const app = initializeApp({
  apiKey: 'AIzaSyBES1Ej6uR4FouRRkh-1PF1B89wRpW7bQo',
  authDomain: 'afrolooki.firebaseapp.com',
  projectId: 'afrolooki',
  appId: '1:186049947777:web:7dc6951123bfb3ff940580',
});
const auth = getAuth(app);
auth.languageCode = lang;

const $ = (s) => document.querySelector(s);
const btns = () => Array.from(document.querySelectorAll('[data-auth]'));
const note = (m) => { const n = $('#auth-msg'); if (n) n.textContent = m || ''; };
let current = null;

async function call(path, body) {
  const token = await auth.currentUser.getIdToken();
  const r = await fetch('/api/' + path, { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer ' + token }, body: JSON.stringify(body || {}) });
  let j = {}; try { j = await r.json(); } catch (e) {}
  return { status: r.status, data: j };
}
window.slashAuth = {
  get user() { return current; },
  call,
  signOut: () => signOut(auth),
  login,
};

async function login() {
  note('');
  btns().forEach((b) => { b.disabled = true; });
  try {
    await signInWithPopup(auth, new GoogleAuthProvider());
  } catch (e) {
    const c = (e && e.code) || '';
    note(c === 'auth/popup-closed-by-user' || c === 'auth/cancelled-popup-request' ? TXT.closed
      : c === 'auth/unauthorized-domain' ? TXT.domain
      : c === 'auth/operation-not-allowed' || c === 'auth/configuration-not-found' ? TXT.off : TXT.err);
  } finally { btns().forEach((b) => { b.disabled = false; }); }
}

function paint(u) {
  btns().forEach((b) => {
    if (u) {
      const first = (u.displayName || u.email || '?').trim().split(/\s+/)[0];
      b.textContent = first.length > 12 ? first.slice(0, 11) + '…' : first;
      b.classList.remove('pri'); b.classList.add('gl');
      b.dataset.in = '1';
    } else {
      b.textContent = TXT.login; b.classList.add('pri'); b.classList.remove('gl'); delete b.dataset.in;
    }
  });
}

document.addEventListener('click', (e) => {
  const b = e.target.closest('[data-auth]');
  if (!b) return;
  e.preventDefault();
  if (b.dataset.in) location.href = b.dataset.account || '/compte/'; else login();
});
document.addEventListener('click', (e) => { if (e.target.closest('[data-login]')) { e.preventDefault(); login(); } if (e.target.closest('[data-logout]')) { e.preventDefault(); signOut(auth); } });

onAuthStateChanged(auth, async (u) => {
  current = u;
  try { localStorage.setItem('sa_in', u ? '1' : '0'); } catch (e) {}
  paint(u);
  if (u) { try { await call('account', { lang }); } catch (e) {} }
  document.dispatchEvent(new CustomEvent('sa:auth', { detail: { user: u } }));
});
