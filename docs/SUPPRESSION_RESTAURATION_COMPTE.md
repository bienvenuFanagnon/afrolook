# Suppression et restauration d'un compte

## Suppression (par l'utilisateur)
`requestAccountDeletion` : accès coupé tout de suite (connexion désactivée, sessions révoquées), compte en
`PENDING_DELETION`, effacement définitif au bout de **15 jours** (`purgeDeletedAccounts`). Alerte e-mail à l'équipe.

## Restauration (par un admin, pendant les 15 jours)
Admin → recherche d'utilisateur → fiche → encadré rouge → **Restaurer le compte** (`restoreDeletedAccount`).

- **Par défaut, la restauration est payante** : le compte passe en `RESTORE_FEE_DUE`, la connexion est réactivée,
  mais l'application affiche seulement l'écran « Ton compte a été restauré » (`AccountRestoreFeeScreen`) : toutes les
  activités sont bloquées tant que le déblocage n'est pas payé en pièces (`payRestoreFee`). Si le solde est
  insuffisant, l'écran propose **Recharger mes pièces**, puis la personne paie.
- **Prix** : même barème que le déblocage d'un compte inactif depuis 20 jours (`canalUnlockCost`, selon les abonnés :
  < 100 → 500, < 2 000 → 1 500, < 3 000 → 2 000, sinon 3 000 pièces). Prix unique possible : `AppConfig/accountRestore`
  `{ "priceCoins": 500 }`.
- **Sans frais** : case « Sans frais (erreur de notre part) » dans la boîte de restauration (`waiveFee`) : compte actif
  tout de suite. Un compte déjà restauré mais pas encore débloqué peut aussi être offert (bouton « Offrir le déblocage »).
- Une fois le déblocage payé (ou offert), `lastPostAt` repart de « maintenant » : la règle des 20 jours d'inactivité
  ne redemande pas un second paiement.
- Les pièces sont retirées du solde de pièces (`giftCoinsBalance`), une transaction `deblocage_compte` est écrite et
  le gain est compté dans les commissions du jour (« déblocages »).
- Les champs `accountStatus`, `restoreFeeDue`, `deletionScheduledAt`, `deletionRequestedAt` ne sont modifiables que
  par le serveur (règles Firestore).

## Limite à connaître
Le blocage complet est appliqué par l'application (écran affiché au démarrage, comme la suspension de compte). Côté
serveur, seules les règles existantes s'appliquent aux comptes non débloqués après 20 jours d'inactivité
(publications refusées, création de canal / groupe / live refusée). Un client modifié pourrait donc encore faire
d'autres actions pendant `RESTORE_FEE_DUE`.
