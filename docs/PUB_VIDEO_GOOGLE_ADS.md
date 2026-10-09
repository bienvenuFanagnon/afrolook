# Vidéo publicitaire Afrolook : scénario et mise en ligne

## Idée directrice
Différence d'Afrolook : **c'est le réseau qui paie ses créateurs** (vues, likes, cadeaux). Toute la vidéo oppose « ailleurs, tu offres ton contenu » à « ici, c'est toi qui es payé », puis finit sur les deux stores.
Aucun montant ni revenu garanti n'est affiché (règles Google sur les gains financiers) ; la fin rappelle que les gains dépendent de l'activité.

## Scénario (32 s)
| Temps | Image | Voix off | Son |
|---|---|---|---|
| 0:00-0:04 | Fond noir, trois lignes qui claquent : « TES VUES. TES LIKES. ÇA VAUT DE L'ARGENT. » ; pluie de pièces | « Tes vues. Tes likes. Ça vaut de l'argent. » | Pop, pièce, montée de tension |
| 0:05-0:09 | « AILLEURS : TU POSTES. TU CRÉES. ILS ENCAISSENT. » (rouge) | « Ailleurs, tu postes... et ce sont eux qui encaissent. » | Whoosh, musique sourde |
| 0:09-0:13 | Explosion verte, logo : « SUR AFROLOOK, C'EST TOI QUI ES PAYÉ. » | « Sur Afrolook, c'est toi qui es payé. » | Montée puis drop, beat afro complet |
| 0:13-0:18 | Trois cartes : VUES = PIÈCES, LIKES = PIÈCES, CADEAUX = PIÈCES | « Chaque palier de vues. Chaque like. Chaque cadeau en direct. » | Une pièce par carte |
| 0:18-0:21 | Écran des gains, bouton « Retirer mes gains », « Demande envoyée » | « Tes gains s'affichent. Tu les retires. » | Clic, succès |
| 0:21-0:24 | Logo : « AFROLOOK, LE RÉSEAU QUI TE PAIE. » | « Afrolook. Le réseau qui te paie. » | Succès |
| 0:24-0:32 | Fin : « TÉLÉCHARGE AFROLOOK », GRATUIT, boutons Google Play et App Store, flèche qui rebondit | « Télécharge-le maintenant. Gratuit sur Google Play et sur l'App Store. » | Pops, pièce |

Pourquoi ça marche sans clic : les 2 premières secondes posent la promesse (pas de logo d'abord), le « ailleurs / ici » crée le contraste, les stores sont dits à voix haute et écrits (on retient le nom même sans cliquer), la fin dure 8 s.

## Fichiers
`ad_9x16.mp4` (vertical, YouTube Shorts / Discover / Play), `ad_1x1.mp4` (carré), `ad_16x9.mp4` (horizontal). Le fichier vidéo n'est pas versionné (poids).

## Mise en ligne dans Google Ads
1. Google Ads n'accepte pas de fichier vidéo : envoyer les 3 fichiers sur une chaîne YouTube (Afrolook), en « Non répertorié ».
2. Dans la campagne pour application : section « Vidéos » → coller les liens YouTube (jusqu'à 20). Mettre au moins le vertical et l'horizontal.
3. Titre YouTube : « Afrolook, le réseau qui te paie » ; description : lien Play Store et App Store.
4. Les badges officiels « Disponible sur Google Play » / « App Store » ont des règles de marque : la vidéo utilise des boutons texte neutres. Si Google ou Apple demandent les badges officiels, remplacer les boutons de la dernière scène (`scene_end` dans `tools/pub_video/render.py`).
