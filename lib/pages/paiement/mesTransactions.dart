import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/home_afroshop.dart';
import 'package:afrotok/pages/auth/authTest/constants.dart';
import 'package:afrotok/pages/paiement/transactionWidget.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/socialVideos/video_details.dart';
import 'package:afrotok/pages/user/amis/mesAmis.dart';
import 'package:afrotok/pages/user/amis/pageMesInvitations.dart';
import 'package:afrotok/pages/user/monetisation.dart';
import 'package:afrotok/pages/userPosts/challenge/listChallenge.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/userProvider.dart';


class MesTransactions extends StatefulWidget {
  const MesTransactions({super.key});

  @override
  State<MesTransactions> createState() => _MesTransactionsState();
}

class _MesTransactionsState extends State<MesTransactions> {
  bool onTap=false;

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final List<String> noms = ['Alice', 'Bob', 'Charlie'];
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  TextEditingController commentController =TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      // Si c'est le même jour
      if (difference.inHours < 1) {
        // Si moins d'une heure
        if (difference.inMinutes < 1) {
          return "publié il y a quelques secondes";
        } else {
          return "publié il y a ${difference.inMinutes} minutes";
        }
      } else {
        return "publié il y a ${difference.inHours} heures";
      }
    } else if (difference.inDays < 7) {
      // Si la semaine n'est pas passée
      return "publié ${difference.inDays} jours plus tôt";
    } else {
      // Si le jour est passé
      return "publié depuis ${DateFormat('dd MMMM yyyy').format(dateTime)}";
    }
  }



  List<TransactionSolde> transactions = []; // Liste locale pour stocker les notifications

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    transactions = [];
    return Scaffold(
        appBar: AppBar(
          title: Text('Mes transactions'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Stack(
              children: [
                Positioned(

                    top: 0,
                    bottom: 0,
                    left: 0,
                    right: 0,

                    child: Visibility(
                      visible: onTap?true:false,
                      child: Container(
                          width: width,
                          height: height,
                          color: Colors.transparent.withOpacity(0.2),

                          alignment: Alignment.center,
                          child: Container(
                              height: 30,
                              width: 30,

                              child: CircularProgressIndicator(backgroundColor: kPrimaryColor,))),
                    )),
                Container(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: StreamBuilder<List<TransactionSolde>>(
                      stream: postProvider.getTransactionsSoldes(authProvider.loginUserData.id!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && transactions.isEmpty) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text("Erreur de chargement", style: TextStyle(color: Colors.red)));
                        }

                        // // Ajouter la nouvelle notification à la liste locale
                        // if (snapshot.hasData && !transactions.contains(snapshot.data!)) {
                        //   // setState(() {
                        //   transactions.add(snapshot.data!);
                        //   // });
                        // }
                        transactions=snapshot.data!;
                        return Container(
                          width: width,
                          height: height * 0.86,
                          child: ListView.builder(
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              TransactionSolde transaction = transactions[index];


                              return Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: TransactionWidget(transaction: transaction),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                )
              ],
            ),
          ),
        ));
  }
}
