// services/remuneration_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/model_data.dart';

enum StatutTransaction { VALIDER, EN_ATTENTE, ECHEC }

class RemunerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fonction utilitaire pour logger avec timestamp
  void _log(String message, {String type = 'INFO'}) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('[$timestamp] $type: $message');
  }

  // ============================================
  // 1. CONFIGURATION
  // ============================================

  Future<RemunerationConfig?> getActiveConfig() async {
    _log('🔍 Récupération de la configuration active...', type: 'PROCESS');

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('RemunerationConfigs')
          .where('estActif', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data() as Map<String, dynamic>;
        data['id'] = snapshot.docs.first.id;

        _log('✅ Configuration trouvée', type: 'SUCCESS');
        return RemunerationConfig.fromJson(data);
      }

      // Configuration par défaut
      return RemunerationConfig(
        nom: 'Configuration par défaut',
        montantParPalier: 200,
        nombreVuesParPalier: 100,
        estActif: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      _log('❌ Erreur récupération config: $e', type: 'ERROR');
      return null;
    }
  }

  // ============================================
  // 2. CALCUL DES GAINS (CŒUR DU SYSTÈME)
  // ============================================

  /// Calcule les gains d'un post en fonction des vues et des paiements déjà effectués
  Future<Map<String, dynamic>> calculerGainsPost(Post post, RemunerationConfig config) async {
    try {
      // Récupérer le dernier encaissement pour ce post
      QuerySnapshot encaissements = await _firestore
          .collection('EncaissementsPost')
          .where('postId', isEqualTo: post.id)
          .orderBy('dateEncaissement', descending: true)
          .limit(1)
          .get();

      // Nombre de paliers déjà payés pour ce post
      int paliersDejaPayes = 0;
      if (encaissements.docs.isNotEmpty) {
        var dernier = EncaissementPost.fromJson(
            encaissements.docs.first.data() as Map<String, dynamic>
        );
        paliersDejaPayes = dernier.paliersEncaisses;
      }

      int vuesActuelles = post.vues ?? 0;

      // Calcul des paliers
      int paliersTotal = vuesActuelles ~/ config.nombreVuesParPalier;
      int paliersNonPayes = paliersTotal - paliersDejaPayes;

      // Ne garder que les paliers complets
      if (paliersNonPayes < 0) paliersNonPayes = 0;

      double montantGagnable = paliersNonPayes * config.montantParPalier;

      return {
        'post': post,
        'postId': post.id,
        'vuesActuelles': vuesActuelles,
        'paliersTotal': paliersTotal,
        'paliersDejaPayes': paliersDejaPayes,
        'paliersNonPayes': paliersNonPayes,
        'montantGagnable': montantGagnable,
      };
    } catch (e) {
      _log('❌ Erreur calcul gains pour post ${post.id}: $e', type: 'ERROR');
      rethrow;
    }
  }

  /// Récupère les posts des 5 derniers mois avec suffisamment de vues
  Future<List<Post>> getPostsCinqDerniersMois(String userId, int seuilVuesMinimum) async {
    _log('📅 Récupération des posts des 5 derniers mois', type: 'PROCESS');

    try {
      DateTime maintenant = DateTime.now();
      DateTime dateLimite = DateTime(maintenant.year, maintenant.month - 5, 1);
      int timestampLimite = dateLimite.microsecondsSinceEpoch;

      QuerySnapshot postsSnapshot = await _firestore
          .collection('Posts')
          .where('user_id', isEqualTo: userId)
          .where('created_at', isGreaterThanOrEqualTo: timestampLimite)
          .where('vues', isGreaterThanOrEqualTo: seuilVuesMinimum)
          .orderBy('created_at', descending: true)
          .get();

      List<Post> posts = [];
      for (var doc in postsSnapshot.docs) {
        var postData = doc.data() as Map<String, dynamic>;
        postData['id'] = doc.id;
        posts.add(Post.fromJson(postData));
      }

      _log('✅ ${posts.length} posts trouvés', type: 'SUCCESS');
      return posts;
    } catch (e) {
      _log('❌ Erreur: $e', type: 'ERROR');
      return [];
    }
  }

  /// Calcule tous les gains avec progression
  Future<Map<String, dynamic>> calculerTousGains(
      String userId,
      RemunerationConfig config,
      Function(int current, int total, Post post) onProgress,
      ) async {
    _log('🚀 Calcul des gains pour l\'utilisateur: $userId', type: 'PROCESS');

    try {
      int seuilMinimum = config.nombreVuesParPalier;
      List<Post> posts = await getPostsCinqDerniersMois(userId, seuilMinimum);
      int totalPosts = posts.length;

      List<Map<String, dynamic>> gainsParPost = [];
      double totalGains = 0.0;
      int postsAvecGains = 0;

      for (var i = 0; i < posts.length; i++) {
        var post = posts[i];

        _log('🔄 Traitement ${i+1}/$totalPosts: ${post.id}', type: 'PROCESS');

        var gains = await calculerGainsPost(post, config);

        if (gains['montantGagnable'] > 0) {
          postsAvecGains++;
          gainsParPost.add(gains);
          totalGains += gains['montantGagnable'];

          _log('  ✅ +${gains['montantGagnable']} FCFA (${gains['paliersNonPayes']} paliers)', type: 'DATA');
        }

        onProgress(i + 1, totalPosts, post);
      }

      _log('✅ Calcul terminé: $totalGains FCFA', type: 'SUCCESS');

      return {
        'totalGains': totalGains,
        'gainsParPost': gainsParPost,
        'postsTraites': totalPosts,
        'postsAvecGains': postsAvecGains,
      };
    } catch (e) {
      _log('❌ Erreur: $e', type: 'ERROR');
      rethrow;
    }
  }

  // ============================================
  // 3. ENCAISSEMENT (NOUVELLE VERSION)
  // ============================================

  /// Vérifie si un encaissement est en cours (moins de 60 secondes)
  Future<bool> isEncaissementEnCours(String userId) async {
    try {
      DateTime uneMinute = DateTime.now().subtract(Duration(seconds: 60));
      int timestampLimite = uneMinute.microsecondsSinceEpoch;

      QuerySnapshot transactions = await _firestore
          .collection('TransactionSoldes')
          .where('user_id', isEqualTo: userId)
          .where('type', isEqualTo: 'ENCAISSEMENT_POST')
          .where('createdAt', isGreaterThanOrEqualTo: timestampLimite)
          .limit(1)
          .get();

      return transactions.docs.isNotEmpty;
    } catch (e) {
      _log('❌ Erreur vérification: $e', type: 'ERROR');
      return false;
    }
  }

  /// Encaissement sécurisé des gains
  Future<Map<String, dynamic>> encaisserGains(
      String userId,
      List<Map<String, dynamic>> gainsParPost, // Liste des posts avec leurs gains
      double montantTotal,
      ) async {
    _log('💰 ENCAISSEMENT', type: 'PROCESS');
    _log('  - Utilisateur: $userId', type: 'DATA');
    _log('  - Montant: $montantTotal FCFA', type: 'DATA');
    _log('  - Posts: ${gainsParPost.length}', type: 'DATA');

    try {
      // 🔒 VÉRIFICATION 1: Encaissement en cours ?
      if (await isEncaissementEnCours(userId)) {
        return {
          'success': false,
          'error': 'Un encaissement est déjà en cours (moins de 60s)',
          'code': 'ENCAISSEMENT_EN_COURS',
        };
      }

      // 🔒 VÉRIFICATION 2: Montant valide ?
      if (montantTotal <= 0 || gainsParPost.isEmpty) {
        return {
          'success': false,
          'error': 'Aucun gain à encaisser',
          'code': 'AUCUN_GAIN',
        };
      }

      // ✅ TRANSACTION ATOMIQUE FIRESTORE
      String transactionId = await _firestore.runTransaction((transaction) async {

        // 1. Créer les EncaissementPost pour chaque post
        List<String> encaissementPostIds = [];

        for (var gain in gainsParPost) {
          if (gain['montantGagnable'] <= 0) continue;

          // Créer l'encaissement pour ce post
          final encaissementPost = EncaissementPost(
            userId: userId,
            postId: gain['postId'],
            nombreVuesAuMomentEncaissement: gain['vuesActuelles'],
            paliersEncaisses: gain['paliersNonPayes'], // 👌 Les nouveaux paliers payés
            montantEncaisser: gain['montantGagnable'],
            periodeId: '', // Optionnel, on peut laisser vide
            dateEncaissement: DateTime.now().microsecondsSinceEpoch,
            statistiques: {
              'vuesAvant': gain['vuesActuelles'] - (gain['paliersNonPayes'] * 100),
              'paliersDejaPayesAvant': gain['paliersDejaPayes'],
            },
          );

          DocumentReference ref = _firestore.collection('EncaissementsPost').doc();
          transaction.set(ref, encaissementPost.toJson());
          encaissementPostIds.add(ref.id);
        }

        // 2. Créer la transaction principale
        final transactionDoc = TransactionSolde()
          ..id = _firestore.collection('TransactionSoldes').doc().id
          ..user_id = userId
          ..type = 'ENCAISSEMENT_POST'
          ..statut = StatutTransaction.VALIDER.name
          ..description = 'Encaissement de $montantTotal FCFA (${gainsParPost.length} posts)'
          ..montant = montantTotal
          ..methode_paiement = "solde_principal"
          ..createdAt = DateTime.now().millisecondsSinceEpoch
          ..updatedAt = DateTime.now().millisecondsSinceEpoch;

        transaction.set(
            _firestore.collection('TransactionSoldes').doc(transactionDoc.id!),
            transactionDoc.toJson()
        );

        // 3. Mettre à jour le solde de l'utilisateur
        DocumentReference userRef = _firestore.collection('Users').doc(userId);
        transaction.update(userRef, {
          'votre_solde_principal': FieldValue.increment(montantTotal),
          'votre_solde': FieldValue.increment(montantTotal),
          // 'updatedAt': DateTime.now().microsecondsSinceEpoch,
        });

        return transactionDoc.id!;
      });

      _log('✅ Encaissement réussi !', type: 'SUCCESS');
      _log('  - Transaction: $transactionId', type: 'DATA');

      return {
        'success': true,
        'montant': montantTotal,
        'transactionId': transactionId,
        'nombrePosts': gainsParPost.length,
      };

    } catch (e) {
      _log('❌ Erreur encaissement: $e', type: 'ERROR');
      return {
        'success': false,
        'error': e.toString(),
        'code': 'ERREUR_GENERALE',
      };
    }
  }

  // ============================================
  // 4. HISTORIQUE
  // ============================================

  /// Récupère l'historique des encaissements
  Future<List<Map<String, dynamic>>> getHistoriqueEncaissements(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('TransactionSoldes')
          .where('user_id', isEqualTo: userId)
          .where('type', isEqualTo: 'ENCAISSEMENT_POST')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _log('❌ Erreur historique: $e', type: 'ERROR');
      return [];
    }
  }
}