'use strict';
// Traduit une erreur de génération (collection GenErrors) en explication claire pour l'administration :
// ce qui s'est passé, et ce qu'il faut faire. La première règle qui correspond l'emporte.

const RULES = [
  {
    cause: 'gemini_credits', gravite: 'critique',
    test: (c, r) => c === 'gemini_credits' || /prepayment credits are depleted|billing|insufficient (funds|credit)/i.test(r),
    titre: 'Crédits Gemini épuisés',
    quoi: 'Google refuse de créer les images : le solde prépayé du projet Gemini est vide. Aucune image ne peut sortir tant qu’il n’est pas rechargé.',
    action: 'Recharger les crédits prépayés sur ai.studio/projects (le projet de la clé GEMINI_API_KEY). Les clients sont remboursés automatiquement.',
    lien: 'https://ai.studio/projects',
  },
  {
    cause: 'gemini_key', gravite: 'critique',
    test: (c, r) => c === 'gemini_key' || /API key not valid|API_KEY_INVALID|PERMISSION_DENIED|api key expired/i.test(r),
    titre: 'Clé Gemini refusée',
    quoi: 'Google ne reconnaît plus la clé API (invalide, supprimée ou sans droits).',
    action: 'Créer une nouvelle clé dans AI Studio et la mettre dans le secret GEMINI_API_KEY, puis redéployer les fonctions.',
    lien: 'https://aistudio.google.com/apikey',
  },
  {
    cause: 'minimax_credits', gravite: 'critique',
    test: (c, r) => /minimax/i.test(c + r) && /balance|credit|insufficient|1008/i.test(r || c),
    titre: 'Crédits MiniMax épuisés',
    quoi: 'Le service vidéo MiniMax refuse les demandes : le solde du compte est insuffisant.',
    action: 'Recharger le compte MiniMax (Plan Usage).',
    lien: 'https://platform.minimax.io',
  },
  {
    cause: 'render_trigger', gravite: 'critique',
    test: (c) => c === 'render_trigger_failed',
    titre: 'Le rendu du film n’a pas démarré',
    quoi: 'Le serveur de rendu vidéo n’a pas répondu au lancement du film (délai dépassé ou adresse invalide).',
    action: 'Vérifier que la fonction slashatlasFilm est déployée et en bonne santé (Console Firebase → Functions → journaux). Le client est remboursé.',
  },
  {
    cause: 'busy', gravite: 'attention',
    test: (c, r) => c === 'busy' || /\b429\b|RESOURCE_EXHAUSTED|quota|rate limit/i.test(r),
    titre: 'Trop de demandes (quota Gemini)',
    quoi: 'Google limite le nombre de demandes par minute ou par jour : les demandes au-delà sont refusées.',
    action: 'Rien à faire si c’est ponctuel. Si cela dure, vérifier les quotas du projet dans AI Studio.',
    lien: 'https://ai.studio/projects',
  },
  {
    cause: 'gemini_unavailable', gravite: 'attention',
    test: (c, r) => c === 'gemini_unavailable' || /\b503\b|UNAVAILABLE|overloaded|not found for API version/i.test(r),
    titre: 'Service d’images indisponible',
    quoi: 'Les modèles d’images de Google (et le secours Cloudflare) n’ont pas répondu. Souvent une panne passagère chez Google.',
    action: 'Attendre quelques minutes. Si cela dure plus d’une heure, vérifier les modèles (IMAGE_MODELS dans studio.js) et le jeton Cloudflare.',
  },
  {
    cause: 'gemini_error', gravite: 'attention',
    test: (c) => c === 'gemini_error',
    titre: 'Gemini a refusé la création',
    quoi: 'Google a renvoyé une erreur sans image. Les erreurs enregistrées avant le 20/10 n’ont pas le détail : le 19/10, la cause était les crédits Gemini épuisés.',
    action: 'Vérifier d’abord les crédits sur ai.studio/projects, puis le détail technique de l’erreur.',
    lien: 'https://ai.studio/projects',
  },
  {
    cause: 'refused', gravite: 'info',
    test: (c) => c === 'refused',
    titre: 'Image refusée par l’IA',
    quoi: 'Le filtre de sécurité de l’IA a refusé la photo ou la demande (contenu jugé sensible).',
    action: 'Rien à faire : le client est remboursé et peut essayer une autre photo.',
  },
  {
    cause: 'timeout', gravite: 'attention',
    test: (c, r) => /abort|timeout|timed out|deadline/i.test(c + ' ' + r),
    titre: 'Délai dépassé',
    quoi: 'L’IA a mis trop de temps à répondre et la demande a été arrêtée.',
    action: 'Rien à faire si c’est rare. Si cela se répète, le service de Google est lent : surveiller.',
  },
  {
    cause: 'script', gravite: 'attention',
    test: (c) => c === 'script_failed',
    titre: 'Texte de la vidéo impossible à écrire',
    quoi: 'Gemini n’a pas pu écrire le texte de la publicité vidéo.',
    action: 'Si cela coïncide avec « Crédits Gemini épuisés », recharger les crédits. Sinon, réessayer plus tard.',
  },
  {
    cause: 'voice', gravite: 'attention',
    test: (c, r) => c === 'voice_error' || c === 'tts' || /text-to-speech|elevenlabs|tts/i.test(r),
    titre: 'Voix off en échec',
    quoi: 'La synthèse vocale (Google TTS ou ElevenLabs) n’a pas répondu.',
    action: 'Vérifier le quota ElevenLabs dans l’onglet Outils et l’API Text-to-Speech dans Google Cloud.',
  },
  {
    cause: 'user_limit', gravite: 'info',
    test: (c) => c === 'daily_limit' || c === 'too_long',
    titre: 'Limite atteinte par l’utilisateur',
    quoi: 'La personne a atteint sa limite du jour ou demandé une vidéo trop longue.',
    action: 'Rien à faire.',
  },
  {
    cause: 'bad_input', gravite: 'info',
    test: (c) => ['no_photo', 'bad_photo', 'photo_too_big'].includes(c),
    titre: 'Photo envoyée invalide',
    quoi: 'La photo est absente, d’un format non accepté ou trop lourde.',
    action: 'Rien à faire : le message d’erreur a été montré à la personne.',
  },
];

const DEFAULT = {
  cause: 'autre', gravite: 'attention',
  titre: 'Erreur non répertoriée',
  quoi: 'Une erreur inattendue s’est produite. Le détail technique est affiché à droite.',
  action: 'Si elle se répète, transmettre le détail technique pour analyse.',
};

/** x = document GenErrors : { type, code, desc?, detail?: { provider, model, http, raw } } */
function explain(x) {
  const c = String((x && x.code) || '');
  const r = [x && x.detail && x.detail.raw, x && x.detail && x.detail.http, x && x.desc].filter(Boolean).join(' ');
  const rule = RULES.find((k) => { try { return k.test(c, r); } catch (_) { return false; } }) || DEFAULT;
  const { test, ...out } = rule;
  return out;
}

module.exports = { explain };
