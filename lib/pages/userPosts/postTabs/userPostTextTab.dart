import 'dart:async';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertagger/fluttertagger.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../../constant/buttons.dart';
import '../../../constant/sizeButtons.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../services/postService/massNotificationService.dart';


class UserPubText extends StatefulWidget {
  final Canal? canal;
  UserPubText({super.key, required this.canal});

  @override
  State<UserPubText> createState() => _UserPubTextState();
}

class _UserPubTextState extends State<UserPubText> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();

  late PostProvider postProvider = Provider.of<PostProvider>(context, listen: false);
  late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTap = false;

  // Contrôle de temps entre les posts
  bool _canPost = true;
  String _timeRemaining = '';

  // Variables pour le type de post
  String? _selectedPostType;
  String? _selectedPostTypeLibeller;

  // Map des types de post avec code et libellé
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
      setState(() {
        onTap = true;
      });

      try {
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

        Post post = Post();
        post.user_id = authProvider.loginUserData.id;
        post.description = _descriptionController.text;
        post.updatedAt = DateTime.now().microsecondsSinceEpoch;
        post.createdAt = DateTime.now().microsecondsSinceEpoch;
        post.status = PostStatus.VALIDE.name;
        post.type = PostType.POST.name;
        post.comments = 0;
        post.nombrePersonneParJour = 60;
        post.dataType = PostDataType.TEXT.name;
        post.typeTabbar = _selectedPostType;
        post.likes = 0;
        post.loves = 0;
        post.feedScore = 0.0;
        post.id = postId;
        post.images = [];

        if (widget.canal != null) {
          post.canal_id = widget.canal!.id;
          post.categorie = "CANAL";
        }

        // 🔥 ÉTAPE 1: Sauvegarder le post dans Firestore
        await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());

        print('✅ Post texte créé avec ID: $postId');

        // 🔥 ÉTAPE 2: NOTIFIER LES ABONNÉS EN ARRIÈRE-PLAN
        if (authProvider.loginUserData.id != null) {
          _notifySubscribersInBackground(postId, authProvider.loginUserData.id!);
        }

        // Nettoyer le formulaire
        _descriptionController.clear();
        setState(() {
          onTap = false;
        });

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
            postType: PostDataType.TEXT.name,
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
            postType: PostDataType.TEXT.name,
            chatId: '',
            smallImage: authProvider.loginUserData.imageUrl,
            isChannel: false,
          );
        }

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
                      'Post publié avec succès !',
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

      _checkPostCooldown();
      setState(() {});
    }
  }

  // 🔥 MÉTHODE POUR NOTIFIER LES ABONNÉS EN ARRIÈRE-PLAN
  void _notifySubscribersInBackground(String postId, String authorId) {
    // Démarrer dans un Future séparé pour ne pas bloquer l'interface
    Future.microtask(() async {
      try {
        print('🚀 Démarrage notification abonnés pour le post texte $postId');
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
          'postType': 'TEXT',
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
          'postType': 'TEXT',
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
                    child: Icon(Icons.text_fields, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publication Texte',
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
                    Text(
                      'Partagez vos pensées',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Grand champ de texte
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        style: TextStyle(color: _textColor, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Exprimez-vous... Partagez vos pensées, vos idées, vos moments...',
                          hintStyle: TextStyle(color: _hintColor),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        maxLength: 3000,
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Le texte est obligatoire';
                          }
                          if (value.length < 10) {
                            return 'Le texte doit contenir au moins 10 caractères';
                          }
                          return null;
                        },
                      ),
                    ),

                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${_descriptionController.text.length}/3000',
                          style: TextStyle(
                            color: _descriptionController.text.length > 2500
                                ? _primaryColor
                                : _hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'PUBLIER',
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