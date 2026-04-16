// lib/widgets/top_dating_profiles_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../models/dating_data.dart';
import '../dating_entry_page.dart';
import '../dating_profile_detail_page.dart';

class TopDatingProfilesWidget extends StatefulWidget {
  const TopDatingProfilesWidget({Key? key}) : super(key: key);

  @override
  State<TopDatingProfilesWidget> createState() => _TopDatingProfilesWidgetState();
}

class _TopDatingProfilesWidgetState extends State<TopDatingProfilesWidget> {
  @override
  void initState() {
    super.initState();
    // Déclencher le chargement si nécessaire
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<UserAuthProvider>();
      if (provider.topDatingProfiles.isEmpty && !provider.isLoadingDatingProfiles) {
        provider.loadTopDatingProfiles();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserAuthProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingDatingProfiles) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final profiles = provider.topDatingProfiles;
        if (profiles.isEmpty) {
          return const SizedBox.shrink(); // ou un message élégant
        }

        return _buildContent(profiles);
      },
    );
  }

  Widget _buildContent(List<DatingProfile> profiles) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.pink, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'AfroLove',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DatingSwipePage()),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.pink),
                  child: const Text('Voir plus', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Des profils qui pourraient vous correspondre',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          // Carrousel horizontal
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildProfileCard(profiles[index]),
            ),
          ),
          const SizedBox(height: 16),
          // Call to action
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DatingSwipePage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                '✨ Rencontrer l\'amour ✨',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(DatingProfile profile) {
    final imageUrl = profile.photosUrls.isNotEmpty ? profile.photosUrls.first : profile.imageUrl;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DatingProfileDetailPage(profile: profile)),
        );
      },
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.person, size: 50),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${profile.pseudo}, ${profile.age}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 10, color: Colors.white70),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '${profile.ville}, ${profile.pays}',
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (profile.popularityScore > 100)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                    child: const Icon(Icons.whatshot, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}