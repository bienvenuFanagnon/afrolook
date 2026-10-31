import 'package:afrotok/services/read_meter.dart';
import 'package:afrotok/widgets/name_tag.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/canaux/detailsCanal.dart';
import 'package:afrotok/pages/user/otherUser/otherUser.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canal_mapper.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
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
  String? _creatorsCursor;
  bool _hasMoreCreators = true;
  String? _canalCursor;

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
    await _loadCreatorsPage();
  }

  Future<void> _loadCreatorsPage() async {
    // Comptes suivis (API : GET /v1/users/{id}/following, curseur)
    try {
      final page = await UsersApi.following(widget.userId, cursor: _creatorsCursor, limit: _pageSize);
      _creatorsCursor = page.next;
      _hasMoreCreators = page.next != null;
      final newUsers = page.items.map(userSummaryFromApi).toList();
      _followingIds.addAll(newUsers.map((u) => u.id!));
      if (mounted) {
        setState(() {
          _creators.addAll(newUsers);
          _loadingCreators = false;
          _loadingMoreCreators = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loadingCreators = false; _loadingMoreCreators = false; });
    }
  }

  Future<void> _loadMoreCreators() async {
    if (_loadingMoreCreators || !_hasMoreCreators) return;
    setState(() => _loadingMoreCreators = true);
    await _loadCreatorsPage();
  }

  Future<void> _loadCanaux() async {
    // Canaux suivis par la personne connectée (API : GET /v1/channels?mine=1). Ceux d'une autre personne ne sont pas exposés.
    try {
      final r = await ApiGateway.instance.client.get('/channels', query: {'mine': 1, 'limit': 20, if (_canalCursor != null) 'cursor': _canalCursor}) as Map;
      final list = ((r['data'] as List?) ?? const []).map((e) => canalFromApi(Map<String, dynamic>.from(e as Map))).toList();
      _canalCursor = r['next_cursor'] as String?;
      if (mounted) {
        setState(() {
          _canaux = list;
          _hasMoreCanaux = _canalCursor != null;
          _loadingCanaux = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCanaux = false);
    }
  }

  Future<void> _loadMoreCanaux() async {
    if (_loadingMoreCanaux || !_hasMoreCanaux || _canalCursor == null) return;
    setState(() => _loadingMoreCanaux = true);
    try {
      final r = await ApiGateway.instance.client.get('/channels', query: {'mine': 1, 'limit': 20, 'cursor': _canalCursor}) as Map;
      final list = ((r['data'] as List?) ?? const []).map((e) => canalFromApi(Map<String, dynamic>.from(e as Map))).toList();
      _canalCursor = r['next_cursor'] as String?;
      if (mounted) {
        setState(() {
          _canaux.addAll(list);
          _hasMoreCanaux = _canalCursor != null;
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

    final hasMore = _hasMoreCreators;

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
      leading: CircleAvatar(onBackgroundImageError: (avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null) != null ? (Object _, StackTrace? __) {} : null, 
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
      title: NameTag(
        label: '#$nom',
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
