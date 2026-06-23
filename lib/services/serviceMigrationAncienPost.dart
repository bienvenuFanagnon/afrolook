// Créez un nouveau fichier migration_service.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/model_data.dart';

class MigrationAncienPostService {
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> migrateOldPostsToCountrySystem() async {
    try {
      printVm('🚀 Début de la migration des posts vers le système de pays...');

      // Récupérer tous les posts existants
      final snapshot = await firestore
          .collection('Posts')
          .where("status", isNotEqualTo: "SUPPRIMER")
          .get();

      printVm('📊 Nombre de posts à migrer: ${snapshot.docs.length}');

      int updatedCount = 0;
      int errorCount = 0;
      int batchNumber = 0;

      const batchSize = 100; // Taille optimale pour Firebase
      final totalBatches = (snapshot.docs.length / batchSize).ceil();

      // Traiter par batches - créer un nouveau batch à chaque fois
      for (int i = 0; i < snapshot.docs.length; i += batchSize) {
        batchNumber++;
        printVm('\n🔄 Traitement du batch $batchNumber/$totalBatches...');

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
            printVm('❌ Erreur sur le post ${doc.id}: $e');
            errorCount++;
          }
        }

        if (batchUpdates > 0) {
          try {
            // Commit ce batch spécifique
            await batch.commit();
            printVm('✅ Batch $batchNumber commité: $batchUpdates posts mis à jour');
            printVm('📊 Progression: $updatedCount posts migrés sur ${snapshot.docs.length}');
          } catch (e) {
            printVm('❌ Erreur lors du commit du batch $batchNumber: $e');
            errorCount += batchUpdates;
          }
        } else {
          printVm('ℹ️ Batch $batchNumber: Aucun post à migrer dans ce lot');
        }

        // Petite pause pour éviter de surcharger Firebase
        if (batchNumber % 5 == 0) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      printVm('\n🎉 Migration terminée!');
      printVm('📈 Posts mis à jour: $updatedCount');
      printVm('❌ Erreurs: $errorCount');
      printVm('📋 Total posts traités: ${snapshot.docs.length}');

    } catch (e) {
      printVm('❌ Erreur lors de la migration: $e');
      rethrow;
    }
  }

  // Version simplifiée - plus facile à déboguer
  static Future<void> migrateOldPostsSimple() async {
    try {
      printVm('🚀 Début de la migration (ajout ALL)...');

      final snapshot = await firestore
          .collection('Posts')
          .where("status", isNotEqualTo: "SUPPRIMER")
          .get();

      printVm('📊 Nombre total de posts: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        printVm('ℹ️ Aucun post trouvé.');
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
          printVm('✅ Batch $batchesProcessed: ${currentBatch.length} posts mis à jour');
        } catch (e) {
          printVm('❌ Erreur batch $batchesProcessed: $e');
        }

        await Future.delayed(Duration(milliseconds: 200));
      }

      printVm('\n🎉 Migration terminée !');
      printVm('📈 Total posts mis à jour: $totalUpdated');

    } catch (e) {
      printVm('❌ Erreur migration ALL: $e');
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
          printVm('✅ Post $postId migré avec succès');
        } else {
          printVm('ℹ️ Post $postId déjà migré');
        }
      }
    } catch (e) {
      printVm('❌ Erreur migration post $postId: $e');
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

      printVm('\n📊 État de la migration:');
      printVm('   Posts échantillonnés: $total');
      printVm('   Posts déjà migrés: $migrated');
      printVm('   Pourcentage migré: ${((migrated / total) * 100).toStringAsFixed(1)}%');

      if (migrated < total) {
        printVm('⚠️  Il reste ${total - migrated} posts à migrer dans cet échantillon');
      } else {
        printVm('✅ Tous les posts sont migrés dans cet échantillon!');
      }

    } catch (e) {
      printVm('❌ Erreur vérification migration: $e');
    }
  }
}

Future<void> migrateDatingProfilesToLowercase() async {
  final firestore = FirebaseFirestore.instance;
  printVm('🔍 Migration: Récupération de tous les profils dating...');
  final snapshot = await firestore.collection('dating_profiles').get();
  final totalDocs = snapshot.docs.length;
  printVm('📊 ${totalDocs} profils trouvés.');

  if (totalDocs == 0) {
    printVm('✅ Aucun profil à migrer.');
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
      printVm('📦 Envoi du lot $batchCount (${i+1} - $end) avec $batchUpdates mise(s) à jour...');
      await batch.commit();
      printVm('✅ Lot $batchCount envoyé.');
    } else {
      printVm('ℹ️ Aucune mise à jour dans le lot ${i+1}-$end.');
    }
  }

  printVm('🎉 Migration terminée ! $updatedCount profils mis à jour.');
}

Future<void> migrateInitialDatingProfilesForMen() async {
  try {
    printVm('🚀 === DÉBUT DE LA MIGRATION DES PROFILS DATING (HOMMES) ===');
    printVm('📅 Date de migration: ${DateTime.now()}');

    // Récupérer tous les utilisateurs dont le genre est "Homme"
    printVm('🔍 Recherche des utilisateurs avec genre = "Homme"...');
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .where('genre', isEqualTo: 'Homme')
        .get();

    printVm('📊 Total des utilisateurs trouvés: ${usersSnapshot.docs.length}');

    int createdCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    for (var userDoc in usersSnapshot.docs) {
      try {
        final userData = UserData.fromJson(userDoc.data());
        printVm('\n--- Traitement de l\'utilisateur ---');
        printVm('📱 ID: ${userData.id}');
        printVm('👤 Pseudo: ${userData.pseudo}');
        printVm('📧 Email: ${userData.email}');

        // Vérifier si un profil dating existe déjà
        final existingProfile = await FirebaseFirestore.instance
            .collection('dating_profiles')
            .where('userId', isEqualTo: userData.id)
            .limit(1)
            .get();

        if (existingProfile.docs.isNotEmpty) {
          printVm('⚠️ Profil dating déjà existant pour cet utilisateur - Ignoré');
          skippedCount++;
          continue;
        }

        // Calcul de l'âge avec gestion des différents formats de date
        final age = _calculateAgeFromUserDataSafe(userData);
        printVm('🎂 Âge calculé: $age ans');

        // Calcul du pourcentage de complétion
        final completionPercentage = _calculateCompletionPercentage(userData);
        printVm('📊 Pourcentage de complétion: ${completionPercentage.toStringAsFixed(1)}%');

        // ✅ CALCUL DU SCORE DE POPULARITÉ
        final userId = userData.id!;
        printVm('📊 Calcul du score de popularité pour $userId...');

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
        printVm('📊 Score calculé: $popularityScore (likes: ${likesCount.count}, coups: ${coupsCount.count}, connexions: ${connectionsCount.count})');

        final now = DateTime.now().millisecondsSinceEpoch;
        printVm('⏰ Timestamp actuel: $now');

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

        printVm('💾 Création du profil dating...');
        await FirebaseFirestore.instance
            .collection('dating_profiles')
            .doc(profileId)
            .set(datingProfile);

        printVm('✅ Profil dating créé avec succès (ID: $profileId, Score: $popularityScore)');
        createdCount++;

      } catch (e) {
        printVm('❌ Erreur lors du traitement de l\'utilisateur ${userDoc.id}: $e');
        errorCount++;
      }
    }

    printVm('\n📊 === RÉSUMÉ DE LA MIGRATION (HOMMES) ===');
    printVm('✅ Profils créés: $createdCount');
    printVm('⚠️ Profils ignorés (déjà existants): $skippedCount');
    printVm('❌ Erreurs: $errorCount');
    printVm('🎯 Total traité: ${usersSnapshot.docs.length}');
    printVm('✅ Migration des profils dating des hommes terminée avec succès!');

  } catch (e) {
    printVm('❌ ERREUR FATALE lors de la migration: $e');
    printVm('📋 Stack trace: ${StackTrace.current}');
  }
}
// Ajoutez cette méthode dans votre UserAuthProvider existant
Future<void> migrateInitialDatingProfiles() async {
  try {
    printVm('🚀 === DÉBUT DE LA MIGRATION DES PROFILS DATING ===');
    printVm('📅 Date de migration: ${DateTime.now()}');

    // Récupérer tous les utilisateurs dont le genre est "femme"
    printVm('🔍 Recherche des utilisateurs avec genre = "Femme"...');
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .where('genre', isEqualTo: 'Femme')
        .get();

    printVm('📊 Total des utilisateurs trouvés: ${usersSnapshot.docs.length}');

    int createdCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    for (var userDoc in usersSnapshot.docs) {
      try {
        final userData = UserData.fromJson(userDoc.data());
        printVm('\n--- Traitement de l\'utilisateur ---');
        printVm('📱 ID: ${userData.id}');
        printVm('👤 Pseudo: ${userData.pseudo}');
        printVm('📧 Email: ${userData.email}');

        // Vérifier si un profil dating existe déjà
        final existingProfile = await FirebaseFirestore.instance
            .collection('dating_profiles')
            .where('userId', isEqualTo: userData.id)
            .limit(1)
            .get();

        if (existingProfile.docs.isNotEmpty) {
          printVm('⚠️ Profil dating déjà existant pour cet utilisateur - Ignoré');
          skippedCount++;
          continue;
        }

        // Calcul de l'âge avec gestion des différents formats de date
        final age = _calculateAgeFromUserDataSafe(userData);
        printVm('🎂 Âge calculé: $age ans');

        // Calcul du pourcentage de complétion
        final completionPercentage = _calculateCompletionPercentage(userData);
        printVm('📊 Pourcentage de complétion: ${completionPercentage.toStringAsFixed(1)}%');

        // ✅ CALCUL DU SCORE DE POPULARITÉ
        final userId = userData.id!;
        printVm('📊 Calcul du score de popularité pour $userId...');

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
        printVm('📊 Score calculé: $popularityScore (likes: ${likesCount.count}, coups: ${coupsCount.count}, connexions: ${connectionsCount.count})');

        final now = DateTime.now().millisecondsSinceEpoch;
        printVm('⏰ Timestamp actuel: $now');

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

        printVm('💾 Création du profil dating...');
        await FirebaseFirestore.instance
            .collection('dating_profiles')
            .doc(profileId)
            .set(datingProfile);

        printVm('✅ Profil dating créé avec succès (ID: $profileId, Score: $popularityScore)');
        createdCount++;

      } catch (e) {
        printVm('❌ Erreur lors du traitement de l\'utilisateur ${userDoc.id}: $e');
        errorCount++;
      }
    }

    printVm('\n📊 === RÉSUMÉ DE LA MIGRATION ===');
    printVm('✅ Profils créés: $createdCount');
    printVm('⚠️ Profils ignorés (déjà existants): $skippedCount');
    printVm('❌ Erreurs: $errorCount');
    printVm('🎯 Total traité: ${usersSnapshot.docs.length}');
    printVm('✅ Migration des profils dating terminée avec succès!');

  } catch (e) {
    printVm('❌ ERREUR FATALE lors de la migration: $e');
    printVm('📋 Stack trace: ${StackTrace.current}');
  }
}

/// Calcule l'âge à partir des données utilisateur en gérant différents formats de date
int _calculateAgeFromUserDataSafe(UserData userData) {
  try {
    // Si createdAt est null, retourner 0
    if (userData.createdAt == null) {
      printVm('⚠️ createdAt est null, âge par défaut: 0');
      return 0;
    }

    DateTime birthDate;
    final createdAt = userData.createdAt;

    // Vérifier si c'est en microsecondes (valeur très grande > 10^12)
    if (createdAt! > 1000000000000) {
      // C'est probablement en microsecondes
      birthDate = DateTime.fromMicrosecondsSinceEpoch(createdAt!);
      printVm('📅 Date de naissance (microsecondes): $birthDate');
    }
    // Vérifier si c'est en millisecondes (valeur entre 10^9 et 10^12)
    else if (createdAt > 1000000000 && createdAt <= 1000000000000) {
      birthDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
      printVm('📅 Date de naissance (millisecondes): $birthDate');
    }
    // Sinon, traiter comme DateTime direct
    else {
      birthDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
      printVm('📅 Date de naissance (par défaut): $birthDate');
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
      printVm('⚠️ Âge invalide calculé: $age, utilisation de 0');
      return 0;
    }

    return age;

  } catch (e) {
    printVm('❌ Erreur lors du calcul de l\'âge: $e');
    printVm('📋 createdAt value: ${userData.createdAt}');
    return 0;
  }
}

double _calculateCompletionPercentage(UserData userData) {
  int completedFields = 0;
  int totalFields = 6;

  printVm('🔍 Vérification des champs pour le calcul de complétion:');

  // Pseudo
  if (userData.pseudo?.isNotEmpty ?? false) {
    completedFields++;
    printVm('  ✅ Pseudo: ${userData.pseudo}');
  } else {
    printVm('  ❌ Pseudo: manquant');
  }

  // Image URL
  if (userData.imageUrl?.isNotEmpty ?? false) {
    completedFields++;
    printVm('  ✅ Image URL: ${userData.imageUrl}');
  } else {
    printVm('  ❌ Image URL: manquant');
  }

  // Bio (apropos)
  if (userData.apropos?.isNotEmpty ?? false) {
    completedFields++;
    printVm('  ✅ Bio: ${userData.apropos?.substring(0, userData.apropos!.length > 50 ? 50 : userData.apropos!.length)}...');
  } else {
    printVm('  ❌ Bio: manquant');
  }

  // Genre
  if (userData.genre?.isNotEmpty ?? false) {
    completedFields++;
    printVm('  ✅ Genre: ${userData.genre}');
  } else {
    printVm('  ❌ Genre: manquant');
  }

  // Adresse
  if (userData.adresse?.isNotEmpty ?? false) {
    completedFields++;
    printVm('  ✅ Adresse: ${userData.adresse}');
  } else {
    printVm('  ❌ Adresse: manquant');
  }

  // Pays
  if (userData.userPays != null) {
    completedFields++;
    printVm('  ✅ Pays: ${userData.userPays?.name}');
  } else {
    printVm('  ❌ Pays: manquant');
  }

  final percentage = (completedFields / totalFields) * 100;
  printVm('📊 Total champs remplis: $completedFields/$totalFields');
  printVm('📊 Pourcentage de complétion: ${percentage.toStringAsFixed(1)}%');

  return percentage;
}