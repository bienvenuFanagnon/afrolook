
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postWidgetPage.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/postProvider.dart';

Future<bool> processPublicashTransaction({
  // required UserData userSendCadeau,
  required BuildContext context,
  // required UserAuthProvider authProvider,
  required PostProvider postProvider,
  required AppDefaultData appdata,
}) async {
  try {
    late UserAuthProvider authProvider =
    Provider.of<UserAuthProvider>(context, listen: false);
    UserData userSendCadeau =authProvider.loginUserData;
    // Récupérer l'utilisateur depuis Firestore
    CollectionReference userCollect = FirebaseFirestore.instance.collection('Users');
    QuerySnapshot querySnapshotUser = await userCollect.where("id", isEqualTo: userSendCadeau.id!).get();

    // Convertir les documents en objets UserData
    List<UserData> listUsers = querySnapshotUser.docs
        .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    // Vérifier si l'utilisateur existe
    if (listUsers.isEmpty) {
      printVm("Utilisateur non trouvé");
      return false;
    }

    // Mettre à jour les données de l'utilisateur
    userSendCadeau = listUsers.first;
    userSendCadeau.votre_solde_principal ??= 0.0;
    appdata.solde_gain ??= 0.0;

    // Vérifier si le solde est suffisant
    if (userSendCadeau.votre_solde_principal! < 2) {
      printVm("Solde insuffisant");
      showInsufficientBalanceDialog(context);
      return false;
    }

    // Mettre à jour les données du post
    // post.users_republier_id ??= [];
    // post.users_republier_id?.add(userSendCadeau.id!);

    // Déduire le montant du solde principal et ajouter au solde de gain
    userSendCadeau.votre_solde_principal = userSendCadeau.votre_solde_principal! - 2;
    appdata.solde_gain = appdata.solde_gain! + 2;

    // Mettre à jour les données dans Firestore
    // await postProvider.updateReplyPost(post, context);
    // await authProvider.updateUser(post.user!);
    await authProvider.updateUser(userSendCadeau);
    await authProvider.updateAppData(appdata);

    await authProvider.getUserById(userSendCadeau.id!).then(
      (value) {
        if(value.isNotEmpty){
          authProvider.loginUserData=value.first;

        }
      },
    );


    // Afficher un message de succès
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     backgroundColor: Colors.green,
    //     content: Text(
    //       '🔝 Félicitations ! Vous avez payé ce look',
    //       style: TextStyle(color: Colors.white),
    //     ),
    //   ),
    // );
    printVm("paiement accepter");

    // Retourner true pour indiquer que la transaction a réussi
    return true;
  } catch (e) {
    // Gérer les erreurs
    printVm("Erreur lors de la transaction : $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          'Une erreur s\'est produite. Veuillez réessayer.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
    return false;
  }
}