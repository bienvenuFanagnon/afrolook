// lib/pages/dating/dating_connections_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'dating_chat_page.dart';
import 'dating_subscription_page.dart';

class DatingConnectionsPage extends StatefulWidget {
  const DatingConnectionsPage({Key? key}) : super(key: key);

  @override
  State<DatingConnectionsPage> createState() => _DatingConnectionsPageState();
}

class _DatingConnectionsPageState extends State<DatingConnectionsPage> {
  String? _currentUserId;
  String? _subscriptionPlan;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _currentUserId = authProvider.loginUserData.id;
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final subscription = snapshot.docs.first;
        _subscriptionPlan = subscription['planCode'];
        _isPremium = _subscriptionPlan == 'plus' || _subscriptionPlan == 'gold';
      } else {
        _isPremium = false;
      }
      setState(() {});
    } catch (e) {
      print('❌ Erreur chargement abonnement: $e');
      _isPremium = false;
    }
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.amber),
            const SizedBox(width: 8),
            const Text(
              'Accès au chat',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE63946), Color(0xFFFF69B4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              '💬 Discutez avec vos matchs',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'La messagerie privée est réservée aux membres AfroLove Plus et Gold.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Passez à l\'abonnement Premium pour :',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildFeatureRow('💬 Messages illimités'),
            _buildFeatureRow('❤️ Voir qui vous a liké'),
            _buildFeatureRow('⭐ 2 super likes par jour'),
            _buildFeatureRow('🚀 Profil mis en avant'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DatingSubscriptionPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text(
              'Voir les offres',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 12)),
        ],
      ),
    );
  }

  /// Met à jour la date du dernier message pour remonter la connexion en tête de liste.
  Future<void> _updateConnectionLastMessageAt(String connectionId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await FirebaseFirestore.instance
        .collection('dating_connections')
        .doc(connectionId)
        .update({
      'lastMessageAt': now,
      'updatedAt': now,
    });
  }

  Future<void> _openChat(String connectionId, String otherUserId, DatingProfile otherProfile) async {
    // Met à jour lastMessageAt pour que cette conversation remonte en tête
    await _updateConnectionLastMessageAt(connectionId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingChatPage(
          connectionId: connectionId,
          otherUserId: otherUserId,
          otherUserName: otherProfile.pseudo,
          otherUserImage: otherProfile.imageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Veuillez vous connecter')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💕 Matchs',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            Text(
              'Profils qui vous ont liké mutuellement',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<DatingConnection>>(
        stream: _getUserConnections(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement de vos matchs...'),
                ],
              ),
            );
          }

          final connections = snapshot.data ?? [];

          if (connections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFCDD2), Color(0xFFFCE4EC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      size: 60,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '💔 Aucun match pour le moment',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Likez des profils pour créer des connexions !',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.favorite, color: Colors.white),
                    label: const Text(
                      'Découvrir des profils',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: connections.length,
            itemBuilder: (context, index) {
              final connection = connections[index];
              final otherUserId = connection.userId1 == _currentUserId
                  ? connection.userId2
                  : connection.userId1;

              return FutureBuilder<DatingProfile?>(
                future: _getOtherDatingProfile(otherUserId),
                builder: (context, profileSnapshot) {
                  if (!profileSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final otherProfile = profileSnapshot.data!;
                  final matchDate = DateTime.fromMillisecondsSinceEpoch(connection.createdAt);
                  final formattedDate = _formatMatchDate(matchDate);
                  final isNew = connection.createdAt > DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: () {
                        if (_isPremium) {
                          _openChat(connection.id, otherUserId, otherProfile);
                        } else {
                          _showPremiumDialog();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.red.shade100,
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            if (isNew)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.red, Colors.pink],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.fiber_new, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Nouveau',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Photo de profil avec effet de cœur
                                  Stack(
                                    children: [
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFE63946), Color(0xFFFF69B4)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(35),
                                            child: Image.network(
                                              otherProfile.imageUrl,
                                              width: 66,
                                              height: 66,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.person,
                                                    size: 40,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.favorite,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  // Infos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          otherProfile.pseudo,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.cake,
                                              size: 12,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${otherProfile.age} ans',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(
                                              Icons.location_on,
                                              size: 12,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              otherProfile.pays,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.favorite,
                                                size: 10,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Match du $formattedDate',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Bouton de chat
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _isPremium ? Colors.red.shade50 : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isPremium ? Icons.chat_bubble : Icons.lock,
                                      size: 24,
                                      color: _isPremium ? Colors.red : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatMatchDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDate = DateTime(date.year, date.month, date.day);

    if (matchDate == today) {
      return "aujourd'hui";
    } else if (matchDate == today.subtract(const Duration(days: 1))) {
      return "hier";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  Future<DatingProfile?> _getOtherDatingProfile(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('dating_profiles')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return DatingProfile.fromJson(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Stream<List<DatingConnection>> _getUserConnections(String userId) {
    return FirebaseFirestore.instance
        .collection('dating_connections')
        .where('userId1', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => DatingConnection.fromJson(doc.data()))
        .toList())
        .asyncMap((connections) async {
      final snapshot2 = await FirebaseFirestore.instance
          .collection('dating_connections')
          .where('userId2', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final otherConnections = snapshot2.docs
          .map((doc) => DatingConnection.fromJson(doc.data()))
          .toList();

      final allConnections = [...connections, ...otherConnections];
      allConnections.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return allConnections;
    });
  }
}