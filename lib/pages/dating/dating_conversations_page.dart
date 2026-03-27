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
            const SizedBox(width: 8),
            const Text(
              'Accès à la messagerie',
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
              '💬 Accédez à vos conversations',
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

  /// Met à jour la date du dernier message pour remonter la conversation en tête de liste.
  Future<void> _updateConversationLastMessageAt(String conversationId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await FirebaseFirestore.instance
        .collection('dating_conversations')
        .doc(conversationId)
        .update({
      'lastMessageAt': now,
      'updatedAt': now,
    });
  }

  Future<void> _openChat(DatingConversation conversation, String otherUserId, DatingProfile otherProfile) async {
    // Met à jour lastMessageAt pour que cette conversation remonte en tête
    await _updateConversationLastMessageAt(conversation.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingChatPage(
          connectionId: conversation.connectionId,
          otherUserId: otherUserId,
          otherUserName: otherProfile.pseudo,
          otherUserImage: otherProfile.imageUrl,
          conversationId: conversation.id,
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
              '💬 Messages',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            Text(
              'Discutez avec vos matchs',
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
      body: StreamBuilder<List<DatingConversation>>(
        stream: _getUserConversations(_currentUserId!),
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
                      Icons.chat_bubble_outline,
                      size: 60,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '💬 Aucun message',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Commencez une conversation avec vos matchs !',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.favorite, color: Colors.white),
                    label: const Text(
                      'Voir mes matchs',
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
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final otherUserId = conversation.userId1 == _currentUserId
                  ? conversation.userId2
                  : conversation.userId1;

              return FutureBuilder<DatingProfile?>(
                future: _getOtherDatingProfile(otherUserId),
                builder: (context, profileSnapshot) {
                  if (!profileSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final otherProfile = profileSnapshot.data!;
                  final unreadCount = _currentUserId == conversation.userId1
                      ? conversation.unreadCountUser1
                      : conversation.unreadCountUser2;

                  final hasUnread = unreadCount > 0;
                  final lastMessageTime = conversation.lastMessageAt ?? conversation.createdAt;
                  final formattedTime = _formatTimeAgo(lastMessageTime);
                  final isNew = lastMessageTime > DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        if (_isPremium) {
                          _openChat(conversation, otherUserId, otherProfile);
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
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: hasUnread ? Colors.red.shade200 : Colors.grey.shade200,
                            width: hasUnread ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Photo de profil avec effet de cœur pour les non lus
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
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(28),
                                        child: Image.network(
                                          otherProfile.imageUrl,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.person,
                                                size: 30,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasUnread)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                    Row(
                                      children: [
                                        Text(
                                          otherProfile.pseudo,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                            color: hasUnread ? Colors.black : Colors.grey.shade800,
                                          ),
                                        ),
                                        if (otherProfile.isVerified)
                                          const SizedBox(width: 8),
                                        if (otherProfile.isVerified)
                                          const Icon(
                                            Icons.verified,
                                            size: 14,
                                            color: Colors.blue,
                                          ),
                                      ],
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
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: hasUnread ? Colors.red.shade700 : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.location_on,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          otherProfile.pays,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.chat_bubble_outline,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
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
                                  const SizedBox(height: 8),
                                  // Bouton de chat
                                  Container(
                                    padding: const EdgeInsets.all(8),
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
}