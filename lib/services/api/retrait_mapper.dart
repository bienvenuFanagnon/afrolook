import 'package:afrotok/models/model_data.dart';

import 'wallet_api.dart';

/// Convertit une demande de retrait de l'API vers le modèle d'affichage existant ([TransactionRetrait]).
/// Statuts : pending → EN_ATTENTE, paid → VALIDER, rejected → ANNULE.
TransactionRetrait retraitFromApi(WithdrawalRow w) {
  final j = w.json;
  final created = w.createdAt?.millisecondsSinceEpoch ?? 0;
  final statut = switch (w.status) { 'paid' => 'VALIDER', 'rejected' => 'ANNULE', _ => 'EN_ATTENTE' };
  final meta = w.meta;
  return TransactionRetrait(
    id: w.id,
    userId: w.userId,
    userPseudo: (j['user_pseudo'] ?? j['username'] ?? meta['user_pseudo']) as String?,
    userEmail: (j['user_email'] ?? meta['user_email']) as String?,
    userPhone: (j['user_phone'] ?? meta['user_phone']) as String?,
    montant: w.amountXof.toDouble(),
    statut: statut,
    description: 'Retrait ${w.method} - ${w.account} (${w.countryCode})',
    motifAnnulation: w.status == 'rejected' ? w.note : null,
    numeroTransaction: 'RET${w.id}',
    countryCode: w.countryCode,
    createdAt: created,
    updatedAt: created,
    methodPaiement: w.method,
    numeroCompte: w.account,
  );
}
