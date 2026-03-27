import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/dating_data.dart';
import '../dating_entry_page.dart';
import '../dating_profile_detail_page.dart';


void showTopDatingAnnounceModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.pink.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône principale
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.pink.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.pink,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),

                // Titre
                const Text(
                  '💕 NOUVEAUTÉ : AFROLOVE !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.pink,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Message principal
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Découvrez maintenant les profils de rencontre qui vous correspondent :',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Section des 3 meilleurs profils
                FutureBuilder<List<DatingProfile>>(
                  future: _fetchTopProfiles(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: SizedBox(
                          height: 150,
                          child: Center(child: CircularProgressIndicator(color: Colors.pink)),
                        ),
                      );
                    }
                    if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink(); // pas de profil disponible, on cache cette partie
                    }
                    final profiles = snapshot.data!;
                    return SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: profiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          return _buildProfileCard(context, profile);
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Boutons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'PLUS TARD',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DatingSwipePage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'DÉCOUVRIR',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Récupère les 3 meilleurs profils actifs (basés sur popularityScore) et les mélange.
Future<List<DatingProfile>> _fetchTopProfiles() async {
  try {
    final query = FirebaseFirestore.instance
        .collection('dating_profiles')
        .where('isActive', isEqualTo: true)
        .orderBy('popularityScore', descending: true)
        .limit(10); // on prend un peu plus pour mélanger ensuite
    final snapshot = await query.get();
    final profiles = snapshot.docs
        .map((doc) => DatingProfile.fromJson(doc.data()))
        .toList();
    profiles.shuffle();
    return profiles.take(3).toList();
  } catch (e) {
    print('Erreur chargement top profils: $e');
    return [];
  }
}

/// Construit une petite carte pour un profil dans le modal.
Widget _buildProfileCard(BuildContext context, DatingProfile profile) {
  final imageUrl = profile.photosUrls.isNotEmpty
      ? profile.photosUrls.first
      : profile.imageUrl;
  return GestureDetector(
    onTap: () {
      // Fermer le modal avant de naviguer vers le détail
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DatingProfileDetailPage(profile: profile),
        ),
      );
    },
    child: Container(
      width: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.person, color: Colors.grey, size: 40),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.pseudo}, ${profile.age}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 8, color: Colors.white70),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            profile.ville,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}