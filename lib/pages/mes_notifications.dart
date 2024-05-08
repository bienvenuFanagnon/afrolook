import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/authProvider.dart';
import '../providers/postProvider.dart';
import '../providers/userProvider.dart';

class MesNotification extends StatefulWidget {
  const MesNotification({super.key});

  @override
  State<MesNotification> createState() => _MesNotificationState();
}

class _MesNotificationState extends State<MesNotification> {

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final List<String> noms = ['Alice', 'Bob', 'Charlie'];
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
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

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: Text('Notifications'),
        ),
        body: SingleChildScrollView(
          child: Container(

            child: Padding(
              padding: const EdgeInsets.all(8),
              child: StreamBuilder<List<NotificationData>>(

                stream: postProvider.getListNotificatio(authProvider.loginUserData.id!),
                builder: (context, snapshot) {

                  if (snapshot.connectionState == ConnectionState.waiting) {

                    return
                      Center(child: Container(width:50 , height:50,child: CircularProgressIndicator()));
                  }else if (snapshot.hasError) {
                    return
                      Center(child: Container(width:50 , height:50,child: CircularProgressIndicator()));
                  }else{
                    return Container(
                      width: width,
                      height: height,
                      child: ListView.builder(
                        //reverse: true,

                          itemCount: snapshot!.data!.length, // Nombre d'éléments dans la liste
                          itemBuilder: (context, index) {
                            List<NotificationData> list=snapshot!.data!;

                            if (!isIn(list[index].users_id_view!,authProvider.loginUserData.id!)) {
                             // list.remove(n);
                              list[index].users_id_view!.add(authProvider.loginUserData.id!);
                               firestore.collection('Notifications').doc( list[index]!.id).update( list[index]!.toJson());

                            }

                            return Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(Radius.circular(5)),
                                  color: Colors.black12,

                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: ListTile(
                                  
                                    title: Text('${list[index].titre}',style: TextStyle(color: Colors.blue),),
                                    subtitle: Text('${list[index].description}'),
                                    leading: Icon(
                                      Icons.notifications,
                                      color:isIn(list[index].users_id_view!,authProvider.loginUserData.id!)? Colors.black87:Colors.red,
                                    ),
                                    trailing: Text("${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(list[index].createdAt!))}",style: TextStyle(fontSize: 8,color: Colors.black87),),),
                                ),
                              ),
                            );

                          }),
                    );

                  }
                },
              ),
            ),
          ),
        ));
  }
}
