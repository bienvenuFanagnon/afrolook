// Dart imports:
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/home/homeWidget.dart';
import 'package:afrotok/pages/userPosts/operationPublicash.dart';
import 'package:fluttertagger/fluttertagger.dart';
import 'package:path/path.dart' as Path;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Flutter imports:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// Package imports:
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mime/mime.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeButtons.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../services/postService/massNotificationService.dart';
import '../hashtag/textHashTag/views/view_models/home_view_model.dart';
import '../hashtag/textHashTag/views/view_models/search_view_model.dart';
import '../hashtag/textHashTag/views/widgets/comment_text_field.dart';
import '../hashtag/textHashTag/views/widgets/search_result_overlay.dart';
import '../postColorsWidget.dart';
import '../utils/pixel_transparent_painter.dart';
import 'package:uuid/uuid.dart';/// A page that displays a preview of the generated image.
///
/// The [PostLookImageTab] widget is a stateful widget that shows a preview of
/// an image created using the provided [imgBytes]. It also supports showing
/// a thumbnail of the original image if [showThumbnail] is set to true.
///
/// The page can display additional information such as [generationTime], the
/// original raw image as [rawOriginalImage], and optional [generationConfigs]
/// used during the image creation process.
///
/// If [showThumbnail] is set to true, [rawOriginalImage] must be provided.
///
/// Example usage:
/// ```dart
/// PreviewImgPage(
///   imgBytes: generatedImageBytes,
///   generationTime: 1200,
///   rawOriginalImage: originalImage,
///   showThumbnail: true,
/// );
/// ```
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:fluttertagger/fluttertagger.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../hashtag/textHashTag/views/view_models/search_view_model.dart';
import '../hashtag/textHashTag/views/widgets/comment_text_field.dart';
import '../hashtag/textHashTag/views/widgets/search_result_overlay.dart';
import '../postColorsWidget.dart';

class PostLookImageTab extends StatefulWidget {
  final Uint8List imgBytes;
  final Canal? canal;
  final double? generationTime;
  final ui.Image? rawOriginalImage;
  final dynamic generationConfigs;
  final bool showThumbnail;

  const PostLookImageTab({
    super.key,
    required this.imgBytes,
    required this.canal,
    this.generationTime,
    this.rawOriginalImage,
    this.generationConfigs,
    this.showThumbnail = false,
  });

  @override
  State<PostLookImageTab> createState() => _PostLookImageTabState();
}

class _PostLookImageTabState extends State<PostLookImageTab> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late PostProvider postProvider;
  late UserAuthProvider authProvider;
  late UserProvider userProvider;

  bool onTap = false;
  bool isSwitched = false;
  bool isChallenge = false;
  bool _canPost = true;
  String _timeRemaining = '';

  String? _selectedPostType;
  String? _selectedPostTypeLibeller;

  Uint8List? _imageBytes;

  // Contrôles pour les challenges
  final TextEditingController _challengeDescriptionController = TextEditingController();
  final TextEditingController _challengeAmountController = TextEditingController();
  String _selectedGiftType = "virtuel";
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  final Map<String, Map<String, dynamic>> _postTypes = {
    'LOOKS': {'label': 'Looks', 'icon': Icons.style},
    'ACTUALITES': {'label': 'Actualités', 'icon': Icons.article},
    'SPORT': {'label': 'Sport', 'icon': Icons.sports},
    'EVENEMENT': {'label': 'Événement', 'icon': Icons.event},
    'OFFRES': {'label': 'Offres', 'icon': Icons.local_offer},
    'GAMER': {'label': 'Games story', 'icon': Icons.gamepad},
  };

  late AnimationController _animationController;
  late Animation<Offset> _animation;
  late final searchViewModel = SearchViewModel();
  late final FlutterTaggerController _taggerController = FlutterTaggerController(text: "");
  late MassNotificationService _notificationService;
  @override
  void initState() {
    super.initState();
    postProvider = Provider.of<PostProvider>(context, listen: false);
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    _notificationService = MassNotificationService();

    _imageBytes = widget.imgBytes;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _animation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _checkPostCooldown();
  }

  // Vérifier le délai entre les posts
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

  Future<File> _convertUint8ListToFile(Uint8List uint8List) async {
    final Directory? dir = await getApplicationDocumentsDirectory();
    final String filePath = '${dir!.path}/afrolook_image${DateTime.now().microsecondsSinceEpoch}.png';
    final File file = File(filePath);
    await file.writeAsBytes(uint8List);
    return file;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }
  Future<void> save(BuildContext pageContext, String description) async {
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

    try {
      if (_imageBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Veuillez choisir une image.',
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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Publication en cours...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      );

      String postId = FirebaseFirestore.instance.collection('Posts').doc().id;

      Post post = Post()
        ..user_id = authProvider.loginUserData.id
        ..description = description
        ..updatedAt = DateTime.now().microsecondsSinceEpoch
        ..createdAt = DateTime.now().microsecondsSinceEpoch
        ..status = PostStatus.VALIDE.name
        ..type = isChallenge ? PostType.CHALLENGE.name : isSwitched ? PostType.PUB.name : PostType.POST.name
        ..urlLink = isSwitched ? _linkController.text : ""
        ..comments = 0
        ..typeTabbar = _selectedPostType
        ..isPostLink = "NON"
        ..nombrePersonneParJour = 60
        ..dataType = PostDataType.IMAGE.name
        ..likes = 0
        ..loves = 0
        ..id = postId
        ..images = [];

      if (widget.canal != null) {
        post.canal_id = widget.canal!.id;
        post.categorie = "CANAL";
      }

      File file = await _convertUint8ListToFile(_imageBytes!);

      final String uniqueFileName = Uuid().v4();
      Reference storageReference = FirebaseStorage.instance.ref().child('post_media/$uniqueFileName.jpg');
      await storageReference.putFile(file);
      String fileURL = await storageReference.getDownloadURL();

      final colorData = await extractColorsFromImageUrl(fileURL);
      post.colorDomine = colorData['dominantColor'];
      post.colorSecondaire = colorData['vibrantColor'];
      post.images!.add(fileURL);

      // 🔥 ÉTAPE 1: Sauvegarder le post dans Firebase
      await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());
      // postProvider.addPostIdToAppDefaultData(postId);

      print('✅ Post créé avec ID: $postId');

      // 🔥 ÉTAPE 2: NOTIFIER LES ABONNÉS EN ARRIÈRE-PLAN
      if (authProvider.loginUserData.id != null) {
        _notifySubscribersWithProgress(postId, authProvider.loginUserData.id!);
      }

      // 🔥 ÉTAPE 3: NOTIFICATIONS PUSH EXISTANTES
      if (widget.canal != null) {
        authProvider.sendPushNotificationToUsers(
          sender: authProvider.loginUserData,
          message: "${getTabBarTypeMessage(_selectedPostType!, post)}",
          typeNotif: NotificationType.POST.name,
          postId: post.id!,
          postType: PostDataType.IMAGE.name,
          chatId: '',
          smallImage: widget.canal!.urlImage,
          isChannel: true,
          channelTitle: widget.canal!.titre,
        );

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
          message: isChallenge ? "📢 🎉 Nouveau challenge en ligne ! 🎉 " : "${getTabBarTypeMessage(_selectedPostType!, post)}",
          typeNotif: NotificationType.POST.name,
          postId: post.id!,
          postType: PostDataType.IMAGE.name,
          chatId: '',
          smallImage: "${authProvider.loginUserData.imageUrl!}",
        );
      }

      addPointsForAction(UserAction.post);

      // Fermer les dialogs et naviguer
      Navigator.pop(context); // Fermer le dialog de chargement
      Navigator.pop(pageContext); // Fermer la page

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Post publié avec succès ! Vos abonnés seront notifiés.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green),
          ),
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      print("❌ Erreur lors de la publication: $e");

      // Fermer le dialog en cas d'erreur
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la publication. Veuillez réessayer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    } finally {
      setState(() {
        onTap = false;
      });
    }
  }


  // 🔥 VERSION AVEC SUIVI DE PROGRÈS
  void _notifySubscribersWithProgress(String postId, String authorId) {
    final startTime = DateTime.now();

    Future.microtask(() async {
      try {
        print('🚀 Notification abonnés démarrée à ${startTime.toIso8601String()}');

        // Optionnel: suivre la progression dans Firestore
        await FirebaseFirestore.instance
            .collection('PostNotifications')
            .doc(postId)
            .set({
          'postId': postId,
          'authorId': authorId,
          'status': 'processing',
          'startedAt': FieldValue.serverTimestamp(),
          'totalSubscribers': 0, // Serait mis à jour si on suit la progression
        });

        await _notificationService.notifySubscribersAboutNewPost(
          postId: postId,
          authorId: authorId,
        );

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        print('✅ Notification terminée en ${duration.inSeconds} secondes');

        // Marquer comme terminé
        await FirebaseFirestore.instance
            .collection('PostNotifications')
            .doc(postId)
            .update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'durationSeconds': duration.inSeconds,
        });

      } catch (e) {
        print('❌ Erreur notification abonnés: $e');

        // Marquer comme échoué
        await FirebaseFirestore.instance
            .collection('PostNotifications')
            .doc(postId)
            .update({
          'status': 'failed',
          'error': e.toString(),
          'failedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
  // Future<void> save(BuildContext pageContext, String description) async {
  //   if (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           'Veuillez attendre $_timeRemaining avant de poster à nouveau',
  //           textAlign: TextAlign.center,
  //           style: TextStyle(color: Colors.red),
  //         ),
  //       ),
  //     );
  //     return;
  //   }
  //
  //   try {
  //     if (_imageBytes == null) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             'Veuillez choisir une image.',
  //             textAlign: TextAlign.center,
  //             style: TextStyle(color: Colors.red),
  //           ),
  //         ),
  //       );
  //       return;
  //     }
  //
  //     setState(() {
  //       onTap = true;
  //     });
  //
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (BuildContext context) {
  //         return Center(
  //           child: CircularProgressIndicator(),
  //         );
  //       },
  //     );
  //
  //     String postId = FirebaseFirestore.instance.collection('Posts').doc().id;
  //
  //     Post post = Post()
  //       ..user_id = authProvider.loginUserData.id
  //       ..description = description
  //       ..updatedAt = DateTime.now().microsecondsSinceEpoch
  //       ..createdAt = DateTime.now().microsecondsSinceEpoch
  //       ..status = PostStatus.VALIDE.name
  //       ..type = isChallenge ? PostType.CHALLENGE.name : isSwitched ? PostType.PUB.name : PostType.POST.name
  //       ..urlLink = isSwitched ? _linkController.text : ""
  //       ..comments = 0
  //       ..typeTabbar = _selectedPostType
  //       ..isPostLink = "NON"
  //       ..nombrePersonneParJour = 60
  //       ..dataType = PostDataType.IMAGE.name
  //       ..likes = 0
  //       ..loves = 0
  //       ..id = postId
  //       ..images = [];
  //
  //     if (widget.canal != null) {
  //       post.canal_id = widget.canal!.id;
  //       post.categorie = "CANAL";
  //     }
  //
  //     File file = await _convertUint8ListToFile(_imageBytes!);
  //
  //     final String uniqueFileName = Uuid().v4();
  //     Reference storageReference = FirebaseStorage.instance.ref().child('post_media/$uniqueFileName.jpg');
  //     await storageReference.putFile(file);
  //     String fileURL = await storageReference.getDownloadURL();
  //
  //     final colorData = await extractColorsFromImageUrl(fileURL);
  //     post.colorDomine = colorData['dominantColor'];
  //     post.colorSecondaire = colorData['vibrantColor'];
  //     post.images!.add(fileURL);
  //
  //     await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());
  //     postProvider.addPostIdToAppDefaultData(postId);
  //
  //     // Notifications
  //     if (widget.canal != null) {
  //       authProvider.sendPushNotificationToUsers(
  //         sender: authProvider.loginUserData,
  //         message: "${getTabBarTypeMessage(_selectedPostType!, post)}",
  //         typeNotif: NotificationType.POST.name,
  //         postId: post.id!,
  //         postType: PostDataType.IMAGE.name,
  //         chatId: '',
  //         smallImage: widget.canal!.urlImage,
  //         isChannel: true,
  //         channelTitle: widget.canal!.titre,
  //       );
  //
  //       widget.canal!.updatedAt = DateTime.now().microsecondsSinceEpoch;
  //       widget.canal!.publication = (widget.canal!.publication ?? 0) + 1;
  //
  //       await FirebaseFirestore.instance
  //           .collection('Canaux')
  //           .doc(widget.canal!.id)
  //           .update({
  //         'updatedAt': widget.canal!.updatedAt,
  //         'publication': widget.canal!.publication,
  //       });
  //     } else {
  //       authProvider.sendPushNotificationToUsers(
  //         sender: authProvider.loginUserData,
  //         message: isChallenge ? "📢 🎉 Nouveau challenge en ligne ! 🎉 " : "${getTabBarTypeMessage(_selectedPostType!, post)}",
  //         typeNotif: NotificationType.POST.name,
  //         postId: post.id!,
  //         postType: PostDataType.IMAGE.name,
  //         chatId: '',
  //         smallImage: "${authProvider.loginUserData.imageUrl!}",
  //       );
  //     }
  //     addPointsForAction(UserAction.post);
  //     Navigator.pop(context);
  //     Navigator.pop(pageContext);
  //
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           'Post publié avec succès !',
  //           textAlign: TextAlign.center,
  //           style: TextStyle(color: Colors.green),
  //         ),
  //       ),
  //     );
  //
  //   } catch (e) {
  //     print("Erreur : $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           'Erreur lors de la publication. Veuillez réessayer.',
  //           textAlign: TextAlign.center,
  //           style: TextStyle(color: Colors.red),
  //         ),
  //       ),
  //     );
  //   } finally {
  //     setState(() {
  //       onTap = false;
  //     });
  //   }
  // }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
    _taggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var insets = MediaQuery.of(context).viewInsets;
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: ConstColors.backgroundColor,
      appBar: AppBar(
        title: TextCustomerPageTitle(
          titre: "Poster un look",
          fontSize: SizeText.homeProfileTextSize,
          couleur: ConstColors.textColors,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.green,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Logo(),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Alerte restriction de temps
                    if (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Prochain post dans: $_timeRemaining',
                                style: TextStyle(color: Colors.orange[800]),
                              ),
                            ),
                          ],
                        ),
                      ),

                    TextFormField(
                      controller: _taggerController,
                      decoration: InputDecoration(
                        hintText: 'Légende',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      maxLength: 3000,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'La légende est obligatoire';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Type de post
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        hintText: 'Type de post',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
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
                              Icon(entry.value['icon'], color: Colors.green),
                              SizedBox(width: 10),
                              Text(entry.value['label']),
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

                    SizedBox(height: 15),

                    // Options admin
                    Visibility(
                      visible: authProvider.loginUserData.role == UserRole.ADM.name,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Pub"),
                          Switch(
                            value: isSwitched,
                            onChanged: (value) {
                              setState(() {
                                isSwitched = value;
                              });
                            },
                            activeColor: Colors.green,
                            inactiveThumbColor: Colors.grey,
                          ),
                          Text("Activé"),
                        ],
                      ),
                    ),

                    Visibility(
                      visible: authProvider.loginUserData.role == UserRole.ADM.name,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Challenge"),
                          Switch(
                            value: isChallenge,
                            onChanged: (value) {
                              setState(() {
                                isChallenge = value;
                              });
                            },
                            activeColor: Colors.green,
                            inactiveThumbColor: Colors.grey,
                          ),
                          Text("Activé"),
                        ],
                      ),
                    ),

                    SizedBox(height: 25),

                    // Formulaire challenge
                    if (isChallenge && authProvider.loginUserData.role == UserRole.ADM.name)
                      Column(
                        children: [
                          TextFormField(
                            controller: _challengeDescriptionController,
                            decoration: InputDecoration(labelText: 'Description du cadeau'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer une description';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedGiftType,
                            decoration: InputDecoration(labelText: 'Type de cadeau'),
                            items: [
                              DropdownMenuItem(child: Text('Physique'), value: 'physique'),
                              DropdownMenuItem(child: Text('Virtuel'), value: 'virtuel'),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedGiftType = value!;
                              });
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _challengeAmountController,
                            decoration: InputDecoration(labelText: 'Montant à gagner'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer un montant';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Text("Date de début: ${DateFormat('dd/MM/yyyy').format(_startDate)}"),
                              IconButton(
                                icon: Icon(Icons.calendar_today),
                                onPressed: () => _selectDate(context, true),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Text("Date de fin: ${DateFormat('dd/MM/yyyy').format(_endDate)}"),
                              IconButton(
                                icon: Icon(Icons.calendar_today),
                                onPressed: () => _selectDate(context, false),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                        ],
                      ),

                    // Aperçu image
                    if (!widget.showThumbnail)
                      ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        child: Container(
                          height: height * 0.5,
                          width: width,
                          child: InteractiveViewer(
                            maxScale: 7,
                            minScale: 1,
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                    SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: FlutterTagger(
        controller: _taggerController,
        animationController: _animationController,
        onSearch: (query, triggerChar) {
          if (triggerChar == "#") {
            searchViewModel.searchHashtag(query);
          }
        },
        triggerCharacterAndStyles: const {
          "#": TextStyle(color: Colors.green),
        },
        tagTextFormatter: (id, tag, triggerCharacter) {
          return "$triggerCharacter$id#$tag#";
        },
        overlayHeight: 380,
        overlay: SearchResultOverlay(
          animation: _animation,
          tagController: _taggerController,
        ),
        builder: (context, containerKey) {
          return CommentTextField(
            focusNode: _focusNode,
            containerKey: containerKey,
            insets: insets,
            controller: _taggerController,
            onSend: onTap || (!_canPost && authProvider.loginUserData.role != UserRole.ADM.name)
                ? () {}
                : () async {
              String textComment = _taggerController.text;
              if (_formKey.currentState!.validate()) {
                save(context, textComment);
              }
            },
          );
        },
      ),
    );
  }
}

