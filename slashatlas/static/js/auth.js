// Connexion réservée à l'administrateur (e-mail + mot de passe du compte Afrolook).
// Aucune création de compte ici : seule la connexion à un compte existant est proposée.
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import { getAuth, signInWithEmailAndPassword, onAuthStateChanged, signOut } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';

const auth = getAuth(initializeApp({
  apiKey: 'AIzaSyBES1Ej6uR4FouRRkh-1PF1B89wRpW7bQo',
  authDomain: 'afrolooki.firebaseapp.com',
  projectId: 'afrolooki',
  appId: '1:186049947777:web:7dc6951123bfb3ff940580',
}));
auth.languageCode = 'fr';
const $ = (s) => document.querySelector(s);
const note = (m) => { const n = $('#auth-msg'); if (n) n.textContent = m || ''; };

window.slashAuth = {
  async call(path, body) {
    const token = await auth.currentUser.getIdToken();
    const r = await fetch('/api/' + path, { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer ' + token }, body: JSON.stringify(body || {}) });
    let j = {}; try { j = await r.json(); } catch (e) {}
    return { status: r.status, data: j };
  },
  signOut: () => signOut(auth),
};

const form = $('#adm-out');
if (form) form.addEventListener('submit', async (e) => {
  e.preventDefault();
  note('');
  const email = form.email.value.trim(), pwd = form.password.value;
  if (!email || !pwd) { note('Saisissez votre e-mail et votre mot de passe.'); return; }
  const btn = form.querySelector('button'); btn.disabled = true;
  try { await signInWithEmailAndPassword(auth, email, pwd); form.password.value = ''; }
  catch (err) {
    const c = (err && err.code) || '';
    note(c === 'auth/too-many-requests' ? 'Trop d’essais. Patientez quelques minutes avant de réessayer.'
      : c === 'auth/network-request-failed' ? 'Connexion réseau impossible.'
      : 'E-mail ou mot de passe incorrect.');
  } finally { btn.disabled = false; }
});
document.addEventListener('click', (e) => { if (e.target.closest('[data-logout]')) { e.preventDefault(); signOut(auth); } });
onAuthStateChanged(auth, (u) => document.dispatchEvent(new CustomEvent('sa:auth', { detail: { user: u } })));
