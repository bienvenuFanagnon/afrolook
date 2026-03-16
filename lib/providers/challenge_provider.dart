// challenge_provider.dart
import 'package:flutter/material.dart';

import '../models/model_data.dart';
import '../pages/challenge/widget/challengeModal.dart';
import 'challenge_controller.dart';

class ChallengeProvider with ChangeNotifier {
  final ChallengeController _controller = ChallengeController();
  List<Challenge> _challengesActifs = [];
  bool _loading = false;
  String? _error;

  List<Challenge> get challengesActifs => _challengesActifs;
  bool get loading => _loading;
  String? get error => _error;

  ChallengeProvider() {
    _initialize();
  }

  void _initialize() async {
    await _loadChallengesActifs();
    _startPeriodicVerification();
  }

  Future<void> _loadChallengesActifs() async {
    try {
      _loading = true;
      notifyListeners();

      // Écouter les challenges actifs
      _controller.getChallengesActifs().listen((challenges) {
        _challengesActifs = challenges;
        _loading = false;
        _error = null;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  void _startPeriodicVerification() {
    // Vérifier les statuts toutes les minutes
    Future.delayed(Duration(minutes: 1), () async {
      await _controller.verifierStatutsChallenges();
      _startPeriodicVerification();
    });
  }

  Future<void> participerAuChallenge(
      String challengeId,
      String description,
      List<String> mediaUrls,
      String typeMedia
      ) async {
    try {
      await _controller.inscrireAuChallenge(challengeId, description, mediaUrls, typeMedia);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> voterPourPost(String challengeId, String postId) async {
    try {
      await _controller.voterPourPost(challengeId, postId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}