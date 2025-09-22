// models/live_models.dart
import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';

import '../../models/model_data.dart';
import '../paiement/newDepot.dart';
import 'create_live_page.dart';
import 'livesAgora.dart';
import 'mesLives.dart';

class LiveListPage extends StatefulWidget {
  @override
  _LiveListPageState createState() => _LiveListPageState();
}

class _LiveListPageState extends State<LiveListPage> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  final RefreshController _allLivesController = RefreshController(initialRefresh: false);
  final RefreshController _activeLivesController = RefreshController(initialRefresh: false);

  int _selectedTab = 0; // 0 pour tous les lives, 1 pour les lives actifs
  bool _isLoading = true;
  List<PostLive> _allLives = [];
  List<PostLive> _activeLives = [];

  @override
  void initState() {
    super.initState();
    printVm('Page liste lives');
    _loadLives();
  }

  Future<void> _loadLives() async {
    final liveProvider = context.read<LiveProvider>();

    if (_selectedTab == 0) {
      await liveProvider.fetchAllLives();
      setState(() {
        _allLives = liveProvider.allLives;
        // Trier: lives en cours d'abord
        _allLives.sort((a, b) {
          if (a.isLive && !b.isLive) return -1;
          if (!a.isLive && b.isLive) return 1;
          return b.startTime.compareTo(a.startTime);
        });
      });
    } else {
      await liveProvider.fetchActiveLives();
      setState(() {
        _activeLives = liveProvider.activeLives;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _onRefreshAll() async {
    await _loadLives();
    _allLivesController.refreshCompleted();
  }

  void _onRefreshActive() async {
    await _loadLives();
    _activeLivesController.refreshCompleted();
  }

  void _onRefresh() async {
    await _loadLives();
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final displayedLives = _selectedTab == 0 ? _allLives : _activeLives;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lives Afrolook', style: TextStyle(fontSize: 20,color: Color(0xFFF9A825))),
          backgroundColor: Colors.black,
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                _selectedTab = index;
                _isLoading = true;
              });
              _loadLives();
            },
            tabs: [
              Tab(text: 'Tous les lives'),
              Tab(text: 'En cours'),
            ],
            indicatorColor: Color(0xFFF9A825),
            labelColor: Color(0xFFF9A825),
            unselectedLabelColor: Colors.grey,
          ),
          actions: [
            // Icon de profil pour accéder aux lives de l'utilisateur
            IconButton(
              icon: CircleAvatar(
                radius: 16,
                backgroundImage: authProvider.loginUserData.imageUrl != null &&
                    authProvider.loginUserData.imageUrl!.isNotEmpty
                    ? NetworkImage(authProvider.loginUserData.imageUrl!)
                    : AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserLivesPage()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: Color(0xFFF9A825)),
              onPressed: _loadLives,
            ),
            IconButton(
              icon: Icon(Icons.add, color: Color(0xFFF9A825)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateLivePage()),
                );
              },
            ),
          ],
        ),
        backgroundColor: Colors.black,
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: Color(0xFFF9A825)))
            : TabBarView(
          children: [
            // Onglet "Tous les lives"
            SmartRefresher(
              controller: _allLivesController,
              onRefresh: _onRefreshAll,
              enablePullDown: true,
              header: WaterDropHeader(
                waterDropColor: Color(0xFFF9A825),
                complete: Icon(Icons.check, color: Color(0xFFF9A825)),
              ),
              child: displayedLives.isEmpty
                  ? _buildEmptyState()
                  : _buildLiveGrid(displayedLives, authProvider, showAll: true),
            ),

            // Onglet "Lives en cours"
            SmartRefresher(
              controller: _activeLivesController,
              onRefresh: _onRefreshActive,
              enablePullDown: true,
              header: WaterDropHeader(
                waterDropColor: Color(0xFFF9A825),
                complete: Icon(Icons.check, color: Color(0xFFF9A825)),
              ),
              child: displayedLives.isEmpty
                  ? _buildEmptyState()
                  : _buildLiveGrid(displayedLives, authProvider, showAll: false),
            ),
          ],
        ),
      ),
    );
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreateLivePage()),
              );
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

  Widget _buildLiveGrid(List<PostLive> lives, UserAuthProvider authProvider, {bool showAll = true}) {
    // Séparer les lives en cours et terminés pour l'onglet "Tous les lives"
    final activeLives = showAll ? lives.where((live) => live.isLive).toList() : lives;
    final endedLives = showAll ? lives.where((live) => !live.isLive).toList() : [];

    return CustomScrollView(
      slivers: [
        // Section des lives en cours
        if (activeLives.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.only(top: 16, left: 16, right: 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Lives en cours',
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
                    (context, index) {
                  final live = activeLives[index];
                  return _buildLiveGridItem(live, authProvider);
                },
                childCount: activeLives.length,
              ),
            ),
          ),
        ],

        // Section des lives terminés (seulement pour l'onglet "Tous les lives")
        if (showAll && endedLives.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.only(top: 24, left: 16, right: 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Lives terminés',
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
                    (context, index) {
                  final live = endedLives[index];
                  return _buildLiveGridItem(live, authProvider);
                },
                childCount: endedLives.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

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
              builder: (context) => LivePage(
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
          border: isLive
              ? Border.all(color: Colors.red, width: 2)
              : Border.all(color: Colors.grey[700]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: isLive ? Colors.red.withOpacity(0.3) : Colors.transparent,
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image de preview avec badge live
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
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isInvited)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Color(0xFFF9A825),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.mail, color: Colors.black, size: 12),
                      ),
                    ),
                  // Overlay sombre pour les lives terminés
                  if (!isLive)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        color: Colors.black54,
                      ),
                      child: Center(
                        child: Icon(Icons.play_circle_filled, color: Colors.white, size: 40),
                      ),
                    ),
                ],
              ),
            ),

            // Informations du live
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    live.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
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
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                          Text(
                            '${live.viewerCount}',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                      Text(
                        isLive ? 'Maintenant' : dateFormat.format(live.startTime),
                        style: TextStyle(color: Colors.grey, fontSize: 10),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showLiveEndedDialog(PostLive live) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Live terminé', style: TextStyle(color: Colors.white)),
        content: Text(
          'Ce live s\'est terminé le ${_formatDate(live.startTime)}.\n\n'
              '${live.viewerCount} personnes y ont assisté.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: Color(0xFFF9A825))),
          ),
        ],
      ),
    );
  }
}