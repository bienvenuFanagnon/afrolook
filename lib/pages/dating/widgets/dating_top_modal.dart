import 'package:flutter/material.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/theme/app_colors.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/dating_data.dart';

import '../dating_entry_page.dart';

import '../dating_profile_detail_page.dart';

void showTopDatingAnnounceModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      final colors = AppColors.of(context);
      const pink = Color(0xFFE91E8C);

      return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pink.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: pink.withOpacity(0.15),
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
                      color: pink.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: pink,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Titre
                  Text(
                    '💕 NOUVEAUTÉ : AFROLOVE !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: pink,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Message principal
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Découvrez maintenant les profils de rencontre qui vous correspondent :',
                      style: TextStyle(
                        color: colors.textSecondary,
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
                        return const SizedBox(
                          height: 150,
                          child: Center(child: CircularProgressIndicator(color: pink)),
                        );
                      }
                      if (snapshot.hasError ||
                          snapshot.data == null ||
                          snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final profiles = snapshot.data!;
                      return SizedBox(
                        height: 140,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: profiles.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return _buildProfileCard(context, profiles[index], colors);
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
                              color: colors.textSecondary,
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
                            backgroundColor: pink,
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
        .limit(10);
    final snapshot = await query.get();
    final profiles = snapshot.docs
        .map((doc) => DatingProfile.fromJson(doc.data()))
        .toList();
    profiles.shuffle();
    return profiles.take(3).toList();
  } catch (e) {
    printVm('Erreur chargement top profils: $e');
    return [];
  }
}

/// Construit une petite carte pour un profil dans le modal.
Widget _buildProfileCard(BuildContext context, DatingProfile profile, AppColors colors) {
  final imageUrl =
      profile.photosUrls.isNotEmpty ? profile.photosUrls.first : profile.imageUrl;
  return GestureDetector(
    onTap: () {
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
        border: Border.all(color: colors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: colors.textSecondary.withOpacity(0.08),
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
                  color: colors.surfaceVariant,
                  child: Icon(Icons.person, color: colors.textSecondary, size: 40),
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
                      Colors.black.withOpacity(0.72),
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
