# Chroniques v2

Décisions validées : commentaires publics et réponse privée gardés tous les deux ; 7 jours d'attente après un refus et 10 invitations par jour ;
pas de bouton partage ; suppression par l'administrateur avec confirmation (sans motif) ; texte limité à 1 000 caractères ; musique avec le barème des montages.

## Écrans
- **Fil** (`chronique_section.dart`) : anneaux, un par personne. Vert et jaune qui tourne doucement = pas vu ; gris = vu ; un segment par chronique.
  « Moi » est toujours en premier (mon anneau, ou « + Ma chronique » en pointillés). Jamais de bloc vide.
- **Liste** (`chroniquehome.dart`) : anneaux, filtres (Pour toi, Abonnements, Populaires, Vidéos, Musique, appliqués aux chroniques déjà chargées),
  recherche par pseudo, deux colonnes de cartes, une pub toutes les 6 personnes, états vide, erreur et chargement.
- **Lecteur** (`chroniquedetails.dart`) : en-tête (profil, ⋯, fermer), pastille vues / j'aime / temps restant, rangée du bas (commentaires, cœur, enveloppe),
  pastille de musique. Texte long défilable avec fondu, durée adaptée (60 ms par caractère, 5 à 45 s), minuteur en pause pendant le geste et les panneaux.
- **Menu ⋯** : ajouter une chronique, voir les commentaires, répondre en privé, voir le profil, supprimer (créateur ; administrateur sur toutes).
- **Commentaires** (`chronique_comments_sheet.dart`) : panneau, 20 par page, j'aime, appui long pour supprimer (auteur, créateur, administrateur), 120 caractères.
- **Création** : ligne « Musique » (texte, image, vidéo), réglage de l'extrait (5 à 30 s), volume, garder ou remplacer le son de la vidéo.

## Musique
Feuille unique « Choisir une musique » (`chronique_music_sheet.dart`), conforme à la maquette validée :
- **Quatre onglets** : Gratuites (musiques d'Afrolook), Artistes (sons d'artistes validés), Ma bibliothèque (titres achetés), Ma voix (enregistrer, 30 s au plus).
- **Recherche** sur les trois premiers onglets (titre, artiste, style) ; la liste des artistes porte sur les 100 sons validés les plus récents.
- **Depuis mon téléphone** : bouton en haut de la feuille (fichier audio de 20 Mo au plus, 3 s au moins).
- Chaque ligne s'écoute avant le choix et porte son prix. **Mêmes règles que partout pour les sons d'artistes** : gratuit = rien à payer ; payant = prix d'utilisation
  (60 % pour l'artiste) débité à la publication ; ses propres sons sont gratuits.
- Onde avec fenêtre de l'extrait (5 à 30 s), volume, et pour une vidéo « garder le son de la vidéo » (mélange) ou le remplacer.
La chronique garde l'adresse de l'**extrait public** (jamais l'original). Ma voix et les fichiers du téléphone sont envoyés avec la chronique (`chronique_voices/`) et supprimés avec elle.
Paiement par la fonction `chroniqueMusicCharge` (une seule fois par chronique). La lecture se fait en boucle dans le lecteur ; la musique globale se met en pause.

**Chronique de type Audio** : on enregistre sa voix (1 minute au plus) ou on choisit un fichier directement dans le formulaire, sans passer par le Studio
(le bouton Studio reste dans la barre du haut pour ceux qui veulent y préparer un contenu).

## Réponse privée : demande de discussion temporaire (comme TikTok)
- Déjà amis : le message part dans la discussion, avec la chronique citée (message `link_share`, type `chronique`).
- Sinon : la fonction `chroniqueReplyInvite` crée une invitation **et** une discussion temporaire (`request_status = pending`) avec la chronique citée et le premier
  message, visibles tout de suite par le destinataire. Une discussion déjà existante entre les deux personnes est réutilisée.
  Règles dans `functions/src/chroniques/replyGate.ts` : bloqué = refus, déjà amis = discussion, invitation en attente = rien, invitation reçue d'elle = on l'accepte,
  refus de moins de 7 jours = attente, 10 par jour.
- **Destinataire** : la discussion apparaît dans sa liste (aperçu « Demande · … »). Dans la discussion, la barre du bas propose Accepter ou Refuser.
  Accepter : l'invitation passe à ACCEPTER (amis), la discussion devient normale, l'autre est prévenu. Refuser : l'invitation passe à REFUSER, la discussion disparaît de sa liste.
- **Personne qui a écrit** : elle voit son message ; la saisie est remplacée par « En attente de la réponse… » (ou « refusé, réessayez dans 7 jours »).
- Accepter ou refuser depuis la page Invitations donne le même résultat : `onInvitationAnswered` recopie l'état de l'invitation dans la discussion.
- La liste des conversations affiche aussi une bannière « N invitations en attente » qui ouvre la page Invitations.
- Limite connue : l'interdiction d'écrire avant acceptation est appliquée par l'application (saisie remplacée). Les messages n'ont pas de règle serveur dédiée, car
  une règle qui lirait la discussion à chaque message coûterait une lecture par message pour tout le monde.

## Économie de lectures et de stockage
- Commentaires lus à la demande (20 par page) au lieu d'une écoute en direct de toute la liste ; dernier commentaire recopié dans la chronique (`lastCommentPseudo`, `lastCommentText`).
- Curseur de pagination pris sur la lecture elle-même (plus de lecture de document en plus à chaque page).
- Profil du créateur lu une fois par ouverture de l'application.
- Liste des sons d'artistes : une lecture gardée 10 minutes au lieu d'une écoute en direct.
- Nettoyage des chroniques expirées : `chroniqueExpiryCleanup` toutes les heures sur le serveur (média, aperçu, commentaires, compteur), au lieu d'un nettoyage lancé par chaque téléphone qui ouvre la liste.
- Aucun flou ni effet coûteux dans les listes ; images en cache disque et en mémoire réduite.

## Chargement rapide (fil et page liste)

- **Une seule requête filtrée** : `where expiresAt > maintenant` + `orderBy createdAt desc` + `limit` (même index que la page liste). Le fil lisait 12 documents pour en garder 6 ; il en lit 6.
- **Première page partagée** (`ChroniqueFirstPage`, 2 min) : le fil garde sa page et son curseur ; la page « Chroniques » s'affiche immédiatement avec, sans lecture, puis ne lit que la suite. Vidée à la publication / suppression.
- **Plus de lecture `Users` bloquante** dans le fil : les anneaux utilisent la photo et le pseudo recopiés dans la chronique.
- **Préchargement** des photos d'auteurs et des aperçus des premières chroniques dès la réponse du serveur.
- **Miniature de 480 px** (`posterUrl`, dossier `chronique_posters`, nettoyée par le ménage horaire) pour les chroniques image : anneaux et cartes ne téléchargent plus l'image entière (anciennes chroniques : repli sur l'image).

## Aperçu dans les anneaux et texte sur image

- L'anneau montre l'aperçu de la **dernière chronique** de la personne (image, aperçu vidéo, texte, pochette) ; sa photo passe en pastille en bas à droite.
- Chronique image/vidéo : le texte tapé s'affiche sur le média et se **glisse où l'on veut** (`textX`/`textY`, 0 à 1, centre du texte) ; le lecteur le replace au même endroit.
