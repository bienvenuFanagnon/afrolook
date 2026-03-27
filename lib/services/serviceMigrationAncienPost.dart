// Créez un nouveau fichier migration_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/model_data.dart';

class MigrationAncienPostService {
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> migrateOldPostsToCountrySystem() async {
    try {
      print('🚀 Début de la migration des posts vers le système de pays...');

      // Récupérer tous les posts existants
      final snapshot = await firestore
          .collection('Posts')
          .where("status", isNotEqualTo: "SUPPRIMER")
          .get();

      print('📊 Nombre de posts à migrer: ${snapshot.docs.length}');

      int updatedCount = 0;
      int errorCount = 0;
      int batchNumber = 0;

      const batchSize = 100; // Taille optimale pour Firebase
      final totalBatches = (snapshot.docs.length / batchSize).ceil();

      // Traiter par batches - créer un nouveau batch à chaque fois
      for (int i = 0; i < snapshot.docs.length; i += batchSize) {
        batchNumber++;
        print('\n🔄 Traitement du batch $batchNumber/$totalBatches...');

        // Déterminer la fin du batch actuel
        final endIndex = (i + batchSize) < snapshot.docs.length
            ? i + batchSize
            : snapshot.docs.length;

        final batchDocs = snapshot.docs.sublist(i, endIndex);

        // Créer un NOUVEAU batch pour chaque groupe
        final batch = firestore.batch();
        int batchUpdates = 0;

        for (var doc in batchDocs) {
          try {
            final postData = doc.data();

            // Vérifier si le post a déjà les nouveaux champs
            final hasNewFields = postData.containsKey('is_available_in_all_countries') ||
                postData.containsKey('available_countries');

            if (!hasNewFields) {
              // Mettre à jour avec les valeurs par défaut
              batch.update(doc.reference, {
                'is_available_in_all_countries': true,
                'available_countries': [], // Vide = tous les pays
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              });
              batchUpdates++;
              updatedCount++;
            }
          } catch (e) {
            print('❌ Erreur sur le post ${doc.id}: $e');
            errorCount++;
          }
        }

        if (batchUpdates > 0) {
          try {
            // Commit ce batch spécifique
            await batch.commit();
            print('✅ Batch $batchNumber commité: $batchUpdates posts mis à jour');
            print('📊 Progression: $updatedCount posts migrés sur ${snapshot.docs.length}');
          } catch (e) {
            print('❌ Erreur lors du commit du batch $batchNumber: $e');
            errorCount += batchUpdates;
          }
        } else {
          print('ℹ️ Batch $batchNumber: Aucun post à migrer dans ce lot');
        }

        // Petite pause pour éviter de surcharger Firebase
        if (batchNumber % 5 == 0) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      print('\n🎉 Migration terminée!');
      print('📈 Posts mis à jour: $updatedCount');
      print('❌ Erreurs: $errorCount');
      print('📋 Total posts traités: ${snapshot.docs.length}');

    } catch (e) {
      print('❌ Erreur lors de la migration: $e');
      rethrow;
    }
  }

  // Version simplifiée - plus facile à déboguer
  static Future<void> migrateOldPostsSimple() async {
    try {
      print('🚀 Début de la migration (ajout ALL)...');

      final snapshot = await firestore
          .collection('Posts')
          .where("status", isNotEqualTo: "SUPPRIMER")
          .get();

      print('📊 Nombre total de posts: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('ℹ️ Aucun post trouvé.');
        return;
      }

      const batchSize = 100;
      int batchesProcessed = 0;
      int totalUpdated = 0;

      for (int i = 0; i < snapshot.docs.length; i += batchSize) {
        batchesProcessed++;

        final endIndex = (i + batchSize < snapshot.docs.length)
            ? i + batchSize
            : snapshot.docs.length;

        final currentBatch = snapshot.docs.sublist(i, endIndex);
        final batch = firestore.batch();

        for (var doc in currentBatch) {
          final data = doc.data() as Map<String, dynamic>;

          // Récupérer la liste actuelle
          List<dynamic> countries = [];
          if (data.containsKey('available_countries') &&
              data['available_countries'] is List) {
            countries = List.from(data['available_countries']);
          }

          // Ajouter ALL seulement si absent
          if (!countries.contains('ALL')) {
            countries.add('ALL');
          }

          batch.update(doc.reference, {
            'is_available_in_all_countries': true,
            'available_countries': countries, // 👈 On ajoute, on ne remplace pas
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }

        try {
          await batch.commit();
          totalUpdated += currentBatch.length;
          print('✅ Batch $batchesProcessed: ${currentBatch.length} posts mis à jour');
        } catch (e) {
          print('❌ Erreur batch $batchesProcessed: $e');
        }

        await Future.delayed(Duration(milliseconds: 200));
      }

      print('\n🎉 Migration terminée !');
      print('📈 Total posts mis à jour: $totalUpdated');

    } catch (e) {
      print('❌ Erreur migration ALL: $e');
      rethrow;
    }
  }

  // Fonction pour migrer un post spécifique (utile pour le debug)
  static Future<void> migrateSinglePost(String postId) async {
    try {
      final docRef = firestore.collection('Posts').doc(postId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data()!;

        // Vérifier si besoin de migration
        final needsMigration = !data.containsKey('is_available_in_all_countries');

        if (needsMigration) {
          await docRef.update({
            'is_available_in_all_countries': true,
            'available_countries': [],
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
          print('✅ Post $postId migré avec succès');
        } else {
          print('ℹ️ Post $postId déjà migré');
        }
      }
    } catch (e) {
      print('❌ Erreur migration post $postId: $e');
    }
  }

  // Fonction pour vérifier l'état de la migration
  static Future<void> checkMigrationStatus() async {
    try {
      final snapshot = await firestore
          .collection('Posts')
          .where("status", isNotEqualTo: "SUPPRIMER")
          .limit(50)
          .get();

      int migrated = 0;
      int total = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('is_available_in_all_countries')) {
          migrated++;
        }
      }

      print('\n📊 État de la migration:');
      print('   Posts échantillonnés: $total');
      print('   Posts déjà migrés: $migrated');
      print('   Pourcentage migré: ${((migrated / total) * 100).toStringAsFixed(1)}%');

      if (migrated < total) {
        print('⚠️  Il reste ${total - migrated} posts à migrer dans cet échantillon');
      } else {
        print('✅ Tous les posts sont migrés dans cet échantillon!');
      }

    } catch (e) {
      print('❌ Erreur vérification migration: $e');
    }
  }
}

Future<void> migrateDatingProfilesToLowercase() async {
  final firestore = FirebaseFirestore.instance;
  print('🔍 Migration: Récupération de tous les profils dating...');
  final snapshot = await firestore.collection('dating_profiles').get();
  final totalDocs = snapshot.docs.length;
  print('📊 ${totalDocs} profils trouvés.');

  if (totalDocs == 0) {
    print('✅ Aucun profil à migrer.');
    return;
  }

  int updatedCount = 0;
  int batchCount = 0;
  const batchLimit = 500; // Firestore batch limit

  // Process in batches of 500
  for (int i = 0; i < totalDocs; i += batchLimit) {
    final end = (i + batchLimit < totalDocs) ? i + batchLimit : totalDocs;
    final batch = firestore.batch();
    int batchUpdates = 0;

    for (int j = i; j < end; j++) {
      final doc = snapshot.docs[j];
      final data = doc.data();
      final sexe = data['sexe'] as String?;
      final rechercheSexe = data['rechercheSexe'] as String?;
      bool needUpdate = false;
      Map<String, dynamic> updates = {};

      if (sexe != null && sexe != sexe.toLowerCase()) {
        updates['sexe'] = sexe.toLowerCase();
        needUpdate = true;
      }
      if (rechercheSexe != null && rechercheSexe != rechercheSexe.toLowerCase()) {
        updates['rechercheSexe'] = rechercheSexe.toLowerCase();
        needUpdate = true;
      }

      if (needUpdate) {
        batch.update(doc.reference, updates);
        batchUpdates++;
        updatedCount++;
      }
    }

    if (batchUpdates > 0) {
      batchCount++;
      print('📦 Envoi du lot $batchCount (${i+1} - $end) avec $batchUpdates mise(s) à jour...');
      await batch.commit();
      print('✅ Lot $batchCount envoyé.');
    } else {
      print('ℹ️ Aucune mise à jour dans le lot ${i+1}-$end.');
    }
  }

  print('🎉 Migration terminée ! $updatedCount profils mis à jour.');
}

Future<void> migrateInitialDatingProfilesForMen() async {
  try {
    print('🚀 === DÉBUT DE LA MIGRATION DES PROFILS DATING (HOMMES) ===');
    print('📅 Date de migration: ${DateTime.now()}');

    // Récupérer tous les utilisateurs dont le genre est "Homme"
    print('🔍 Recherche des utilisateurs avec genre = "Homme"...');
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .where('genre', isEqualTo: 'Homme')
        .get();

    print('📊 Total des utilisateurs trouvés: ${usersSnapshot.docs.length}');

    int createdCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    for (var userDoc in usersSnapshot.docs) {
      try {
        final userData = UserData.fromJson(userDoc.data());
        print('\n--- Traitement de l\'utilisateur ---');
        print('📱 ID: ${userData.id}');
        print('👤 Pseudo: ${userData.pseudo}');
        print('📧 Email: ${userData.email}');

        // Vérifier si un profil dating existe déjà
        final existingProfile = await FirebaseFirestore.instance
            .collection('dating_profiles')
            .where('userId', isEqualTo: userData.id)
            .limit(1)
            .get();

        if (existingProfile.docs.isNotEmpty) {
          print('⚠️ Profil dating déjà existant pour cet utilisateur - Ignoré');
          skippedCount++;
          continue;
        }

        // Calcul de l'âge avec gestion des différents formats de date
        final age = _calculateAgeFromUserDataSafe(userData);
        print('🎂 Âge calculé: $age ans');

        // Calcul du pourcentage de complétion
        final completionPercentage = _calculateCompletionPercentage(userData);
        print('📊 Pourcentage de complétion: ${completionPercentage.toStringAsFixed(1)}%');

        // ✅ CALCUL DU SCORE DE POPULARITÉ
        final userId = userData.id!;
        print('📊 Calcul du score de popularité pour $userId...');

        // Récupérer les compteurs
        final likesCount = await FirebaseFirestore.instance
            .collection('dating_likes')
            .where('toUserId', isEqualTo: userId)
            .count()
            .get();

        final coupsCount = await FirebaseFirestore.instance
            .collection('dating_coup_de_coeurs')
            .where('toUserId', isEqualTo: userId)
            .count()
            .get();

        final connectionsCount = await FirebaseFirestore.instance
            .collection('dating_connections')
            .where('userId1', isEqualTo: userId)
            .count()
            .get();

        // Calcul du score: 1 point par like, 2 points par coup de cœur, 3 points par connexion
        final popularityScore = (likesCount.count! * 1) + (coupsCount.count! * 2) + (connectionsCount.count! * 3);
        print('📊 Score calculé: $popularityScore (likes: ${likesCount.count}, coups: ${coupsCount.count}, connexions: ${connectionsCount.count})');

        final now = DateTime.now().millisecondsSinceEpoch;
        print('⏰ Timestamp actuel: $now');

        final profileId = FirebaseFirestore.instance.collection('dating_profiles').doc().id;

        final datingProfile = {
          'id': profileId,
          'userId': userData.id,
          'pseudo': userData.pseudo ?? '',
          'imageUrl': userData.imageUrl ?? '',
          'photosUrls': [userData.imageUrl ?? ''],
          'bio': userData.apropos ?? '',
          'age': age,
          'sexe': userData.genre!.toLowerCase() ?? '',
          'ville': userData.adresse?.split(',')[0] ?? '',
          'pays': userData.userPays?.name ?? '',
          'profession': null,
          'centresInteret': [],
          'rechercheSexe': 'femme', // 👈 Adapté : hommes cherchant des femmes (à modifier selon votre logique)
          'rechercheAgeMin': 18,
          'rechercheAgeMax': 50,
          'recherchePays': '',
          'isVerified': false,
          'isActive': true,
          'isProfileComplete': completionPercentage >= 100,
          'completionPercentage': completionPercentage,
          'createdByMigration': true,
          'likesCount': 0,
          'coupsDeCoeurCount': 0,
          'connexionsCount': 0,
          'visitorsCount': 0,
          'popularityScore': popularityScore,
          'createdAt': now,
          'updatedAt': now,
        };

        print('💾 Création du profil dating...');
        await FirebaseFirestore.instance
            .collection('dating_profiles')
            .doc(profileId)
            .set(datingProfile);

        print('✅ Profil dating créé avec succès (ID: $profileId, Score: $popularityScore)');
        createdCount++;

      } catch (e) {
        print('❌ Erreur lors du traitement de l\'utilisateur ${userDoc.id}: $e');
        errorCount++;
      }
    }

    print('\n📊 === RÉSUMÉ DE LA MIGRATION (HOMMES) ===');
    print('✅ Profils créés: $createdCount');
    print('⚠️ Profils ignorés (déjà existants): $skippedCount');
    print('❌ Erreurs: $errorCount');
    print('🎯 Total traité: ${usersSnapshot.docs.length}');
    print('✅ Migration des profils dating des hommes terminée avec succès!');

  } catch (e) {
    print('❌ ERREUR FATALE lors de la migration: $e');
    print('📋 Stack trace: ${StackTrace.current}');
  }
}
// Ajoutez cette méthode dans votre UserAuthProvider existant
Future<void> migrateInitialDatingProfiles() async {
  try {
    print('🚀 === DÉBUT DE LA MIGRATION DES PROFILS DATING ===');
    print('📅 Date de migration: ${DateTime.now()}');

    // Récupérer tous les utilisateurs dont le genre est "femme"
    print('🔍 Recherche des utilisateurs avec genre = "Femme"...');
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .where('genre', isEqualTo: 'Femme')
        .get();

    print('📊 Total des utilisateurs trouvés: ${usersSnapshot.docs.length}');

    int createdCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    for (var userDoc in usersSnapshot.docs) {
      try {
        final userData = UserData.fromJson(userDoc.data());
        print('\n--- Traitement de l\'utilisateur ---');
        print('📱 ID: ${userData.id}');
        print('👤 Pseudo: ${userData.pseudo}');
        print('📧 Email: ${userData.email}');

        // Vérifier si un profil dating existe déjà
        final existingProfile = await FirebaseFirestore.instance
            .collection('dating_profiles')
            .where('userId', isEqualTo: userData.id)
            .limit(1)
            .get();

        if (existingProfile.docs.isNotEmpty) {
          print('⚠️ Profil dating déjà existant pour cet utilisateur - Ignoré');
          skippedCount++;
          continue;
        }

        // Calcul de l'âge avec gestion des différents formats de date
        final age = _calculateAgeFromUserDataSafe(userData);
        print('🎂 Âge calculé: $age ans');

        // Calcul du pourcentage de complétion
        final completionPercentage = _calculateCompletionPercentage(userData);
        print('📊 Pourcentage de complétion: ${completionPercentage.toStringAsFixed(1)}%');

        // ✅ CALCUL DU SCORE DE POPULARITÉ
        final userId = userData.id!;
        print('📊 Calcul du score de popularité pour $userId...');

        // Récupérer les compteurs
        final likesCount = await FirebaseFirestore.instance
            .collection('dating_likes')
            .where('toUserId', isEqualTo: userId)
            .count()
            .get();

        final coupsCount = await FirebaseFirestore.instance
            .collection('dating_coup_de_coeurs')
            .where('toUserId', isEqualTo: userId)
            .count()
            .get();

        final connectionsCount = await FirebaseFirestore.instance
            .collection('dating_connections')
            .where('userId1', isEqualTo: userId)
            .count()
            .get();

        // Calcul du score: 1 point par like, 2 points par coup de cœur, 3 points par connexion
        final popularityScore = (likesCount.count! * 1) + (coupsCount.count! * 2) + (connectionsCount.count! * 3);
        print('📊 Score calculé: $popularityScore (likes: ${likesCount.count}, coups: ${coupsCount.count}, connexions: ${connectionsCount.count})');

        final now = DateTime.now().millisecondsSinceEpoch;
        print('⏰ Timestamp actuel: $now');

        final profileId = FirebaseFirestore.instance.collection('dating_profiles').doc().id;

        final datingProfile = {
          'id': profileId,
          'userId': userData.id,
          'pseudo': userData.pseudo ?? '',
          'imageUrl': userData.imageUrl ?? '',
          'photosUrls': [userData.imageUrl ?? ''],
          'bio': userData.apropos ?? '',
          'age': age,
          'sexe': userData.genre!.toLowerCase() ?? '',
          'ville': userData.adresse?.split(',')[0] ?? '',
          'pays': userData.userPays?.name ?? '',
          'profession': null,
          'centresInteret': [],
          'rechercheSexe': 'homme',
          'rechercheAgeMin': 18,
          'rechercheAgeMax': 50,
          'recherchePays': '',
          'isVerified': false,
          'isActive': true,
          'isProfileComplete': completionPercentage >= 100,
          'completionPercentage': completionPercentage,
          'createdByMigration': true,
          'likesCount': 0,
          'coupsDeCoeurCount': 0,
          'connexionsCount': 0,
          'visitorsCount': 0,
          'popularityScore': popularityScore, // ✅ NOUVEAU CHAMP AJOUTÉ
          'createdAt': now,
          'updatedAt': now,
        };

        print('💾 Création du profil dating...');
        await FirebaseFirestore.instance
            .collection('dating_profiles')
            .doc(profileId)
            .set(datingProfile);

        print('✅ Profil dating créé avec succès (ID: $profileId, Score: $popularityScore)');
        createdCount++;

      } catch (e) {
        print('❌ Erreur lors du traitement de l\'utilisateur ${userDoc.id}: $e');
        errorCount++;
      }
    }

    print('\n📊 === RÉSUMÉ DE LA MIGRATION ===');
    print('✅ Profils créés: $createdCount');
    print('⚠️ Profils ignorés (déjà existants): $skippedCount');
    print('❌ Erreurs: $errorCount');
    print('🎯 Total traité: ${usersSnapshot.docs.length}');
    print('✅ Migration des profils dating terminée avec succès!');

  } catch (e) {
    print('❌ ERREUR FATALE lors de la migration: $e');
    print('📋 Stack trace: ${StackTrace.current}');
  }
}

/// Calcule l'âge à partir des données utilisateur en gérant différents formats de date
int _calculateAgeFromUserDataSafe(UserData userData) {
  try {
    // Si createdAt est null, retourner 0
    if (userData.createdAt == null) {
      print('⚠️ createdAt est null, âge par défaut: 0');
      return 0;
    }

    DateTime birthDate;
    final createdAt = userData.createdAt;

    // Vérifier si c'est en microsecondes (valeur très grande > 10^12)
    if (createdAt! > 1000000000000) {
      // C'est probablement en microsecondes
      birthDate = DateTime.fromMicrosecondsSinceEpoch(createdAt!);
      print('📅 Date de naissance (microsecondes): $birthDate');
    }
    // Vérifier si c'est en millisecondes (valeur entre 10^9 et 10^12)
    else if (createdAt > 1000000000 && createdAt <= 1000000000000) {
      birthDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
      print('📅 Date de naissance (millisecondes): $birthDate');
    }
    // Sinon, traiter comme DateTime direct
    else {
      birthDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
      print('📅 Date de naissance (par défaut): $birthDate');
    }

    final now = DateTime.now();
    int age = now.year - birthDate.year;

    // Vérifier si l'anniversaire est déjà passé cette année
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    // Validation de l'âge
    if (age < 0 || age > 120) {
      print('⚠️ Âge invalide calculé: $age, utilisation de 0');
      return 0;
    }

    return age;

  } catch (e) {
    print('❌ Erreur lors du calcul de l\'âge: $e');
    print('📋 createdAt value: ${userData.createdAt}');
    return 0;
  }
}

double _calculateCompletionPercentage(UserData userData) {
  int completedFields = 0;
  int totalFields = 6;

  print('🔍 Vérification des champs pour le calcul de complétion:');

  // Pseudo
  if (userData.pseudo?.isNotEmpty ?? false) {
    completedFields++;
    print('  ✅ Pseudo: ${userData.pseudo}');
  } else {
    print('  ❌ Pseudo: manquant');
  }

  // Image URL
  if (userData.imageUrl?.isNotEmpty ?? false) {
    completedFields++;
    print('  ✅ Image URL: ${userData.imageUrl}');
  } else {
    print('  ❌ Image URL: manquant');
  }

  // Bio (apropos)
  if (userData.apropos?.isNotEmpty ?? false) {
    completedFields++;
    print('  ✅ Bio: ${userData.apropos?.substring(0, userData.apropos!.length > 50 ? 50 : userData.apropos!.length)}...');
  } else {
    print('  ❌ Bio: manquant');
  }

  // Genre
  if (userData.genre?.isNotEmpty ?? false) {
    completedFields++;
    print('  ✅ Genre: ${userData.genre}');
  } else {
    print('  ❌ Genre: manquant');
  }

  // Adresse
  if (userData.adresse?.isNotEmpty ?? false) {
    completedFields++;
    print('  ✅ Adresse: ${userData.adresse}');
  } else {
    print('  ❌ Adresse: manquant');
  }

  // Pays
  if (userData.userPays != null) {
    completedFields++;
    print('  ✅ Pays: ${userData.userPays?.name}');
  } else {
    print('  ❌ Pays: manquant');
  }

  final percentage = (completedFields / totalFields) * 100;
  print('📊 Total champs remplis: $completedFields/$totalFields');
  print('📊 Pourcentage de complétion: ${percentage.toStringAsFixed(1)}%');

  return percentage;
}