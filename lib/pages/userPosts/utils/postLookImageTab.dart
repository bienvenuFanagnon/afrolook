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

  @override
  void initState() {
    super.initState();
    postProvider = Provider.of<PostProvider>(context, listen: false);
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);

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
            child: CircularProgressIndicator(),
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

      await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());
      postProvider.addPostIdToAppDefaultData(postId);

      // Notifications
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
      Navigator.pop(context);
      Navigator.pop(pageContext);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Post publié avec succès !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green),
          ),
        ),
      );

    } catch (e) {
      print("Erreur : $e");
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

// class PostLookImageTab extends StatefulWidget {
//   /// Creates a new [PostLookImageTab] widget.
//   ///
//   /// The [imgBytes] parameter is required and contains the generated image
//   /// data to be displayed. The [generationTime] is optional and represents
//   /// the time taken to generate the image. If [showThumbnail] is true,
//   /// [rawOriginalImage] must be provided.
//   const PostLookImageTab({
//     super.key,
//     required this.imgBytes,
//     required this.canal,
//     this.generationTime,
//     this.rawOriginalImage,
//     this.generationConfigs,
//     this.showThumbnail = false,
//   }) : assert(
//           showThumbnail == false || rawOriginalImage != null,
//           'rawOriginalImage is required if you want to display a thumbnail.',
//         );
//
//   /// The image data in bytes to be displayed.
//    final Uint8List imgBytes;
//    final Canal? canal;
//
//   /// The time taken to generate the image, in milliseconds.
//   final double? generationTime;
//
//   /// Whether or not to show a thumbnail of the original image.
//   final bool showThumbnail;
//
//   /// The original raw image, required if [showThumbnail] is true.
//   final ui.Image? rawOriginalImage;
//
//   /// Optional configurations used during image generation.
//   final ImageGenerationConfigs? generationConfigs;
//
//   @override
//   State<PostLookImageTab> createState() => _PostLookImageTabState();
// }
//
// /// The state for the [PostLookImageTab] widget.
// ///
// /// This class manages the logic and display of the preview image and optional
// /// thumbnail, along with any associated generation information.
// class _PostLookImageTabState extends State<PostLookImageTab> with TickerProviderStateMixin {
//   final _valueStyle = const TextStyle(fontStyle: FontStyle.italic);
//
//   Future<ImageInfos>? _decodedImageInfos;
//   String _contentType = 'Unknown';
//   double? _generationTime;
//
//   Future<Uint8List?>? _highQualityGeneration;
//
//   late Uint8List? _imageBytes;
//
//   final _numberFormatter = NumberFormat();
//
//
//
//   final _formKey = GlobalKey<FormState>();
//
//   // GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   final TextEditingController _titreController = TextEditingController();
//
//   // final TextEditingController _descriptionController = TextEditingController();
//   late PostProvider postProvider =
//   Provider.of<PostProvider>(context, listen: false);
//   late UserAuthProvider authProvider =
//   Provider.of<UserAuthProvider>(context, listen: false);
//
//   late UserProvider userProvider =
//   Provider.of<UserProvider>(context, listen: false);
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   bool onTap = false;
//
//   int  limitePosts = 40;
//   File? _selectedFile;
//   final ImagePicker _picker = ImagePicker();
//   String? _selectedPostType; // Variable pour stocker la valeur sélectionnée (code)
//   String? _selectedPostLink; // Variable pour stocker la valeur sélectionnée (code)
//   String? _selectedPostTypeLibeller; // Variable pour stocker la valeur sélectionnée (code)
//
//   // Map des types de post avec code et libellé
//   final Map<String, Map<String, dynamic>> _postTypes = {
//
//     'LOOKS': {
//       'label': 'Looks',
//       'icon': Icons.style,
//     },
//     'ACTUALITES': {
//       'label': 'Actualités',
//       'icon': Icons.article,
//     },
//     'SPORT': {
//       'label': 'Sport',
//       'icon': Icons.sports,
//     },
//     'EVENEMENT': {
//       'label': 'Événement',
//       'icon': Icons.event,
//     },
//     'OFFRES': {
//       'label': 'Offres',
//       'icon': Icons.local_offer,
//     },
//     'GAMER': {
//       'label': 'Games story',
//       'icon': Icons.gamepad,
//     },
//   };
//
//   final Map<String, Map<String, dynamic>> _postLink = {
//     'OUI': {
//       'label': 'Avec de lien',
//       'icon': Icons.check_box,
//     },
//     'NON': {
//       'label': 'Pas de lien',
//       'icon': Icons.close,
//     },
//
//   };
//
//   // Capture an image or video
//   Future<void> _captureMedia(bool isPhoto) async {
//     final XFile? file = await (isPhoto
//         ? _picker.pickImage(source: ImageSource.camera)
//         : _picker.pickVideo(source: ImageSource.camera));
//
//     if (file != null) {
//       setState(() {
//         _selectedFile = File(file.path);
//       });
//     }
//   }
//
//   // Convert Uint8List to File
//   Future<File> _convertUint8ListToFile(Uint8List uint8List, String fileName) async {
//     // final Directory tempDir = await getTemporaryDirectory();
//     // final Directory? downloadsDir = await getDownloadsDirectory();
//     final Directory? downloadsDir = await getApplicationDocumentsDirectory();
//     // final Directory? downloadsDir = await getExternalStorageDirectory();
//
//     final String filePath = '${downloadsDir!.path}/afrolook_image${DateTime.now().microsecond}.png';
//     // printVm("filePath: $filePath");
//     final File file = File(filePath);
//
//     await file.writeAsBytes(uint8List);
//     printVm("**********************filePath: ${file.path}");
//
//     return file;
//   }
//   Future<void> save(BuildContext pagecontext, String description) async {
//
//
//     try {
//
//       if (_imageBytes! == null) {
//         setState(() {
//           onTap = false;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Veuillez choisir une image.',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//         );
//         return;
//       }
//       String? selectedPostLink='OUI';
//       // if(_selectedPostLink=='OUI'){
//       //   selectedPostLink=_selectedPostLink;
//       //   bool success = await processPublicashTransaction(
//       //     // userSendCadeau: authProvider.loginUserData,
//       //     context: context,
//       //     // authProvider: authProvider,
//       //     postProvider: postProvider,
//       //     appdata: authProvider.appDefaultData,
//       //   );
//       //
//       //   if (!success) {
//       //     print("Transaction échouée.");
//       //
//       //     return;
//       //
//       //   } else {
//       //     print("Transaction réussie !");
//       //
//       //   }
//       //
//       // }
//
//
//
//       setState(() {
//         onTap = true; // Désactive le bouton
//       });
//
//       // Afficher un indicateur de chargement
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (BuildContext context) {
//           return Center(
//             child: CircularProgressIndicator(),
//           );
//         },
//       );
//
//       String postId = FirebaseFirestore.instance.collection('Posts').doc().id;
//       String postMId = FirebaseFirestore.instance.collection('PostsMonetiser').doc().id;
//
//       Post post = Post()
//         ..user_id = authProvider.loginUserData.id
//         ..description = description
//         ..updatedAt = DateTime.now().microsecondsSinceEpoch
//         ..createdAt = DateTime.now().microsecondsSinceEpoch
//         ..status = PostStatus.VALIDE.name
//         ..type =isChallenge? PostType.CHALLENGE.name:isSwitched? PostType.PUB.name:PostType.POST.name
//         ..urlLink =isSwitched? _linkController.text:""
//         ..comments = 0
//         ..typeTabbar = _selectedPostType
//         ..isPostLink = selectedPostLink
//         ..nombrePersonneParJour = 60
//         ..dataType = PostDataType.IMAGE.name
//         ..likes = 0
//         ..loves = 0
//         ..id = postId
//         ..images = [];
//
//       if(widget.canal!=null){
//         post.canal_id=widget.canal!.id;
//         post.categorie="CANAL";
//       }
//
//       _convertUint8ListToFile(
//         _imageBytes!,
//         '${Path.basename(File.fromRawPath(_imageBytes!).path)}',
//       ).then((file) async {
//
//         // Générer un nom unique AVANT l'upload
//         final String uniqueFileName = const Uuid().v4();
//
// // Créer la référence avec le nom unique
//         Reference storageReference =
//         FirebaseStorage.instance.ref().child('post_media/$uniqueFileName.jpg');
//
// // Uploader le fichier
//         await storageReference.putFile(file);
//
// // Récupérer l'URL
//         String fileURL = await storageReference.getDownloadURL();
//
// // Extraire les couleurs (avec await direct)
//         final colorData = await extractColorsFromImageUrl(fileURL);
//         post.colorDomine = colorData['dominantColor'];
//         post.colorSecondaire = colorData['vibrantColor'];
//
// // Ajouter l'URL au post
//         post.images!.add(fileURL);
//         // Reference storageReference =
//         // FirebaseStorage.instance.ref().child('post_media/${file.path}');
//         // UploadTask uploadTask = storageReference.putFile(file);
//
//         // await uploadTask.whenComplete(() async {
//         //   String fileURL = await storageReference.getDownloadURL();
//         //
//         //   await extractColorsFromImageUrl(fileURL).then((value) {
//         //     post.colorDomine= value['dominantColor'];
//         //     post.colorSecondaire= value['vibrantColor'];
//         //
//         //   },);
//         //
//         //   post.images!.add(fileURL);
//
//           await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());
//           // await FirebaseFirestore.instance.collection('PostsMonetiser').doc(postMId).set(postMonetiser.toJson());
//
//           // authProvider.loginUserData.mesPubs = authProvider.loginUserData.mesPubs! + 1;
//           // await userProvider.updateUser(authProvider.loginUserData!);
//           // postProvider.listConstposts.add(post);
//         postProvider.addPostIdToAppDefaultData(postId);
//
//
//
//
//           if(widget.canal!=null){
//
//             authProvider.sendPushNotificationToUsers(
//               sender: authProvider.loginUserData,                          // L'utilisateur qui envoie la notification
//               message: "📢 ${getTabBarTypeMessage(_selectedPostType!, post)}", // Message dynamique
//               typeNotif: NotificationType.POST.name,                       // Type de notification
//               postId: post!.id!,                                           // ID du post
//               postType: PostDataType.IMAGE.name,                           // Type de post
//               chatId: '',                                                   // Vide si pas de chat
//               smallImage: widget.canal!.urlImage,                           // Image de notification (optionnelle)
//               isChannel: true,                                              // Indique que c’est un canal
//               channelTitle: widget.canal!.titre,                            // Titre du canal
//             );
//
//             //  authProvider
//             //     .getAllUsersOneSignaUserId()
//             //     .then(
//             //       (userIds) async {
//             //     if (userIds.isNotEmpty) {
//             //       await authProvider.sendNotification(
//             //         appName: "#${widget.canal!.titre}",
//             //           userIds: userIds,
//             //           smallImage: "${widget.canal!.urlImage}",
//             //           send_user_id: "${authProvider.loginUserData.id!}",
//             //           recever_user_id: "",
//             //           message: "📢 ${getTabBarTypeMessage(_selectedPostType!,post)}",
//             //           type_notif: NotificationType.POST.name,
//             //           post_id: "${post!.id!}",
//             //           post_type: PostDataType.IMAGE.name, chat_id: ''
//             //       );
//             //
//             //     }
//             //   },
//             // );
//              // 🔹 Mise à jour du canal
//              widget.canal!.updatedAt = DateTime.now().microsecondsSinceEpoch;
//
//              // 🔹 Incrémentation du nombre de publications
//              widget.canal!.publication = (widget.canal!.publication ?? 0) + 1;
//
//              // 🔹 Sauvegarde de la mise à jour dans Firestore
//              await FirebaseFirestore.instance
//                  .collection('Canaux')
//                  .doc(widget.canal!.id)
//                  .update({
//                'updatedAt': widget.canal!.updatedAt,
//                'publication': widget.canal!.publication,
//              });
//
//              // 🔹 Mise à jour locale via ton provider (si nécessaire)
//             //  postProvider.updateCanal(widget.canal!, context);
//             // widget.canal!.updatedAt =
//             //     DateTime.now().microsecondsSinceEpoch;
//             // postProvider.updateCanal( widget.canal!, context);
//           }
//           else{
//
//             authProvider
//                 .sendPushNotificationToUsers(
//               sender: authProvider.loginUserData,        // L'utilisateur qui envoie la notification
//               message: isChallenge?"📢 🎉 Nouveau challenge en ligne ! 🎉 ":"📢 @${authProvider.loginUserData.pseudo!} ${getTabBarTypeMessage(_selectedPostType!,post)}",
//               typeNotif: NotificationType.POST.name,     // Type de notification
//               postId: post!.id!,                         // ID du post
//               postType: PostDataType.IMAGE.name,         // Type de post
//               chatId: '',                                // Vide si pas de chat
//               smallImage: "${authProvider.loginUserData.imageUrl!}",
//             );
//             // await authProvider
//             //     .getAllUsersOneSignaUserId()
//             //     .then(
//             //       (userIds) async {
//             //     if (userIds.isNotEmpty) {
//             //
//             //       await authProvider.sendNotification(
//             //           userIds: userIds,
//             //           smallImage: "${authProvider.loginUserData.imageUrl!}",
//             //           send_user_id: "${authProvider.loginUserData.id!}",
//             //           recever_user_id: "",
//             //           message: isChallenge?"📢 🎉 Nouveau challenge en ligne ! 🎉 ":"📢 @${authProvider.loginUserData.pseudo!} ${getTabBarTypeMessage(_selectedPostType!,post)}",
//             //           type_notif: NotificationType.CHALLENGE.name,
//             //           post_id: "${post!.id!}",
//             //           post_type: PostDataType.IMAGE.name, chat_id: ''
//             //       );
//             //
//             //     }
//             //   },
//             // );
//           }
//
//
//
//           // postProvider.getPostsImages(limitePosts);
//           _imageBytes==null;
//
//           Navigator.pop(context); // Fermer le dialog de chargement
//           Navigator.pop(pagecontext); // Fermer la page
//
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'Le post a été validé avec succès !',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.green),
//               ),
//             ),
//           );
//       }).catchError((error) {
//         Navigator.pop(context); // Fermer le dialog de chargement en cas d'erreur
//         throw error; // Relancer pour le catch suivant
//       });
//     } catch (e) {
//       print("Erreur : $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'La validation du post a échoué. Veuillez réessayer.',
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.red),
//           ),
//         ),
//       );
//     } finally {
//       setState(() {
//         onTap = false; // Réactiver le bouton
//       });
//     }
//   }
//
//
//   Future<void> _uploadToFirebase(File file) async {
//     try {
//       final String fileName = 'uploads/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
//       final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
//       await storageRef.putFile(file);
//
//       final String downloadURL = await storageRef.getDownloadURL();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Fichier uploadé : $downloadURL')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Échec de l\'upload : $e')),
//       );
//     }
//   }
//
//   // Save the file locally and upload to Firebase
//   Future<void> _saveAndUploadMedia() async {
//     if (_selectedFile == null) return;
//
//     final Directory appDir = await getApplicationDocumentsDirectory();
//     final String savePath = '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
//
//     final File savedFile = await _selectedFile!.copy(savePath);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Fichier sauvegardé : $savePath')),
//     );
//
//     await _uploadToFirebase(savedFile);
//   }
//
//
//
//
//   void _setContentType() {
//     _contentType = lookupMimeType('', headerBytes: _imageBytes!) ?? 'Unknown';
//   }
//
//   String formatBytes(int bytes, [int decimals = 2]) {
//     if (bytes <= 0) return '0 B';
//     const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
//     var i = (log(bytes) / log(1024)).floor();
//     var size = bytes / pow(1024, i);
//     return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
//   }
//
//   late AnimationController _animationController;
//   late Animation<Offset> _animation;
//
//   double overlayHeight = 380;
//
//   late final homeViewModel = HomeViewModel();
//   late final _descriptionController = FlutterTaggerController(
//     text:
//     "",
//   );
//   late final _linkController = TextEditingController();
//   late final _focusNode = FocusNode();
//
//   bool isSwitched =false;
//   bool isChallenge =false;
//
//   void _focusListener() {
//     if (!_focusNode.hasFocus) {
//       _descriptionController.dismissOverlay();
//     }
//   }
//
//   // final _formKey = GlobalKey<FormState>();
//
//   // Variables pour stocker les informations du formulaire
//   TextEditingController descriptionController = TextEditingController();
//   TextEditingController descriptionCadeauxController = TextEditingController();
//   TextEditingController amountController = TextEditingController();
//   String selectedGiftType = "virtuel";
//   DateTime startDate = DateTime.now();
//   DateTime endDate = DateTime.now();
//   bool showForm = false;
//
//   // Méthode pour afficher le DatePicker
//   Future<void> _selectDate(BuildContext context, bool isStartDate) async {
//     final DateTime picked = await showDatePicker(
//       context: context,
//       initialDate: isStartDate ? startDate : endDate,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//     ) ?? DateTime.now();
//
//     setState(() {
//       if (isStartDate) {
//         startDate = picked;
//       } else {
//         endDate = picked;
//       }
//     });
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _generationTime = widget.generationTime;
//     _imageBytes = widget.imgBytes;
//     _setContentType();
//     _focusNode.addListener(_focusListener);
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 150),
//     );
//
//     _animation = Tween<Offset>(
//       begin: const Offset(0, 0.5),
//       end: Offset.zero,
//     ).animate(
//       CurvedAnimation(
//         parent: _animationController,
//         curve: Curves.easeInOut,
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     _focusNode.removeListener(_focusListener);
//     _focusNode.dispose();
//     _descriptionController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     var insets = MediaQuery.of(context).viewInsets;
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//     return LayoutBuilder(builder: (context, constraints) {
//       _decodedImageInfos ??=
//           decodeImageInfos(bytes: _imageBytes!, screenSize: constraints.biggest);
//
//       if (widget.showThumbnail) {
//         Stopwatch stopwatch = Stopwatch()..start();
//         _highQualityGeneration ??= generateHighQualityImage(
//           widget.rawOriginalImage!,
//
//           /// Set optional configs for the output
//           configs: widget.generationConfigs ?? const ImageGenerationConfigs(),
//           context: context,
//         ).then((res) {
//           if (res == null) return res;
//           _imageBytes = res;
//           _generationTime = stopwatch.elapsedMilliseconds.toDouble();
//           stopwatch.stop();
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             _decodedImageInfos = null;
//             _setContentType();
//             setState(() {});
//           });
//           return res;
//         });
//       }
//       return Scaffold(
//         backgroundColor: ConstColors.backgroundColor,
//         appBar: AppBar(
//           title: TextCustomerPageTitle(
//             titre: "Poster un look",
//             fontSize: SizeText.homeProfileTextSize,
//             couleur: ConstColors.textColors,
//             fontWeight: FontWeight.bold,
//           ),
//
//
//
//           //backgroundColor: Colors.blue,
//           actions: [
//             Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Logo(),
//             )
//           ],
//           //title: Text(widget.title),
//         ),
//         body: SingleChildScrollView(
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Stack(
//               children: [
//                 // Padding(
//                 //   padding: const EdgeInsets.all(8.0),
//                 //   child: Text("Type post: ${widget.canal==null?"Look":"Canal"}"),
//                 // ),
//                 Form(
//                   key: _formKey,
//                   child: Column(
//                     children: [
//                       TextFormField(
//                         controller: _descriptionController,
//                         decoration: InputDecoration(
//                           hintText: 'Légende',
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(10.0), // Add rounded corners
//                             borderSide: BorderSide(color: Colors.blue, width: 2.0), // Customize color and thickness
//                           ),
//                         ),
//                         // maxLines: 3,
//                         maxLength: 3000,
//                         maxLines: null, // Permet d'écrire sur plusieurs lignes
//                         keyboardType: TextInputType.multiline,
//                         validator: (value) {
//                           if (value!.isEmpty) {
//                             return 'La légende est obligatoire';
//                           }
//
//                           return null;
//                         },
//                       ),
//                       SizedBox(height: 20),
//
//                       // Liste déroulante pour le type de post
//                       DropdownButtonFormField<String>(
//                         decoration: InputDecoration(
//                           hintText: 'Type de post',
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(10.0), // Add rounded corners
//                             borderSide: BorderSide(color: Colors.green, width: 2.0), // Customize color and thickness
//                           ),
//                         ),
//
//                         value: _selectedPostType,
//                         onChanged: (String? newValue) {
//                           setState(() {
//                             _selectedPostType = newValue;
//                             printVm('_selectedPostType: ${_selectedPostType}');
//                             String? selectedLabel = _postTypes[_selectedPostType]?['label'];
//                             _selectedPostTypeLibeller=selectedLabel;
//
//                             printVm('selectedLabel: ${selectedLabel}');
//
//                           });
//                         },
//                         items: _postTypes.entries.map<DropdownMenuItem<String>>((entry) {
//                           return DropdownMenuItem<String>(
//                             value: entry.key, // Utilisez la clé (code) comme valeur
//                             child: Row(
//                               children: [
//                                 Icon(entry.value['icon'], color: Colors.green), // Icône
//                                 SizedBox(width: 10),
//                                 Text(entry.value['label']), // Libellé
//                               ],
//                             ),
//                           );
//                         }).toList(),
//                         validator: (value) {
//                           if (value == null || value.isEmpty) {
//                             return 'Veuillez sélectionner un type de post';
//                           }
//                           return null;
//                         },
//                       ),
//                       // SizedBox(
//                       //   height: 15.0,
//                       // ),
//                       // DropdownButtonFormField<String>(
//                       //   decoration: InputDecoration(
//                       //     labelText: 'Le post contient-il un lien ? Si oui, coût : 2 PC.',
//                       //     labelStyle: TextStyle(fontSize: 13),
//                       //     border: OutlineInputBorder(
//                       //       borderRadius: BorderRadius.circular(10.0), // Add rounded corners
//                       //       borderSide: BorderSide(color: Colors.green, width: 2.0), // Customize color and thickness
//                       //     ),
//                       //   ),
//                       //
//                       //   value: _selectedPostLink,
//                       //   onChanged: (String? newValue) {
//                       //     setState(() {
//                       //       _selectedPostLink = newValue;
//                       //       printVm('_selectedPostLink: ${_selectedPostLink}');
//                       //       // String? selectedLabel = _postTypes[_selectedPostType]?['label'];
//                       //       // _selectedPostTypeLibeller=selectedLabel;
//                       //       //
//                       //       // printVm('selectedLabel: ${selectedLabel}');
//                       //
//                       //     });
//                       //   },
//                       //   items: _postLink.entries.map<DropdownMenuItem<String>>((entry) {
//                       //     return DropdownMenuItem<String>(
//                       //       value: entry.key, // Utilisez la clé (code) comme valeur
//                       //       child: Row(
//                       //         children: [
//                       //           Icon(entry.value['icon'], color: Colors.green), // Icône
//                       //           SizedBox(width: 10),
//                       //           Text(entry.value['label']), // Libellé
//                       //         ],
//                       //       ),
//                       //     );
//                       //   }).toList(),
//                       //   validator: (value) {
//                       //     if (value == null || value.isEmpty) {
//                       //       return 'Veuillez sélectionner';
//                       //     }
//                       //     return null;
//                       //   },
//                       // ),
//                       SizedBox(
//                         height: 15.0,
//                       ),
//                       Visibility(
//                         visible: authProvider.loginUserData.role==UserRole.ADM.name,
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             const Text("Pub"),
//                             Switch(
//                               value: isSwitched,
//                               onChanged: (value) {
//                                 setState(() {
//                                   isSwitched = value;
//                                 });
//                               },
//                               activeColor: Colors.green, // Couleur quand activé
//                               inactiveThumbColor: Colors.grey, // Couleur quand désactivé
//                             ),
//                             const Text("Activé"),
//                           ],
//                         ),
//                       ),
//                       Visibility(
//                         visible: authProvider.loginUserData.role==UserRole.ADM.name,
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             const Text("Challenge"),
//                             Switch(
//                               value: isChallenge,
//                               onChanged: (value) {
//                                 setState(() {
//                                   isChallenge = value;
//                                 });
//                               },
//                               activeColor: Colors.green, // Couleur quand activé
//                               inactiveThumbColor: Colors.grey, // Couleur quand désactivé
//                             ),
//                             const Text("Activé"),
//                           ],
//                         ),
//                       ),
//                       SizedBox(
//                         height: 25.0,
//                       ),
//                       if (isChallenge)
//                       Column(
//                         children: [
//                           // Champ pour la description du cadeau
//                           TextFormField(
//                             controller: descriptionController,
//                             decoration: InputDecoration(labelText: 'Description du cadeau'),
//                             validator: (value) {
//                               if (value == null || value.isEmpty) {
//                                 return 'Veuillez entrer une description';
//                               }
//                               return null;
//                             },
//                           ),
//                           SizedBox(height: 16),
//
//                           // Sélection du type de cadeau (physique ou virtuel)
//                           DropdownButtonFormField<String>(
//                             value: selectedGiftType,
//                             decoration: InputDecoration(labelText: 'Type de cadeau'),
//                             items: [
//                               DropdownMenuItem(child: Text('Physique'), value: 'physique'),
//                               DropdownMenuItem(child: Text('Virtuel'), value: 'virtuel'),
//                             ],
//                             onChanged: (value) {
//                               setState(() {
//                                 selectedGiftType = value!;
//                               });
//                             },
//                             validator: (value) {
//                               if (value == null || value.isEmpty) {
//                                 return 'Veuillez choisir un type de cadeau';
//                               }
//                               return null;
//                             },
//                           ),
//                           SizedBox(height: 16),
//
//                           // Champ pour le montant à gagner
//                           TextFormField(
//                             controller: amountController,
//                             decoration: InputDecoration(labelText: 'Montant à gagner'),
//                             keyboardType: TextInputType.number,
//                             validator: (value) {
//                               if (value == null || value.isEmpty) {
//                                 return 'Veuillez entrer un montant';
//                               }
//                               return null;
//                             },
//                           ),
//                           SizedBox(height: 16),
//
//                           // Sélection de la date de début
//                           Row(
//                             children: [
//                               Text("Date de début: ${DateFormat('dd/MM/yyyy').format(startDate)}"),
//                               IconButton(
//                                 icon: Icon(Icons.calendar_today),
//                                 onPressed: () => _selectDate(context, true),
//                               ),
//                             ],
//                           ),
//                           SizedBox(height: 16),
//
//                           // Sélection de la date de fin
//                           Row(
//                             children: [
//                               Text("Date de fin: ${DateFormat('dd/MM/yyyy').format(endDate)}"),
//                               IconButton(
//                                 icon: Icon(Icons.calendar_today),
//                                 onPressed: () => _selectDate(context, false),
//                               ),
//                             ],
//                           ),
//                           SizedBox(height: 16),
//                         ],
//                       ),
//
//
//                       if (!widget.showThumbnail)
//                         ClipRRect(
//
//                           borderRadius:
//                           BorderRadius.all(Radius.circular(20)),
//                           child: Container(
//                               height: height*0.5,
//                               width: width,
//                               child: _buildFinalImage()),
//                         ),
//                       // else
//                       //   _buildThumbnailPreview(),
//                       // if (_generationTime != null) _buildGenerationInfos(),
//
//                       SizedBox(
//                         height: 60,
//                       ),
//                       // StatefulBuilder(
//                       //     builder: (BuildContext context, StateSetter setState) {
//                       //     return GestureDetector(
//                       //         onTap:onTap?(){}: () async {
//                       //           //_getImages();
//                       //           setState(() {
//                       //             onTap=true;
//                       //           });
//                       //           printVm('tap');
//                       //           if (_formKey.currentState!.validate()) {
//                       //
//                       //             save(context);
//                       //           }else{
//                       //             setState(() {
//                       //             onTap=false;
//                       //           });
//                       //
//                       //           }
//                       //         },
//                       //         child:onTap? Center(
//                       //           child: LoadingAnimationWidget.flickr(
//                       //             size: 20,
//                       //             leftDotColor: Colors.green,
//                       //             rightDotColor: Colors.black,
//                       //           ),
//                       //         ): PostsButtons(
//                       //           text: 'Créer votre look',
//                       //           hauteur: height*0.07,
//                       //           largeur: width*0.9,
//                       //           urlImage: 'assets/images/sender.png',
//                       //         ));
//                       //   }
//                       // ),
//                     ],
//                   ),
//                 ),
//                 // if (onTap)
//                   // Container(
//                   //   height: height*0.8,
//                   //   width: width,
//                   //   color: Colors.black.withOpacity(0.5),
//                   //   child: Center(
//                   //     child: CircularProgressIndicator(),
//                   //   ),
//                   // ),
//               ],
//             ),
//           ),
//         ),
//
//         bottomNavigationBar:  FlutterTagger(
//           controller: _descriptionController,
//           animationController: _animationController,
//
//           onSearch: (query, triggerChar) {
//             // if (triggerChar == "@") {
//             //   searchViewModel.searchUser(query);
//             // }
//             if (triggerChar == "#") {
//               searchViewModel.searchHashtag(query);
//             }
//           },
//           triggerCharacterAndStyles: const {
//             // "@": TextStyle(color: Colors.pinkAccent),
//             "#": TextStyle(color: Colors.green),
//           },
//           tagTextFormatter: (id, tag, triggerCharacter) {
//             return "$triggerCharacter$id#$tag#";
//           },
//           overlayHeight: overlayHeight,
//           overlay: SearchResultOverlay(
//             animation: _animation,
//             tagController: _descriptionController,
//           ),
//           builder: (context, containerKey) {
//             return CommentTextField(
//
//               focusNode: _focusNode,
//               containerKey: containerKey,
//               insets: insets,
//               controller: _descriptionController,
//               onSend:  onTap?(){}: () async {
//                 printVm("***************send comment;");
//
//
//                 //_getImages();
//                 String textComment=_descriptionController.text;
//                 printVm('textComment: ${textComment}');
//
//                 if (_formKey.currentState!.validate()) {
//                   save(context,textComment);
//
//
//                 }
//
//
//
//                 // _descriptionController.clear();
//               },
//             );
//           },
//         ),
//       );
//     });
//   }
//
//   Widget _buildFinalImage({Uint8List? bytes}) {
//     return InteractiveViewer(
//       maxScale: 7,
//       minScale: 1,
//       child: Image.memory(
//         bytes ?? _imageBytes!,
//         fit: BoxFit.contain,
//       ),
//     );
//   }
//
// }
