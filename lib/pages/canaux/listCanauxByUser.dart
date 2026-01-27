import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../providers/postProvider.dart';
import 'detailsCanal.dart';
import 'newCanal.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import 'detailsCanal.dart';
import 'newCanal.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import 'detailsCanal.dart';
import 'newCanal.dart';

class CanalListPageByUser extends StatefulWidget {
  @override
  _CanalListPageByUserState createState() => _CanalListPageByUserState();
}

class _CanalListPageByUserState extends State<CanalListPageByUser> {
  List<Canal> allCanaux = [];
  List<Canal> createdCanaux = [];
  List<Canal> adminCanaux = [];
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCanaux();
  }

  Future<void> _loadCanaux() async {
    setState(() {
      isLoading = true;
      hasError = false;
      allCanaux.clear();
      createdCanaux.clear();
      adminCanaux.clear();
    });

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final userId = authProvider.loginUserData.id!;

      // Utiliser la nouvelle fonction qui combine les deux requêtes
      final stream = postProvider.getAllCanauxForUser(userId);

      await for (Canal canal in stream) {
        // Vérifier si le canal est déjà dans la liste
        if (!allCanaux.any((c) => c.id == canal.id)) {
          allCanaux.add(canal);

          // Séparer en deux listes
          if (canal.userId == userId) {
            // Canal créé par l'utilisateur
            createdCanaux.add(canal);
          } else {
            // Canal où l'utilisateur est admin mais pas créateur
            adminCanaux.add(canal);
          }

          setState(() {});
        }
      }

      setState(() {
        isLoading = false;
      });

    } catch (e) {
      print("Erreur chargement canaux: $e");
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Erreur de chargement: $e';
      });
    }
  }

  Future<void> _suivreCanal(Canal canal, BuildContext context) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final userId = authProvider.loginUserData.id!;

    if (!canal.usersSuiviId!.contains(userId)) {
      try {
        canal.usersSuiviId!.add(userId);

        await firestore.collection('Canaux').doc(canal.id).update({
          'usersSuiviId': canal.usersSuiviId,
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        });

        // Créer une notification
        final notif = NotificationData(
          id: firestore.collection('Notifications').doc().id,
          titre: "Canal 📺",
          media_url: authProvider.loginUserData.imageUrl,
          type: "FOLLOW_CANAL",
          description: "@${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!}",
          user_id: userId,
          receiver_id: canal.userId,
          createdAt: DateTime.now().microsecondsSinceEpoch,
          updatedAt: DateTime.now().microsecondsSinceEpoch,
          status: "VALIDE",
        );

        await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vous suivez maintenant ce canal',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {});
      } catch (e) {
        print("Erreur suivre canal: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors du suivi',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCanalCard(Canal canal, BuildContext context, {bool isAdminCard = false}) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final isOwner = canal.userId == authProvider.loginUserData.id;
    final isFollowing = canal.usersSuiviId?.contains(authProvider.loginUserData.id) == true;
    final isAdmin = canal.adminIds?.contains(authProvider.loginUserData.id) == true && !isOwner;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CanalDetails(canal: canal),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar du canal avec badge
                Stack(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isOwner
                              ? [Color(0xFFC62828), Color(0xFFFFD600)]
                              : isAdminCard
                              ? [Color(0xFF6A1B9A), Color(0xFF9C27B0)]
                              : [Color(0xFF2196F3), Color(0xFF03A9F4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        backgroundImage: canal.urlImage != null && canal.urlImage!.isNotEmpty
                            ? NetworkImage(canal.urlImage!)
                            : null,
                        child: canal.urlImage == null || canal.urlImage!.isEmpty
                            ? Icon(
                          isOwner ? Icons.star : Icons.admin_panel_settings,
                          size: 30,
                          color: isOwner ? Color(0xFFC62828) : Color(0xFF6A1B9A),
                        )
                            : null,
                      ),
                    ),
                    if (canal.isVerify == true)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 1.5),
                          ),
                          child: Icon(
                            Icons.verified,
                            size: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    // Badge propriétaire/admin
                    if (isOwner || isAdmin)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOwner ? Color(0xFFC62828) : Color(0xFF6A1B9A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isOwner ? 'PROPRIO' : 'ADMIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(width: 16),

                // Infos du canal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "#${canal.titre ?? 'Sans nom'}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 4),

                      // Info créateur (seulement pour les canaux administrés)
                      if (isAdminCard && canal.user != null)
                        Text(
                          'Créé par: ${canal.user!.pseudo ?? 'Inconnu'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      if (canal.description != null && canal.description!.isNotEmpty)
                        Text(
                          canal.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      SizedBox(height: 8),

                      Row(
                        children: [
                          // Abonnés
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                size: 16,
                                color: Color(0xFFFFD600),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "${canal.usersSuiviId?.length ?? 0}",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(width: 16),

                          // Publications
                          Row(
                            children: [
                              Icon(
                                Icons.post_add,
                                size: 16,
                                color: Color(0xFFC62828),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "${canal.publication ?? 0}",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),

                          Spacer(),

                          // Type de canal
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: canal.isPrivate == true
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: canal.isPrivate == true ? Colors.orange : Colors.green,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  canal.isPrivate == true ? Icons.lock : Icons.public,
                                  size: 12,
                                  color: canal.isPrivate == true ? Colors.orange : Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  canal.isPrivate == true ? 'Privé' : 'Public',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: canal.isPrivate == true ? Colors.orange : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bouton d'action
                if (!isOwner && !isFollowing)
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    child: ElevatedButton(
                      onPressed: () => _suivreCanal(canal, context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFC62828),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        'Suivre',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required int count, required Color color}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection({required String message, required IconData icon, Color? color}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 50,
            color: color ?? Colors.grey.shade300,
          ),
          SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC62828)),
          ),
          SizedBox(height: 16),
          Text(
            'Chargement des canaux...',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadCanaux,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(
              'Réessayer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAll() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off,
            size: 80,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16),
          Text(
            'Aucun canal',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Créez votre premier canal',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NewCanal()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(
              'Créer un canal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCreatedCanals = createdCanaux.isNotEmpty;
    final hasAdminCanals = adminCanaux.isNotEmpty;
    final isEmpty = !hasCreatedCanals && !hasAdminCanals;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Mes Canaux',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFFC62828),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loadCanaux,
            icon: Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: isLoading
          ? _buildLoading()
          : hasError
          ? _buildError()
          : isEmpty
          ? _buildEmptyAll()
          : RefreshIndicator(
        onRefresh: _loadCanaux,
        color: Color(0xFFC62828),
        child: ListView(
          padding: EdgeInsets.only(bottom: 80),
          children: [
            // Section Canaux Créés
            if (hasCreatedCanals) ...[
              _buildSectionHeader(
                title: 'Canaux que j\'ai créés',
                count: createdCanaux.length,
                color: Color(0xFFC62828),
              ),
              ...createdCanaux.map((canal) => _buildCanalCard(
                canal,
                context,
                isAdminCard: false,
              )).toList(),
              SizedBox(height: 20),
            ] else ...[
              _buildSectionHeader(
                title: 'Canaux que j\'ai créés',
                count: 0,
                color: Color(0xFFC62828),
              ),
              _buildEmptySection(
                message: 'Vous n\'avez créé aucun canal',
                icon: Icons.group_off,
                color: Color(0xFFC62828).withOpacity(0.5),
              ),
            ],

            // Section Canaux Administrés
            if (hasAdminCanals) ...[
              _buildSectionHeader(
                title: 'Canaux que j\'administre',
                count: adminCanaux.length,
                color: Color(0xFF6A1B9A),
              ),
              ...adminCanaux.map((canal) => _buildCanalCard(
                canal,
                context,
                isAdminCard: true,
              )).toList(),
            ] else ...[
              _buildSectionHeader(
                title: 'Canaux que j\'administre',
                count: 0,
                color: Color(0xFF6A1B9A),
              ),
              _buildEmptySection(
                message: 'Vous n\'administrez aucun canal',
                icon: Icons.admin_panel_settings_outlined,
                color: Color(0xFF6A1B9A).withOpacity(0.5),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewCanal()),
          );
        },
        backgroundColor: Color(0xFFC62828),
        foregroundColor: Colors.white,
        child: Icon(Icons.add, size: 28),
        shape: CircleBorder(),
      ),
    );
  }
}
// class CanalListPageByUser extends StatefulWidget {
//   final bool isUserCanals;
//
//   CanalListPageByUser({required this.isUserCanals});
//
//   @override
//   _CanalListPageByUserState createState() => _CanalListPageByUserState();
// }
//
// class _CanalListPageByUserState extends State<CanalListPageByUser> {
//   List<Canal> canaux = [];
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   bool isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadCanaux();
//   }
//
//   Future<void> _loadCanaux() async {
//     setState(() => isLoading = true);
//
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final postProvider = Provider.of<PostProvider>(context, listen: false);
//
//     try {
//       final stream = postProvider.getCanauxByUser(authProvider.loginUserData.id!);
//       stream.listen((canal) {
//         if (!canaux.any((c) => c.id == canal.id)) {
//           setState(() {
//             canaux.add(canal);
//             isLoading = false;
//           });
//         }
//       });
//     } catch (e) {
//       print("Erreur chargement canaux: $e");
//       setState(() => isLoading = false);
//     }
//   }
//
//   Future<void> _suivreCanal(Canal canal, BuildContext context) async {
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//
//     if (!canal.usersSuiviId!.contains(authProvider.loginUserData.id)) {
//       canal.usersSuiviId!.add(authProvider.loginUserData.id!);
//
//       await firestore.collection('Canaux').doc(canal.id).update({
//         'usersSuiviId': canal.usersSuiviId,
//       });
//
//       // Créer une notification
//       final notif = NotificationData(
//         id: firestore.collection('Notifications').doc().id,
//         titre: "Canal 📺",
//         media_url: authProvider.loginUserData.imageUrl,
//         type: "FOLLOW_CANAL",
//         description: "@${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!}",
//         user_id: authProvider.loginUserData.id,
//         receiver_id: canal.userId,
//         createdAt: DateTime.now().microsecondsSinceEpoch,
//         updatedAt: DateTime.now().microsecondsSinceEpoch,
//         status: "VALIDE",
//       );
//
//       await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Vous suivez maintenant ce canal',
//             style: TextStyle(color: Colors.white),
//           ),
//           backgroundColor: Colors.green,
//         ),
//       );
//
//       setState(() {});
//     }
//   }
//
//   Widget _buildCanalCard(Canal canal, BuildContext context) {
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final isOwner = canal.userId == authProvider.loginUserData.id;
//     final isFollowing = canal.usersSuiviId!.contains(authProvider.loginUserData.id);
//
//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 8,
//             offset: Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => CanalDetails(canal: canal),
//               ),
//             );
//           },
//           borderRadius: BorderRadius.circular(16),
//           child: Padding(
//             padding: EdgeInsets.all(16),
//             child: Row(
//               children: [
//                 // Avatar du canal
//                 Stack(
//                   children: [
//                     Container(
//                       width: 70,
//                       height: 70,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         gradient: LinearGradient(
//                           colors: [Color(0xFFC62828), Color(0xFFFFD600)],
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                         ),
//                       ),
//                       child: CircleAvatar(
//                         radius: 32,
//                         backgroundColor: Colors.white,
//                         backgroundImage: canal.urlImage != null && canal.urlImage!.isNotEmpty
//                             ? NetworkImage(canal.urlImage!)
//                             : null,
//                         child: canal.urlImage == null || canal.urlImage!.isEmpty
//                             ? Icon(
//                           Icons.group,
//                           size: 30,
//                           color: Color(0xFFC62828),
//                         )
//                             : null,
//                       ),
//                     ),
//                     if (canal.isVerify == true)
//                       Positioned(
//                         bottom: 0,
//                         right: 0,
//                         child: Container(
//                           padding: EdgeInsets.all(3),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             shape: BoxShape.circle,
//                             border: Border.all(color: Colors.blue, width: 1.5),
//                           ),
//                           child: Icon(
//                             Icons.verified,
//                             size: 14,
//                             color: Colors.blue,
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//
//                 SizedBox(width: 16),
//
//                 // Infos du canal
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               "#${canal.titre ?? 'Sans nom'}",
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.black,
//                               ),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       SizedBox(height: 4),
//
//                       if (canal.description != null && canal.description!.isNotEmpty)
//                         Text(
//                           canal.description!,
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: Colors.grey.shade600,
//                           ),
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//
//                       SizedBox(height: 8),
//
//                       Row(
//                         children: [
//                           // Abonnés
//                           Row(
//                             children: [
//                               Icon(
//                                 Icons.people,
//                                 size: 16,
//                                 color: Color(0xFFFFD600),
//                               ),
//                               SizedBox(width: 4),
//                               Text(
//                                 "${canal.usersSuiviId?.length ?? 0}",
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w600,
//                                   color: Colors.black,
//                                 ),
//                               ),
//                             ],
//                           ),
//
//                           SizedBox(width: 16),
//
//                           // Publications
//                           Row(
//                             children: [
//                               Icon(
//                                 Icons.post_add,
//                                 size: 16,
//                                 color: Color(0xFFC62828),
//                               ),
//                               SizedBox(width: 4),
//                               Text(
//                                 "${canal.publication ?? 0}",
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w600,
//                                   color: Colors.black,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Bouton d'action
//                 if (!isOwner && !isFollowing)
//                   Container(
//                     margin: EdgeInsets.only(left: 8),
//                     child: ElevatedButton(
//                       onPressed: () => _suivreCanal(canal, context),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Color(0xFFC62828),
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                       ),
//                       child: Text(
//                         'Suivre',
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade50,
//       appBar: AppBar(
//         title: Text(
//           'Mes Canaux',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         backgroundColor: Color(0xFFC62828),
//         iconTheme: IconThemeData(color: Colors.white),
//         actions: [
//           IconButton(
//             onPressed: _loadCanaux,
//             icon: Icon(Icons.refresh, color: Colors.white),
//             tooltip: 'Rafraîchir',
//           ),
//         ],
//       ),
//       body: isLoading && canaux.isEmpty
//           ? Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC62828)),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Chargement des canaux...',
//               style: TextStyle(
//                 color: Colors.grey.shade600,
//               ),
//             ),
//           ],
//         ),
//       )
//           : canaux.isEmpty
//           ? Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.group_off,
//               size: 80,
//               color: Colors.grey.shade300,
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Aucun canal',
//               style: TextStyle(
//                 fontSize: 18,
//                 color: Colors.grey.shade600,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               'Créez votre premier canal',
//               style: TextStyle(
//                 color: Colors.grey.shade500,
//               ),
//             ),
//             SizedBox(height: 24),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (context) => NewCanal()),
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Color(0xFFC62828),
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
//               ),
//               child: Text(
//                 'Créer un canal',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       )
//           : RefreshIndicator(
//         onRefresh: _loadCanaux,
//         color: Color(0xFFC62828),
//         child: ListView.builder(
//           physics: AlwaysScrollableScrollPhysics(),
//           itemCount: canaux.length,
//           itemBuilder: (context, index) {
//             return _buildCanalCard(canaux[index], context);
//           },
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => NewCanal()),
//           );
//         },
//         backgroundColor: Color(0xFFC62828),
//         foregroundColor: Colors.white,
//         child: Icon(Icons.add, size: 28),
//         shape: CircleBorder(),
//       ),
//     );
//   }
// }