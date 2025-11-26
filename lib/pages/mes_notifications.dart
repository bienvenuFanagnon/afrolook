import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/home_afroshop.dart';
import 'package:afrotok/pages/auth/authTest/constants.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/postDetails.dart';
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

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/home_afroshop.dart';
import 'package:afrotok/pages/auth/authTest/constants.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/postDetails.dart';
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
import 'UserServices/listUserService.dart';
import 'afroshop/marketPlace/acceuil/produit_details.dart';
import 'component/showUserDetails.dart';

class MesNotification extends StatefulWidget {
  const MesNotification({super.key});

  @override
  State<MesNotification> createState() => _MesNotificationState();
}

class _MesNotificationState extends State<MesNotification> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<NotificationData> _notifications = [];
  final Map<String, UserData> _userCache = {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isHandlingNotification = false;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 20;

  late UserAuthProvider _authProvider;
  late PostProvider _postProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _postProvider = Provider.of<PostProvider>(context, listen: false);
    _loadInitialNotifications();
  }

  Future<void> _loadInitialNotifications() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _notifications.clear();
    });

    try {
      await _loadNotificationsBatch();
    } catch (e) {
      print("Erreur chargement notifications: $e");
      _showErrorSnackBar("Erreur de chargement des notifications");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await _loadNotificationsBatch();
    } catch (e) {
      print("Erreur chargement plus: $e");
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadNotificationsBatch() async {
    Query query = _firestore
        .collection('Notifications')
        .where("receiver_id", isEqualTo: _authProvider.loginUserData.id!)
        .orderBy('created_at', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      setState(() {
        _hasMore = false;
      });
      return;
    }

    _lastDocument = snapshot.docs.last;

    for (var doc in snapshot.docs) {
      final notification = NotificationData.fromJson(doc.data() as Map<String, dynamic>);

      // Marquer comme lu si nécessaire
      if (!isIn(notification.users_id_view!, _authProvider.loginUserData.id!)) {
        notification.users_id_view!.add(_authProvider.loginUserData.id!);
        await _firestore.collection('Notifications').doc(notification.id).update(notification.toJson());
      }

      _notifications.add(notification);

      // Charger les données utilisateur en arrière-plan
      _loadUserData(notification.user_id!);
    }

    setState(() {});
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
          if (notif.user_id == userId) {
            notif.userData = userData;
          }
        }
        setState(() {});
      }
    } catch (e) {
      print("Erreur chargement user $userId: $e");
    }
  }

  Widget _getNotificationIcon(NotificationData notification) {
    const double iconSize = 20.0;

    switch (notification.type) {
      case 'MESSAGE':
        return Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.message, color: Colors.red, size: iconSize),
        );
      case 'POST':
        return Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.post_add, color: Colors.red, size: iconSize),
        );
      case 'INVITATION':
        return Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.yellow.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_add, color: Colors.yellow, size: iconSize),
        );
      case 'ARTICLE':
        return Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.shopping_bag, color: Colors.blue, size: iconSize),
        );
      case 'SERVICE':
        return Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.handyman, color: Colors.green, size: iconSize),
        );
      case 'CHALLENGE':
        return Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.emoji_events, color: Colors.orange, size: iconSize),
        );
      case 'ACCEPTINVITATION':
        return Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.people, color: Colors.purple, size: iconSize),
        );
      case 'PARRAINAGE':
        return Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.attach_money, color: Colors.teal, size: iconSize),
        );
      default:
        return Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.notifications, color: Colors.grey, size: iconSize),
        );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) {
          return "À l'instant";
        } else {
          return "Il y a ${difference.inMinutes} min";
        }
      } else {
        return "Il y a ${difference.inHours} h";
      }
    } else if (difference.inDays < 7) {
      return "Il y a ${difference.inDays} j";
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

      // Naviguer vers la cible - SANS fermer le loading ici
      await _navigateToNotificationTarget(notification);

    } catch (e) {
      print("Erreur traitement notification: $e");
      _showErrorSnackBar("Erreur lors de l'ouverture");
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
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chargement...',
                    style: TextStyle(
                      color: Colors.white,
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
        default:
          _hideLoadingOverlay();
          setState(() {
            _isHandlingNotification = false;
          });
          break;
      }
    } catch (e) {
      _hideLoadingOverlay();
      print("Erreur navigation: $e");
      _showErrorSnackBar("Erreur lors de l'ouverture");
      setState(() {
        _isHandlingNotification = false;
      });
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
              builder: (context) => OnlyPostVideo(videos: videos),
            )).then((_) {
              setState(() {
                _isHandlingNotification = false;
              });
            });
          } else {
            _hideLoadingOverlay();
            _showErrorSnackBar("Vidéo non trouvée");
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
            _showErrorSnackBar("Publication non trouvée");
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
            _showErrorSnackBar("Publication non trouvée");
            setState(() {
              _isHandlingNotification = false;
            });
          }
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
      print("Erreur post notification: $e");
      _showErrorSnackBar("Erreur lors du chargement du post");
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
        _showErrorSnackBar("Service non trouvé");
        setState(() {
          _isHandlingNotification = false;
        });
      }
    } catch (e) {
      _hideLoadingOverlay();
      print("Erreur service notification: $e");
      _showErrorSnackBar("Erreur lors du chargement du service");
      setState(() {
        _isHandlingNotification = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final batch = _firestore.batch();
      for (var notif in _notifications.where((n) => !n.is_open!)) {
        batch.update(_firestore.collection('Notifications').doc(notif.id), {
          'is_open': true,
          'users_id_view': FieldValue.arrayUnion([_authProvider.loginUserData.id!])
        });
      }
      await batch.commit();

      setState(() {
        for (var notif in _notifications) {
          notif.is_open = true;
        }
      });

      _showSuccessSnackBar("Toutes les notifications sont marquées comme lues");
    } catch (e) {
      print("Erreur marquer tout comme lu: $e");
      _showErrorSnackBar("Erreur lors du marquage comme lu");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool isIn(List<String> list, String item) {
    return list.any((element) => element == item);
  }

  Widget _buildNotificationItem(NotificationData notification) {
    final user = _userCache[notification.user_id];
    final isUnread = !notification.is_open!;
    printVm("_buildNotificationItem data : ${notification.toJson()}");

    return Container(
      decoration: BoxDecoration(
        color: isUnread
            ? Colors.red.withOpacity(0.08)
            : Colors.transparent,
        border: isUnread
            ? Border.all(color: Colors.red.withOpacity(0.2), width: 1)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () => _handleNotificationTap(notification),
          leading: GestureDetector(
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
                      color: isUnread ? Colors.red : Colors.grey.shade300,
                      width: isUnread ? 2 : 1,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: user?.imageUrl != null && user!.imageUrl!.isNotEmpty
                        ? NetworkImage(user.imageUrl!)
                        : null,
                    child: user?.imageUrl == null || user!.imageUrl!.isEmpty
                        ? Icon(Icons.person, color: Colors.grey)
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Icon(
                        Icons.verified,
                        color: Colors.blue,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: user?.prenom ?? 'Utilisateur',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isUnread ? Colors.red : Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: ' ${notification.description}',
                        style: TextStyle(
                          color: isUnread ? Colors.black87 : Colors.black54,
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
            child: Text(
              _formatDateTime(DateTime.fromMicrosecondsSinceEpoch(notification.createdAt!)),
              style: TextStyle(
                color: isUnread ? Colors.red.shade600 : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          trailing: isUnread
              ? Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_notifications.any((n) => !n.is_open!))
            IconButton(
              onPressed: _markAllAsRead,
              icon: Icon(Icons.done_all, color: Colors.red),
              tooltip: 'Tout marquer comme lu',
            ),
        ],
      ),
      body: _isLoading && _notifications.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
            SizedBox(height: 16),
            Text(
              'Chargement des notifications...',
              style: TextStyle(
                color: Colors.grey.shade600,
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
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 16),
            Text(
              'Aucune notification',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Vous serez notifié des nouvelles activités',
              style: TextStyle(
                color: Colors.grey.shade500,
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
              color: Colors.white,
              child: Row(
                children: [
                  Text(
                    '${_notifications.where((n) => !n.is_open!).length} non lue(s)',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 4),
            Expanded(
              child: ListView.separated(
                itemCount: _notifications.length + (_hasMore ? 1 : 0),
                separatorBuilder: (context, index) => SizedBox(height: 4),
                itemBuilder: (context, index) {
                  if (index == _notifications.length) {
                    return _isLoadingMore
                        ? Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                    )
                        : SizedBox.shrink();
                  }
                  return _buildNotificationItem(_notifications[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}