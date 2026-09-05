import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/canaux/detailsCanal.dart';
import 'package:afrotok/pages/user/otherUser/otherUser.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserFollowingPage extends StatefulWidget {
  final String userId;
  final String? displayName;
  final int initialTab;

  const UserFollowingPage({
    required this.userId,
    this.displayName,
    this.initialTab = 0,
    super.key,
  });

  @override
  State<UserFollowingPage> createState() => _UserFollowingPageState();
}

class _UserFollowingPageState extends State<UserFollowingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Créateurs
  List<UserData> _creators = [];
  List<String> _followingIds = [];
  bool _loadingCreators = true;
  bool _loadingMoreCreators = false;
  int _creatorPage = 0;
  static const int _pageSize = 20;

  // Canaux
  List<Canal> _canaux = [];
  bool _loadingCanaux = true;
  bool _loadingMoreCanaux = false;
  DocumentSnapshot? _lastCanalDoc;
  bool _hasMoreCanaux = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadFollowingIds();
    _loadCanaux();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowingIds() async {
    try {
      final doc =
          await _firestore.collection('Users').doc(widget.userId).get();
      final data = doc.data();
      if (data != null && data['followingIds'] is List) {
        _followingIds = List<String>.from(data['followingIds']);
      }
    } catch (_) {
      _followingIds = [];
    }
    await _loadCreatorsPage();
  }

  Future<void> _loadCreatorsPage() async {
    if (_followingIds.isEmpty) {
      if (mounted) setState(() => _loadingCreators = false);
      return;
    }

    final start = _creatorPage * _pageSize;
    if (start >= _followingIds.length) {
      if (mounted) setState(() => _loadingCreators = false);
      return;
    }

    final end = (start + _pageSize).clamp(0, _followingIds.length);
    final chunk = _followingIds.sublist(start, end);

    final newUsers = <UserData>[];
    for (var i = 0; i < chunk.length; i += 10) {
      final sub = chunk.sublist(i, (i + 10).clamp(0, chunk.length));
      try {
        final snap = await _firestore
            .collection('Users')
            .where(FieldPath.documentId, whereIn: sub)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          newUsers.add(UserData.fromJson(data));
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _creators.addAll(newUsers);
        _loadingCreators = false;
        _loadingMoreCreators = false;
      });
    }
  }

  Future<void> _loadMoreCreators() async {
    if (_loadingMoreCreators) return;
    final nextStart = (_creatorPage + 1) * _pageSize;
    if (nextStart >= _followingIds.length) return;
    setState(() => _loadingMoreCreators = true);
    _creatorPage++;
    await _loadCreatorsPage();
  }

  Future<void> _loadCanaux() async {
    try {
      Query query = _firestore
          .collection('Canaux')
          .where('usersSuiviId', arrayContains: widget.userId)
          .limit(20);

      final snap = await query.get();
      final list = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Canal.fromJson(data);
      }).toList();

      if (mounted) {
        setState(() {
          _canaux = list;
          _lastCanalDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
          _hasMoreCanaux = snap.docs.length == 20;
          _loadingCanaux = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCanaux = false);
    }
  }

  Future<void> _loadMoreCanaux() async {
    if (_loadingMoreCanaux || !_hasMoreCanaux || _lastCanalDoc == null) return;
    setState(() => _loadingMoreCanaux = true);
    try {
      final snap = await _firestore
          .collection('Canaux')
          .where('usersSuiviId', arrayContains: widget.userId)
          .startAfterDocument(_lastCanalDoc!)
          .limit(20)
          .get();

      final list = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Canal.fromJson(data);
      }).toList();

      if (mounted) {
        setState(() {
          _canaux.addAll(list);
          _lastCanalDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastCanalDoc;
          _hasMoreCanaux = snap.docs.length == 20;
          _loadingMoreCanaux = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMoreCanaux = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final title = widget.displayName != null
        ? 'Abonnements de ${widget.displayName}'
        : 'Abonnements';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: colors.primary,
          tabs: const [
            Tab(text: '👤 Créateurs'),
            Tab(text: '📢 Canaux'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreatorsTab(colors),
          _buildCanauxTab(colors),
        ],
      ),
    );
  }

  Widget _buildCreatorsTab(AppColors colors) {
    if (_loadingCreators) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    if (_creators.isEmpty) {
      return Center(
        child: Text(
          'Aucun créateur suivi',
          style: TextStyle(color: colors.textSecondary, fontSize: 15),
        ),
      );
    }

    final hasMore = (_creatorPage + 1) * _pageSize < _followingIds.length;

    return ListView.builder(
      itemCount: _creators.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _creators.length) {
          return _buildLoadMoreButton(
            loading: _loadingMoreCreators,
            onTap: _loadMoreCreators,
            colors: colors,
          );
        }
        return _buildCreatorItem(_creators[index], colors);
      },
    );
  }

  Widget _buildCreatorItem(UserData user, AppColors colors) {
    final avatar = user.imageUrl ?? '';
    final pseudo = user.pseudo ?? user.nom ?? 'Utilisateur';
    final flag = user.countryData?['flag'];

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colors.surfaceVariant,
        backgroundImage:
            avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
        child: avatar.isEmpty
            ? Icon(Icons.person, color: colors.textSecondary)
            : null,
      ),
      title: Row(
        children: [
          Text(
            pseudo,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (flag != null && flag.toString().isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(flag.toString(), style: const TextStyle(fontSize: 16)),
          ],
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherUserPage(otherUser: user),
          ),
        );
      },
    );
  }

  Widget _buildCanauxTab(AppColors colors) {
    if (_loadingCanaux) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    if (_canaux.isEmpty) {
      return Center(
        child: Text(
          'Aucun canal suivi',
          style: TextStyle(color: colors.textSecondary, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      itemCount: _canaux.length + (_hasMoreCanaux ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _canaux.length) {
          return _buildLoadMoreButton(
            loading: _loadingMoreCanaux,
            onTap: _loadMoreCanaux,
            colors: colors,
          );
        }
        return _buildCanalItem(_canaux[index], colors);
      },
    );
  }

  Widget _buildCanalItem(Canal canal, AppColors colors) {
    final imageUrl = canal.urlImage ?? '';
    final nom = canal.titre ?? 'Canal';
    final description = canal.description ?? '';

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: colors.surfaceVariant,
                  child: Icon(Icons.campaign, color: colors.textSecondary),
                ),
              )
            : Container(
                width: 48,
                height: 48,
                color: colors.surfaceVariant,
                child: Icon(Icons.campaign, color: colors.textSecondary),
              ),
      ),
      title: Text(
        nom,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: description.isNotEmpty
          ? Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CanalDetails(canal: canal),
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreButton({
    required bool loading,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? CircularProgressIndicator(color: colors.primary)
            : TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: const Text('Charger plus'),
              ),
      ),
    );
  }
}
