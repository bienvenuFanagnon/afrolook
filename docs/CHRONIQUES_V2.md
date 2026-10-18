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
Choix dans la liste existante du Studio (gratuites d'Afrolook, sons d'artistes). La chronique garde l'adresse de l'**extrait public** (jamais l'original), le début, la fin, le volume.
Paiement à la publication par la fonction `chroniqueMusicCharge` (une seule fois par chronique, 60 % pour l'artiste, gratuit pour ses propres sons et les sons gratuits).
La musique est lue en boucle par le lecteur ; la musique globale de l'application se met en pause pendant la chronique.

## Réponse privée
- Déjà amis : le message part dans la discussion, avec la chronique citée (message `link_share`, type `chronique`).
- Sinon : fonction `chroniqueReplyInvite` crée une invitation (message 1 à 200 caractères, chronique, miniature). Règles dans `functions/src/chroniques/replyGate.ts` :
  bloqué = refus, déjà amis = discussion, invitation en attente = rien, invitation reçue d'elle = on l'accepte, refus de moins de 7 jours = attente, 10 par jour.
- À l'acceptation, `onChroniqueInviteAccepted` ouvre la discussion côté serveur : chronique citée puis message d'invitation, messages non lus pour la personne qui a accepté.
- La page Invitations affiche la chronique et le message.

## Économie de lectures et de stockage
- Commentaires lus à la demande (20 par page) au lieu d'une écoute en direct de toute la liste ; dernier commentaire recopié dans la chronique (`lastCommentPseudo`, `lastCommentText`).
- Curseur de pagination pris sur la lecture elle-même (plus de lecture de document en plus à chaque page).
- Profil du créateur lu une fois par ouverture de l'application.
- Liste des sons d'artistes : une lecture gardée 10 minutes au lieu d'une écoute en direct.
- Nettoyage des chroniques expirées : `chroniqueExpiryCleanup` toutes les heures sur le serveur (média, aperçu, commentaires, compteur), au lieu d'un nettoyage lancé par chaque téléphone qui ouvre la liste.
- Aucun flou ni effet coûteux dans les listes ; images en cache disque et en mémoire réduite.
