import 'package:afrotok/widgets/name_tag.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:flutter/material.dart';
import 'package:afrotok/services/api/canaux_api.dart';

import '../../models/model_data.dart';

import '../../theme/app_colors.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/tr.dart';

class ChannelFollowersPage extends StatefulWidget {
  /// Ancienne liste d'identifiants (n'est plus utilisée : les abonnés sont lus par page sur l'API à partir de [canalId]).
  final List<String> userIds;
  final String channelName;

  /// Identifiant du canal : nécessaire pour lire les abonnés sur l'API (administrateurs du canal et équipe seulement).
  final String? canalId;

  ChannelFollowersPage({
    this.userIds = const [],
    required this.channelName,
    this.canalId,
  });

  @override
  State<ChannelFollowersPage> createState() => _ChannelFollowersPageState();
}

class _ChannelFollowersPageState extends State<ChannelFollowersPage> {
  final ScrollController _scrollController = ScrollController();
  final List<UserData> _displayedUsers = [];
  String? _cursor; // page suivante (API)
  String? _error;
  final int _pageSize = 30;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoadComplete = false;

  late AppColors _colors;

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialUsers() async {
    if (widget.canalId == null) {
      if (mounted) setState(() { _initialLoadComplete = true; _hasMore = false; });
      return;
    }
    if (mounted) setState(() { _isLoading = true; _error = null; });
    await _loadNextPage();
    if (mounted) setState(() { _isLoading = false; _initialLoadComplete = true; });
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || widget.canalId == null) return;

    if (mounted) setState(() { _isLoading = true; });

    try {
      final page = await CanauxApi.members(widget.canalId!, cursor: _cursor, limit: _pageSize);
      final users = page.items.map((m) => UserData()
        ..id = '${m['user_id']}'
        ..pseudo = '${m['username'] ?? ''}'
        ..imageUrl = '${m['avatar_url'] ?? ''}').toList();
      if (mounted) {
        setState(() {
          _displayedUsers.addAll(users);
          _cursor = page.next;
          _hasMore = page.next != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      printVm('Erreur _loadNextPage: $e');
      if (mounted) setState(() { _isLoading = false; _error = CanauxApi.message(e); _hasMore = false; });
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange &&
        _hasMore &&
        !_isLoading) {
      _loadNextPage();
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _displayedUsers.clear();
        _cursor = null;
        _hasMore = true;
        _initialLoadComplete = false;
        _isLoading = true;
        _error = null;
      });
    }

    await _loadNextPage();

    if (mounted) setState(() { _isLoading = false; _initialLoadComplete = true; });
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        title: Text(
          '${l10n.canalFollowers} - ${widget.channelName}',
          style: TextStyle(fontWeight: FontWeight.bold, color: _colors.onPrimary, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: _colors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: _colors.onPrimary),
      ),
      body: _buildBody(width, height, l10n),
    );
  }

  Widget _buildBody(double width, double height, AppLocalizations l10n) {
    if (_isLoading && !_initialLoadComplete) {
      return _buildLoading(l10n);
    }

    if (_error != null && _displayedUsers.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: _colors.textSecondary)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _refreshData, child: Text(context.tr('Réessayer'))),
        ]),
      );
    }

    if (_displayedUsers.isEmpty && _initialLoadComplete) {
      return _buildEmptyState(l10n);
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      backgroundColor: _colors.primary,
      color: _colors.accent,
      child: ListView.builder(
        controller: _scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        itemCount: _displayedUsers.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _displayedUsers.length) {
            return _buildLoadingMore();
          }
          final user = _displayedUsers[index];
          return _buildUserItem(user, width, height, context, l10n);
        },
      ),
    );
  }

  Widget _buildUserItem(UserData user, double width, double height, BuildContext context, AppLocalizations l10n) {
    final followerCount = user.followersCount;
    final isVerified = user.isVerify ?? false;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showUserDetailsModalDialog(user, width, height, context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: user.imageUrl?.isNotEmpty == true
                            ? Image.network(
                          user.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(_colors.primary),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                        )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                    if (isVerified)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _colors.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2),
                            ],
                          ),
                          child: Icon(Icons.verified, color: _colors.accent, size: 16),
                        ),
                      ),
                  ],
                ),

                SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: NameTag(label: '@${user.pseudo ?? l10n.canalUser}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _colors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                          ),
                          SizedBox(width: 4),
                          if (user.isConnected ?? false)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            ),
                        ],
                      ),

                      SizedBox(height: 4),

                      Row(
                        children: [
                          Icon(Icons.people, size: 14, color: _colors.textSecondary),
                          SizedBox(width: 4),
                          Text(
                            _formatNumber(followerCount),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _colors.textSecondary),
                          ),
                          SizedBox(width: 2),
                          Text(
                            l10n.canalFollowers,
                            style: TextStyle(fontSize: 13, color: _colors.textSecondary),
                          ),
                        ],
                      ),

                      if ((user.followersCount) > 1000)
                        Container(
                          margin: EdgeInsets.only(top: 6),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _colors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            l10n.canalPopular,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _colors.primary),
                          ),
                        ),
                    ],
                  ),
                ),

                Icon(Icons.chevron_right, color: _colors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: _colors.primary.withOpacity(0.1),
      child: Center(
        child: Icon(Icons.person, color: _colors.primary.withOpacity(0.6), size: 28),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  Widget _buildLoading(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(_colors.primary),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(l10n.canalLoadingFollowers, style: TextStyle(color: _colors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildLoadingMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(_colors.primary),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: _colors.textSecondary),
            SizedBox(height: 16),
            Text(
              l10n.canalNoFollowers,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _colors.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              l10n.canalNoFollowersDesc,
              style: TextStyle(fontSize: 14, color: _colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _colors.primary,
                foregroundColor: _colors.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 0,
              ),
              child: Text(context.tr('Rafraîchir')),
            ),
          ],
        ),
      ),
    );
  }
}
