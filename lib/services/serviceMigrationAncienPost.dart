// Créez un nouveau fichier migration_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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