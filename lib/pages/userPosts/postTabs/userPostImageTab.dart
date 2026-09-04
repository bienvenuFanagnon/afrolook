import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'dart:io';
import 'dart:typed_data';

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

import 'package:path_provider/path_provider.dart';

import 'package:iconsax/iconsax.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/postProvider.dart';

import '../../../providers/userProvider.dart';

import '../../../theme/app_colors.dart';

import '../../../services/postService/massNotificationService.dart';

import '../../../services/postService/post_cooldown_service.dart';

import '../../../services/utils/abonnement_utils.dart';

import '../../pub/rewarded_ad_widget.dart';
import '../../../widgets/hashtag_suggestion_bar.dart';

import '../../user/userAbonnementPage.dart';

import '../../user/userPubs/user_my_advertisements_page.dart';

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
  final TextEditingController _countrySearchController = TextEditingController();
  final TextEditingController _actionUrlController = TextEditingController();

  late PostProvider postProvider;
  late UserAuthProvider authProvider;
  late UserProvider userProvider;

  bool onTap = false;
  bool _canPost = true;
  String _timeRemaining = '';

  String? _selectedPostType;
  List<Uint8List> _selectedImages = [];
  List<String> _imageNames = [];

  // Variables pour la sélection des pays
  List<AfricanCountry> _selectedCountries = [];
  List<AfricanCountry> _filteredCountries = [];
  bool _selectAllCountries = false;
  int _maxCountriesForFree = 2;
  bool _showCountrySelection = false;
  final FocusNode _countrySearchFocus = FocusNode();

  // Variables pour la publicité
  bool _isAdvertisement = false;
  String? _selectedActionType; // 'download', 'visit', 'learn_more'
  int? _selectedDurationDays; // 7, 14, 30, 60, 90, 180, 365
  final List<int> _durationOptions = [7, 14, 30, 60, 90, 180, 365];

  final Map<String, Map<String, dynamic>> _postTypes = {
    'LOOKS': {'label': 'Looks', 'icon': Icons.style},
    'ACTUALITES': {'label': 'Actualités', 'icon': Icons.article},
    'SPORT': {'label': 'Sport', 'icon': Icons.sports},
    'EVENEMENT': {'label': 'Événement', 'icon': Icons.event},
    'OFFRES': {'label': 'Offres', 'icon': Icons.local_offer},
    'GAMER': {'label': 'Games story', 'icon': Icons.gamepad},
  };

  final Map<String, Map<String, dynamic>> _actionTypes = {
    'download': {'label': 'Télécharger', 'icon': Icons.download, 'hint': 'https://play.google.com/...'},
    'visit': {'label': 'Visiter', 'icon': Icons.language, 'hint': 'https://monsite.com'},
    'learn_more': {'label': 'En savoir plus', 'icon': Icons.info, 'hint': 'https://...'},
  };

  late AppColors _c;
  late MassNotificationService _notificationService;

  // Variables pour restrictions
  int _maxImages = 1;
  int _maxCharacters = 300;
  int _cooldownMinutes = 60;
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
    _actionUrlController.dispose();
    super.dispose();
  }

  // Ajoutez ces variables dans la classe _UserPostLookImageTabState
  DateTime? _selectedEventDate;
  bool _isEventDatePast = false;

// Ajoutez cette méthode pour vérifier si la date est passée
  void _validateEventDate(DateTime? date) {
    if (date != null && _selectedPostType == 'EVENEMENT') {
      setState(() {
        _isEventDatePast = date.isBefore(DateTime.now());
      });
    }
  }

// Ajoutez ce widget dans le build, après le sélecteur de type
  Widget _buildEventDatePicker() {
    if (_selectedPostType != 'EVENEMENT') return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEventDatePast ? _c.danger : _c.primary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, color: _c.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Date de l\'événement',
                style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (_isEventDatePast)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _c.danger.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'DATE PASSÉE',
                    style: TextStyle(color: _c.danger, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedEventDate ?? DateTime.now().add(Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: _c.primary,
                        onPrimary: _c.onPrimary,
                        surface: _c.surface,
                        onSurface: _c.textPrimary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedEventDate = picked;
                  _isEventDatePast = false;
                });
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _c.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _c.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: _c.primary, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedEventDate != null
                          ? '${_selectedEventDate!.day}/${_selectedEventDate!.month}/${_selectedEventDate!.year}'
                          : 'Sélectionnez la date de l\'événement',
                      style: TextStyle(
                        color: _selectedEventDate != null ? _c.textPrimary : _c.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: _c.textSecondary),
                ],
              ),
            ),
          ),
          if (_selectedEventDate != null)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '📅 ${_formatEventDate(_selectedEventDate!)}',
                style: TextStyle(color: _c.primary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _formatEventDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) return "AUJOURD'HUI";
    if (difference == 1) return "DEMAIN";
    if (difference < 7) return "DANS $difference JOURS";
    if (difference < 30) return "DANS ${(difference / 7).ceil()} SEMAINES";
    return "LE ${date.day}/${date.month}/${date.year}";
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
      _maxImages = 10;
      _maxCharacters = 5000;
      _cooldownMinutes = 0;
      return;
    }

    final isGold    = AbonnementUtils.isGold(abonnement);
    final isPremium = AbonnementUtils.isPremiumActive(abonnement);

    if (isGold) {
      _maxImages = 5;
      _maxCharacters = 5000;
      _cooldownMinutes = 0;
    } else if (isPremium) {
      _maxImages = 3;
      _maxCharacters = 3000;
      _cooldownMinutes = 0;
    } else {
      _maxImages = 1;
      _maxCharacters = 300;
      _cooldownMinutes = 5;
    }
  }

  Future<void> _checkPostCooldown() async {
    if (_cooldownMinutes == 0) {
      setState(() => _canPost = true);
      return;
    }
    // Lecture du cache local (SharedPreferences) — partagé entre tous les onglets
    final remaining = await PostCooldownService.localRemainingSeconds();
    if (remaining > 0) {
      _startCooldownTimer(remaining * 1000000); // secondes → microsecondes
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

  Future<void> _selectImage() async {
    if (_selectedImages.length >= _maxImages) {
      final abonnement = authProvider.loginUserData.abonnement;
      final isGold = AbonnementUtils.isGold(abonnement);
      final isPremium = !isGold && AbonnementUtils.isPremiumActive(abonnement);
      if (isPremium) {
        // Premium à 3 images → proposer Gold
        _showPremiumModal(
          title: 'Limite Premium atteinte',
          message: 'Vous avez atteint la limite de 3 images (plan Premium).\n\n👑 Avec Gold, publiez jusqu\'à 5 images par post !',
          actionText: 'PASSER À GOLD',
        );
      } else {
        // Gratuit à 1 image → proposer Premium ou Gold
        _showPremiumModal(
          title: 'Limite d\'images atteinte',
          message: 'L\'abonnement gratuit est limité à 1 image.\n\n⭐ Premium : jusqu\'à 3 images\n👑 Gold : jusqu\'à 5 images',
          actionText: 'VOIR LES ABONNEMENTS',
        );
      }
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (image != null) {
      try {
        final Uint8List compressedBytes = await _compressImage(await image.readAsBytes());

        setState(() {
          _selectedImages.add(compressedBytes);
          _imageNames.add(image.name);
        });
      } catch (e) {
        printVm("Erreur lors de la compression: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du traitement de l\'image', textAlign: TextAlign.center, style: TextStyle(color: _c.danger)),
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
        quality: 75,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      printVm("Erreur compression: $e");
      return bytes;
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageNames.removeAt(index);
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
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _c.accent),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium, color: _c.accent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Afrolook Premium', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
                        Text('Pays illimités • 3 images (5 avec Gold 👑) • Pas de cooldown', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
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
            child: Text('COMPRENDRE', style: TextStyle(color: _c.textSecondary)),
          ),
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
            decoration: BoxDecoration(
              color: _c.surface,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
            ),
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
                      _selectAllCountries ? '🌍 Tous les pays' : '${_selectedCountries.length} pays sélectionné(s)',
                      style: TextStyle(color: _c.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: _c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _c.border),
                  ),
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
                decoration: BoxDecoration(
                  color: _selectAllCountries ? _c.primary : _c.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
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
              subtitle: Text('Votre post sera visible dans toute l\'Afrique', style: TextStyle(color: _c.textSecondary)),
              trailing: _selectAllCountries
                  ? Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: _c.primary, shape: BoxShape.circle),
                child: Icon(Icons.check, color: Colors.white, size: 20),
              )
                  : null,
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
                      decoration: BoxDecoration(
                        color: isSelected ? _c.primary : _c.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text(country.flag, style: TextStyle(fontSize: 20))),
                    ),
                    title: Text(country.name, style: TextStyle(color: isDisabled ? _c.textSecondary : _c.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('Code: ${country.code}', style: TextStyle(color: isDisabled ? _c.textSecondary : _c.textSecondary)),
                    trailing: isSelected
                        ? Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _c.primary, shape: BoxShape.circle),
                      child: Icon(Icons.check, color: Colors.white, size: 16),
                    )
                        : isDisabled
                        ? Icon(Icons.lock, color: _c.textSecondary, size: 16)
                        : null,
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _c.surface,
              border: Border(top: BorderSide(color: _c.border)),
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
                      foregroundColor: _c.textSecondary,
                      side: BorderSide(color: _c.border),
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
                      backgroundColor: _c.primary,
                      foregroundColor: _c.onPrimary,
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

  Widget _buildAfrolookAdsPromoButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _c.accent, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android, color: _c.accent, size: 24),
              SizedBox(width: 12),
              Text(
                'Faites la promotion de votre contenu !',
                style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Vous pouvez créer des publicités pour vos événements, produits ou services. '
                'Atteignez plus de 1 000 000 utilisateurs par pays près de chez vous, ciblez des pays spécifiques '
                'et suivez vos statistiques en temps réel.',
            style: TextStyle(color: _c.textSecondary, fontSize: 13),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserMyAdvertisementsPage()),
              );
            },
            icon: Icon(Icons.add_circle),
            label: Text('CRÉER UNE PUBLICITÉ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _c.primary,
              foregroundColor: _c.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Text('Visibilité du post', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(displayMessage, style: TextStyle(color: _selectedCountries.isEmpty && !_selectAllCountries ? _c.warning : _c.textSecondary, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPremium || isAdmin ? _c.accent.withOpacity(0.2) : _c.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isPremium || isAdmin ? _c.accent : _c.primary),
                ),
                child: Text(
                  isPremium || isAdmin ? 'PREMIUM' : 'GRATUIT',
                  style: TextStyle(color: isPremium || isAdmin ? _c.accent : _c.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _c.primary.withOpacity(0.2),
              foregroundColor: _c.primary,
              minimumSize: Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        color: _c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _c.accent),
      ),
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
                    Text('Prochain post dans: $_timeRemaining', style: TextStyle(color: _c.textSecondary, fontSize: 14)),
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
                  onUserEarnedReward: (double amount, String name) {
                    printVm('RewardedAdWidget - amount : $amount -- name: $name');
                    setState(() {
                      _canPost = true;
                      _timeRemaining = '';
                      _showRewardedAd = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merci ! Vous pouvez poster maintenant !', style: TextStyle(color: _c.primary)), backgroundColor: _c.surface, behavior: SnackBarBehavior.floating));

                  },
                  // onUserEarnedReward: (reward) {
                  //   setState(() {
                  //     _canPost = true;
                  //     _timeRemaining = '';
                  //     _showRewardedAd = false;
                  //   });
                  //   ScaffoldMessenger.of(context).showSnackBar(
                  //     SnackBar(
                  //       content: Text('Merci ! Vous pouvez poster maintenant !', style: TextStyle(color: _c.primary)),
                  //       backgroundColor: _c.surface,
                  //       behavior: SnackBarBehavior.floating,
                  //     ),
                  //   );
                  // },
                  onAdDismissed: () => setState(() => _showRewardedAd = false),
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
                Text('Regardez une courte publicité pour\npublier immédiatement sans attendre',
                    textAlign: TextAlign.center, style: TextStyle(color: _c.textSecondary, fontSize: 11)),
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
              Text('Type de publication', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              hintText: 'Choisir un type de publication',
              hintStyle: TextStyle(color: _c.textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.primary)),
              filled: true,
              fillColor: _c.background,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            dropdownColor: _c.surface,
            style: TextStyle(color: _c.textPrimary, fontSize: 14),
            value: _selectedPostType,
            onChanged: (String? newValue) {
              setState(() => _selectedPostType = newValue);
              if (newValue != null) {
                final tag = HashtagSuggestionBar.randomHashtagForType(newValue);
                if (tag != null && !_descriptionController.text.contains('#')) {
                  final current = _descriptionController.text.trim();
                  _descriptionController.text = current.isEmpty ? '$tag ' : '$current $tag ';
                  _descriptionController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _descriptionController.text.length),
                  );
                }
              }
            },
            items: _postTypes.entries.map<DropdownMenuItem<String>>((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    Icon(entry.value['icon'] as IconData, color: _c.primary, size: 18),
                    SizedBox(width: 12),
                    Text(entry.value['label'], style: TextStyle(color: _c.textPrimary)),
                  ],
                ),
              );
            }).toList(),
            validator: (value) => value == null || value.isEmpty ? 'Veuillez sélectionner un type de post' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildImageCounter() {
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
    final isGold = AbonnementUtils.isGold(authProvider.loginUserData.abonnement);
    final isPremium = !isGold && AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);

    String statusText;
    Color statusColor;

    if (isAdmin) {
      statusText = 'Admin • Images illimitées';
      statusColor = _c.primary;
    } else if (isGold) {
      statusText = 'Gold 👑 • ${_selectedImages.length}/5 images';
      statusColor = const Color(0xFFFFD700);
    } else if (isPremium) {
      statusText = 'Premium • ${_selectedImages.length}/3 images';
      statusColor = const Color(0xFFFDB813);
    } else {
      statusText = 'Gratuit • ${_selectedImages.length}/1 image';
      statusColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image, size: 14, color: statusColor),
          SizedBox(width: 6),
          Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
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
          backgroundColor: _c.surfaceVariant,
          valueColor: AlwaysStoppedAnimation<Color>(counterColor),
          minHeight: 3,
        ),
      ],
    );
  }

  void _showPremiumModal({required String title, required String message, required String actionText}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _c.surface,
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
            Text(message, style: TextStyle(color: _c.textSecondary)),
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
                        Text('Afrolook Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Pays illimités • 3 images • 3000 caractères', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
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
            child: Text(actionText),
          ),
        ],
      ),
    );
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
              decoration: BoxDecoration(
                color: _c.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _c.accent),
              ),
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

  Future<void> _publishPost() async {
    // Protection double-tap : bloquer immédiatement avant tout await
    if (onTap) return;

    if (!_canPost && _cooldownMinutes > 0) {
      _showRewardedAdOption();
      return;
    }

    // Désactiver le bouton AVANT le premier await pour éviter double-soumission
    setState(() => onTap = true);

    // Vérification serveur uniquement si utilisateur soumis au cooldown
    if (_cooldownMinutes > 0) {
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
    }

    if (widget.canal != null) {
      final currentUserId = authProvider.loginUserData.id;
      final isOwner = currentUserId == widget.canal!.userId;
      final isAdmin = widget.canal!.adminIds?.contains(currentUserId) == true;
      final canPost = widget.canal!.allowedPostersIds?.contains(currentUserId) == true;
      final allowAllMembers = widget.canal!.allowAllMembersToPost == true;
      final isMember = widget.canal!.usersSuiviId?.contains(currentUserId) == true;

      if (!isOwner && !isAdmin && !canPost && !(allowAllMembers && isMember)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Vous n\'êtes pas autorisé à poster dans ce canal', textAlign: TextAlign.center, style: TextStyle(color: _c.danger))),
        );
        return;
      }
      if (!isMember && !isOwner && !isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Vous devez être abonné au canal pour poster', textAlign: TextAlign.center, style: TextStyle(color: _c.danger))),
        );
        return;
      }
    }

    if (_formKey.currentState!.validate()) {
      if (_selectedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner au moins une image', textAlign: TextAlign.center, style: TextStyle(color: _c.danger))),
        );
        return;
      }

      final textLength = _descriptionController.text.length;
      if (textLength > _maxCharacters) {
        final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
        if (!isPremium) {
          _showPremiumModal(
            title: 'Limite de caractères dépassée',
            message: 'L\'abonnement gratuit est limité à 300 caractères.\nPassez à Afrolook Premium pour écrire jusqu\'à 3000 caractères.',
            actionText: 'PASSER À PREMIUM',
          );
          return;
        }
      }

      final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

      if (!_selectAllCountries && _selectedCountries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner au moins un pays', textAlign: TextAlign.center, style: TextStyle(color: _c.danger))),
        );
        return;
      }
// Ajoutez cette validation après la vérification des pays
      if (_selectedPostType == 'EVENEMENT') {
        if (_selectedEventDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Veuillez sélectionner la date de l\'événement', textAlign: TextAlign.center, style: TextStyle(color: _c.danger))),
          );
          return;
        }
        if (_selectedEventDate!.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('La date de l\'événement ne peut pas être dans le passé', textAlign: TextAlign.center, style: TextStyle(color: _c.danger))),
          );
          return;
        }
      }
      if (!isPremium && !isAdmin) {
        if (_selectedCountries.isEmpty || _selectedCountries.length > _maxCountriesForFree) {
          _showCountryLimitModal();
          return;
        }
      }

      // Validation de la publicité
      if (_isAdvertisement) {
        if (_selectedActionType == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Veuillez sélectionner un type d\'action pour la publicité', textAlign: TextAlign.center, style: TextStyle(color: _c.danger))),
          );
          return;
        }
        if (_actionUrlController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Veuillez saisir le lien de la publicité', textAlign: TextAlign.center, style: TextStyle(color: _c.danger))),
          );
          return;
        }
        if (_selectedDurationDays == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Veuillez sélectionner la durée de la publicité', textAlign: TextAlign.center, style: TextStyle(color: _c.danger))),
          );
          return;
        }
      }

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
                  LoadingAnimationWidget.flickr(size: 50, leftDotColor: _c.primary, rightDotColor: _c.accent),
                  SizedBox(height: 16),
                  Text('Publication en cours...', style: TextStyle(color: _c.textPrimary)),
                  SizedBox(height: 8),
                  Text(
                    '${_selectedImages.length} image(s) • ${_selectAllCountries ? 'Toute l\'Afrique' : '${_selectedCountries.length} pays'}${_isAdvertisement ? ' • Publicité' : ''}',
                    style: TextStyle(color: _c.textSecondary, fontSize: 12),
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
          ..images = []
          ..isAdvertisement = _isAdvertisement // Nouveau champ
         ..eventDate = _selectedPostType == 'EVENEMENT' ? _selectedEventDate?.millisecondsSinceEpoch : null;

        // if (_selectAllCountries) {
        //   post.availableCountries = ['ALL'];
        // } else {
        //   post.availableCountries = _selectedCountries.map((c) => c.code).toList();
        // }
        post.availableCountries = _selectedCountries.map((c) => c.code).toList();

        if (widget.canal != null) {
          post.canal_id = widget.canal!.id;
          post.categorie = "CANAL";
        }

        List<String> imageUrls = [];
        for (int i = 0; i < _selectedImages.length; i++) {
          final String uniqueFileName = Uuid().v4();
          Reference storageReference = FirebaseStorage.instance.ref().child('post_media/$uniqueFileName.jpg');

          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$uniqueFileName.jpg');
          await file.writeAsBytes(_selectedImages[i]);

          await storageReference.putFile(file);
          String fileURL = await storageReference.getDownloadURL();
          imageUrls.add(fileURL);
        }

        post.images = imageUrls;

        // Sauvegarder le post
        await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());
        await PostCooldownService.markPosted();

        // Si c'est une publicité, créer l'entrée dans Advertisement
        if (_isAdvertisement) {
          String advertisementId = FirebaseFirestore.instance.collection('Advertisements').doc().id;
          int now = DateTime.now().microsecondsSinceEpoch;

          Advertisement ad = Advertisement(
            id: advertisementId,
            postId: postId,
            actionType: _selectedActionType,
            actionUrl: _actionUrlController.text,
            actionButtonText: _actionTypes[_selectedActionType]!['label'],
            durationDays: _selectedDurationDays,
            startDate: now,
            endDate: now + (_selectedDurationDays! * 24 * 60 * 60 * 1000000),
            status: 'pending', // En attente de validation admin
            isRenewable: true,
            renewalCount: 0,
            createdBy: authProvider.loginUserData.id,
            createdAt: now,
            updatedAt: now,
          );

          await FirebaseFirestore.instance.collection('Advertisements').doc(advertisementId).set(ad.toJson());

          // Mettre à jour le post avec l'ID de la publicité
          await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
            'advertisementId': advertisementId,
          });
        }

        printVm('✅ Post créé avec ID: $postId, ${_selectedImages.length} images${_isAdvertisement ? ' (Publicité en attente)' : ''}');

        _descriptionController.clear();
        setState(() {
          onTap = false;
          _selectedImages.clear();
          _imageNames.clear();
          _selectedCountries.clear();
          _selectAllCountries = false;
          _isAdvertisement = false;
          _selectedActionType = null;
          _selectedDurationDays = null;
          _actionUrlController.clear();
        });

        if (widget.canal != null) {
          authProvider.sendPushNotificationToUsers(
              sender: authProvider.loginUserData,
              message: "Image 🖼️: ${post.description}",
              typeNotif: NotificationType.POST.name,
              postId: post.id!,
              postType: PostDataType.IMAGE.name,
              chatId: '',
              smallImage:post.images!.first!=null?post.images!.first: widget.canal!.urlImage,
              isChannel: true,
              channelTitle: widget.canal!.titre,
              canal: widget.canal
          );

          widget.canal!.updatedAt = DateTime.now().microsecondsSinceEpoch;
          widget.canal!.publication = (widget.canal!.publication ?? 0) + 1;
          FirebaseFirestore.instance.collection('Canaux').doc(widget.canal!.id).update({
            'updatedAt': widget.canal!.updatedAt,
            'publication': widget.canal!.publication,
          });
        } else {
          authProvider.sendPushNotificationToUsers(
            sender: authProvider.loginUserData,
            message: "Image 🖼️: ${post.description}",
            typeNotif: NotificationType.POST.name,
            postId: post.id!,
            postType: PostDataType.IMAGE.name,
            chatId: '',
            smallImage:post.images!.first!=null?post.images!.first: authProvider.loginUserData.imageUrl,

            isChannel: false,
          );
        }

        addPointsForAction(UserAction.post);

        Navigator.pop(context);

        String successMessage = _isAdvertisement
            ? 'Publication réussie ! Publicité en attente de validation.'
            : 'Publication réussie !';

        String countryMessage = _selectAllCountries
            ? 'Visible dans toute l\'Afrique'
            : 'Visible dans ${_selectedCountries.length} pays';

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
                    Text(successMessage, style: TextStyle(color: _c.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 4),
                Text('${_selectedImages.length} image(s) • $countryMessage', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
            backgroundColor: _c.surface,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        _checkPostCooldown();

      } catch (e) {
        printVm("❌ Erreur lors de la publication: $e");

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        setState(() => onTap = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la publication. Veuillez réessayer.', textAlign: TextAlign.center, style: TextStyle(color: _c.danger))),
        );
      }
    }
  }

  Widget _buildImageUpgradeBanner() {
    final abonnement = authProvider.loginUserData.abonnement;
    final isGold = AbonnementUtils.isGold(abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
    if (isGold || isAdmin) return const SizedBox.shrink();

    final isPremium = AbonnementUtils.isPremiumActive(abonnement);
    final String text;
    final Color color;
    if (isPremium) {
      text = '👑 Gold : jusqu\'à 5 images par post';
      color = const Color(0xFFFFD700);
    } else {
      text = '⭐ Premium : 3 images — 👑 Gold : 5 images par post';
      color = const Color(0xFFFDB813);
    }
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AbonnementScreen(),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.upgrade, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_selectedImages.isEmpty) {
      return GestureDetector(
        onTap: _selectImage,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: _c.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _c.border, width: 2, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 60, color: _c.textSecondary),
              SizedBox(height: 16),
              Text('Ajouter une image', style: TextStyle(color: _c.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Cliquez pour sélectionner\n(Gratuit : 1 • Premium : 3 • Gold 👑 : 5)', textAlign: TextAlign.center, style: TextStyle(color: _c.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _selectedImages.length == 1 ? 1 : 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _selectedImages.length,
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_selectedImages[index], fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                    child: IconButton(
                      icon: Icon(Icons.close, size: 18, color: Colors.white),
                      onPressed: () => _removeImage(index),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                    child: Text('${index + 1}', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildImageCounter()),
            SizedBox(width: 10),
            if (_selectedImages.length < _maxImages)
              ElevatedButton.icon(
                onPressed: _selectImage,
                icon: Icon(Icons.add, size: 16),
                label: Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _c.primary,
                  foregroundColor: _c.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _c.surface,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _c.primary, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.photo_library, color: Colors.white, size: 24),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Publication Image', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                            SizedBox(height: 4),
                            _buildImageCounter(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                if (!_canPost && _cooldownMinutes > 0) _buildCooldownAlert(),
                _buildPostTypeSelector(),
                _buildEventDatePicker(),
                _buildCountrySelectionCard(),
                // NOUVEAU: Section publicité
                _buildAfrolookAdsPromoButton(),
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _c.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _c.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _selectedImages.isNotEmpty ? _c.primary : _c.border, width: 2),
                          ),
                          child: _buildImageGrid(),
                        ),
                        _buildImageUpgradeBanner(),
                        SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _c.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _descriptionController,
                                style: TextStyle(color: _c.textPrimary, fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Décrivez votre image...',
                                  hintStyle: TextStyle(color: _c.textSecondary),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                ),
                                maxLines: 5,
                                onChanged: (value) => setState(() {}),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'La description est obligatoire';
                                  if (value.length < 10) return 'La description doit contenir au moins 10 caractères';
                                  if (value.length > _maxCharacters) return 'Limite de $_maxCharacters caractères dépassée';
                                  if (!value.contains('#')) return 'Ajoutez au moins un hashtag (#) à votre description';
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
                        HashtagSuggestionBar(
                          selectedPostType: _selectedPostType,
                          descriptionController: _descriptionController,
                          onHashtagAdded: () => setState(() {}),
                        ),
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: _c.primary.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _c.primary.withOpacity(0.18)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.tips_and_updates_outlined, color: _c.primary, size: 15),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Les #hashtags améliorent la visibilité de ton post, aident à mieux distribuer ton contenu aux bons utilisateurs et permettent des suggestions de commentaires plus pertinentes. Choisis des hashtags adaptés à ton sujet !',
                                  style: TextStyle(fontSize: 11.5, color: _c.textSecondary, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(color: _c.background, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(
                                authProvider.loginUserData.role == UserRole.ADM.name
                                    ? Icons.admin_panel_settings
                                    : AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement)
                                    ? Icons.workspace_premium
                                    : Icons.lock,
                                color: authProvider.loginUserData.role == UserRole.ADM.name
                                    ? _c.primary
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
                                      : AbonnementUtils.isGold(authProvider.loginUserData.abonnement)
                                      ? 'Gold 👑: Pays illimités • 5 images • 5000 caractères'
                                      : AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement)
                                      ? 'Mode Premium: Pays illimités • 3 images • 3000 caractères'
                                      : 'Mode Gratuit: Max 2 pays • 1 image • 300 caractères',
                                  style: TextStyle(color: _c.textSecondary, fontSize: 12),
                                ),
                              ),
                              if (!AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement) && authProvider.loginUserData.role != UserRole.ADM.name)
                                TextButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AbonnementScreen())),
                                  child: Text('PASSER À PREMIUM', style: TextStyle(color: Color(0xFFFDB813), fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: onTap || (!_canPost && _cooldownMinutes > 0)
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
                              onTap: onTap || (!_canPost && _cooldownMinutes > 0) ? null : _publishPost,
                              child: Center(
                                child: onTap
                                    ? LoadingAnimationWidget.flickr(size: 30, leftDotColor: Colors.white, rightDotColor: _c.accent)
                                    : (!_canPost && _cooldownMinutes > 0)
                                    ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.timer, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('Attendez $_timeRemaining', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: _c.accent, borderRadius: BorderRadius.circular(12)),
                                      child: InkWell(
                                        onTap: () => RewardedAdWidget.showAd(_rewardedAdKey),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_arrow, color: Colors.black, size: 16),
                                            Text('Pub', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                    : (_selectedCountries.isEmpty && !_selectAllCountries)
                                    ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.warning, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('SÉLECTIONNEZ UN PAYS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                )
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_isAdvertisement ? Iconsax.dollar_circle : Icons.send, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      _isAdvertisement ? 'PUBLIER LA PUBLICITÉ' : 'PUBLIER VOTRE POST',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    if (_isAdvertisement) ...[
                                      SizedBox(width: 4),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: _c.accent, borderRadius: BorderRadius.circular(8)),
                                        child: Text('PUB', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                    SizedBox(width: 4),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                      child: Text(
                                        _selectAllCountries ? '🌍' : '${_selectedCountries.length}',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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

