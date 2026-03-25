// lib/pages/dating/dating_likes_list_page.dart
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'dating_profile_detail_page.dart';

class DatingLikesListPage extends StatefulWidget {
  const DatingLikesListPage({Key? key}) : super(key: key);

  @override
  State<DatingLikesListPage> createState() => _DatingLikesListPageState();
}

class _DatingLikesListPageState extends State<DatingLikesListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _currentUserId = authProvider.loginUserData.id;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '❤️ Mes likes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            Text(
              'Personnes qui vous ont liké et vos likes',
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
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white24),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.favorite), text: 'Reçus'),
                Tab(icon: Icon(Icons.thumb_up), text: 'Envoyés'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLikesList(isReceived: true),
          _buildLikesList(isReceived: false),
        ],
      ),
    );
  }

  Widget _buildLikesList({required bool isReceived}) {
    final collection = 'dating_likes';
    final field = isReceived ? 'toUserId' : 'fromUserId';
    final title = isReceived ? 'Personnes qui vous ont liké' : 'Personnes que vous avez likées';
    final emptyIcon = isReceived ? Icons.favorite_border : Icons.thumb_up_off_alt;
    final emptyTitle = isReceived ? 'Aucun like reçu' : 'Aucun like envoyé';
    final emptyMessage = isReceived
        ? 'Les personnes qui vous likent apparaîtront ici'
        : 'Les profils que vous likez apparaîtront ici';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(field, isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        printVm('Erreur: ${snapshot.error}');
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
                Text('Chargement...'),
              ],
            ),
          );
        }

        final likes = snapshot.data?.docs ?? [];

        if (likes.isEmpty) {
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
                    emptyIcon,
                    size: 60,
                    color: Colors.red.shade400,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  emptyTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 32),
                if (!isReceived)
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
          itemCount: likes.length,
          itemBuilder: (context, index) {
            final like = likes[index];
            final userId = isReceived ? like['fromUserId'] : like['toUserId'];
            final createdAt = like['createdAt'] as int;
            final date = DateTime.fromMillisecondsSinceEpoch(createdAt);

            return FutureBuilder<UserData?>(
              future: _getUserData(userId),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return SizedBox.shrink();
                }

                final user = userSnapshot.data!;
                final isNew = createdAt > DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;

                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      _navigateToProfile(userId);
                    },
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
                            // Photo de profil
                            Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: isNew
                                          ? [Colors.red.shade400, Colors.pink.shade400]
                                          : [Colors.grey.shade300, Colors.grey.shade400],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isNew
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
                                        user.imageUrl ?? '',
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
                                if (isNew)
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
                                        size: 10,
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
                                    user.pseudo ?? 'Utilisateur',
                                    style: TextStyle(
                                      fontSize: 16,
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
                                        _calculateAge(user),
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
                                        user.userPays?.name ?? 'Pays',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isNew ? Colors.red.shade50 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 10,
                                          color: isNew ? Colors.red : Colors.grey,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          _formatDate(date),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isNew ? Colors.red : Colors.grey.shade600,
                                            fontWeight: isNew ? FontWeight.w500 : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Bouton voir profil
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 20,
                                color: Colors.red,
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
        );
      },
    );
  }

  String _calculateAge(UserData user) {
    if (user.createdAt == null) return '?';
    final birthDate = DateTime.fromMillisecondsSinceEpoch(user.createdAt!);
    final now = DateTime.now();
    final age = now.year - birthDate.year;
    return '$age ans';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final likeDate = DateTime(date.year, date.month, date.day);

    if (likeDate == today) {
      return "Aujourd'hui";
    } else if (likeDate == today.subtract(Duration(days: 1))) {
      return "Hier";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  Future<UserData?> _getUserData(String userId) async {
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

  void _navigateToProfile(String userId) {
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