// services/retraitService.dart

import 'dart:async';

import 'package:afrotok/pages/component/consoleWidget.dart';
import '../models/model_data.dart';
import 'api/retrait_mapper.dart';
import 'api/wallet_api.dart';

/// Retraits : demande manuelle via l'API (aucun paiement automatique). L'équipe valide ou annule ; l'API rembourse le solde en cas d'annulation.
class RetraitService {
  /// Dernière explication d'échec (message en français), lisible par l'écran après un `false`.
  static String? lastError;

  /// Faire une demande de retrait (heures d'ouverture, solde et dette sont vérifiés par l'API).
  static Future<bool> demanderRetrait({
    required String userId,
    required double montant,
    required String methodPaiement,
    required String numeroCompte,
    required String countryCode,
    required UserData userData,
    Map<String, dynamic>? extra, // devise, montant local, taux, type de retrait…
  }) async {
    lastError = null;
    try {
      if (montant <= 0) throw Exception('Montant invalide');
      await WalletApi.instance.requestWithdrawal(
        amountXof: montant.round(),
        method: methodPaiement,
        accountNumber: numeroCompte,
        countryCode: countryCode,
        meta: extra,
      );
      printVm('✅ Demande de retrait créée: $montant FCFA pour $countryCode');
      return true;
    } catch (e) {
      lastError = WalletApi.message(e, fallback: 'Demande de retrait impossible');
      printVm('❌ Erreur demande retrait: $e');
      return false;
    }
  }

  /// 🔄 Valider un retrait (équipe) : le paiement a été fait à la main.
  static Future<bool> validerRetrait({required String retraitId, required String adminId}) async {
    lastError = null;
    try {
      await WalletApi.instance.payWithdrawal(retraitId);
      return true;
    } catch (e) {
      lastError = WalletApi.message(e);
      printVm('❌ Erreur validation retrait: $e');
      return false;
    }
  }

  /// 🚫 Annuler un retrait (équipe) : le solde est remboursé par l'API.
  static Future<bool> annulerRetrait({required String retraitId, required String adminId, required String motif}) async {
    lastError = null;
    try {
      await WalletApi.instance.rejectWithdrawal(retraitId, motif);
      return true;
    } catch (e) {
      lastError = WalletApi.message(e);
      printVm('❌ Erreur annulation retrait: $e');
      return false;
    }
  }

  /// Relit [load] tout de suite puis toutes les [every]. Les erreurs sont transmises au flux (l'écran affiche « Réessayer »).
  static Stream<List<TransactionRetrait>> _poll(Future<List<TransactionRetrait>> Function() load, {Duration every = const Duration(seconds: 30)}) async* {
    while (true) {
      yield await load();
      await Future<void>.delayed(every);
    }
  }

  /// 📊 Mes retraits (côté personne : seuls les 4 derniers chiffres du compte sont renvoyés)
  static Stream<List<TransactionRetrait>> getRetraitsUtilisateur(String userId) =>
      _poll(() async => (await WalletApi.instance.myWithdrawals()).map(retraitFromApi).toList());

  static Future<List<TransactionRetrait>> _allAdmin() async {
    final lists = await Future.wait([
      WalletApi.instance.adminWithdrawals(status: 'pending'),
      WalletApi.instance.adminWithdrawals(status: 'paid'),
      WalletApi.instance.adminWithdrawals(status: 'rejected'),
    ]);
    final all = lists.expand((l) => l).map(retraitFromApi).toList()..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    return all;
  }

  /// 🔍 Retraits recherchés par e-mail, pseudo ou identifiant (équipe). Filtre fait ici : l'API n'a pas encore de recherche (voir lacunes).
  static Stream<List<TransactionRetrait>> searchRetraitsByEmail(String email) {
    final q = email.trim().toLowerCase();
    return _poll(() async => (await _allAdmin())
        .where((r) => (r.userEmail ?? '').toLowerCase().contains(q) || (r.userPseudo ?? '').toLowerCase().contains(q) || (r.userId ?? '').toLowerCase() == q)
        .toList());
  }

  /// 🔍 Retraits recherchés par numéro de transaction (« RET… ») ou identifiant de demande (équipe).
  static Stream<List<TransactionRetrait>> searchRetraitsByNumero(String numero) {
    final q = numero.trim().toLowerCase();
    return _poll(() async => (await _allAdmin()).where((r) => (r.numeroTransaction ?? '').toLowerCase() == q || (r.id ?? '').toLowerCase() == q).toList());
  }

  /// 👑 Tous les retraits (équipe)
  static Stream<List<TransactionRetrait>> getAllRetraits() => _poll(_allAdmin);
}
