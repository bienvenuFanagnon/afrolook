// main_challenge_integration.dart
import 'package:afrotok/pages/challenge/widget/challengeModal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/challenge_controller.dart';
import '../../providers/challenge_provider.dart';

class ChallengeIntegration {
  static void initialize() {
    // Vérifier les challenges au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final challengeController = ChallengeController();
      challengeController.verifierStatutsChallenges();
    });
  }

  static Widget buildChallengeModal(BuildContext context) {
    return Consumer<ChallengeProvider>(
      builder: (context, provider, child) {
        final challengesActifs = provider.challengesActifs
            .where((challenge) => challenge.isEnAttente ||
            (challenge.isTermine &&
                DateTime.now().microsecondsSinceEpoch - (challenge.finishedAt ?? 0) <
                    Duration(days: 5).inMicroseconds))
            .toList();

        if (challengesActifs.isEmpty) return SizedBox.shrink();

        return ChallengeModal(challenge: challengesActifs.first);
      },
    );
  }
}
