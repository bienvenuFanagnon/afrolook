// lib/pages/dating/dating_super_likes_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../component/consoleWidget.dart';
import 'dating_profile_detail_page.dart';

class DatingSuperLikesPage extends StatefulWidget {
  const DatingSuperLikesPage({Key? key}) : super(key: key);

  @override
  State<DatingSuperLikesPage> createState() => _DatingSuperLikesPageState();
}

class _DatingSuperLikesPageState extends State<DatingSuperLikesPage>
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
              '⭐ Super likes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            Text(
              'Coups de cœur reçus et envoyés',
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
                Tab(icon: Icon(Icons.star), text: 'Reçus'),
                Tab(icon: Icon(Icons.star_border), text: 'Envoyés'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuperLikesList(isReceived: true),
          _buildSuperLikesList(isReceived: false),
        ],
      ),
    );
  }

  Widget _buildSuperLikesList({required bool isReceived}) {
    final collection = 'dating_coup_de_coeurs';
    final field = isReceived ? 'toUserId' : 'fromUserId';
    final title = isReceived ? 'Coups de cœur reçus' : 'Coups de cœur envoyés';
    final emptyIcon = isReceived ? Icons.star_border : Icons.star_border;
    final emptyTitle = isReceived ? 'Aucun super like reçu' : 'Aucun super like envoyé';
    final emptyMessage = isReceived
        ? 'Les personnes qui vous envoient des super likes apparaîtront ici'
        : 'Les profils à qui vous envoyez des super likes apparaîtront ici';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(field, isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
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

        final superLikes = snapshot.data?.docs ?? [];

        if (superLikes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade100, Colors.orange.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    emptyIcon,
                    size: 60,
                    color: Colors.amber.shade600,
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
                    icon: Icon(Icons.star, color: Colors.white),
                    label: Text(
                      'Envoyer un super like',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
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
          itemCount: superLikes.length,
          itemBuilder: (context, index) {
            final superLike = superLikes[index];
            final userId = isReceived ? superLike['fromUserId'] : superLike['toUserId'];
            final createdAt = superLike['createdAt'] as int;
            final date = DateTime.fromMillisecondsSinceEpoch(createdAt);

            return FutureBuilder<DatingProfile?>(
              future: _getDatingProfile(userId),
              builder: (context, profileSnapshot) {
                if (!profileSnapshot.hasData) {
                  return SizedBox.shrink();
                }

                final profile = profileSnapshot.data!;
                final isNew = createdAt > DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;

                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      _navigateToProfile(profile);
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
                          color: isNew ? Colors.amber.shade200 : Colors.grey.shade200,
                          width: isNew ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Photo de profil avec effet étoile (depuis le dating profile)
                            Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: isNew
                                          ? [Colors.amber.shade400, Colors.orange.shade400]
                                          : [Colors.grey.shade300, Colors.grey.shade400],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isNew
                                            ? Colors.amber.withOpacity(0.3)
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
                                        profile.imageUrl,
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
                                        color: Colors.amber,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: Icon(
                                        Icons.star,
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
                                    profile.pseudo,
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
                                        '${profile.age} ans',
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
                                        profile.pays,
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
                                      color: isNew ? Colors.amber.shade50 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 10,
                                          color: isNew ? Colors.amber : Colors.grey,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          _formatDate(date),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isNew ? Colors.amber.shade800 : Colors.grey.shade600,
                                            fontWeight: isNew ? FontWeight.w500 : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Badge super like
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.amber.shade400, Colors.orange.shade400],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.star,
                                size: 20,
                                color: Colors.white,
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

  Future<DatingProfile?> _getDatingProfile(String userId) async {
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
      print('❌ Erreur récupération dating profile: $e');
      return null;
    }
  }

  void _navigateToProfile(DatingProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingProfileDetailPage(profile: profile),
      ),
    );
  }
}