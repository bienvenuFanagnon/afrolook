// lib/pages/creator/creator_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dating_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/creator_provider.dart';
import 'creator_content_detail_page.dart';
import 'creator_subscription_page.dart';

class CreatorProfilePage extends StatefulWidget {
  final String creatorId;

  const CreatorProfilePage({Key? key, required this.creatorId}) : super(key: key);

  @override
  State<CreatorProfilePage> createState() => _CreatorProfilePageState();
}

class _CreatorProfilePageState extends State<CreatorProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CreatorProvider>(context, listen: false);
      provider.loadCreatorProfile(widget.creatorId);
      provider.loadCreatorContents(widget.creatorId);

      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final currentUserId = authProvider.loginUserData?.id;
      if (currentUserId != null) {
        provider.checkSubscription( widget.creatorId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CreatorProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentCreatorProfile == null) {
            return Center(child: CircularProgressIndicator());
          }

          final profile = provider.currentCreatorProfile;
          if (profile == null) {
            return Center(child: Text('Profil créateur introuvable'));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        profile.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(color: Colors.grey.shade300);
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.pseudo,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              profile.bio,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                _buildStatChip(
                                  '${profile.subscribersCount} abonnés',
                                  Icons.people,
                                ),
                                SizedBox(width: 8),
                                _buildStatChip(
                                  '${profile.totalViews} vues',
                                  Icons.visibility,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (!provider.isSubscribed)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreatorSubscriptionPage(
                              creatorId: widget.creatorId,
                              creatorName: profile.pseudo,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text('S\'abonner'),
                    ),
                  if (provider.isSubscribed)
                    IconButton(
                      icon: Icon(Icons.notifications_active, color: Colors.red),
                      onPressed: () {
                        // Gérer les notifications
                      },
                    ),
                ],
              ),
              SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final content = provider.creatorContents[index];
                      return _buildContentCard(context, content);
                    },
                    childCount: provider.creatorContents.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(BuildContext context, CreatorContent content) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatorContentDetailPage(content: content),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      content.thumbnailUrl ?? content.mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: Colors.grey.shade200);
                      },
                    ),
                    if (content.isPaid)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                '${content.priceCoins} coins',
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.titre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 12, color: Colors.red),
                      SizedBox(width: 4),
                      Text(
                        '${content.likesCount + content.lovesCount}',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.visibility, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        '${content.viewsCount}',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}