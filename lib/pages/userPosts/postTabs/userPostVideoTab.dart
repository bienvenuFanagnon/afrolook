import 'dart:async';
import 'dart:io';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../services/postService/massNotificationService.dart';



class UserPubVideo extends StatefulWidget {
  final Canal? canal;
  const UserPubVideo({super.key, required this.canal});

  @override
  State<UserPubVideo> createState() => _UserPubVideoState();
}

class _UserPubVideoState extends State<UserPubVideo> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();

  bool onTap = false;
  double _uploadProgress = 0;
  late XFile videoFile;
  bool isVideo = false;

  VideoPlayerController? _controller;

  final ImagePicker picker = ImagePicker();

  // Variables pour le type de post
  String? _selectedPostType;
  String? _selectedPostTypeLibeller;

  // Contrôle de temps entre les posts
  bool _canPost = true;
  String _timeRemaining = '';

  // Map des types de post avec code et libellé
  final Map<String, Map<String, dynamic>> _postTypes = {
    'LOOKS': {'label': '👗 Looks', 'icon': Icons.style},
    'ACTUALITES': {'label': '📰 Actualités', 'icon': Icons.article},
    'SPORT': {'label': '⚽ Sport', 'icon': Icons.sports},
    'EVENEMENT': {'label': '🎉 Événement', 'icon': Icons.event},
    'OFFRES': {'label': '🏷️ Offres', 'icon': Icons.local_offer},
    'GAMER': {'label': '🎮 Games story', 'icon': Icons.gamepad},
  };

  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Couleurs personnalisées
  final Color _primaryColor = Color(0xFFE21221); // Rouge
  final Color _secondaryColor = Color(0xFFFFD600); // Jaune
  final Color _backgroundColor = Color(0xFF121212); // Noir
  final Color _cardColor = Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;
  late MassNotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    _notificationService = MassNotificationService();

    _checkPostCooldown();
  }

  @override
  void dispose() {
    super.dispose();
    if (_controller != null) {
      _controller!.pause();
      _controller!.dispose();
    }
  }

  Future<void> _checkPostCooldown() async {
    if (authProvider.loginUserData.role == UserRole.ADM.name) {
      setState(() {
        _canPost = true;
      });
      return;
    }

    try {
      final userPosts = await firestore
          .collection('Posts')
          .where('user_id', isEqualTo: authProvider.loginUserData.id)
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      if (userPosts.docs.isNotEmpty) {
        final lastPost = userPosts.docs.first;
        final lastPostTime = lastPost['created_at'] as int;
        final now = DateTime.now().microsecondsSinceEpoch;
        final oneHourInMicroseconds = 60 * 60 * 1000000;

        final timeSinceLastPost = now - lastPostTime;

        if (timeSinceLastPost < oneHourInMicroseconds) {
          final remainingTime = oneHourInMicroseconds - timeSinceLastPost;
          _startCooldownTimer(remainingTime);
        } else {
          setState(() {
            _canPost = true;
          });
        }
      } else {
        setState(() {
          _canPost = true;
        });
      }
    } catch (e) {
      print("Erreur vérification cooldown: $e");
      setState(() {
        _canPost = true;
      });
    }
  }

  void _startCooldownTimer(int remainingMicroseconds) {
    setState(() {
      _canPost = false;
    });

    _updateTimeRemaining(remainingMicroseconds);

    Timer.periodic(Duration(seconds: 1), (timer) {
      remainingMicroseconds -= 1000000;

      if (remainingMicroseconds <= 0) {
        timer.cancel();
        setState(() {
          _canPost = true;
          _timeRemaining = '';
        });
      } else {
        _updateTimeRemaining(remainingMicroseconds);
      }
    });
  }

  void _updateTimeRemaining(int microseconds) {
    final seconds = microseconds ~/ 1000000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    setState(() {
      _timeRemaining = '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _getVideo() async {
    await picker.pickVideo(source: ImageSource.gallery).then((video) async {
      if (video == null) return;

      late VideoPlayerController controller;

      if (kIsWeb) {
        controller = VideoPlayerController.networkUrl(Uri.parse(video.path));
        videoFile = video;
        _controller = controller;
      } else {
        videoFile = video;
        controller = VideoPlayerController.file(File(video.path));
        _controller = controller;
      }

      const double volume = kIsWeb ? 0.0 : 1.0;
      await controller.setVolume(volume);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      setState(() {});
    });
  }

  Widget _buildCooldownAlert() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _secondaryColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: _secondaryColor, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temps d\'attente',
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Prochain post dans: $_timeRemaining',
                  style: TextStyle(
                    color: _hintColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _secondaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _timeRemaining,
              style: TextStyle(
                color: _secondaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostTypeSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Type de publication',
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              hintText: 'Choisir un type de publication',
              hintStyle: TextStyle(color: _hintColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor),
              ),
              filled: true,
              fillColor: _backgroundColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            dropdownColor: _cardColor,
            style: TextStyle(color: _textColor, fontSize: 14),
            value: _selectedPostType,
            onChanged: (String? newValue) {
              setState(() {
                _selectedPostType = newValue;
                _selectedPostTypeLibeller = _postTypes[_selectedPostType]?['label'];
              });
            },
            items: _postTypes.entries.map<DropdownMenuItem<String>>((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    Icon(_postTypes[entry.key]!['icon'] as IconData,
                        color: _primaryColor, size: 18),
                    SizedBox(width: 12),
                    Text(
                      _postTypes[entry.key]!['label'],
                      style: TextStyle(color: _textColor),
                    ),
                  ],
                ),
              );
            }).toList(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez sélectionner un type de post';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Future<void> _publishVideo() async {
    if (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez attendre $_timeRemaining avant de poster à nouveau',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (_controller == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Veuillez choisir une vidéo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
        return;
      }

      try {
        setState(() {
          onTap = true;
          _uploadProgress = 0;
        });

        // 🔥 AFFICHER UN INDICATEUR DE PROGRESSION AMÉLIORÉ
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: _cardColor,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Publication en cours...',
                    style: TextStyle(color: _textColor),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Téléchargement de la vidéo et notification des abonnés',
                    style: TextStyle(
                      color: _hintColor,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );

        Duration videoDuration = _controller!.value.duration;
        int size = await videoFile.length();

        // Vérification de la durée
        if (videoDuration.inSeconds > 60 * 5) {
          Navigator.pop(context); // Fermer le dialog
          setState(() {
            onTap = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'La durée de la vidéo dépasse 5 min !',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
          return;
        }

        // Vérification de la taille
        if (size > 20971520) {
          Navigator.pop(context); // Fermer le dialog
          setState(() {
            onTap = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'La vidéo est trop grande (plus de 20 Mo).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
          return;
        }

        String postId = FirebaseFirestore.instance.collection('Posts').doc().id;

        Post post = Post();
        post.user_id = authProvider.loginUserData.id;
        post.description = _descriptionController.text;
        post.updatedAt = DateTime.now().microsecondsSinceEpoch;
        post.createdAt = DateTime.now().microsecondsSinceEpoch;
        post.status = PostStatus.VALIDE.name;
        post.type = PostType.POST.name;
        post.dataType = PostDataType.VIDEO.name;
        post.typeTabbar = _selectedPostType;
        post.comments = 0;
        post.likes = 0;
        post.feedScore = 0.0;
        post.loves = 0;
        post.id = postId;
        post.images = [];

        if (widget.canal != null) {
          post.canal_id = widget.canal!.id;
          post.categorie = "CANAL";
        }

        // Upload de la vidéo
        Reference storageReference = FirebaseStorage.instance
            .ref()
            .child('post_media/${Path.basename(videoFile.path)}');

        UploadTask uploadTask = storageReference.putFile(File(videoFile.path));

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        });

        await uploadTask.whenComplete(() async {
          String fileURL = await storageReference.getDownloadURL();
          post.url_media = fileURL;
        });

        // 🔥 ÉTAPE 1: Sauvegarder le post dans Firestore
        await FirebaseFirestore.instance
            .collection('Posts')
            .doc(postId)
            .set(post.toJson());

        print('✅ Post vidéo créé avec ID: $postId');

        // 🔥 ÉTAPE 2: NOTIFIER LES ABONNÉS EN ARRIÈRE-PLAN
        if (authProvider.loginUserData.id != null) {
          _notifySubscribersInBackground(postId, authProvider.loginUserData.id!);
        }

        // 🔥 ÉTAPE 3: NOTIFICATIONS PUSH EXISTANTES
        if (widget.canal != null) {
          widget.canal!.updatedAt = DateTime.now().microsecondsSinceEpoch;
          widget.canal!.publicash = (widget.canal!.publicash ?? 0) + 1;
          postProvider.updateCanal(widget.canal!, context);

          authProvider.sendPushNotificationToUsers(
            sender: authProvider.loginUserData,
            message: "${post.description}",
            typeNotif: NotificationType.POST.name,
            postId: post.id!,
            postType: PostDataType.VIDEO.name,
            chatId: '',
            smallImage: widget.canal!.urlImage,
            isChannel: true,
            channelTitle: widget.canal!.titre,
          );
        } else {
          authProvider.sendPushNotificationToUsers(
            sender: authProvider.loginUserData,
            message: "${post.description}",
            typeNotif: NotificationType.POST.name,
            postId: post.id!,
            postType: PostDataType.VIDEO.name,
            chatId: '',
            smallImage: authProvider.loginUserData.imageUrl,
            isChannel: false,
          );
        }

        // Nettoyer le formulaire
        setState(() {
          _descriptionController.text = '';
          onTap = false;
          _uploadProgress = 0;
          _controller?.pause();
          _controller = null;
        });

        addPointsForAction(UserAction.post);

        // 🔥 FERMER LE DIALOG ET AFFICHER LE SUCCÈS
        Navigator.pop(context);

        // 🔥 MESSAGE DE SUCCÈS AMÉLIORÉ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Vidéo publiée avec succès !',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Vos abonnés recevront une notification.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            backgroundColor: _cardColor,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        _checkPostCooldown();
        setState(() {});

      } catch (e) {
        print("❌ Erreur lors de la publication: $e");

        // Fermer le dialog en cas d'erreur
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        setState(() {
          onTap = false;
          _uploadProgress = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la publication. Veuillez réessayer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      }
    }
  }

  // 🔥 MÉTHODE POUR NOTIFIER LES ABONNÉS EN ARRIÈRE-PLAN
  void _notifySubscribersInBackground(String postId, String authorId) {
    // Démarrer dans un Future séparé pour ne pas bloquer l'interface
    Future.microtask(() async {
      try {
        print('🚀 Démarrage notification abonnés pour la vidéo $postId');
        final startTime = DateTime.now();

        await _notificationService.notifySubscribersAboutNewPost(
          postId: postId,
          authorId: authorId,
        );

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        print('✅ Notification abonnés terminée en ${duration.inSeconds} secondes');

        // Optionnel: Log de la notification réussie
        await FirebaseFirestore.instance
            .collection('NotificationLogs')
            .doc(postId)
            .set({
          'postId': postId,
          'authorId': authorId,
          'postType': 'VIDEO',
          'status': 'completed',
          'durationSeconds': duration.inSeconds,
          'completedAt': FieldValue.serverTimestamp(),
        });

      } catch (e) {
        print('⚠️ Erreur lors de la notification des abonnés: $e');

        // Log de l'erreur (optionnel)
        await FirebaseFirestore.instance
            .collection('NotificationLogs')
            .doc(postId)
            .set({
          'postId': postId,
          'authorId': authorId,
          'postType': 'VIDEO',
          'status': 'failed',
          'error': e.toString(),
          'failedAt': FieldValue.serverTimestamp(),
        });

        // Ne pas afficher d'erreur à l'utilisateur car c'est en arrière-plan
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Container(
      color: _backgroundColor,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header avec indication du type
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 15,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.videocam, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publication Vidéo',
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          widget.canal != null
                              ? 'Canal: ${widget.canal!.titre}'
                              : 'Post utilisateur',
                          style: TextStyle(
                            color: _hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Alerte restriction de temps
            if (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name)
              _buildCooldownAlert(),

            // Type de post
            _buildPostTypeSelector(),

            // Formulaire principal
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Champ de description
// Dans le champ de description, ajoutez le validator :
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                          hintText: 'Décrivez votre vidéo...', // Changé: description obligatoire
                          hintStyle: TextStyle(color: _hintColor),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.description, color: _primaryColor),
                        ),
                        maxLines: 2,
                        maxLength: 400,
                        validator: (value) { // AJOUT: Validation obligatoire
                          if (value == null || value.isEmpty) {
                            return 'La description est obligatoire pour les vidéos';
                          }
                          if (value.length < 10) {
                            return 'La description doit contenir au moins 10 caractères';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 10),

                    // Bouton de sélection de vidéo
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _secondaryColor, width: 2),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _getVideo,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library, color: _secondaryColor),
                              SizedBox(width: 8),
                              Text(
                                'SÉLECTIONNER UNE VIDÉO',
                                style: TextStyle(
                                  color: _secondaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Aperçu de la vidéo
                    if (_controller != null)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aperçu de la vidéo:',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_fill, color: _primaryColor),
                                SizedBox(width: 4),
                                Text(
                                  'Vidéo sélectionnée',
                                  style: TextStyle(
                                    color: _hintColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Indicateur de progression
                    if (onTap && _uploadProgress > 0)
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Téléchargement:',
                                  style: TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${(_uploadProgress * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.grey[800],
                              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 30),

                    // Bouton de publication
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: onTap || (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name)
                              ? [Colors.grey, Colors.grey]
                              : [_primaryColor, Color(0xFFFF5252)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(25),
                          onTap: onTap || (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name)
                              ? null
                              : _publishVideo,
                          child: Center(
                            child: onTap
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Publication...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                                : (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name)
                                ? Text(
                              'Attendez $_timeRemaining',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'PUBLIER LA VIDÉO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
}