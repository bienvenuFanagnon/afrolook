// DatingConnectionsPage - Liste des connexions (matchs)

// lib/pages/dating/dating_connections_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'dating_chat_page.dart';

class DatingConnectionsPage extends StatefulWidget {
  const DatingConnectionsPage({Key? key}) : super(key: key);

  @override
  State<DatingConnectionsPage> createState() => _DatingConnectionsPageState();
}

class _DatingConnectionsPageState extends State<DatingConnectionsPage> {
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
          'Mes connexions',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<DatingConnection>>(
        stream: _getUserConnections(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final connections = snapshot.data ?? [];

          if (connections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aucune connexion pour le moment',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Likez des profils pour créer des connexions',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text('Découvrir des profils'),
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
              final otherUserId = connection.userId1 == currentUserId
                  ? connection.userId2
                  : connection.userId1;

              return FutureBuilder<UserData?>(
                future: _getOtherUser(otherUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return SizedBox.shrink();
                  }

                  final otherUser = userSnapshot.data!;
                  final lastMessage = connection.lastMessageAt != null
                      ? _formatLastMessageTime(connection.lastMessageAt!)
                      : 'Nouvelle connexion';

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
                              connectionId: connection.id,
                              otherUserId: otherUserId,
                              otherUserName: otherUser.pseudo ?? 'Utilisateur',
                              otherUserImage: otherUser.imageUrl ?? '',
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
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
                                    lastMessage,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (connection.lastMessageAt != null)
                              Text(
                                _formatTimeAgo(connection.lastMessageAt!),
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
      // Ajouter les connexions où l'utilisateur est userId2
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

  String _formatLastMessageTime(int timestamp) {
    final now = DateTime.now();
    final messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(messageTime);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else {
      return '${difference.inDays} j';
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