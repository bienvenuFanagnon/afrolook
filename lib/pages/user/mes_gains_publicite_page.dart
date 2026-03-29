// lib/pages/remuneration/mes_gains_publicite_page.dart

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MesGainsPublicitePage extends StatefulWidget {
  final String userId;

  const MesGainsPublicitePage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<MesGainsPublicitePage> createState() => _MesGainsPublicitePageState();
}

class _MesGainsPublicitePageState extends State<MesGainsPublicitePage> {
  late Future<UserData> _userFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUserData();
  }

  Future<UserData> _loadUserData() async {
    final doc = await _firestore.collection('Users').doc(widget.userId).get();
    if (doc.exists) {
      return UserData.fromJson(doc.data() as Map<String, dynamic>);
    } else {
      throw Exception('Utilisateur non trouvé');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Gains Publicitaires',
          style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<UserData>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          final user = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(user),
                const SizedBox(height: 20),
                _buildExplanationCard(),
                const SizedBox(height: 20),
                _buildComingSoonCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(UserData user) {
    final totalCoins = user.totalCoinsEarnedFromAdSupport ?? 0;
    final totalViews = user.totalAdViewsSupported ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: Color(0xFFFFD700), size: 28),
              const SizedBox(width: 10),
              const Text(
                'Vos gains',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildGainRow('Pièces gagnées', '$totalCoins 🪙', const Color(0xFF4CAF50)),
          const Divider(color: Colors.white24),
          _buildGainRow('Soutiens reçus', '$totalViews 👥', Colors.lightBlue),
        ],
      ),
    );
  }

  Widget _buildGainRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2A1E), Color(0xFF0D1A0D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFFFD700)),
              SizedBox(width: 8),
              Text(
                'Comment ça fonctionne ?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Google diffuse des publicités sur vos posts via Afrolook. '
                'Chaque fois qu\'un de vos abonnés, amis ou visiteurs regarde une publicité sur votre contenu, '
                'vous recevez 10 pièces.',
            style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ces pièces pourront bientôt être converties en argent réel (FCFA ou Euro) '
                'et retirées sur votre compte principal Afrolook.',
            style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.emoji_events, color: Color(0xFFFFD700)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎯 Jusqu\'à 400€ par mois possibles si vous développez votre communauté !',
                    style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.shade400),
      ),
      child: Column(
        children: [
          const Icon(Icons.construction, size: 48, color: Color(0xFFFFD700)),
          const SizedBox(height: 12),
          const Text(
            '💱 Conversion en argent réel',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'La fonctionnalité de conversion de vos pièces en argent réel arrivera très bientôt.\n'
                'Nous travaillons activement pour vous permettre de retirer vos gains (jusqu\'à 400€ par mois) '
                'directement sur votre compte Afrolook.',
            style: TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              '🔜 Bientôt disponible',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}