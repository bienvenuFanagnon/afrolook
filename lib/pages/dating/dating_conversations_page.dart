// lib/pages/dating/dating_conversations_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'dating_chat_page.dart';
import 'dating_subscription_page.dart';

class DatingConversationsPage extends StatefulWidget {
  const DatingConversationsPage({Key? key}) : super(key: key);

  @override
  State<DatingConversationsPage> createState() => _DatingConversationsPageState();
}

class _DatingConversationsPageState extends State<DatingConversationsPage> {
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
              'Accès à la messagerie',
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
              '💬 Accédez à vos conversations',
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
              '💬 Messages',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            Text(
              'Discutez avec vos matchs',
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
      body: StreamBuilder<List<DatingConversation>>(
        stream: _getUserConversations(_currentUserId!),
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
                  Text('Chargement de vos messages...'),
                ],
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
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
                      Icons.chat_bubble_outline,
                      size: 60,
                      color: Colors.red.shade400,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    '💬 Aucun message',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Commencez une conversation avec vos matchs !',
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
                      'Voir mes matchs',
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
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final otherUserId = conversation.userId1 == _currentUserId
                  ? conversation.userId2
                  : conversation.userId1;

              return FutureBuilder<UserData?>(
                future: _getOtherUser(otherUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return SizedBox.shrink();
                  }

                  final otherUser = userSnapshot.data!;
                  final unreadCount = _currentUserId == conversation.userId1
                      ? conversation.unreadCountUser1
                      : conversation.unreadCountUser2;

                  final hasUnread = unreadCount > 0;
                  final lastMessageTime = conversation.lastMessageAt ?? conversation.createdAt;
                  final formattedTime = _formatTimeAgo(lastMessageTime);

                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        if (_isPremium) {
                          _openChat(conversation, otherUserId, otherUser);
                        } else {
                          _showPremiumDialog();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: hasUnread ? Colors.red.shade50 : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: hasUnread ? Colors.red.shade200 : Colors.grey.shade200,
                            width: hasUnread ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Photo de profil avec statut en ligne
                              Stack(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: hasUnread
                                            ? [Colors.red.shade400, Colors.pink.shade400]
                                            : [Colors.grey.shade300, Colors.grey.shade400],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: hasUnread
                                              ? Colors.red.withOpacity(0.3)
                                              : Colors.grey.withOpacity(0.2),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(2),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(28),
                                        child: Image.network(
                                          otherUser.imageUrl ?? '',
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: Icon(
                                                Icons.person,
                                                size: 30,
                                                color: Colors.grey.shade400,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Badge de message non lu
                                  if (hasUnread)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: Text(
                                          '$unreadCount',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                    Row(
                                      children: [
                                        Text(
                                          otherUser.pseudo ?? 'Utilisateur',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                            color: hasUnread ? Colors.black : Colors.grey.shade800,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        if (otherUser.isVerify ?? false)
                                          Icon(
                                            Icons.verified,
                                            size: 14,
                                            color: Colors.blue,
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: 12,
                                          color: hasUnread ? Colors.red : Colors.grey.shade500,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          _calculateAge(otherUser),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: hasUnread ? Colors.red.shade700 : Colors.grey.shade600,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.location_on,
                                          size: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          otherUser.userPays?.name ?? 'Pays',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 12,
                                          color: hasUnread ? Colors.red : Colors.grey.shade500,
                                        ),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            conversation.lastMessage ?? 'Nouvelle conversation',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: hasUnread
                                                  ? Colors.red.shade700
                                                  : Colors.grey.shade600,
                                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Heure du dernier message
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: hasUnread ? Colors.red : Colors.grey.shade500,
                                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  // Bouton de chat
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _isPremium
                                          ? (hasUnread ? Colors.red : Colors.grey.shade100)
                                          : Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isPremium ? Icons.chat_bubble : Icons.lock,
                                      size: 18,
                                      color: _isPremium
                                          ? (hasUnread ? Colors.red : Colors.grey.shade600)
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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

  String _formatTimeAgo(int timestamp) {
    final now = DateTime.now();
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'maintenant';
    } else if (difference.inHours < 1) {
      return 'il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'il y a ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'hier';
    } else if (difference.inDays < 7) {
      return 'il y a ${difference.inDays} j';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  void _openChat(DatingConversation conversation, String otherUserId, UserData otherUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingChatPage(
          connectionId: conversation.connectionId,
          otherUserId: otherUserId,
          otherUserName: otherUser.pseudo ?? 'Utilisateur',
          otherUserImage: otherUser.imageUrl ?? '',
          conversationId: conversation.id,
        ),
      ),
    );
  }

  Stream<List<DatingConversation>> _getUserConversations(String userId) {
    return FirebaseFirestore.instance
        .collection('dating_conversations')
        .where('userId1', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => DatingConversation.fromJson(doc.data()))
        .toList())
        .asyncMap((conversations) async {
      final snapshot2 = await FirebaseFirestore.instance
          .collection('dating_conversations')
          .where('userId2', isEqualTo: userId)
          .get();

      final otherConversations = snapshot2.docs
          .map((doc) => DatingConversation.fromJson(doc.data()))
          .toList();

      final allConversations = [...conversations, ...otherConversations];
      allConversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return allConversations;
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