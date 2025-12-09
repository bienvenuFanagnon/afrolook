import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/contentDetailsEbook.dart';
import 'package:afrotok/pages/contenuPayant/seriesDetailScreenContenu.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/authProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import '../user/profile/profile.dart';
import 'contentDetails.dart';
import 'contentForm.dart';
import 'contentSerie.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/seriesDetailScreenContenu.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/authProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import '../user/profile/profile.dart';
import 'contentDetails.dart';
import 'contentForm.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/seriesDetailScreenContenu.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/authProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import '../user/profile/profile.dart';
import 'contentDetails.dart';
import 'contentForm.dart';

class ProfileScreenContenu extends StatefulWidget {
  final String? userId;

  ProfileScreenContenu({this.userId});

  @override
  _ProfileScreenContenuState createState() => _ProfileScreenContenuState();
}

class _ProfileScreenContenuState extends State<ProfileScreenContenu> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    if (widget.userId != null && widget.userId != authProvider.loginUserData.id) {
      await contentProvider.loadOtherUserContentPaies(widget.userId!);
    } else {
      await contentProvider.loadUserContentPaies();
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final contentProvider = Provider.of<ContentProvider>(context);

    final UserData user;
    final bool isCurrentUser;
    final List<ContentPaie> userVideos;
    final List<ContentPaie> userSeries;

    if (widget.userId != null && widget.userId != authProvider.loginUserData.id) {
      user = contentProvider.otherUserData ?? authProvider.loginUserData;
      isCurrentUser = false;
      userVideos = contentProvider.otherUserContentPaies.where((c) => !c.isSeries).toList();
      userSeries = contentProvider.otherUserContentPaies.where((c) => c.isSeries).toList();
    } else {
      user = authProvider.loginUserData;
      isCurrentUser = true;
      userVideos = contentProvider.userContentPaies.where((c) => !c.isSeries).toList();
      userSeries = contentProvider.userContentPaies.where((c) => c.isSeries).toList();
    }

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC62828)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // AppBar avec tabs
            SliverAppBar(
              title: Text(
                isCurrentUser ? 'Mon Profil Créateur' : 'Profil Créateur',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Color(0xFFC62828),
              iconTheme: IconThemeData(color: Colors.white),
              actions: isCurrentUser
                  ? [
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadUserData,
                  tooltip: 'Rafraîchir',
                ),
              ]
                  : null,
              pinned: true,
              floating: true,
              snap: true,
              expandedHeight: 360, // Hauteur totale du header (y compris les tabs)
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _buildHeader(user, isCurrentUser),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(50),
                child: Container(
                  color: Colors.white,
                  child: TabBar(

                    controller: _tabController,
                    indicatorColor: Color(0xFFC62828),
                    indicatorWeight: 2,
                    labelColor: Color(0xFFC62828),
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam, size: 18),
                            SizedBox(width: 6),
                            Text('Vidéos/Ebooks'),
                            SizedBox(width: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFC62828).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${userVideos.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC62828),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.movie_filter, size: 18),
                            SizedBox(width: 6),
                            Text('Séries'),
                            SizedBox(width: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFC62828).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${userSeries.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC62828),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tab(
                      //   child: Row(
                      //     mainAxisAlignment: MainAxisAlignment.center,
                      //     children: [
                      //       Icon(Icons.bar_chart, size: 18),
                      //       SizedBox(width: 6),
                      //       Text('Statistiques'),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Onglet Vidéos/Ebooks
            _buildVideosTab(userVideos, isCurrentUser),
            // Onglet Séries
            _buildSeriesTab(userSeries, isCurrentUser),
            // // Onglet Statistiques
            // _buildStatsTab(user, isCurrentUser),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UserData user, bool isCurrentUser) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFC62828), Color(0xFFFFD600)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(height: 50),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Photo de profil
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: user.imageUrl != null && user.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                            imageUrl: user.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade800,
                              child: Center(
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade800,
                              child: Center(
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          )
                              : Container(
                            color: Colors.grey.shade800,
                            child: Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (user.isVerify ?? false)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blue, width: 2),
                            ),
                            child: Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${user.pseudo ?? 'Utilisateur'}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Créateur de contenu',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [

                            SizedBox(width: 16),
                            _buildStatItem(Icons.people, '${user.userAbonnesIds!.length ?? 0}', 'Abonnés'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            if (isCurrentUser)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ContentFormScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFFC62828),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 3,
                        ),
                        icon: Icon(Icons.add_circle, size: 22),
                        label: Text(
                          'Nouveau contenu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => UserProfil()),
                        );
                      },
                      icon: Icon(Icons.more_horiz, color: Colors.white, size: 32),
                      tooltip: 'Voir profil complet',
                    ),
                  ],
                ),
              ),
            if (isCurrentUser) SizedBox(height: 16),
            if (isCurrentUser)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Color(0xFFFFD600), size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Solde :',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${user.votre_solde_principal?.toStringAsFixed(2) ?? '0'} FCFA',
                      style: TextStyle(
                        color: Color(0xFFFFD600),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Color(0xFFFFD600), size: 18),
            SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildVideosTab(List<ContentPaie> videos, bool isCurrentUser) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 90,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 20),
            Text(
              isCurrentUser ? 'Aucun contenu publié' : 'Aucun contenu disponible',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              isCurrentUser ? 'Commencez par créer votre premier contenu' : 'Cet utilisateur n\'a pas encore publié',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            if (isCurrentUser)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ContentFormScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Créer un contenu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: Color(0xFFC62828),
      child: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return _buildContentCard(video);
        },
      ),
    );
  }

  Widget _buildSeriesTab(List<ContentPaie> series, bool isCurrentUser) {
    if (series.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_filter,
              size: 90,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 20),
            Text(
              isCurrentUser ? 'Aucune série créée' : 'Aucune série disponible',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              isCurrentUser ? 'Créez votre première série de contenus' : 'Cet utilisateur n\'a pas encore créé de série',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            if (isCurrentUser)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ContentFormScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Créer une série',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: Color(0xFFC62828),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: series.length,
        itemBuilder: (context, index) {
          final serie = series[index];
          return _buildSeriesCard(serie, isCurrentUser);
        },
      ),
    );
  }

  Widget _buildContentCard(ContentPaie content) {
    return GestureDetector(
      onTap: () {
        if(content.isEbook){
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EbookDetailScreen(content: content)),
          );
        }else{
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ContentDetailScreen(content: content)),
          );
        }

      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 130,
                    child: CachedNetworkImage(
                      imageUrl: content.thumbnailUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFC62828),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Icon(
                            content.isVideo ? Icons.videocam : Icons.menu_book,
                            color: Colors.grey.shade400,
                            size: 45,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: content.isVideo ? Color(0xFFC62828) : Color(0xFFFFD600),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          content.isVideo ? Icons.play_arrow_rounded : Icons.book_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          content.isVideo ? 'VIDÉO' : 'EBOOK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: content.isFree ? Colors.green : Color(0xFFFFD600),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      content.isFree ? 'GRATUIT' : '${content.price.toInt()} FCFA',
                      style: TextStyle(
                        color: content.isFree ? Colors.white : Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (content.isVideo)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Container(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      _buildStatWithIcon(
                        icon: Icons.remove_red_eye_outlined,
                        value: content.views.toString(),
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 16),
                      _buildStatWithIcon(
                        icon: Icons.thumb_up_outlined,
                        value: content.likes.toString(),
                        color: Colors.grey.shade600,
                      ),
                      Spacer(),
                      if (content.isEbook && content.pageCount > 0)
                        _buildStatWithIcon(
                          icon: Icons.menu_book_outlined,
                          value: '${content.pageCount} p',
                          color: Color(0xFFC62828),
                        ),
                      if (content.isVideo && content.duration > 0)
                        _buildStatWithIcon(
                          icon: Icons.timer_outlined,
                          value: _formatDuration(content.duration),
                          color: Color(0xFFC62828),
                        ),
                    ],
                  ),
                  // if (content.hashtags.isNotEmpty)
                  //   Padding(
                  //     padding: EdgeInsets.only(top: 10),
                  //     child: Wrap(
                  //       spacing: 6,
                  //       runSpacing: 4,
                  //       children: content.hashtags.take(3).map((tag) {
                  //         return Container(
                  //           padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  //           decoration: BoxDecoration(
                  //             color: Colors.grey.shade100,
                  //             borderRadius: BorderRadius.circular(12),
                  //           ),
                  //           child: Text(
                  //             '#$tag',
                  //             style: TextStyle(
                  //               fontSize: 10,
                  //               color: Colors.grey.shade700,
                  //               fontWeight: FontWeight.w500,
                  //             ),
                  //           ),
                  //         );
                  //       }).toList(),
                  //     ),
                  //   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesCard(ContentPaie serie, bool isCurrentUser) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SeriesDetailScreen(series: serie)),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: serie.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFC62828),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Text(
                    serie.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFC62828),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.movie_filter_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'SÉRIE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (serie.description.isNotEmpty)
                    Text(
                      serie.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: serie.isFree
                              ? Colors.green.withOpacity(0.1)
                              : Color(0xFFFFD600).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: serie.isFree ? Colors.green : Color(0xFFFFD600),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          serie.isFree ? 'GRATUIT' : '${serie.price.toInt()} FCFA',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: serie.isFree ? Colors.green : Colors.black,
                          ),
                        ),
                      ),
                      Spacer(),
                      FutureBuilder<List<Episode>>(
                        future: Provider.of<ContentProvider>(context, listen: false)
                            .getEpisodesForSeries(serie.id!),
                        builder: (context, snapshot) {
                          final episodeCount = snapshot.hasData ? snapshot.data!.length : 0;
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.playlist_play_rounded, size: 14, color: Color(0xFFC62828)),
                                SizedBox(width: 6),
                                Text(
                                  '$episodeCount épisode${episodeCount > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 12),
                      if (isCurrentUser)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(0xFFC62828),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFC62828).withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(Icons.add, color: Colors.white, size: 20),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ContentFormScreen(
                                    isEpisode: true,
                                    seriesId: serie.id,
                                  ),
                                ),
                              );
                            },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatWithIcon({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab(UserData user, bool isCurrentUser) {
    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: Color(0xFFC62828),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard2(
                  title: 'Vues totales',
                  value: '${user.userlikes ?? 0}',
                  icon: Icons.visibility,
                  color: Color(0xFFC62828),
                ),
                _buildStatCard2(
                  title: 'Likes totaux',
                  value: '${user.likes ?? 0}',
                  icon: Icons.thumb_up,
                  color: Color(0xFFFFD600),
                ),
                _buildStatCard2(
                  title: 'Abonnés',
                  value: '${user.userAbonnesIds!.length ?? 0}',
                  icon: Icons.people,
                  color: Colors.black,
                ),
                _buildStatCard2(
                  title: 'Contenus',
                  value: '${user.userAbonnesIds?.length ?? 0}',
                  icon: Icons.video_library,
                  color: Colors.green,
                ),
              ],
            ),
            SizedBox(height: 24),
            if (isCurrentUser)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenus',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildRevenueCard(
                    title: 'Solde Principal',
                    value: '${user.votre_solde_principal?.toStringAsFixed(2) ?? '0'} FCFA',
                    icon: Icons.account_balance_wallet,
                    color: Color(0xFFC62828),
                  ),
                  SizedBox(height: 8),
                  _buildRevenueCard(
                    title: 'Solde Contenu',
                    value: '${user.votre_solde_contenu?.toStringAsFixed(2) ?? '0'} FCFA',
                    icon: Icons.movie,
                    color: Color(0xFFFFD600),
                  ),
                  SizedBox(height: 8),
                  _buildRevenueCard(
                    title: 'Solde Cadeau',
                    value: '${user.votre_solde_cadeau?.toStringAsFixed(2) ?? '0'} FCFA',
                    icon: Icons.card_giftcard,
                    color: Colors.black,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard2({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
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
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: color, size: 24),
            ),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 22),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// class ProfileScreenContenu extends StatefulWidget {
//   @override
//   _ProfileScreenContenuState createState() => _ProfileScreenContenuState();
// }
//
// class _ProfileScreenContenuState extends State<ProfileScreenContenu> with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final userAuthProvider = Provider.of<UserAuthProvider>(context);
//     final contentProvider = Provider.of<ContentProvider>(context);
//     final user = userAuthProvider.loginUserData;
//
//     final userVideos = contentProvider.userContentPaies.where((c) => !c.isSeries).toList();
//     final userSeries = contentProvider.userContentPaies.where((c) => c.isSeries).toList();
//
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       appBar: AppBar(
//         title: Text('Mon Profil de Créateur', style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.green[800],
//         iconTheme: IconThemeData(color: Colors.white),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.add, color: Colors.white),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => ContentFormScreen()),
//               );
//             },
//           ),
//         ],
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: Colors.yellow,
//           labelColor: Colors.white,
//           unselectedLabelColor: Colors.white70,
//           tabs: [
//             Tab(text: 'Vidéos (${userVideos.length})'),
//             Tab(text: 'Séries (${userSeries.length})'),
//             Tab(text: 'Statistiques'),
//           ],
//         ),
//       ),
//       body: Column(
//         children: [
//           // En-tête avec informations utilisateur et solde
//           _buildUserHeader(user),
//           Divider(height: 1, color: Colors.grey[300]),
//           Expanded(
//             child: TabBarView(
//               controller: _tabController,
//               children: [
//                 _buildVideosTab(userVideos, contentProvider),
//                 _buildSeriesTab(userSeries, contentProvider),
//                 _buildStatsTab(user),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildUserHeader(UserData? user) {
//     return Container(
//       color: Colors.white,
//       padding: EdgeInsets.all(16),
//       child: Row(
//         children: [
//           // Photo de profil
//           Container(
//             width: 70,
//             height: 70,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               border: Border.all(color: Colors.green, width: 2),
//             ),
//             child: ClipOval(
//               child: user?.imageUrl != null && user!.imageUrl!.isNotEmpty
//                   ? CachedNetworkImage(
//                 imageUrl: user.imageUrl!,
//                 fit: BoxFit.cover,
//                 placeholder: (context, url) => Container(
//                   color: Colors.grey[300],
//                   child: Icon(Icons.person, color: Colors.grey),
//                 ),
//                 errorWidget: (context, url, error) => Container(
//                   color: Colors.grey[300],
//                   child: Icon(Icons.person, color: Colors.grey),
//                 ),
//               )
//                   : Container(
//                 color: Colors.grey[300],
//                 child: Icon(Icons.person, color: Colors.grey, size: 40),
//               ),
//             ),
//           ),
//           SizedBox(width: 16),
//           // Informations utilisateur
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   user?.pseudo ?? 'Utilisateur',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   'Créateur de contenu',
//                   style: TextStyle(
//                     fontSize: 14,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//                 SizedBox(height: 8),
//                 // Solde principal
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                   decoration: BoxDecoration(
//                     color: Colors.yellow[50],
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: Colors.yellow[700]!),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(Icons.account_balance_wallet, color: Colors.yellow[800], size: 16),
//                       SizedBox(width: 8),
//                       Text(
//                         'Solde : ',
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.grey[700],
//                         ),
//                       ),
//                       Text(
//                         '${user?.votre_solde_principal!.toStringAsFixed(2) ?? 0} FCFA',
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.green[800],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // Bouton Voir plus
//           Column(
//             children: [
//               IconButton(
//                 icon: Icon(Icons.visibility, color: Colors.green),
//                 onPressed: () {
//                   // Navigation vers la page de profil utilisateur complet
//                   Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfil()));
//                 },
//               ),
//               Text(
//                 'Voir plus',
//                 style: TextStyle(fontSize: 12, color: Colors.green),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildVideosTab(List<ContentPaie> videos, ContentProvider contentProvider) {
//     if (videos.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.videocam_off, size: 60, color: Colors.grey),
//             SizedBox(height: 16),
//             Text(
//               'Aucune vidéo publiée',
//               style: TextStyle(color: Colors.grey, fontSize: 18),
//             ),
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (context) => ContentFormScreen()),
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green[800],
//                 foregroundColor: Colors.white,
//                 padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               ),
//               child: Text('Créer une vidéo'),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return GridView.builder(
//       padding: EdgeInsets.all(16),
//       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         crossAxisSpacing: 12,
//         mainAxisSpacing: 12,
//         childAspectRatio: 0.8,
//       ),
//       itemCount: videos.length,
//       itemBuilder: (context, index) {
//         final video = videos[index];
//         return _buildVideoItem(video);
//       },
//     );
//   }
//
//   Widget _buildSeriesTab(List<ContentPaie> series, ContentProvider contentProvider) {
//     if (series.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.movie_filter, size: 60, color: Colors.grey),
//             SizedBox(height: 16),
//             Text(
//               'Aucune série créée',
//               style: TextStyle(color: Colors.grey, fontSize: 18),
//             ),
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (context) => ContentFormScreen()),
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green[800],
//                 foregroundColor: Colors.white,
//                 padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               ),
//               child: Text('Créer une série'),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return ListView.builder(
//       padding: EdgeInsets.all(16),
//       itemCount: series.length,
//       itemBuilder: (context, index) {
//         final serie = series[index];
//         return FutureBuilder<List<Episode>>(
//           future: contentProvider.getEpisodesForSeries(serie.id!),
//           builder: (context, snapshot) {
//             final episodeCount = snapshot.hasData ? snapshot.data!.length : 0;
//
//             return Card(
//               margin: EdgeInsets.only(bottom: 16),
//               elevation: 2,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: ListTile(
//                 contentPadding: EdgeInsets.all(12),
//                 leading: ClipRRect(
//                   borderRadius: BorderRadius.circular(8),
//                   child: CachedNetworkImage(
//                     imageUrl: serie.thumbnailUrl,
//                     width: 60,
//                     height: 60,
//                     fit: BoxFit.cover,
//                     placeholder: (context, url) => Container(
//                       color: Colors.grey[300],
//                       width: 60,
//                       height: 60,
//                       child: Icon(Icons.movie, color: Colors.grey),
//                     ),
//                     errorWidget: (context, url, error) => Container(
//                       color: Colors.grey[300],
//                       width: 60,
//                       height: 60,
//                       child: Icon(Icons.error, color: Colors.grey),
//                     ),
//                   ),
//                 ),
//                 title: Text(
//                   serie.title,
//                   style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
//                 ),
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SizedBox(height: 4),
//                     Text(
//                       '$episodeCount épisode(s)',
//                       style: TextStyle(color: Colors.grey[600]),
//                     ),
//                     SizedBox(height: 4),
//                     Text(
//                       serie.isFree ? 'Gratuit' : 'À partir de ${serie.price} FCFA',
//                       style: TextStyle(
//                         color: serie.isFree ? Colors.green : Colors.yellow[800],
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//                 trailing: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     IconButton(
//                       icon: Icon(Icons.add_circle, color: Colors.green,size: 15,),
//                       onPressed: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => ContentFormScreen(
//                               isEpisode: true,
//                               seriesId: serie.id,
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                     // Text(
//                     //   'Ajouter',
//                     //   style: TextStyle(fontSize: 10, color: Colors.green),
//                     // ),
//                   ],
//                 ),
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       // builder: (context) => SeriesEpisodesScreen(series: serie),
//                       builder: (context) => SeriesDetailScreen(series: serie),
//                     ),
//                   );
//                 },
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   Widget _buildStatsTab(UserData? user) {
//     return SingleChildScrollView(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Mes Statistiques',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//           ),
//           SizedBox(height: 16),
//           // Cartes de statistiques
//           GridView.count(
//             crossAxisCount: 2,
//             crossAxisSpacing: 16,
//             mainAxisSpacing: 16,
//             shrinkWrap: true,
//             physics: NeverScrollableScrollPhysics(),
//             children: [
//               // _buildStatCard('Vues totales', '${user?.userlikes ?? 0}', Icons.visibility, Colors.blue),
//               _buildStatCard('Likes totaux', '${user?.likes ?? 0}', Icons.thumb_up, Colors.pink),
//               _buildStatCard('Abonnés', '${user?.abonnes ?? 0}', Icons.people, Colors.purple),
//               // _buildStatCard('Commentaires', '${user?.comments ?? 0}', Icons.comment, Colors.orange),
//             ],
//           ),
//           SizedBox(height: 24),
//           Text(
//             'Mes Revenus',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//           ),
//           SizedBox(height: 16),
//           _buildRevenueCard('Solde Principal', '${user?.votre_solde_principal ?? 0} FCFA', Icons.account_balance_wallet, Colors.green),
//         //   SizedBox(height: 12),
//         //   _buildRevenueCard('Solde Contenu', '${user?.votre_solde_contenu ?? 0} FCFA', Icons.movie, Colors.yellow[700]!),
//         //   SizedBox(height: 12),
//         //   _buildRevenueCard('Solde Cadeau', '${user?.votre_solde_cadeau ?? 0} FCFA', Icons.card_giftcard, Colors.red),
//          ],
//       ),
//     );
//   }
//
//   Widget _buildStatCard(String title, String value, IconData icon, Color color) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, color: color, size: 30),
//             SizedBox(height: 8),
//             Text(
//               value,
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//             SizedBox(height: 4),
//             Text(
//               title,
//               style: TextStyle(
//                 color: Colors.grey[600],
//                 fontSize: 14,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildRevenueCard(String title, String value, IconData icon, Color color) {
//     return Card(
//       elevation: 3,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: ListTile(
//         leading: Icon(icon, color: color, size: 30),
//         title: Text(
//           title,
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: Colors.black87,
//           ),
//         ),
//         trailing: Text(
//           value,
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: Colors.green[800],
//             fontSize: 16,
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildVideoItem(ContentPaie video) {
//     return GestureDetector(
//       onTap: () {
//         Navigator.push(
//             context, MaterialPageRoute(builder: (_) => ContentDetailScreen(content: video)));
//       },
//       child: Card(
//         elevation: 4,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             // Image de la vidéo
//             ClipRRect(
//               borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
//               child: Container(
//                 height: 110,
//                 child: CachedNetworkImage(
//                   imageUrl: video.thumbnailUrl,
//                   fit: BoxFit.cover,
//                   placeholder: (context, url) => Container(
//                     color: Colors.grey[300],
//                     child: Center(child: CircularProgressIndicator(color: Colors.green)),
//                   ),
//                   errorWidget: (context, url, error) => Container(
//                     color: Colors.grey[300],
//                     child: Icon(Icons.error, color: Colors.grey),
//                   ),
//                 ),
//               ),
//             ),
//             // Contenu de la carte
//             Padding(
//               padding: EdgeInsets.all(12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     video.title,
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 12,
//                       color: Colors.black87,
//                     ),
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   SizedBox(height: 8),
//                   Row(
//                     children: [
//                       Icon(Icons.visibility, size: 10, color: Colors.grey),
//                       SizedBox(width: 4),
//                       Text('${video.views}', style: TextStyle(fontSize: 10, color: Colors.grey)),
//                       SizedBox(width: 12),
//                       Icon(Icons.thumb_up, size: 10, color: Colors.grey),
//                       SizedBox(width: 4),
//                       Text('${video.likes}', style: TextStyle(fontSize: 10, color: Colors.grey)),
//                     ],
//                   ),
//                   SizedBox(height: 8),
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: video.isFree ? Colors.green[50] : Colors.yellow[50],
//                       borderRadius: BorderRadius.circular(4),
//                       border: Border.all(
//                         color: video.isFree ? Colors.green : Colors.yellow[700]!,
//                         width: 1,
//                       ),
//                     ),
//                     child: Text(
//                       video.isFree
//                           ? 'GRATUIT'
//                           : '${video.price.toStringAsFixed(2)} FCFA',
//                       style: TextStyle(
//                         color: video.isFree ? Colors.green[800] : Colors.yellow[800],
//                         fontWeight: FontWeight.bold,
//                         fontSize: 9,
//                       ),
//                     ),
//
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }
// }