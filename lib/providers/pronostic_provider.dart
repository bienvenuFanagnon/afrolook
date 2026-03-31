

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/model_data.dart';

class PronosticProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache
  final Map<String, Pronostic> _pronosticsCache = {};
  final Map<String, StreamSubscription?> _activeSubscriptions = {};

  // Getter pour accéder au cache si besoin
  Map<String, Pronostic> get cache => _pronosticsCache;

  // ========== MÉTHODES DE RÉCUPÉRATION ==========

  // Récupérer un pronostic par son ID
  Future<Pronostic?> getPronosticById(String pronosticId) async {
    // Vérifier le cache
    if (_pronosticsCache.containsKey(pronosticId)) {
      return _pronosticsCache[pronosticId];
    }

    try {
      DocumentSnapshot doc = await _firestore
          .collection('Pronostics')
          .doc(pronosticId)
          .get();

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        var pronostic = Pronostic.fromJson(data);
        _pronosticsCache[pronosticId] = pronostic;
        return pronostic;
      }
    } catch (e) {
      print('Erreur récupération pronostic by ID: $e');
    }
    return null;
  }

  // Récupérer un pronostic par postId
  Future<Pronostic?> getPronosticByPostId(String postId) async {
    // Vérifier le cache
    if (_pronosticsCache.values.any((p) => p.postId == postId)) {
      return _pronosticsCache.values.firstWhere((p) => p.postId == postId);
    }

    try {
      var query = await _firestore
          .collection('Pronostics')
          .where('postId', isEqualTo: postId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        var data = query.docs.first.data();
        data['id'] = query.docs.first.id;
        var pronostic = Pronostic.fromJson(data);
        _pronosticsCache[pronostic.id] = pronostic;
        return pronostic;
      }
    } catch (e) {
      print('Erreur récupération pronostic by postId: $e');
    }
    return null;
  }

  // Stream pour écouter un pronostic en temps réel
  Stream<Pronostic?> streamPronostic(String postId) {
    return _firestore
        .collection('Pronostics')
        .where('postId', isEqualTo: postId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        var pronostic = Pronostic.fromJson(data);
        _pronosticsCache[pronostic.id] = pronostic;
        return pronostic;
      }
      return null;
    });
  }

  // Stream pour tous les pronostics (feed admin)
  Stream<List<Pronostic>> streamAllPronostics({
    PronosticStatut? statut,
    int limit = 20,
  }) {
    Query query = _firestore
        .collection('Pronostics')
        .orderBy('dateCreation', descending: true)
        .limit(limit);

    if (statut != null) {
      query = query.where('statut', isEqualTo: statut.name);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data()as Map<String, dynamic>;
        data['id'] = doc.id;
        var pronostic = Pronostic.fromJson(data  );
        _pronosticsCache[pronostic.id] = pronostic;
        return pronostic;
      }).toList();
    });
  }

  // Récupérer les pronostics d'un utilisateur
  Future<List<Pronostic>> getPronosticsByUser(String userId) async {
    try {
      var query = await _firestore
          .collection('Pronostics')
          .where('createurId', isEqualTo: userId)
          .orderBy('dateCreation', descending: true)
          .get();

      return query.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        var pronostic = Pronostic.fromJson(data);
        _pronosticsCache[pronostic.id] = pronostic;
        return pronostic;
      }).toList();
    } catch (e) {
      print('Erreur récupération pronostics user: $e');
      return [];
    }
  }

  // ========== MÉTHODES DE CRÉATION ==========

  // Créer un nouveau pronostic
  Future<String> createPronostic({
    required String postId,
    required String createurId,
    required Equipe equipeA,
    required Equipe equipeB,
    required String typeAcces,
    required double prixParticipation,
    required double cagnotte,
    int quotaMaxParScore = 10,
    required DateTime dateDebutMatch,
  }) async {
    try {
      var now = DateTime.now();

      var pronostic = Pronostic(
        id: '', // Sera remplacé par l'ID Firestore
        postId: postId,
        createurId: createurId,
        equipeA: equipeA,
        equipeB: equipeB,
        typeAcces: typeAcces,
        prixParticipation: prixParticipation,
        cagnotte: cagnotte,
        quotaMaxParScore: quotaMaxParScore,
        statut: PronosticStatut.OUVERT,
        participationsParScore: {},
        toutesParticipations: [],
        dateCreation: now,
        dateDebutMatch: dateDebutMatch
      );

      DocumentReference docRef = await _firestore
          .collection('Pronostics')
          .add(pronostic.toJson());

      // Mettre à jour avec l'ID
      await docRef.update({'id': docRef.id});

      pronostic.id = docRef.id;
      _pronosticsCache[pronostic.id] = pronostic;

      notifyListeners();
      return docRef.id;
    } catch (e) {
      print('Erreur création pronostic: $e');
      rethrow;
    }
  }

  // ========== MÉTHODES DE MISE À JOUR PARTIELLE ==========

  // 1. Mise à jour du statut uniquement
  Future<void> updateStatut({
    required String pronosticId,
    required PronosticStatut nouveauStatut,
  }) async
  {
    try {
      Map<String, dynamic> updates = {
        'statut': nouveauStatut.name,
      };

      // Ajouter les timestamps correspondants
      switch (nouveauStatut) {
        case PronosticStatut.EN_COURS:
          updates['dateDebutMatch'] = DateTime.now().microsecondsSinceEpoch;
          break;
        case PronosticStatut.TERMINE:
          updates['dateFinMatch'] = DateTime.now().microsecondsSinceEpoch;
          break;
        case PronosticStatut.GAINS_DISTRIBUES:
          updates['dateDistributionGains'] = DateTime.now().microsecondsSinceEpoch;
          break;
        default:
          break;
      }

      await _firestore
          .collection('Pronostics')
          .doc(pronosticId)
          .update(updates);

      // Mettre à jour le cache
      if (_pronosticsCache.containsKey(pronosticId)) {
        _pronosticsCache[pronosticId]?.statut = nouveauStatut;
        // Mettre à jour les dates dans le cache si nécessaire
        if (updates.containsKey('dateDebutMatch')) {
          _pronosticsCache[pronosticId]?.dateDebutMatch = DateTime.now();
        }
        if (updates.containsKey('dateFinMatch')) {
          _pronosticsCache[pronosticId]?.dateFinMatch = DateTime.now();
        }
        if (updates.containsKey('dateDistributionGains')) {
          _pronosticsCache[pronosticId]?.dateDistributionGains = DateTime.now();
        }
      }

      notifyListeners();
    } catch (e) {
      print('Erreur updateStatut: $e');
      rethrow;
    }
  }

  // 2. Mise à jour du score final
  Future<void> updateScoreFinal({
    required String pronosticId,
    required int scoreA,
    required int scoreB,
  })
  async {
    try {
      await _firestore
          .collection('Pronostics')
          .doc(pronosticId)
          .update({
        'scoreFinalEquipeA': scoreA,
        'scoreFinalEquipeB': scoreB,
        'statut': PronosticStatut.TERMINE.name,
        'dateFinMatch': DateTime.now().microsecondsSinceEpoch,
      });

      // Mettre à jour le cache
      if (_pronosticsCache.containsKey(pronosticId)) {
        _pronosticsCache[pronosticId]?.scoreFinalEquipeA = scoreA;
        _pronosticsCache[pronosticId]?.scoreFinalEquipeB = scoreB;
        _pronosticsCache[pronosticId]?.statut = PronosticStatut.TERMINE;
        _pronosticsCache[pronosticId]?.dateFinMatch = DateTime.now();
      }

      notifyListeners();
    } catch (e) {
      print('Erreur updateScoreFinal: $e');
      rethrow;
    }
  }

  // Pour mettre à jour le score pendant le match (sans changer le statut)
  Future<void> updateScore({
    required String pronosticId,
    required int scoreA,
    required int scoreB,
  }) async {
    try {
      await _firestore
          .collection('Pronostics')
          .doc(pronosticId)
          .update({
        'scoreFinalEquipeA': scoreA,
        'scoreFinalEquipeB': scoreB,
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      // Mettre à jour le cache
      if (_pronosticsCache.containsKey(pronosticId)) {
        _pronosticsCache[pronosticId]?.scoreFinalEquipeA = scoreA;
        _pronosticsCache[pronosticId]?.scoreFinalEquipeB = scoreB;
      }

      notifyListeners();
    } catch (e) {
      print('Erreur updateScore: $e');
      rethrow;
    }
  }

  // 3. Ajout d'une participation (avec transaction)
  Future<Map<String, dynamic>> ajouterParticipation({
    required String pronosticId,
    required ParticipationPronostic participation,
  }) async {
    try {
      final pronosticRef = _firestore.collection('Pronostics').doc(pronosticId);
      String scoreKey = participation.scoreKey;

      bool success = await _firestore.runTransaction<bool>((transaction) async {
        // Lire l'état actuel
        DocumentSnapshot snapshot = await transaction.get(pronosticRef);
        if (!snapshot.exists) return false;

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

        // Vérifier le statut
        if (data['statut'] != PronosticStatut.OUVERT.name) {
          throw Exception('Pronostic non ouvert');
        }

        Map<String, dynamic> participationsParScore =
        Map<String, dynamic>.from(data['participationsParScore'] ?? {});
        List<dynamic> toutesParticipations = List.from(data['toutesParticipations'] ?? []);

        // Vérifier le quota
        List<dynamic> participantsPourScore =
        List.from(participationsParScore[scoreKey] ?? []);

        if (participantsPourScore.length >= (data['quotaMaxParScore'] ?? 10)) {
          return false;
        }

        // Vérifier si l'utilisateur a déjà participé
        bool aDejaParticipe = toutesParticipations.any(
                (p) => p['userId'] == participation.userId
        );

        if (aDejaParticipe) {
          throw Exception('Utilisateur a déjà participé');
        }

        // Mettre à jour les structures
        participantsPourScore.add(participation.userId);
        participationsParScore[scoreKey] = participantsPourScore;

        toutesParticipations.add(participation.toJson());

        // Mise à jour atomique
        transaction.update(pronosticRef, {
          'participationsParScore': participationsParScore,
          'toutesParticipations': toutesParticipations,
          'nombreParticipants': FieldValue.increment(1),
          'nombrePronosticsUniques': (participationsParScore as Map).keys.length,
        });

        return true;
      });

      if (success) {
        // Mettre à jour le cache
        if (_pronosticsCache.containsKey(pronosticId)) {
          var pronostic = _pronosticsCache[pronosticId];
          pronostic?.toutesParticipations.add(participation);

          String key = participation.scoreKey;
          if (pronostic?.participationsParScore.containsKey(key) ?? false) {
            pronostic?.participationsParScore[key]?.add(participation.userId);
          } else {
            pronostic?.participationsParScore[key] = [participation.userId];
          }
          pronostic?.nombreParticipants = (pronostic?.nombreParticipants ?? 0) + 1;
          pronostic?.nombrePronosticsUniques = pronostic?.participationsParScore.length ?? 0;
        }

        notifyListeners();

        return {
          'success': true,
          'message': 'Participation ajoutée avec succès',
        };
      } else {
        return {
          'success': false,
          'message': 'Quota atteint pour ce score',
        };
      }
    } catch (e) {
      print('Erreur ajoutParticipation: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // 4. Distribution des gains
  Future<Map<String, dynamic>> distribuerGains({
    required String pronosticId,
    required List<String> gagnantsIds,
    required double gainParGagnant,
  }) async {
    try {
      await _firestore
          .collection('Pronostics')
          .doc(pronosticId)
          .update({
        'gagnantsIds': gagnantsIds,
        'gainParGagnant': gainParGagnant,
        'statut': PronosticStatut.GAINS_DISTRIBUES.name,
        'dateDistributionGains': DateTime.now().microsecondsSinceEpoch,
      });

      // Mettre à jour le cache
      if (_pronosticsCache.containsKey(pronosticId)) {
        _pronosticsCache[pronosticId]?.gagnantsIds = gagnantsIds;
        _pronosticsCache[pronosticId]?.gainParGagnant = gainParGagnant;
        _pronosticsCache[pronosticId]?.statut = PronosticStatut.GAINS_DISTRIBUES;
        _pronosticsCache[pronosticId]?.dateDistributionGains = DateTime.now();
      }

      notifyListeners();

      return {
        'success': true,
        'message': 'Gains distribués avec succès',
        'gagnantsIds': gagnantsIds,
        'gainParGagnant': gainParGagnant,
      };
    } catch (e) {
      print('Erreur distribuerGains: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // 5. Mise à jour de la cagnotte
  Future<void> updateCagnotte({
    required String pronosticId,
    required double nouvelleCagnotte,
  }) async {
    try {
      await _firestore
          .collection('Pronostics')
          .doc(pronosticId)
          .update({'cagnotte': nouvelleCagnotte});

      if (_pronosticsCache.containsKey(pronosticId)) {
        _pronosticsCache[pronosticId]?.cagnotte = nouvelleCagnotte;
      }

      notifyListeners();
    } catch (e) {
      print('Erreur updateCagnotte: $e');
      rethrow;
    }
  }

  // 6. Marquer des participants comme gagnants (avant distribution)
  Future<void> marquerGagnants({
    required String pronosticId,
    required List<String> gagnantsIds,
  }) async {
    try {
      // Récupérer le pronostic
      var pronostic = await getPronosticById(pronosticId);
      if (pronostic == null) return;

      // Mettre à jour chaque participation
      var updatedParticipations = pronostic.toutesParticipations.map((p) {
        if (gagnantsIds.contains(p.userId)) {
          p.estGagnant = true;
        }
        return p;
      }).toList();

      await _firestore
          .collection('Pronostics')
          .doc(pronosticId)
          .update({
        'toutesParticipations': updatedParticipations.map((p) => p.toJson()).toList(),
      });

      if (_pronosticsCache.containsKey(pronosticId)) {
        _pronosticsCache[pronosticId]?.toutesParticipations = updatedParticipations;
      }

      notifyListeners();
    } catch (e) {
      print('Erreur marquerGagnants: $e');
      rethrow;
    }
  }

  // 7. Annuler un pronostic (statut spécial)
  Future<void> annulerPronostic({
    required String pronosticId,
    required String raison,
  }) async {
    try {
      await _firestore
          .collection('Pronostics')
          .doc(pronosticId)
          .update({
        'statut': 'ANNULE',
        'raisonAnnulation': raison,
        'dateAnnulation': DateTime.now().microsecondsSinceEpoch,
      });

      if (_pronosticsCache.containsKey(pronosticId)) {
        _pronosticsCache[pronosticId]?.statut = PronosticStatut.OUVERT; // À ajouter dans l'enum
      }

      notifyListeners();
    } catch (e) {
      print('Erreur annulerPronostic: $e');
      rethrow;
    }
  }

  // ========== MÉTHODES DE SUPPRESSION ==========

  // Supprimer un pronostic (soft delete ou hard delete)
  Future<void> deletePronostic(String pronosticId, {bool softDelete = true}) async {
    try {
      if (softDelete) {
        // Soft delete : juste marquer comme supprimé
        await _firestore
            .collection('Pronostics')
            .doc(pronosticId)
            .update({
          'estSupprime': true,
          'dateSuppression': DateTime.now().microsecondsSinceEpoch,
        });
      } else {
        // Hard delete : supprimer complètement
        await _firestore
            .collection('Pronostics')
            .doc(pronosticId)
            .delete();
      }

      _pronosticsCache.remove(pronosticId);
      notifyListeners();
    } catch (e) {
      print('Erreur deletePronostic: $e');
      rethrow;
    }
  }

  // ========== MÉTHODES UTILITAIRES ==========

  // Calculer les statistiques d'un pronostic
  Map<String, dynamic> calculerStatistiques(Pronostic pronostic) {
    Map<String, int> repartitionScores = {};

    for (var participation in pronostic.toutesParticipations) {
      String key = participation.scoreKey;
      repartitionScores[key] = (repartitionScores[key] ?? 0) + 1;
    }

    return {
      'totalParticipants': pronostic.nombreParticipants,
      'scoresUniques': pronostic.nombrePronosticsUniques,
      'repartitionScores': repartitionScores,
      'tauxRemplissage': (pronostic.nombreParticipants /
          (pronostic.quotaMaxParScore * 100) * 100), // À ajuster
    };
  }

  // Vérifier si un utilisateur peut participer
  Future<Map<String, dynamic>> verifierParticipation({
    required String pronosticId,
    required String userId,
    required int scoreA,
    required int scoreB,
  }) async {
    try {
      var pronostic = await getPronosticById(pronosticId);
      if (pronostic == null) {
        return {
          'peutParticiper': false,
          'raison': 'Pronostic non trouvé',
        };
      }

      // Vérifier statut
      if (pronostic.statut != PronosticStatut.OUVERT) {
        return {
          'peutParticiper': false,
          'raison': 'Ce pronostic n\'est plus ouvert (${pronostic.statut.name})',
        };
      }

      // Vérifier participation existante
      if (pronostic.aDejaParticipe(userId)) {
        return {
          'peutParticiper': false,
          'raison': 'Vous avez déjà participé à ce pronostic',
        };
      }

      // Vérifier quota
      if (!pronostic.isScoreDisponible(scoreA, scoreB)) {
        return {
          'peutParticiper': false,
          'raison': 'Ce score a atteint le quota maximum de ${pronostic.quotaMaxParScore} participants',
          'participantsActuels': pronostic.getNombreParticipantsPourScore(scoreA, scoreB),
          'quotaMax': pronostic.quotaMaxParScore,
        };
      }

      return {
        'peutParticiper': true,
        'raison': 'OK',
        'prix': pronostic.prixParticipation,
        'typeAcces': pronostic.typeAcces,
      };
    } catch (e) {
      print('Erreur verificationParticipation: $e');
      return {
        'peutParticiper': false,
        'raison': 'Erreur: $e',
      };
    }
  }

  // Nettoyer le cache
  void clearCache() {
    _pronosticsCache.clear();

    // Annuler tous les abonnements actifs
    for (var subscription in _activeSubscriptions.values) {
      subscription?.cancel();
    }
    _activeSubscriptions.clear();

    notifyListeners();
  }

  // Souscrire à un pronostic (pour les mises à jour en temps réel)
  void subscribeToPronostic(String pronosticId, Function(Pronostic) onUpdate) {
    // Annuler l'abonnement précédent s'il existe
    _activeSubscriptions[pronosticId]?.cancel();

    var subscription = _firestore
        .collection('Pronostics')
        .doc(pronosticId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        data['id'] = snapshot.id;
        var pronostic = Pronostic.fromJson(data);
        _pronosticsCache[pronosticId] = pronostic;
        onUpdate(pronostic);
        notifyListeners();
      }
    });

    _activeSubscriptions[pronosticId] = subscription;
  }

  // Se désabonner
  void unsubscribeFromPronostic(String pronosticId) {
    _activeSubscriptions[pronosticId]?.cancel();
    _activeSubscriptions.remove(pronosticId);
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}