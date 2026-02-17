import 'package:afrotok/models/model_data.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constant/logo.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../component/consoleWidget.dart';
import '../userPosts/postTabs/userPostAudioTab.dart';
import '../userPosts/postTabs/userPostImageTab.dart';
import '../userPosts/postTabs/userPostTextTab.dart';
import '../userPosts/postTabs/userPostVideoTab.dart';

class CanalPostForm extends StatefulWidget {
  final Canal? canal;
  CanalPostForm({super.key, required this.canal});

  @override
  State<CanalPostForm> createState() => _CanalPostFormState();
}

class _CanalPostFormState extends State<CanalPostForm> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Couleurs personnalisées
  final Color _primaryColor = Color(0xFFE21221); // Rouge
  final Color _secondaryColor = Color(0xFFFFD600); // Jaune
  final Color _backgroundColor = Color(0xFF121212); // Noir
  final Color _cardColor = Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          "Publication Canal",
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _cardColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Logo(),
          )
        ],
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Carte du canal
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar du canal avec bordure colorée
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _primaryColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: Image.network(
                          widget.canal!.urlImage ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.group,
                                color: _primaryColor,
                                size: 30,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "#${widget.canal!.titre ?? 'Canal'}",
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _primaryColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people, size: 14, color: _primaryColor),
                                    SizedBox(width: 4),
                                    Text(
                                      "${widget.canal!.usersSuiviId?.length ?? 0} abonnés",
                                      style: TextStyle(
                                        color: _primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _secondaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _secondaryColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 14, color: _secondaryColor),
                                    SizedBox(width: 4),
                                    Text(
                                      "Canal",
                                      style: TextStyle(
                                        color: _secondaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          if (widget.canal!.description != null && widget.canal!.description!.isNotEmpty)
                            Text(
                              widget.canal!.description!,
                              style: TextStyle(
                                color: _hintColor,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Section des onglets de publication
              Container(
                width: width,
                height: height * 0.78,
                margin: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // En-tête des onglets
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.add_circle, color: Colors.white, size: 24),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nouvelle Publication',
                                  style: TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  'Choisissez le type de contenu à publier',
                                  style: TextStyle(
                                    color: _hintColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Onglets de contenu
                    Expanded(
                      child: ContainedTabBarView(
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.audiotrack, size: 20, color: _textColor),
                                SizedBox(width: 8),
                                Text(
                                  "Audio",
                                  style: TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.text_fields, size: 20, color: _textColor),
                                SizedBox(width: 8),
                                Text(
                                  "Texte",
                                  style: TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo, size: 20, color: _textColor),
                                SizedBox(width: 8),
                                Text(
                                  "Image",
                                  style: TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam, size: 20, color: _textColor),
                                SizedBox(width: 8),
                                Text(
                                  "Vidéo",
                                  style: TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        tabBarProperties: TabBarProperties(
                          height: 50.0,
                          indicatorColor: _primaryColor,
                          indicatorWeight: 3.0,
                          labelColor: _textColor,
                          unselectedLabelColor: _hintColor,
                          background: Container(
                            color: _cardColor,
                          ),
                        ),
                        views: [
                          // Onglet Texte
                          Container(
                            padding: EdgeInsets.all(8),
                            child: UserPostLookAudioTab(canal: widget.canal),
                          ),
                          Container(
                            padding: EdgeInsets.all(8),
                            child: UserPubText(canal: widget.canal),
                          ),
                          // Onglet Image
                          Container(
                            padding: EdgeInsets.all(8),
                            child: UserPostLookImageTab(canal: widget.canal),
                          ),
                          // Onglet Vidéo
                          Container(
                            padding: EdgeInsets.all(8),
                            child: UserPubVideo(canal: widget.canal),
                          ),
                        ],
                        onChange: (index) => printVm(index),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Informations supplémentaires
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: _primaryColor, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Votre publication sera visible par tous les abonnés du canal',
                        style: TextStyle(
                          color: _hintColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}