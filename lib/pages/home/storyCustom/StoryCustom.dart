import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../story/afroStory/repository.dart';
import '../../story/afroStory/story2/storyComment.dart';

// enum MediaType { image, video, text }

// class WhatsappStory {
//   MediaType? mediaType;
//   final String? media;
//   final double? duration;
//   final String? caption;
//   final String? when;
//   final String? color;
//   final int? nbrComment;
//   final List<String>? vues;
//   final int? nbrVues;
//   final int? nbrJaimes;
//   final List<String>? jaimes;
//   final int? createdAt;
//   final int? updatedAt;
//
//   WhatsappStory({
//     this.mediaType,
//     this.media,
//     this.duration,
//     this.caption,
//     this.when,
//     this.color,
//     this.nbrVues = 0,
//     this.nbrComment = 0,
//     this.vues,
//     this.nbrJaimes = 0,
//     this.jaimes,
//     this.createdAt,
//     this.updatedAt,
//   });
//
//   Map<String, dynamic> toJson() {
//     return {
//       'mediaType': mediaType?.name,
//       'media': media,
//       'duration': duration,
//       'caption': caption,
//       'when': when,
//       'color': color,
//       'nbrVues': nbrVues,
//       'nbrComment': nbrComment,
//       'vues': vues,
//       'nbrJaimes': nbrJaimes,
//       'jaimes': jaimes,
//       'createdAt': createdAt,
//       'updatedAt': updatedAt,
//     };
//   }
//
//   WhatsappStory.fromJson(Map<String, dynamic> json)
//       : mediaType = MediaType.values.firstWhere(
//         (e) => e.name == json['mediaType'],
//     orElse: () => MediaType.image,
//   ),
//         media = json['media'],
//         duration = json['duration']?.toDouble(),
//         caption = json['caption'],
//         when = json['when'],
//         color = json['color'],
//         nbrVues = json['nbrVues'] ?? 0,
//         nbrComment = json['nbrComment'] ?? 0,
//         vues = json['vues'] != null ? List<String>.from(json['vues']) : [],
//         nbrJaimes = json['nbrJaimes'] ?? 0,
//         jaimes = json['jaimes'] != null ? List<String>.from(json['jaimes']) : [],
//         createdAt = json['createdAt'],
//         updatedAt = json['updatedAt'];
// }
//
// class UserData {
//   final String id;
//   final String name;
//   final String imageUrl;
//   final int followers;
//   final bool isVerified;
//   final List<WhatsappStory> stories;
//
//   UserData({
//     required this.id,
//     required this.name,
//     required this.imageUrl,
//     required this.followers,
//     required this.isVerified,
//     required this.stories,
//   });
//
//   factory UserData.fromJson(Map<String, dynamic> json) {
//     return UserData(
//       id: json['id'] ?? '',
//       name: json['pseudo'] ?? json['nom'] ?? 'Utilisateur',
//       imageUrl: json['imageUrl'] ?? '',
//       followers: json['abonnes'] ?? 0,
//       isVerified: json['isVerify'] ?? false,
//       stories: json['stories'] != null
//           ? (json['stories'] as List).map((story) => WhatsappStory.fromJson(story)).toList()
//           : [],
//     );
//   }
// }



// Widget StoryPreview (à inclure dans votre fichier)
class StoryPreviewCustom extends StatelessWidget {
  final UserData user;
  final double h;
  final double w;

  const StoryPreviewCustom({
    Key? key,
    required this.user,
    required this.h,
    required this.w,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final hasUnviewedStories = user.stories?.any((story) =>
    !(story.vues?.contains(authProvider.loginUserData.id) ?? false)) ?? false;

    final firstStory = user.stories != null && user.stories!.isNotEmpty
        ? user.stories!.last
        : null;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StoryViewer(
              users: [user],
              initialUserIndex: 0,
              initialStoryIndex: 0,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          // Fond de la story
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: firstStory?.mediaType == MediaType.text
                  ? (firstStory?.color != null
                  ? Color(int.parse(firstStory!.color!, radix: 16))
                  : Colors.grey)
                  : null,
            ),
            child: firstStory != null
                ? firstStory.mediaType == MediaType.text
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  firstStory.caption ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
                : CachedNetworkImage(
              imageUrl: firstStory.media!,
              fit: BoxFit.cover,
              width: w,
              height: h,
              placeholder: (context, url) =>
                  Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) =>
                  Icon(Icons.person, color: Colors.white),
            )
                : Icon(Icons.person, color: Colors.white, size: 30),
          ),

          // Indicateur de nouvelles stories
          if (hasUnviewedStories)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),

          // Nom de l'utilisateur
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Text(
                '@${user.pseudo ?? user.nom ?? 'Utilisateur'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class StoryViewer extends StatefulWidget {
  final List<UserData> users;
  final int initialUserIndex;
  final int initialStoryIndex;

  const StoryViewer({
    Key? key,
    required this.users,
    this.initialUserIndex = 0,
    this.initialStoryIndex = 0,
  }) : super(key: key);

  @override
  _StoryViewerState createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late PageController _userPageController;
  late PageController _storyPageController;
  late AnimationController _animationController;
  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  VideoPlayerController? _videoController;
  bool _isPaused = false;
  bool _isLoading = true;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex;
    _currentStoryIndex = widget.initialStoryIndex;

    _userPageController = PageController(initialPage: widget.initialUserIndex);
    _storyPageController = PageController(initialPage: widget.initialStoryIndex);

    _initializeAnimationController();
  }

  void _initializeAnimationController() {
    final currentStory = _getCurrentStory();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (currentStory.duration?? 50000).toInt()),
    );

    // _animationController.addStatusListener((status) {
    //   if (status == AnimationStatus.completed) {
    //     _nextStory();
    //   }
    // });

    _loadStory();
  }

  void _loadStory() async {
    setState(() {
      _isLoading = true;
    });

    // Dispose previous video controller if exists
    if (_videoController != null) {
      _videoController!.dispose();
      _videoController = null;
    }

    _animationController.stop();
    _animationController.reset();

    final story = _getCurrentStory();

    if (story.mediaType == MediaType.video && story.media != null) {
      try {
        _videoController = VideoPlayerController.network(story.media!);
        await _videoController!.initialize();

        setState(() {
          _isLoading = false;
        });

        _videoController!.play();
        _animationController.duration = _videoController!.value.duration;

        if (!_isPaused) {
          _animationController.forward();
        }
      } catch (e) {
        print("Error loading video: $e");
        setState(() {
          _isLoading = false;
        });
        // If video fails, proceed after default duration
        Future.delayed(Duration(milliseconds: (story.duration ?? 5000).toInt()), () {
          if (mounted) _nextStory();
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      _animationController.duration = Duration(
        milliseconds: (story.duration ?? 5000).toInt(),
      );
      if (!_isPaused) {
        _animationController.forward();
      }
    }
  }

  WhatsappStory _getCurrentStory() {
    if (widget.users[_currentUserIndex].stories == null ||
        widget.users[_currentUserIndex].stories!.isEmpty) {
      return WhatsappStory(
        mediaType: MediaType.text!,
        caption: 'No story available',
        duration: 3000,
      );
    }
    return widget.users[_currentUserIndex].stories![_currentStoryIndex];
  }

  UserData _getCurrentUser() {
    return widget.users[_currentUserIndex];
  }

  void _nextStory() {
    final currentUser = _getCurrentUser();
    if (_currentStoryIndex < currentUser.stories!.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _storyPageController.animateToPage(
        _currentStoryIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) => _loadStory());
    } else {
      _nextUser();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _storyPageController.animateToPage(
        _currentStoryIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) => _loadStory());
    } else {
      _previousUser();
    }
  }

  void _nextUser() {
    if (_currentUserIndex < widget.users.length - 1) {
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
      });
      _userPageController.animateToPage(
        _currentUserIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) => _loadStory());
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousUser() {
    if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        final previousUserStories = widget.users[_currentUserIndex].stories;
        _currentStoryIndex = previousUserStories != null && previousUserStories.isNotEmpty
            ? previousUserStories.length - 1
            : 0;
      });
      _userPageController.animateToPage(
        _currentUserIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) => _loadStory());
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onTapDown(TapDownDetails details) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dx = details.globalPosition.dx;

    if (dx < screenWidth / 3) {
      _previousStory();
    } else {
      _nextStory();
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() {
      _isPaused = true;
      _animationController.stop();
      if (_getCurrentStory().mediaType == MediaType.video && _videoController != null) {
        _videoController!.pause();
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _isPaused = false;
      _animationController.forward();
      if (_getCurrentStory().mediaType == MediaType.video && _videoController != null) {
        _videoController!.play();
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _animationController.stop();
        if (_getCurrentStory().mediaType == MediaType.video && _videoController != null) {
          _videoController!.pause();
        }
      } else {
        _animationController.forward();
        if (_getCurrentStory().mediaType == MediaType.video && _videoController != null) {
          _videoController!.play();
        }
      }
    });
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StoryComments(story: _getCurrentStory(), userStory: _getCurrentUser(),)

      // builder: (context) => CommentModal(
      //   story: _getCurrentStory(),
      //   user: _getCurrentUser(),
      // ),
    );
  }

  @override
  void dispose() {
    _userPageController.dispose();
    _storyPageController.dispose();
    _animationController.dispose();
    if (_videoController != null) {
      _videoController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _getCurrentUser();
    final currentStory = _getCurrentStory();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Conteneur principal avec le contenu de la story
          GestureDetector(
            onTapDown: _onTapDown,
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            child: AbsorbPointer(
              child: PageView.builder(
                controller: _userPageController,
                physics: NeverScrollableScrollPhysics(),
                itemCount: widget.users.length,
                itemBuilder: (context, userIndex) {
                  final user = widget.users[userIndex];
                  return PageView.builder(
                    controller: _storyPageController,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: user.stories?.length ?? 0,
                    itemBuilder: (context, storyIndex) {
                      final story = user.stories![storyIndex];
                      return _StoryContent(
                        story: story,
                        videoController: storyIndex == _currentStoryIndex && userIndex == _currentUserIndex
                            ? _videoController
                            : null,
                        isLoading: _isLoading,
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Barre de progression
          _ProgressBars(
            users: widget.users,
            currentUserIndex: _currentUserIndex,
            currentStoryIndex: _currentStoryIndex,
            animationController: _animationController,
          ),

          // En-tête avec infos utilisateur
          _Header(user: currentUser),

          // Bouton de pause
          if (!_isLoading)
            Positioned(
              top: 100,
              right: 20,
              child: IconButton(
                icon: Icon(
                  _isPaused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _togglePause,
              ),
            ),

          // Pied de page avec interactions
          if (!_isLoading)
            _Footer(
              story: currentStory,
              user: currentUser,          // Ajouter l'utilisateur propriétaire
              currentUserId: authProvider.loginUserData.id!, // Remplace par l'ID de l'utilisateur qui regarde
              onCommentPressed: _openComments,
            ),

          // Indicateur de chargement
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryContent extends StatelessWidget {
  final WhatsappStory story;
  final VideoPlayerController? videoController;
  final bool isLoading;

  const _StoryContent({
    required this.story,
    this.videoController,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(color: Colors.black);
    }

    if (story.mediaType == MediaType.video && videoController != null && videoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: videoController!.value.aspectRatio,
        child: VideoPlayer(videoController!),
      );
    } else if (story.mediaType == MediaType.image) {
      return CachedNetworkImage(
        imageUrl: story.media ?? 'https://cdn.pixabay.com/photo/2019/05/14/21/50/storytelling-4203628_1280.jpg',
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.white),
      );
    } else {
      // Story texte
      return Container(
        color: story.color != null
            ? Color(int.parse(
          story.color!.replaceFirst('#', ''),
          radix: 16,
        )).withOpacity(1.0) // si tu veux forcer l'opacité
            : Colors.grey[900],

        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              story.caption ?? 'No caption',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }
}

class _ProgressBars extends StatelessWidget {
  final List<UserData> users;
  final int currentUserIndex;
  final int currentStoryIndex;
  final AnimationController animationController;

  const _ProgressBars({
    required this.users,
    required this.currentUserIndex,
    required this.currentStoryIndex,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = users[currentUserIndex];
    final stories = currentUser.stories ?? [];

    return Positioned(
      top: 40,
      left: 10,
      right: 10,
      child: Column(
        children: [
          // Barres de progression pour l'utilisateur actuel
          if (stories.isNotEmpty)
            Row(
              children: List.generate(stories.length, (index) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Stack(
                      children: [
                        if (index < currentStoryIndex)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        if (index == currentStoryIndex)
                          AnimatedBuilder(
                            animation: animationController,
                            builder: (context, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                width: MediaQuery.of(context).size.width *
                                    animationController.value /
                                    stories.length,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          SizedBox(height: 10),
          // Indicateur d'utilisateurs (optionnel)
          if (users.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(users.length, (index) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == currentUserIndex ? Colors.white : Colors.white54,
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserData user;

  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 10,
      right: 10,
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(user.imageUrl ?? ''),
            radius: 20,
            child: user.imageUrl == null ? Icon(Icons.person, color: Colors.white) : null,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.pseudo ?? user.nom ?? 'Utilisateur',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(width: 5),
                    if (user.isVerify ?? false)
                      Icon(Icons.verified, color: Colors.blue, size: 16),
                  ],
                ),
                Text(
                  '${user.userAbonnesIds?.length ?? 0} abonnés',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatefulWidget {
  final WhatsappStory story;
  final UserData user; // L'utilisateur propriétaire de la story
  final VoidCallback onCommentPressed;
  final String currentUserId; // ID de l'utilisateur qui regarde

  const _Footer({
    required this.story,
    required this.user,
    required this.currentUserId,
    required this.onCommentPressed,
  });

  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  Future<void> _incrementViews() async {
    if (!widget.story.vues!.contains(widget.currentUserId)) {
      setState(() {
        widget.story.vues = List<String>.from(widget.story.vues ?? []);
        if (!widget.story.vues!.contains(widget.currentUserId)) {
          widget.story.vues!.add(widget.currentUserId);
          widget.story.nbrVues = widget.story.vues!.length;
          widget.story.updatedAt = DateTime.now().millisecondsSinceEpoch;
        }
      });


      try {
        final userDocRef = FirebaseFirestore.instance
            .collection('Users')
            .doc(widget.user.id);

        final userSnapshot = await userDocRef.get();
        if (!userSnapshot.exists) return;

        final userData = userSnapshot.data()!;
        final stories = List<Map<String, dynamic>>.from(userData['stories'] ?? []);

        // Cherche la story correspondante
        for (var s in stories) {
          if ((widget.story.mediaType == MediaType.text && s['caption'] == widget.story.caption) ||
              (widget.story.mediaType != MediaType.text && s['media'] == widget.story.media)) {
            s['vues'] = widget.story.vues ?? [];
            s['nbrVues'] = widget.story.nbrVues ?? 0;
            s['updatedAt'] = widget.story.updatedAt;
            break;
          }
        }

        // Met à jour la liste complète des stories
        await userDocRef.update({'stories': stories});
        printVm("Story vues mise à jour !");
      } catch (e) {
        printVm("Erreur lors de la mise à jour des vues : $e");
      }
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      if (widget.story.jaimes!.contains(widget.currentUserId)) {
        widget.story.jaimes!.remove(widget.currentUserId);
      } else {
        widget.story.jaimes!.add(widget.currentUserId);
      }
      widget.story.nbrJaimes = widget.story.jaimes!.length;
      widget.story.updatedAt = DateTime.now().millisecondsSinceEpoch;
    });

    try {
      final userDocRef = FirebaseFirestore.instance.collection('Users').doc(widget.user.id);
      final userSnapshot = await userDocRef.get();

      if (!userSnapshot.exists) return;

      final userData = userSnapshot.data()!;
      final stories = List<Map<String, dynamic>>.from(userData['stories'] ?? []);

      for (var s in stories) {
        if ((widget.story.mediaType == MediaType.text && s['caption'] == widget.story.caption) ||
            (widget.story.mediaType != MediaType.text && s['media'] == widget.story.media)) {
          s['jaimes'] = widget.story.jaimes ?? [];
          s['nbrJaimes'] = widget.story.nbrJaimes ?? 0;
          s['updatedAt'] = widget.story.updatedAt;
          break;
        }
      }

      await userDocRef.update({'stories': stories});
      printVm("Story like mise à jour !");
    } catch (e) {
      printVm("Erreur lors de la mise à jour du like : $e");
    }
  }
@override
  void initState() {
    // TODO: implement initState
    super.initState();

}
  @override
  Widget build(BuildContext context) {
    // On incrémente la vue dès que le footer est construit (donc story affichée)
    _incrementViews();

    return Positioned(
      bottom: 20,
      left: 10,
      right: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.story.caption != null && widget.story.mediaType != MediaType.text)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(
                widget.story.caption!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInteractionButton(
                  Icons.favorite,
                  '${widget.story.nbrJaimes ?? 0}',
                  onPressed: _toggleLike),
              _buildInteractionButton(
                  Icons.remove_red_eye, '${widget.story.nbrVues ?? 0}'),
              _buildInteractionButton(Icons.comment, '${widget.story.nbrComment ?? 0}',
                  onPressed: widget.onCommentPressed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton(IconData icon, String text,
      {VoidCallback? onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Icon(icon, color: Colors.white),
          if (text.isNotEmpty && text != '0')
            Text(
              text,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class CommentModal extends StatelessWidget {
  final WhatsappStory story;
  final UserData user;

  const CommentModal({
    Key? key,
    required this.story,
    required this.user,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // En-tête du modal
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(user.imageUrl ?? ''),
                      radius: 20,
                      child: user.imageUrl == null ? Icon(Icons.person) : null,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.pseudo ?? 'Utilisateur',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${story.nbrComment ?? 0} commentaires',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Liste des commentaires
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: story.nbrComment ?? 0,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          'https://picsum.photos/200?random=$index',
                        ),
                      ),
                      title: Text('Utilisateur ${index + 1}'),
                      subtitle: Text('Commentaire exemple ${index + 1}'),
                      trailing: Text('${index + 1}h', style: TextStyle(color: Colors.grey)),
                    );
                  },
                ),
              ),

              // Champ de saisie de commentaire
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Ajouter un commentaire...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.blue),
                      onPressed: () {
                        // Envoyer le commentaire
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}