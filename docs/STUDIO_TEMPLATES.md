# Studio Afrolook — templates prêts à poster, musique et sons d'artistes

## Templates
- Catalogue : `lib/pages/studio/montage/montage_catalog.dart` (`kMontageTemplates`, 53 templates en 5 catégories :
  Situations, Émotions, Insta, Culture, Fêtes). Pour en ajouter un : une entrée `MontageTemplate(...)` + une ligne dans
  `kTemplateMusic` (musique par défaut).
- Tout est modifiable ou retirable (« Éléments » dans l'éditeur) : sur-titre, titre, texte, badge, logo, @pseudo,
  statistiques, abonnés, effet animé, cadre, teinte, drapeau. Seul le filigrane « Créé sur Afrolook » reste.
- **Statistiques** (comme les cartes) : J'aime et commentaires (exemple propre à chaque template, modifiables, `1400` devient
  `1,4k`) et abonnés (vrai nombre du profil, modifiable). Chaque groupe se retire séparément.

## Musique
- 17 pistes gratuites, **créées par synthèse** (aucun échantillon ni mélodie existante, donc aucun droit à payer) :
  `node functions/scripts/gen_studio_music.cjs <dossier> [id…]` produit `<id>.m4a` (≈30 s, boucle sans coupure,
  loudnorm -14 LUFS, -16 pour les pistes calmes). Elles sont dans Storage `studio_music/<id>.m4a`
  (envoi : copier le dossier avec un compte admin ; le catalogue Dart est `montage_music.dart` → `kStudioTracks`).
- Chaque template propose une musique d'office (`kTemplateMusic`). La personne l'écoute, en choisit une autre, règle le début,
  choisit la durée (photo : 10/15/30 s), garde ou non le son de sa vidéo, ou retire la musique (« Sans musique »).
- Avec une musique, le résultat est **toujours une vidéo** MP4 (assemblée par la Cloud Function `renderStudioMontage`,
  ffmpeg : la musique boucle, fondu d'entrée et de sortie).

## Sons d'artistes (rémunérés)
- **Où l'artiste dépose son son** : bouton « 🎤 Tu es artiste ? Propose ton son » dans (1) l'écran d'accueil du Studio,
  (2) le sélecteur de musique des templates (onglet Artistes), (3) le profil (« Espace artiste : mes sons et mes gains »),
  (4) le fil (bandeau « Sons des artistes »). Il mène à `MyArtistSoundsPage` (ses sons, statuts, utilisations, gains) puis
  `ArtistSoundSubmitPage` (fichier audio ≤ 50 Mo, pochette, titre, genre, **case obligatoire « je détiens les droits »**).
- **Validation** : un admin valide ou refuse dans Admin → « Sons artistes ». Un son non validé n'est jamais proposé.
- **Paiement (100 % côté serveur)** : à la fin d'un montage réussi, `renderStudioMontage` débite la personne de
  `artistSoundPrice` pièces (5 par défaut) et crédite l'artiste de `artistSoundShare` pièces gagnées (3 par défaut, convertibles),
  le reste va aux commissions Afrolook. Réglages : `AppConfig/studio { artistSoundPrice, artistSoundShare }`.
  Une seule fois par montage (`ArtistSoundUses/{uid}_{jobId}`) ; l'artiste qui utilise son propre son ne paie rien ;
  solde insuffisant = montage refusé avant tout calcul ; rien n'est débité si le montage échoue.
  Historique dans `TransactionSoldes` des deux côtés (`purchaseKind: studio_son_artiste`).
- Règles Firestore : un son est créé en `pending_review` (compteurs à 0, droits certifiés) par son auteur ; seuls les admins
  le modifient. L'ancien crédit direct depuis le téléphone a été supprimé.
- Index Firestore `artist_sounds` (status+validatedAt, userId+createdAt, status+createdAt) ajoutés.

## À savoir
- Les pistes sont des instruments synthétiques : correctes pour un fond sonore, pas un vrai studio. De vraies pistes (ou des
  artistes) les remplaceront au fil du temps ; les artistes partenaires passent par le circuit ci-dessus.
- L'aperçu de la musique dans l'éditeur lit le fichier depuis Storage (réseau nécessaire).
