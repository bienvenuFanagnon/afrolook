// lib/pages/dating/dating_profiles_list_page.dart
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dating_data.dart';
import '../../providers/dating/dating_provider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'dating_profile_detail_page.dart';


class DatingProfilesListPage extends StatefulWidget {
  @override
  State<DatingProfilesListPage> createState() => _DatingProfilesListPageState();
}

class _DatingProfilesListPageState extends State<DatingProfilesListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final userId = authProvider.loginUserData?.id;
      if (userId != null) {
        Provider.of<DatingProvider>(context, listen: false)
            .loadRecommendedProfiles();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
        title: Text(t.datingMeetingsTitle, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.favorite_border),
            onPressed: () => Navigator.pushNamed(context, '/dating/connections'),
          ),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.pushNamed(context, '/dating/conversations'),
          ),
        ],
      ),
      body: Consumer<DatingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.recommendedProfiles.isEmpty) {
            return Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.datingErrorGeneric.replaceAll('{error}', '${provider.error}')),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
                      final userId = authProvider.loginUserData?.id;
                      if (userId != null) {
                        provider.loadRecommendedProfiles();
                        // provider.loadRecommendedProfiles(userId);
                      }
                    },
                    child: Text(t.datingRetry),
                  ),
                ],
              ),
            );
          }

          if (provider.recommendedProfiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    t.datingNoProfileToShow,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.of(context).textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    t.datingComeBackForNewProfiles,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: provider.recommendedProfiles.length,
            itemBuilder: (context, index) {
              final profile = provider.recommendedProfiles[index];
              return _buildProfileCard(context, profile);
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, DatingProfile profile) {
    final t = AppLocalizations.of(context);
    final provider = Provider.of<DatingProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData?.id;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DatingProfileDetailPage(profile: profile),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.of(context).surface,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  _cdnUrl(profile.imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.pseudo}, ${profile.age}',
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
                        Icons.location_on,
                        size: 12,
                        color: AppColors.of(context).textSecondary,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          profile.ville,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.of(context).textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionButton(
                        icon: Icons.favorite_border,
                        color: Colors.red,
                        onPressed: () async {
                          if (currentUserId != null) {
                            await provider.likeProfile(profile.userId);
                            // await provider.likeProfile(currentUserId, profile.userId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t.datingYouLikedUser.replaceAll('{pseudo}', profile.pseudo))),
                            );
                          }
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.star_border,
                        color: Colors.orange,
                        onPressed: () {
                          // Coup de cœur
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.chat_bubble_outline,
                        color: Colors.blue,
                        onPressed: () {
                          // Message
                        },
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

  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 20,
          color: color,
        ),
      ),
    );
  }
}