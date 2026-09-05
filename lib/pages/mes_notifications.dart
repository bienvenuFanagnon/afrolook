import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/home_afroshop.dart';
import 'package:afrotok/pages/auth/authTest/constants.dart';
import 'package:afrotok/pages/canaux/detailsCanal.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';
import 'package:afrotok/pages/socialVideos/video_details.dart';
import 'package:afrotok/pages/user/amis/mesAmis.dart';
import 'package:afrotok/pages/user/amis/pageMesInvitations.dart';
import 'package:afrotok/pages/user/monetisation.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/authProvider.dart';
import '../providers/postProvider.dart';
import 'UserServices/detailsUserService.dart';
import 'afroshop/marketPlace/acceuil/produit_details.dart';
import 'chronique/chroniquedetails.dart';
import 'LiveAgora/livePage.dart';
import 'LiveAgora/live_list_page.dart';
import 'LiveAgora/livesAgora.dart';
import 'component/showUserDetails.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';

class MesNotification extends StatefulWidget {
  const MesNotification({super.key});

  @override
  State<MesNotification> createState() => _MesNotificationState();
}

class _MesNotificationState extends State<MesNotification> {
  late AppColors _colors;
  late AppLocalizations _l10n;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, UserData> _userCache = {};
  final Map<String, Canal> _canalCache = {};
  bool _isHandlingNotification = false;
  bool _showFilterMenu = false;
  String? _selectedTypeFilter;
  List<String> _availableTypes = [];

  static const int _pageSize = 60;

  // Liste plate de toutes les notifications chargées
  List<NotificationData> _notifications = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  int get _totalUnreadCount => _notifications.where((n) => !(n.is_open ?? true)).length;

  Future<void> _loadInitialNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final userId = _authProvider.loginUserData.id!;
    try {
      final snap = await _firestore
          .collection('Notifications')
          .where('receiver_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(_pageSize)
          .get();

      final items = snap.docs
          .map((d) => NotificationData.fromJson(d.data() as Map<String, dynamic>))
          .toList();

      for (final n in items) {
        if (n.canal_id != null && n.canal_id!.isNotEmpty) {
          _loadCanalData(n.canal_id!);
        } else if (n.user_id != null && n.user_id!.isNotEmpty) {
          _loadUserData(n.user_id!);
        }
      }

      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isLoading = false;
        _hasMore = snap.docs.length >= _pageSize;
        if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
        // Auto-ouvrir le groupe avec la notification la plus récente (même tri que l'UI)
        String? mostRecentGroup;
        int mostRecentTs = 0;
        for (final n in items) {
          final g = _groupForType(n.type);
          if ((n.createdAt ?? 0) > mostRecentTs) {
            mostRecentTs = n.createdAt ?? 0;
            mostRecentGroup = g;
          }
        }
        for (final g in _groupTypes.keys) {
          _groupExpanded[g] = g == mostRecentGroup;
        }
      });
    } catch (e) {
      printVm("Erreur chargement notifications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _isLoadingMore = true);
    final userId = _authProvider.loginUserData.id!;
    try {
      final snap = await _firestore
          .collection('Notifications')
          .where('receiver_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      final items = snap.docs
          .map((d) => NotificationData.fromJson(d.data() as Map<String, dynamic>))
          .toList();

      for (final n in items) {
        if (n.canal_id != null && n.canal_id!.isNotEmpty) {
          _loadCanalData(n.canal_id!);
        } else if (n.user_id != null && n.user_id!.isNotEmpty) {
          _loadUserData(n.user_id!);
        }
      }

      if (!mounted) return;
      setState(() {
        _notifications = [..._notifications, ...items];
        _isLoadingMore = false;
        _hasMore = snap.docs.length >= _pageSize;
        if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
      });
    } catch (e) {
      printVm("Erreur chargement plus de notifications: $e");
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  final Map<String, int> _groupUnreadCounts = {};
  // 2 notifications préchargées par groupe pour garantir l'affichage même si
  // le groupe n'a pas de notification dans le batch global des 60 dernières.
  final Map<String, List<NotificationData>> _groupSamples = {};

  Future<void> _loadGroupCounts() async {
    final userId = _authProvider.loginUserData.id!;
    await Future.wait(_groupTypes.entries.map((entry) async {
      try {
        final snap = await _firestore
            .collection('Notifications')
            .where('receiver_id', isEqualTo: userId)
            .where('is_open', isEqualTo: false)
            .where('type', whereIn: entry.value)
            .count()
            .get();
        if (mounted) setState(() => _groupUnreadCounts[entry.key] = snap.count ?? 0);
      } catch (_) {}
    }));
  }

  /// Charge 2 notifications par groupe en parallèle.
  /// Utilisé pour afficher quelque chose même quand le groupe n'est pas
  /// présent dans les 60 notifications du batch global.
  Future<void> _loadGroupSamples() async {
    final userId = _authProvider.loginUserData.id!;
    await Future.wait(_groupTypes.entries.map((entry) async {
      try {
        final snap = await _firestore
            .collection('Notifications')
            .where('receiver_id', isEqualTo: userId)
            .where('type', whereIn: entry.value)
            .orderBy('created_at', descending: true)
            .limit(2)
            .get();
        final items = snap.docs
            .map((d) => NotificationData.fromJson(d.data() as Map<String, dynamic>))
            .toList();
        for (final n in items) {
          if (n.canal_id != null && n.canal_id!.isNotEmpty) {
            _loadCanalData(n.canal_id!);
          } else if (n.user_id != null && n.user_id!.isNotEmpty) {
            _loadUserData(n.user_id!);
          }
        }
        if (mounted) setState(() => _groupSamples[entry.key] = items);
      } catch (_) {}
    }));
  }

  late UserAuthProvider _authProvider;
  late PostProvider _postProvider;

  // Types par défaut à afficher
  final List<String> _defaultTypes = [
    'NEWPOST',
    'INVITATION',
    'PARRAINAGE',
    'COMMENT',
    'COMMENTAIRE',
    'FAVORITE'
  ];

  // ── Groupes accordion ──
  static const Map<String, List<String>> _groupTypes = {
    'J\'aime':                    ['FAVORITE'],
    'Commentaires':               ['COMMENT', 'COMMENTAIRE'],
    'Abonnés':                    ['ABONNER', 'INVITATION', 'ACCEPTINVITATION'],
    'Messages':                   ['MESSAGE'],
    'Publications & Lives':       ['NEWPOST', 'POST', 'LIVE', 'CHALLENGE'],
    'Articles & Contenus':        ['ARTICLE', 'CHRONIQUE', 'SERVICE'],
    'Récompenses':                ['WEEKLY_REWARD'],
    'Gains & Parrainages':        ['GAIN', 'PARRAINAGE'],
    'Afrolook':                   ['SUPPORT', 'MARKETING', 'COMPTE_OFFICIEL', 'USER'],
  };

  static const Map<String, IconData> _groupIcons = {
    'J\'aime':                    Icons.favorite_border,
    'Commentaires':               Icons.chat_bubble_outline,
    'Abonnés':                    Icons.person_add_alt_1_outlined,
    'Messages':                   Icons.mark_chat_unread_outlined,
    'Publications & Lives':       Icons.play_circle_outline,
    'Articles & Contenus':        Icons.article_outlined,
    'Récompenses':                Icons.emoji_events_outlined,
    'Gains & Parrainages':        Icons.monetization_on_outlined,
    'Afrolook':                   Icons.verified_outlined,
  };

  final Map<String, bool> _groupExpanded = {
    'J\'aime':                    false,
    'Commentaires':               false,
    'Abonnés':                    false,
    'Messages':                   false,
    'Publications & Lives':       false,
    'Articles & Contenus':        false,
    'Récompenses':                false,
    'Gains & Parrainages':        false,
    'Afrolook':                   false,
  };

  // Nombre de notifications visibles par groupe (2 au départ, +5 à chaque "Voir plus")
  final Map<String, int> _groupVisibleCount = {};

  String _groupForType(String? type) {
    if (type == null) return 'Afrolook';
    for (final entry in _groupTypes.entries) {
      if (entry.value.contains(type.toUpperCase())) return entry.key;
    }
    return 'Afrolook';
  }

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _postProvider = Provider.of<PostProvider>(context, listen: false);
    _loadAvailableTypes();
    _loadInitialNotifications();
    _loadGroupCounts();
    _loadGroupSamples();
  }

  Future<void> _loadAvailableTypes() async {
    try {
      // Récupérer uniquement les types distincts de l'enum
      setState(() {
        _availableTypes = NotificationType.values
            .map((e) => e.toString().split('.').last)
            .toList();
      });
    } catch (e) {
      printVm("Erreur chargement types: $e");
    }
  }


  Future<void> _loadUserData(String userId) async {
    if (_userCache.containsKey(userId)) return;

    try {
      final userSnapshot = await _firestore
          .collection('Users')
          .where("id", isEqualTo: userId)
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final userData = UserData.fromJson(userSnapshot.docs.first.data() as Map<String, dynamic>);
        _userCache[userId] = userData;

        // Mettre à jour les notifications avec les données utilisateur
        for (var notif in _notifications) {
          if (notif.user_id == userId && notif.canal_id == null) {
            notif.userData = userData;
          }
        }
        setState(() {});
      }
    } catch (e) {
      printVm("Erreur chargement user $userId: $e");
    }
  }

  Future<void> _loadCanalData(String canalId) async {
    if (_canalCache.containsKey(canalId)) return;

    try {
      final canalSnapshot = await _firestore
          .collection('Canaux')
          .where("id", isEqualTo: canalId)
          .limit(1)
          .get();

      if (canalSnapshot.docs.isNotEmpty) {
        final canalData = Canal.fromJson(canalSnapshot.docs.first.data() as Map<String, dynamic>);
        _canalCache[canalId] = canalData;
        setState(() {});
      }
    } catch (e) {
      printVm("Erreur chargement canal $canalId: $e");
    }
  }

  Widget _getNotificationIcon(NotificationData notification) {
    const double iconSize = 20.0;

    switch (notification.type) {
      case 'MESSAGE':
        return _buildIconContainer(Icons.message, _colors.danger, iconSize);
      case 'POST':
      case 'NEWPOST':
        return _buildIconContainer(Icons.post_add, _colors.danger, iconSize);
      case 'INVITATION':
        return _buildIconContainer(Icons.person_add, _colors.warning, iconSize);
      case 'ARTICLE':
        return _buildIconContainer(Icons.shopping_bag, _colors.info, iconSize);
      case 'SERVICE':
        return _buildIconContainer(Icons.handyman, _colors.success, iconSize);
      case 'CHALLENGE':
        return _buildIconContainer(Icons.emoji_events, _colors.warning, iconSize);
      case 'ACCEPTINVITATION':
        return _buildIconContainer(Icons.people, _colors.accent, iconSize);
      case 'PARRAINAGE':
        return _buildIconContainer(Icons.attach_money, _colors.success, iconSize);
      case 'FAVORITE':
        return _buildIconContainer(Icons.favorite, _colors.danger, iconSize);
      case 'COMMENT':
      case 'COMMENTAIRE':
        return _buildIconContainer(Icons.comment, _colors.info, iconSize);
      default:
        return _buildIconContainer(Icons.notifications, _colors.textSecondary, iconSize);
    }
  }

  Widget _buildIconContainer(IconData icon, Color color, double size) {
    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) {
          return _l10n.notifJustNow;
        } else {
          return _l10n.notifMinutesAgo(difference.inMinutes);
        }
      } else {
        return _l10n.notifHoursAgo(difference.inHours);
      }
    } else if (difference.inDays < 7) {
      return _l10n.notifDaysAgo(difference.inDays);
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }

  void _showUserProfile(String userId) {
    final user = _userCache[userId];
    if (user != null) {
      double w = MediaQuery.of(context).size.width;
      double h = MediaQuery.of(context).size.height;
      showUserDetailsModalDialog(user, w, h, context);
    }
  }

  void _navigateToCanal(String canalId) {
    final canal = _canalCache[canalId];
    if (canal != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CanalDetails(canal: canal),
        ),
      );
    } else {
      _showErrorSnackBar(_l10n.notifChannelNotFound);
    }
  }

  Future<void> _handleNotificationTap(NotificationData notification) async {
    if (_isHandlingNotification) return;

    setState(() {
      _isHandlingNotification = true;
    });

    // Afficher l'indicateur de chargement
    _showLoadingOverlay();

    try {
      // Marquer comme lu dans Firestore
      if (!notification.is_open!) {
        await _firestore.collection('Notifications').doc(notification.id).update({
          'is_open': true,
          'users_id_view': FieldValue.arrayUnion([_authProvider.loginUserData.id!])
        });

        // Mettre à jour localement
        setState(() {
          notification.is_open = true;
        });
      }

      // Naviguer vers la cible
      await _navigateToNotificationTarget(notification);

    } catch (e) {
      printVm("Erreur traitement notification: $e");
      _showErrorSnackBar(_l10n.notifErrorOpening);
      _hideLoadingOverlay();
      setState(() {
        _isHandlingNotification = false;
      });
    }
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _colors.background.withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_colors.primary),
                  ),
                  SizedBox(height: 16),
                  Text(
                    _l10n.notifLoadingEllipsis,
                    style: TextStyle(
                      color: _colors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideLoadingOverlay() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _navigateToNotificationTarget(NotificationData notification) async {
    try {
      switch (notification.type) {
        case 'MESSAGE':
          await _handlePostNotification(notification);
          break;
        case 'POST':
          await _handlePostNotification(notification);
          break;
        case 'NEWPOST':
          await _handlePostNotification(notification);
          break;
        case 'INVITATION':
          _hideLoadingOverlay();
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => MesInvitationsPage(context: context),
          )).then((_) {
            setState(() {
              _isHandlingNotification = false;
            });
          });
          break;
      // 🔥 NOUVEAU CAS POUR CHRONIQUES
        case 'CHRONIQUE':
          _hideLoadingOverlay();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChroniqueDetailPage(
                initialChroniqueId: notification.post_id!,
              ),
            ),
          ).then((_) {
            setState(() {
              _isHandlingNotification = false;
            });
          });
          break;
        case 'ARTICLE':
          _hideLoadingOverlay();
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => ProduitDetail(productId: notification.post_id!),
          )).then((_) {
            setState(() {
              _isHandlingNotification = false;
            });
          });
          break;
        case 'LIVE':
          await _handleLiveNotification(notification);
          break;
        case 'SERVICE':
          await _handleServiceNotification(notification);
          break;
        case 'ACCEPTINVITATION':
          _hideLoadingOverlay();
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => MesAmis(context: context),
          )).then((_) {
            setState(() {
              _isHandlingNotification = false;
            });
          });
          break;
        case 'PARRAINAGE':
          _hideLoadingOverlay();
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => MonetisationPage(),
          )).then((_) {
            setState(() {
              _isHandlingNotification = false;
            });
          });
          break;
        case 'FAVORITE':
        // Pour les favoris, on va sur le post
          await _handlePostNotification(notification);
          break;
        case 'COMMENT':
        case 'COMMENTAIRE':
          await _handlePostNotification(notification);
          break;
        default:
          _hideLoadingOverlay();
          setState(() {
            _isHandlingNotification = false;
          });
          break;
      }
    } catch (e) {
      _hideLoadingOverlay();
      printVm("Erreur navigation: $e");
      _showErrorSnackBar(_l10n.notifErrorOpening);
      setState(() {
        _isHandlingNotification = false;
      });
    }
  }

  Future<void> _handleLiveNotification(NotificationData notification) async {
    final liveId = notification.post_id;
    try {
      if (liveId == null || liveId.isEmpty) {
        _hideLoadingOverlay();
        Navigator.push(context, MaterialPageRoute(builder: (_) => LiveListPage()));
        setState(() => _isHandlingNotification = false);
        return;
      }
      final doc = await _firestore.collection('lives').doc(liveId).get();
      _hideLoadingOverlay();
      if (!mounted) return;
      if (doc.exists) {
        final live = PostLive.fromMap(doc.data()!);
        if (live.isLive) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => LivePage(
              liveId: live.liveId!,
              isHost: false,
              hostName: live.hostName ?? '',
              hostImage: live.hostImage ?? '',
              isInvited: false,
              postLive: live,
            ),
          )).then((_) => setState(() => _isHandlingNotification = false));
          return;
        }
      }
      // Live terminé ou introuvable → liste des lives
      Navigator.push(context, MaterialPageRoute(builder: (_) => LiveListPage()))
          .then((_) => setState(() => _isHandlingNotification = false));
    } catch (_) {
      _hideLoadingOverlay();
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LiveListPage()))
            .then((_) => setState(() => _isHandlingNotification = false));
      }
    }
  }

  Future<void> _handlePostNotification(NotificationData notification) async {
    printVm("notification data : ${notification.toJson()}");
    try {
      switch (notification.post_data_type) {
        case "VIDEO":
          final videos = await _postProvider.getPostsVideosById(notification.post_id!);
          if (videos.isNotEmpty) {
            _hideLoadingOverlay();
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => VideoYoutubePageDetails(initialPost: videos.first),
            )).then((_) {
              setState(() {
                _isHandlingNotification = false;
              });
            });
          } else {
            _hideLoadingOverlay();
            _showErrorSnackBar(_l10n.notifVideoNotFound);
            setState(() {
              _isHandlingNotification = false;
            });
          }
          break;
        case "IMAGE":
        case "TEXT":
          final posts = await _postProvider.getPostsImagesById(notification.post_id!);
          if (posts.isNotEmpty) {
            _hideLoadingOverlay();
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => DetailsPost(post: posts.first),
            )).then((_) {
              setState(() {
                _isHandlingNotification = false;
              });
            });
          } else {
            _hideLoadingOverlay();
            _showErrorSnackBar(_l10n.notifPostNotFound);
            setState(() {
              _isHandlingNotification = false;
            });
          }
          break;
        case 'COMMENT':
          final posts = await _postProvider.getPostsImagesById(notification.post_id!);
          if (posts.isNotEmpty) {
            _hideLoadingOverlay();
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => PostComments(post: posts.first),
            )).then((_) {
              setState(() {
                _isHandlingNotification = false;
              });
            });
          } else {
            _hideLoadingOverlay();
            _showErrorSnackBar(_l10n.notifPostNotFound);
            setState(() {
              _isHandlingNotification = false;
            });
          }
          break;
        default:
        // Pour les favoris, essayer de récupérer le post
          try {
            final posts = await _postProvider.getPostsImagesById(notification.post_id!);
            if (posts.isNotEmpty) {
              _hideLoadingOverlay();
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => DetailsPost(post: posts.first),
              )).then((_) {
                setState(() {
                  _isHandlingNotification = false;
                });
              });
            } else {
              _hideLoadingOverlay();
              _showErrorSnackBar(_l10n.notifPostNotFound);
              setState(() {
                _isHandlingNotification = false;
              });
            }
          } catch (e) {
            _hideLoadingOverlay();
            _showErrorSnackBar(_l10n.notifErrorLoading);
            setState(() {
              _isHandlingNotification = false;
            });
          }
          break;
      }
    } catch (e) {
      _hideLoadingOverlay();
      printVm("Erreur post notification: $e");
      _showErrorSnackBar(_l10n.notifErrorLoadingPost);
      setState(() {
        _isHandlingNotification = false;
      });
    }
  }

  Future<void> _handleServiceNotification(NotificationData notification) async {
    try {
      final services = await _postProvider.getUserServiceById(notification.post_id!);
      if (services.isNotEmpty) {
        final service = services.first;
        service.vues = (service.vues ?? 0) + 1;

        if (!isIn(service.usersViewId!, _authProvider.loginUserData.id!)) {
          service.usersViewId!.add(_authProvider.loginUserData.id!);
        }

        await _postProvider.updateUserService(service, context);

        _hideLoadingOverlay();
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => DetailUserServicePage(data: service),
        )).then((_) {
          setState(() {
            _isHandlingNotification = false;
          });
        });
      } else {
        _hideLoadingOverlay();
        _showErrorSnackBar(_l10n.notifServiceNotFound);
        setState(() {
          _isHandlingNotification = false;
        });
      }
    } catch (e) {
      _hideLoadingOverlay();
      printVm("Erreur service notification: $e");
      _showErrorSnackBar(_l10n.notifErrorLoadingService);
      setState(() {
        _isHandlingNotification = false;
      });
    }
  }

  Widget _buildProfileAvatar(NotificationData notification) {
    final isUnread = !notification.is_open!;

    // Vérifier si c'est une notification d'un canal
    if (notification.canal_id != null && notification.canal_id!.isNotEmpty) {
      final canal = _canalCache[notification.canal_id];

      return GestureDetector(
        onTap: () {
          if (canal != null) {
            _navigateToCanal(notification.canal_id!);
          }
        },
        child: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnread ? _colors.danger : _colors.info,
                  width: isUnread ? 2 : 1,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: _colors.info.withOpacity(0.1),
                backgroundImage: canal?.urlImage != null && canal!.urlImage!.isNotEmpty
                    ? NetworkImage(canal.urlImage!)
                    : null,
                child: canal?.urlImage == null || canal!.urlImage!.isEmpty
                    ? Icon(Icons.group, color: _colors.info)
                    : null,
              ),
            ),
            if (canal?.isVerify ?? false)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _colors.info),
                  ),
                  child: Icon(
                    Icons.verified,
                    color: _colors.info,
                    size: 14,
                  ),
                ),
              ),
            // Badge spécial pour les favoris
            if (notification.type == 'FAVORITE')
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: _colors.danger,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      // C'est une notification d'un utilisateur
      final user = _userCache[notification.user_id];

      return GestureDetector(
        onTap: () {
          if (user != null) {
            _showUserProfile(notification.user_id!);
          }
        },
        child: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnread ? _colors.danger : _colors.border,
                  width: isUnread ? 2 : 1,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: _colors.surfaceVariant,
                backgroundImage: user?.imageUrl != null && user!.imageUrl!.isNotEmpty
                    ? NetworkImage(user.imageUrl!)
                    : null,
                child: user?.imageUrl == null || user!.imageUrl!.isEmpty
                    ? Icon(Icons.person, color: _colors.textSecondary)
                    : null,
              ),
            ),
            if (user?.isVerify ?? false)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _colors.border),
                  ),
                  child: Icon(
                    Icons.verified,
                    color: _colors.info,
                    size: 14,
                  ),
                ),
              ),
            // Badge spécial pour les favoris
            if (notification.type == 'FAVORITE')
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: _colors.danger,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }

  String _getSenderName(NotificationData notification) {
    // Vérifier si c'est une notification d'un canal
    if (notification.canal_id != null && notification.canal_id!.isNotEmpty) {
      final canal = _canalCache[notification.canal_id];
      return canal?.titre ?? _l10n.notifChannelLabel;
    } else {
      // C'est une notification d'un utilisateur
      final user = _userCache[notification.user_id];
      return user?.prenom ?? _l10n.profileDefaultUser;
    }
  }

  Widget _buildNotificationItem(NotificationData notification) {
    final isUnread = !notification.is_open!;
    final senderName = _getSenderName(notification);

    // Déterminer si c'est une notification de canal
    final isCanalNotification = notification.canal_id != null && notification.canal_id!.isNotEmpty;
    final isFavorite = notification.type == 'FAVORITE';
    final isComment = notification.type == 'COMMENT' || notification.type == 'COMMENTAIRE';

    // Couleur spécifique selon le type
    Color getUnreadColor() {
      if (isFavorite) return _colors.danger;
      if (isComment) return _colors.info;
      if (isCanalNotification) return _colors.info;
      return _colors.danger;
    }

    return Container(
      decoration: BoxDecoration(
        color: isUnread
            ? (isFavorite
            ? _colors.danger.withOpacity(0.08)
            : (isCanalNotification
            ? _colors.info.withOpacity(0.08)
            : _colors.danger.withOpacity(0.08)))
            : Colors.transparent,
        border: isUnread
            ? Border.all(
            color: getUnreadColor().withOpacity(0.2),
            width: 1)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () => _handleNotificationTap(notification),
          leading: _buildProfileAvatar(notification),
          title: Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: _colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isUnread
                              ? (isFavorite
                              ? _colors.danger
                              : (isCanalNotification ? _colors.info : _colors.danger))
                              : _colors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: ' ${notification.description ?? ""}',
                        style: TextStyle(
                          color: isUnread ? _colors.textPrimary : _colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _getNotificationIcon(notification),
            ],
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (isCanalNotification)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _colors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group, size: 12, color: _colors.info),
                        SizedBox(width: 2),
                        Text(
                          _l10n.notifChannelLabel,
                          style: TextStyle(
                            color: _colors.info,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isFavorite)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _colors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, size: 12, color: _colors.danger),
                        SizedBox(width: 2),
                        Text(
                          _l10n.notifFavoriteLabel,
                          style: TextStyle(
                            color: _colors.danger,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isComment)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _colors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.comment, size: 12, color: _colors.info),
                        SizedBox(width: 2),
                        Text(
                          _l10n.notifCommentLabel,
                          style: TextStyle(
                            color: _colors.info,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  _formatDateTime(DateTime.fromMicrosecondsSinceEpoch(notification.createdAt!)),
                  style: TextStyle(
                    color: isUnread
                        ? (isFavorite
                        ? _colors.danger
                        : (isCanalNotification ? _colors.info : _colors.danger))
                        : _colors.textSecondary,
                    fontSize: 12,
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          trailing: isUnread
              ? Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: getUnreadColor(),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: getUnreadColor().withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String type) {
    final isSelected = _selectedTypeFilter == type;
    final isDefault = _defaultTypes.contains(type);

    return FilterChip(
      label: Text(
        type,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? _colors.onAccent : (isDefault ? _colors.danger : _colors.textSecondary),
          fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTypeFilter = selected ? type : null;
          _loadInitialNotifications();
        });
      },
      backgroundColor: _colors.surface,
      selectedColor: isDefault ? _colors.danger : _colors.info,
      checkmarkColor: _colors.onAccent,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _markAllAsRead() async {
    final userId = _authProvider.loginUserData.id!;
    try {
      // Requête directe Firestore — ne dépend pas de ce qui est chargé en mémoire
      // On traite par lots de 500 (limite Firestore batch)
      QuerySnapshot snap;
      int totalMarked = 0;

      do {
        snap = await _firestore
            .collection('Notifications')
            .where('receiver_id', isEqualTo: userId)
            .where('is_open', isEqualTo: false)
            .limit(500)
            .get();

        if (snap.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {
            'is_open': true,
            'users_id_view': FieldValue.arrayUnion([userId]),
          });
        }
        await batch.commit();
        totalMarked += snap.docs.length;
      } while (snap.docs.length == 500);

      // Mettre à jour aussi la liste locale déjà chargée
      if (mounted) {
        setState(() {
          for (final notif in _notifications) {
            notif.is_open = true;
          }
        });
        _showSuccessSnackBar(_l10n.notifAllMarkedAsRead);
      }
    } catch (e) {
      printVm("Erreur marquer tout comme lu: $e");
      if (mounted) _showErrorSnackBar(_l10n.notifErrorMarkingAsRead);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _colors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _colors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool isIn(List<String> list, String item) {
    return list.any((element) => element == item);
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    _l10n = l10n;
    return Scaffold(
      backgroundColor: _colors.surface,
      appBar: AppBar(
        backgroundColor: _colors.surfaceVariant,
        elevation: 1,
        title: Text(
          l10n.notifTitle,
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_availableTypes.isNotEmpty)
            IconButton(
              onPressed: () {
                setState(() {
                  _showFilterMenu = !_showFilterMenu;
                });
              },
              icon: Icon(
                _showFilterMenu ? Icons.filter_alt_off : Icons.filter_alt,
                color: _selectedTypeFilter != null ? _colors.danger : _colors.textSecondary,
              ),
              tooltip: _l10n.notifFilterByType,
            ),
          if (_notifications.any((n) => !n.is_open!))
            IconButton(
              onPressed: _markAllAsRead,
              icon: Icon(Icons.done_all, color: _colors.danger),
              tooltip: l10n.notifMarkRead,
            ),
        ],
      ),
      body: CenteredContent(
        maxWidth: AppLayout.isDesktop(context) ? 800 : AppLayout.maxFeedWidth,
        child: Column(
        children: [
          if (_showFilterMenu && _availableTypes.isNotEmpty)
            Container(
              height: 50,
              color: _colors.surface,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: _availableTypes.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: FilterChip(
                        label: Text(
                          _l10n.notifAllLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedTypeFilter == null ? _colors.onAccent : _colors.textSecondary,
                          ),
                        ),
                        selected: _selectedTypeFilter == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTypeFilter = null;
                            _loadInitialNotifications();
                          });
                        },
                        backgroundColor: _colors.surface,
                        selectedColor: _colors.danger,
                        checkmarkColor: _colors.onAccent,
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    );
                  }
                  return Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: _buildFilterChip(_availableTypes[index - 1]),
                  );
                },
              ),
            ),
          Expanded(
            child: _isLoading && _notifications.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_colors.danger),
                  ),
                  SizedBox(height: 16),
                  Text(
                    _l10n.notifLoadingNotifications,
                    style: TextStyle(
                      color: _colors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
                : _notifications.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 80,
                    color: _colors.border,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _l10n.notifNoNotification,
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _l10n.notifEmptyStateSubtitle,
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                  _loadMoreNotifications();
                }
                return false;
              },
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: _colors.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _l10n.notifUnreadCount(_notifications.where((n) => !n.is_open!).length),
                            style: TextStyle(
                              color: _colors.danger,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedTypeFilter != null)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _colors.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _l10n.notifFilterLabel(_selectedTypeFilter ?? ''),
                              style: TextStyle(
                                color: _colors.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  Expanded(
                    child: ListView(
                      children: [
                        ...() {
                          // Groupes avec contenu en premier (triés par plus récent),
                          // puis les groupes vides à la suite.
                          // On prend le max entre le batch global et les samples préchargés.
                          final groups = _groupTypes.keys.toList()
                            ..sort((a, b) {
                              int latestOf(String g) {
                                final fromBatch = _notifications
                                    .where((n) => _groupForType(n.type) == g)
                                    .fold<int>(0, (m, n) => (n.createdAt ?? 0) > m ? (n.createdAt ?? 0) : m);
                                final fromSamples = (_groupSamples[g] ?? [])
                                    .fold<int>(0, (m, n) => (n.createdAt ?? 0) > m ? (n.createdAt ?? 0) : m);
                                return fromBatch > fromSamples ? fromBatch : fromSamples;
                              }
                              final la = latestOf(a), lb = latestOf(b);
                              if (la == 0 && lb == 0) return 0;
                              if (la == 0) return 1;
                              if (lb == 0) return -1;
                              return lb.compareTo(la);
                            });
                          return groups;
                        }().map((group) {
                          // Notifications du groupe dans le batch global (60 dernières)
                          final batchItems = _notifications
                              .where((n) => _groupForType(n.type) == group)
                              .toList();
                          // Si le groupe n'a pas de résultat dans le batch, utiliser
                          // les 2 items préchargés par groupe (_groupSamples).
                          final items = batchItems.isNotEmpty
                              ? batchItems
                              : (_groupSamples[group] ?? []);
                          // Vrai compte non-lus depuis Firestore (query count), fallback local
                          final unread = _groupUnreadCounts.containsKey(group)
                              ? _groupUnreadCounts[group]!
                              : items.where((n) => !(n.is_open ?? false)).length;
                          final isOpen = _groupExpanded[group] ?? false;
                          // Groupe vraiment vide seulement si ni le batch ni les samples n'ont rien
                          final isEmpty = items.isEmpty;
                          return Column(
                            children: [
                              // ── En-tête groupe (toujours visible) ──
                              InkWell(
                                onTap: isEmpty
                                    ? null
                                    : () => setState(() => _groupExpanded[group] = !isOpen),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  color: isEmpty
                                      ? _colors.surface.withOpacity(0.6)
                                      : _colors.surface,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _groupIcons[group] ?? Icons.notifications_outlined,
                                        size: 20,
                                        color: isEmpty ? _colors.textSecondary.withOpacity(0.4) : _colors.textSecondary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          group,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isEmpty
                                                ? _colors.textPrimary.withOpacity(0.4)
                                                : _colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (unread > 0)
                                        Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _colors.danger,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            unread > 99 ? '99+' : '$unread',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      if (isEmpty)
                                        Text(
                                          'Vide',
                                          style: TextStyle(color: _colors.textSecondary.withOpacity(0.4), fontSize: 11),
                                        )
                                      else
                                        Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: _colors.textSecondary, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                              // ── Items du groupe (2 au départ, +5 à chaque "Voir plus") ──
                              if (isOpen && !isEmpty) ...[
                                ...() {
                                  final visible = _groupVisibleCount[group] ?? 2;
                                  return items.take(visible).map((n) => _buildNotificationItem(n));
                                }(),
                                // Bouton "Voir plus" si des items restent à afficher
                                Builder(builder: (ctx) {
                                  final visible = _groupVisibleCount[group] ?? 2;
                                  final remaining = items.length - visible;
                                  if (remaining <= 0 && !_hasMore) return const SizedBox.shrink();
                                  if (remaining <= 0 && _hasMore) {
                                    return _isLoadingMore
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 8),
                                            child: Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: TextButton.icon(
                                              onPressed: () async {
                                                await _loadMoreNotifications();
                                                if (mounted) setState(() => _groupVisibleCount[group] = visible + 5);
                                              },
                                              icon: const Icon(Icons.expand_more, size: 16),
                                              label: const Text('Voir plus'),
                                              style: TextButton.styleFrom(foregroundColor: _colors.textSecondary),
                                            ),
                                          );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: TextButton.icon(
                                      onPressed: () => setState(() => _groupVisibleCount[group] = visible + 5),
                                      icon: const Icon(Icons.expand_more, size: 16),
                                      label: Text('Voir plus ($remaining)'),
                                      style: TextButton.styleFrom(foregroundColor: _colors.textSecondary),
                                    ),
                                  );
                                }),
                              ],
                              const Divider(height: 1),
                            ],
                          );
                        }),
                        // Chargement de plus
                        if (_hasMore)
                          _isLoadingMore
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_colors.danger))),
                                )
                              : const SizedBox.shrink(),
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
    );
  }

  List<Widget> _buildTypeCounts() {
    Map<String, int> counts = {};
    for (var notif in _notifications) {
      final type = notif.type ?? 'AUTRE';
      counts[type] = (counts[type] ?? 0) + 1;
    }

    return counts.entries.map((entry) {
      return Padding(
        padding: EdgeInsets.only(left: 8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _defaultTypes.contains(entry.key) ? _colors.danger.withOpacity(0.1) : _colors.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${entry.key}: ${entry.value}',
            style: TextStyle(
              color: _defaultTypes.contains(entry.key) ? _colors.danger : _colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }).toList();
  }
}
//
// class MesNotification extends StatefulWidget {
//   const MesNotification({super.key});
//
//   @override
//   State<MesNotification> createState() => _MesNotificationState();
// }
//
// class _MesNotificationState extends State<MesNotification> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final List<NotificationData> _notifications = [];
//   final Map<String, UserData> _userCache = {};
//   final Map<String, Canal> _canalCache = {};
//   bool _isLoading = false;
//   bool _isLoadingMore = false;
//   bool _hasMore = true;
//   bool _isHandlingNotification = false;
//   DocumentSnapshot? _lastDocument;
//   final int _pageSize = 20;
//
//   late UserAuthProvider _authProvider;
//   late PostProvider _postProvider;
//
//   @override
//   void initState() {
//     super.initState();
//     _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     _postProvider = Provider.of<PostProvider>(context, listen: false);
//     _loadInitialNotifications();
//   }
//
//   Future<void> _loadInitialNotifications() async {
//     if (_isLoading) return;
//
//     setState(() {
//       _isLoading = true;
//       _notifications.clear();
//     });
//
//     try {
//       await _loadNotificationsBatch();
//     } catch (e) {
//       printVm("Erreur chargement notifications: $e");
//       _showErrorSnackBar(_l10n.notifErrorLoadingNotifications);
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _loadMoreNotifications() async {
//     if (_isLoadingMore || !_hasMore) return;
//
//     setState(() {
//       _isLoadingMore = true;
//     });
//
//     try {
//       await _loadNotificationsBatch();
//     } catch (e) {
//       printVm("Erreur chargement plus: $e");
//     } finally {
//       setState(() {
//         _isLoadingMore = false;
//       });
//     }
//   }
//
//   Future<void> _loadNotificationsBatch() async {
//     Query query = _firestore
//         .collection('Notifications')
//         .where("receiver_id", isEqualTo: _authProvider.loginUserData.id!)
//         .orderBy('created_at', descending: true)
//         .limit(_pageSize);
//
//     if (_lastDocument != null) {
//       query = query.startAfterDocument(_lastDocument!);
//     }
//
//     final snapshot = await query.get();
//
//     if (snapshot.docs.isEmpty) {
//       setState(() {
//         _hasMore = false;
//       });
//       return;
//     }
//
//     _lastDocument = snapshot.docs.last;
//
//     for (var doc in snapshot.docs) {
//       final notification = NotificationData.fromJson(doc.data() as Map<String, dynamic>);
//
//       // Marquer comme lu si nécessaire
//       if (!isIn(notification.users_id_view!, _authProvider.loginUserData.id!)) {
//         notification.users_id_view!.add(_authProvider.loginUserData.id!);
//         await _firestore.collection('Notifications').doc(notification.id).update(notification.toJson());
//       }
//
//       _notifications.add(notification);
//
//       // Charger les données utilisateur OU canal en arrière-plan
//       if (notification.canal_id != null && notification.canal_id!.isNotEmpty) {
//         // C'est une notification d'un canal
//         _loadCanalData(notification.canal_id!);
//       } else {
//         // C'est une notification d'un utilisateur
//         _loadUserData(notification.user_id!);
//       }
//     }
//
//     setState(() {});
//   }
//
//   Future<void> _loadUserData(String userId) async {
//     if (_userCache.containsKey(userId)) return;
//
//     try {
//       final userSnapshot = await _firestore
//           .collection('Users')
//           .where("id", isEqualTo: userId)
//           .limit(1)
//           .get();
//
//       if (userSnapshot.docs.isNotEmpty) {
//         final userData = UserData.fromJson(userSnapshot.docs.first.data() as Map<String, dynamic>);
//         _userCache[userId] = userData;
//
//         // Mettre à jour les notifications avec les données utilisateur
//         for (var notif in _notifications) {
//           if (notif.user_id == userId && notif.canal_id == null) {
//             notif.userData = userData;
//           }
//         }
//         setState(() {});
//       }
//     } catch (e) {
//       printVm("Erreur chargement user $userId: $e");
//     }
//   }
//
//   Future<void> _loadCanalData(String canalId) async {
//     if (_canalCache.containsKey(canalId)) return;
//
//     try {
//       final canalSnapshot = await _firestore
//           .collection('Canaux')
//           .where("id", isEqualTo: canalId)
//           .limit(1)
//           .get();
//
//       if (canalSnapshot.docs.isNotEmpty) {
//         final canalData = Canal.fromJson(canalSnapshot.docs.first.data() as Map<String, dynamic>);
//         _canalCache[canalId] = canalData;
//
//         setState(() {});
//       }
//     } catch (e) {
//       printVm("Erreur chargement canal $canalId: $e");
//     }
//   }
//
//   Widget _getNotificationIcon(NotificationData notification) {
//     const double iconSize = 20.0;
//
//     switch (notification.type) {
//       case 'MESSAGE':
//         return Container(
//           padding: EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.red.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(Icons.message, color: Colors.red, size: iconSize),
//         );
//       case 'POST':
//       case 'NEWPOST':
//         return Container(
//           padding: EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.red.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(Icons.post_add, color: Colors.red, size: iconSize),
//         );
//       case 'INVITATION':
//         return Container(
//           padding: EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.yellow.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(Icons.person_add, color: Colors.yellow, size: iconSize),
//         );
//       case 'ARTICLE':
//         return Container(
//           padding: EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.blue.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(Icons.shopping_bag, color: Colors.blue, size: iconSize),
//         );
//       case 'SERVICE':
//         return Container(
//           padding: EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.green.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(Icons.handyman, color: Colors.green, size: iconSize),
//         );
//       case 'CHALLENGE':
//         return Container(
//           padding: EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.orange.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(Icons.emoji_events, color: Colors.orange, size: iconSize),
//         );
//       case 'ACCEPTINVITATION':
//         return Container(
//           padding: EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.purple.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(Icons.people, color: Colors.purple, size: iconSize),
//         );
//
//
//       case 'PARRAINAGE':
//         return Container(
//           padding: EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.teal.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(Icons.attach_money, color: Colors.teal, size: iconSize),
//         );
//       default:
//         return Container(
//           padding: EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.grey.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(Icons.notifications, color: Colors.grey, size: iconSize),
//         );
//     }
//   }
//
//   String _formatDateTime(DateTime dateTime) {
//     final now = DateTime.now();
//     final difference = now.difference(dateTime);
//
//     if (difference.inDays < 1) {
//       if (difference.inHours < 1) {
//         if (difference.inMinutes < 1) {
//           return "À l'instant";
//         } else {
//           return "Il y a ${difference.inMinutes} min";
//         }
//       } else {
//         return "Il y a ${difference.inHours} h";
//       }
//     } else if (difference.inDays < 7) {
//       return "Il y a ${difference.inDays} j";
//     } else {
//       return DateFormat('dd/MM/yy').format(dateTime);
//     }
//   }
//
//   void _showUserProfile(String userId) {
//     final user = _userCache[userId];
//     if (user != null) {
//       double w = MediaQuery.of(context).size.width;
//       double h = MediaQuery.of(context).size.height;
//       showUserDetailsModalDialog(user, w, h, context);
//     }
//   }
//
//   void _navigateToCanal(String canalId) {
//     final canal = _canalCache[canalId];
//     if (canal != null) {
//       // Naviguer vers la page du canal
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => CanalDetails(canal: canal),
//         ),
//       );
//     } else {
//       _showErrorSnackBar(_l10n.notifChannelNotFound);
//     }
//   }
//
//   Future<void> _handleNotificationTap(NotificationData notification) async {
//     if (_isHandlingNotification) return;
//
//     setState(() {
//       _isHandlingNotification = true;
//     });
//
//     // Afficher l'indicateur de chargement
//     _showLoadingOverlay();
//
//     try {
//       // Marquer comme lu dans Firestore
//       if (!notification.is_open!) {
//         await _firestore.collection('Notifications').doc(notification.id).update({
//           'is_open': true,
//           'users_id_view': FieldValue.arrayUnion([_authProvider.loginUserData.id!])
//         });
//
//         // Mettre à jour localement
//         setState(() {
//           notification.is_open = true;
//         });
//       }
//
//       // Naviguer vers la cible - SANS fermer le loading ici
//       await _navigateToNotificationTarget(notification);
//
//     } catch (e) {
//       printVm("Erreur traitement notification: $e");
//       _showErrorSnackBar("Erreur lors de l'ouverture");
//       _hideLoadingOverlay();
//       setState(() {
//         _isHandlingNotification = false;
//       });
//     }
//   }
//
//   void _showLoadingOverlay() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return PopScope(
//           canPop: false,
//           child: Dialog(
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             child: Container(
//               padding: EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.8),
//                 borderRadius: BorderRadius.circular(15),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   CircularProgressIndicator(
//                     valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
//                   ),
//                   SizedBox(height: 16),
//                   Text(
//                     'Chargement...',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void _hideLoadingOverlay() {
//     Navigator.of(context, rootNavigator: true).pop();
//   }
//
//   Future<void> _navigateToNotificationTarget(NotificationData notification) async {
//     try {
//       switch (notification.type) {
//         case 'MESSAGE':
//           await _handlePostNotification(notification);
//           break;
//         case 'POST':
//           await _handlePostNotification(notification);
//           break;
//         case 'NEWPOST':
//           await _handlePostNotification(notification);
//           break;
//         case 'INVITATION':
//           _hideLoadingOverlay();
//           Navigator.push(context, MaterialPageRoute(
//             builder: (context) => MesInvitationsPage(context: context),
//           )).then((_) {
//             setState(() {
//               _isHandlingNotification = false;
//             });
//           });
//           break;
//         case 'ARTICLE':
//           _hideLoadingOverlay();
//           Navigator.push(context, MaterialPageRoute(
//             builder: (context) => ProduitDetail(productId: notification.post_id!),
//           )).then((_) {
//             setState(() {
//               _isHandlingNotification = false;
//             });
//           });
//           break;
//         case 'SERVICE':
//           await _handleServiceNotification(notification);
//           break;
//         case 'ACCEPTINVITATION':
//           _hideLoadingOverlay();
//           Navigator.push(context, MaterialPageRoute(
//             builder: (context) => MesAmis(context: context),
//           )).then((_) {
//             setState(() {
//               _isHandlingNotification = false;
//             });
//           });
//           break;
//         case 'PARRAINAGE':
//           _hideLoadingOverlay();
//           Navigator.push(context, MaterialPageRoute(
//             builder: (context) => MonetisationPage(),
//           )).then((_) {
//             setState(() {
//               _isHandlingNotification = false;
//             });
//           });
//           break;
//         default:
//           _hideLoadingOverlay();
//           setState(() {
//             _isHandlingNotification = false;
//           });
//           break;
//       }
//     } catch (e) {
//       _hideLoadingOverlay();
//       printVm("Erreur navigation: $e");
//       _showErrorSnackBar("Erreur lors de l'ouverture");
//       setState(() {
//         _isHandlingNotification = false;
//       });
//     }
//   }
//
//   Future<void> _handlePostNotification(NotificationData notification) async {
//     printVm("notification data : ${notification.toJson()}");
//     try {
//       switch (notification.post_data_type) {
//         case "VIDEO":
//           final videos = await _postProvider.getPostsVideosById(notification.post_id!);
//           if (videos.isNotEmpty) {
//             _hideLoadingOverlay();
//             Navigator.push(context, MaterialPageRoute(
//               builder: (context) => OnlyPostVideo(videos: videos),
//             )).then((_) {
//               setState(() {
//                 _isHandlingNotification = false;
//               });
//             });
//           } else {
//             _hideLoadingOverlay();
//             _showErrorSnackBar(_l10n.notifVideoNotFound);
//             setState(() {
//               _isHandlingNotification = false;
//             });
//           }
//           break;
//         case "IMAGE":
//         case "TEXT":
//           final posts = await _postProvider.getPostsImagesById(notification.post_id!);
//           if (posts.isNotEmpty) {
//             _hideLoadingOverlay();
//             Navigator.push(context, MaterialPageRoute(
//               builder: (context) => DetailsPost(post: posts.first),
//             )).then((_) {
//               setState(() {
//                 _isHandlingNotification = false;
//               });
//             });
//           } else {
//             _hideLoadingOverlay();
//             _showErrorSnackBar("Publication non trouvée");
//             setState(() {
//               _isHandlingNotification = false;
//             });
//           }
//           break;
//         case 'COMMENT':
//           final posts = await _postProvider.getPostsImagesById(notification.post_id!);
//           if (posts.isNotEmpty) {
//             _hideLoadingOverlay();
//             Navigator.push(context, MaterialPageRoute(
//               builder: (context) => PostComments(post: posts.first),
//             )).then((_) {
//               setState(() {
//                 _isHandlingNotification = false;
//               });
//             });
//           } else {
//             _hideLoadingOverlay();
//             _showErrorSnackBar("Publication non trouvée");
//             setState(() {
//               _isHandlingNotification = false;
//             });
//           }
//           break;
//         default:
//           _hideLoadingOverlay();
//           setState(() {
//             _isHandlingNotification = false;
//           });
//           break;
//       }
//     } catch (e) {
//       _hideLoadingOverlay();
//       printVm("Erreur post notification: $e");
//       _showErrorSnackBar(_l10n.notifErrorLoadingPost);
//       setState(() {
//         _isHandlingNotification = false;
//       });
//     }
//   }
//
//   Future<void> _handleServiceNotification(NotificationData notification) async {
//     try {
//       final services = await _postProvider.getUserServiceById(notification.post_id!);
//       if (services.isNotEmpty) {
//         final service = services.first;
//         service.vues = (service.vues ?? 0) + 1;
//
//         if (!isIn(service.usersViewId!, _authProvider.loginUserData.id!)) {
//           service.usersViewId!.add(_authProvider.loginUserData.id!);
//         }
//
//         await _postProvider.updateUserService(service, context);
//
//         _hideLoadingOverlay();
//         Navigator.push(context, MaterialPageRoute(
//           builder: (context) => DetailUserServicePage(data: service),
//         )).then((_) {
//           setState(() {
//             _isHandlingNotification = false;
//           });
//         });
//       } else {
//         _hideLoadingOverlay();
//         _showErrorSnackBar(_l10n.notifServiceNotFound);
//         setState(() {
//           _isHandlingNotification = false;
//         });
//       }
//     } catch (e) {
//       _hideLoadingOverlay();
//       printVm("Erreur service notification: $e");
//       _showErrorSnackBar(_l10n.notifErrorLoadingService);
//       setState(() {
//         _isHandlingNotification = false;
//       });
//     }
//   }
//
//   Widget _buildProfileAvatar(NotificationData notification) {
//     final isUnread = !notification.is_open!;
//
//     // Vérifier si c'est une notification d'un canal
//     if (notification.canal_id != null && notification.canal_id!.isNotEmpty) {
//       final canal = _canalCache[notification.canal_id];
//
//       return GestureDetector(
//         onTap: () {
//           if (canal != null) {
//             _navigateToCanal(notification.canal_id!);
//           }
//         },
//         child: Stack(
//           children: [
//             Container(
//               width: 50,
//               height: 50,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: isUnread ? Colors.red : Colors.blue.shade300,
//                   width: isUnread ? 2 : 1,
//                 ),
//               ),
//               child: CircleAvatar(
//                 radius: 22,
//                 backgroundColor: Colors.blue.shade50,
//                 backgroundImage: canal?.urlImage != null && canal!.urlImage!.isNotEmpty
//                     ? NetworkImage(canal.urlImage!)
//                     : null,
//                 child: canal?.urlImage == null || canal!.urlImage!.isEmpty
//                     ? Icon(Icons.group, color: Colors.blue)
//                     : null,
//               ),
//             ),
//             if (canal?.isVerify ?? false)
//               Positioned(
//                 bottom: 0,
//                 right: 0,
//                 child: Container(
//                   padding: EdgeInsets.all(2),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     shape: BoxShape.circle,
//                     border: Border.all(color: Colors.blue.shade300),
//                   ),
//                   child: Icon(
//                     Icons.verified,
//                     color: Colors.blue,
//                     size: 14,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       );
//     } else {
//       // C'est une notification d'un utilisateur
//       final user = _userCache[notification.user_id];
//
//       return GestureDetector(
//         onTap: () {
//           if (user != null) {
//             _showUserProfile(notification.user_id!);
//           }
//         },
//         child: Stack(
//           children: [
//             Container(
//               width: 50,
//               height: 50,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: isUnread ? Colors.red : Colors.grey.shade300,
//                   width: isUnread ? 2 : 1,
//                 ),
//               ),
//               child: CircleAvatar(
//                 radius: 22,
//                 backgroundColor: Colors.grey.shade300,
//                 backgroundImage: user?.imageUrl != null && user!.imageUrl!.isNotEmpty
//                     ? NetworkImage(user.imageUrl!)
//                     : null,
//                 child: user?.imageUrl == null || user!.imageUrl!.isEmpty
//                     ? Icon(Icons.person, color: Colors.grey)
//                     : null,
//               ),
//             ),
//             if (user?.isVerify ?? false)
//               Positioned(
//                 bottom: 0,
//                 right: 0,
//                 child: Container(
//                   padding: EdgeInsets.all(2),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     shape: BoxShape.circle,
//                     border: Border.all(color: Colors.grey.shade300),
//                   ),
//                   child: Icon(
//                     Icons.verified,
//                     color: Colors.blue,
//                     size: 14,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       );
//     }
//   }
//
//   String _getSenderName(NotificationData notification) {
//     // Vérifier si c'est une notification d'un canal
//     if (notification.canal_id != null && notification.canal_id!.isNotEmpty) {
//       final canal = _canalCache[notification.canal_id];
//       return canal?.titre ?? 'Canal';
//     } else {
//       // C'est une notification d'un utilisateur
//       final user = _userCache[notification.user_id];
//       return user?.prenom ?? 'Utilisateur';
//     }
//   }
//
//   Widget _buildNotificationItem(NotificationData notification) {
//     final isUnread = !notification.is_open!;
//     final senderName = _getSenderName(notification);
//
//     // Déterminer si c'est une notification de canal
//     final isCanalNotification = notification.canal_id != null && notification.canal_id!.isNotEmpty;
//
//     return Container(
//       decoration: BoxDecoration(
//         color: isUnread
//             ? (isCanalNotification ? Colors.blue.withOpacity(0.08) : Colors.red.withOpacity(0.08))
//             : Colors.transparent,
//         border: isUnread
//             ? Border.all(
//             color: isCanalNotification ? Colors.blue.withOpacity(0.2) : Colors.red.withOpacity(0.2),
//             width: 1
//         )
//             : null,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       child: Material(
//         color: Colors.transparent,
//         child: ListTile(
//           onTap: () => _handleNotificationTap(notification),
//           leading: _buildProfileAvatar(notification),
//           title: Row(
//             children: [
//               Expanded(
//                 child: RichText(
//                   text: TextSpan(
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                     ),
//                     children: [
//                       TextSpan(
//                         text: senderName,
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: isUnread
//                               ? (isCanalNotification ? Colors.blue : Colors.red)
//                               : Colors.black,
//                         ),
//                       ),
//                       TextSpan(
//                         text: ' ${notification.description}',
//                         style: TextStyle(
//                           color: isUnread ? Colors.black87 : Colors.black54,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               _getNotificationIcon(notification),
//             ],
//           ),
//           subtitle: Padding(
//             padding: EdgeInsets.only(top: 4),
//             child: Row(
//               children: [
//                 if (isCanalNotification)
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                     margin: EdgeInsets.only(right: 6),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.group, size: 12, color: Colors.blue),
//                         SizedBox(width: 2),
//                         Text(
//                           'Canal',
//                           style: TextStyle(
//                             color: Colors.blue,
//                             fontSize: 10,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 Text(
//                   _formatDateTime(DateTime.fromMicrosecondsSinceEpoch(notification.createdAt!)),
//                   style: TextStyle(
//                     color: isUnread
//                         ? (isCanalNotification ? Colors.blue.shade600 : Colors.red.shade600)
//                         : Colors.grey.shade600,
//                     fontSize: 12,
//                     fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           trailing: isUnread
//               ? Container(
//             width: 10,
//             height: 10,
//             decoration: BoxDecoration(
//               color: isCanalNotification ? Colors.blue : Colors.red,
//               shape: BoxShape.circle,
//               boxShadow: [
//                 BoxShadow(
//                   color: (isCanalNotification ? Colors.blue : Colors.red).withOpacity(0.5),
//                   blurRadius: 4,
//                   spreadRadius: 1,
//                 ),
//               ],
//             ),
//           )
//               : null,
//         ),
//       ),
//     );
//   }
//
//   Future<void> _markAllAsRead() async {
//     try {
//       final batch = _firestore.batch();
//       for (var notif in _notifications.where((n) => !n.is_open!)) {
//         batch.update(_firestore.collection('Notifications').doc(notif.id), {
//           'is_open': true,
//           'users_id_view': FieldValue.arrayUnion([_authProvider.loginUserData.id!])
//         });
//       }
//       await batch.commit();
//
//       setState(() {
//         for (var notif in _notifications) {
//           notif.is_open = true;
//         }
//       });
//
//       _showSuccessSnackBar("Toutes les notifications sont marquées comme lues");
//     } catch (e) {
//       printVm("Erreur marquer tout comme lu: $e");
//       _showErrorSnackBar("Erreur lors du marquage comme lu");
//     }
//   }
//
//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
//
//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.green,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
//
//   bool isIn(List<String> list, String item) {
//     return list.any((element) => element == item);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade50,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 1,
//         title: Text(
//           'Notifications',
//           style: TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.bold,
//             fontSize: 20,
//           ),
//         ),
//         actions: [
//           if (_notifications.any((n) => !n.is_open!))
//             IconButton(
//               onPressed: _markAllAsRead,
//               icon: Icon(Icons.done_all, color: Colors.red),
//               tooltip: 'Tout marquer comme lu',
//             ),
//         ],
//       ),
//       body: _isLoading && _notifications.isEmpty
//           ? Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Chargement des notifications...',
//               style: TextStyle(
//                 color: Colors.grey.shade600,
//               ),
//             ),
//           ],
//         ),
//       )
//           : _notifications.isEmpty
//           ? Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.notifications_off,
//               size: 80,
//               color: Colors.grey.shade300,
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Aucune notification',
//               style: TextStyle(
//                 color: Colors.grey.shade600,
//                 fontSize: 16,
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               'Vous serez notifié des nouvelles activités',
//               style: TextStyle(
//                 color: Colors.grey.shade500,
//                 fontSize: 14,
//               ),
//             ),
//           ],
//         ),
//       )
//           : NotificationListener<ScrollNotification>(
//         onNotification: (ScrollNotification scrollInfo) {
//           if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
//             _loadMoreNotifications();
//           }
//           return false;
//         },
//         child: Column(
//           children: [
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               color: Colors.white,
//               child: Row(
//                 children: [
//                   Text(
//                     '${_notifications.where((n) => !n.is_open!).length} non lue(s)',
//                     style: TextStyle(
//                       color: Colors.red,
//                       fontWeight: FontWeight.w600,
//                       fontSize: 14,
//                     ),
//                   ),
//                   Spacer(),
//                   if (_notifications.any((n) => n.canal_id != null && n.canal_id!.isNotEmpty))
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                       decoration: BoxDecoration(
//                         color: Colors.blue.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Text(
//                         '${_notifications.where((n) => n.canal_id != null && n.canal_id!.isNotEmpty).length} canal(s)',
//                         style: TextStyle(
//                           color: Colors.blue,
//                           fontSize: 12,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//             SizedBox(height: 4),
//             Expanded(
//               child: ListView.separated(
//                 itemCount: _notifications.length + (_hasMore ? 1 : 0),
//                 separatorBuilder: (context, index) => SizedBox(height: 4),
//                 itemBuilder: (context, index) {
//                   if (index == _notifications.length) {
//                     return _isLoadingMore
//                         ? Padding(
//                       padding: EdgeInsets.all(16),
//                       child: Center(
//                         child: CircularProgressIndicator(
//                           valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
//                         ),
//                       ),
//                     )
//                         : SizedBox.shrink();
//                   }
//                   return _buildNotificationItem(_notifications[index]);
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
