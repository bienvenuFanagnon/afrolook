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
            SizedBox(width: 8),
            Text(
              'Accès au chat',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.pink.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline, size: 40, color: Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              '💬 Discutez avec vos matchs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'La messagerie privée est réservée aux membres AfroLove Plus et Gold.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Passez à l\'abonnement Premium pour :',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            SizedBox(height: 12),
            _buildFeatureRow('💬 Messages illimités'),
            _buildFeatureRow('❤️ Voir qui vous a liké'),
            _buildFeatureRow('⭐ 2 super likes par jour'),
            _buildFeatureRow('🚀 Profil mis en avant'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DatingSubscriptionPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
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
          Icon(Icons.check_circle, size: 16, color: Colors.green),
          SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        body: Center(child: Text('Veuillez vous connecter')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💕 Matchs',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            Text(
              'Profils qui vous ont liké mutuellement',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
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
                  SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
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
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade100, Colors.pink.shade100],
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
                  SizedBox(height: 24),
                  Text(
                    '💔 Aucun match pour le moment',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Likez des profils pour créer des connexions !',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.favorite, color: Colors.white),
                    label: Text(
                      'Découvrir des profils',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            padding: EdgeInsets.all(16),
            itemCount: connections.length,
            itemBuilder: (context, index) {
              final connection = connections[index];
              final otherUserId = connection.userId1 == _currentUserId
                  ? connection.userId2
                  : connection.userId1;

              return FutureBuilder<UserData?>(
                future: _getOtherUser(otherUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return SizedBox.shrink();
                  }

                  final otherUser = userSnapshot.data!;
                  final matchDate = DateTime.fromMillisecondsSinceEpoch(connection.createdAt);
                  final formattedDate = _formatMatchDate(matchDate);

                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: () {
                        if (_isPremium) {
                          _openChat(connection.id, otherUserId, otherUser);
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
                              offset: Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.red.shade100,
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Badge "Nouveau match" si récent
                            if (connection.createdAt > DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.red, Colors.pink],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fiber_new, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
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
                              padding: EdgeInsets.all(16),
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
                                          gradient: LinearGradient(
                                            colors: [Colors.red.shade400, Colors.pink.shade400],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(2),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(35),
                                            child: Image.network(
                                              otherUser.imageUrl ?? '',
                                              width: 66,
                                              height: 66,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey.shade200,
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 40,
                                                    color: Colors.grey.shade400,
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
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: Icon(
                                            Icons.favorite,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 16),
                                  // Infos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          otherUser.pseudo ?? 'Utilisateur',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.cake,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              _calculateAge(otherUser),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Icon(
                                              Icons.location_on,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              otherUser.userPays?.name ?? 'Pays',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.favorite,
                                                size: 10,
                                                color: Colors.green.shade700,
                                              ),
                                              SizedBox(width: 4),
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
                                    padding: EdgeInsets.all(10),
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

  String _calculateAge(UserData user) {
    if (user.createdAt == null) return '?';
    final birthDate = DateTime.fromMillisecondsSinceEpoch(user.createdAt!);
    final now = DateTime.now();
    final age = now.year - birthDate.year;
    return '$age ans';
  }

  String _formatMatchDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDate = DateTime(date.year, date.month, date.day);

    if (matchDate == today) {
      return "aujourd'hui";
    } else if (matchDate == today.subtract(Duration(days: 1))) {
      return "hier";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  void _openChat(String connectionId, String otherUserId, UserData otherUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingChatPage(
          connectionId: connectionId,
          otherUserId: otherUserId,
          otherUserName: otherUser.pseudo ?? 'Utilisateur',
          otherUserImage: otherUser.imageUrl ?? '',
        ),
      ),
    );
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

  Future<UserData?> _getOtherUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserData.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}