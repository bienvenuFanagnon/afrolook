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
import '../../../services/utils/abonnement_utils.dart';
import '../../user/userAbonnementPage.dart';

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

  // Variables pour les restrictions
  int _maxCharacters = 300;
  int _maxVideoSizeMB = 10; // 10 Mo pour gratuit, 80 Mo pour premium
  int _cooldownMinutes = 60;

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

    _setupRestrictions();
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

  void _setupRestrictions() {
    final user = authProvider.loginUserData;
    final abonnement = user.abonnement;

    // Si c'est un ADMIN, aucune restriction
    if (user.role == UserRole.ADM.name) {
      _maxCharacters = 5000;
      _maxVideoSizeMB = 200; // 200 Mo pour admin
      _cooldownMinutes = 0;
      print('🔓 Mode Admin activé: pas de restrictions');
      return;
    }

    // Vérifier les restrictions selon l'abonnement
    final isPremium = AbonnementUtils.isPremiumActive(abonnement);

    if (isPremium) {
      // Abonnement Premium
      _maxCharacters = 3000;
      _maxVideoSizeMB = 80; // 80 Mo pour premium
      _cooldownMinutes = 0; // Pas de cooldown pour les premium
      print('🌟 Mode Premium: 3000 caractères, 80 Mo, pas de cooldown');
    } else {
      // Abonnement Gratuit
      _maxCharacters = 300;
      _maxVideoSizeMB = 10; // 10 Mo pour gratuit
      _cooldownMinutes = 60; // 60 minutes de cooldown
      print('🔒 Mode Gratuit: 300 caractères, 10 Mo, cooldown 60min');
    }
  }

  Future<void> _checkPostCooldown() async {
    // Si pas de cooldown (premium ou admin), on peut poster
    if (_cooldownMinutes == 0) {
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
        final cooldownInMicroseconds = _cooldownMinutes * 60 * 1000000;

        final timeSinceLastPost = now - lastPostTime;

        if (timeSinceLastPost < cooldownInMicroseconds) {
          final remainingTime = cooldownInMicroseconds - timeSinceLastPost;
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

  Widget _buildUserStatusBadge() {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (isAdmin) {
      badgeColor = Colors.green;
      badgeText = 'ADMIN';
      badgeIcon = Icons.admin_panel_settings;
    } else if (isPremium) {
      badgeColor = Color(0xFFFDB813);
      badgeText = 'PREMIUM';
      badgeIcon = Icons.workspace_premium;
    } else {
      badgeColor = Colors.grey;
      badgeText = 'GRATUIT';
      badgeIcon = Icons.lock;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          SizedBox(width: 6),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterCounter() {
    final textLength = _descriptionController.text.length;
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    double percentage = textLength / _maxCharacters;
    Color counterColor;

    if (textLength > _maxCharacters) {
      counterColor = Colors.red;
    } else if (percentage > 0.8) {
      counterColor = Colors.orange;
    } else {
      counterColor = Colors.green;
    }

    String statusText;
    if (isAdmin) {
      statusText = 'Admin • ${textLength}/5000';
    } else if (isPremium) {
      statusText = 'Premium • ${textLength}/3000';
    } else {
      statusText = 'Gratuit • ${textLength}/300';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          statusText,
          style: TextStyle(
            color: counterColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage.clamp(0.0, 1.0),
          backgroundColor: Colors.grey[800],
          valueColor: AlwaysStoppedAnimation<Color>(counterColor),
          minHeight: 3,
        ),
      ],
    );
  }

  Widget _buildVideoSizeInfo() {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    String sizeText;
    Color color;

    if (isAdmin) {
      sizeText = 'Taille max: 200 Mo (Admin)';
      color = Colors.green;
    } else if (isPremium) {
      sizeText = 'Taille max: 80 Mo (Premium)';
      color = Color(0xFFFDB813);
    } else {
      sizeText = 'Taille max: 10 Mo (Gratuit)';
      color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage, size: 14, color: color),
          SizedBox(width: 6),
          Text(
            sizeText,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictionsInfo() {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    String infoText;
    Color infoColor;

    if (isAdmin) {
      infoText = 'Mode Admin : Toutes les vidéos acceptées';
      infoColor = Colors.green;
    } else if (isPremium) {
      infoText = 'Mode Premium : 80 Mo, 3000 caractères, pas d\'attente';
      infoColor = Color(0xFFFDB813);
    } else {
      infoText = 'Mode Gratuit : 10 Mo, 300 caractères, attente 60min';
      infoColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: infoColor),
      ),
      child: Row(
        children: [
          Icon(
            isAdmin ? Icons.admin_panel_settings :
            isPremium ? Icons.workspace_premium : Icons.info,
            color: infoColor,
            size: 16,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              infoText,
              style: TextStyle(
                color: infoColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isPremium && !isAdmin)
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => AbonnementScreen(),
                ));
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text(
                'PASSER À PREMIUM',
                style: TextStyle(
                  color: Color(0xFFFDB813),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPremiumModal({String? reason}) {
    String title = '';
    String message = '';

    if (reason == 'size') {
      title = 'Vidéo trop grande';
      message = 'L\'abonnement gratuit est limité à 10 Mo.\nPassez à Afrolook Premium pour publier des vidéos jusqu\'à 80 Mo.';
    } else {
      title = 'Limite de caractères atteinte';
      message = 'L\'abonnement gratuit est limité à 300 caractères.\nPassez à Afrolook Premium pour écrire jusqu\'à 3000 caractères.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFDB813)),
            SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFFDB813)),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Color(0xFFFDB813)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'À partir de 200 F/mois',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Réduction sur les abonnements longs',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'PAS MAINTENANT',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => AbonnementScreen(),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFDB813),
              foregroundColor: Colors.black,
            ),
            child: Text('VOIR L\'ABONNEMENT'),
          ),
        ],
      ),
    );
  }

  Future<void> _getVideo() async {
    await picker.pickVideo(source: ImageSource.gallery).then((video) async {
      if (video == null) return;

      // Vérifier la taille de la vidéo
      final size = await video.length();
      final sizeInMB = size / (1024 * 1024); // Convertir en Mo

      final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

      if (!isAdmin && !isPremium && sizeInMB > _maxVideoSizeMB) {
        _showPremiumModal(reason: 'size');
        return;
      }

      if (!isAdmin && isPremium && sizeInMB > _maxVideoSizeMB) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La vidéo dépasse la limite de 80 Mo pour les abonnés Premium',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
        return;
      }

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

  Future<void> _publishVideo() async {
    // Vérifier cooldown (sauf pour admin et premium)
    if (!_canPost && _cooldownMinutes > 0) {
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
      // Vérifier la longueur du texte
      final textLength = _descriptionController.text.length;
      if (textLength > _maxCharacters) {
        final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
        if (!isPremium) {
          _showPremiumModal();
          return;
        }
      }

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

        // Afficher un indicateur de progression
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
        final sizeInMB = size / (1024 * 1024); // Convertir en Mo

        // Vérification de la taille selon l'abonnement
        if (sizeInMB > _maxVideoSizeMB) {
          Navigator.pop(context); // Fermer le dialog
          setState(() {
            onTap = false;
          });

          final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
          final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

          String errorMessage;
          if (!isAdmin && !isPremium) {
            errorMessage = 'La vidéo est trop grande (plus de 10 Mo). Passez à Premium pour 80 Mo.';
          } else if (isPremium) {
            errorMessage = 'La vidéo dépasse la limite de 80 Mo pour les abonnés Premium';
          } else {
            errorMessage = 'La vidéo est trop grande';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
          return;
        }

        // Vérification de la durée (5 minutes max pour tous)
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
            .child('post_media/${Path.basename(videoFile.path)}_${DateTime.now().millisecondsSinceEpoch}');

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

        // Sauvegarder le post dans Firestore
        await FirebaseFirestore.instance
            .collection('Posts')
            .doc(postId)
            .set(post.toJson());

        print('✅ Post vidéo créé avec ID: $postId');

        // Notifier les abonnés en arrière-plan
        if (authProvider.loginUserData.id != null) {
          _notifySubscribersInBackground(postId, authProvider.loginUserData.id!);
        }

        // Notifications push
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

        // Fermer le dialog et afficher le succès
        Navigator.pop(context);

        // Message de succès avec infos sur le type d'abonnement
        final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
        final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

        String successMessage = 'Vidéo publiée avec succès !';
        if (isAdmin) {
          successMessage = 'Vidéo publiée (Mode Admin) !';
        } else if (isPremium) {
          successMessage = 'Vidéo publiée avec Premium !';
        }

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
                      successMessage,
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '${textLength} caractères • ${sizeInMB.toStringAsFixed(1)} Mo',
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

  // Méthode pour notifier les abonnés en arrière-plan
  void _notifySubscribersInBackground(String postId, String authorId) {
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
      }
    });
  }

  Widget _buildVideoPreview() {
    if (_controller != null) {
      try {
        final size = videoFile.length();

        return FutureBuilder<int>(
          future: size,
          builder: (context, snapshot) {
            final sizeInMB = snapshot.hasData ? snapshot.data! / (1024 * 1024) : 0;
            final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
            final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

            Color sizeColor = Colors.green;
            if (!isAdmin && !isPremium && sizeInMB > 10) {
              sizeColor = Colors.red;
            } else if (isPremium && sizeInMB > 80) {
              sizeColor = Colors.orange;
            }

            return Container(
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
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: sizeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sizeColor),
                        ),
                        child: Text(
                          snapshot.hasData
                              ? '${sizeInMB.toStringAsFixed(1)} Mo'
                              : 'Chargement...',
                          style: TextStyle(
                            color: sizeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      } catch (e) {
        return Container();
      }
    }
    return Container();
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
            // Header avec badge de statut
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
                        SizedBox(height: 4),
                        _buildUserStatusBadge(),
                      ],
                    ),
                  ),
                  _buildVideoSizeInfo(),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Information sur les restrictions
            _buildRestrictionsInfo(),

            // Alerte restriction de temps
            if (!_canPost && _cooldownMinutes > 0)
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
                    // Champ de description avec compteur
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _descriptionController,
                            style: TextStyle(color: _textColor),
                            decoration: InputDecoration(
                              hintText: 'Décrivez votre vidéo...',
                              hintStyle: TextStyle(color: _hintColor),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                              prefixIcon: Icon(Icons.description, color: _primaryColor),
                            ),
                            maxLines: 3,
                            onChanged: (value) {
                              setState(() {});
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La description est obligatoire pour les vidéos';
                              }
                              if (value.length < 10) {
                                return 'La description doit contenir au moins 10 caractères';
                              }
                              if (value.length > _maxCharacters) {
                                return 'Limite de $_maxCharacters caractères dépassée';
                              }
                              return null;
                            },
                          ),
                          Padding(
                            padding: EdgeInsets.all(16).copyWith(top: 8),
                            child: _buildCharacterCounter(),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Information sur la durée
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Durée maximale: 5 minutes pour tous les utilisateurs',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Bouton de sélection de vidéo
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _secondaryColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _secondaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _getVideo,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library, color: _secondaryColor, size: 24),
                              SizedBox(width: 12),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SÉLECTIONNER UNE VIDÉO',
                                    style: TextStyle(
                                      color: _secondaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Limite selon votre abonnement',
                                    style: TextStyle(
                                      color: _hintColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Aperçu de la vidéo
                    _buildVideoPreview(),

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
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: onTap || (!_canPost && _cooldownMinutes > 0) || _controller == null
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
                          onTap: onTap || (!_canPost && _cooldownMinutes > 0) || _controller == null
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
                                : (!_canPost && _cooldownMinutes > 0)
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Attendez $_timeRemaining',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                                : _controller == null
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.video_library, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'CHOISIR UNE VIDÉO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
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

                    SizedBox(height: 15),

                    // Indication du canal si présent
                    if (widget.canal != null)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.group, color: Colors.blue, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Publication dans le canal: ${widget.canal!.titre}',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
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
}


// import 'dart:async';
// import 'dart:io';
// import 'package:afrotok/models/model_data.dart';
// import 'package:afrotok/pages/component/consoleWidget.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:path/path.dart' as Path;
// import 'package:provider/provider.dart';
// import 'package:video_player/video_player.dart';
//
// import '../../../providers/authProvider.dart';
// import '../../../providers/postProvider.dart';
// import '../../../providers/userProvider.dart';
// import '../../../services/postService/massNotificationService.dart';
//
//
//
// class UserPubVideo extends StatefulWidget {
//   final Canal? canal;
//   const UserPubVideo({super.key, required this.canal});
//
//   @override
//   State<UserPubVideo> createState() => _UserPubVideoState();
// }
//
// class _UserPubVideoState extends State<UserPubVideo> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _descriptionController = TextEditingController();
//
//   bool onTap = false;
//   double _uploadProgress = 0;
//   late XFile videoFile;
//   bool isVideo = false;
//
//   VideoPlayerController? _controller;
//
//   final ImagePicker picker = ImagePicker();
//
//   // Variables pour le type de post
//   String? _selectedPostType;
//   String? _selectedPostTypeLibeller;
//
//   // Contrôle de temps entre les posts
//   bool _canPost = true;
//   String _timeRemaining = '';
//
//   // Map des types de post avec code et libellé
//   final Map<String, Map<String, dynamic>> _postTypes = {
//     'LOOKS': {'label': '👗 Looks', 'icon': Icons.style},
//     'ACTUALITES': {'label': '📰 Actualités', 'icon': Icons.article},
//     'SPORT': {'label': '⚽ Sport', 'icon': Icons.sports},
//     'EVENEMENT': {'label': '🎉 Événement', 'icon': Icons.event},
//     'OFFRES': {'label': '🏷️ Offres', 'icon': Icons.local_offer},
//     'GAMER': {'label': '🎮 Games story', 'icon': Icons.gamepad},
//   };
//
//   late UserAuthProvider authProvider;
//   late UserProvider userProvider;
//   late PostProvider postProvider;
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//
//   // Couleurs personnalisées
//   final Color _primaryColor = Color(0xFFE21221); // Rouge
//   final Color _secondaryColor = Color(0xFFFFD600); // Jaune
//   final Color _backgroundColor = Color(0xFF121212); // Noir
//   final Color _cardColor = Color(0xFF1E1E1E);
//   final Color _textColor = Colors.white;
//   final Color _hintColor = Colors.grey[400]!;
//   late MassNotificationService _notificationService;
//
//   @override
//   void initState() {
//     super.initState();
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     userProvider = Provider.of<UserProvider>(context, listen: false);
//     postProvider = Provider.of<PostProvider>(context, listen: false);
//     _notificationService = MassNotificationService();
//
//     _checkPostCooldown();
//   }
//
//   @override
//   void dispose() {
//     super.dispose();
//     if (_controller != null) {
//       _controller!.pause();
//       _controller!.dispose();
//     }
//   }
//
//   Future<void> _checkPostCooldown() async {
//     if (authProvider.loginUserData.role == UserRole.ADM.name) {
//       setState(() {
//         _canPost = true;
//       });
//       return;
//     }
//
//     try {
//       final userPosts = await firestore
//           .collection('Posts')
//           .where('user_id', isEqualTo: authProvider.loginUserData.id)
//           .orderBy('created_at', descending: true)
//           .limit(1)
//           .get();
//
//       if (userPosts.docs.isNotEmpty) {
//         final lastPost = userPosts.docs.first;
//         final lastPostTime = lastPost['created_at'] as int;
//         final now = DateTime.now().microsecondsSinceEpoch;
//         final oneHourInMicroseconds = 60 * 60 * 1000000;
//
//         final timeSinceLastPost = now - lastPostTime;
//
//         if (timeSinceLastPost < oneHourInMicroseconds) {
//           final remainingTime = oneHourInMicroseconds - timeSinceLastPost;
//           _startCooldownTimer(remainingTime);
//         } else {
//           setState(() {
//             _canPost = true;
//           });
//         }
//       } else {
//         setState(() {
//           _canPost = true;
//         });
//       }
//     } catch (e) {
//       print("Erreur vérification cooldown: $e");
//       setState(() {
//         _canPost = true;
//       });
//     }
//   }
//
//   void _startCooldownTimer(int remainingMicroseconds) {
//     setState(() {
//       _canPost = false;
//     });
//
//     _updateTimeRemaining(remainingMicroseconds);
//
//     Timer.periodic(Duration(seconds: 1), (timer) {
//       remainingMicroseconds -= 1000000;
//
//       if (remainingMicroseconds <= 0) {
//         timer.cancel();
//         setState(() {
//           _canPost = true;
//           _timeRemaining = '';
//         });
//       } else {
//         _updateTimeRemaining(remainingMicroseconds);
//       }
//     });
//   }
//
//   void _updateTimeRemaining(int microseconds) {
//     final seconds = microseconds ~/ 1000000;
//     final minutes = seconds ~/ 60;
//     final remainingSeconds = seconds % 60;
//
//     setState(() {
//       _timeRemaining = '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
//     });
//   }
//
//   Future<void> _getVideo() async {
//     await picker.pickVideo(source: ImageSource.gallery).then((video) async {
//       if (video == null) return;
//
//       late VideoPlayerController controller;
//
//       if (kIsWeb) {
//         controller = VideoPlayerController.networkUrl(Uri.parse(video.path));
//         videoFile = video;
//         _controller = controller;
//       } else {
//         videoFile = video;
//         controller = VideoPlayerController.file(File(video.path));
//         _controller = controller;
//       }
//
//       const double volume = kIsWeb ? 0.0 : 1.0;
//       await controller.setVolume(volume);
//       await controller.initialize();
//       await controller.setLooping(true);
//       await controller.play();
//       setState(() {});
//     });
//   }
//
//   Widget _buildCooldownAlert() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: _secondaryColor),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.3),
//             blurRadius: 10,
//             offset: Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.timer, color: _secondaryColor, size: 24),
//           SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Temps d\'attente',
//                   style: TextStyle(
//                     color: _textColor,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   'Prochain post dans: $_timeRemaining',
//                   style: TextStyle(
//                     color: _hintColor,
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             decoration: BoxDecoration(
//               color: _secondaryColor.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Text(
//               _timeRemaining,
//               style: TextStyle(
//                 color: _secondaryColor,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPostTypeSelector() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.3),
//             blurRadius: 10,
//             offset: Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.category, color: _primaryColor, size: 20),
//               SizedBox(width: 8),
//               Text(
//                 'Type de publication',
//                 style: TextStyle(
//                   color: _textColor,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 12),
//           DropdownButtonFormField<String>(
//             decoration: InputDecoration(
//               hintText: 'Choisir un type de publication',
//               hintStyle: TextStyle(color: _hintColor),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(color: Colors.grey[700]!),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(color: Colors.grey[700]!),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(color: _primaryColor),
//               ),
//               filled: true,
//               fillColor: _backgroundColor,
//               contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//             ),
//             dropdownColor: _cardColor,
//             style: TextStyle(color: _textColor, fontSize: 14),
//             value: _selectedPostType,
//             onChanged: (String? newValue) {
//               setState(() {
//                 _selectedPostType = newValue;
//                 _selectedPostTypeLibeller = _postTypes[_selectedPostType]?['label'];
//               });
//             },
//             items: _postTypes.entries.map<DropdownMenuItem<String>>((entry) {
//               return DropdownMenuItem<String>(
//                 value: entry.key,
//                 child: Row(
//                   children: [
//                     Icon(_postTypes[entry.key]!['icon'] as IconData,
//                         color: _primaryColor, size: 18),
//                     SizedBox(width: 12),
//                     Text(
//                       _postTypes[entry.key]!['label'],
//                       style: TextStyle(color: _textColor),
//                     ),
//                   ],
//                 ),
//               );
//             }).toList(),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Veuillez sélectionner un type de post';
//               }
//               return null;
//             },
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _publishVideo() async {
//     if (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Veuillez attendre $_timeRemaining avant de poster à nouveau',
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.red),
//           ),
//         ),
//       );
//       return;
//     }
//
//     if (_formKey.currentState!.validate()) {
//       if (_controller == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Veuillez choisir une vidéo.',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//         );
//         return;
//       }
//
//       try {
//         setState(() {
//           onTap = true;
//           _uploadProgress = 0;
//         });
//
//         // 🔥 AFFICHER UN INDICATEUR DE PROGRESSION AMÉLIORÉ
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return AlertDialog(
//               backgroundColor: _cardColor,
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   CircularProgressIndicator(
//                     valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
//                   ),
//                   SizedBox(height: 16),
//                   Text(
//                     'Publication en cours...',
//                     style: TextStyle(color: _textColor),
//                   ),
//                   SizedBox(height: 8),
//                   Text(
//                     'Téléchargement de la vidéo et notification des abonnés',
//                     style: TextStyle(
//                       color: _hintColor,
//                       fontSize: 12,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//
//         Duration videoDuration = _controller!.value.duration;
//         int size = await videoFile.length();
//
//         // Vérification de la durée
//         if (videoDuration.inSeconds > 60 * 5) {
//           Navigator.pop(context); // Fermer le dialog
//           setState(() {
//             onTap = false;
//           });
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'La durée de la vidéo dépasse 5 min !',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.red),
//               ),
//             ),
//           );
//           return;
//         }
//
//         // Vérification de la taille
//         if (size > 20971520) {
//           Navigator.pop(context); // Fermer le dialog
//           setState(() {
//             onTap = false;
//           });
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'La vidéo est trop grande (plus de 20 Mo).',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.red),
//               ),
//             ),
//           );
//           return;
//         }
//
//         String postId = FirebaseFirestore.instance.collection('Posts').doc().id;
//
//         Post post = Post();
//         post.user_id = authProvider.loginUserData.id;
//         post.description = _descriptionController.text;
//         post.updatedAt = DateTime.now().microsecondsSinceEpoch;
//         post.createdAt = DateTime.now().microsecondsSinceEpoch;
//         post.status = PostStatus.VALIDE.name;
//         post.type = PostType.POST.name;
//         post.dataType = PostDataType.VIDEO.name;
//         post.typeTabbar = _selectedPostType;
//         post.comments = 0;
//         post.likes = 0;
//         post.feedScore = 0.0;
//         post.loves = 0;
//         post.id = postId;
//         post.images = [];
//
//         if (widget.canal != null) {
//           post.canal_id = widget.canal!.id;
//           post.categorie = "CANAL";
//         }
//
//         // Upload de la vidéo
//         Reference storageReference = FirebaseStorage.instance
//             .ref()
//             .child('post_media/${Path.basename(videoFile.path)}');
//
//         UploadTask uploadTask = storageReference.putFile(File(videoFile.path));
//
//         uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
//           setState(() {
//             _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
//           });
//         });
//
//         await uploadTask.whenComplete(() async {
//           String fileURL = await storageReference.getDownloadURL();
//           post.url_media = fileURL;
//         });
//
//         // 🔥 ÉTAPE 1: Sauvegarder le post dans Firestore
//         await FirebaseFirestore.instance
//             .collection('Posts')
//             .doc(postId)
//             .set(post.toJson());
//
//         print('✅ Post vidéo créé avec ID: $postId');
//
//         // 🔥 ÉTAPE 2: NOTIFIER LES ABONNÉS EN ARRIÈRE-PLAN
//         if (authProvider.loginUserData.id != null) {
//           _notifySubscribersInBackground(postId, authProvider.loginUserData.id!);
//         }
//
//         // 🔥 ÉTAPE 3: NOTIFICATIONS PUSH EXISTANTES
//         if (widget.canal != null) {
//           widget.canal!.updatedAt = DateTime.now().microsecondsSinceEpoch;
//           widget.canal!.publicash = (widget.canal!.publicash ?? 0) + 1;
//           postProvider.updateCanal(widget.canal!, context);
//
//           authProvider.sendPushNotificationToUsers(
//             sender: authProvider.loginUserData,
//             message: "${post.description}",
//             typeNotif: NotificationType.POST.name,
//             postId: post.id!,
//             postType: PostDataType.VIDEO.name,
//             chatId: '',
//             smallImage: widget.canal!.urlImage,
//             isChannel: true,
//             channelTitle: widget.canal!.titre,
//           );
//         } else {
//           authProvider.sendPushNotificationToUsers(
//             sender: authProvider.loginUserData,
//             message: "${post.description}",
//             typeNotif: NotificationType.POST.name,
//             postId: post.id!,
//             postType: PostDataType.VIDEO.name,
//             chatId: '',
//             smallImage: authProvider.loginUserData.imageUrl,
//             isChannel: false,
//           );
//         }
//
//         // Nettoyer le formulaire
//         setState(() {
//           _descriptionController.text = '';
//           onTap = false;
//           _uploadProgress = 0;
//           _controller?.pause();
//           _controller = null;
//         });
//
//         addPointsForAction(UserAction.post);
//
//         // 🔥 FERMER LE DIALOG ET AFFICHER LE SUCCÈS
//         Navigator.pop(context);
//
//         // 🔥 MESSAGE DE SUCCÈS AMÉLIORÉ
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Icon(Icons.check_circle, color: Colors.green, size: 20),
//                     SizedBox(width: 8),
//                     Text(
//                       'Vidéo publiée avec succès !',
//                       style: TextStyle(
//                         color: Colors.green,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   'Vos abonnés recevront une notification.',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//             backgroundColor: _cardColor,
//             duration: Duration(seconds: 4),
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//           ),
//         );
//
//         _checkPostCooldown();
//         setState(() {});
//
//       } catch (e) {
//         print("❌ Erreur lors de la publication: $e");
//
//         // Fermer le dialog en cas d'erreur
//         if (Navigator.canPop(context)) {
//           Navigator.pop(context);
//         }
//
//         setState(() {
//           onTap = false;
//           _uploadProgress = 0;
//         });
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Erreur lors de la publication. Veuillez réessayer.',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//         );
//       }
//     }
//   }
//
//   // 🔥 MÉTHODE POUR NOTIFIER LES ABONNÉS EN ARRIÈRE-PLAN
//   void _notifySubscribersInBackground(String postId, String authorId) {
//     // Démarrer dans un Future séparé pour ne pas bloquer l'interface
//     Future.microtask(() async {
//       try {
//         print('🚀 Démarrage notification abonnés pour la vidéo $postId');
//         final startTime = DateTime.now();
//
//         await _notificationService.notifySubscribersAboutNewPost(
//           postId: postId,
//           authorId: authorId,
//         );
//
//         final endTime = DateTime.now();
//         final duration = endTime.difference(startTime);
//
//         print('✅ Notification abonnés terminée en ${duration.inSeconds} secondes');
//
//         // Optionnel: Log de la notification réussie
//         await FirebaseFirestore.instance
//             .collection('NotificationLogs')
//             .doc(postId)
//             .set({
//           'postId': postId,
//           'authorId': authorId,
//           'postType': 'VIDEO',
//           'status': 'completed',
//           'durationSeconds': duration.inSeconds,
//           'completedAt': FieldValue.serverTimestamp(),
//         });
//
//       } catch (e) {
//         print('⚠️ Erreur lors de la notification des abonnés: $e');
//
//         // Log de l'erreur (optionnel)
//         await FirebaseFirestore.instance
//             .collection('NotificationLogs')
//             .doc(postId)
//             .set({
//           'postId': postId,
//           'authorId': authorId,
//           'postType': 'VIDEO',
//           'status': 'failed',
//           'error': e.toString(),
//           'failedAt': FieldValue.serverTimestamp(),
//         });
//
//         // Ne pas afficher d'erreur à l'utilisateur car c'est en arrière-plan
//       }
//     });
//   }
//   @override
//   Widget build(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     return Container(
//       color: _backgroundColor,
//       child: SingleChildScrollView(
//         child: Column(
//           children: [
//             // Header avec indication du type
//             Container(
//               padding: EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: _cardColor,
//                 borderRadius: BorderRadius.only(
//                   bottomLeft: Radius.circular(20),
//                   bottomRight: Radius.circular(20),
//                 ),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.5),
//                     blurRadius: 15,
//                     offset: Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     padding: EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: _primaryColor,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Icon(Icons.videocam, color: Colors.white, size: 24),
//                   ),
//                   SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Publication Vidéo',
//                           style: TextStyle(
//                             color: _textColor,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 18,
//                           ),
//                         ),
//                         Text(
//                           widget.canal != null
//                               ? 'Canal: ${widget.canal!.titre}'
//                               : 'Post utilisateur',
//                           style: TextStyle(
//                             color: _hintColor,
//                             fontSize: 12,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//             SizedBox(height: 16),
//
//             // Alerte restriction de temps
//             if (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name)
//               _buildCooldownAlert(),
//
//             // Type de post
//             _buildPostTypeSelector(),
//
//             // Formulaire principal
//             Container(
//               margin: EdgeInsets.all(16),
//               padding: EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: _cardColor,
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.3),
//                     blurRadius: 10,
//                     offset: Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     // Champ de description
// // Dans le champ de description, ajoutez le validator :
//                     Container(
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(16),
//                         border: Border.all(color: Colors.grey[700]!),
//                       ),
//                       child: TextFormField(
//                         controller: _descriptionController,
//                         style: TextStyle(color: _textColor),
//                         decoration: InputDecoration(
//                           hintText: 'Décrivez votre vidéo...', // Changé: description obligatoire
//                           hintStyle: TextStyle(color: _hintColor),
//                           border: InputBorder.none,
//                           contentPadding: EdgeInsets.all(16),
//                           prefixIcon: Icon(Icons.description, color: _primaryColor),
//                         ),
//                         maxLines: 2,
//                         maxLength: 400,
//                         validator: (value) { // AJOUT: Validation obligatoire
//                           if (value == null || value.isEmpty) {
//                             return 'La description est obligatoire pour les vidéos';
//                           }
//                           if (value.length < 10) {
//                             return 'La description doit contenir au moins 10 caractères';
//                           }
//                           return null;
//                         },
//                       ),
//                     ),
//                     SizedBox(height: 10),
//
//                     // Bouton de sélection de vidéo
//                     Container(
//                       width: double.infinity,
//                       height: 50,
//                       decoration: BoxDecoration(
//                         color: _cardColor,
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: _secondaryColor, width: 2),
//                       ),
//                       child: Material(
//                         color: Colors.transparent,
//                         child: InkWell(
//                           borderRadius: BorderRadius.circular(12),
//                           onTap: _getVideo,
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(Icons.video_library, color: _secondaryColor),
//                               SizedBox(width: 8),
//                               Text(
//                                 'SÉLECTIONNER UNE VIDÉO',
//                                 style: TextStyle(
//                                   color: _secondaryColor,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//
//                     SizedBox(height: 20),
//
//                     // Aperçu de la vidéo
//                     if (_controller != null)
//                       Container(
//                         padding: EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: _backgroundColor,
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Aperçu de la vidéo:',
//                               style: TextStyle(
//                                 color: _textColor,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16,
//                               ),
//                             ),
//                             SizedBox(height: 12),
//                             Container(
//                               width: double.infinity,
//                               height: 200,
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(12),
//                                 color: Colors.black,
//                               ),
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.circular(12),
//                                 child: VideoPlayer(_controller!),
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(Icons.play_circle_fill, color: _primaryColor),
//                                 SizedBox(width: 4),
//                                 Text(
//                                   'Vidéo sélectionnée',
//                                   style: TextStyle(
//                                     color: _hintColor,
//                                     fontStyle: FontStyle.italic,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//
//                     // Indicateur de progression
//                     if (onTap && _uploadProgress > 0)
//                       Container(
//                         padding: EdgeInsets.all(16),
//                         margin: EdgeInsets.symmetric(vertical: 16),
//                         decoration: BoxDecoration(
//                           color: _backgroundColor,
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         child: Column(
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   'Téléchargement:',
//                                   style: TextStyle(
//                                     color: _textColor,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 Text(
//                                   '${(_uploadProgress * 100).toStringAsFixed(1)}%',
//                                   style: TextStyle(
//                                     color: _primaryColor,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             SizedBox(height: 8),
//                             LinearProgressIndicator(
//                               value: _uploadProgress,
//                               backgroundColor: Colors.grey[800],
//                               valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                           ],
//                         ),
//                       ),
//
//                     SizedBox(height: 30),
//
//                     // Bouton de publication
//                     Container(
//                       width: double.infinity,
//                       height: 50,
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: onTap || (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name)
//                               ? [Colors.grey, Colors.grey]
//                               : [_primaryColor, Color(0xFFFF5252)],
//                           begin: Alignment.centerLeft,
//                           end: Alignment.centerRight,
//                         ),
//                         borderRadius: BorderRadius.circular(25),
//                         boxShadow: [
//                           BoxShadow(
//                             color: _primaryColor.withOpacity(0.3),
//                             blurRadius: 10,
//                             offset: Offset(0, 4),
//                           ),
//                         ],
//                       ),
//                       child: Material(
//                         color: Colors.transparent,
//                         child: InkWell(
//                           borderRadius: BorderRadius.circular(25),
//                           onTap: onTap || (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name)
//                               ? null
//                               : _publishVideo,
//                           child: Center(
//                             child: onTap
//                                 ? Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 CircularProgressIndicator(
//                                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                                   strokeWidth: 2,
//                                 ),
//                                 SizedBox(width: 10),
//                                 Text(
//                                   'Publication...',
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             )
//                                 : (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name)
//                                 ? Text(
//                               'Attendez $_timeRemaining',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 14,
//                               ),
//                             )
//                                 : Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(Icons.videocam, color: Colors.white, size: 20),
//                                 SizedBox(width: 8),
//                                 Text(
//                                   'PUBLIER LA VIDÉO',
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }