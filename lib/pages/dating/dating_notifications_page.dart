// lib/pages/dating/dating_notifications_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../component/consoleWidget.dart';
import 'dating_profile_detail_page.dart';

class DatingNotificationsPage extends StatefulWidget {
  const DatingNotificationsPage({Key? key}) : super(key: key);

  @override
  State<DatingNotificationsPage> createState() => _DatingNotificationsPageState();
}

class _DatingNotificationsPageState extends State<DatingNotificationsPage> {
  String? _currentUserId;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _currentUserId = authProvider.loginUserData.id;
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Notifications')
          .where('receiver_id', isEqualTo: _currentUserId)
          .where('type', isGreaterThanOrEqualTo: 'DATING_')
          .where('is_open', isEqualTo: false)
          .get();

      setState(() {
        _unreadCount = snapshot.docs.length;
      });
      print('📊 Notifications non lues: $_unreadCount');
    } catch (e) {
      print('❌ Erreur chargement compteur notifications: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Notifications')
          .doc(notificationId)
          .update({
        'is_open': true,
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      });
      _loadUnreadCount();
    } catch (e) {
      print('❌ Erreur marquage notification comme lue: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '🔔 Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                if (_unreadCount > 0)
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              'Vos interactions récentes',
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Notifications')
            .where('receiver_id', isEqualTo: _currentUserId)
            .where('type', isGreaterThanOrEqualTo: 'DATING_')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            printVm('Erreur: ${snapshot.error}');
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
                  Text('Chargement...'),
                ],
              ),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
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
                      Icons.notifications_none,
                      size: 60,
                      color: Colors.red.shade400,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Aucune notification',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Les notifications apparaîtront ici',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notificationData = notifications[index].data();
              final notification = NotificationData.fromJson(notificationData as Map<String, dynamic>);

              final type = notification.type ?? '';
              final title = notification.titre ?? '';
              final description = notification.description ?? '';
              final mediaUrl = notification.media_url;
              final userId = notification.user_id ?? '';
              final createdAt = notification.createdAt ?? 0;
              final isOpen = notification.is_open ?? false;
              final notificationId = notification.id ?? '';

              final date = DateTime.fromMicrosecondsSinceEpoch(createdAt);
              final isNew = !isOpen;

              IconData icon;
              Color iconColor;
              Color bgColor;

              if (type.contains('MATCH')) {
                icon = Icons.favorite;
                iconColor = Colors.red;
                bgColor = Colors.red.shade50;
              } else if (type.contains('SUPER_LIKE')) {
                icon = Icons.star;
                iconColor = Colors.amber;
                bgColor = Colors.amber.shade50;
              } else if (type.contains('LIKE')) {
                icon = Icons.favorite_border;
                iconColor = Colors.pink;
                bgColor = Colors.pink.shade50;
              } else {
                icon = Icons.notifications;
                iconColor = Colors.grey;
                bgColor = Colors.grey.shade50;
              }

              return GestureDetector(
                onTap: () async {
                  if (!isOpen) {
                    await _markAsRead(notificationId);
                  }
                  _navigateToProfile(userId);
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: isNew ? Colors.red.shade200 : Colors.grey.shade200,
                        width: isNew ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Icône de notification
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: bgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              size: 24,
                              color: iconColor,
                            ),
                          ),
                          SizedBox(width: 16),
                          // Contenu
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatDate(date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isNew ? Colors.red : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Image de profil si disponible
                          if (mediaUrl != null && mediaUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Image.network(
                                mediaUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Colors.grey.shade400,
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (!isOpen)
                            Container(
                              margin: EdgeInsets.only(left: 8),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifDate = DateTime(date.year, date.month, date.day);

    if (notifDate == today) {
      return "Aujourd'hui à ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } else if (notifDate == today.subtract(Duration(days: 1))) {
      return "Hier à ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  void _navigateToProfile(String userId) {
    if (userId.isEmpty) return;

    FirebaseFirestore.instance
        .collection('dating_profiles')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get()
        .then((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final profile = DatingProfile.fromJson(snapshot.docs.first.data());
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DatingProfileDetailPage(profile: profile),
          ),
        );
      }
    });
  }
}