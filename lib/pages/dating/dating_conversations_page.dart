//DatingConversationsPage - Liste des conversations

// lib/pages/dating/dating_conversations_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'dating_chat_page.dart';


class DatingConversationsPage extends StatefulWidget {
  const DatingConversationsPage({Key? key}) : super(key: key);

  @override
  State<DatingConversationsPage> createState() => _DatingConversationsPageState();
}

class _DatingConversationsPageState extends State<DatingConversationsPage> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) {
      return Scaffold(
        body: Center(child: Text('Veuillez vous connecter')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Messages',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<DatingConversation>>(
        stream: _getUserConversations(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aucun message',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Commencez une conversation avec vos connexions',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
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
              final otherUserId = conversation.userId1 == currentUserId
                  ? conversation.userId2
                  : conversation.userId1;

              return FutureBuilder<UserData?>(
                future: _getOtherUser(otherUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return SizedBox.shrink();
                  }

                  final otherUser = userSnapshot.data!;
                  final unreadCount = currentUserId == conversation.userId1
                      ? conversation.unreadCountUser1
                      : conversation.unreadCountUser2;

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () {
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
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Image.network(
                                    otherUser.imageUrl ?? '',
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 60,
                                        height: 60,
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
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    otherUser.pseudo ?? 'Utilisateur',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    conversation.lastMessage ?? 'Nouvelle conversation',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: unreadCount > 0
                                          ? Colors.black
                                          : Colors.grey.shade600,
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (conversation.lastMessageAt != null)
                              Text(
                                _formatTimeAgo(conversation.lastMessageAt!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
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

  String _formatTimeAgo(int timestamp) {
    final now = DateTime.now();
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'à l\'instant';
    } else if (difference.inHours < 1) {
      return 'il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'il y a ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'hier';
    } else {
      return 'il y a ${difference.inDays} j';
    }
  }
}