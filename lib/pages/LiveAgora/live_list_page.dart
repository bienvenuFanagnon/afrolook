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
  Widget _buildLivesTab(List<PostLive> lives, UserAuthProvider authProvider, RefreshController controller) {
    if (lives.isEmpty) return _buildEmptyState();

    // Séparer les lives actifs et terminés pour le tab "Tous les lives"
    final List<PostLive> activeLives = _selectedTab == 0 ? lives.where((live) => live.isLive).toList() : [];
    print("activeLives! ${activeLives.length}");
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
        slivers: _buildSliverList(activeLives, endedLives, displayLives, authProvider),
      ),
    );
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
              childAspectRatio: 0.8,
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
              childAspectRatio: 0.8,
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
              childAspectRatio: 0.8,
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

  // Le reste du code (_buildLiveGridItem, _showLiveEndedDialog, etc.) reste identique
  Widget _buildLiveGridItem(PostLive live, UserAuthProvider authProvider) {
    final isInvited = live.invitedUsers.contains(authProvider.userId);
    final isHost = live.hostId == authProvider.userId;
    final isLive = live.isLive;
    final dateFormat = DateFormat('dd/MM/yy HH:mm');

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
          _showLiveEndedDialog(live);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: isLive ? Border.all(color: Colors.red, width: 2) : Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  if (isLive)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text('LIVE',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  if (!isLive)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(12)),
                        child: Text('TERMINÉ',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (isInvited)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Color(0xFFF9A825), shape: BoxShape.circle),
                        child: Icon(Icons.mail, color: Colors.black, size: 12),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(live.title,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(radius: 10, backgroundImage: NetworkImage(live.hostImage!)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(live.hostName!,
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('${live.viewerCount}', style: TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                      Text(
                        isLive ? 'Maintenant' : '${live.giftTotal.toStringAsFixed(0)} FCFA',
                        style: TextStyle(color: Colors.yellowAccent, fontSize: 10, fontWeight: FontWeight.bold),
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

  void _showLiveEndedDialog(PostLive live) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text('🎉 Live terminé !', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(live.title, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            SizedBox(height: 15),
            Text('📅 Terminé le: ${_formatDate(live.startTime)}', style: TextStyle(color: Colors.yellowAccent)),
            SizedBox(height: 10),
            Text('👥 Spectateurs: ${live.viewerCount}', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 5),
            Text('💝 Cadeaux reçus: ${live.gifts.length}', style: TextStyle(color: Colors.pinkAccent)),
            SizedBox(height: 5),
            Text('❤️ Likes: ${live.likeCount ?? 0}', style: TextStyle(color: Colors.redAccent)),
            SizedBox(height: 10),
            Text('💰 Montant gagné: ${live.giftTotal.toStringAsFixed(0)} FCFA',
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10)),
              child: Text('Fermer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          SizedBox(height: 5),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

// class LiveListPage extends StatefulWidget {
//   @override
//   _LiveListPageState createState() => _LiveListPageState();
// }
//
// class _LiveListPageState extends State<LiveListPage> {
//   final RefreshController _allLivesController = RefreshController(initialRefresh: false);
//   final RefreshController _activeLivesController = RefreshController(initialRefresh: false);
//
//   int _selectedTab = 0; // 0 = tous, 1 = actifs
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadLives(reset: true);
//   }
//
//   Future<void> _loadLives({bool reset = false}) async {
//     final liveProvider = context.read<LiveProvider>();
//     setState(() => _isLoading = true);
//
//     if (_selectedTab == 0) {
//       await liveProvider.fetchAllLivesBatch(reset: reset);
//     } else {
//       await liveProvider.fetchActiveLivesBatch(reset: reset);
//     }
//
//     setState(() => _isLoading = false);
//   }
//
//   Future<void> _loadMoreLives() async {
//     final liveProvider = context.read<LiveProvider>();
//     if (_selectedTab == 0) {
//       await liveProvider.fetchAllLivesBatch();
//       _allLivesController.loadComplete();
//     } else {
//       await liveProvider.fetchActiveLivesBatch();
//       _activeLivesController.loadComplete();
//     }
//   }
//
//   void _onRefresh() async {
//     await _loadLives(reset: true);
//     if (_selectedTab == 0) {
//       _allLivesController.refreshCompleted();
//     } else {
//       _activeLivesController.refreshCompleted();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = context.watch<UserAuthProvider>();
//     final liveProvider = context.watch<LiveProvider>();
//     final displayedLives = _selectedTab == 0 ? liveProvider.allLives : liveProvider.activeLives;
//
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         backgroundColor: Colors.black,
//         appBar: AppBar(
//           title: Text('Lives Afrolook', style: TextStyle(fontSize: 20, color: Color(0xFFF9A825))),
//           backgroundColor: Colors.black,
//           bottom: TabBar(
//             onTap: (index) {
//               setState(() {
//                 _selectedTab = index;
//                 _isLoading = true;
//               });
//               _loadLives(reset: true);
//             },
//             tabs: [
//               Tab(text: 'Tous les lives'),
//               Tab(text: 'En cours'),
//             ],
//             indicatorColor: Color(0xFFF9A825),
//             labelColor: Color(0xFFF9A825),
//             unselectedLabelColor: Colors.grey,
//           ),
//           actions: [
//             IconButton(
//               icon: CircleAvatar(
//                 radius: 16,
//                 backgroundImage: authProvider.loginUserData.imageUrl != null &&
//                     authProvider.loginUserData.imageUrl!.isNotEmpty
//                     ? NetworkImage(authProvider.loginUserData.imageUrl!)
//                     : AssetImage('assets/default_avatar.png') as ImageProvider,
//               ),
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(builder: (_) => UserLivesPage()));
//               },
//             ),
//             IconButton(
//               icon: Icon(Icons.refresh, color: Color(0xFFF9A825)),
//               onPressed: () => _loadLives(reset: true),
//             ),
//             IconButton(
//               icon: Icon(Icons.add, color: Color(0xFFF9A825)),
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(builder: (_) => CreateLivePage()));
//               },
//             ),
//           ],
//         ),
//         body: _isLoading
//             ? Center(child: CircularProgressIndicator(color: Color(0xFFF9A825)))
//             : Column(
//           children: [
//             // Message accrocheur
// // Message accrocheur
//             Container(
//               width: double.infinity,
//               color: Colors.yellow[800],
//               padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//               child: Text(
//                 "🎥 Créez votre live pour présenter vos produits, formations ou sujets ! "
//                     "Gagnez jusqu’à 50 000 FCFA par cadeaux et 70% des montants récoltés grâce aux cadeaux. "
//                     "Le secret ? Créez votre live et partagez le lien sur vos réseaux pour attirer le maximum de monde ! "
//                     "Pas besoin d’abonnés pour commencer.",
//                 style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//             Expanded(
//               child: TabBarView(
//                 physics: NeverScrollableScrollPhysics(),
//                 children: [
//                   _buildLivesTab(displayedLives, authProvider, _allLivesController),
//                   _buildLivesTab(displayedLives, authProvider, _activeLivesController),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLivesTab(List<PostLive> lives, UserAuthProvider authProvider, RefreshController controller) {
//     if (lives.isEmpty) return _buildEmptyState();
//
//     return SmartRefresher(
//       controller: controller,
//       enablePullDown: true,
//       enablePullUp: lives.length < 30,
//       onRefresh: _onRefresh,
//       onLoading: _loadMoreLives,
//       header: WaterDropHeader(
//         waterDropColor: Color(0xFFF9A825),
//         complete: Icon(Icons.check, color: Color(0xFFF9A825)),
//       ),
//       footer: CustomFooter(
//         builder: (context, mode) {
//           if (mode == LoadStatus.loading) {
//             return Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Center(child: CircularProgressIndicator(color: Color(0xFFF9A825))),
//             );
//           } else {
//             return SizedBox.shrink();
//           }
//         },
//       ),
//       child: CustomScrollView(
//         slivers: [
//           SliverPadding(
//             padding: EdgeInsets.all(16),
//             sliver: SliverGrid(
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.8),
//               delegate: SliverChildBuilderDelegate(
//                     (context, index) => _buildLiveGridItem(lives[index], authProvider),
//                 childCount: lives.length,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.videocam_off, size: 64, color: Colors.grey),
//           SizedBox(height: 16),
//           Text(
//             _selectedTab == 0 ? 'Aucun live' : 'Aucun live en cours',
//             style: TextStyle(color: Colors.white, fontSize: 18),
//           ),
//           SizedBox(height: 8),
//           Text(
//             _selectedTab == 0
//                 ? 'Soyez le premier à créer un live!'
//                 : 'Aucun live ne diffuse en ce moment',
//             style: TextStyle(color: Colors.grey, fontSize: 14),
//           ),
//           SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.push(context, MaterialPageRoute(builder: (_) => CreateLivePage()));
//             },
//             child: Text('Créer un live', style: TextStyle(color: Colors.black)),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Color(0xFFF9A825),
//               padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLiveGridItem(PostLive live, UserAuthProvider authProvider) {
//     final isInvited = live.invitedUsers.contains(authProvider.userId);
//     final isHost = live.hostId == authProvider.userId;
//     final isLive = live.isLive;
//     final dateFormat = DateFormat('dd/MM/yy HH:mm');
//
//     return GestureDetector(
//       onTap: () {
//         if (isLive) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => LivePage(
//                 liveId: live.liveId!,
//                 isHost: isHost,
//                 hostName: live.hostName!,
//                 hostImage: live.hostImage!,
//                 isInvited: isInvited,
//                 postLive: live,
//               ),
//             ),
//           );
//         } else {
//           _showLiveEndedDialog(live);
//         }
//       },
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.grey[900],
//           borderRadius: BorderRadius.circular(12),
//           border: isLive ? Border.all(color: Colors.red, width: 2) : Border.all(color: Colors.grey[700]!, width: 1),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Expanded(
//               child: Stack(
//                 children: [
//                   Container(
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
//                       image: DecorationImage(
//                         image: NetworkImage(live.hostImage!),
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                   ),
//                   if (isLive)
//                     Positioned(
//                       top: 8,
//                       left: 8,
//                       child: Container(
//                         padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                         decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Icon(Icons.circle, color: Colors.white, size: 8),
//                             SizedBox(width: 4),
//                             Text('LIVE',
//                                 style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
//                           ],
//                         ),
//                       ),
//                     ),
//                   if (!isLive)
//                     Positioned(
//                       top: 8,
//                       left: 8,
//                       child: Container(
//                         padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
//                         decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(12)),
//                         child: Text('TERMINÉ',
//                             style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
//                       ),
//                     ),
//                   if (isInvited)
//                     Positioned(
//                       top: 8,
//                       right: 8,
//                       child: Container(
//                         padding: EdgeInsets.all(4),
//                         decoration: BoxDecoration(color: Color(0xFFF9A825), shape: BoxShape.circle),
//                         child: Icon(Icons.mail, color: Colors.black, size: 12),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//             Padding(
//               padding: EdgeInsets.all(8),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(live.title,
//                       style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis),
//                   SizedBox(height: 4),
//                   Row(
//                     children: [
//                       CircleAvatar(radius: 10, backgroundImage: NetworkImage(live.hostImage!)),
//                       SizedBox(width: 6),
//                       Expanded(
//                         child: Text(live.hostName!,
//                             style: TextStyle(color: Colors.grey, fontSize: 10),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 4),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Row(
//                         children: [
//                           Icon(Icons.people, size: 12, color: Colors.grey),
//                           SizedBox(width: 4),
//                           Text('${live.viewerCount}', style: TextStyle(color: Colors.grey, fontSize: 10)),
//                         ],
//                       ),
//                       Text(
//                         isLive ? 'Maintenant' : '${live.giftTotal.toStringAsFixed(0)} FCFA',
//                         style: TextStyle(color: Colors.yellowAccent, fontSize: 10, fontWeight: FontWeight.bold),
//                       ),
//                     ],
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
//   void _showLiveEndedDialog(PostLive live) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         backgroundColor: Colors.black,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: Center(
//           child: Text('🎉 Live terminé !', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(live.title, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
//             SizedBox(height: 15),
//             Text('📅 Terminé le: ${_formatDate(live.startTime)}', style: TextStyle(color: Colors.yellowAccent)),
//             SizedBox(height: 10),
//             Text('👥 Spectateurs: ${live.viewerCount}', style: TextStyle(color: Colors.white70)),
//             SizedBox(height: 5),
//             Text('💝 Cadeaux reçus: ${live.gifts.length}', style: TextStyle(color: Colors.pinkAccent)),
//             SizedBox(height: 5),
//             Text('❤️ Likes: ${live.likeCount ?? 0}', style: TextStyle(color: Colors.redAccent)),
//             SizedBox(height: 10),
//             Text('💰 Montant gagné: ${live.giftTotal.toStringAsFixed(0)} FCFA',
//                 style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
//           ],
//         ),
//         actions: [
//           Center(
//             child: ElevatedButton(
//               onPressed: () => Navigator.pop(context),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10)),
//               child: Text('Fermer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
//             ),
//           ),
//           SizedBox(height: 5),
//         ],
//       ),
//     );
//   }
//
//   String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
// }
