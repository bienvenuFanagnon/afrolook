import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path/path.dart' as Path;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../services/postService/massNotificationService.dart';

class UserPostLookImageTab extends StatefulWidget {
  final Canal? canal;
  const UserPostLookImageTab({
    super.key,
    required this.canal,
  });

  @override
  State<UserPostLookImageTab> createState() => _UserPostLookImageTabState();
}

class _UserPostLookImageTabState extends State<UserPostLookImageTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();

  late PostProvider postProvider;
  late UserAuthProvider authProvider;
  late UserProvider userProvider;

  bool onTap = false;
  bool _canPost = true;
  String _timeRemaining = '';

  String? _selectedPostType;
  Uint8List? _imageBytes;
  String? _imageName;

  final Map<String, Map<String, dynamic>> _postTypes = {
    'LOOKS': {'label': '👗 Looks', 'icon': Icons.style},
    'ACTUALITES': {'label': '📰 Actualités', 'icon': Icons.article},
    'SPORT': {'label': '⚽ Sport', 'icon': Icons.sports},
    'EVENEMENT': {'label': '🎉 Événement', 'icon': Icons.event},
    'OFFRES': {'label': '🏷️ Offres', 'icon': Icons.local_offer},
    'GAMER': {'label': '🎮 Games story', 'icon': Icons.gamepad},
  };

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
    postProvider = Provider.of<PostProvider>(context, listen: false);
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    _notificationService = MassNotificationService();

    _checkPostCooldown();
  }

  Future<void> _checkPostCooldown() async {
    if (authProvider.loginUserData.role == UserRole.ADM.name) {
      setState(() {
        _canPost = true;
      });
      return;
    }

    try {
      final userPosts = await FirebaseFirestore.instance
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

  Future<void> _selectImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // Qualité réduite pour compression
      maxWidth: 1920,   // Largeur maximale
      maxHeight: 1080,  // Hauteur maximale
    );

    if (image != null) {
      try {
        // Compression supplémentaire de l'image
        final Uint8List compressedBytes = await _compressImage(await image.readAsBytes());

        setState(() {
          _imageBytes = compressedBytes;
          _imageName = image.name;
        });

        print('Image sélectionnée: ${image.name}');
        print('Taille compressée: ${compressedBytes.length} bytes');
      } catch (e) {
        print("Erreur lors de la compression: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors du traitement de l\'image',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      }
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 1080,
        minWidth: 1080,
        quality: 75, // Qualité réduite pour économiser l'espace
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      print("Erreur compression: $e");
      return bytes; // Retourne l'original si échec
    }
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
              });
            },
            items: _postTypes.entries.map<DropdownMenuItem<String>>((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    Icon(entry.value['icon'] as IconData,
                        color: _primaryColor, size: 18),
                    SizedBox(width: 12),
                    Text(
                      entry.value['label'],
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

  Future<void> _publishPost() async {
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
      if (_imageBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Veuillez sélectionner une image',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
        return;
      }

      setState(() {
        onTap = true;
      });

      try {
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
                  LoadingAnimationWidget.flickr(
                    size: 50,
                    leftDotColor: _primaryColor,
                    rightDotColor: _secondaryColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Publication en cours...',
                    style: TextStyle(color: _textColor),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vos abonnés seront notifiés',
                    style: TextStyle(
                      color: _hintColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        );

        String postId = FirebaseFirestore.instance.collection('Posts').doc().id;

        Post post = Post()
          ..user_id = authProvider.loginUserData.id
          ..description = _descriptionController.text
          ..updatedAt = DateTime.now().microsecondsSinceEpoch
          ..createdAt = DateTime.now().microsecondsSinceEpoch
          ..status = PostStatus.VALIDE.name
          ..type = PostType.POST.name
          ..comments = 0
          ..typeTabbar = _selectedPostType
          ..nombrePersonneParJour = 60
          ..dataType = PostDataType.IMAGE.name
          ..likes = 0
          ..feedScore = 0.0
          ..loves = 0
          ..id = postId
          ..images = [];

        if (widget.canal != null) {
          post.canal_id = widget.canal!.id;
          post.categorie = "CANAL";
        }

        // Upload de l'image compressée
        final String uniqueFileName = Uuid().v4();
        Reference storageReference = FirebaseStorage.instance.ref().child('post_media/$uniqueFileName.jpg');

        // Créer un fichier temporaire avec les bytes compressés
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$uniqueFileName.jpg');
        await file.writeAsBytes(_imageBytes!);

        // Upload vers Firebase Storage
        await storageReference.putFile(file);
        String fileURL = await storageReference.getDownloadURL();
        post.images!.add(fileURL);

        // 🔥 ÉTAPE 1: Sauvegarder le post dans Firestore
        await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());

        print('✅ Post créé avec ID: $postId');

        // 🔥 ÉTAPE 2: NOTIFIER LES ABONNÉS EN ARRIÈRE-PLAN
        if (authProvider.loginUserData.id != null) {
          _notifySubscribersInBackground(postId, authProvider.loginUserData.id!);
        }

        // Nettoyer le formulaire
        _descriptionController.clear();
        setState(() {
          onTap = false;
          _imageBytes = null;
          _imageName = null;
        });

        // 🔥 ÉTAPE 3: NOTIFICATIONS PUSH EXISTANTES
        if (widget.canal != null) {
          authProvider.sendPushNotificationToUsers(
            sender: authProvider.loginUserData,
            message: "${post.description}",
            typeNotif: NotificationType.POST.name,
            postId: post.id!,
            postType: PostDataType.IMAGE.name,
            chatId: '',
            smallImage: widget.canal!.urlImage,
            isChannel: true,
            channelTitle: widget.canal!.titre,
          );

          // Mettre à jour le canal
          widget.canal!.updatedAt = DateTime.now().microsecondsSinceEpoch;
          widget.canal!.publication = (widget.canal!.publication ?? 0) + 1;
          await FirebaseFirestore.instance
              .collection('Canaux')
              .doc(widget.canal!.id)
              .update({
            'updatedAt': widget.canal!.updatedAt,
            'publication': widget.canal!.publication,
          });
        } else {
          authProvider.sendPushNotificationToUsers(
            sender: authProvider.loginUserData,
            message: "${post.description}",
            typeNotif: NotificationType.POST.name,
            postId: post.id!,
            postType: PostDataType.IMAGE.name,
            chatId: '',
            smallImage: authProvider.loginUserData.imageUrl,
            isChannel: false,
          );
        }

        // Ajouter des points pour l'action
        addPointsForAction(UserAction.post);

        // Fermer le dialog et montrer le succès
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
                      'Image publiée avec succès !',
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

        // Re-vérifier le cooldown
        _checkPostCooldown();

      } catch (e) {
        print("❌ Erreur lors de la publication: $e");

        // Fermer le dialog en cas d'erreur
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        setState(() {
          onTap = false;
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
        print('🚀 Démarrage notification abonnés pour le post $postId');
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

    return Scaffold(
      backgroundColor: _backgroundColor,
      // appBar: AppBar(
      //   title: Text(
      //     "Publier une image",
      //     style: TextStyle(
      //       color: _textColor,
      //       fontWeight: FontWeight.bold,
      //       fontSize: 20,
      //     ),
      //   ),
      //   backgroundColor: _cardColor,
      //   elevation: 0,
      //   iconTheme: IconThemeData(color: _textColor),
      //   actions: [
      //     Padding(
      //       padding: const EdgeInsets.only(right: 16.0),
      //       child: Logo(),
      //     )
      //   ],
      // ),
      body: SingleChildScrollView(
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
                    child: Icon(Icons.photo_library, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publication Image',
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
                    // Section sélection d'image
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _imageBytes != null ? _primaryColor : Colors.grey[700]!,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_imageBytes != null)
                            Column(
                              children: [
                                Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.black,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _imageBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  _imageName ?? 'Image sélectionnée',
                                  style: TextStyle(
                                    color: _hintColor,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _selectImage,
                                      icon: Icon(Icons.change_circle, size: 18),
                                      label: Text('Changer'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _cardColor,
                                        foregroundColor: _textColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _imageBytes = null;
                                          _imageName = null;
                                        });
                                      },
                                      icon: Icon(Icons.delete, size: 18),
                                      label: Text('Supprimer'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                Icon(
                                  Icons.photo_library,
                                  size: 60,
                                  color: _hintColor,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Aucune image sélectionnée',
                                  style: TextStyle(
                                    color: _hintColor,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _selectImage,
                                  icon: Icon(Icons.add_photo_alternate),
                                  label: Text('Sélectionner une image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Formats supportés: JPG, PNG\nTaille recommandée: < 5MB',
                                  textAlign: TextAlign.center,
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

                    SizedBox(height: 10),

                    // Champ de description
// Dans le champ de description, remplacez cette partie :
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        style: TextStyle(color: _textColor, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Décrivez votre image...', // Changé: supprimé "(Optionnel)"
                          hintStyle: TextStyle(color: _hintColor),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        maxLines: 3,
                        maxLength: 500,
                        validator: (value) { // AJOUT: Validation obligatoire
                          if (value == null || value.isEmpty) {
                            return 'La description est obligatoire';
                          }
                          if (value.length < 10) {
                            return 'La description doit contenir au moins 10 caractères';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 15),

                    // Bouton de publication
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: onTap || (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name) || _imageBytes == null
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
                          onTap: onTap || (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name) || _imageBytes == null
                              ? null
                              : _publishPost,
                          child: Center(
                            child: onTap
                                ? LoadingAnimationWidget.flickr(
                              size: 30,
                              leftDotColor: Colors.white,
                              rightDotColor: _secondaryColor,
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
                                : _imageBytes == null
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'SÉLECTIONNEZ UNE IMAGE',
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
                                Icon(Icons.send, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'PUBLIER L\'IMAGE',
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