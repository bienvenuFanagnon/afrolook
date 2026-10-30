/**
 * Règles des diffuseurs Afrolook Ads : texte officiel et numéro de version. Un diffuseur doit les accepter (version courante) pour ajouter des sites ou
 * applications ; si les règles changent, la version change et chacun doit les accepter de nouveau. Le même texte est servi par adsPubMe (espace diffuseur)
 * et reproduit sur la page publique /ads/diffuseur/regles/ (site/src/ads.mjs : RULES_PAGE doit rester identique).
 * Les pourcentages et délais ci-dessous sont ceux validés par le propriétaire le 29/10/2026 (partage 65 %, retenue 30 jours, retrait minimum 10 000 F).
 */
export const PUBLISHER_RULES_VERSION = "2026-10-29";

export interface RuleBlock { title: string; items: string[] }
export const PUBLISHER_RULES: RuleBlock[] = [
  { title: "1. Ton site ou ton application", items: [
    "Il doit être réel, en ligne et accessible au public. Nous vérifions l'adresse (site) ou le lien Google Play ou App Store (application).",
    "Un site doit prouver qu'il t'appartient : la balise ou le fichier fourni doit rester en place. S'il disparaît pendant 3 jours, la diffusion est suspendue.",
    "Chaque site ou application a son identifiant publicitaire (ap_…). Tu ne l'utilises que sur le site ou l'application déclaré, et tu ne le partages avec personne. Utilisé ailleurs, il ne fonctionne pas et peut entraîner la suspension.",
  ] },
  { title: "2. Ton audience", items: [
    "Tu déclares ton audience mensuelle (personnes différentes par mois) avec honnêteté.",
    "Afrolook Ads mesure l'audience réelle : le nombre de personnes différentes pour lesquelles la balise ou le composant a été chargé, sur 30 et 60 jours. Tu la vois dans ton espace, comparée à ce que tu as déclaré.",
    "L'audience retenue est fixée par Afrolook Ads, jamais au-dessus de la déclarée. En cas d'écart important et durable entre la déclarée et la mesurée, Afrolook Ads ajuste l'audience retenue, et peut suspendre la diffusion.",
    "Afrolook Ads détermine lui-même le pays de chaque visiteur (d'après son adresse IP) et compare la répartition à celle que tu as annoncée : un site qui se dit togolais doit avoir des visiteurs togolais. Un écart important est signalé et examiné.",
  ] },
  { title: "3. Ce qui est interdit", items: [
    "Cliquer sur tes propres annonces, ou demander ou payer pour qu'on y clique.",
    "Acheter du trafic, utiliser des robots, des scripts, des affichages ou des rafraîchissements automatiques, ou faire afficher les annonces dans des cadres cachés, de 1 pixel ou empilés.",
    "Modifier, masquer ou déformer une annonce, son lien ou la mention « Annonce » ; mettre plus de 3 emplacements sur une même page.",
    "Faire appeler le serveur d'annonces par d'autres sites, applications ou serveurs que ceux que tu as déclarés.",
  ] },
  { title: "4. Comment les vues et les clics sont comptés", items: [
    "Seules les vues et les clics valides comptent : jeton signé et à usage unique, annonce visible à l'écran pendant la durée minimale du format, intervalles et plafonds respectés, clic passant par la redirection d'Afrolook Ads.",
    "Le reste est du trafic invalide : il n'est ni facturé à l'annonceur, ni payé au diffuseur. Tu vois ton taux de trafic invalide dans ton espace.",
    "Moins de 10 % de trafic invalide : normal. De 10 à 25 % : alerte. Plus de 25 % : l'emplacement est suspendu.",
  ] },
  { title: "5. Rémunération", items: [
    "Tu reçois 65 % du budget des annonces de l'offre Réseau réellement affichées chez toi. Aucun revenu n'est garanti : sans annonceur payant, il n'y a pas de gain. Les annonces gratuites ne rémunèrent pas les diffuseurs.",
    "Les gains sont bloqués 30 jours avant de pouvoir être retirés, avec une réserve de 10 % pendant 90 jours. Retrait minimum : 10 000 F, par Mobile Money. Les frais de paiement et de retrait sont à la charge de l'annonceur, pas des tiens.",
    "Les gains concernés par une fraude sont annulés. Un site ou une application de type application n'est rémunéré qu'après vérification de l'application (attestation).",
  ] },
  { title: "6. Contenu des annonces", items: [
    "Seules des annonces validées par l'équipe Afrolook Ads s'affichent chez toi.",
    "Chaque annonce a une catégorie (commerce, mode, finance, paris, alcool, médicaments, rencontres, contenu sensuel, politique, religion, loteries…). Tu choisis les catégories que tu acceptes : seules celles-là s'affichent chez toi. Les catégories sensibles ne s'affichent jamais sans ton accord explicite. Le contenu sexuellement explicite est interdit pour tous.",
    "Les annonces respectent le ciblage défini par leur annonceur (pays, langues, appareils, types de sites). Afrolook Ads veille à ce qu'au plus 40 % des vues d'une annonce ciblée sur des pays précis viennent d'autres pays.",
    "Afrolook Ads peut retirer à tout moment une annonce ou suspendre un diffuseur pour protéger les visiteurs et les annonceurs.",
  ] },
  { title: "7. Données et vie privée", items: [
    "Afrolook Ads n'utilise aucun cookie, ne suit pas les visiteurs d'un site à l'autre et ne fait aucun ciblage comportemental. Le visiteur est reconnu par un identifiant propre à ton site.",
    "Ta politique de confidentialité doit mentionner l'affichage d'annonces par Afrolook Ads. Si la loi l'exige, tu recueilles le consentement de tes visiteurs.",
  ] },
  { title: "8. Suspension et changements des règles", items: [
    "En cas de manquement, Afrolook Ads peut avertir, suspendre ou fermer le compte et annuler les gains concernés. Tu es prévenu par e-mail avec le motif et tu peux répondre.",
    "Si ces règles changent, leur numéro de version change et tu dois les accepter de nouveau pour ajouter un site ou une application.",
  ] },
];
