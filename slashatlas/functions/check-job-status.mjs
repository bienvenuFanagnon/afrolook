import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';

const SA = JSON.parse(readFileSync('./service-account.json', 'utf8'));
initializeApp({ credential: cert(SA), projectId: 'slashatlas-studio' });
const db = getFirestore();

const JOB_ID = 'kEpoqmjW3IA27ChCklTb';

const snap = await db.collection('FilmJobs').doc(JOB_ID).get();
if (!snap.exists) { console.log('Job introuvable'); process.exit(1); }
const { status, videoUrl, error, updatedAt } = snap.data();
console.log('Status :', status);
if (videoUrl) console.log('URL :', videoUrl);
if (error) console.log('Erreur :', error);
if (updatedAt) console.log('Mis à jour :', updatedAt.toDate().toISOString());
process.exit(0);
