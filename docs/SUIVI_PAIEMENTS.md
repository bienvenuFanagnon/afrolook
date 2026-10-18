# Suivi des paiements

**Où voir** : application, profil administrateur → tableau de bord → « Suivi des paiements ».
Compteurs du jour (réussis / en erreur par fournisseur), journal filtrable (« Erreurs » ou « Tout », par fournisseur), détail copiable.

**Ce qui est consigné** (collection `PaymentLogs`, écrite par le serveur seulement, lisible par l'administration) :
| Fournisseur | Étapes suivies |
|---|---|
| FeexPay (Mobile Money / carte) | démarrage, envoi à l'opérateur, confirmation (webhook), vérification du statut, crédit |
| CinetPay, PayGate | démarrage, confirmation, crédit, secret de webhook invalide |
| Google Play, App Store | vérification de l'achat (toute erreur), crédit |
| Application | achat refusé ou coupé avant d'arriver au serveur (`paymentReport`) ; annulation par la personne consignée sans alerte |

**Alertes** : chaque erreur envoie un e-mail à l'administration (`officiel.afrolook@gmail.com`, `jorbienvenu@gmail.com`), au plus **un par fournisseur toutes les 10 minutes**, avec le nombre d'erreurs non envoyées depuis. Les annulations par la personne ne déclenchent pas d'e-mail.

**Paiements bloqués** : toutes les 15 minutes, un paiement Mobile Money / carte démarré il y a plus de 30 minutes et jamais confirmé est signalé une fois (la personne a peut-être payé sans être créditée : à vérifier chez FeexPay).

**Technique** : `functions/src/payments/paymentLog.ts` (`logPayment`, `withPaymentLog`, `paymentReport`, `paymentWatchdog`) ; `PaymentStats/{jour}` pour les compteurs ; `lib/services/payment_report.dart` côté application ; `lib/pages/admin/payment_logs_admin_page.dart`.
**Pas encore suivis** : les achats de pièces avec le solde (`buyCoinsWithBalance`) et les retraits.

Paiement par carte (site web) : étapes `card_start`, `card_check`, `card_settle`, `card_credit` du fournisseur FeexPay, voir `PAIEMENT_CARTE_WEB.md`.
