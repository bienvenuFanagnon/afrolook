import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../services/postService/massNotificationService.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../../pub/rewarded_ad_widget.dart';
import '../../user/userAbonnementPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
class UserPubVideo extends StatefulWidget {
  final Canal? canal;
  const UserPubVideo({super.key, required this.canal});

  @override
  State<UserPubVideo> createState() => _UserPubVideoState();
}

class _UserPubVideoState extends State<UserPubVideo> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _countrySearchController = TextEditingController();

  String? _localThumbnailPath;      // Chemin local pour l’aperçu
  String? _generatedThumbnailUrl;   // URL stockée après upload
  bool _isGeneratingThumbnail = false;
  bool _isUploadingThumbnail = false;
  bool onTap = false;
  double _uploadProgress = 0;
// À ajouter avec les autres variables d'état
  XFile? _customThumbnailFile;
  Uint8List? _customThumbnailBytes;
  bool _isUploadingCustomThumbnail = false;
  bool _useCustomThumbnail = false;
  // Gestion de la vidéo pour mobile (File) et web (Uint8List)
  XFile? _videoFile;
  Uint8List? _videoBytes;
  String? _videoFileName;

  bool isVideo = false;
  VideoPlayerController? _controller;

  final ImagePicker picker = ImagePicker();

  // Variables pour le type de post
  String? _selectedPostType;
  String? _selectedPostTypeLibeller;

  // Contrôle de temps entre les posts
  bool _canPost = true;
  String _timeRemaining = '';
// Variables pour le modal de qualité vidéo
  bool _showVideoQualityModal = false;
  bool _hasAcceptedVideoConditions = false;
  // Variables pour les restrictions
  int _maxCharacters = 300;
  int _maxVideoSizeMB = 100; // 20 Mo pour gratuit, 80 Mo pour premium
  // int _maxVideoSizeMB = 20; // 20 Mo pour gratuit, 80 Mo pour premium
  int _cooldownMinutes = 60;

  // Variables pour la sélection des pays
  List<AfricanCountry> _selectedCountries = [];
  List<AfricanCountry> _filteredCountries = [];
  bool _selectAllCountries = false;
  int _maxCountriesForFree = 2;
  bool _showCountrySelection = false;
  final FocusNode _countrySearchFocus = FocusNode();

  // Map des types de post avec code et libellé
  final Map<String, Map<String, dynamic>> _postTypes = {
    'LOOKS': {'label': 'Looks', 'icon': Icons.style},
    'ACTUALITES': {'label': 'Actualités', 'icon': Icons.article},
    'SPORT': {'label': 'Sport', 'icon': Icons.sports},
    'EVENEMENT': {'label': 'Événement', 'icon': Icons.event},
    'OFFRES': {'label': 'Offres', 'icon': Icons.local_offer},
    'GAMER': {'label': 'Games story', 'icon': Icons.gamepad},
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
  final Color _successColor = Color(0xFF4CAF50);
  late MassNotificationService _notificationService;
// Variables pour les restrictions de format
  double _minAspectRatio = 1.33;  // Minimum 4:3 (1.33)
  double _maxAspectRatio = 1.78;  // Maximum 16:9 (1.78)
  bool _isValidAspectRatio = true;
  String _aspectRatioError = '';
  // ✅ Ajoutez la clé pour la pub récompensée
  final GlobalKey<RewardedAdWidgetState> _rewardedAdKey = GlobalKey();
  bool _showRewardedAd = false;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    _notificationService = MassNotificationService();
    _filteredCountries = AfricanCountry.allCountries;

    _setupRestrictions();
    _checkPostCooldown();
    _checkVideoQualityModalStatus(); // ✅ AJOUTER CETTE LIGNE

    _countrySearchController.addListener(_filterCountries);

    // Par défaut, aucun pays n'est sélectionné
    _selectAllCountries = false;
    _selectedCountries.clear();
  }

  // Ajoute cette méthode après _getVideoSize()

  Future<void> _checkVideoQualityModalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenModal = prefs.getBool('has_seen_video_quality_modal') ?? false;

    if (!hasSeenModal && mounted) {
      // Attendre un peu que la page soit complètement chargée
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _showVideoQualityModal = true;
          _showVideoQualityDialog();
        }
      });
    }
  }

  void _showVideoQualityDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 24,
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header simplifié
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryColor, Color(0xFFFF5252)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.emoji_events, color: _secondaryColor, size: 40),
                          SizedBox(height: 8),
                          Text(
                            'GAGNEZ DE L\'ARGENT !',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _secondaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'JUSQU\'À 50€ (~32 800 FCFA) PAR VIDÉO',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Contenu scrollable
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Qualité vidéo
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.video_library, color: _primaryColor, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CONTENU DE QUALITÉ',
                                          style: TextStyle(
                                            color: _primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'Vidéos bien produites, instructives et utiles comme sur YouTube',
                                          style: TextStyle(color: _hintColor, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 12),

                            // Format recommandé
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.aspect_ratio, color: Colors.blue, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'FORMAT RECOMMANDÉ',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'Paysage (16:9) • Bonne résolution • Son clair',
                                          style: TextStyle(color: _hintColor, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 12),

                            // Contenu éligible
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.school, color: Colors.green, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CONTENU INSTRUCTIF',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '✓ Tutoriels & astuces\n'
                                              '✓ Formations & cours\n'
                                              '✓ Conseils professionnels\n'
                                              '✓ Expériences & témoignages',
                                          style: TextStyle(color: _hintColor, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 16),

                            // Gains potentiels
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_secondaryColor.withOpacity(0.2), _primaryColor.withOpacity(0.1)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _secondaryColor),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.monetization_on, color: _secondaryColor, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'GAINS POTENTIELS',
                                        style: TextStyle(
                                          color: _secondaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Avec des vidéos de qualité et instructives, '
                                        'vous pouvez gagner plus de 50€ (~32 800 FCFA) par vidéo '
                                        'selon l\'engagement et les vues.',
                                    style: TextStyle(color: _textColor, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 20),

                            // Checkbox
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _hasAcceptedVideoConditions,
                                    onChanged: (bool? value) {
                                      setStateDialog(() {
                                        _hasAcceptedVideoConditions = value ?? false;
                                      });
                                    },
                                    activeColor: _primaryColor,
                                    checkColor: Colors.white,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Je m\'engage à publier des vidéos de qualité et instructives',
                                      style: TextStyle(color: _textColor, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bouton
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey[800]!)),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (!_hasAcceptedVideoConditions) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Veuillez accepter les conditions',
                                  style: TextStyle(color: Colors.red),
                                ),
                                backgroundColor: _cardColor,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          _saveModalSeen();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'COMMENCER À POSTER',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveModalSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_video_quality_modal', true);
  }


  @override
  void dispose() {
    _countrySearchController.removeListener(_filterCountries);
    _countrySearchController.dispose();
    _countrySearchFocus.dispose();
    super.dispose();
    if (_controller != null) {
      _controller!.pause();
      _controller!.dispose();
    }
  }

  void _filterCountries() {
    final query = _countrySearchController.text.toLowerCase();
    setState(() {
      _filteredCountries = AfricanCountry.allCountries.where((country) {
        return country.name.toLowerCase().contains(query) ||
            country.code.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _selectCustomThumbnail() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _useCustomThumbnail = true;
        _isUploadingCustomThumbnail = true;
      });

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _customThumbnailBytes = bytes;
          _customThumbnailFile = image;
        });
      } else {
        setState(() {
          _customThumbnailFile = image;
          _customThumbnailBytes = null;
        });
      }

      setState(() {
        _isUploadingCustomThumbnail = false;
      });

    } catch (e) {
      print("Erreur sélection miniature: $e");
      setState(() {
        _isUploadingCustomThumbnail = false;
      });
    }
  }

  Future<String?> _uploadCustomThumbnail() async {
    try {
      if (_customThumbnailFile == null && _customThumbnailBytes == null) {
        return null;
      }

      final fileName = 'thumbnails/custom_thumb_${authProvider.loginUserData.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask;

      if (kIsWeb && _customThumbnailBytes != null) {
        uploadTask = ref.putData(
          _customThumbnailBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else if (_customThumbnailFile != null) {
        uploadTask = ref.putFile(File(_customThumbnailFile!.path));
      } else {
        return null;
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Erreur upload miniature personnalisée: $e');
      return null;
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
      _maxVideoSizeMB = 200; // 80 Mo pour premium
      _cooldownMinutes = 0; // Pas de cooldown pour les premium
      print('🌟 Mode Premium: 3000 caractères, 80 Mo, pas de cooldown');
    } else {
      // Abonnement Gratuit
      _maxCharacters = 300;
      _maxVideoSizeMB = 100; // 20 Mo pour gratuit
      // _maxVideoSizeMB = 20; // 20 Mo pour gratuit
      _cooldownMinutes = 60; // 60 minutes de cooldown
      print('🔒 Mode Gratuit: 300 caractères, 100 Mo, cooldown 60min');
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

  // Méthodes pour la sélection des pays
  void _toggleCountrySelection(AfricanCountry country) {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    if (!isPremium && !isAdmin) {
      // Pour les utilisateurs gratuits
      if (_selectedCountries.length >= _maxCountriesForFree &&
          !_selectedCountries.contains(country)) {
        _showCountryLimitModal();
        return;
      }
    }

    setState(() {
      if (_selectedCountries.contains(country)) {
        _selectedCountries.remove(country);
      } else {
        _selectedCountries.add(country);
      }
      _selectAllCountries = false;
    });
  }

  void _toggleSelectAllCountries() {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    // Vérifier si l'utilisateur peut sélectionner "Tous les pays"
    if (!isPremium && !isAdmin) {
      _showPremiumModal(
        title: 'Fonctionnalité Premium',
        message: 'L\'option "Tous les pays" est réservée aux abonnés Premium.\n'
            'Passez à Afrolook Premium pour atteindre toute l\'Afrique.',
        actionText: 'PASSER À PREMIUM',
      );
      return;
    }

    setState(() {
      if (_selectAllCountries) {
        _selectedCountries.clear();
      }
    });
  }

  void _showCountryLimitModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.lock, color: _primaryColor),
            SizedBox(width: 10),
            Text(
              'Limite de pays atteinte',
              style: TextStyle(
                color: _textColor,
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
              'L\'abonnement gratuit est limité à 2 pays maximum.\n'
                  'Passez à Afrolook Premium pour sélectionner tous les pays africains.',
              style: TextStyle(color: _hintColor),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _secondaryColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium, color: _secondaryColor),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Afrolook Premium',
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Pays illimités • 80 Mo vidéo • Pas de cooldown',
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'COMPRENDRE',
              style: TextStyle(color: _hintColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AbonnementScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _secondaryColor,
              foregroundColor: Colors.black,
            ),
            child: Text('PASSER À PREMIUM'),
          ),
        ],
      ),
    );
  }

  Widget _buildCountrySelectionModal() {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sélection des pays',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _textColor),
                      onPressed: () {
                        setState(() {
                          _showCountrySelection = false;
                          _countrySearchController.clear();
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(height: 10),
                // Statut de sélection
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPremium || isAdmin ? _secondaryColor.withOpacity(0.2) : _primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPremium || isAdmin ? _secondaryColor : _primaryColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPremium || isAdmin ? Icons.workspace_premium : Icons.lock,
                            size: 14,
                            color: isPremium || isAdmin ? _secondaryColor : _primaryColor,
                          ),
                          SizedBox(width: 6),
                          Text(
                            isPremium || isAdmin ? 'Pays illimités' : 'Max 2 pays',
                            style: TextStyle(
                              color: isPremium || isAdmin ? _secondaryColor : _primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      _selectAllCountries
                          ? '🌍 Toute l\'Afrique (Premium)'
                          : _selectedCountries.isEmpty
                          ? '⚠️ Aucun pays'
                          : '${_selectedCountries.length} pays sélectionné(s)',
                      style: TextStyle(
                        color: _selectedCountries.isEmpty && !_selectAllCountries
                            ? Colors.orange
                            : _hintColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                // Barre de recherche
                Container(
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: TextField(
                    controller: _countrySearchController,
                    focusNode: _countrySearchFocus,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un pays...',
                      hintStyle: TextStyle(color: _hintColor),
                      prefixIcon: Icon(Icons.search, color: _primaryColor),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Option "Tous les pays"
          Material(
            color: _cardColor,
            child: ListTile(
              onTap: _toggleSelectAllCountries,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectAllCountries ? _secondaryColor : Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: _selectAllCountries ? Colors.white : _hintColor,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    'Tous les pays africains',
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _secondaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PREMIUM',
                      style: TextStyle(
                        color: _secondaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                'Fonctionnalité Premium - Votre vidéo sera visible dans toute l\'Afrique',
                style: TextStyle(color: _hintColor),
              ),
              trailing: _selectAllCountries
                  ? Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _successColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
              )
                  : null,
            ),
          ),

          // Avertissement pour les gratuits
          if (!isPremium && !isAdmin)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                border: Border(
                  left: BorderSide(color: _primaryColor, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: _primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Abonnement gratuit : Sélectionnez 1 ou 2 pays maximum',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Divider(color: Colors.grey[800], height: 1),

          // Liste des pays
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _filteredCountries.length,
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                final isSelected = _selectedCountries.contains(country);
                final isDisabled = !isPremium && !isAdmin &&
                    _selectedCountries.length >= _maxCountriesForFree &&
                    !isSelected;

                return Material(
                  color: isSelected ? _primaryColor.withOpacity(0.1) : _cardColor,
                  child: ListTile(
                    onTap: isDisabled ? null : () => _toggleCountrySelection(country),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryColor : Colors.grey[800],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          country.flag,
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    title: Text(
                      country.name,
                      style: TextStyle(
                        color: isDisabled ? Colors.grey[600] : _textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'Code: ${country.code}',
                      style: TextStyle(
                        color: isDisabled ? Colors.grey[600] : _hintColor,
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    )
                        : isDisabled
                        ? Icon(
                      Icons.lock,
                      color: Colors.grey[600],
                      size: 16,
                    )
                        : null,
                  ),
                );
              },
            ),
          ),

          // Bouton de confirmation
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedCountries.clear();
                        _selectAllCountries = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _hintColor,
                      side: BorderSide(color: Colors.grey[700]!),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('RÉINITIALISER'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showCountrySelection = false;
                        _countrySearchController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('CONFIRMER'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountrySelectionCard() {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    // Déterminer le message d'affichage
    String displayMessage;
    if (_selectAllCountries) {
      displayMessage = '🌍 Toute l\'Afrique (Premium)';
    } else if (_selectedCountries.isEmpty) {
      displayMessage = '⚠️ Aucun pays sélectionné';
    } else {
      displayMessage = '${_selectedCountries.length} pays sélectionné(s)';
    }

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
        border: Border.all(
          color: _selectedCountries.isEmpty && !_selectAllCountries
              ? Colors.orange // Avertissement si aucun pays
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectAllCountries ? _secondaryColor : _primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _selectAllCountries
                          ? Icons.workspace_premium
                          : Icons.public,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visibilité de la vidéo',
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        displayMessage,
                        style: TextStyle(
                          color: _selectedCountries.isEmpty && !_selectAllCountries
                              ? Colors.orange
                              : _hintColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPremium || isAdmin ? _secondaryColor.withOpacity(0.2) : _primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPremium || isAdmin ? _secondaryColor : _primaryColor,
                  ),
                ),
                child: Text(
                  isPremium || isAdmin ? 'PREMIUM' : 'GRATUIT',
                  style: TextStyle(
                    color: isPremium || isAdmin ? _secondaryColor : _primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Avertissement si aucun pays sélectionné
          if (_selectedCountries.isEmpty && !_selectAllCountries)
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vous devez sélectionner au moins un pays',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Affichage des pays sélectionnés
          if (!_selectAllCountries && _selectedCountries.isNotEmpty)
            Column(
              children: [
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedCountries.take(3).map((country) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _primaryColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(country.flag),
                          SizedBox(width: 6),
                          Text(
                            country.name,
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (_selectedCountries.length > 3)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '+ ${_selectedCountries.length - 3} autres pays...',
                      style: TextStyle(
                        color: _hintColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showCountrySelection = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  FocusScope.of(context).requestFocus(_countrySearchFocus);
                });
              });
            },
            icon: Icon(Icons.edit_location, size: 18),
            label: Text('SÉLECTIONNER LES PAYS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor.withOpacity(0.2),
              foregroundColor: _primaryColor,
              minimumSize: Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
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
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.timer, color: _secondaryColor, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Temps d\'attente',
                        style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Prochain post dans: $_timeRemaining',
                        style: TextStyle(color: _hintColor, fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _secondaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_timeRemaining,
                    style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),

          SizedBox(height: 16),

          // ✅ Option de publicité récompensée
          Container(
            width: double.infinity,
            child: Column(
              children: [
                Divider(color: Colors.grey[800]),
                SizedBox(height: 12),
                Text('OU',
                    style: TextStyle(color: _hintColor, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                RewardedAdWidget(
                  key: _rewardedAdKey,
                  onUserEarnedReward: (reward) {
                    setState(() {
                      _canPost = true;
                      _timeRemaining = '';
                      _showRewardedAd = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Merci ! Vous pouvez poster maintenant !',
                            style: TextStyle(color: Colors.green)),
                        backgroundColor: _cardColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  onAdDismissed: () {
                    setState(() => _showRewardedAd = false);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_filled, color: Colors.black, size: 24),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PUBLICITÉ RÉCOMPENSÉE',
                                style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Regardez une pub pour poster maintenant',
                                style: TextStyle(color: Colors.black54, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text('Regardez une courte publicité pour\npublier immédiatement sans attendre',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _hintColor, fontSize: 11)),
              ],
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
      sizeText = 'Taille max: 100 Mo (Premium)';
      color = Color(0xFFFDB813);
    } else {
      sizeText = 'Taille max: 100 Mo (Gratuit)';
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
      infoText = 'Mode Admin : Tous pays • 200 Mo • Pas de restrictions';
      infoColor = Colors.green;
    } else if (isPremium) {
      infoText = 'Mode Premium : Tous pays • 100 Mo • Pas d\'attente';
      infoColor = Color(0xFFFDB813);
    } else {
      infoText = 'Mode Gratuit : Max 2 pays • 100 Mo • Attente 60min';
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

  void _showRewardedAdOption() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.timer, color: _secondaryColor),
            SizedBox(width: 10),
            Text('Temps d\'attente',
                style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vous devez attendre $_timeRemaining avant de pouvoir publier.',
              style: TextStyle(color: _hintColor),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _secondaryColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.play_circle_filled, color: _secondaryColor, size: 40),
                  SizedBox(height: 8),
                  Text('Regardez une publicité',
                      style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('et publiez immédiatement !',
                      style: TextStyle(color: _secondaryColor, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ATTENDRE', style: TextStyle(color: _hintColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _showRewardedAd = true);
              RewardedAdWidget.showAd(_rewardedAdKey);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _secondaryColor,
              foregroundColor: Colors.black,
            ),
            child: Text('REGARDER LA PUB'),
          ),
        ],
      ),
    );
  }

  void _showPremiumModal({String? reason, String? title, String? message, String? actionText}) {
    if (title == null) {
      if (reason == 'size') {
        title = 'Vidéo trop grande';
        // message = 'L\'abonnement gratuit est limité à 20 Mo.\nPassez à Afrolook Premium pour publier des vidéos jusqu\'à 80 Mo.';
        message = 'L\'abonnement gratuit est limité à 100 Mo.\nPassez à Afrolook Premium pour publier des vidéos jusqu\'à 200 Mo.';
        actionText = 'VOIR L\'ABONNEMENT';
      } else {
        title = 'Limite de caractères atteinte';
        message = 'L\'abonnement gratuit est limité à 300 caractères.\nPassez à Afrolook Premium pour écrire jusqu\'à 3000 caractères.';
        actionText = 'VOIR L\'ABONNEMENT';
      }
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
              title!,
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
              message!,
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
                          'Pays illimités • 80 Mo vidéo • Pas de cooldown',
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
            child: Text(actionText!),
          ),
        ],
      ),
    );
  }

  // Méthode pour obtenir la taille de la vidéo (compatible web et mobile)
  Future<int> _getVideoSize() async {
    if (kIsWeb) {
      // Pour le web : taille des bytes
      return _videoBytes?.length ?? 0;
    } else {
      // Pour mobile : taille du fichier
      return await _videoFile?.length() ?? 0;
    }
  }

  // Méthode pour sélectionner une vidéo (compatible web et mobile)
  Future<void> _getVideo() async {
    try {
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(minutes: 5),
      );

      if (video == null) return;

      // Vérifier la taille de la vidéo
      int size = await video.length();
      final sizeInMB = size / (1024 * 1024);
      final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

      // Vérification de la taille
      if (!isAdmin && !isPremium && sizeInMB > _maxVideoSizeMB) {
        _showPremiumModal(reason: 'size');
        return;
      }

      // Initialiser le contrôleur vidéo
      _controller = VideoPlayerController.file(File(video.path));

      // Attendre l'initialisation
      await _controller!.initialize();

      // ✅ VÉRIFICATION DU FORMAT (16:9 ou 4:3)
      final videoWidth = _controller!.value.size.width;
      final videoHeight = _controller!.value.size.height;
      final aspectRatio = videoWidth / videoHeight;

      // Format paysage minimum (4:3 = 1.33, 16:9 = 1.78)
      const double minAspectRatio = 1.33;

      print("📐 Dimensions vidéo: ${videoWidth}x${videoHeight}");
      print("📐 Ratio: ${aspectRatio.toStringAsFixed(2)}");

      // Vérifier si c'est du format portrait
      if (aspectRatio < 1.0) {
        _controller!.pause();
        _controller = null;

        _showFormatErrorDialog(
          title: 'Format portrait non accepté',
          message: 'Les vidéos en format portrait (téléphone vertical) ne sont pas acceptées.',
          aspectRatio: aspectRatio,
        );
        return;
      }

      // Vérifier si le format est assez large
      if (aspectRatio < minAspectRatio) {
        _controller!.pause();
        _controller = null;

        _showFormatErrorDialog(
          title: 'Format paysage requis',
          message: 'Veuillez utiliser le format paysage (16:9 ou 4:3).',
          aspectRatio: aspectRatio,
        );
        return;
      }

      // ✅ VIDÉO VALIDE - Continuer avec le traitement normal

      setState(() {
        _videoFile = video;
        _videoFileName = Path.basename(video.path);
      });

      await _controller!.setLooping(true);
      await _controller!.play();

      // Génération miniature locale
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 50,
        timeMs: 1000,
      );

      setState(() {
        _localThumbnailPath = thumbnailPath;
      });

      setState(() {}); // Mettre à jour l'UI

    } catch (e) {
      print("Erreur lors de la sélection de la vidéo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFormatErrorDialog({
    required String title,
    required String message,
    required double aspectRatio,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.aspect_ratio, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Format détecté: ${aspectRatio.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Formats acceptés:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '✓ 16:9 (1.78) - Format YouTube\n'
                        '✓ 4:3 (1.33) - Format classique',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '💡 Tournez votre téléphone en mode paysage',
                    style: TextStyle(
                      color: Colors.yellow[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
              'COMPRENDRE',
              style: TextStyle(color: _primaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Optionnel: ouvrir un tutoriel ou guide
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('RÉESSAYER'),
          ),
        ],
      ),
    );
  }
  Future<String?> _uploadThumbnail(File thumbnailFile) async {
    try {
      final fileName = 'thumbnails/thumb_${authProvider.loginUserData.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = ref.putFile(thumbnailFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Erreur upload miniature: $e');
      return null;
    }
  }

  Future<void> _generateAndUploadThumbnail(String postId, String videoUrl) async {
    if (_isGeneratingThumbnail || _isUploadingThumbnail) return;
    setState(() {
      _isGeneratingThumbnail = true;
    });
    try {
      // Générer la miniature à partir de l’URL Firebase (après upload)
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 1000,
      );
      if (thumbnailFile == null) return;

      setState(() {
        _isGeneratingThumbnail = false;
        _isUploadingThumbnail = true;
      });

      final thumbnailUrl = await _uploadThumbnail(File(thumbnailFile));
      if (thumbnailUrl != null && mounted) {
        // Mettre à jour le post avec l’URL de la miniature
        await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
          'thumbnail': thumbnailUrl,
        });
        setState(() {
          _generatedThumbnailUrl = thumbnailUrl;
        });
        print('✅ Miniature uploadée pour le post $postId');
      }
    } catch (e) {
      print('Erreur génération/upload miniature: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingThumbnail = false;
          _isUploadingThumbnail = false;
        });
      }
    }
  }
  // Méthode pour uploader la vidéo (compatible web et mobile)
  Future<String> _uploadVideo() async {
    try {
      if (_videoBytes == null && _videoFile == null) {
        throw Exception("Aucune vidéo sélectionnée");
      }

      // Générer un nom de fichier unique
      String fileName = 'video_${authProvider.loginUserData.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      Reference storageReference = FirebaseStorage.instance
          .ref()
          .child('post_videos/$fileName');

      UploadTask uploadTask;

      if (kIsWeb && _videoBytes != null) {
        // Pour le web : upload avec les bytes
        uploadTask = storageReference.putData(
          _videoBytes!,
          SettableMetadata(
            contentType: 'video/mp4',
            customMetadata: {
              'originalName': _videoFileName ?? 'web_video.mp4',
              'uploadedBy': authProvider.loginUserData.id ?? 'unknown',
            },
          ),
        );
      } else if (_videoFile != null) {
        // Pour mobile : upload avec le fichier
        uploadTask = storageReference.putFile(File(_videoFile!.path));
      } else {
        throw Exception("Format de vidéo non supporté");
      }

      // Suivre la progression
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print("Erreur lors de l'upload de la vidéo: $e");
      throw Exception("Échec de l'upload de la vidéo");
    }
  }

  Future<void> _publishVideo() async {
    if (widget.canal != null) {
      final currentUserId = authProvider.loginUserData.id;
      final isOwner = currentUserId == widget.canal!.userId;
      final isAdmin = widget.canal!.adminIds?.contains(currentUserId) == true;
      final canPost = widget.canal!.allowedPostersIds?.contains(currentUserId) == true;
      final allowAllMembers = widget.canal!.allowAllMembersToPost == true;
      final isMember = widget.canal!.usersSuiviId?.contains(currentUserId) == true;

      // Vérifier si l'utilisateur a la permission de poster
      if (!isAdmin) {
        if (!canPost) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Vous n\'êtes pas autorisé à poster dans ce canal',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
          return;
        }

        // Vérifier s'il est membre du canal
        if (!isMember) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Vous devez être abonné au canal pour poster',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
          return;
        }
      }
    }

    // Vérifier cooldown
    if (!_canPost && _cooldownMinutes > 0) {
      _showRewardedAdOption(); // Proposer la pub
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

      // Vérifier qu'au moins un pays est sélectionné
      final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

      if (!_selectAllCountries && _selectedCountries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Veuillez sélectionner au moins un pays',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
        return;
      }

      // Vérifier la limite de pays pour les gratuits
      if (!isPremium && !isAdmin) {
        if (_selectedCountries.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Veuillez sélectionner 1 ou 2 pays maximum',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
          return;
        }

        if (_selectedCountries.length > _maxCountriesForFree) {
          _showCountryLimitModal();
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
                    '${textLength} caractères • ${_selectAllCountries ? 'Toute l\'Afrique' : '${_selectedCountries.length} pays'}',
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
        final size = await _getVideoSize();
        final sizeInMB = size / (1024 * 1024);

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
            errorMessage = 'La vidéo est trop grande (plus de 100 Mo). Passez à Premium pour 200 Mo.';
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
        // if (videoDuration.inSeconds > 60 * 5) {
        //   Navigator.pop(context); // Fermer le dialog
        //   setState(() {
        //     onTap = false;
        //   });
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(
        //       content: Text(
        //         'La durée de la vidéo dépasse 5 min !',
        //         textAlign: TextAlign.center,
        //         style: TextStyle(color: Colors.red),
        //       ),
        //     ),
        //   );
        //   return;
        // }

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

        // Quand l'utilisateur coche "Tous les pays"
        if (_selectAllCountries) {
          post.availableCountries = ['ALL'];
        } else {
          // Quand il sélectionne des pays spécifiques
          post.availableCountries = _selectedCountries.map((c) => c.code).toList();
        }

        if (widget.canal != null) {
          post.canal_id = widget.canal!.id;
          post.categorie = "CANAL";
        }

        // Upload de la vidéo
        String fileURL = await _uploadVideo();
        post.url_media = fileURL;

        // Sauvegarder le post dans Firestore
        await FirebaseFirestore.instance
            .collection('Posts')
            .doc(postId)
            .set(post.toJson());
// Upload de la miniature (personnalisée ou générée)
        String? thumbnailUrl;
        if (_useCustomThumbnail && (_customThumbnailFile != null || _customThumbnailBytes != null)) {
          thumbnailUrl = await _uploadCustomThumbnail();
          if (thumbnailUrl != null && mounted) {
            await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
              'thumbnail': thumbnailUrl,
            });
            print('✅ Miniature personnalisée uploadée');
          }
        } else {
          // Générer la miniature automatiquement
          await _generateAndUploadThumbnail(postId, fileURL);
        }        print('✅ Post vidéo créé avec ID: $postId, ${_selectAllCountries ? 'Tous pays' : '${_selectedCountries.length} pays'}');

        // Notifications push
        if (widget.canal != null) {
          widget.canal!.updatedAt = DateTime.now().microsecondsSinceEpoch;
          widget.canal!.publicash = (widget.canal!.publicash ?? 0) + 1;
          postProvider.updateCanal(widget.canal!, context);

          authProvider.sendPushNotificationToUsers(
              sender: authProvider.loginUserData,
              message: "Video 🎥: ${post.description}",
              typeNotif: NotificationType.POST.name,
              postId: post.id!,
              postType: PostDataType.VIDEO.name,
              chatId: '',
              smallImage: widget.canal!.urlImage,
              isChannel: true,
              channelTitle: widget.canal!.titre,
              canal: widget.canal!
          );
        } else {
          authProvider.sendPushNotificationToUsers(
            sender: authProvider.loginUserData,
            message: "Video 🎥: ${post.description}",
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
          _videoFile = null;
          _videoBytes = null;
          _selectedCountries.clear();
          _selectAllCountries = false;
        });

        addPointsForAction(UserAction.post);

        // Fermer le dialog et afficher le succès
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        // Message de succès
        String successMessage = 'Vidéo publiée avec succès !';
        if (isAdmin) {
          successMessage = 'Vidéo publiée (Mode Admin) !';
        } else if (isPremium) {
          successMessage = 'Vidéo publiée avec Premium !';
        }

        String countryMessage = _selectAllCountries
            ? 'Visible dans toute l\'Afrique 🌍'
            : 'Visible dans ${_selectedCountries.length} pays';

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
                  '${textLength} caractères • ${sizeInMB.toStringAsFixed(1)} Mo • $countryMessage',
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

  // Widget pour la sélection de miniature personnalisée
  Widget _buildThumbnailSelector() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Miniature de la vidéo',
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Aperçu de la miniature
          if (_useCustomThumbnail && (_customThumbnailBytes != null || _customThumbnailFile != null))
            Container(
              height: 150,
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb && _customThumbnailBytes != null
                    ? Image.memory(
                  _customThumbnailBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                )
                    : _customThumbnailFile != null
                    ? Image.file(
                  File(_customThumbnailFile!.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                )
                    : Container(),
              ),
            )
          else if (_localThumbnailPath != null && !_useCustomThumbnail)
            Container(
              height: 150,
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_localThumbnailPath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),

          // Options de miniature
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploadingCustomThumbnail ? null : _selectCustomThumbnail,
                  icon: _isUploadingCustomThumbnail
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Icon(Icons.image, size: 18),
                  label: Text(
                    _useCustomThumbnail ? 'CHANGER LA MINIATURE' : 'CHOISIR UNE MINIATURE',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _primaryColor),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_useCustomThumbnail)
                SizedBox(width: 8),
              if (_useCustomThumbnail)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _useCustomThumbnail = false;
                        _customThumbnailFile = null;
                        _customThumbnailBytes = null;
                      });
                    },
                    icon: Icon(Icons.refresh, size: 18),
                    label: Text('UTILISER AUTO', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: BorderSide(color: Colors.orange),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 8),
          Text(
            'Choisissez une image personnalisée comme miniature ou utilisez la génération automatique',
            style: TextStyle(color: _hintColor, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  // Widget pour l'aperçu vidéo (compatible web et mobile)

  Widget _buildVideoPreview() {
    // Pour le web : afficher uniquement les infos sans le lecteur vidéo
    if (kIsWeb) {
      if (_videoFile == null && _videoBytes == null) return Container();

      return FutureBuilder<int>(
        future: _getVideoSize(),
        builder: (context, snapshot) {
          final sizeInMB = snapshot.hasData ? snapshot.data! / (1024 * 1024) : 0;
          final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
          final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

          Color sizeColor = Colors.green;
          if (!isAdmin && !isPremium && sizeInMB > 20) {
            sizeColor = Colors.red;
          } else if (isPremium && sizeInMB > 80) {
            sizeColor = Colors.orange;
          }

          return Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sizeColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec statut
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sizeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.videocam,
                        color: sizeColor,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vidéo sélectionnée',
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Prête à être publiée',
                            style: TextStyle(
                              color: _hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sizeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sizeColor),
                      ),
                      child: Text(
                        snapshot.hasData
                            ? '${sizeInMB.toStringAsFixed(1)} Mo'
                            : '...',
                        style: TextStyle(
                          color: sizeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Informations détaillées
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Nom du fichier
                      Row(
                        children: [
                          Icon(Icons.insert_drive_file, color: _hintColor, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _videoFileName ?? 'Vidéo',
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Statut de taille
                      Row(
                        children: [
                          Icon(
                            sizeInMB > _maxVideoSizeMB ? Icons.warning : Icons.check_circle,
                            color: sizeInMB > _maxVideoSizeMB ? Colors.orange : Colors.green,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sizeInMB > _maxVideoSizeMB
                                  ? 'Dépasse la limite autorisée'
                                  : 'Taille dans les limites',
                              style: TextStyle(
                                color: sizeInMB > _maxVideoSizeMB ? Colors.orange : Colors.green,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // Message d'information pour le web
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '✅ Vidéo prête à être publiée\n(L\'aperçu vidéo n\'est pas disponible sur le web)',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Avertissement si taille trop grande
                if (sizeInMB > _maxVideoSizeMB)
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cette vidéo dépasse la limite autorisée. Elle ne pourra pas être publiée.',
                            style: TextStyle(
                              color: Colors.red,
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
          );
        },
      );
    }

    // Pour mobile : garder l'aperçu normal avec VideoPlayer
    else {
      if (_controller == null) return Container();

      return FutureBuilder<int>(
        future: _getVideoSize(),
        builder: (context, snapshot) {
          final sizeInMB = snapshot.hasData ? snapshot.data! / (1024 * 1024) : 0;
          final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
          final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

          Color sizeColor = Colors.green;
          if (!isAdmin && !isPremium && sizeInMB > 20) {
            sizeColor = Colors.red;
          } else if (isPremium && sizeInMB > 80) {
            sizeColor = Colors.orange;
          }

          return Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sizeColor.withOpacity(0.3)),
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

                // Lecteur vidéo
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

                SizedBox(height: 6),
                _buildThumbnailSelector(),
                SizedBox(height: 6),

                // Contrôles vidéo
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _controller!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: _primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _controller!.value.isPlaying
                              ? _controller!.pause()
                              : _controller!.play();
                        });
                      },
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: _primaryColor,
                          bufferedColor: _secondaryColor,
                          backgroundColor: Colors.grey[800]!,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.volume_up,
                        color: _controller!.value.volume > 0 ? _primaryColor : _hintColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _controller!.setVolume(_controller!.value.volume > 0 ? 0 : 1);
                        });
                      },
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // Informations
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.play_circle_fill, color: _primaryColor, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Vidéo sélectionnée',
                          style: TextStyle(
                            color: _hintColor,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
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

                // Durée
                if (_controller!.value.isInitialized)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Durée: ${_formatDuration(_controller!.value.duration)}',
                      style: TextStyle(
                        color: _hintColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }
  }

// Méthode utilitaire pour formater la durée
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
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

                // Sélection des pays
                _buildCountrySelectionCard(),

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
                        // Widget d'information sur le format requis
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.aspect_ratio, color: Colors.blue, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Format vidéo requis',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Format paysage uniquement (16:9 ou 4:3)\n'
                                          '• Vidéos portrait (format téléphone) non acceptées\n'
                                          '• Rotation automatique de votre téléphone recommandée',
                                      style: TextStyle(
                                        color: Colors.blue[300],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        //
                        // // Information sur la durée
                        // Container(
                        //   padding: EdgeInsets.all(12),
                        //   decoration: BoxDecoration(
                        //     color: Colors.blue.withOpacity(0.1),
                        //     borderRadius: BorderRadius.circular(12),
                        //     border: Border.all(color: Colors.blue),
                        //   ),
                        //   child: Row(
                        //     children: [
                        //       Icon(Icons.timer, color: Colors.blue, size: 16),
                        //       SizedBox(width: 8),
                        //       Expanded(
                        //         child: Text(
                        //           'Durée maximale: 5 minutes pour tous les utilisateurs',
                        //           style: TextStyle(
                        //             color: Colors.blue,
                        //             fontSize: 12,
                        //             fontWeight: FontWeight.w500,
                        //           ),
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),

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
                                    : _selectedCountries.isEmpty && !_selectAllCountries
                                    ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.warning, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'SÉLECTIONNEZ UN PAYS',
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
                                    SizedBox(width: 4),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _selectAllCountries ? '🌍' : '${_selectedCountries.length}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
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
                SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Modal de sélection des pays
        if (_showCountrySelection)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCountrySelectionModal(),
          ),
      ],
    );
  }
}

