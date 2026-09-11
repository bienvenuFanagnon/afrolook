import 'package:afrotok/models/model_data.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constant/logo.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          l10n.canalNewPost,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Logo(),
          )
        ],
        iconTheme: IconThemeData(color: colors.textPrimary),
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
                  color: colors.surface,
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
                        border: Border.all(color: colors.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withOpacity(0.3),
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
                                color: colors.primary.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.group,
                                color: colors.primary,
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
                              color: colors.textPrimary,
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
                                  color: colors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colors.primary),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people, size: 14, color: colors.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      "${widget.canal!.usersSuiviId?.length ?? 0} ${l10n.canalFollowers}",
                                      style: TextStyle(
                                        color: colors.primary,
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
                                  color: colors.accent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colors.accent),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 14, color: colors.accent),
                                    SizedBox(width: 4),
                                    Text(
                                      "Canal",
                                      style: TextStyle(
                                        color: colors.accent,
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
                                color: colors.textSecondary,
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
                  color: colors.surface,
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
                        color: colors.surface,
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
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.add_circle, color: colors.onPrimary, size: 24),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.canalNewPost,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  l10n.canalPostChooseType,
                                  style: TextStyle(
                                    color: colors.textSecondary,
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
                      child: DefaultTabController(
                        length: 4,
                        child: Column(
                          children: [
                            Container(
                              color: colors.surface,
                              child: TabBar(
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                indicatorColor: colors.primary,
                                indicatorWeight: 3.0,
                                labelColor: colors.textPrimary,
                                unselectedLabelColor: colors.textSecondary,
                                tabs: [
                                  Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.audiotrack, size: 18),
                                    SizedBox(width: 6),
                                    Text("Audio", style: TextStyle(fontWeight: FontWeight.w600)),
                                  ])),
                                  Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.text_fields, size: 18),
                                    SizedBox(width: 6),
                                    Text("Texte", style: TextStyle(fontWeight: FontWeight.w600)),
                                  ])),
                                  Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.photo, size: 18),
                                    SizedBox(width: 6),
                                    Text("Image", style: TextStyle(fontWeight: FontWeight.w600)),
                                  ])),
                                  Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.videocam, size: 18),
                                    SizedBox(width: 6),
                                    Text("Vidéo", style: TextStyle(fontWeight: FontWeight.w600)),
                                  ])),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  Container(padding: EdgeInsets.all(8), child: UserPostLookAudioTab(canal: widget.canal)),
                                  Container(padding: EdgeInsets.all(8), child: UserPubText(canal: widget.canal)),
                                  Container(padding: EdgeInsets.all(8), child: UserPostLookImageTab(canal: widget.canal)),
                                  Container(padding: EdgeInsets.all(8), child: UserPubVideo(canal: widget.canal)),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: colors.primary, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.canalPostVisible,
                        style: TextStyle(
                          color: colors.textSecondary,
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