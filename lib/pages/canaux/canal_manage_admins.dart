import 'package:flutter/material.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';

import '../../providers/userProvider.dart';

import '../../models/model_data.dart';

import '../../theme/app_colors.dart';

import '../../l10n/app_localizations.dart';

class CanalManageAdminsPage extends StatefulWidget {
  final Canal canal;

  const CanalManageAdminsPage({Key? key, required this.canal}) : super(key: key);

  @override
  _CanalManageAdminsPageState createState() => _CanalManageAdminsPageState();
}

class _CanalManageAdminsPageState extends State<CanalManageAdminsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late UserAuthProvider _authProvider;
  late UserProvider _userProvider;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pseudoController = TextEditingController();
  List<UserData> _searchResults = [];
  bool _isSearching = false;
  bool _searchByEmail = true;

  late AppColors _colors;
  late AppLocalizations _l10n;

  bool _isOwner = false;
  List<UserData> _currentAdmins = [];
  bool _isLoadingAdmins = true;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);

    // Vérifier si l'utilisateur est le propriétaire
    _isOwner = _authProvider.loginUserData.id == widget.canal.userId;

    // Initialiser les listes si elles sont nulles
    widget.canal.adminIds ??= [];
    widget.canal.allowedPostersIds ??= [];
    widget.canal.allowAllMembersToPost ??= false;

    // Le créateur est automatiquement admin
    if (!widget.canal.adminIds!.contains(widget.canal.userId)) {
      widget.canal.adminIds!.add(widget.canal.userId!);
    }

    // Charger les administrateurs actuels
    _loadCurrentAdmins();
  }

  Future<void> _loadCurrentAdmins() async {
    setState(() {
      _isLoadingAdmins = true;
    });

    try {
      if (widget.canal.adminIds!.isNotEmpty) {
        _currentAdmins = await _fetchUsersByIds(widget.canal.adminIds!);
      }
    } catch (e) {
      printVm('Erreur chargement admins: $e');
    } finally {
      setState(() {
        _isLoadingAdmins = false;
      });
    }
  }

  Future<void> _searchUsers() async {
    final query = _searchByEmail
        ? _emailController.text.trim()
        : _pseudoController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      String searchField = _searchByEmail ? 'email' : 'pseudo';
      String searchQuery = query.toLowerCase();

      final querySnapshot = await _firestore
          .collection('Users')
          .where(searchField, isGreaterThanOrEqualTo: searchQuery)
          .where(searchField, isLessThanOrEqualTo: '$searchQuery\uf8ff')
          .limit(20)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserData.fromJson(doc.data()))
          .where((user) => user.id != widget.canal.userId) // Exclure le créateur
          .where((user) => !widget.canal.adminIds!.contains(user.id)) // Exclure les admins existants
          .where((user) => widget.canal.usersSuiviId?.contains(user.id) == true) // Seulement les membres du canal
          .toList();

      setState(() {
        _searchResults = users;
        _isSearching = false;
      });
    } catch (e) {
      printVm('Erreur recherche utilisateurs: $e');
      setState(() {
        _isSearching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de la recherche'),
          backgroundColor: _colors.danger,
        ),
      );
    }
  }

  Future<void> _addAdmin(UserData user) async {
    try {
      if (!widget.canal.adminIds!.contains(user.id)) {
        // Ajouter comme admin
        widget.canal.adminIds!.add(user.id!);

        // Ajouter aussi aux allowedPostersIds si pas déjà présent
        if (!widget.canal.allowedPostersIds!.contains(user.id)) {
          widget.canal.allowedPostersIds!.add(user.id!);
        }

        await _firestore.collection('Canaux').doc(widget.canal.id).update({
          'adminIds': widget.canal.adminIds,
          'allowedPostersIds': widget.canal.allowedPostersIds,
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        });

        // Mettre à jour la liste locale
        setState(() {
          _currentAdmins.add(user);
          _searchResults.removeWhere((u) => u.id == user.id);
        });

        // Créer une notification pour l'utilisateur
        await _createAdminNotification(user);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${user.pseudo} est maintenant administrateur'),
            backgroundColor: _colors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      printVm('Erreur ajout admin: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de l\'ajout'),
          backgroundColor: _colors.danger,
        ),
      );
    }
  }

  Future<void> _removeAdmin(UserData user) async {
    try {
      // Ne pas retirer le créateur
      if (user.id == widget.canal.userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Le propriétaire ne peut pas être retiré'),
            backgroundColor: _colors.danger,
          ),
        );
        return;
      }

      widget.canal.adminIds!.remove(user.id);

      // Ne pas retirer des allowedPostersIds ici
      // L'utilisateur peut toujours poster même s'il n'est plus admin

      await _firestore.collection('Canaux').doc(widget.canal.id).update({
        'adminIds': widget.canal.adminIds,
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      // Mettre à jour la liste locale
      setState(() {
        _currentAdmins.removeWhere((u) => u.id == user.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${user.pseudo} n\'est plus administrateur'),
          backgroundColor: _colors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      printVm('Erreur retrait admin: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors du retrait'),
          backgroundColor: _colors.danger,
        ),
      );
    }
  }

  Future<void> _togglePostingPermission(UserData user) async {
    try {
      if (widget.canal.allowedPostersIds!.contains(user.id)) {
        widget.canal.allowedPostersIds!.remove(user.id);
      } else {
        widget.canal.allowedPostersIds!.add(user.id!);
      }

      await _firestore.collection('Canaux').doc(widget.canal.id).update({
        'allowedPostersIds': widget.canal.allowedPostersIds,
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.canal.allowedPostersIds!.contains(user.id)
              ? '✅ ${user.pseudo} peut maintenant poster'
              : '✅ ${user.pseudo} ne peut plus poster'),
          backgroundColor: _colors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      printVm('Erreur mise à jour permission: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de la mise à jour'),
          backgroundColor: _colors.danger,
        ),
      );
    }
  }

  Future<void> _toggleAllowAllMembersToPost() async {
    try {
      widget.canal.allowAllMembersToPost = !widget.canal.allowAllMembersToPost!;

      await _firestore.collection('Canaux').doc(widget.canal.id).update({
        'allowAllMembersToPost': widget.canal.allowAllMembersToPost,
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.canal.allowAllMembersToPost!
              ? '✅ Tous les membres peuvent maintenant poster'
              : '✅ Seuls les utilisateurs autorisés peuvent poster'),
          backgroundColor: _colors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      printVm('Erreur mise à jour permissions générales: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de la mise à jour'),
          backgroundColor: _colors.danger,
        ),
      );
    }
  }

  Future<void> _createAdminNotification(UserData user) async {
    try {
      final notification = NotificationData(
        id: _firestore.collection('Notifications').doc().id,
        titre: "Gestion Canal 📺",
        media_url: widget.canal.urlImage,
        type: NotificationType.INVITATION.name,
        description: "Vous avez été nommé administrateur du canal #${widget.canal.titre}!",
        users_id_view: [],
        user_id: _authProvider.loginUserData.id!,
        receiver_id: user.id!,
        post_id: "",
        post_data_type: "",
        updatedAt: DateTime.now().microsecondsSinceEpoch,
        createdAt: DateTime.now().microsecondsSinceEpoch,
        status: PostStatus.VALIDE.name,
      );

      await _firestore.collection('Notifications').doc(notification.id).set(notification.toJson());

      // Envoyer notification push
      if (user.oneIgnalUserid != null) {
        _authProvider.sendNotification(
          userIds: [user.oneIgnalUserid!],
          smallImage: widget.canal.urlImage!,
          send_user_id: _authProvider.loginUserData.id!,
          recever_user_id: user.id!,
          message: "🎖️ Vous êtes maintenant administrateur du canal #${widget.canal.titre}!",
          type_notif: NotificationType.INVITATION.name,
          post_id: "",
          post_type: "",
          chat_id: "",
        );
      }
    } catch (e) {
      printVm('Erreur création notification: $e');
    }
  }

  Future<List<UserData>> _fetchUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final List<Future<UserData?>> futures = userIds.map((id) async {
        final doc = await _firestore.collection('Users').doc(id).get();
        if (doc.exists) {
          return UserData.fromJson(doc.data()!);
        }
        return null;
      }).toList();

      final results = await Future.wait(futures);
      return results.whereType<UserData>().toList();
    } catch (e) {
      printVm('Erreur récupération utilisateurs: $e');
      return [];
    }
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        title: Text(_l10n.canalManageAdmins, style: TextStyle(color: _colors.textPrimary)),
        backgroundColor: _colors.background,
        iconTheme: IconThemeData(color: _colors.textPrimary),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _colors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _colors.danger),
                ),
                child: Icon(Icons.lock, size: 80, color: _colors.danger),
              ),
              SizedBox(height: 30),
              Text(
                _l10n.canalAdminRestricted,
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                _l10n.canalAdminRestricted,
                textAlign: TextAlign.center,
                style: TextStyle(color: _colors.textSecondary, fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                _l10n.canalAdminContactOwner,
                textAlign: TextAlign.center,
                style: TextStyle(color: _colors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: _colors.primary),
              SizedBox(width: 8),
              Text(
                _l10n.canalSearchMember,
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Sélecteur type de recherche
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(_l10n.canalSearchByEmail),
                  selected: _searchByEmail,
                  onSelected: (selected) {
                    setState(() {
                      _searchByEmail = selected;
                      _searchResults = [];
                      _emailController.clear();
                      _pseudoController.clear();
                    });
                  },
                  selectedColor: _colors.primary,
                  backgroundColor: _colors.surfaceVariant,
                  labelStyle: TextStyle(
                    color: _searchByEmail ? _colors.onPrimary : _colors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text(_l10n.canalSearchByPseudo),
                  selected: !_searchByEmail,
                  onSelected: (selected) {
                    setState(() {
                      _searchByEmail = !selected;
                      _searchResults = [];
                      _emailController.clear();
                      _pseudoController.clear();
                    });
                  },
                  selectedColor: _colors.primary,
                  backgroundColor: _colors.surfaceVariant,
                  labelStyle: TextStyle(
                    color: !_searchByEmail ? _colors.onPrimary : _colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Champ de recherche
          TextField(
            controller: _searchByEmail ? _emailController : _pseudoController,
            style: TextStyle(color: _colors.textPrimary),
            decoration: InputDecoration(
              hintText: _searchByEmail
                  ? 'Entrez l\'email du membre...'
                  : 'Entrez le pseudo du membre...',
              hintStyle: TextStyle(color: _colors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _colors.primary),
              ),
              filled: true,
              fillColor: _colors.surfaceVariant,
              suffixIcon: _isSearching
                  ? Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _colors.primary,
                ),
              )
                  : IconButton(
                icon: Icon(Icons.search, color: _colors.primary),
                onPressed: _searchUsers,
              ),
            ),
            onChanged: (value) {
              if (value.length > 2) {
                _searchUsers();
              } else {
                setState(() {
                  _searchResults = [];
                });
              }
            },
            onSubmitted: (value) => _searchUsers(),
          ),

          SizedBox(height: 8),
          Text(
            _l10n.canalMembers,
            style: TextStyle(color: _colors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          '${_l10n.canalAdminResults} (${_searchResults.length})',
          style: TextStyle(
            color: _colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        ..._searchResults.map((user) => _buildUserCard(user, isSearchResult: true)).toList(),
      ],
    );
  }

  Widget _buildCurrentAdminsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          '${_l10n.canalAdminList} (${_currentAdmins.length})',
          style: TextStyle(
            color: _colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),

        if (_isLoadingAdmins)
          Center(
            child: CircularProgressIndicator(color: _colors.primary),
          )
        else if (_currentAdmins.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _l10n.canalAdminNone,
                style: TextStyle(color: _colors.textSecondary),
              ),
            ),
          )
        else
          ..._currentAdmins.map((admin) => _buildUserCard(admin, isSearchResult: false)).toList(),
      ],
    );
  }

  Widget _buildUserCard(UserData user, {required bool isSearchResult}) {
    final bool isAdmin = widget.canal.adminIds!.contains(user.id);
    final bool canPost = widget.canal.allowedPostersIds!.contains(user.id);
    final bool isCreator = user.id == widget.canal.userId;

    return Card(
      color: _colors.surface,
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: user.imageUrl != null
                  ? NetworkImage(user.imageUrl!)
                  : AssetImage('assets/default_profile.png') as ImageProvider,
            ),
            if (isCreator)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _colors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: _colors.surface, width: 2),
                  ),
                  child: Icon(Icons.star, size: 12, color: _colors.onAccent),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.pseudo ?? _l10n.canalUser,
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontWeight: isCreator ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCreator)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: _colors.warning,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _l10n.canalOwnerLabel,
                  style: TextStyle(
                    color: _colors.onAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email ?? 'Pas d\'email',
              style: TextStyle(color: _colors.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAdmin ? _colors.primary.withOpacity(0.2) : _colors.textSecondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isAdmin ? _colors.primary : _colors.textSecondary,
                    ),
                  ),
                  child: Text(
                    isAdmin ? _l10n.canalAdminLabel : _l10n.canalMemberLabel,
                    style: TextStyle(
                      color: isAdmin ? _colors.primary : _colors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: canPost ? _colors.primary.withOpacity(0.2) : _colors.textSecondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: canPost ? _colors.primary : _colors.textSecondary,
                    ),
                  ),
                  child: Text(
                    canPost ? _l10n.canalCanPost : _l10n.canalCannotPost,
                    style: TextStyle(
                      color: canPost ? _colors.primary : _colors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: isSearchResult
            ? IconButton(
          icon: Icon(Icons.add_circle, color: _colors.primary),
          onPressed: () => _addAdmin(user),
          tooltip: 'Ajouter comme administrateur',
        )
            : isCreator
            ? Tooltip(
          message: 'Le propriétaire ne peut pas être modifié',
          child: Icon(Icons.lock, color: _colors.textSecondary),
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                canPost ? Icons.create : Icons.create_outlined,
                color: canPost ? _colors.primary : _colors.textSecondary,
                size: 20,
              ),
              onPressed: () => _togglePostingPermission(user),
              tooltip: canPost
                  ? 'Retirer permission de poster'
                  : 'Autoriser à poster',
            ),
            IconButton(
              icon: Icon(
                Icons.remove_circle,
                color: _colors.danger,
                size: 20,
              ),
              onPressed: () => _removeAdmin(user),
              tooltip: 'Retirer comme administrateur',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSettings() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: _colors.primary),
              SizedBox(width: 8),
              Text(
                _l10n.canalPublishSettings,
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Option pour autoriser tous les membres
          SwitchListTile(
            title: Text(
              _l10n.canalAllowAllToPost,
              style: TextStyle(color: _colors.textPrimary),
            ),
            subtitle: Text(
              widget.canal.allowAllMembersToPost!
                  ? _l10n.canalAllowAllToPost
                  : _l10n.canalMembersOnlyCanAdd,
              style: TextStyle(color: _colors.textSecondary, fontSize: 12),
            ),
            value: widget.canal.allowAllMembersToPost!,
            onChanged: (value) => _toggleAllowAllMembersToPost(),
            activeColor: _colors.primary,
            inactiveTrackColor: _colors.border,
          ),

          SizedBox(height: 8),
          Divider(color: _colors.border),
          SizedBox(height: 8),

          // Statistiques
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    widget.canal.adminIds!.length.toString(),
                    style: TextStyle(
                      color: _colors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _l10n.canalAdminLabel,
                    style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    widget.canal.allowedPostersIds!.length.toString(),
                    style: TextStyle(
                      color: _colors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _l10n.canalCanPost,
                    style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    widget.canal.usersSuiviId?.length.toString() ?? '0',
                    style: TextStyle(
                      color: _colors.info,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _l10n.canalMembers,
                    style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    _l10n = AppLocalizations.of(context);

    // Vérifier l'accès
    if (!_isOwner) {
      return _buildAccessDenied();
    }

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        title: Text(
          _l10n.canalManageAdmins,
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _colors.background,
        iconTheme: IconThemeData(color: _colors.textPrimary),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du canal
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _colors.primary),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: widget.canal.urlImage != null
                        ? NetworkImage(widget.canal.urlImage!)
                        : AssetImage('assets/default_profile.png') as ImageProvider,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.canal.titre!,
                          style: TextStyle(
                            color: _colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _l10n.canalOwner,
                          style: TextStyle(
                            color: _colors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Paramètres de publication
            _buildPermissionSettings(),

            // Section recherche
            _buildSearchSection(),

            // Résultats de recherche
            _buildSearchResults(),

            // Administrateurs actuels
            _buildCurrentAdminsSection(),

            SizedBox(height: 40),

            // Informations importantes
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _colors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _colors.warning),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: _colors.warning, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les administrateurs peuvent gérer les membres mais seul le propriétaire peut modifier le canal ou ajouter/retirer des administrateurs.',
                      style: TextStyle(color: _colors.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}