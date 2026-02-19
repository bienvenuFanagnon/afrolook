// pages/lives/live_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../pub/native_ad_widget.dart';
import 'create_live_page.dart';
import 'livePage.dart';
import 'livesAgora.dart';
import 'mesLives.dart';

// pages/lives/live_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'create_live_page.dart';
import 'livesAgora.dart';
import 'mesLives.dart';

// pages/lives/live_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'create_live_page.dart';
import 'livesAgora.dart';
import 'mesLives.dart';

// pages/lives/live_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'create_live_page.dart';
import 'livePage.dart';
import 'livesAgora.dart';
import 'mesLives.dart';

class LiveListPage extends StatefulWidget {
  @override
  _LiveListPageState createState() => _LiveListPageState();
}

class _LiveListPageState extends State<LiveListPage> with SingleTickerProviderStateMixin {
  final RefreshController _allLivesController = RefreshController(initialRefresh: false);
  final RefreshController _activeLivesController = RefreshController(initialRefresh: false);

  late TabController _tabController;
  int _selectedTab = 0; // 0 = tous, 1 = actifs
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadLives(reset: true);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTab = _tabController.index;
        _isLoading = true;
      });
      _loadLives(reset: true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLives({bool reset = false}) async {
    final liveProvider = context.read<LiveProvider>();
    setState(() => _isLoading = true);

    try {
      if (_selectedTab == 0) {
        // await liveProvider.fetchEndedLivesBatch(reset: reset);
        await liveProvider.fetchAllLivesBatch(reset: reset);
      } else {
        await liveProvider.fetchActiveLivesBatch(reset: reset);
      }
    } catch (e) {
      print("Erreur lors du chargement des lives: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreLives() async {
    final liveProvider = context.read<LiveProvider>();
    try {
      if (_selectedTab == 0) {
        await liveProvider.fetchAllLivesBatch();
        _allLivesController.loadComplete();
      } else {
        await liveProvider.fetchActiveLivesBatch();
        _activeLivesController.loadComplete();
      }
    } catch (e) {
      print("Erreur lors du chargement supplémentaire: $e");
      if (_selectedTab == 0) {
        _allLivesController.loadFailed();
      } else {
        _activeLivesController.loadFailed();
      }
    }
  }

  void _onRefresh() async {
    await _loadLives(reset: true);
    if (_selectedTab == 0) {
      _allLivesController.refreshCompleted();
    } else {
      _activeLivesController.refreshCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final liveProvider = context.watch<LiveProvider>();

    // Récupérer les listes appropriées selon l'onglet
    final displayedLives = _selectedTab == 0
        ? _getAllLivesWithActiveFirst(liveProvider)
        : liveProvider.activeLives;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Lives Afrolook', style: TextStyle(fontSize: 20, color: Color(0xFFF9A825))),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Tous les lives'),
            Tab(text: 'En cours'),
          ],
          indicatorColor: Color(0xFFF9A825),
          labelColor: Color(0xFFF9A825),
          unselectedLabelColor: Colors.grey,
        ),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: authProvider.loginUserData.imageUrl != null &&
                  authProvider.loginUserData.imageUrl!.isNotEmpty
                  ? NetworkImage(authProvider.loginUserData.imageUrl!)
                  : AssetImage('assets/default_avatar.png') as ImageProvider,
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => UserLivesPage()));
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFFF9A825)),
            onPressed: () => _loadLives(reset: true),
          ),
          IconButton(
            icon: Icon(Icons.add, color: Color(0xFFF9A825)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateLivePage()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Message accrocheur
          Container(
            width: double.infinity,
            color: Colors.yellow[800],
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text(
              "🎥 Créez votre live pour présenter vos produits, formations ou sujets ! "
                  "Gagnez jusqu'à 50 000 FCFA par cadeaux et 70% des montants récoltés grâce aux cadeaux. "
                  "Le secret ? Créez votre live et partagez le lien sur vos réseaux pour attirer le maximum de monde ! "
                  "Pas besoin d'abonnés pour commencer.",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFFF9A825)))
                : TabBarView(
              controller: _tabController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                // Tab 1: Tous les lives (actifs en premier)
                _buildLivesTab(displayedLives, authProvider, _allLivesController),
                // Tab 2: Seulement les lives actifs
                _buildLivesTab(displayedLives, authProvider, _activeLivesController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fonction pour organiser tous les lives avec les actifs en premier
  List<PostLive> _getAllLivesWithActiveFirst(LiveProvider liveProvider) {
    // Vérifier d'abord si les données sont disponibles
    if (liveProvider.allLives.isEmpty && liveProvider.activeLives.isEmpty) {
      print("⚠️ Aucun live disponible dans le provider");
      return [];
    }

    // Si on a des lives actifs spécifiques, on les utilise
    final activeLives = liveProvider.activeLives.isNotEmpty
        ? List<PostLive>.from(liveProvider.activeLives)
        : liveProvider.allLives.where((live) => live.isLive).toList();

    // Pour les lives terminés, utiliser la liste dédiée ou filtrer
// Pour les lives terminés, utiliser la liste dédiée ou filtrer
    final endedLives = liveProvider.endedLives.isNotEmpty
        ? List<PostLive>.from(liveProvider.endedLives)
        : liveProvider.allLives.where((live) => !live.isLive).toList();

    print("📊 Organisation des lives:");
    print("   - Lives actifs: ${activeLives.length}");
    print("   - Lives terminés: ${endedLives.length}");

    // Trier les lives actifs par giftTotal (décroissant)
    if (activeLives.isNotEmpty) {
      activeLives.sort((a, b) => b.giftTotal.compareTo(a.giftTotal));
      print("   ✅ Lives actifs triés par giftTotal");
    }

    // Trier les lives terminés par date de création (décroissant)
    if (endedLives.isNotEmpty) {
      endedLives.sort((a, b) => b.startTime.compareTo(a.startTime));
      print("   ✅ Lives terminés triés par date");
    }

    // Combiner: actifs d'abord, puis terminés
    final result = [...activeLives, ...endedLives];
    print("   🎯 Total lives organisés: ${result.length}");

    return result;
  }
// Ajoutez cette fonction dans votre classe _LiveListPageState
  Widget _buildAdBanner({required String key}) {
    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: NativeAdWidget(
        templateType: TemplateType.small, // Utilisez small pour les lives
        onAdLoaded: () {
          print('✅ Native Ad chargée dans LivePage: $key');
        },
      ),
    );
  }
  Widget _buildLivesTab(List<PostLive> lives, UserAuthProvider authProvider, RefreshController controller) {
    if (lives.isEmpty) return _buildEmptyState();

    // Séparer les lives actifs et terminés pour le tab "Tous les lives"
    final List<PostLive> activeLives = _selectedTab == 0 ? lives.where((live) => live.isLive).toList() : [];
    final List<PostLive> endedLives = _selectedTab == 0 ? lives.where((live) => !live.isLive).toList() : [];

    // Pour le tab "En cours", utiliser directement la liste
    final List<PostLive> displayLives = _selectedTab == 1 ? lives : [];

    return SmartRefresher(
      controller: controller,
      enablePullDown: true,
      enablePullUp: lives.length < 30,
      onRefresh: _onRefresh,
      onLoading: _loadMoreLives,
      header: WaterDropHeader(
        waterDropColor: Color(0xFFF9A825),
        complete: Icon(Icons.check, color: Color(0xFFF9A825)),
      ),
      footer: CustomFooter(
        builder: (context, mode) {
          if (mode == LoadStatus.loading) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFF9A825))),
            );
          } else {
            return SizedBox.shrink();
          }
        },
      ),
      child: CustomScrollView(
        slivers: _buildSliverListWithAds( // ✅ Utilisez cette nouvelle fonction
          activeLives,
          endedLives,
          displayLives,
          authProvider,
          selectedTab: _selectedTab, // Passez l'onglet sélectionné
        ),
      ),
    );
  }

// ✅ Nouvelle fonction avec intégration des pubs
  List<Widget> _buildSliverListWithAds(
      List<PostLive> activeLives,
      List<PostLive> endedLives,
      List<PostLive> displayLives,
      UserAuthProvider authProvider, {
        required int selectedTab,
      }) {
    final slivers = <Widget>[];

    // Pour le tab "En cours" - afficher avec pub en première position
    if (selectedTab == 1) {
      // ✅ Ajouter la pub en première position
      slivers.add(
        SliverToBoxAdapter(
          child: _buildAdBanner(key: 'live_tab_active_first'),
        ),
      );

      // Ajouter un espacement
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(height: 8),
        ),
      );

      // Ensuite la grille des lives
      if (displayLives.isNotEmpty) {
        slivers.add(
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildLiveGridItem(displayLives[index], authProvider),
                childCount: displayLives.length,
              ),
            ),
          ),
        );
      } else {
        slivers.add(
          SliverFillRemaining(
            child: _buildEmptyState(),
          ),
        );
      }

      return slivers;
    }

    // Pour le tab "Tous les lives" avec sections séparées

    // ✅ Ajouter la pub en première position
    slivers.add(
      SliverToBoxAdapter(
        child: _buildAdBanner(key: 'live_tab_all_first'),
      ),
    );

    // Ajouter un espacement
    slivers.add(
      SliverToBoxAdapter(
        child: SizedBox(height: 8),
      ),
    );

    // Section Lives Actifs
    if (activeLives.isNotEmpty) {
      slivers.addAll([
        SliverPadding(
          padding: EdgeInsets.only(top: 16, left: 16, right: 16),
          sliver: SliverToBoxAdapter(
            child: Text(
              '🔴 Lives en cours (${activeLives.length})',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildLiveGridItem(activeLives[index], authProvider),
              childCount: activeLives.length,
            ),
          ),
        ),
      ]);
    }

    // Section Lives Terminés
    if (endedLives.isNotEmpty) {
      slivers.addAll([
        SliverPadding(
          padding: EdgeInsets.only(top: activeLives.isNotEmpty ? 32 : 16, left: 16, right: 16),
          sliver: SliverToBoxAdapter(
            child: Text(
              '📁 Lives terminés (${endedLives.length})',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildLiveGridItem(endedLives[index], authProvider),
              childCount: endedLives.length,
            ),
          ),
        ),
      ]);
    }

    // Si aucune vie
    if (activeLives.isEmpty && endedLives.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          child: _buildEmptyState(),
        ),
      );
    }

    return slivers;
  }
  List<Widget> _buildSliverList(
      List<PostLive> activeLives,
      List<PostLive> endedLives,
      List<PostLive> displayLives,
      UserAuthProvider authProvider
      ) {
    // Pour le tab "En cours" - afficher simplement la grille
    if (_selectedTab == 1) {
      return [
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildLiveGridItem(displayLives[index], authProvider),
              childCount: displayLives.length,
            ),
          ),
        ),
      ];
    }

    // Pour le tab "Tous les lives" avec sections séparées
    final slivers = <Widget>[];

    // Section Lives Actifs
    if (activeLives.isNotEmpty) {
      slivers.addAll([
        SliverPadding(
          padding: EdgeInsets.only(top: 16, left: 16, right: 16),
          sliver: SliverToBoxAdapter(
            child: Text(
              '🔴 Lives en cours (${activeLives.length})',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildLiveGridItem(activeLives[index], authProvider),
              childCount: activeLives.length,
            ),
          ),
        ),
      ]);
    }

    // Section Lives Terminés
    if (endedLives.isNotEmpty) {
      slivers.addAll([
        SliverPadding(
          padding: EdgeInsets.only(top: activeLives.isNotEmpty ? 32 : 16, left: 16, right: 16),
          sliver: SliverToBoxAdapter(
            child: Text(
              '📁 Lives terminés (${endedLives.length})',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildLiveGridItem(endedLives[index], authProvider),
              childCount: endedLives.length,
            ),
          ),
        ),
      ]);
    }

    // Si aucune vie
    if (activeLives.isEmpty && endedLives.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          child: _buildEmptyState(),
        ),
      );
    }

    return slivers;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAdBanner(key: 'live_tab_active_first'),
          Icon(Icons.videocam_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            _selectedTab == 0 ? 'Aucun live' : 'Aucun live en cours',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            _selectedTab == 0
                ? 'Soyez le premier à créer un live!'
                : 'Aucun live ne diffuse en ce moment',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateLivePage()));
            },
            child: Text('Créer un live', style: TextStyle(color: Colors.black)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF9A825),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveGridItem(PostLive live, UserAuthProvider authProvider) {
    final isInvited = live.invitedUsers.contains(authProvider.userId);
    final isHost = live.hostId == authProvider.userId;
    final isLive = live.isLive;
    final isPaidLive = live.isPaidLive;
    final hasPinnedText = live.pinnedText != null && live.pinnedText!.isNotEmpty;

    // Calcul du total des spectateurs (spectateurs + participants)
    final totalSpectateurs = live.totalspectateurs.length;
    final currentViewers = live.viewerCount; // Spectateurs actuels pour les lives en cours

    return GestureDetector(
      onTap: () {
        if (isLive) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LivePage(
                liveId: live.liveId!,
                isHost: isHost,
                hostName: live.hostName!,
                hostImage: live.hostImage!,
                isInvited: isInvited,
                postLive: live,
              ),
            ),
          );
        } else {
          _showLiveDetailsDialog(live);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: isLive
              ? Border.all(color: Colors.red, width: 2)
              : Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section image avec badges
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      image: DecorationImage(
                        image: NetworkImage(live.hostImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // Badge LIVE/TERMINÉ
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: isLive ? Colors.red : Colors.grey[700],
                          borderRadius: BorderRadius.circular(12)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLive ? Icons.circle : Icons.check_circle,
                            color: Colors.white,
                            size: 8,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isLive ? 'LIVE' : 'TERMINÉ',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Badge Live Privé
                  if (isPaidLive)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              'PRIVÉ',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Badge Invitation
                  if (isInvited && !isPaidLive)
                    Positioned(
                      top: 40,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Color(0xFFF9A825),
                            shape: BoxShape.circle
                        ),
                        child: Icon(Icons.mail, color: Colors.black, size: 12),
                      ),
                    ),

                  // Overlay pour lives terminés
                  if (!isLive)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),

            // Section informations
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre avec badge texte épinglé
                  Row(
                    children: [
                      if (hasPinnedText)
                        Icon(Icons.push_pin, color: Color(0xFFF9A825), size: 10),
                      SizedBox(width: hasPinnedText ? 4 : 0),
                      Expanded(
                        child: Text(
                          live.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 6),

                  // Informations hôte
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: NetworkImage(live.hostImage!),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          live.hostName!,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 6),

                  // Statistiques
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Spectateurs (différent selon live actif ou terminé)
                      Row(
                        children: [
                          Icon(Icons.people, size: 12, color: Colors.grey),
                          SizedBox(width: 2),
                          Text(
                            isLive ? '$currentViewers' : '$totalSpectateurs',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),

                      // Likes
                      Row(
                        children: [
                          Icon(Icons.favorite, size: 12, color: Colors.pink),
                          SizedBox(width: 2),
                          Text(
                            '${live.likeCount ?? 0}',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),

                      // Cadeaux
                      Row(
                        children: [
                          Icon(Icons.card_giftcard, size: 12, color: Color(0xFFF9A825)),
                          SizedBox(width: 2),
                          Text(
                            '${live.gifts.length}',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: 4),

                  // Montant et durée
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isLive ? 'En cours' : _formatDuration(live.startTime, live.endTime),
                        style: TextStyle(
                          color: isLive ? Colors.green : Colors.grey,
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        '${live.giftTotal.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          color: Color(0xFFF9A825),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return 'En cours';

    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  void _showLiveDetailsDialog(PostLive live) {
    final duration = _formatDuration(live.startTime, live.endTime);
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');

    // Calcul des totaux
    final totalSpectateurs = live.totalspectateurs.length;
    final totalParticipants = live.participants.length;
    final totalSpectateursSeuls = live.spectators.length;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey[700]!, width: 1)
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Center(
                child: Text(
                  '📊 Détails du Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Titre
              Text(
                live.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 15),

              // Informations hôte
              _buildDetailRow('👤 Hôte:', live.hostName!),
              _buildDetailRow('📅 Début:', dateFormat.format(live.startTime)),
              if (live.endTime != null)
                _buildDetailRow('⏱️ Durée:', duration),

              SizedBox(height: 15),

              // Statistiques d'audience
              Text(
                '👥 Audience',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildStatCard('👥 Total spectateurs', '$totalSpectateurs', Icons.people, Colors.blue),
                  // _buildStatCard('🎤 Participants', '$totalParticipants', Icons.mic, Colors.green),
                  _buildStatCard('👀 Spectateurs', '$totalSpectateursSeuls', Icons.visibility, Colors.orange),
                  _buildStatCard('❤️ Likes', '${live.likeCount ?? 0}', Icons.favorite, Colors.pink),
                ],
              ),

              SizedBox(height: 15),

              // Autres statistiques
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildStatCard('🎁 Cadeaux', '${live.gifts.length}', Icons.card_giftcard, Color(0xFFF9A825)),
                  _buildStatCard('📤 Partages', '${live.shareCount}', Icons.share, Colors.green),
                  if (live.isPaidLive)
                    _buildStatCard('💰 Participations', '${live.paidParticipationTotal.toStringAsFixed(0)} FCFA', Icons.payment, Colors.purple),
                  // _buildStatCard('👥 Invités', '${live.invitedUsers.length}', Icons.mail, Colors.cyan),
                ],
              ),

              SizedBox(height: 15),

              // Revenus
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[900]!.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    Text(
                      '💰 Revenus générés',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '${live.giftTotal.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (live.paidParticipationTotal > 0)
                      Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Text(
                          '+ ${live.paidParticipationTotal.toStringAsFixed(0)} FCFA (participations)',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 15),

              // Type de live
              if (live.isPaidLive)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple[900]!.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: Colors.purpleAccent, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Live Privé - Accès payant',
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 20),

              // Bouton fermer
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text(
                    'Fermer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
    children: [
    Text(
    label,
    style: TextStyle(
    color: Colors.grey,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    ),
    ),
    SizedBox(width: 8),
    Expanded(
    child: Text(
    value,
    style: TextStyle(
    color: Colors.white,
    fontSize: 14,
    ),
    ),
    ),
    ],)
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

