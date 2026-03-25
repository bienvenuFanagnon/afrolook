// lib/providers/dating_provider.dart
import 'package:flutter/material.dart';
import '../../models/chatmodels/models.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../services/dating/dating_service.dart';
import '../authProvider.dart';

class DatingProvider extends ChangeNotifier {
  final DatingService _datingService = DatingService();
  final UserAuthProvider? authProvider;

  DatingProfile? _currentProfile;
  List<DatingProfile> _recommendedProfiles = [];
  bool _isLoading = false;
  String? _error;

  DatingProvider({this.authProvider});

  // Getters
  DatingProfile? get currentProfile => _currentProfile;
  List<DatingProfile> get recommendedProfiles => _recommendedProfiles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Charger le profil actuel
  Future<void> loadCurrentProfile() async {
    if (authProvider?.loginUserData.id == null) return;

    _setLoading(true);
    _error = null;

    try {
      _currentProfile = await _datingService.checkDatingProfileStatus(
          authProvider!.loginUserData.id!
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Créer ou mettre à jour le profil
  Future<bool> saveProfile(DatingProfile profile) async {
    _setLoading(true);
    _error = null;

    try {
      final success = await _datingService.saveDatingProfile(profile);
      if (success) {
        _currentProfile = profile;
        notifyListeners();
        if (authProvider?.loginUserData.id != null) {
          await loadRecommendedProfiles();
        }
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

  // Charger les profils recommandés
  Future<void> loadRecommendedProfiles() async {
    if (authProvider?.loginUserData.id == null) return;

    _setLoading(true);
    _error = null;

    try {
      _datingService.getRecommendedProfiles(authProvider!.loginUserData.id!).listen((profiles) {
        _recommendedProfiles = profiles;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Liker un profil
  Future<bool> likeProfile(String toUserId) async {
    if (authProvider?.loginUserData.id == null) return false;

    _setLoading(true);
    _error = null;

    try {
      return await _datingService.likeProfile(
          authProvider!.loginUserData.id!,
          toUserId
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Envoyer un message
  Future<bool> sendMessage({
    required String conversationId,
    required String receiverId,
    required MessageType type,
    String? text,
    String? mediaUrl,
  }) async {
    if (authProvider?.loginUserData.id == null) return false;

    _setLoading(true);
    _error = null;

    try {
      return await _datingService.sendMessage(
        conversationId: conversationId,
        senderId: authProvider!.loginUserData.id!,
        receiverId: receiverId,
        type: type,
        text: text,
        mediaUrl: mediaUrl,
      );
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