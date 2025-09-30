// challenge_modal.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/challenge_controller.dart';

class ChallengeModal extends StatefulWidget {
  final Challenge challenge;

  const ChallengeModal({Key? key, required this.challenge}) : super(key: key);

  @override
  _ChallengeModalState createState() => _ChallengeModalState();
}

class _ChallengeModalState extends State<ChallengeModal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challengeController = Provider.of<ChallengeController>(context);

    return ScaleTransition(
      scale: _animation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade100, Colors.purple.shade100],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildCountdown(),
              const SizedBox(height: 20),
              _buildPrizeInfo(),
              const SizedBox(height: 20),
              _buildActionButton(challengeController),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.emoji_events, color: Colors.amber, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.challenge.titre ?? 'Challenge',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildCountdown() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final startTime = widget.challenge.endInscriptionAt ?? 0;
    final timeLeft = startTime - now;

    if (timeLeft <= 0) {
      return Text(
        'Challenge en cours!',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
      );
    }

    final duration = Duration(microseconds: timeLeft);
    return Column(
      children: [
        Text('Début dans:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTimeUnit(duration.inDays, 'Jours'),
            _buildTimeUnit(duration.inHours.remainder(24), 'Heures'),
            _buildTimeUnit(duration.inMinutes.remainder(60), 'Minutes'),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeUnit(int value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildPrizeInfo() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.red),
              const SizedBox(width: 10),
              Text(
                'Prix à gagner:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${widget.challenge.prix ?? 0} FCFA',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          if (widget.challenge.descriptionCadeaux != null) ...[
            const SizedBox(height: 5),
            Text(
              widget.challenge.descriptionCadeaux!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(ChallengeController controller) {
    final user = FirebaseAuth.instance.currentUser;
    final isInscrit = widget.challenge.isInscrit(user?.uid);

    if (widget.challenge.isTermine) {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          // Naviguer vers la page des résultats
        },
        icon: Icon(Icons.emoji_events),
        label: Text('Voir les résultats'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
        ),
      );
    } else if (isInscrit) {
      return Text(
        'Vous êtes inscrit!',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
      );
    } else if (widget.challenge.inscriptionsOuvertes) {
      return ElevatedButton(
        onPressed: () {
          Navigator.of(context).pop();
          _showInscriptionModal(context, controller);
        },
        child: Text('S\'inscrire au challenge'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 50),
        ),
      );
    } else {
      return Text(
        'Inscriptions fermées',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      );
    }
  }

  void _showInscriptionModal(BuildContext context, ChallengeController controller) {
    // Implémentation du modal d'inscription
  }
}