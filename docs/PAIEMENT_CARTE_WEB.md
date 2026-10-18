# Achat de pièces par carte bancaire (site web uniquement)

Mis en place le 17 octobre 2026. Même moteur FeexPay « carte » que SlashAtlas, mêmes identifiants (la clé API est celle du compte
FeexPay ; seul l'identifiant de boutique change : celui d'Afrolook, `FEEXPAY_SHOP_ID`).

## Où c'est visible
- **Site web uniquement** : le bouton « Payer par carte bancaire » n'existe que si `kIsWeb` (écran Recharger, `coin_recharge_screen.dart`).
  Aucun texte ni lien dans les applications Android / iPhone.
- **Serveur** : toutes les fonctions carte refusent une demande dont l'en-tête `Origin` n'est pas afrolookmedia.com (ou les adresses
  afrolooki.web.app / firebaseapp.com). Les applications natives n'envoient pas d'Origin : même un appel direct est rejeté.

## Prix
`prix carte (USD) = ceil( prix du pack en FCFA ÷ 600 ÷ (1 − (6,9 % + 3 %)) , au centime )`
- 6,9 % = frais FeexPay carte internationale (3,9 % + 3 % de conversion), 3 % = marge de sécurité. Tout est payé par l'acheteur.
- Taux fixe 600 FCFA = 1 USD (décision du propriétaire ; le taux réel du jour était ≈ 583).
- Packs : 1 000 / 2 500 / 5 000 / 12 000 / 25 000 / 50 000 pièces → 0,89 / 2,13 / 4,07 / 9,25 / 18,50 / 37,00 USD.
- Pas de TVA ajoutée : prix final payé (la TVA éventuelle d'Afrolook est une question comptable, hors code).

## Parcours et sécurité
1. `cardCoinQuote` : prix et réglages publics. 2. `cardCoinStart` : contrôles (connecté, pack autorisé, CGV acceptées, limites, carte non
bloquée), crée `CardCoinOrders/{id}` puis appelle FeexPay `requesttopay/init`, renvoie l'URL de paiement. 3. Retour de la page FeexPay sur
`/feexpay-callback` → `/app/` : l'accueil web appelle `cardCoinStatus` jusqu'à confirmation.
- **Crédit** (`settleCardOrder`) : uniquement après `single/status/{reference}` = SUCCESSFUL et montant identique (si FeexPay le donne en USD),
  dans une transaction Firestore, une seule fois. Le webhook (`afrolookFeexpayWebhook`) ne fait que relancer cette vérification.
  `cardCoinReconcile` (toutes les 10 min) rattrape un webhook manqué ou un onglet fermé ; une commande non confirmée après 24 h expire.
- **Pièces achetées** : `giftCoinsBalance` + verrou (`lockFieldsAfterChange`), donc dépensables mais non convertibles en argent.
- **Limites** (réglables, valeurs initiales) : 10 paiements/jour/compte, 20/jour/IP, 1 000 USD/mois/compte, alerte admin (e-mail + push) au
  50ᵉ paiement de la journée. Compte obligatoire.
- **Transaction** : `TransactionSoldes` type `ACHAT_PIECES`, moyen « Carte bancaire », montant en USD, net estimé (après frais FeexPay),
  e-mail + notification aux admins (`onPurchaseOrDepositNotify`), journal `PaymentLogs` (`card_start`, `card_check`, `card_settle`, `card_credit`).
- **Preuve** : version des conditions, date, IP hachée et navigateur sont stockés sur la commande ; FeexPay renvoie ses champs financiers (`fx`).

## Réglages (sans redéployer)
Icône carte en haut de « Suivi des paiements » (admin) → `cardCoinAdminConfig` → document `AppConfig/cardPayments` :
`enabled` (interrupteur), `feePct`, `marginPct`, `xofPerUsd`, `packs`, `userPerDay`, `ipPerDay`, `userMonthUsd`, `alertPerDay`.

## Litige (rétrofacturation)
Fonction `cardCoinAdminChargeback({orderId, note})` (admin) : retire les pièces de la commande (le solde peut devenir négatif), passe la
commande en `chargeback` et pose `cardBlocked` sur le compte (carte désactivée pour lui, Mobile Money toujours possible).
Le contrat FeexPay met les litiges à la charge du marchand : la marge de 3 % sert à les amortir.

## À vérifier au premier paiement réel
Pack 1 000 pièces (0,89 $) : la carte est liée au compte FeexPay, mais seul un paiement réel confirme qu'elle est acceptée avec la boutique
Afrolook. Si FeexPay répond `CARD_PAYMENT_NOT_AUTHORIZED`, le message apparaît dans « Suivi des paiements » (étape `card_start`).
