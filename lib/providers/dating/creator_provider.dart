// lib/providers/creator_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../services/dating/creator_service.dart';
import '../authProvider.dart';

class CreatorProvider extends ChangeNotifier {
  final CreatorService _creatorService = CreatorService();
  final UserAuthProvider? authProvider;

  CreatorProfile? _currentCreatorProfile;
  List<CreatorProfile> _creatorsList = [];
  List<CreatorContent> _creatorContents = [];
  bool _isLoading = false;
  bool _isSubscribed = false;
  String? _error;

  CreatorProvider({this.authProvider});

  // Getters
  CreatorProfile? get currentCreatorProfile => _currentCreatorProfile;
  List<CreatorProfile> get creatorsList => _creatorsList;
  List<CreatorContent> get creatorContents => _creatorContents;
  bool get isLoading => _isLoading;
  bool get isSubscribed => _isSubscribed;
  String? get error => _error;

  // Créer un profil créateur
  Future<bool> createCreatorProfile(CreatorProfile profile) async {
    _setLoading(true);
    _error = null;

    try {
      final success = await _creatorService.createCreatorProfile(profile);
      if (success) {
        _currentCreatorProfile = profile;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Charger le profil créateur
  Future<void> loadCreatorProfile(String creatorId) async {
    _setLoading(true);
    _error = null;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('creator_profiles')
          .doc(creatorId)
          .get();

      if (snapshot.exists) {
        _currentCreatorProfile = CreatorProfile.fromJson(snapshot.data()!);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // S'abonner à un créateur
  Future<bool> subscribeToCreator({
    required String creatorId,
    bool isPaid = false,
    int? paidCoinsAmount,
  }) async {
    if (authProvider?.loginUserData.id == null) return false;

    _setLoading(true);
    _error = null;

    try {
      final success = await _creatorService.subscribeToCreator(
        userId: authProvider!.loginUserData.id!,
        creatorId: creatorId,
        isPaid: isPaid,
        paidCoinsAmount: paidCoinsAmount,
      );

      if (success) {
        _isSubscribed = true;
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Vérifier l'abonnement
  Future<void> checkSubscription(String creatorId) async {
    if (authProvider?.loginUserData.id == null) return;

    try {
      _isSubscribed = await _creatorService.isSubscribedToCreator(
          authProvider!.loginUserData.id!,
          creatorId
      );
      notifyListeners();
    } catch (e) {
      print('Erreur vérification abonnement: $e');
    }
  }

  // Charger les contenus d'un créateur
  void loadCreatorContents(String creatorId) {
    _creatorService.getCreatorContents(creatorId).listen((contents) {
      _creatorContents = contents;
      notifyListeners();
    });
  }

  // Publier un contenu
  Future<bool> publishContent(CreatorContent content) async {
    _setLoading(true);
    _error = null;

    try {
      final success = await _creatorService.publishContent(content);
      if (success && _currentCreatorProfile != null) {
        if (content.isPaid) {
          _currentCreatorProfile = _currentCreatorProfile!.copyWith(
            paidContentsCount: (_currentCreatorProfile!.paidContentsCount + 1),
          );
        } else {
          _currentCreatorProfile = _currentCreatorProfile!.copyWith(
            freeContentsCount: (_currentCreatorProfile!.freeContentsCount + 1),
          );
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Réagir à un contenu
  Future<bool> reactToContent({
    required String contentId,
    required String creatorId,
    required ReactionType reactionType,
  }) async {
    if (authProvider?.loginUserData.id == null) return false;

    try {
      return await _creatorService.reactToContent(
        contentId: contentId,
        creatorId: creatorId,
        userId: authProvider!.loginUserData.id!,
        reactionType: reactionType,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Acheter un contenu payant
  Future<bool> purchasePaidContent({
    required String contentId,
    required String creatorId,
    required int priceCoins,
  }) async {
    if (authProvider?.loginUserData.id == null) return false;

    _setLoading(true);
    _error = null;

    try {
      return await _creatorService.purchasePaidContent(
        contentId: contentId,
        creatorId: creatorId,
        buyerUserId: authProvider!.loginUserData.id!,
        priceCoins: priceCoins,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}