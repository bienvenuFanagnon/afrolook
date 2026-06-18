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

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';
import 'chroniqueform.dart';
// pages/chronique/chronique_detail_page.dart
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';
import 'chroniqueform.dart';

class ChroniqueDetailPage extends StatefulWidget {
  final String initialChroniqueId;

  const ChroniqueDetailPage({
    Key? key,
    required this.initialChroniqueId,
  }) : super(key: key);

  @override
  State<ChroniqueDetailPage> createState() => _ChroniqueDetailPageState();
}

class _ChroniqueDetailPageState extends State<ChroniqueDetailPage> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  UserData? _chroniqueOwner;
  late UserAuthProvider authProvider ;
  late ChroniqueProvider chroniqueProvider ;
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  bool _showHeartAnimation = false;
  bool _hasLikedCurrent = false;

  DateTime? _lastTap;
  final int _doubleTapTimeout = 300;

  List<Chronique> _allChroniques = [];
  bool _isLoading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _batchSize = 5;
  bool _isLoadingMore = false;

  // Publicités injectées entre les chroniques
  List<Advertisement> _activeAds = [];
  final Map<String, String?> _adImageUrls = {};

  Map<String, bool> _likesMap = {};
  Map<String, int> _likesCountMap = {};

  bool _showMessages = true;
  final int _maxMessageLength = 30;

  @override
  void initState() {
    super.initState();
 authProvider = Provider.of<UserAuthProvider>(context, listen: false);
     chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
    _pageController = PageController();
    _initializeLikesData();
    _loadInitialChroniques();
    _loadActiveAds();

    _heartAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _heartScaleAnimation = Tween<double>(begin: 0.0, end: 1.5).animate(
      CurvedAnimation(parent: _heartAnimationController, curve: Curves.elasticOut),
    );

    _heartOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _heartAnimationController, curve: Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeartAnimation = false);
        _heartAnimationController.reset();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🔥 Recharger les likes à chaque fois qu'on revient sur la page
    _refreshLikesFromCurrentChronique();
  }

  void _refreshLikesFromCurrentChronique() {
    if (_allChroniques.isEmpty) return;

    final currentChronique = _allChroniques[_currentPage];
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    // 🔥 Vérifier directement dans la chronique locale si l'utilisateur a liké
    final hasLiked = currentChronique.likers.contains(authProvider.loginUserData.id);
    final likesCount = currentChronique.likeCount;

    setState(() {
      _hasLikedCurrent = hasLiked;
      if (currentChronique.id != null) {
        _likesMap[currentChronique.id!] = hasLiked;
        _likesCountMap[currentChronique.id!] = likesCount;
      }
    });

    print('🔄 Refresh likes - hasLiked: $hasLiked, likesCount: $likesCount, likers: ${currentChronique.likers}');
  }
  Future<void> _loadInitialChroniques() async {
    setState(() {
      _isLoading = true;
      _allChroniques.clear();
      _hasMore = true;
      _lastDocument = null;
    });

    try {
      final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
      final result = await chroniqueProvider.getActiveChroniquesBatch(
        limit: _batchSize,
        lastDocument: _lastDocument,
      );

      if (result.isNotEmpty) {
        DocumentSnapshot? newLastDocument;
        if (result.last.id != null) {
          newLastDocument = await FirebaseFirestore.instance
              .collection('chroniques')
              .doc(result.last.id)
              .get();
        }

        setState(() {
          _allChroniques = result;
          _lastDocument = newLastDocument;
          _hasMore = result.length == _batchSize;
        });

        // 🔥 AJOUTER CET APPEL - Initialiser les likes à partir des données chargées
        _initializeLikesData();  // ← AJOUTEZ CETTE LIGNE

        int initialIndex = _allChroniques.indexWhere((c) => c.id == widget.initialChroniqueId);
        if (initialIndex != -1 && initialIndex != 0) {
          _currentPage = initialIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) => _pageController.jumpToPage(_chroniqueToVirtual(initialIndex)));
        }

        if (_allChroniques.isNotEmpty) {
          _initializeCurrentMedia();
          _loadChroniqueOwner();
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      print('Erreur chargement chroniques: $e');
      setState(() => _isLoading = false);
    }
  }
  Future<void> _loadMoreChroniques() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
      final result = await chroniqueProvider.getActiveChroniquesBatch(
        limit: _batchSize,
        lastDocument: _lastDocument,
      );

      if (result.isNotEmpty) {
        DocumentSnapshot? newLastDocument;
        if (result.last.id != null) {
          newLastDocument = await FirebaseFirestore.instance
              .collection('chroniques')
              .doc(result.last.id)
              .get();
        }

        setState(() {
          _allChroniques.addAll(result);
          _lastDocument = newLastDocument;
          _hasMore = result.length == _batchSize;
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      print('Erreur chargement plus de chroniques: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _initializeLikesData() {
    // 🔥 Plus besoin d'appeler Firestore, on utilise les données déjà chargées

    for (var chronique in _allChroniques) {
      if (chronique.id != null) {
        // Utiliser les listes déjà présentes dans l'objet Chronique
        bool hasLiked = chronique.likers.contains(authProvider.loginUserData.id);
        int likesCount = chronique.likeCount;  // Directement depuis l'objet

        _likesMap[chronique.id!] = hasLiked;
        _likesCountMap[chronique.id!] = likesCount;
      }
    }

    if (_allChroniques.isNotEmpty && _allChroniques[_currentPage].id != null) {
      setState(() => _hasLikedCurrent = _likesMap[_allChroniques[_currentPage].id!] ?? false);
    }
  }

  void _loadChroniqueOwner() async {
    if (_allChroniques.isEmpty) return;
    final currentChronique = _allChroniques[_currentPage];
    final userDoc = await FirebaseFirestore.instance.collection('Users').doc(currentChronique.userId).get();
    if (userDoc.exists) {
      setState(() => _chroniqueOwner = UserData.fromJson(userDoc.data()!));
    }
  }

  void _initializeCurrentMedia() async {
    if (_allChroniques.isEmpty) return;
    final currentChronique = _allChroniques[_currentPage];

    if (currentChronique.type == ChroniqueType.VIDEO && currentChronique.mediaUrl != null) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.network(currentChronique.mediaUrl!)
        ..initialize().then((_) {
          setState(() => _isVideoInitialized = true);
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

    if (!chronique.viewers.contains(authProvider.loginUserData.id!)) {
      chroniqueProvider.markAsViewed(chronique.id!, authProvider.loginUserData.id!);
    }
  }

  void _updateCurrentLikeStatus(Chronique chronique) {
    setState(() => _hasLikedCurrent = _likesMap[chronique.id!] ?? false);
  }

  void _handleDoubleTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < _doubleTapTimeout) {
      if (!_hasLikedCurrent) {
        _likeCurrentChronique();
        _triggerHeartAnimation();
      }
    }
    _lastTap = now;
  }

  void _triggerHeartAnimation() {
    setState(() => _showHeartAnimation = true);
    _heartAnimationController.forward();
  }

  void _likeCurrentChronique() async {
    if (_allChroniques.isEmpty) return;

    final currentChronique = _allChroniques[_currentPage];
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    if (!_hasLikedCurrent && currentChronique.id != null) {

      // 🔥 1. METTRE À JOUR LOCALEMENT D'ABORD
      setState(() {
        // Mettre à jour la chronique dans _allChroniques
        final index = _currentPage;
        _allChroniques[index].likers.add(authProvider.loginUserData.id!);
        _allChroniques[index].likeCount += 1;

        // Mettre à jour les maps
        _likesMap[currentChronique.id!] = true;
        _likesCountMap[currentChronique.id!] = (_likesCountMap[currentChronique.id!] ?? 0) + 1;
        _hasLikedCurrent = true;
      });

      // 🔥 2. ENSUITE SYNC AVEC FIRESTORE (en arrière-plan)
      try {
        await chroniqueProvider.addLike(currentChronique.id!, authProvider.loginUserData.id!);

        // Points et notifications
        addPointsForAction(UserAction.like);
        addPointsForOtherUserAction(currentChronique.userId, UserAction.autre);

        await _sendNotification(
            authProvider,
            currentChronique,
            '❤️ a aimé votre chronique',
            'LIKE'
        );
      } catch (e) {
        // En cas d'erreur, on annule localement
        setState(() {
          _allChroniques[_currentPage].likers.remove(authProvider.loginUserData.id!);
          _allChroniques[_currentPage].likeCount -= 1;
          _likesMap[currentChronique.id!] = false;
          _likesCountMap[currentChronique.id!] = (_likesCountMap[currentChronique.id!] ?? 1) - 1;
          _hasLikedCurrent = false;
        });
        print('Erreur like: $e');
      }
    }
  }
  void _likeMessage(ChroniqueMessage message) async {
    final currentChronique = _allChroniques[_currentPage];
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    try {
      await chroniqueProvider.likeMessage(message.id!, authProvider.loginUserData.id!);
      if (message.userId != authProvider.loginUserData.id!) {
        await _sendCommentLikeNotification(authProvider, currentChronique, message);
      }
    } catch (e) {
      print('Erreur like message: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_messageController.text.length > _maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message trop long (max $_maxMessageLength caractères)'), backgroundColor: Colors.orange),
      );
      return;
    }

    final currentChronique = _allChroniques[_currentPage];
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
      _messageController.clear();
    } catch (e) {
      print('Erreur envoi message: $e');
    }
  }

  void _deleteMessage(ChroniqueMessage message, Chronique chronique) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
    bool canDelete = authProvider.loginUserData.id == message.userId || authProvider.loginUserData.id == chronique.userId;

    if (!canDelete) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('Supprimer', style: TextStyle(color: Color(0xFFFFD700))),
        content: Text('Supprimer ce commentaire ?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await chroniqueProvider.deleteMessage(chronique.id!, message.id!);
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendNotification(UserAuthProvider authProvider, Chronique chronique, String message, String type) async {
    final ownerDoc = await FirebaseFirestore.instance.collection('Users').doc(chronique.userId).get();
    if (ownerDoc.exists && ownerDoc.data()!['oneIgnalUserid'] != null) {
      await authProvider.sendNotification(
        appName: '@${authProvider.loginUserData.pseudo!}',
        userIds: [ownerDoc.data()!['oneIgnalUserid']],
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

  Future<void> _sendCommentLikeNotification(UserAuthProvider authProvider, Chronique chronique, ChroniqueMessage message) async {
    final commentOwnerDoc = await FirebaseFirestore.instance.collection('Users').doc(message.userId).get();
    if (commentOwnerDoc.exists && commentOwnerDoc.data()!['oneIgnalUserid'] != null) {
      await authProvider.sendNotification(
        appName: '@${authProvider.loginUserData.pseudo!}',
        userIds: [commentOwnerDoc.data()!['oneIgnalUserid']],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: message.userId,
        message: '🙏 a aimé votre commentaire',
        type_notif: 'COMMENT_LIKE',
        post_id: chronique.id!,
        post_type: 'CHRONIQUE',
        chat_id: '',
      );
    }
  }

  void _deleteChronique(Chronique chronique) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
    bool canDelete = authProvider.loginUserData.id == chronique.userId || authProvider.loginUserData.role == 'ADM';

    if (!canDelete) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('Supprimer', style: TextStyle(color: Color(0xFFFFD700))),
        content: Text('Supprimer cette chronique ?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await chroniqueProvider.deleteChronique(chronique.id!, chronique.mediaUrl ?? '');
              setState(() => _allChroniques.removeWhere((c) => c.id == chronique.id));
              if (_allChroniques.isEmpty) Navigator.pop(context);
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PhotoView(
                imageProvider: CachedNetworkImageProvider(imageUrl),
                backgroundDecoration: BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
              Positioned(
                top: 40,
                left: 16,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenVideo() {
    if (_videoController == null || !_isVideoInitialized) return;

    final oldController = _videoController;
    final isPlaying = _videoController!.value.isPlaying;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),
              Positioned(
                top: 40,
                left: 16,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (isPlaying && oldController != null) {
        oldController.play();
      }
    });
  }

  Widget _buildMessageBubble(ChroniqueMessage message, Chronique chronique) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    bool isMessageOwner = authProvider.loginUserData.id == message.userId;
    bool isChroniqueOwner = authProvider.loginUserData.id == chronique.userId;
    bool canInteract = isChroniqueOwner && !isMessageOwner;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chronique_messages').doc(message.id!).snapshots(),
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
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final isChroniqueOwner = authProvider.loginUserData.id == chronique.userId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: () {
          final canDelete = authProvider.loginUserData.id == message.userId ||
              authProvider.loginUserData.id == chronique.userId ||
              authProvider.loginUserData.role == 'ADM';
          if (canDelete) {
            _showDeleteMessageDialog(message, chronique);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3), // 🔥 Blanc transparent à 10%
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5), // 🔥 Bordure très légère
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showUserProfile(message.userId),
                child: CircleAvatar(
                  radius: 14,
                  backgroundImage: CachedNetworkImageProvider(message.userImageUrl),
                ),
              ),
              SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _showUserProfile(message.userId),
                      child: Text(
                        '@${message.userPseudo}',
                        style: TextStyle(
                          color: isMessageOwner ? Colors.blue : Color(0xFFFFD700),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      message.message,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              _buildMessageLikeButton(message, likeCount, isLiked, isChroniqueOwner, isMessageOwner),
            ],
          ),
        ),
      ),
    );
  }
// 🔥 Nouvelle méthode pour afficher le dialogue de suppression
  void _showDeleteMessageDialog(ChroniqueMessage message, Chronique chronique) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    bool canDelete = authProvider.loginUserData.id == message.userId ||
        authProvider.loginUserData.id == chronique.userId ||
        authProvider.loginUserData.role == 'ADM';

    if (!canDelete) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Supprimer le message',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer ce message ?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
              await chroniqueProvider.deleteMessage(chronique.id!, message.id!);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Message supprimé'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  Widget _buildMessageLikeButton(ChroniqueMessage message, int likeCount, bool isLiked, bool isChroniqueOwner, bool isMessageOwner) {
    // Seul le propriétaire de la chronique peut liker les messages des autres
    final canLike = isChroniqueOwner && !isMessageOwner;

    return GestureDetector(
      onTap: () {
        if (canLike && !isLiked) {
          _likeMessage(message);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: canLike ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.1), // 🔥 Fond rouge pour le bouton like
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : (canLike ? Colors.red : Colors.grey.withOpacity(0.5)), // 🔥 Rouge pour le like
              size: 14,
            ),
            if (likeCount > 0) ...[
              SizedBox(width: 4),
              Text(
                '$likeCount',
                style: TextStyle(
                  color: isLiked ? Colors.red : (canLike ? Colors.red : Colors.grey),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showUserProfile(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
    if (userDoc.exists) {
      showUserDetailsModalDialog(UserData.fromJson(userDoc.data()!), MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
    }
  }

  // ============================================================
  // PUBS — chargement et injection entre chroniques
  // ============================================================

  Future<void> _loadActiveAds() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Advertisements')
          .where('status', isEqualTo: 'active')
          .limit(5)
          .get();

      final ads = <Advertisement>[];
      final futures = <Future<void>>[];

      for (final doc in snap.docs) {
        final ad = Advertisement.fromJson(doc.data());
        ad.id = doc.id;
        ads.add(ad);

        if (ad.postId != null) {
          futures.add(
            FirebaseFirestore.instance.collection('Posts').doc(ad.postId).get().then((postDoc) {
              if (!postDoc.exists) return;
              final data = postDoc.data()!;
              final images = data['images'] as List?;
              final url = (images != null && images.isNotEmpty)
                  ? images.first as String?
                  : data['url_media'] as String?;
              if (url != null && url.isNotEmpty) {
                _adImageUrls[ad.id!] = url;
              }
            }).catchError((_) {}),
          );
        }
      }

      await Future.wait(futures);

      if (mounted && ads.isNotEmpty) {
        setState(() => _activeAds = ads);
      }
    } catch (_) {}
  }

  Future<void> _recordAdView(Advertisement ad) async {
    if (ad.id == null) return;
    final viewIncr = Random().nextInt(3) + 1;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).update({
        'views': FieldValue.increment(viewIncr),
        'uniqueViews': FieldValue.increment(1),
        'dailyStats.$today.views': FieldValue.increment(viewIncr),
      });
    } catch (_) {}
  }

  Future<void> _recordAdClick(Advertisement ad) async {
    if (ad.id == null) return;
    final clickIncr = Random().nextInt(3) + 1;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).update({
        'clicks': FieldValue.increment(clickIncr),
        'uniqueClicks': FieldValue.increment(1),
        'dailyStats.$today.clicks': FieldValue.increment(clickIncr),
      });
    } catch (_) {}
  }

  /// Liste mixte Chronique + Advertisement pour le PageView.
  /// Règle : après la 1ère chronique, puis toutes les 3.
  List<dynamic> get _displayItems {
    if (_activeAds.isEmpty) return _allChroniques;
    final result = <dynamic>[];
    for (int i = 0; i < _allChroniques.length; i++) {
      result.add(_allChroniques[i]);
      if (i % 3 == 0) {
        final adIndex = (i ~/ 3) % _activeAds.length;
        result.add(_activeAds[adIndex]);
      }
    }
    return result;
  }

  int _virtualToChronique(int virtualIndex) {
    int count = 0;
    for (int i = 0; i < virtualIndex && i < _displayItems.length; i++) {
      if (_displayItems[i] is Chronique) count++;
    }
    return count;
  }

  bool _isVirtualAd(int virtualIndex) {
    if (virtualIndex < 0 || virtualIndex >= _displayItems.length) return false;
    return _displayItems[virtualIndex] is Advertisement;
  }

  int _chroniqueToVirtual(int chroniqueIndex) {
    int count = 0;
    for (int i = 0; i < _displayItems.length; i++) {
      if (_displayItems[i] is Chronique) {
        if (count == chroniqueIndex) return i;
        count++;
      }
    }
    return chroniqueIndex;
  }

  Widget _buildAdSlide(Advertisement ad) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordAdView(ad));

    final imageUrl = _adImageUrls[ad.id ?? ''];
    // Bouton au-dessus du bottom bar :
    //   sans messages : ~40px toggle + 8 + 40px input + 15px bottom = ~103px
    //   avec messages : ~40 + 8 + 150 + 8 + 40 + 15 = ~261px
    final actionBottomOffset = _showMessages ? 280.0 : 120.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Fond flouté (BoxFit.cover pour remplir l'écran) ──
        if (imageUrl != null)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.55),
            colorBlendMode: BlendMode.darken,
            placeholder: (_, __) => Container(color: Colors.black),
            errorWidget: (_, __, ___) => Container(color: Colors.black),
          )
        else
          Container(color: Colors.black87),

        // ── Image principale (BoxFit.contain → respecte le format paysage/portrait) ──
        if (imageUrl != null)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

        // ── Dégradés haut et bas ──
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                  Colors.black.withOpacity(0.75),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // ── Badge SPONSORISÉ ──
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD600),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Colors.black, size: 13),
                SizedBox(width: 4),
                Text('SPONSORISÉ', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),

        // ── Bouton d'action — positionné au-dessus du bottom bar ──
        if (ad.actionType != null || ad.actionButtonText != null)
          Positioned(
            bottom: actionBottomOffset,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    _recordAdClick(ad);
                    if (ad.actionUrl != null && ad.actionUrl!.isNotEmpty) {
                      final url = Uri.parse(ad.actionUrl!);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE21221), Color(0xFFFF5252)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ad.actionType == 'download' ? Icons.download
                              : ad.actionType == 'visit' ? Icons.language
                              : Icons.info_outline,
                          color: Colors.white,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ad.getActionButtonText(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFD700)),
              SizedBox(height: 16),
              Text('Chargement des chroniques...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (_allChroniques.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, color: Color(0xFFFFD700), size: 80),
              SizedBox(height: 20),
              Text('Aucune chronique disponible', style: TextStyle(color: Colors.white, fontSize: 18)),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddChroniquePage())),
                icon: Icon(Icons.add, color: Colors.black),
                label: Text('Créer une chronique'),
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFFD700), foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
      );
    }

    final currentChronique = _allChroniques[_currentPage];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _displayItems.length,
              onPageChanged: (virtualIndex) {
                final chroniqueIdx = _virtualToChronique(virtualIndex);
                setState(() => _currentPage = chroniqueIdx);
                if (!_isVirtualAd(virtualIndex)) {
                  _initializeCurrentMedia();
                  _loadChroniqueOwner();
                }
                if (_currentPage >= _allChroniques.length - 2 && _hasMore && !_isLoadingMore) {
                  _loadMoreChroniques();
                }
              },
              itemBuilder: (context, index) {
                final item = _displayItems[index];
                if (item is Advertisement) {
                  return _buildAdSlide(item);
                }
                final chronique = item as Chronique;
                return GestureDetector(
                  onTap: () {
                    if (chronique.type == ChroniqueType.IMAGE) {
                      _showFullScreenImage(chronique.mediaUrl!);
                    } else if (chronique.type == ChroniqueType.VIDEO && _isVideoInitialized) {
                      _showFullScreenVideo();
                    } else {
                      _handleDoubleTap();
                    }
                  },
                  child: _buildChroniqueContent(chronique),
                );
              },
            ),
            _buildHeader(currentChronique),
            _buildProgressIndicator(),
            _buildUserProfile(currentChronique),
            _buildBottomBar(currentChronique),
            _buildLikeSection(),
            _buildHeartAnimation(),
            if (_isLoadingMore)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Chronique chronique) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    bool canDelete = authProvider.loginUserData.id == chronique.userId || authProvider.loginUserData.role == 'ADM';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent]),
        ),
        child: Row(
          children: [
            IconButton(icon: Icon(Icons.close, color: Colors.white, size: 24), onPressed: () => Navigator.pop(context)),
            Spacer(),
            IconButton(
              icon: Icon(Icons.add_circle, color: Color(0xFFFFD700), size: 22),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddChroniquePage())),
            ),
            if (canDelete) IconButton(icon: Icon(Icons.delete, color: Colors.red, size: 22), onPressed: () => _deleteChronique(chronique)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (_allChroniques.length <= 1) return SizedBox();
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Row(
        children: _allChroniques.map((chronique) {
          int index = _allChroniques.indexOf(chronique);
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

  Widget _buildUserProfile(Chronique chronique) {
    final likesCount = chronique.likeCount ?? 0;

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
              child: CircleAvatar(
                radius: 16,
                backgroundImage: CachedNetworkImageProvider(chronique.userImageUrl),
              ),
            ),
            SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showUserProfile(chronique.userId),
              child: Text('@${chronique.userPseudo}', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            if (_chroniqueOwner?.isVerify == true) ...[
              SizedBox(width: 4),
              Icon(Icons.verified, color: Colors.blue, size: 14),
            ],
            SizedBox(width: 12),
            _buildStatItem(Icons.favorite, '$likesCount', 14),
            SizedBox(width: 8),
            _buildStatItem(Icons.remove_red_eye, '${chronique.viewCount}', 14),
            SizedBox(width: 8),
            _buildStatItem(Icons.timer, _getTimeLeft(chronique.expiresAt), 14),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(Chronique currentChronique) {
    return Positioned(
      bottom: 15,
      left: 8,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton masquer/afficher à gauche
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _showMessages = !_showMessages),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_showMessages ? Icons.visibility_off : Icons.visibility, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(_showMessages ? 'Masquer' : 'Afficher', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Messages
          if (_showMessages)
            Container(
              height: 150,
              child: StreamBuilder<List<ChroniqueMessage>>(
                stream: Provider.of<ChroniqueProvider>(context).getChroniqueMessages(currentChronique.id!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return SizedBox();
                  return ListView.builder(
                    controller: _messageScrollController,
                    padding: EdgeInsets.all(4),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) => _buildMessageBubble(snapshot.data![index], currentChronique),
                  );
                },
              ),
            ),
          SizedBox(height: 8),
          // Champ de saisie
          Container(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLength: _maxMessageLength,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Message (max $_maxMessageLength)...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        counterText: '',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle),
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.black, size: 16),
                    onPressed: _sendMessage,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikeSection() {
    if (_allChroniques.isEmpty) return SizedBox();
    final currentChronique = _allChroniques[_currentPage];
    final likesCount = currentChronique.likeCount ?? 0;

    return Positioned(
      bottom: 70,
      right: 16,
      child: Column(
        children: [
          GestureDetector(
            onTap: _likeCurrentChronique,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
              child: Center(
                child: Icon(_hasLikedCurrent ? Icons.favorite : Icons.favorite_border, color: _hasLikedCurrent ? Colors.red : Colors.white, size: 28),
              ),
            ),
          ),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
            child: Text('$likesCount', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
              child: Transform.scale(scale: _heartScaleAnimation.value, child: Icon(Icons.favorite, color: Colors.red, size: 100)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String count, double iconSize) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: iconSize),
      SizedBox(width: 2),
      Text(count, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildChroniqueContent(Chronique chronique) {
    return Container(margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10), child: _buildMainContent(chronique));
  }

  Widget _buildMainContent(Chronique chronique) {
    switch (chronique.type) {
      case ChroniqueType.TEXT:
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(color: Color(int.parse(chronique.backgroundColor!, radix: 16)), borderRadius: BorderRadius.circular(15)),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(chronique.textContent!, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ),
          ),
        );

      case ChroniqueType.IMAGE:
        return ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: CachedNetworkImage(
            imageUrl: chronique.mediaUrl!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(color: Colors.grey[800], child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))),
          ),
        );

      case ChroniqueType.VIDEO:
        return ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              if (_videoController != null && _isVideoInitialized)
                AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!)),
              if (!_isVideoInitialized)
                Container(color: Colors.grey[800], child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))),
              Center(
                child: IconButton(
                  icon: Icon(_videoController?.value.isPlaying == true ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white.withOpacity(0.7), size: 50),
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
        );
    }
  }

  String _getTimeLeft(Timestamp expiresAt) {
    final difference = expiresAt.toDate().difference(DateTime.now());
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Expiré';
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
