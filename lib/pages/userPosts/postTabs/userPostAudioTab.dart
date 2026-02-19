import 'dart:async';
import 'dart:io';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as Path;
import 'package:iconsax/iconsax.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../services/postService/massNotificationService.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../../pub/rewarded_ad_widget.dart';
import '../../user/userAbonnementPage.dart';
import '../../widgetGlobal.dart';

class UserPostLookAudioTab extends StatefulWidget {
  final Canal? canal;
  const UserPostLookAudioTab({
    super.key,
    required this.canal,
  });

  @override
  State<UserPostLookAudioTab> createState() => _UserPostLookAudioTabState();
}

class _UserPostLookAudioTabState extends State<UserPostLookAudioTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _countrySearchController = TextEditingController();

  late PostProvider postProvider;
  late UserAuthProvider authProvider;
  late UserProvider userProvider;

  bool onTap = false;
  bool _canPost = true;
  String _timeRemaining = '';

  String? _selectedPostType;

  // ========== GESTION AUDIO ==========
  bool _isRecording = false;
  bool _isSendingAudio = false;
  bool _isPlaying = false;
  bool _isAudioLoading = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Fichier audio sélectionné/enregistré
  File? _audioFile;
  String? _audioFileName;
  int? _audioDuration;

  // Lecture audio
  Duration _currentAudioPosition = Duration.zero;
  Duration _currentAudioDuration = Duration.zero;

  // ========== IMAGE DE COUVERTURE ==========
  File? _coverImage;
  String? _coverImageName;

  // ========== SÉLECTION DES PAYS ==========
  List<AfricanCountry> _selectedCountries = [];
  List<AfricanCountry> _filteredCountries = [];
  bool _selectAllCountries = false;
  int _maxCountriesForFree = 2;
  bool _showCountrySelection = false;
  final FocusNode _countrySearchFocus = FocusNode();

  // Limites
  final int _maxAudioDuration = 180; // 3 minutes en secondes
  final int _maxAudioSize = 10 * 1024 * 1024; // 10 MB

  final Map<String, Map<String, dynamic>> _postTypes = {
    'LOOKS': {'label': 'Looks', 'icon': Icons.style},
    'ACTUALITES': {'label': 'Actualités', 'icon': Icons.article},
    'SPORT': {'label': 'Sport', 'icon': Icons.sports},
    'EVENEMENT': {'label': 'Événement', 'icon': Icons.event},
    'OFFRES': {'label': 'Offres', 'icon': Icons.local_offer},
    'GAMER': {'label': 'Games story', 'icon': Icons.gamepad},
  };


  // Couleurs
  final Color _primaryColor = Color(0xFFE21221);
  final Color _secondaryColor = Color(0xFFFFD600);
  final Color _backgroundColor = Color(0xFF121212);
  final Color _cardColor = Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;
  final Color _successColor = Color(0xFF4CAF50);
  final Color _audioColor = Color(0xFF2196F3);

  late MassNotificationService _notificationService;

  // Restrictions
  int _maxCharacters = 300;
  int _cooldownMinutes = 60;


// ✅ Ajoutez la clé pour la pub récompensée
  final GlobalKey<RewardedAdWidgetState> _rewardedAdKey = GlobalKey();
  bool _showRewardedAd = false;

  @override
  void initState() {
    super.initState();
    postProvider = Provider.of<PostProvider>(context, listen: false);
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    _notificationService = MassNotificationService();
    _filteredCountries = AfricanCountry.allCountries;

    _setupRestrictions();
    _checkPostCooldown();
    _setupAudioListener();

    _countrySearchController.addListener(_filterCountries);
  }

  void _setupAudioListener() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _currentAudioDuration = duration;
          _audioDuration = duration.inSeconds;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentAudioPosition = position;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentAudioPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    _countrySearchController.removeListener(_filterCountries);
    _countrySearchController.dispose();
    _countrySearchFocus.dispose();
    super.dispose();
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

  void _setupRestrictions() {
    final user = authProvider.loginUserData;
    final abonnement = user.abonnement;

    if (user.role == UserRole.ADM.name) {
      _maxCharacters = 5000;
      _cooldownMinutes = 0;
      print('🔓 Mode Admin');
      return;
    }

    final isPremium = AbonnementUtils.isPremiumActive(abonnement);

    if (isPremium) {
      _maxCharacters = 3000;
      _cooldownMinutes = 0;
      print('🌟 Mode Premium');
    } else {
      _maxCharacters = 300;
      // ✅ POUR LES TESTS : Garder cooldown mais on le simule dans initState
      _cooldownMinutes = 60; // Garder la valeur normale
      print('🔒 Mode Gratuit');
    }
  }

  Future<void> _checkPostCooldown() async {
    if (_cooldownMinutes == 0) {
      setState(() => _canPost = true);
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
        final cooldownInMicroseconds = _cooldownMinutes * 60 * 1000000;

        if (now - lastPostTime < cooldownInMicroseconds) {
          _startCooldownTimer(cooldownInMicroseconds - (now - lastPostTime));
        } else {
          setState(() => _canPost = true);
        }
      } else {
        setState(() => _canPost = true);
      }
    } catch (e) {
      setState(() => _canPost = true);
    }
  }

  void _startCooldownTimer(int remainingMicroseconds) {
    setState(() => _canPost = false);
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

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
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
  // ========== GESTION AUDIO ==========

  // Enregistrement audio
  Future<void> _startRecording() async {
    try {
      if (kIsWeb) {
        showWebUnavailableModal(context,'Enregistrement audio');
        return;
      }
      if (await Permission.microphone.request().isGranted) {
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
          _audioFile = null;
          _audioFileName = null;
          _audioDuration = null;
        });

        _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration = timer.tick;
            });
            if (_recordingDuration >= _maxAudioDuration) {
              _stopRecording();
            }
          }
        });

        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000, // 64 kbps pour bonne qualité
          ),
          path: path,
        );
      } else {
        _showErrorSnackbar("Permission microphone refusée");
      }
    } catch (e) {
      _showErrorSnackbar("Erreur lors de l'enregistrement");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          setState(() {
            _audioFile = file;
            _audioFileName = 'Enregistrement $_recordingDuration s';
            _audioDuration = _recordingDuration;
            _isRecording = false;
          });
        }
      } else {
        setState(() => _isRecording = false);
      }
    } catch (e) {
      _showErrorSnackbar("Erreur lors de l'arrêt");
      setState(() => _isRecording = false);
    }
  }

  // Import audio depuis la galerie
  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null) {
        final filePath = result.files.single.path;
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;

        if (filePath == null) return;

        // Vérifier la taille
        if (fileSize > _maxAudioSize) {
          _showErrorSnackbar("Fichier trop volumineux (max 10 MB)");
          return;
        }

        final file = File(filePath);

        // Obtenir la durée du fichier audio
        final duration = await _getAudioDuration(file);

        if (duration > _maxAudioDuration) {
          _showErrorSnackbar("Audio trop long (max 3 minutes)");
          return;
        }

        setState(() {
          _audioFile = file;
          _audioFileName = fileName;
          _audioDuration = duration;
        });
      }
    } catch (e) {
      _showErrorSnackbar("Erreur lors de la sélection du fichier");
    }
  }

  Future<int> _getAudioDuration(File file) async {
    try {
      final player = AudioPlayer();
      await player.setSource(DeviceFileSource(file.path));
      final duration = await player.getDuration();
      await player.dispose();
      return duration?.inSeconds ?? 0;
    } catch (e) {
      print("Erreur obtention durée: $e");
      return 0;
    }
  }

  // Lecture audio
  Future<void> _playAudio() async {
    if (_audioFile == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        setState(() {
          _isAudioLoading = true;
        });

        // IMPORTANT: Utiliser correctement DeviceFileSource
        await _audioPlayer.play(DeviceFileSource(_audioFile!.path));

        setState(() {
          _isPlaying = true;
          _isAudioLoading = false;
        });
      }
    } catch (e) {
      print("Erreur lecture audio: $e");
      _showErrorSnackbar("Erreur lors de la lecture");
      setState(() {
        _isPlaying = false;
        _isAudioLoading = false;
      });
    }
  }

  void _seekAudio(double value) {
    _audioPlayer.seek(Duration(seconds: value.toInt()));
  }

  void _removeAudio() {
    // Arrêter la lecture si en cours
    if (_isPlaying) {
      _audioPlayer.stop();
    }

    setState(() {
      _audioFile = null;
      _audioFileName = null;
      _audioDuration = null;
      _recordingDuration = 0;
      _isPlaying = false;
      _currentAudioPosition = Duration.zero;
      _currentAudioDuration = Duration.zero;
    });
  }

  // ========== GESTION IMAGE DE COUVERTURE ==========

  Future<void> _pickCoverImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        setState(() {
          _coverImage = File(image.path);
          _coverImageName = image.name;
        });
      }
    } catch (e) {
      _showErrorSnackbar("Erreur lors de la sélection de l'image");
    }
  }

  void _removeCoverImage() {
    setState(() {
      _coverImage = null;
      _coverImageName = null;
    });
  }

  // ========== SÉLECTION PAYS ==========

  void _toggleCountrySelection(AfricanCountry country) {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    if (!isPremium && !isAdmin) {
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
      // _selectAllCountries = !_selectAllCountries;
      // if (_selectAllCountries) {
      //   _selectedCountries.clear();
      // }

      _selectedCountries = List.from(_filteredCountries);

    });
  }

  void _showCountryLimitModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock, color: _primaryColor),
            SizedBox(width: 10),
            Text('Limite de pays atteinte',
                style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
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
                        Text('Afrolook Premium',
                            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
                        Text('Pays illimités • Audio 3 min • Pas de cooldown',
                            style: TextStyle(color: _hintColor, fontSize: 12)),
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
            child: Text('COMPRENDRE', style: TextStyle(color: _hintColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => AbonnementScreen()));
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
                    Text('Sélection des pays',
                        style: TextStyle(color: _textColor, fontSize: 20, fontWeight: FontWeight.bold)),
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
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPremium || isAdmin ? _secondaryColor.withOpacity(0.2) : _primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isPremium || isAdmin ? _secondaryColor : _primaryColor),
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
                          ? '🌍 Tous les pays'
                          : '${_selectedCountries.length} pays sélectionné(s)',
                      style: TextStyle(color: _hintColor, fontSize: 14),
                    ),
                  ],
                ),
                SizedBox(height: 15),
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
          Material(
            color: _cardColor,
            child: ListTile(
              onTap: _toggleSelectAllCountries,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectAllCountries ? _primaryColor : Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: _selectAllCountries ? Colors.white : _hintColor,
                ),
              ),
              title: Row(
                children: [
                  Text('Tous les pays africains',
                      style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _secondaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('PREMIUM',
                        style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              subtitle: Text(
                'Fonctionnalité Premium - Votre post sera visible dans toute l\'Afrique',
                style: TextStyle(color: _hintColor),
              ),
              trailing: _selectAllCountries
                  ? Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _successColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: 20),
              )
                  : null,
            ),
          ),
          Divider(color: Colors.grey[800], height: 1),
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
                        child: Text(country.flag, style: TextStyle(fontSize: 20)),
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
                      child: Icon(Icons.check, color: Colors.white, size: 16),
                    )
                        : isDisabled
                        ? Icon(Icons.lock, color: Colors.grey[600], size: 16)
                        : null,
                  ),
                );
              },
            ),
          ),
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
                        _selectAllCountries = true;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _hintColor,
                      side: BorderSide(color: Colors.grey[700]!),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        border: Border.all(
          color: _selectedCountries.isEmpty && !_selectAllCountries
              ? Colors.orange
              : Colors.transparent,
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
                      _selectAllCountries ? Icons.workspace_premium : Icons.public,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visibilité du post',
                          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(displayMessage,
                          style: TextStyle(color: _hintColor, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPremium || isAdmin ? _secondaryColor.withOpacity(0.2) : _primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isPremium || isAdmin ? _secondaryColor : _primaryColor),
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
                    child: Text('Vous devez sélectionner au moins un pays',
                        style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ),
                ],
              ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text('Type de publication',
                  style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
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
              setState(() => _selectedPostType = newValue);
            },
            items: _postTypes.entries.map<DropdownMenuItem<String>>((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    Icon(entry.value['icon'] as IconData, color: _primaryColor, size: 18),
                    SizedBox(width: 12),
                    Text(entry.value['label'], style: TextStyle(color: _textColor)),
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

  Widget _buildAudioSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _audioFile != null ? _audioColor : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.audiotrack, color: _audioColor, size: 20),
              SizedBox(width: 8),
              Text('Audio (obligatoire)',
                  style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _audioColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Max 3 min',
                    style: TextStyle(color: _audioColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: 16),

          if (_isRecording) ...[
            // Mode enregistrement
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.red, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Enregistrement... $_recordingDuration s',
                        style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _recordingDuration / _maxAudioDuration,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _stopRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 45),
                    ),
                    child: Text('ARRÊTER L\'ENREGISTREMENT'),
                  ),
                ],
              ),
            ),
          ] else if (_audioFile == null) ...[
            // Pas d'audio - choix entre enregistrer ou importer
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startRecording,
                    icon: Icon(Icons.mic, size: 20),
                    label: Column(
                      children: [
                        Text('Enregistrer'),
                        Text('(max 3 min)', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _audioColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickAudioFile,
                    icon: Icon(Icons.folder_open, size: 20),
                    label: Column(
                      children: [
                        Text('Importer'),
                        Text('(MP3, M4A...)', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: _audioColor,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Audio sélectionné/enregistré - affichage avec lecture
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _audioColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.audio_file, color: _audioColor, size: 32),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _audioFileName ?? 'Audio',
                              style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${_audioDuration ?? 0}s • ${_audioFile != null ? '${(_audioFile!.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB' : ''}',
                              style: TextStyle(color: _hintColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _playAudio,
                            icon: _isAudioLoading
                                ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: _audioColor, strokeWidth: 2),
                            )
                                : Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: _isPlaying ? _audioColor : Colors.white,
                              size: 28,
                            ),
                          ),
                          IconButton(
                            onPressed: _removeAudio,
                            icon: Icon(Icons.close, color: Colors.red, size: 24),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (_isPlaying) ...[
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          _formatTime(_currentAudioPosition),
                          style: TextStyle(color: _hintColor, fontSize: 12),
                        ),
                        Expanded(
                          child: Slider(
                            value: _currentAudioPosition.inSeconds.toDouble(),
                            min: 0,
                            max: _currentAudioDuration.inSeconds > 0
                                ? _currentAudioDuration.inSeconds.toDouble()
                                : 1.0,
                            onChanged: _seekAudio,
                            activeColor: _audioColor,
                            inactiveColor: Colors.grey[700],
                          ),
                        ),
                        Text(
                          _formatTime(_currentAudioDuration),
                          style: TextStyle(color: _hintColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoverImageSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _coverImage != null ? _primaryColor : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text('Image de couverture (optionnelle)',
                  style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SizedBox(height: 16),

          if (_coverImage == null) ...[
            GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 40, color: _hintColor),
                    SizedBox(height: 8),
                    Text('Ajouter une image de couverture',
                        style: TextStyle(color: _hintColor, fontSize: 14)),
                    Text('(optionnel)', style: TextStyle(color: _hintColor, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ] else ...[
            Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(_coverImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.white),
                      onPressed: _removeCoverImage,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCharacterCounter() {
    final textLength = _descriptionController.text.length;
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    double percentage = textLength / _maxCharacters;
    Color counterColor = textLength > _maxCharacters
        ? Colors.red
        : percentage > 0.8
        ? Colors.orange
        : Colors.green;

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
        Text(statusText, style: TextStyle(color: counterColor, fontSize: 12, fontWeight: FontWeight.bold)),
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

  void _showPremiumModal({
    required String title,
    required String message,
    required String actionText,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFDB813)),
            SizedBox(width: 10),
            Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(color: Colors.grey[400])),
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
                        Text('Afrolook Premium',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Pays illimités • Audio 3 min • 3000 caractères',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12)),
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
            child: Text('PAS MAINTENANT', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => AbonnementScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFDB813),
              foregroundColor: Colors.black,
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  Future<void> _publishPost() async {

    if (!_canPost && _cooldownMinutes > 0) {
      _showRewardedAdOption(); // Proposer la pub
      return;
    }

    // Vérification audio obligatoire
    if (_audioFile == null) {
      _showErrorSnackbar('Veuillez ajouter un audio');
      return;
    }

    // Vérification pays
    if (!_selectAllCountries && _selectedCountries.isEmpty) {
      _showErrorSnackbar('Veuillez sélectionner au moins un pays');
      return;
    }

    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    if (!isPremium && !isAdmin) {
      if (_selectedCountries.length > _maxCountriesForFree) {
        _showCountryLimitModal();
        return;
      }
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => onTap = true);

    try {
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
                Text('Publication en cours...', style: TextStyle(color: _textColor)),
                SizedBox(height: 8),
                Text('Audio • ${_selectAllCountries ? "Toute l'Afrique" : '${_selectedCountries.length} pays'}',
                    style: TextStyle(color: _hintColor, fontSize: 12)),
              ],
            ),
          );
        },
      );

      String postId = FirebaseFirestore.instance.collection('Posts').doc().id;

      // Upload audio
      String audioUrl = await _uploadAudio();

      // Upload image de couverture si présente
      String? coverImageUrl;
      if (_coverImage != null) {
        coverImageUrl = await _uploadCoverImage();
      }

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
        ..dataType = "AUDIO"
        ..likes = 0
        ..feedScore = 0.0
        ..loves = 0
        ..id = postId
        ..url_media = audioUrl
        ..images = coverImageUrl != null ? [coverImageUrl] : [];

      if (_selectAllCountries) {
        post.availableCountries = ['ALL'];
      } else {
        post.availableCountries = _selectedCountries.map((c) => c.code).toList();
      }

      if (widget.canal != null) {
        post.canal_id = widget.canal!.id;
        post.categorie = "CANAL";
      }

      await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());

      // Nettoyage
      _descriptionController.clear();
      if (_audioFile != null) {
        _audioFile!.delete();
      }
      setState(() {
        onTap = false;
        _audioFile = null;
        _audioFileName = null;
        _audioDuration = null;
        _coverImage = null;
        _coverImageName = null;
        _selectedCountries.clear();
        _selectAllCountries = true;
      });

      // Notifications
      if (widget.canal != null) {
        authProvider.sendPushNotificationToUsers(
          sender: authProvider.loginUserData,
          message: "Audio🎵: ${post.description}",

          // message: "🎵 Nouvel audio dans ${widget.canal!.titre}",
          typeNotif: NotificationType.POST.name,
          postId: post.id!,
          postType: "AUDIO",
          chatId: '',
          smallImage: widget.canal!.urlImage,
          isChannel: true,
          channelTitle: widget.canal!.titre,
          canal: widget.canal,
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
          message: "Audio🎵: ${post.description}",
          typeNotif: NotificationType.POST.name,
          postId: post.id!,
          postType: "AUDIO",
          chatId: '',
          smallImage: authProvider.loginUserData.imageUrl,
          isChannel: false,
        );
      }

      addPointsForAction(UserAction.post);

      Navigator.pop(context);

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
                  Text('Publication réussie !',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 4),
              Text('Audio • ${_selectAllCountries ? "Toute l'Afrique" : '${_selectedCountries.length} pays'}',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          backgroundColor: _cardColor,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      _checkPostCooldown();
    } catch (e) {
      print("❌ Erreur publication: $e");
      if (Navigator.canPop(context)) Navigator.pop(context);
      setState(() => onTap = false);
      _showErrorSnackbar('Erreur lors de la publication');
    }
  }

  Future<String> _uploadAudio() async {
    if (_audioFile == null) throw Exception("Aucun audio à uploader");

    final String uniqueFileName = Uuid().v4();
    Reference storageReference = FirebaseStorage.instance
        .ref()
        .child('post_audio/$uniqueFileName.m4a');

    final metadata = SettableMetadata(
      contentType: 'audio/mp4',
      customMetadata: {
        'duration': (_audioDuration ?? 0).toString(),
        'originalName': _audioFileName ?? 'audio.m4a',
      },
    );

    await storageReference.putFile(_audioFile!, metadata);
    return await storageReference.getDownloadURL();
  }

  Future<String> _uploadCoverImage() async {
    if (_coverImage == null) throw Exception("Aucune image à uploader");

    final String uniqueFileName = Uuid().v4();
    Reference storageReference = FirebaseStorage.instance
        .ref()
        .child('post_images/$uniqueFileName.jpg');

    await storageReference.putFile(_coverImage!);
    return await storageReference.getDownloadURL();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
        backgroundColor: _cardColor,
        duration: Duration(seconds: 3),
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
  @override
  Widget build(BuildContext context) {
    final canPublish = _audioFile != null &&
        (_selectAllCountries || _selectedCountries.isNotEmpty) &&
        _canPost &&
        !onTap &&
        !_isRecording;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _audioColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.audiotrack, color: Colors.white, size: 24),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Publication Audio',
                                style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _audioColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Max 3 minutes',
                                  style: TextStyle(color: _audioColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                if (!_canPost && _cooldownMinutes > 0) _buildCooldownAlert(),

                _buildPostTypeSelector(),
                _buildCountrySelectionCard(),

                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildAudioSection(),
                        SizedBox(height: 20),
                        _buildCoverImageSection(),
                        SizedBox(height: 20),

                        // Description
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _descriptionController,
                                style: TextStyle(color: _textColor, fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Description (optionnelle)...',
                                  hintStyle: TextStyle(color: _hintColor),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                ),
                                maxLines: 3,
                                onChanged: (value) => setState(() {}),
                              ),
                              Padding(
                                padding: EdgeInsets.all(16).copyWith(top: 8),
                                child: _buildCharacterCounter(),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20),

                        // Info abonnement
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                authProvider.loginUserData.role == UserRole.ADM.name
                                    ? Icons.admin_panel_settings
                                    : AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement)
                                    ? Icons.workspace_premium
                                    : Icons.lock,
                                color: authProvider.loginUserData.role == UserRole.ADM.name
                                    ? Colors.green
                                    : AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement)
                                    ? Color(0xFFFDB813)
                                    : Colors.grey,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authProvider.loginUserData.role == UserRole.ADM.name
                                      ? 'Mode Admin: Aucune restriction'
                                      : AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement)
                                      ? 'Mode Premium: Pays illimités • Audio 3 min • 3000 caractères'
                                      : 'Mode Gratuit: Max 2 pays • Audio 3 min • 300 caractères',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                              ),
                              if (!AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement) &&
                                  authProvider.loginUserData.role != UserRole.ADM.name)
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => AbonnementScreen()),
                                  ),
                                  child: Text('PASSER À PREMIUM',
                                      style: TextStyle(color: Color(0xFFFDB813), fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20),

                        // Bouton publication
                        // Bouton de publication
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: onTap || (!_canPost && _cooldownMinutes > 0)
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
                              onTap: onTap || (!_canPost && _cooldownMinutes > 0)
                                  ? null
                                  : _publishPost,
                              child: Center(
                                child: onTap
                                    ? LoadingAnimationWidget.flickr(
                                  size: 30,
                                  leftDotColor: Colors.white,
                                  rightDotColor: _secondaryColor,
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
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _secondaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          // ✅ Utilisation de la méthode statique avec la clé
                                          RewardedAdWidget.showAd(_rewardedAdKey);
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_arrow, color: Colors.black, size: 16),
                                            Text(
                                              'Pub',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
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
                                    Icon(Icons.send, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'PUBLIER VOTRE TEXTE',
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
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 80),
              ],
            ),
          ),

          if (_showCountrySelection)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildCountrySelectionModal(),
            ),
        ],
      ),
    );
  }
}