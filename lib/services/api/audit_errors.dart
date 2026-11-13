import 'package:afrolook_api_client/afrolook_api_client.dart';

import '../../l10n/tr.dart';

/// Contexte de l'erreur : certains codes de l'API (plafond, compte trop récent, minimum…) ne disent pas la même chose selon l'écran.
enum ErrorScope { generic, withdrawal, views, conversion, defi, admin, share }

/// Correctifs de l'audit de sécurité du 01/11/2026 côté application : conversion par lots de 25 pièces, e-mail non vérifié,
/// nouveaux codes d'erreur de l'API (retraits, encaissement des vues, défis, administration), validation à deux des retraits.
/// Aucun calcul d'argent ici : l'application affiche ce que l'API renvoie.
class AuditErrors {
  AuditErrors._();

  /// Lot de conversion des pièces gagnées en FCFA (25 pièces = 10 FCFA). L'API refuse tout autre nombre (`coins_not_multiple`).
  static const int conversionStep = 25;

  /// Arrondi vers le bas au lot de conversion le plus proche (0 si moins d'un lot).
  static int roundDownToStep(int coins, {int step = conversionStep}) => coins <= 0 || step <= 0 ? 0 : coins - coins % step;

  /// Le nombre de pièces est-il déjà un multiple du lot ?
  static bool isMultipleOfStep(int coins, {int step = conversionStep}) => coins > 0 && step > 0 && coins % step == 0;

  /// 403 `email_unverified` : la route exige un e-mail confirmé (voir [EmailVerificationGate]).
  static bool isEmailUnverified(Object e) => e is ApiException && e.code == 'email_unverified';

  /// La personne a déjà vu la fenêtre « Confirme ton e-mail » (ouverte par le client d'API) et a renoncé : pas de seconde fenêtre.
  static bool emailPromptDeclined(Object e) => isEmailUnverified(e) && (e as ApiException).details['declined'] == true;

  /// Message traduit pour un code connu de l'API, ou null si le code n'est pas l'un de ceux de l'audit.
  /// Les messages de l'API sont en français : ici ils sont remplacés par des textes traduits dans la langue de la personne.
  static String? known(Object e, {ErrorScope scope = ErrorScope.generic}) {
    if (e is! ApiException) return null;
    switch (e.code) {
      case 'post_cooldown':
        // délai entre deux publications : le temps RESTANT (ancien serveur : sans `remaining_seconds`, on garde le message de l'API)
        final left = (e.details['remaining_seconds'] as num?)?.toInt();
        if (left == null) return null;
        final min = (left / 60).ceil().clamp(1, 999);
        return min > 1
            ? tr('Patientez encore {n} minutes avant de publier à nouveau (les abonnés Premium et les médias filmés avec l\'application publient sans délai).', {'n': min})
            : tr('Patientez encore 1 minute avant de publier à nouveau (les abonnés Premium et les médias filmés avec l\'application publient sans délai).');
      case 'email_unverified':
        return tr('Confirme ton e-mail pour utiliser cette fonction.');
      case 'coins_not_multiple':
        final step = (e.details['step'] as num?)?.toInt() ?? conversionStep;
        return tr('Les pièces se convertissent par lots de {n}. Choisis un multiple de {n} : le montant est arrondi vers le bas.', {'n': step});
      case 'below_minimum':
        return switch (scope) {
          ErrorScope.withdrawal => tr('Le montant est inférieur au minimum de retrait.'),
          ErrorScope.views => tr("Le montant est inférieur au minimum d'encaissement."),
          _ => tr('Le montant est inférieur au minimum autorisé.'),
        };
      case 'account_too_young':
        return switch (scope) {
          ErrorScope.withdrawal => tr('Ton compte est trop récent pour retirer de l’argent. Réessaie dans quelques jours.'),
          ErrorScope.views => tr('Ton compte est trop récent pour encaisser tes gains de vues. Réessaie dans quelques jours.'),
          _ => tr('Ton compte est trop récent pour cette opération. Réessaie dans quelques jours.'),
        };
      case 'daily_cap_reached':
        return scope == ErrorScope.withdrawal
            ? tr('Tu as atteint le plafond de retrait des dernières 24 heures. Réessaie plus tard.')
            : tr("Tu as atteint le plafond d'encaissement du jour. Réessaie demain.");
      case 'weekly_cap_reached':
        return tr('Tu as atteint le plafond de retrait de la semaine. Réessaie plus tard.');
      case 'too_soon':
        return tr('Un encaissement vient d’être fait. Patiente une minute avant de recommencer.');
      case 'exceeds_available':
        return tr('Le montant dépasse tes gains de vues disponibles.');
      case 'closed':
        return tr('Le service de retrait est fermé pour le moment. Il ouvre du lundi au vendredi de 8 h à 17 h et le samedi de 8 h à 14 h (heure de Lomé).');
      case 'debt_outstanding':
        return tr('Tu as une dette en cours : rembourse-la avant de continuer.');
      case 'insufficient_funds':
        return switch (scope) {
          ErrorScope.conversion => tr('Seules tes pièces gagnées sont convertibles.'),
          ErrorScope.withdrawal => tr('Ton solde est insuffisant pour ce retrait.'),
          _ => null,
        };
      case 'creator_cannot_participate':
        return tr('Tu es le créateur de ce DÉFI : tu ne peux pas y participer.');
      case 'creator_cannot_vote':
        return tr('Tu es le créateur de ce DÉFI : tu ne peux pas voter pour les participants.');
      case 'self_withdrawal':
        return tr('Tu ne peux pas traiter ta propre demande de retrait.');
      case 'second_validation_required':
        return tr('Ce retrait doit d’abord être validé par une personne de l’équipe, puis payé par une autre.');
      case 'request_not_pending':
        return tr('Cette demande a déjà été traitée.');
      case 'payment_reference_required':
        return tr("Indique la référence du paiement de l'annonceur pour activer la campagne.");
      case 'second_approver_required':
        return tr('Une autre personne que le créateur doit approuver une campagne de ce montant.');
      case 'self_decision':
        return tr('Tu ne peux pas approuver ton propre profil de partageur.');
      case 'reason_required':
        return tr('Un motif est obligatoire pour refuser.');
    }
    return null;
  }

  /// Message prêt à afficher : texte traduit du code, sinon message de l'API (français), sinon [fallback].
  /// Une erreur réseau donne toujours le message de connexion (jamais de repli sur Firebase).
  static String message(Object e, {ErrorScope scope = ErrorScope.generic, String fallback = 'Une erreur est survenue. Réessaie.'}) {
    if (e is ApiException && e.isNetwork) return tr('Connexion impossible. Vérifie ta connexion puis réessaie.');
    final k = known(e, scope: scope);
    if (k != null) return k;
    if (e is ApiException && e.message.isNotEmpty) return e.message;
    return tr(fallback);
  }

  /// Signaux de risque que l'API joint à une demande de retrait (`meta.risk`), traduits pour l'équipe.
  static String riskLabel(String code) => switch (code) {
        'new_account' => tr('Compte de moins de 30 jours'),
        'recent_gains' => tr('Gains convertis ou encaissés dans les dernières 24 h'),
        'second_validation_required' => tr('Gros montant : deux personnes de l’équipe doivent approuver'),
        _ => code,
      };
}

/// Étape où en est une demande de retrait côté équipe (validation à deux dès le seuil fixé par l'API, `needs_second_validation`).
enum WithdrawalStep {
  /// Montant sous le seuil, ou déjà validé par une autre personne : le paiement est possible.
  payable,

  /// Gros montant, personne n'a encore validé : le bouton « Valider » (1re approbation) est proposé.
  needsFirstValidation,

  /// Gros montant déjà validé PAR MOI : un second approbateur doit payer.
  waitingSecondApprover,
}

/// Étape d'une demande. [validatedBy] : identifiant de la personne qui a validé en premier ; [me] : identifiant de la personne connectée.
WithdrawalStep withdrawalStep({required bool needsSecondValidation, required String? validatedBy, required String? me}) {
  if (!needsSecondValidation) return WithdrawalStep.payable;
  if (validatedBy == null || validatedBy.isEmpty) return WithdrawalStep.needsFirstValidation;
  return validatedBy == me ? WithdrawalStep.waitingSecondApprover : WithdrawalStep.payable;
}
