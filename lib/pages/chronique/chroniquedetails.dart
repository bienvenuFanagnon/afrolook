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

class ChroniqueDetailPage extends StatefulWidget {
  final List<Chronique> userChroniques;

  const ChroniqueDetailPage({Key? key, required this.userChroniques}) : super(key: key);

  @override
  State<ChroniqueDetailPage> createState() => _ChroniqueDetailPageState();
}

class _ChroniqueDetailPageState extends State<ChroniqueDetailPage> {
  late PageController _pageController;
  int _currentPage = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _showMessages = true; // Par défaut affiché
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  UserData? _chroniqueOwner;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeCurrentMedia();
    _loadChroniqueOwner();
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
  }

  void _markAsViewed(Chronique chronique) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    if (!chronique.viewers.contains(authProvider.loginUserData.id!)) {
      chroniqueProvider.markAsViewed(chronique.id!, authProvider.loginUserData.id!);
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
    return GestureDetector(
      onLongPress: () => _deleteMessage(message, chronique),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1), // Couleur plus légère
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1), // Ombre plus légère
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
                        color: Color(0xFFFFD700),
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
      bottom: 70,
      left: 8,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bouton pour fermer/afficher les commentaires - TOUJOURS VISIBLE
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
            // Liste des commentaires (seulement quand _showMessages = true)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: _showMessages ? 250 : 0, // Augmenté à 250 (vous pouvez mettre plus si besoin)
              child: _showMessages ? StreamBuilder<List<ChroniqueMessage>>(
                stream: Provider.of<ChroniqueProvider>(context)
                    .getChroniqueMessages(currentChronique.id!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                   print(snapshot.error.toString());
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
    final totalReactions = currentChronique.likeCount + currentChronique.loveCount;

    return Positioned(
      bottom: 10,
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
            // Bouton like avec nombre superposé

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
            SizedBox(width: 6),

            Stack(
              children: [
                _buildReactionButton(),
                if (totalReactions > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$totalReactions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildReactionButton() {
    final currentChronique = widget.userChroniques[_currentPage];
    final authProvider = Provider.of<UserAuthProvider>(context);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context);

    return FutureBuilder<bool>(
      future: chroniqueProvider.hasLiked(currentChronique.id!, authProvider.loginUserData.id!),
      builder: (context, snapshot) {
        final hasLiked = snapshot.data ?? false;

        return GestureDetector(
          onTap: () => _toggleReaction(currentChronique, chroniqueProvider, authProvider, hasLiked),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.thumb_up,
              color: hasLiked ? Color(0xFFFFD700) : Colors.white,
              size: 18,
            ),
          ),
        );
      },
    );
  }
  Widget _buildNavigationButtons() {
    return Positioned(
      right: 8,
      top: MediaQuery.of(context).size.height / 2 - 20,
      child: Column(
        children: [
          if (_currentPage > 0)
            _buildNavButton(Icons.arrow_upward, () {
              _pageController.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }),
          SizedBox(height: 16),
          if (_currentPage < widget.userChroniques.length - 1)
            _buildNavButton(Icons.arrow_downward, () {
              _pageController.nextPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(color: Color(0xFFFFD700)),
        ),
        child: Icon(icon, color: Color(0xFFFFD700), size: 20),
      ),
    );
  }

  Widget _buildUserProfileWithStats(Chronique chronique) {
    return Positioned(
      top: 50,
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
            // Profil utilisateur
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
            // Pseudo
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
            // Stats (vues et chrono)
            _buildStatItem(Icons.remove_red_eye, '${chronique.viewCount}', 14),
            SizedBox(width: 8),
            _buildStatItem(Icons.timer, '${_getTimeLeft(chronique.expiresAt)}', 14),
            SizedBox(width: 8),
            _buildStatItem(Icons.thumb_up, '${chronique.likeCount + chronique.loveCount}', 14),
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
    final authProvider = Provider.of<UserAuthProvider>(context);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Contenu principal
            PageView.builder(
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

            // Header avec bouton suppression
            _buildHeader(currentChronique, authProvider),

            // Profil utilisateur avec stats
            _buildUserProfileWithStats(currentChronique),

            // Messages
            _buildMessagesPanel(currentChronique),

            // Input message avec like
            _buildMessageInput(),

            // Navigation
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Chronique chronique, UserAuthProvider authProvider) {
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

  void _toggleReaction(Chronique chronique, ChroniqueProvider provider, UserAuthProvider authProvider, bool hasLiked) async {
    if (hasLiked) {
      await provider.removeLike(chronique.id!, authProvider.loginUserData.id!);
    } else {
      await provider.addLike(chronique.id!, authProvider.loginUserData.id!);
      addPointsForAction(UserAction.like);
      addPointsForOtherUserAction(chronique.userId, UserAction.autre);

      await _sendNotification(
          authProvider,
          chronique,
          '👍 a aimé votre chronique',
          'LIKE'
      );
    }
    setState(() {});
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
    super.dispose();
  }
}

// class ChroniqueDetailPage extends StatefulWidget {
//   final List<Chronique> userChroniques;
//
//   const ChroniqueDetailPage({Key? key, required this.userChroniques}) : super(key: key);
//
//   @override
//   State<ChroniqueDetailPage> createState() => _ChroniqueDetailPageState();
// }
//
// class _ChroniqueDetailPageState extends State<ChroniqueDetailPage> {
//   late PageController _pageController;
//   int _currentPage = 0;
//   VideoPlayerController? _videoController;
//   bool _isVideoInitialized = false;
//   bool _showMessages = true;
//   bool _showDescriptionOverlay = false;
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _messageScrollController = ScrollController();
//   UserData? _chroniqueOwner;
//
//   @override
//   void initState() {
//     super.initState();
//     _pageController = PageController();
//     _initializeCurrentMedia();
//     _loadChroniqueOwner();
//   }
//
//   void _loadChroniqueOwner() async {
//     final currentChronique = widget.userChroniques[_currentPage];
//     final userDoc = await FirebaseFirestore.instance
//         .collection('Users')
//         .doc(currentChronique.userId)
//         .get();
//
//     if (userDoc.exists) {
//       setState(() {
//         _chroniqueOwner = UserData.fromJson(userDoc.data()!);
//       });
//     }
//   }
//
//   void _initializeCurrentMedia() async {
//     final currentChronique = widget.userChroniques[_currentPage];
//
//     if (currentChronique.type == ChroniqueType.VIDEO) {
//       _videoController?.dispose();
//       _videoController = VideoPlayerController.network(currentChronique.mediaUrl!)
//         ..initialize().then((_) {
//           setState(() {
//             _isVideoInitialized = true;
//           });
//           _videoController!.play();
//           _videoController!.setLooping(true);
//         });
//     } else {
//       _videoController?.dispose();
//       _videoController = null;
//       _isVideoInitialized = false;
//     }
//
//     _markAsViewed(currentChronique);
//   }
//
//   void _markAsViewed(Chronique chronique) {
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
//
//     if (!chronique.viewers.contains(authProvider.loginUserData.id!)) {
//       chroniqueProvider.markAsViewed(chronique.id!, authProvider.loginUserData.id!);
//     }
//   }
//
//   void _sendMessage() async {
//     if (_messageController.text.trim().isEmpty) return;
//
//     final currentChronique = widget.userChroniques[_currentPage];
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
//
//     try {
//       await chroniqueProvider.addMessage(
//         chroniqueId: currentChronique.id!,
//         userId: authProvider.loginUserData.id!,
//         userPseudo: authProvider.loginUserData.pseudo!,
//         userImageUrl: authProvider.loginUserData.imageUrl!,
//         message: _messageController.text.trim(),
//       );
//
//
//
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         _messageScrollController.animateTo(
//           _messageScrollController.position.maxScrollExtent,
//           duration: Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       });
//
//       // Envoyer notification au propriétaire
//       await _sendNotification(
//           authProvider,
//           currentChronique,
//           '💬 a commenté votre chronique: "${_messageController.text.trim()}"',
//           'COMMENT'
//       );
//       _messageController.clear();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text('Erreur: $e'),
//         ),
//       );
//     }
//   }
//
//   Future<void> _sendNotification(
//       UserAuthProvider authProvider,
//       Chronique chronique,
//       String message,
//       String type
//       ) async {
//     try {
//       // Récupérer le oneIgnalUserid du propriétaire
//       final ownerDoc = await FirebaseFirestore.instance
//           .collection('Users')
//           .doc(chronique.userId)
//           .get();
//
//       if (ownerDoc.exists) {
//         final ownerData = UserData.fromJson(ownerDoc.data()!);
//         if (ownerData.oneIgnalUserid != null && ownerData.oneIgnalUserid!.isNotEmpty) {
//           await authProvider.sendNotification(
//             appName: '@${authProvider.loginUserData.pseudo!}',
//             userIds: [ownerData.oneIgnalUserid!],
//             smallImage: authProvider.loginUserData.imageUrl!,
//             send_user_id: authProvider.loginUserData.id!,
//             recever_user_id: chronique.userId,
//             message: message,
//             type_notif: type,
//             post_id: chronique.id!,
//             post_type: 'CHRONIQUE',
//             chat_id: '',
//           );
//         }
//       }
//     } catch (e) {
//       print('Erreur envoi notification: $e');
//     }
//   }
//
//   void _deleteChronique(Chronique chronique) async {
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
//
//     bool canDelete = authProvider.loginUserData.id == chronique.userId ||
//         authProvider.loginUserData.role == 'ADM';
//
//     if (!canDelete) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text('Vous n\'avez pas la permission de supprimer cette chronique'),
//         ),
//       );
//       return;
//     }
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.black,
//         title: Text(
//           'Supprimer la chronique',
//           style: TextStyle(color: Color(0xFFFFD700)),
//         ),
//         content: Text(
//           'Êtes-vous sûr de vouloir supprimer cette chronique ?',
//           style: TextStyle(color: Colors.white),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Annuler', style: TextStyle(color: Colors.grey)),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               try {
//                 await chroniqueProvider.deleteChronique(
//                     chronique.id!,
//                     chronique.mediaUrl ?? ''
//                 );
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     backgroundColor: Colors.green,
//                     content: Text('Chronique supprimée avec succès'),
//                   ),
//                 );
//                 if (widget.userChroniques.length == 1) {
//                   Navigator.pop(context);
//                 } else {
//                   setState(() {});
//                 }
//               } catch (e) {
//                 print("'Erreur lors de la suppression: $e'");
//
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     backgroundColor: Colors.green,
//                     content: Text('Chronique supprimée avec succès'),
//                   ),
//                 );
//                 // ScaffoldMessenger.of(context).showSnackBar(
//                 //   SnackBar(
//                 //     backgroundColor: Colors.red,
//                 //     content: Text('Erreur lors de la suppression: $e'),
//                 //   ),
//                 // );
//               }
//             },
//             child: Text('Supprimer', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMessageBubble(ChroniqueMessage message) {
//     return Container(
//       margin: EdgeInsets.symmetric(vertical: 2, horizontal: 8),
//       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.7),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: Color(0xFFFFD700).withOpacity(0.5)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           GestureDetector(
//             onTap: () => _showUserProfile(message.userId),
//             child: CircleAvatar(
//               radius: 12,
//               backgroundImage: CachedNetworkImageProvider(message.userImageUrl),
//             ),
//           ),
//           SizedBox(width: 8),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 GestureDetector(
//                   onTap: () => _showUserProfile(message.userId),
//                   child: Text(
//                     message.userPseudo,
//                     style: TextStyle(
//                       color: Color(0xFFFFD700),
//                       fontSize: 10,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 2),
//                 Text(
//                   message.message,
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showUserProfile(String userId) async {
//     final userDoc = await FirebaseFirestore.instance
//         .collection('Users')
//         .doc(userId)
//         .get();
//
//     if (userDoc.exists) {
//       final user = UserData.fromJson(userDoc.data()!);
//       double w = MediaQuery.of(context).size.width;
//       double h = MediaQuery.of(context).size.height;
//
//       showUserDetailsModalDialog(user, w, h, context);
//       // showUserProfilModalDetailsModalDialog(user, w, h, context);
//     }
//   }
//
//   Widget _buildMessagesPanel(Chronique currentChronique) {
//     return Positioned(
//       bottom: 100,
//       left: 0,
//       right: 0,
//       child: AnimatedContainer(
//         duration: Duration(milliseconds: 300),
//         height: _showMessages ? 150 : 0,
//         child: _showMessages ? StreamBuilder<List<ChroniqueMessage>>(
//           stream: Provider.of<ChroniqueProvider>(context)
//               .getChroniqueMessages(currentChronique.id!),
//           builder: (context, snapshot) {
//             if (!snapshot.hasData) {
//               return SizedBox();
//             }
//
//             final messages = snapshot.data!;
//
//             return ListView.builder(
//               controller: _messageScrollController,
//               padding: EdgeInsets.all(8),
//               itemCount: messages.length,
//               itemBuilder: (context, index) {
//                 return _buildMessageBubble(messages[index]);
//               },
//             );
//           },
//         ) : SizedBox(),
//       ),
//     );
//   }
//
//   Widget _buildMessageInput() {
//     return Positioned(
//       bottom: 50,
//       left: 0,
//       right: 0,
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.bottomCenter,
//             end: Alignment.topCenter,
//             colors: [
//               Colors.black.withOpacity(0.9),
//               Colors.transparent,
//             ],
//           ),
//         ),
//         child: Row(
//           children: [
//             Expanded(
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.7),
//                   borderRadius: BorderRadius.circular(25),
//                   border: Border.all(color: Color(0xFFFFD700)),
//                 ),
//                 child: TextField(
//                   controller: _messageController,
//                   maxLength: 20,
//                   style: TextStyle(color: Colors.white, fontSize: 14),
//                   decoration: InputDecoration(
//                     hintText: 'Message (20 caractères max)...',
//                     hintStyle: TextStyle(color: Colors.grey),
//                     border: InputBorder.none,
//                     contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                     counterText: '',
//                   ),
//                   onSubmitted: (_) => _sendMessage(),
//                 ),
//               ),
//             ),
//             SizedBox(width: 8),
//             CircleAvatar(
//               backgroundColor: Color(0xFFFFD700),
//               child: IconButton(
//                 icon: Icon(Icons.send, color: Colors.black),
//                 onPressed: _sendMessage,
//               ),
//             ),
//             SizedBox(width: 8),
//             CircleAvatar(
//               backgroundColor: Colors.black.withOpacity(0.7),
//               child: IconButton(
//                 icon: Icon(
//                   _showMessages ? Icons.chat : Icons.chat_bubble_outline,
//                   color: Color(0xFFFFD700),
//                 ),
//                 onPressed: () {
//                   setState(() {
//                     _showMessages = !_showMessages;
//                   });
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildNavigationButtons() {
//     return Positioned(
//       right: 16,
//       top: MediaQuery.of(context).size.height / 2 - 50,
//       child: Column(
//         children: [
//           if (_currentPage > 0)
//             _buildNavButton(Icons.arrow_upward, 'Précédent', () {
//               _pageController.previousPage(
//                 duration: Duration(milliseconds: 300),
//                 curve: Curves.easeInOut,
//               );
//             }),
//           SizedBox(height: 20),
//           if (_currentPage < widget.userChroniques.length - 1)
//             _buildNavButton(Icons.arrow_downward, 'Suivant', () {
//               _pageController.nextPage(
//                 duration: Duration(milliseconds: 300),
//                 curve: Curves.easeInOut,
//               );
//             }),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildNavButton(IconData icon, String label, VoidCallback onTap) {
//     return Column(
//       children: [
//         GestureDetector(
//           onTap: onTap,
//           child: Container(
//             padding: EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.black.withOpacity(0.7),
//               shape: BoxShape.circle,
//               border: Border.all(color: Color(0xFFFFD700)),
//             ),
//             child: Icon(icon, color: Color(0xFFFFD700), size: 24),
//           ),
//         ),
//         SizedBox(height: 4),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 10,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildDescriptionOverlay(Chronique chronique) {
//     // Afficher seulement pour IMAGE et VIDEO avec description
//     if (chronique.type == ChroniqueType.TEXT ||
//         chronique.textContent == null ||
//         chronique.textContent!.isEmpty) {
//       return SizedBox();
//     }
//
//     return Positioned(
//       top: 80,
//       left: 16,
//       right: 16,
//       child: AnimatedOpacity(
//         opacity: _showDescriptionOverlay ? 1.0 : 0.7,
//         duration: Duration(milliseconds: 300),
//         child: GestureDetector(
//           onTap: () {
//             setState(() {
//               _showDescriptionOverlay = !_showDescriptionOverlay;
//             });
//           },
//           child: Container(
//             padding: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.black.withOpacity(_showDescriptionOverlay ? 0.9 : 0.6),
//               borderRadius: BorderRadius.circular(15),
//               border: Border.all(
//                 color: Color(0xFFFFD700),
//                 width: _showDescriptionOverlay ? 2 : 1,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.5),
//                   blurRadius: 10,
//                   offset: Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 if (_showDescriptionOverlay) ...[
//                   Row(
//                     children: [
//                       Icon(Icons.description, color: Color(0xFFFFD700), size: 16),
//                       SizedBox(width: 8),
//                       Text(
//                         'Description',
//                         style: TextStyle(
//                           color: Color(0xFFFFD700),
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Spacer(),
//                       GestureDetector(
//                         onTap: () {
//                           setState(() {
//                             _showDescriptionOverlay = false;
//                           });
//                         },
//                         child: Icon(Icons.close, color: Colors.white, size: 16),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 8),
//                 ],
//                 Text(
//                   chronique.textContent!,
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: _showDescriptionOverlay ? 14 : 12,
//                     fontWeight: _showDescriptionOverlay ? FontWeight.normal : FontWeight.w300,
//                   ),
//                   maxLines: _showDescriptionOverlay ? null : 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildUserProfileButton(Chronique chronique) {
//     return Positioned(
//       top: 80,
//       right: 16,
//       child: GestureDetector(
//         onTap: () => _showUserProfile(chronique.userId),
//         child: Container(
//           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: Colors.black.withOpacity(0.7),
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: Color(0xFFFFD700)),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               CircleAvatar(
//                 radius: 12,
//                 backgroundImage: CachedNetworkImageProvider(chronique.userImageUrl),
//               ),
//               SizedBox(width: 6),
//               Text(
//                 'Voir profil',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 10,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final currentChronique = widget.userChroniques[_currentPage];
//     final authProvider = Provider.of<UserAuthProvider>(context);
//     final chroniqueProvider = Provider.of<ChroniqueProvider>(context);
//
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Stack(
//           children: [
//             // Contenu principal
//             PageView.builder(
//               controller: _pageController,
//               itemCount: widget.userChroniques.length,
//               onPageChanged: (index) {
//                 setState(() {
//                   _currentPage = index;
//                   _showDescriptionOverlay = false;
//                 });
//                 _initializeCurrentMedia();
//                 _loadChroniqueOwner();
//               },
//               itemBuilder: (context, index) {
//                 final chronique = widget.userChroniques[index];
//                 return _buildChroniqueContent(chronique);
//               },
//             ),
//
//             // Header avec bouton suppression
//             _buildHeader(currentChronique, authProvider),
//
//             // Description overlay (uniquement pour IMAGE/VIDEO)
//             _buildDescriptionOverlay(currentChronique),
//
//             // Bouton profil utilisateur
//             _buildUserProfileButton(currentChronique),
//
//             // Messages
//             _buildMessagesPanel(currentChronique),
//
//             // Input message
//             _buildMessageInput(),
//
//             // Navigation
//             _buildNavigationButtons(),
//
//             // Footer avec stats
//             _buildFooter(currentChronique, authProvider, chroniqueProvider),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader(Chronique chronique, UserAuthProvider authProvider) {
//     bool canDelete = authProvider.loginUserData.id == chronique.userId ||
//         authProvider.loginUserData.role == 'ADM';
//
//     return Positioned(
//       top: 0,
//       left: 0,
//       right: 0,
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Colors.black.withOpacity(0.8),
//               Colors.transparent,
//             ],
//           ),
//         ),
//         child: Row(
//           children: [
//             GestureDetector(
//               onTap: () => _showUserProfile(chronique.userId),
//               child: CircleAvatar(
//                 radius: 20,
//                 backgroundImage: CachedNetworkImageProvider(chronique.userImageUrl),
//               ),
//             ),
//             SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   GestureDetector(
//                     onTap: () => _showUserProfile(chronique.userId),
//                     child: Text(
//                       chronique.userPseudo,
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   Text(
//                     _formatTime(chronique.createdAt),
//                     style: TextStyle(
//                       color: Colors.grey,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             if (canDelete)
//               IconButton(
//                 icon: Icon(Icons.delete, color: Colors.red),
//                 onPressed: () => _deleteChronique(chronique),
//               ),
//             IconButton(
//               icon: Icon(Icons.close, color: Colors.white),
//               onPressed: () => Navigator.pop(context),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildChroniqueContent(Chronique chronique) {
//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//       child: Stack(
//         children: [
//           _buildMainContent(chronique),
//           if (chronique.type == ChroniqueType.VIDEO && _videoController != null)
//             Positioned(
//               top: 20,
//               left: 20,
//               right: 20,
//               child: _buildVideoProgressIndicator(),
//             ),
//           Positioned(
//             bottom: 20,
//             left: 0,
//             right: 0,
//             child: _buildPageIndicator(),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMainContent(Chronique chronique) {
//     switch (chronique.type) {
//       case ChroniqueType.TEXT:
//         return Container(
//           width: double.infinity,
//           height: double.infinity,
//           decoration: BoxDecoration(
//             color: Color(int.parse(chronique.backgroundColor!, radix: 16)),
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: Center(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Text(
//                 chronique.textContent!,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 28,
//                   fontWeight: FontWeight.w600,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),
//         );
//
//       case ChroniqueType.IMAGE:
//         return ClipRRect(
//           borderRadius: BorderRadius.circular(20),
//           child: CachedNetworkImage(
//             imageUrl: chronique.mediaUrl!,
//             fit: BoxFit.cover,
//             width: double.infinity,
//             height: double.infinity,
//             placeholder: (context, url) => Container(
//               color: Colors.grey[800],
//               child: Center(
//                 child: CircularProgressIndicator(color: Color(0xFFFFD700)),
//               ),
//             ),
//           ),
//         );
//
//       case ChroniqueType.VIDEO:
//         return ClipRRect(
//           borderRadius: BorderRadius.circular(20),
//           child: Stack(
//             children: [
//               if (_videoController != null && _isVideoInitialized)
//                 VideoPlayer(_videoController!),
//               if (!_isVideoInitialized)
//                 Container(
//                   color: Colors.grey[800],
//                   child: Center(
//                     child: CircularProgressIndicator(color: Color(0xFFFFD700)),
//                   ),
//                 ),
//               Center(
//                 child: IconButton(
//                   icon: Icon(
//                     _videoController?.value.isPlaying == true
//                         ? Icons.pause_circle_filled
//                         : Icons.play_circle_filled,
//                     color: Colors.white.withOpacity(0.7),
//                     size: 60,
//                   ),
//                   onPressed: () {
//                     if (_videoController?.value.isPlaying == true) {
//                       _videoController?.pause();
//                     } else {
//                       _videoController?.play();
//                     }
//                     setState(() {});
//                   },
//                 ),
//               ),
//             ],
//           ),
//         );
//     }
//   }
//
//   Widget _buildVideoProgressIndicator() {
//     return StreamBuilder(
//       stream: _videoController?.position.asStream(),
//       builder: (context, snapshot) {
//         final position = snapshot.data ?? Duration.zero;
//         final duration = _videoController?.value.duration ?? Duration.zero;
//
//         if (duration.inSeconds == 0) return SizedBox();
//
//         return LinearProgressIndicator(
//           value: position.inSeconds / duration.inSeconds,
//           backgroundColor: Colors.grey.withOpacity(0.3),
//           color: Color(0xFFFFD700),
//         );
//       },
//     );
//   }
//
//   Widget _buildPageIndicator() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: List.generate(widget.userChroniques.length, (index) {
//         return Container(
//           width: 8,
//           height: 8,
//           margin: EdgeInsets.symmetric(horizontal: 4),
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: _currentPage == index
//                 ? Color(0xFFFFD700)
//                 : Colors.grey.withOpacity(0.5),
//           ),
//         );
//       }),
//     );
//   }
//
//   Widget _buildFooter(Chronique chronique, UserAuthProvider authProvider, ChroniqueProvider chroniqueProvider) {
//     return Positioned(
//       bottom: 0,
//       left: 0,
//       right: 0,
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.bottomCenter,
//             end: Alignment.topCenter,
//             colors: [
//               Colors.black.withOpacity(0.9),
//               Colors.transparent,
//             ],
//           ),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             _buildStatItem(
//               Icons.remove_red_eye,
//               '${chronique.viewCount}',
//               Colors.white,
//             ),
//             _buildReactionButton(
//               Icons.thumb_up,
//               '${chronique.likeCount}',
//               chroniqueProvider.hasLiked(chronique.id!, authProvider.loginUserData.id!),
//                   () => _toggleLike(chronique, chroniqueProvider, authProvider),
//             ),
//             _buildReactionButton(
//               Icons.favorite,
//               '${chronique.loveCount}',
//               chroniqueProvider.hasLoved(chronique.id!, authProvider.loginUserData.id!),
//                   () => _toggleLove(chronique, chroniqueProvider, authProvider),
//             ),
//             _buildStatItem(
//               Icons.timer,
//               '${_getTimeLeft(chronique.expiresAt)}',
//               Color(0xFFFFD700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildStatItem(IconData icon, String count, Color color) {
//     return Column(
//       children: [
//         Icon(icon, color: color, size: 20),
//         SizedBox(height: 4),
//         Text(
//           count,
//           style: TextStyle(
//             color: color,
//             fontSize: 12,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildReactionButton(
//       IconData icon,
//       String count,
//       Future<bool> isActive,
//       VoidCallback onTap,
//       ) {
//     return FutureBuilder<bool>(
//       future: isActive,
//       builder: (context, snapshot) {
//         final active = snapshot.data ?? false;
//         return GestureDetector(
//           onTap: onTap,
//           child: Column(
//             children: [
//               Icon(
//                 icon,
//                 color: active ? Color(0xFFFFD700) : Colors.white,
//                 size: 24,
//               ),
//               SizedBox(height: 4),
//               Text(
//                 count,
//                 style: TextStyle(
//                   color: active ? Color(0xFFFFD700) : Colors.white,
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   void _toggleLike(Chronique chronique, ChroniqueProvider provider, UserAuthProvider authProvider) async {
//     final hasLiked = await provider.hasLiked(chronique.id!, authProvider.loginUserData.id!);
//
//     if (hasLiked) {
//       await provider.removeLike(chronique.id!, authProvider.loginUserData.id!);
//     } else {
//       await provider.addLike(chronique.id!, authProvider.loginUserData.id!);
//       // Envoyer notification
//       await _sendNotification(
//           authProvider,
//           chronique,
//           '👍 a aimé votre chronique',
//           'LIKE'
//       );
//     }
//     setState(() {});
//   }
//
//   void _toggleLove(Chronique chronique, ChroniqueProvider provider, UserAuthProvider authProvider) async {
//     final hasLoved = await provider.hasLoved(chronique.id!, authProvider.loginUserData.id!);
//
//     if (hasLoved) {
//       await provider.removeLove(chronique.id!, authProvider.loginUserData.id!);
//     } else {
//       await provider.addLove(chronique.id!, authProvider.loginUserData.id!);
//       // Envoyer notification
//       await _sendNotification(
//           authProvider,
//           chronique,
//           '❤️ a adoré votre chronique',
//           'LOVE'
//       );
//     }
//     setState(() {});
//   }
//
//   String _formatTime(Timestamp timestamp) {
//     final now = DateTime.now();
//     final time = timestamp.toDate();
//     final difference = now.difference(time);
//
//     if (difference.inMinutes < 1) return 'À l\'instant';
//     if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
//     if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
//     return 'Il y a ${difference.inDays} j';
//   }
//
//   String _getTimeLeft(Timestamp expiresAt) {
//     final now = DateTime.now();
//     final expireTime = expiresAt.toDate();
//     final difference = expireTime.difference(now);
//
//     if (difference.inHours > 0) {
//       return '${difference.inHours}h';
//     } else if (difference.inMinutes > 0) {
//       return '${difference.inMinutes}min';
//     } else {
//       return 'Expiré';
//     }
//   }
//
//   @override
//   void dispose() {
//     _pageController.dispose();
//     _videoController?.dispose();
//     _messageController.dispose();
//     _messageScrollController.dispose();
//     super.dispose();
//   }
// }

// Fonction pour afficher le profil utilisateur (doit exister dans votre code)
