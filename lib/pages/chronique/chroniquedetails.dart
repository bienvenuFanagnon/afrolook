// pages/chronique/chronique_detail_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';
import '../user/detailsOtherUser.dart';
import 'chroniqueform.dart';// pages/chronique/chronique_detail_page.dart
// pages/chronique/chronique_detail_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';

class ChroniqueDetailPage extends StatefulWidget {
  final List<Chronique> userChroniques;

  const ChroniqueDetailPage({Key? key, required this.userChroniques}) : super(key: key);

  @override
  State<ChroniqueDetailPage> createState() => _ChroniqueDetailPageState();
}

class _ChroniqueDetailPageState extends State<ChroniqueDetailPage> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _showMessages = true;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  UserData? _chroniqueOwner;

  // Animation pour le cœur
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  bool _showHeartAnimation = false;
  bool _hasLikedCurrent = false;

  // États pour le double tap
  DateTime? _lastTap;
  final int _doubleTapTimeout = 300;

  // Map pour stocker les likes de chaque chronique
  Map<String, bool> _likesMap = {};
  Map<String, int> _likesCountMap = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeCurrentMedia();
    _loadChroniqueOwner();
    _initializeLikesData();

    // Initialisation de l'animation du cœur
    _heartAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _heartScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: Curves.elasticOut,
    ));

    _heartOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: Interval(0.5, 1.0, curve: Curves.easeOut),
    ));

    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showHeartAnimation = false;
        });
        _heartAnimationController.reset();
      }
    });
  }

  void _initializeLikesData() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    for (var chronique in widget.userChroniques) {
      // Vérifier si l'utilisateur a liké
      bool hasLiked = await chroniqueProvider.hasLiked(chronique.id!, authProvider.loginUserData.id!);
      _likesMap[chronique.id!] = hasLiked;

      // Récupérer le nombre de likes
      int likesCount = await chroniqueProvider.getLikesCount(chronique.id!);
      _likesCountMap[chronique.id!] = likesCount;
    }

    setState(() {
      _hasLikedCurrent = _likesMap[widget.userChroniques[_currentPage].id!] ?? false;
    });
  }

  void _loadChroniqueOwner() async {
    final currentChronique = widget.userChroniques[_currentPage];
    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(currentChronique.userId)
        .get();

    if (userDoc.exists) {
      setState(() {
        _chroniqueOwner = UserData.fromJson(userDoc.data()!);
      });
    }
  }

  void _initializeCurrentMedia() async {
    final currentChronique = widget.userChroniques[_currentPage];

    if (currentChronique.type == ChroniqueType.VIDEO) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.network(currentChronique.mediaUrl!)
        ..initialize().then((_) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController!.play();
          _videoController!.setLooping(true);
        });
    } else {
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = false;
    }

    _markAsViewed(currentChronique);
    _updateCurrentLikeStatus(currentChronique);
  }

  void _markAsViewed(Chronique chronique) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    if (!chronique.viewers.contains(authProvider.loginUserData.id!)) {
      chroniqueProvider.markAsViewed(chronique.id!, authProvider.loginUserData.id!);
    }
  }

  void _updateCurrentLikeStatus(Chronique chronique) {
    setState(() {
      _hasLikedCurrent = _likesMap[chronique.id!] ?? false;
    });
  }

  void _handleDoubleTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < _doubleTapTimeout) {
      // Double tap détecté
      if (!_hasLikedCurrent) {
        _likeCurrentChronique();
        _triggerHeartAnimation();
      }
    }
    _lastTap = now;
  }

  void _triggerHeartAnimation() {
    setState(() {
      _showHeartAnimation = true;
    });
    _heartAnimationController.forward();
  }

  void _likeCurrentChronique() async {
    final currentChronique = widget.userChroniques[_currentPage];
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    if (!_hasLikedCurrent) {
      await chroniqueProvider.addLike(currentChronique.id!, authProvider.loginUserData.id!);

      // Mettre à jour les données locales
      setState(() {
        _likesMap[currentChronique.id!] = true;
        _likesCountMap[currentChronique.id!] = (_likesCountMap[currentChronique.id!] ?? 0) + 1;
        _hasLikedCurrent = true;
      });

      addPointsForAction(UserAction.like);
      addPointsForOtherUserAction(currentChronique.userId, UserAction.autre);

      await _sendNotification(
          authProvider,
          currentChronique,
          '❤️ a aimé votre chronique',
          'LIKE'
      );
    }
  }

  void _likeMessage(ChroniqueMessage message) async {
    final currentChronique = widget.userChroniques[_currentPage];
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    try {
      await chroniqueProvider.likeMessage(message.id!, authProvider.loginUserData.id!);

      // Envoyer notification de remerciement à l'utilisateur qui a commenté
      if (message.userId != authProvider.loginUserData.id!) {
        await _sendCommentLikeNotification(authProvider, currentChronique, message);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('🙏 Merci pour ce commentaire!'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Erreur: $e'),
        ),
      );
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final currentChronique = widget.userChroniques[_currentPage];
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    try {
      await chroniqueProvider.addMessage(
        chroniqueId: currentChronique.id!,
        userId: authProvider.loginUserData.id!,
        userPseudo: authProvider.loginUserData.pseudo!,
        userImageUrl: authProvider.loginUserData.imageUrl!,
        message: _messageController.text.trim(),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messageScrollController.animateTo(
          _messageScrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
      addPointsForAction(UserAction.commentaire);
      addPointsForOtherUserAction(currentChronique.userId, UserAction.autre);

      await _sendNotification(
          authProvider,
          currentChronique,
          '💬 a commenté votre chronique: "${_messageController.text.trim()}"',
          'COMMENT'
      );
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Erreur: $e'),
        ),
      );
    }
  }

  void _deleteMessage(ChroniqueMessage message, Chronique chronique) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    bool canDelete = authProvider.loginUserData.id == message.userId ||
        authProvider.loginUserData.id == chronique.userId;

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Vous n\'avez pas la permission de supprimer ce message'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Supprimer le commentaire',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer ce commentaire ?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await chroniqueProvider.deleteMessage(chronique.id!, message.id!);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('Commentaire supprimé avec succès'),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text('Erreur lors de la suppression: $e'),
                  ),
                );
              }
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendNotification(
      UserAuthProvider authProvider,
      Chronique chronique,
      String message,
      String type
      ) async {
    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(chronique.userId)
          .get();

      if (ownerDoc.exists) {
        final ownerData = UserData.fromJson(ownerDoc.data()!);
        if (ownerData.oneIgnalUserid != null && ownerData.oneIgnalUserid!.isNotEmpty) {
          await authProvider.sendNotification(
            appName: '@${authProvider.loginUserData.pseudo!}',
            userIds: [ownerData.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: chronique.userId,
            message: message,
            type_notif: type,
            post_id: chronique.id!,
            post_type: 'CHRONIQUE',
            chat_id: '',
          );
        }
      }
    } catch (e) {
      print('Erreur envoi notification: $e');
    }
  }

  Future<void> _sendCommentLikeNotification(
      UserAuthProvider authProvider,
      Chronique chronique,
      ChroniqueMessage message
      ) async {
    try {
      final commentOwnerDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(message.userId)
          .get();

      if (commentOwnerDoc.exists) {
        final commentOwnerData = UserData.fromJson(commentOwnerDoc.data()!);
        if (commentOwnerData.oneIgnalUserid != null && commentOwnerData.oneIgnalUserid!.isNotEmpty) {

          // Message de notification personnalisé avec contexte de la chronique
          String notificationMessage;
          if (chronique.textContent != null && chronique.textContent!.isNotEmpty) {
            String chroniquePreview = chronique.textContent!.length > 30
                ? '${chronique.textContent!.substring(0, 30)}...'
                : chronique.textContent!;
            notificationMessage = '🙏 @${authProvider.loginUserData.pseudo!} a aimé votre commentaire sur sa chronique "$chroniquePreview"';
          } else {
            notificationMessage = '🙏 @${authProvider.loginUserData.pseudo!} a aimé votre commentaire sur sa chronique';
          }

          await authProvider.sendNotification(
            appName: '@${authProvider.loginUserData.pseudo!}',
            userIds: [commentOwnerData.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: message.userId,
            message: notificationMessage,
            type_notif: 'COMMENT_LIKE',
            post_id: chronique.id!,
            post_type: 'CHRONIQUE',
            chat_id: '',
          );
        }
      }
    } catch (e) {
      print('Erreur envoi notification like commentaire: $e');
    }
  }

  void _deleteChronique(Chronique chronique) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    bool canDelete = authProvider.loginUserData.id == chronique.userId ||
        authProvider.loginUserData.role == 'ADM';

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Vous n\'avez pas la permission de supprimer cette chronique'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Supprimer la chronique',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer cette chronique ?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await chroniqueProvider.deleteChronique(
                    chronique.id!,
                    chronique.mediaUrl ?? ''
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('Chronique supprimée avec succès'),
                  ),
                );
                if (widget.userChroniques.length == 1) {
                  Navigator.pop(context);
                } else {
                  setState(() {});
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('Chronique supprimée avec succès'),
                  ),
                );
              }
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChroniqueMessage message, Chronique chronique) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    bool isMessageOwner = authProvider.loginUserData.id == message.userId;
    bool isChroniqueOwner = authProvider.loginUserData.id == chronique.userId;
    bool canInteract = isChroniqueOwner && !isMessageOwner; // Le propriétaire peut interagir sur les messages des autres

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chronique_messages')
          .doc(message.id!)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildMessageContent(message, chronique, canInteract, isMessageOwner, 0, false);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final likeCount = data?['likeCount'] ?? 0;
        final likers = List<String>.from(data?['likers'] ?? []);
        final isLiked = likers.contains(authProvider.loginUserData.id!);

        return _buildMessageContent(message, chronique, canInteract, isMessageOwner, likeCount, isLiked);
      },
    );
  }

  Widget _buildMessageContent(ChroniqueMessage message, Chronique chronique, bool canInteract, bool isMessageOwner, int likeCount, bool isLiked) {
    return GestureDetector(
      onLongPress: () => _deleteMessage(message, chronique),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _showUserProfile(message.userId),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundImage: CachedNetworkImageProvider(message.userImageUrl),
                  ),
                  if (isMessageOwner)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _showUserProfile(message.userId),
                    child: Text(
                      '@${message.userPseudo}',
                      style: TextStyle(
                        color: isMessageOwner ? Colors.blue : Color(0xFFFFD700),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    message.message,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (canInteract || isMessageOwner)
              _buildMessageLikeButton(message, likeCount, isLiked, canInteract),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageLikeButton(ChroniqueMessage message, int likeCount, bool isLiked, bool canInteract) {
    return GestureDetector(
      onTap: () {
        if (canInteract && !isLiked) {
          _likeMessage(message);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : (canInteract ? Colors.grey : Colors.grey.withOpacity(0.5)),
              size: 12,
            ),
            SizedBox(width: 2),
            Text(
              likeCount > 0 ? '$likeCount' : '',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserProfile(String userId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .get();

    if (userDoc.exists) {
      final user = UserData.fromJson(userDoc.data()!);
      double w = MediaQuery.of(context).size.width;
      double h = MediaQuery.of(context).size.height;
      showUserDetailsModalDialog(user, w, h, context);
    }
  }

  Widget _buildMessagesPanel(Chronique currentChronique) {
    return Positioned(
      bottom: 120,
      left: 8,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showMessages = !_showMessages;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showMessages ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _showMessages ? 'Masquer' : 'Afficher',
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
            SizedBox(height: 4),
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: _showMessages ? 200 : 0,
              child: _showMessages ? StreamBuilder<List<ChroniqueMessage>>(
                stream: Provider.of<ChroniqueProvider>(context)
                    .getChroniqueMessages(currentChronique.id!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return SizedBox();
                  }

                  final messages = snapshot.data!;

                  return ListView.builder(
                    controller: _messageScrollController,
                    padding: EdgeInsets.all(4),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(messages[index], currentChronique);
                    },
                  );
                },
              ) : SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final currentChronique = widget.userChroniques[_currentPage];

    return Positioned(
      bottom: 15,
      left: 8,
      right: 8,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLength: 20,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 10),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: 6),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.send, color: Colors.black, size: 16),
                onPressed: _sendMessage,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikeSection() {
    final currentChronique = widget.userChroniques[_currentPage];
    final likesCount = _likesCountMap[currentChronique.id!] ?? 0;

    return Positioned(
      bottom: 70,
      right: 16,
      child: Column(
        children: [
          // Bouton Like avec animation
          GestureDetector(
            onTap: _likeCurrentChronique,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _hasLikedCurrent ? Icons.favorite : Icons.favorite_border,
                    color: _hasLikedCurrent ? Colors.red : Colors.white,
                    size: 35,
                  ),
                  if (_showHeartAnimation)
                    AnimatedBuilder(
                      animation: _heartAnimationController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _heartOpacityAnimation.value,
                          child: Transform.scale(
                            scale: _heartScaleAnimation.value,
                            child: Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 4),
          // Affichage du nombre de likes
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$likesCount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartAnimation() {
    if (!_showHeartAnimation) return SizedBox();

    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _heartAnimationController,
          builder: (context, child) {
            return Opacity(
              opacity: _heartOpacityAnimation.value,
              child: Transform.scale(
                scale: _heartScaleAnimation.value,
                child: Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 120,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Row(
        children: widget.userChroniques.map((chronique) {
          int index = widget.userChroniques.indexOf(chronique);
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: _currentPage == index ? Color(0xFFFFD700) : Colors.grey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserProfileWithStats(Chronique chronique) {
    final likesCount = _likesCountMap[chronique.id!] ?? 0;

    return Positioned(
      top: 60,
      left: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _showUserProfile(chronique.userId),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: CachedNetworkImageProvider(chronique.userImageUrl),
                  ),
                  if (_chroniqueOwner?.isVerify == true)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showUserProfile(chronique.userId),
              child: Text(
                '@${chronique.userPseudo}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 12),
            _buildStatItem(Icons.favorite, '$likesCount', 14),
            SizedBox(width: 8),
            _buildStatItem(Icons.remove_red_eye, '${chronique.viewCount}', 14),
            SizedBox(width: 8),
            _buildStatItem(Icons.timer, '${_getTimeLeft(chronique.expiresAt)}', 14),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String count, double iconSize) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: iconSize),
        SizedBox(width: 2),
        Text(
          count,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentChronique = widget.userChroniques[_currentPage];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Contenu principal avec GestureDetector pour double tap
            GestureDetector(
              onTap: _handleDoubleTap,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.userChroniques.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _initializeCurrentMedia();
                  _loadChroniqueOwner();
                },
                itemBuilder: (context, index) {
                  final chronique = widget.userChroniques[index];
                  return _buildChroniqueContent(chronique);
                },
              ),
            ),

            // Header avec bouton suppression
            _buildHeader(currentChronique),

            // Barre de progression
            _buildProgressIndicator(),

            // Profil utilisateur avec stats
            _buildUserProfileWithStats(currentChronique),

            // Messages
            _buildMessagesPanel(currentChronique),

            // Section Like avec compteur
            _buildLikeSection(),

            // Animation du cœur
            _buildHeartAnimation(),

            // Input message
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Chronique chronique) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    bool canDelete = authProvider.loginUserData.id == chronique.userId ||
        authProvider.loginUserData.role == 'ADM';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
            Spacer(),
            if (canDelete)
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red, size: 22),
                onPressed: () => _deleteChronique(chronique),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChroniqueContent(Chronique chronique) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: _buildMainContent(chronique),
    );
  }

  Widget _buildMainContent(Chronique chronique) {
    switch (chronique.type) {
      case ChroniqueType.TEXT:
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Color(int.parse(chronique.backgroundColor!, radix: 16)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                chronique.textContent!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 8,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );

      case ChroniqueType.IMAGE:
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: CachedNetworkImage(
                imageUrl: chronique.mediaUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                  ),
                ),
              ),
            ),
            if (chronique.textContent != null && chronique.textContent!.isNotEmpty)
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    chronique.textContent!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );

      case ChroniqueType.VIDEO:
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  if (_videoController != null && _isVideoInitialized)
                    VideoPlayer(_videoController!),
                  if (!_isVideoInitialized)
                    Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                      ),
                    ),
                  Center(
                    child: IconButton(
                      icon: Icon(
                        _videoController?.value.isPlaying == true
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white.withOpacity(0.7),
                        size: 60,
                      ),
                      onPressed: () {
                        if (_videoController?.value.isPlaying == true) {
                          _videoController?.pause();
                        } else {
                          _videoController?.play();
                        }
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (chronique.textContent != null && chronique.textContent!.isNotEmpty)
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    chronique.textContent!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
    }
  }

  String _getTimeLeft(Timestamp expiresAt) {
    final now = DateTime.now();
    final expireTime = expiresAt.toDate();
    final difference = expireTime.difference(now);

    if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Expiré';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    _messageController.dispose();
    _messageScrollController.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }
}