import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

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

import 'package:iconsax/iconsax.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/postProvider.dart';

import '../../../providers/userProvider.dart';

import '../../../theme/app_colors.dart';

import '../../../services/postService/post_cooldown_service.dart';

import '../../../services/utils/abonnement_utils.dart';

import '../../pub/rewarded_ad_widget.dart';

import '../../user/userAbonnementPage.dart';

import 'package:shared_preferences/shared_preferences.dart';

class UserPubVibe extends StatefulWidget {
  final Canal? canal;
  const UserPubVibe({super.key, this.canal});

  @override
  State<UserPubVibe> createState() => _UserPubVibeState();
}

class _UserPubVibeState extends State<UserPubVibe> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _countrySearchController = TextEditingController();

  String? _localThumbnailPath;
  bool _isGeneratingThumbnail = false;
  bool _isUploadingThumbnail = false;
  bool onTap = false;
  double _uploadProgress = 0;
  XFile? _customThumbnailFile;
  Uint8List? _customThumbnailBytes;
  bool _isUploadingCustomThumbnail = false;
  bool _useCustomThumbnail = false;
  XFile? _videoFile;
  Uint8List? _videoBytes;
  String? _videoFileName;
  bool _isPickingVideo = false;
  VideoPlayerController? _controller;

  final ImagePicker picker = ImagePicker();

  String? _selectedVibeCategory;
  bool _canPost = true;
  String _timeRemaining = '';
  bool _showVideoQualityModal = false;
  bool _hasAcceptedVideoConditions = false;
  int _maxCharacters = 150;
  int _maxVideoSizeMB = 50;
  int _maxVideoDurationSeconds = 30;
  int _cooldownMinutes = 30;

  double aspectRatio = 0.0;

  // Variables pour la sélection des pays
  List<AfricanCountry> _selectedCountries = [];
  List<AfricanCountry> _filteredCountries = [];
  bool _selectAllCountries = false;
  int _maxCountriesForFree = 2;
  bool _showCountrySelection = false;
  final FocusNode _countrySearchFocus = FocusNode();

  // Catégories de vibes (couleurs déco fixes — pas liées au thème)
  static const Map<String, Map<String, dynamic>> _vibeCategories = {
    'COMEDIE': {'label': '🎭 Comédie', 'icon': Icons.theater_comedy, 'color': Color(0xFFFF9800)},
    'DANSE': {'label': '💃 Danse', 'icon': Icons.music_note, 'color': Colors.pink},
    'MUSIQUE': {'label': '🎵 Musique', 'icon': Icons.music_video, 'color': Colors.purple},
    'CHALLENGE': {'label': '🏆 Challenge', 'icon': Icons.emoji_events, 'color': Colors.yellow},
    'TUTO': {'label': '📱 Tutoriel', 'icon': Icons.school, 'color': Colors.blue},
    'ASTUCE': {'label': '💡 Astuce', 'icon': Icons.lightbulb, 'color': Color(0xFFE21221)},
    'INSPIRATION': {'label': '✨ Inspiration', 'icon': Icons.psychology, 'color': Colors.teal},
    'LOL': {'label': '😂 LOL', 'icon': Icons.face, 'color': Color(0xFFE53935)},
    'FOOT': {'label': '⚽ Foot', 'icon': Icons.sports_soccer, 'color': Color(0xFFE21221)},
    'BASKET': {'label': '🏀 Basket', 'icon': Icons.sports_basketball, 'color': Color(0xFFFF9800)},
  };

  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  late AppColors _c;

  final GlobalKey<RewardedAdWidgetState> _rewardedAdKey = GlobalKey();
  bool _showRewardedAd = false;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    _filteredCountries = AfricanCountry.allCountries;

    _setupRestrictions();
    _checkPostCooldown();
    _checkVideoQualityModalStatus();

    _countrySearchController.addListener(_filterCountries);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c = AppColors.of(context);
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
        maxWidth: 400,
        maxHeight: 400,
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
      printVm("Erreur sélection miniature: $e");
      setState(() {
        _isUploadingCustomThumbnail = false;
      });
    }
  }

  Future<String?> _uploadCustomThumbnail() async {
    try {
      if (_customThumbnailFile == null && _customThumbnailBytes == null) return null;
      final fileName = 'thumbnails/vibe_thumb_${authProvider.loginUserData.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask;
      if (kIsWeb && _customThumbnailBytes != null) {
        uploadTask = ref.putData(_customThumbnailBytes!, SettableMetadata(contentType: 'image/jpeg'));
      } else if (_customThumbnailFile != null) {
        uploadTask = ref.putFile(File(_customThumbnailFile!.path));
      } else {
        return null;
      }
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      printVm('Erreur upload miniature personnalisée: $e');
      return null;
    }
  }

  void _setupRestrictions() {
    final user = authProvider.loginUserData;
    final abonnement = user.abonnement;
    if (user.role == UserRole.ADM.name) {
      _maxCharacters = 500;
      _maxVideoSizeMB = 100;
      _maxVideoDurationSeconds = 60;
      _cooldownMinutes = 0;
      return;
    }
    final isPremium = AbonnementUtils.isPremiumActive(abonnement);
    if (isPremium) {
      _maxCharacters = 300;
      _maxVideoSizeMB = 100;
      _maxVideoDurationSeconds = 45;
      _cooldownMinutes = 0;
    } else {
      _maxCharacters = 150;
      _maxVideoSizeMB = 50;
      _maxVideoDurationSeconds = 30;
      _cooldownMinutes = 5;
    }
  }

  Future<void> _checkPostCooldown() async {
    if (_cooldownMinutes == 0) {
      setState(() => _canPost = true);
      return;
    }
    final remaining = await PostCooldownService.localRemainingSeconds();
    if (remaining > 0) {
      _startCooldownTimer(remaining * 1000000);
    } else {
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

  void _toggleCountrySelection(AfricanCountry country) {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
    if (!isPremium && !isAdmin) {
      if (_selectedCountries.length >= _maxCountriesForFree && !_selectedCountries.contains(country)) {
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
        message: 'L\'option "Tous les pays" est réservée aux abonnés Premium.\nPassez à Afrolook Premium pour atteindre toute l\'Afrique.',
        actionText: 'PASSER À PREMIUM',
      );
      return;
    }
    setState(() {
      _selectedCountries = List.from(_filteredCountries);
    });
  }

  void _showCountryLimitModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock, color: _c.primary),
            SizedBox(width: 10),
            Text('Limite de pays atteinte', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('L\'abonnement gratuit est limité à 2 pays maximum.\nPassez à Afrolook Premium pour sélectionner tous les pays africains.',
                style: TextStyle(color: _c.textSecondary)),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: _c.accent)),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium, color: _c.accent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Afrolook Premium', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
                        Text('Pays illimités • Pas de cooldown', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('COMPRENDRE', style: TextStyle(color: _c.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => AbonnementScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: _c.accent, foregroundColor: _c.onAccent),
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
        color: _c.background,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sélection des pays', style: TextStyle(color: _c.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.close, color: _c.textPrimary),
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
                        color: isPremium || isAdmin ? _c.accent.withOpacity(0.2) : _c.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isPremium || isAdmin ? _c.accent : _c.primary),
                      ),
                      child: Row(
                        children: [
                          Icon(isPremium || isAdmin ? Icons.workspace_premium : Icons.lock, size: 14,
                              color: isPremium || isAdmin ? _c.accent : _c.primary),
                          SizedBox(width: 6),
                          Text(isPremium || isAdmin ? 'Pays illimités' : 'Max 2 pays',
                              style: TextStyle(color: isPremium || isAdmin ? _c.accent : _c.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      _selectAllCountries ? '🌍 Toute l\'Afrique (Premium)' : (_selectedCountries.isEmpty ? '⚠️ Aucun pays' : '${_selectedCountries.length} pays sélectionné(s)'),
                      style: TextStyle(color: _selectedCountries.isEmpty && !_selectAllCountries ? _c.warning : _c.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _c.border)),
                  child: TextField(
                    controller: _countrySearchController,
                    focusNode: _countrySearchFocus,
                    style: TextStyle(color: _c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un pays...',
                      hintStyle: TextStyle(color: _c.textSecondary),
                      prefixIcon: Icon(Icons.search, color: _c.primary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: _c.surface,
            child: ListTile(
              onTap: _toggleSelectAllCountries,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _selectAllCountries ? _c.accent : _c.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.workspace_premium, color: _selectAllCountries ? Colors.white : _c.textSecondary),
              ),
              title: Row(
                children: [
                  Text('Tous les pays africains', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _c.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text('PREMIUM', style: TextStyle(color: _c.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              subtitle: Text('Fonctionnalité Premium - Votre vibe sera visible dans toute l\'Afrique', style: TextStyle(color: _c.textSecondary)),
              trailing: _selectAllCountries
                  ? Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: _c.primary, shape: BoxShape.circle), child: Icon(Icons.check, color: Colors.white, size: 20))
                  : null,
            ),
          ),
          if (!isPremium && !isAdmin)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: _c.primary.withOpacity(0.1), border: Border(left: BorderSide(color: _c.primary, width: 3))),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: _c.primary),
                  SizedBox(width: 8),
                  Expanded(child: Text('Abonnement gratuit : Sélectionnez 1 ou 2 pays maximum', style: TextStyle(color: _c.textPrimary, fontSize: 12))),
                ],
              ),
            ),
          Divider(color: _c.surfaceVariant, height: 1),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _filteredCountries.length,
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                final isSelected = _selectedCountries.contains(country);
                final isDisabled = !isPremium && !isAdmin && _selectedCountries.length >= _maxCountriesForFree && !isSelected;
                return Material(
                  color: isSelected ? _c.primary.withOpacity(0.1) : _c.surface,
                  child: ListTile(
                    onTap: isDisabled ? null : () => _toggleCountrySelection(country),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: isSelected ? _c.primary : _c.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text(country.flag, style: TextStyle(fontSize: 20))),
                    ),
                    title: Text(country.name, style: TextStyle(color: isDisabled ? _c.textSecondary : _c.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('Code: ${country.code}', style: TextStyle(color: isDisabled ? _c.textSecondary : _c.textSecondary)),
                    trailing: isSelected
                        ? Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: _c.primary, shape: BoxShape.circle), child: Icon(Icons.check, color: Colors.white, size: 16))
                        : (isDisabled ? Icon(Icons.lock, color: _c.textSecondary, size: 16) : null),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: _c.surface, border: Border(top: BorderSide(color: _c.border))),
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
                    style: OutlinedButton.styleFrom(foregroundColor: _c.textSecondary, side: BorderSide(color: _c.border), padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
                    style: ElevatedButton.styleFrom(backgroundColor: _c.primary, foregroundColor: _c.onPrimary, padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
        color: _c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))],
        border: Border.all(color: _selectedCountries.isEmpty && !_selectAllCountries ? _c.warning : Colors.transparent, width: 1),
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
                    decoration: BoxDecoration(color: _selectAllCountries ? _c.accent : _c.primary, borderRadius: BorderRadius.circular(10)),
                    child: Icon(_selectAllCountries ? Icons.workspace_premium : Icons.public, color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visibilité de la vibe', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(displayMessage, style: TextStyle(color: _selectedCountries.isEmpty && !_selectAllCountries ? _c.warning : _c.textSecondary, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: isPremium || isAdmin ? _c.accent.withOpacity(0.2) : _c.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: isPremium || isAdmin ? _c.accent : _c.primary)),
                child: Text(isPremium || isAdmin ? 'PREMIUM' : 'GRATUIT', style: TextStyle(color: isPremium || isAdmin ? _c.accent : _c.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_selectedCountries.isEmpty && !_selectAllCountries)
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: _c.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _c.warning)),
              child: Row(
                children: [
                  Icon(Icons.warning, size: 16, color: _c.warning),
                  SizedBox(width: 8),
                  Expanded(child: Text('Vous devez sélectionner au moins un pays', style: TextStyle(color: _c.warning, fontSize: 12))),
                ],
              ),
            ),
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
                      decoration: BoxDecoration(color: _c.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _c.primary)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(country.flag),
                          SizedBox(width: 6),
                          Text(country.name, style: TextStyle(color: _c.textPrimary, fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (_selectedCountries.length > 3)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('+ ${_selectedCountries.length - 3} autres pays...', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
                  ),
              ],
            ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showCountrySelection = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => FocusScope.of(context).requestFocus(_countrySearchFocus));
              });
            },
            icon: Icon(Icons.edit_location, size: 18),
            label: Text('SÉLECTIONNER LES PAYS'),
            style: ElevatedButton.styleFrom(backgroundColor: _c.primary.withOpacity(0.2), foregroundColor: _c.primary, minimumSize: Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
  }

  Widget _buildVibeCategorySelector() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: _c.primary, size: 20),
              SizedBox(width: 8),
              Text('Catégorie de la vibe', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _vibeCategories.entries.map((entry) {
              final isSelected = _selectedVibeCategory == entry.key;
              return FilterChip(
                label: Text(entry.value['label'], style: TextStyle(color: isSelected ? Colors.white : _c.textPrimary, fontSize: 12)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedVibeCategory = selected ? entry.key : null;
                  });
                },
                backgroundColor: _c.background,
                selectedColor: entry.value['color'],
                checkmarkColor: Colors.white,
                shape: StadiumBorder(),
              );
            }).toList(),
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
      decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _c.accent)),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.timer, color: _c.accent, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Temps d\'attente', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Prochaine vibe dans: $_timeRemaining', style: TextStyle(color: _c.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _c.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(_timeRemaining, style: TextStyle(color: _c.accent, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: Column(
              children: [
                Divider(color: _c.surfaceVariant),
                SizedBox(height: 12),
                Text('OU', style: TextStyle(color: _c.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                RewardedAdWidget(
                  key: _rewardedAdKey,
                  onAdDismissed: () => setState(() => _showRewardedAd = false),
                  onUserEarnedReward: (double amount, String name) {
                    setState(() {
                      _canPost = true;
                      _timeRemaining = '';
                      _showRewardedAd = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merci ! Vous pouvez poster maintenant !', style: TextStyle(color: _c.primary)), backgroundColor: _c.surface, behavior: SnackBarBehavior.floating));
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: _c.accent, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_filled, color: Colors.black, size: 24),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PUBLICITÉ RÉCOMPENSÉE', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Regardez une pub pour poster maintenant', style: TextStyle(color: Colors.black54, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text('Regardez une courte publicité pour\npublier immédiatement sans attendre', textAlign: TextAlign.center, style: TextStyle(color: _c.textSecondary, fontSize: 11)),
              ],
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
    Color counterColor = textLength > _maxCharacters ? _c.danger : (percentage > 0.8 ? _c.warning : _c.primary);
    String statusText;
    if (isAdmin) {
      statusText = 'Admin • ${textLength}/500';
    } else if (isPremium) {
      statusText = 'Premium • ${textLength}/300';
    } else {
      statusText = 'Gratuit • ${textLength}/150';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(statusText, style: TextStyle(color: counterColor, fontSize: 12, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        LinearProgressIndicator(value: percentage.clamp(0.0, 1.0), backgroundColor: _c.surfaceVariant, valueColor: AlwaysStoppedAnimation<Color>(counterColor), minHeight: 3),
      ],
    );
  }

  Widget _buildVideoSizeInfo() {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
    String sizeText;
    Color color;
    if (isAdmin) {
      sizeText = 'Taille max: 100 Mo (Admin)';
      color = _c.primary;
    } else if (isPremium) {
      sizeText = 'Taille max: 100 Mo (Premium)';
      color = Color(0xFFFDB813);
    } else {
      sizeText = 'Taille max: 50 Mo (Gratuit)';
      color = Colors.grey;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage, size: 14, color: color),
          SizedBox(width: 6),
          Text(sizeText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDurationInfo() {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
    String durationText;
    Color color;
    if (isAdmin) {
      durationText = 'Durée max: 60 sec (Admin)';
      color = _c.primary;
    } else if (isPremium) {
      durationText = 'Durée max: 45 sec (Premium)';
      color = Color(0xFFFDB813);
    } else {
      durationText = 'Durée max: 30 sec (Gratuit)';
      color = Colors.grey;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 14, color: color),
          SizedBox(width: 6),
          Text(durationText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
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
      infoText = 'Mode Admin : Tous pays • 100 Mo • 60 sec max';
      infoColor = _c.primary;
    } else if (isPremium) {
      infoText = 'Mode Premium : Tous pays • 100 Mo • 45 sec max • Pas d\'attente';
      infoColor = Color(0xFFFDB813);
    } else {
      infoText = 'Mode Gratuit : Max 2 pays • 50 Mo • 30 sec max • Attente 30min';
      infoColor = Colors.grey;
    }
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: infoColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: infoColor)),
      child: Row(
        children: [
          Icon(isAdmin ? Icons.admin_panel_settings : (isPremium ? Icons.workspace_premium : Icons.info), color: infoColor, size: 16),
          SizedBox(width: 8),
          Expanded(child: Text(infoText, style: TextStyle(color: infoColor, fontSize: 12, fontWeight: FontWeight.w500))),
          if (!isPremium && !isAdmin)
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AbonnementScreen())),
              style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
              child: Text('PASSER À PREMIUM', style: TextStyle(color: Color(0xFFFDB813), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  void _showPremiumModal({String? reason, String? title, String? message, String? actionText}) {
    if (title == null) {
      if (reason == 'size') {
        title = 'Vidéo trop grande';
        message = 'L\'abonnement gratuit est limité à 50 Mo.\nPassez à Afrolook Premium pour publier des vidéos jusqu\'à 100 Mo.';
        actionText = 'VOIR L\'ABONNEMENT';
      } else if (reason == 'duration') {
        title = 'Vidéo trop longue';
        message = 'L\'abonnement gratuit est limité à 30 secondes.\nPassez à Afrolook Premium pour publier des vidéos jusqu\'à 45 secondes.';
        actionText = 'VOIR L\'ABONNEMENT';
      } else {
        title = 'Limite de caractères atteinte';
        message = 'L\'abonnement gratuit est limité à 150 caractères.\nPassez à Afrolook Premium pour écrire jusqu\'à 300 caractères.';
        actionText = 'VOIR L\'ABONNEMENT';
      }
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFDB813)),
            SizedBox(width: 10),
            Text(title!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message!, style: TextStyle(color: _c.textSecondary)),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFFFDB813))),
              child: Row(
                children: [
                  Icon(Icons.star, color: Color(0xFFFDB813)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('À partir de 200 F/mois', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Pays illimités • 100 Mo vidéo • Pas de cooldown', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('PAS MAINTENANT', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => AbonnementScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFDB813), foregroundColor: _c.onAccent),
            child: Text(actionText!),
          ),
        ],
      ),
    );
  }

  Future<int> _getVideoSize() async {
    if (kIsWeb) {
      return _videoBytes?.length ?? 0;
    } else {
      return await _videoFile?.length() ?? 0;
    }
  }

  Future<Duration> _getVideoDuration() async {
    if (_controller != null && _controller!.value.isInitialized) {
      return _controller!.value.duration;
    }
    return Duration.zero;
  }

  Future<void> _getVideo() async {
    if (_isPickingVideo) return;
    _isPickingVideo = true;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: _c.surface,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_c.primary)),
                SizedBox(height: 16),
                Text('Traitement de la vibe...', style: TextStyle(color: _c.textPrimary)),
                SizedBox(height: 8),
                Text('Initialisation et vérification', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
              ],
            ),
          );
        },
      );

      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) {
        _isPickingVideo = false;
        if (Navigator.canPop(context)) Navigator.pop(context);
        return;
      }

      int size = await video.length();
      final sizeInMB = size / (1024 * 1024);
      final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

      if (!isAdmin && !isPremium && sizeInMB > _maxVideoSizeMB) {
        Navigator.pop(context);
        _showPremiumModal(reason: 'size');
        _isPickingVideo = false;
        return;
      }

      _controller = VideoPlayerController.file(File(video.path));
      await _controller!.initialize();

      final duration = _controller!.value.duration;
      final durationInSeconds = duration.inSeconds;

      if (!isAdmin && durationInSeconds > _maxVideoDurationSeconds) {
        Navigator.pop(context);
        _showPremiumModal(reason: 'duration');
        _isPickingVideo = false;
        _controller = null;
        return;
      }

      final videoWidth = _controller!.value.size.width;
      final videoHeight = _controller!.value.size.height;
      aspectRatio = videoWidth / videoHeight;

      setState(() {
        _videoFile = video;
        _videoFileName = Path.basename(video.path);
      });

      await _controller!.setLooping(true);
      await _controller!.play();

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

      Navigator.pop(context);
    } catch (e) {
      printVm("Erreur lors de la sélection de la vidéo: $e");
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors du traitement de la vidéo'), backgroundColor: _c.danger));
    } finally {
      _isPickingVideo = false;
    }
  }

  Future<String?> _uploadThumbnail(File thumbnailFile) async {
    try {
      final fileName = 'thumbnails/vibe_thumb_${authProvider.loginUserData.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = ref.putFile(thumbnailFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      printVm('Erreur upload miniature: $e');
      return null;
    }
  }

  Future<void> _generateAndUploadThumbnail(String postId, String videoUrl) async {
    if (_isGeneratingThumbnail || _isUploadingThumbnail) return;
    setState(() => _isGeneratingThumbnail = true);
    try {
      final thumbnailFile = await VideoThumbnail.thumbnailFile(video: videoUrl, thumbnailPath: (await getTemporaryDirectory()).path, imageFormat: ImageFormat.JPEG, maxWidth: 400, quality: 75, timeMs: 1000);
      if (thumbnailFile == null) return;
      setState(() {
        _isGeneratingThumbnail = false;
        _isUploadingThumbnail = true;
      });
      final thumbnailUrl = await _uploadThumbnail(File(thumbnailFile));
      if (thumbnailUrl != null && mounted) {
        await FirebaseFirestore.instance.collection('Posts').doc(postId).update({'thumbnail': thumbnailUrl});
      }
    } catch (e) {
      printVm('Erreur génération/upload miniature: $e');
    } finally {
      if (mounted) setState(() {
        _isGeneratingThumbnail = false;
        _isUploadingThumbnail = false;
      });
    }
  }

  Future<String> _uploadVideo() async {
    try {
      if (_videoBytes == null && _videoFile == null) throw Exception("Aucune vidéo sélectionnée");
      String fileName = 'vibe_${authProvider.loginUserData.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      Reference storageReference = FirebaseStorage.instance.ref().child('vibe_videos/$fileName');
      UploadTask uploadTask;
      if (kIsWeb && _videoBytes != null) {
        uploadTask = storageReference.putData(_videoBytes!, SettableMetadata(contentType: 'video/mp4'));
      } else if (_videoFile != null) {
        uploadTask = storageReference.putFile(File(_videoFile!.path));
      } else {
        throw Exception("Format de vidéo non supporté");
      }
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() => _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes);
      });
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      printVm("Erreur lors de l'upload de la vidéo: $e");
      throw Exception("Échec de l'upload de la vidéo");
    }
  }

  Future<void> _publishVideo() async {
    if (onTap) return;

    if (widget.canal != null) {
      final currentUserId = authProvider.loginUserData.id;
      final isOwner = currentUserId == widget.canal!.userId;
      final isAdmin = widget.canal!.adminIds?.contains(currentUserId) == true;
      final canPost = widget.canal!.allowedPostersIds?.contains(currentUserId) == true;
      final allowAllMembers = widget.canal!.allowAllMembersToPost == true;
      final isMember = widget.canal!.usersSuiviId?.contains(currentUserId) == true;
      if (!isAdmin && !canPost && !isOwner) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Vous n\'êtes pas autorisé à poster dans ce canal')));
        return;
      }
      if (!isMember && !isOwner && !isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Vous devez être abonné au canal pour poster')));
        return;
      }
    }

    if (!_canPost && _cooldownMinutes > 0) {
      _showRewardedAdOption();
      return;
    }

    setState(() => onTap = true);

    // Vérification serveur : cooldown 5 min universel (anti-fraude)
    final cooldown = await PostCooldownService.check();
    if (!cooldown.canPost) {
      setState(() => onTap = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '⏳ Attendez ${PostCooldownService.formatRemaining(cooldown.remainingSeconds)} avant de publier à nouveau.',
            textAlign: TextAlign.center,
          ),
          duration: const Duration(seconds: 4),
        ));
      }
      return;
    }

    if (_formKey.currentState!.validate()) {
      final textLength = _descriptionController.text.length;
      if (textLength > _maxCharacters) {
        final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
        if (!isPremium) {
          _showPremiumModal();
          return;
        }
      }

      final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

      if (!_selectAllCountries && _selectedCountries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez sélectionner au moins un pays')));
        return;
      }
      if (!isPremium && !isAdmin) {
        if (_selectedCountries.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez sélectionner 1 ou 2 pays maximum')));
          return;
        }
        if (_selectedCountries.length > _maxCountriesForFree) {
          _showCountryLimitModal();
          return;
        }
      }

      if (_selectedVibeCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez sélectionner une catégorie pour votre vibe')));
        return;
      }

      if (_controller == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez choisir une vidéo.')));
        return;
      }

      try {
        setState(() => _uploadProgress = 0);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: _c.surface,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_c.primary)),
                  SizedBox(height: 16),
                  Text('Publication de la vibe...', style: TextStyle(color: _c.textPrimary)),
                  SizedBox(height: 8),
                  Text('${textLength} caractères • ${_selectAllCountries ? 'Toute l\'Afrique' : '${_selectedCountries.length} pays'}', style: TextStyle(color: _c.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            );
          },
        );

        Duration videoDuration = _controller!.value.duration;
        final size = await _getVideoSize();
        final sizeInMB = size / (1024 * 1024);
        final durationInSeconds = videoDuration.inSeconds;

        if (sizeInMB > _maxVideoSizeMB) {
          Navigator.pop(context);
          setState(() => onTap = false);
          _showPremiumModal(reason: 'size');
          return;
        }

        if (durationInSeconds > _maxVideoDurationSeconds && authProvider.loginUserData.role != UserRole.ADM.name) {
          Navigator.pop(context);
          setState(() => onTap = false);
          _showPremiumModal(reason: 'duration');
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
        post.typeTabbar = 'VIBE';  // 🔥 Spécifique aux vibes
        post.categorie = _selectedVibeCategory;
        post.comments = 0;
        post.likes = 0;
        post.feedScore = 0.0;
        post.loves = 0;
        post.id = postId;
        post.images = [];
        post.isPortrait = true;  // Format portrait pour vibes
        post.isAdvertisement = false;

        post.availableCountries = _selectedCountries.map((c) => c.code).toList();

        if (widget.canal != null) {
          post.canal_id = widget.canal!.id;
          post.categorie = "CANAL";
        }

        String fileURL = await _uploadVideo();
        post.url_media = fileURL;

        await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());
        await PostCooldownService.markPosted();

        String? thumbnailUrl;
        if (_useCustomThumbnail && (_customThumbnailFile != null || _customThumbnailBytes != null)) {
          thumbnailUrl = await _uploadCustomThumbnail();
          if (thumbnailUrl != null && mounted) {
            await FirebaseFirestore.instance.collection('Posts').doc(postId).update({'thumbnail': thumbnailUrl});
          }
        } else {
          await _generateAndUploadThumbnail(postId, fileURL);
        }

        if (widget.canal != null) {
          widget.canal!.updatedAt = DateTime.now().microsecondsSinceEpoch;
          widget.canal!.publicash = (widget.canal!.publicash ?? 0) + 1;
          postProvider.updateCanal(widget.canal!, context);
        }

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
          _selectedVibeCategory = null;
        });

        if (Navigator.canPop(context)) Navigator.pop(context);

        String countryMessage = _selectAllCountries ? 'Visible dans toute l\'Afrique 🌍' : 'Visible dans ${_selectedCountries.length} pays';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: _c.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Vibe publiée avec succès ! 🎉', style: TextStyle(color: _c.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 4),
                Text('${_vibeCategories[_selectedVibeCategory]!['label']} • ${durationInSeconds} sec • $countryMessage', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
            backgroundColor: _c.surface,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        addPointsForAction(UserAction.post);
        _checkPostCooldown();
      } catch (e) {
        printVm("❌ Erreur lors de la publication: $e");
        if (Navigator.canPop(context)) Navigator.pop(context);
        setState(() {
          onTap = false;
          _uploadProgress = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la publication. Veuillez réessayer.')));
      }
    }
  }

  void _showRewardedAdOption() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.timer, color: _c.accent),
            SizedBox(width: 10),
            Text('Temps d\'attente', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vous devez attendre $_timeRemaining avant de pouvoir publier.', style: TextStyle(color: _c.textSecondary)),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(color: _c.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _c.accent)),
              child: Column(
                children: [
                  Icon(Icons.play_circle_filled, color: _c.accent, size: 40),
                  SizedBox(height: 8),
                  Text('Regardez une publicité', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('et publiez immédiatement !', style: TextStyle(color: _c.accent, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ATTENDRE', style: TextStyle(color: _c.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _showRewardedAd = true);
              RewardedAdWidget.showAd(_rewardedAdKey);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _c.accent, foregroundColor: _c.onAccent),
            child: Text('REGARDER LA PUB'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _checkVideoQualityModalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenModal = prefs.getBool('has_seen_vibe_modal') ?? false;
    if (!hasSeenModal && mounted) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _showVideoQualityModal = true;
          _showVibeInfoDialog();
        }
      });
    }
  }

  void _showVibeInfoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: _c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 24,
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_c.primary, Color(0xFFFF5252)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.music_video, color: _c.accent, size: 40),
                          SizedBox(height: 8),
                          Text('BIENVENUE DANS LES VIBES !', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: _c.accent, borderRadius: BorderRadius.circular(20)),
                            child: Text('VIDÉOS COURTES ET DIVERTISSANTES', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(color: _c.border.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Icon(Icons.timer, color: _c.primary, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('VIDÉOS COURTES (MAX 30s)', style: TextStyle(color: _c.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('Des vidéos rapides et percutantes pour divertir', style: TextStyle(color: _c.textSecondary, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(color: _c.border.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Icon(Icons.vertical_align_center, color: Colors.blue, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('FORMAT PORTRAIT', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('Tournez votre téléphone à la verticale (9:16)', style: TextStyle(color: _c.textSecondary, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(color: _c.border.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.celebration, color: _c.warning, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('CONTENU DIVERTISSANT', style: TextStyle(color: _c.warning, fontWeight: FontWeight.bold, fontSize: 13)),
                                        SizedBox(height: 4),
                                        Text(
                                          '✓ Comédie et humour\n'
                                              '✓ Challenge et défi\n'
                                              '✓ Danse et musique\n'
                                              '✓ Astuces et tutoriels\n'
                                              '✓ Inspiration et motivation',
                                          style: TextStyle(color: _c.textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(gradient: LinearGradient(colors: [_c.accent.withOpacity(0.2), _c.primary.withOpacity(0.1)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: _c.accent)),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.monetization_on, color: _c.accent, size: 20),
                                      SizedBox(width: 8),
                                      Text('GAGNEZ DE L\'ARGENT', style: TextStyle(color: _c.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Les vibes populaires peuvent vous rapporter des gains ! Plus vos vidéos sont vues et appréciées, plus vous gagnez.',
                                    style: TextStyle(color: _c.textPrimary, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(color: _c.border.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _hasAcceptedVideoConditions,
                                    onChanged: (bool? value) => setStateDialog(() => _hasAcceptedVideoConditions = value ?? false),
                                    activeColor: _c.primary,
                                    checkColor: Colors.white,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Je comprends que les vibes sont des vidéos courtes et divertissantes (< 30 sec)',
                                      style: TextStyle(color: _c.textPrimary, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: _c.border))),
                      child: ElevatedButton(
                        onPressed: () {
                          if (!_hasAcceptedVideoConditions) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez accepter les conditions')));
                            return;
                          }
                          _saveModalSeen();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _c.primary, foregroundColor: _c.onPrimary, minimumSize: Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text('COMMENCER À POSTER DES VIBES', style: TextStyle(fontWeight: FontWeight.bold)),
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
    await prefs.setBool('has_seen_vibe_modal', true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: _c.background,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _c.surface,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: _c.primary, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.music_video, color: Colors.white, size: 24)),
                      SizedBox(height: 6),
                      Text('Publier une Vibe', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 4),
                      Text('Vidéo courte et divertissante', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
                      _buildVideoSizeInfo(),
                      SizedBox(height: 4),
                      _buildDurationInfo(),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                _buildRestrictionsInfo(),
                if (!_canPost && _cooldownMinutes > 0) _buildCooldownAlert(),
                _buildVibeCategorySelector(),
                _buildCountrySelectionCard(),
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))]),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Description
                        Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _c.border)),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _descriptionController,
                                style: TextStyle(color: _c.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Décrivez votre vibe... (ex: "Tuto maquillage 3min", "Challenge danse")',
                                  hintStyle: TextStyle(color: _c.textSecondary),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                  prefixIcon: Icon(Icons.description, color: _c.primary),
                                ),
                                maxLines: 3,
                                onChanged: (value) => setState(() {}),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'La description est obligatoire';
                                  if (value.length > _maxCharacters) return 'Limite de $_maxCharacters caractères dépassée';
                                  return null;
                                },
                              ),
                              Padding(padding: EdgeInsets.all(16).copyWith(top: 8), child: _buildCharacterCounter()),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),

                        // Information format
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
                                      '📱 Format recommandé : Portrait (9:16)',
                                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• Vidéos verticales (téléphone à la verticale)\n'
                                          '• Maximum 30 secondes\n'
                                          '• Contenu divertissant et créatif',
                                      style: TextStyle(color: Colors.blue[300], fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),

                        // Sélection vidéo
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            color: _c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _c.accent, width: 2),
                            boxShadow: [BoxShadow(color: _c.accent.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _getVideo,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.video_library, color: _c.accent, size: 24),
                                  SizedBox(width: 12),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('SÉLECTIONNER UNE VIDÉO', style: TextStyle(color: _c.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                                      SizedBox(height: 2),
                                      Text('Max ${_maxVideoDurationSeconds} secondes', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),

                        // Aperçu vidéo
                        if (_controller != null) _buildVideoPreview(),
                        if (onTap && _uploadProgress > 0)
                          Container(
                            padding: EdgeInsets.all(16),
                            margin: EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(color: _c.background, borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Téléchargement:', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)), Text('${(_uploadProgress * 100).toStringAsFixed(1)}%', style: TextStyle(color: _c.primary, fontWeight: FontWeight.bold))]),
                                SizedBox(height: 8),
                                LinearProgressIndicator(value: _uploadProgress, backgroundColor: _c.surfaceVariant, valueColor: AlwaysStoppedAnimation<Color>(_c.primary), borderRadius: BorderRadius.circular(10)),
                              ],
                            ),
                          ),
                        SizedBox(height: 30),

                        // Bouton publication
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: onTap || (!_canPost && _cooldownMinutes > 0) || _controller == null || _selectedVibeCategory == null
                                  ? [Colors.grey, Colors.grey]
                                  : [_c.primary, Color(0xFFFF5252)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [BoxShadow(color: _c.primary.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(25),
                              onTap: onTap || (!_canPost && _cooldownMinutes > 0) || _controller == null || _selectedVibeCategory == null ? null : _publishVideo,
                              child: Center(
                                child: onTap
                                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2), SizedBox(width: 10), Text('Publication...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])
                                    : (!_canPost && _cooldownMinutes > 0)
                                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.timer, color: Colors.white, size: 20), SizedBox(width: 8), Text('Attendez $_timeRemaining', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))])
                                    : _controller == null
                                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.video_library, color: Colors.white, size: 20), SizedBox(width: 8), Text('CHOISIR UNE VIDÉO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))])
                                    : _selectedVibeCategory == null
                                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.category, color: Colors.white, size: 20), SizedBox(width: 8), Text('SÉLECTIONNEZ UNE CATÉGORIE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))])
                                    : (_selectedCountries.isEmpty && !_selectAllCountries)
                                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.warning, color: Colors.white, size: 20), SizedBox(width: 8), Text('SÉLECTIONNEZ UN PAYS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))])
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.music_video, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('PUBLIER LA VIBE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    SizedBox(width: 4),
                                    Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(_selectAllCountries ? '🌍' : '${_selectedCountries.length}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                        if (widget.canal != null)
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue)),
                            child: Row(children: [Icon(Icons.group, color: Colors.blue, size: 16), SizedBox(width: 8), Expanded(child: Text('Publication dans le canal: ${widget.canal!.titre}', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w500)))]),
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
        if (_showCountrySelection)
          Positioned(bottom: 0, left: 0, right: 0, child: _buildCountrySelectionModal()),
        if (_showRewardedAd)
          RewardedAdWidget(
            key: _rewardedAdKey,
            onUserEarnedReward: (amount, name) {
              setState(() {
                _canPost = true;
                _timeRemaining = '';
                _showRewardedAd = false;
              });
            },
            onAdDismissed: () => setState(() => _showRewardedAd = false),
            child: SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    if (kIsWeb) {
      if (_videoFile == null && _videoBytes == null) return Container();
      return FutureBuilder<int>(
        future: _getVideoSize(),
        builder: (context, snapshot) {
          final sizeInMB = snapshot.hasData ? snapshot.data! / (1024 * 1024) : 0;
          return Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _c.primary.withOpacity(0.3))),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: _c.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.videocam, color: _c.primary, size: 20)),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Vidéo sélectionnée', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)), Text('Prête à être publiée', style: TextStyle(color: _c.textSecondary, fontSize: 12))])),
                    Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _c.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text(snapshot.hasData ? '${sizeInMB.toStringAsFixed(1)} Mo' : '...', style: TextStyle(color: _c.primary, fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
                SizedBox(height: 12),
                _buildThumbnailSelector(),
              ],
            ),
          );
        },
      );
    } else {
      if (_controller == null) return Container();
      return FutureBuilder<int>(
        future: _getVideoSize(),
        builder: (context, snapshot) {
          final sizeInMB = snapshot.hasData ? snapshot.data! / (1024 * 1024) : 0;
          final duration = _controller!.value.duration;
          final durationInSeconds = duration.inSeconds;
          final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
          final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);

          Color durationColor = _c.primary;
          if (!isAdmin && !isPremium && durationInSeconds > _maxVideoDurationSeconds) {
            durationColor = _c.danger;
          } else if (isPremium && durationInSeconds > _maxVideoDurationSeconds) {
            durationColor = _c.warning;
          }

          return Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: _c.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: durationColor.withOpacity(0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aperçu de la vibe:', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
                  child: ClipRRect(borderRadius: BorderRadius.circular(12), child: VideoPlayer(_controller!)),
                ),
                SizedBox(height: 6),
                _buildThumbnailSelector(),
                SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(icon: Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow, color: _c.primary), onPressed: () => setState(() => _controller!.value.isPlaying ? _controller!.pause() : _controller!.play())),
                    Expanded(child: VideoProgressIndicator(_controller!, allowScrubbing: true, colors: VideoProgressColors(playedColor: _c.primary, bufferedColor: _c.accent, backgroundColor: _c.border))),
                    IconButton(icon: Icon(Icons.volume_up, color: _controller!.value.volume > 0 ? _c.primary : _c.textSecondary), onPressed: () => setState(() => _controller!.setVolume(_controller!.value.volume > 0 ? 0 : 1))),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [Icon(Icons.play_circle_fill, color: _c.primary, size: 16), SizedBox(width: 4), Text('Vidéo sélectionnée', style: TextStyle(color: _c.textSecondary, fontStyle: FontStyle.italic, fontSize: 12))]),
                    Row(
                      children: [
                        Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _c.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text(snapshot.hasData ? '${sizeInMB.toStringAsFixed(1)} Mo' : '...', style: TextStyle(color: _c.primary, fontSize: 12, fontWeight: FontWeight.bold))),
                        SizedBox(width: 8),
                        Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: durationColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: durationColor)), child: Text('${durationInSeconds}s', style: TextStyle(color: durationColor, fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
                if (durationInSeconds > _maxVideoDurationSeconds && !isAdmin)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: _c.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(Icons.warning, color: _c.danger, size: 16), SizedBox(width: 8), Expanded(child: Text('Cette vidéo dépasse la durée limite de ${_maxVideoDurationSeconds} secondes', style: TextStyle(color: _c.danger, fontSize: 12)))])),
                  ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildThumbnailSelector() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image, color: _c.primary, size: 20),
              SizedBox(width: 8),
              Text('Miniature de la vibe', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SizedBox(height: 12),
          if (_useCustomThumbnail && (_customThumbnailBytes != null || _customThumbnailFile != null))
            Container(
              height: 150,
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _c.primary)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb && _customThumbnailBytes != null
                    ? Image.memory(_customThumbnailBytes!, fit: BoxFit.cover, width: double.infinity)
                    : (_customThumbnailFile != null ? Image.file(File(_customThumbnailFile!.path), fit: BoxFit.cover, width: double.infinity) : Container()),
              ),
            )
          else if (_localThumbnailPath != null && !_useCustomThumbnail)
            Container(
              height: 150,
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _c.border)),
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_localThumbnailPath!), fit: BoxFit.cover, width: double.infinity)),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploadingCustomThumbnail ? null : _selectCustomThumbnail,
                  icon: _isUploadingCustomThumbnail ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.image, size: 18),
                  label: Text(_useCustomThumbnail ? 'CHANGER LA MINIATURE' : 'CHOISIR UNE MINIATURE', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: _c.primary, side: BorderSide(color: _c.primary), padding: EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              if (_useCustomThumbnail) SizedBox(width: 8),
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
                    style: OutlinedButton.styleFrom(foregroundColor: _c.warning, side: BorderSide(color: _c.warning), padding: EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text('Choisissez une image personnalisée comme miniature ou utilisez la génération automatique', style: TextStyle(color: _c.textSecondary, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}