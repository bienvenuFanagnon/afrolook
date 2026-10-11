// Connexion avec Google (projet Firebase slashatlas-studio). Aucun mot de passe : la session reste dans le navigateur.
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import { getAuth, GoogleAuthProvider, signInWithPopup, onAuthStateChanged, signOut } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';

const lang = document.body.dataset.lang === 'en' ? 'en' : 'fr';
const MSG = {
  fr: { closed: 'Fenêtre fermée avant la fin de la connexion.', domain: 'Cette adresse n’est pas encore autorisée pour la connexion Google.', off: 'La connexion Google n’est pas encore activée.', err: 'Connexion impossible pour le moment. Réessayez.' },
  en: { closed: 'Window closed before sign-in finished.', domain: 'This address is not yet authorised for Google sign-in.', off: 'Google sign-in is not enabled yet.', err: 'Sign-in failed. Please try again.' },
}[lang];

const auth = getAuth(initializeApp({
  apiKey: 'AIzaSyDw_toWGZHcmg86ljS20sXVAkCErucQDTY',
  authDomain: 'slashatlas-studio.firebaseapp.com',
  projectId: 'slashatlas-studio',
  appId: '1:485906805806:web:d18b3b66f3472601209bbf',
}));
auth.languageCode = lang;
const $ = (s) => document.querySelector(s);
const note = (m) => { const n = $('#auth-msg'); if (n) n.textContent = m || ''; };

window.slashAuth = {
  get user() { return auth.currentUser; },
  async call(path, body) {
    const token = await auth.currentUser.getIdToken();
    const r = await fetch('/api/' + path, { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer ' + token }, body: JSON.stringify(body || {}) });
    let j = {}; try { j = await r.json(); } catch (e) {}
    return { status: r.status, data: j };
  },
  signOut: () => signOut(auth),
  login,
};

async function login() {
  note('');
  document.querySelectorAll('[data-login]').forEach((b) => { b.disabled = true; });
  try { await signInWithPopup(auth, new GoogleAuthProvider()); }
  catch (e) {
    const c = (e && e.code) || '';
    note(c === 'auth/popup-closed-by-user' || c === 'auth/cancelled-popup-request' ? MSG.closed
      : c === 'auth/unauthorized-domain' ? MSG.domain
      : c === 'auth/operation-not-allowed' || c === 'auth/configuration-not-found' ? MSG.off : MSG.err);
  } finally { document.querySelectorAll('[data-login]').forEach((b) => { b.disabled = false; }); }
}
document.addEventListener('click', (e) => {
  if (e.target.closest('[data-login]')) { e.preventDefault(); login(); }
  if (e.target.closest('[data-logout]')) { e.preventDefault(); signOut(auth); }
});
onAuthStateChanged(auth, (u) => document.dispatchEvent(new CustomEvent('sa:auth', { detail: { user: u } })));
