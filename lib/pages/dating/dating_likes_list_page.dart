// lib/pages/dating/dating_likes_list_page.dart
import 'dart:ui';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'dating_profile_detail_page.dart';
import 'dating_subscription_page.dart';

class DatingLikesListPage extends StatefulWidget {
  const DatingLikesListPage({Key? key}) : super(key: key);

  @override
  State<DatingLikesListPage> createState() => _DatingLikesListPageState();
}

class _DatingLikesListPageState extends State<DatingLikesListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserId;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _currentUserId = authProvider.loginUserData.id;
    _loadSubscriptionPlan();
  }

  /// Vérifie si l'utilisateur a un abonnement Plus ou Gold, pour débloquer
  /// la liste complète des personnes qui l'ont liké.
  Future<void> _loadSubscriptionPlan() async {
    if (_currentUserId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final plan = snapshot.docs.first['planCode'];
        if (mounted) {
          setState(() => _isPremium = plan == 'plus' || plan == 'gold');
        }
      }
    } catch (e) {
      printVm('❌ Erreur chargement abonnement: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.datingMyLikesTitle,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            Text(
              t.datingMyLikesSubtitle,
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
              tabs: [
                Tab(icon: const Icon(Icons.favorite), text: t.datingTabReceived),
                Tab(icon: const Icon(Icons.thumb_up), text: t.datingTabSent),
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
    final t = AppLocalizations.of(context);
    final collection = 'dating_likes';
    final field = isReceived ? 'toUserId' : 'fromUserId';
    final emptyIcon = isReceived ? Icons.favorite_border : Icons.thumb_up_off_alt;
    final emptyTitle = isReceived ? t.datingNoLikeReceived : t.datingNoLikeSent;
    final emptyMessage = isReceived ? t.datingLikesReceivedEmptyMsg : t.datingLikesSentEmptyMsg;

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
                Text(t.datingErrorGeneric.replaceAll('{error}', '${snapshot.error}')),
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
                Text(t.datingLoadingText),
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
                    color: AppColors.of(context).textPrimary,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.of(context).textSecondary,
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
                      t.datingDiscoverProfiles,
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

        if (isReceived && !_isPremium) {
          return _buildLockedLikesTeaser(likes.length);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: likes.length,
          itemBuilder: (context, index) {
            final like = likes[index];
            final userId = isReceived ? like['fromUserId'] : like['toUserId'];
            final createdAt = like['createdAt'] as int;
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
                        color: AppColors.of(context).surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: isNew ? Colors.red.shade200 : AppColors.of(context).border,
                          width: isNew ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Photo de profil (depuis le dating profile)
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
                                        _cdnUrl(profile.imageUrl),
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
                                    profile.pseudo,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.of(context).textPrimary,
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
                                        t.datingAgeYears.replaceAll('{age}', '${profile.age}'),
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

  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }

  /// Affiche une vignette verrouillée (fonctionnalité Plus/Gold) à la place de la
  /// liste complète des personnes ayant liké le profil de l'utilisateur gratuit.
  Widget _buildLockedLikesTeaser(int count) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.red.shade300, Colors.pink.shade300],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 48),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.lock, color: Colors.white, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              count == 0
                  ? t.datingNoOneLikedYet
                  : (count == 1 ? t.datingOnePersonLikedYou : t.datingNPeopleLikedYou.replaceAll('{count}', '$count')),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t.datingUpgradeToSeeWhoLiked,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DatingSubscriptionPage()),
                );
              },
              icon: const Icon(Icons.star, color: Colors.white),
              label: Text(t.datingSeeSubscriptions, style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final likeDate = DateTime(date.year, date.month, date.day);

    if (likeDate == today) {
      return t.datingTodayCap;
    } else if (likeDate == today.subtract(Duration(days: 1))) {
      return t.datingYesterdayCap;
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
      printVm('❌ Erreur récupération dating profile: $e');
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