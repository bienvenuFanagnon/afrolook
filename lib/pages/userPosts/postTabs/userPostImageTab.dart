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
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:iconsax/iconsax.dart';

import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../services/postService/massNotificationService.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../../pub/rewarded_ad_widget.dart';
import '../../user/userAbonnementPage.dart';

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

  // Couleurs personnalisées
  final Color _primaryColor = Color(0xFFE21221); // Rouge
  final Color _secondaryColor = Color(0xFFFFD600); // Jaune
  final Color _backgroundColor = Color(0xFF121212); // Noir
  final Color _cardColor = Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;
  final Color _successColor = Color(0xFF4CAF50);
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
  void dispose() {
    _countrySearchController.removeListener(_filterCountries);
    _countrySearchController.dispose();
    _countrySearchFocus.dispose();
    _actionUrlController.dispose();
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
      _maxImages = 10;
      _maxCharacters = 5000;
      _cooldownMinutes = 0;
      return;
    }

    final isPremium = AbonnementUtils.isPremiumActive(abonnement);

    if (isPremium) {
      _maxImages = 3;
      _maxCharacters = 3000;
      _cooldownMinutes = 0;
    } else {
      _maxImages = 1;
      _maxCharacters = 300;
      _cooldownMinutes = 60;
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
      print("Erreur vérification cooldown: $e");
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
      _showPremiumModal(
        title: 'Limite d\'images atteinte',
        message: 'L\'abonnement gratuit est limité à 1 image.\nPassez à Afrolook Premium pour publier jusqu\'à 3 images.',
        actionText: 'VOIR L\'ABONNEMENT',
      );
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
        print("Erreur lors de la compression: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du traitement de l\'image', textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
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
      print("Erreur compression: $e");
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
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock, color: _primaryColor),
            SizedBox(width: 10),
            Text('Limite de pays atteinte', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('L\'abonnement gratuit est limité à 2 pays maximum.\nPassez à Afrolook Premium pour sélectionner tous les pays africains.',
                style: TextStyle(color: _hintColor)),
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
                        Text('Afrolook Premium', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
                        Text('Pays illimités • 3 images • Pas de cooldown', style: TextStyle(color: _hintColor, fontSize: 12)),
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => AbonnementScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor, foregroundColor: Colors.black),
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
        borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sélection des pays', style: TextStyle(color: _textColor, fontSize: 20, fontWeight: FontWeight.bold)),
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
                          Icon(isPremium || isAdmin ? Icons.workspace_premium : Icons.lock, size: 14,
                              color: isPremium || isAdmin ? _secondaryColor : _primaryColor),
                          SizedBox(width: 6),
                          Text(isPremium || isAdmin ? 'Pays illimités' : 'Max 2 pays',
                              style: TextStyle(color: isPremium || isAdmin ? _secondaryColor : _primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      _selectAllCountries ? '🌍 Tous les pays' : '${_selectedCountries.length} pays sélectionné(s)',
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
                child: Icon(Icons.workspace_premium, color: _selectAllCountries ? Colors.white : _hintColor),
              ),
              title: Row(
                children: [
                  Text('Tous les pays africains', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _secondaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text('PREMIUM', style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              subtitle: Text('Votre post sera visible dans toute l\'Afrique', style: TextStyle(color: _hintColor)),
              trailing: _selectAllCountries
                  ? Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: _successColor, shape: BoxShape.circle),
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
                final isDisabled = !isPremium && !isAdmin && _selectedCountries.length >= _maxCountriesForFree && !isSelected;

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
                      child: Center(child: Text(country.flag, style: TextStyle(fontSize: 20))),
                    ),
                    title: Text(country.name, style: TextStyle(color: isDisabled ? Colors.grey[600] : _textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('Code: ${country.code}', style: TextStyle(color: isDisabled ? Colors.grey[600] : _hintColor)),
                    trailing: isSelected
                        ? Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _primaryColor, shape: BoxShape.circle),
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
                        _selectAllCountries = false;
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))],
        border: Border.all(color: _selectedCountries.isEmpty && !_selectAllCountries ? Colors.orange : Colors.transparent, width: 1),
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
                    decoration: BoxDecoration(color: _selectAllCountries ? _secondaryColor : _primaryColor, borderRadius: BorderRadius.circular(10)),
                    child: Icon(_selectAllCountries ? Icons.workspace_premium : Icons.public, color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visibilité du post', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(displayMessage, style: TextStyle(color: _selectedCountries.isEmpty && !_selectAllCountries ? Colors.orange : _hintColor, fontSize: 14)),
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
                  style: TextStyle(color: isPremium || isAdmin ? _secondaryColor : _primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (_selectedCountries.isEmpty && !_selectAllCountries)
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
              child: Row(
                children: [
                  Icon(Icons.warning, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('Vous devez sélectionner au moins un pays', style: TextStyle(color: Colors.orange, fontSize: 12))),
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
                      decoration: BoxDecoration(color: _primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _primaryColor)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(country.flag),
                          SizedBox(width: 6),
                          Text(country.name, style: TextStyle(color: _textColor, fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (_selectedCountries.length > 3)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('+ ${_selectedCountries.length - 3} autres pays...', style: TextStyle(color: _hintColor, fontSize: 12)),
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

  // NOUVEAU: Widget pour la publicité
  Widget _buildAdvertisementCard() {
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);

    // Seuls les admins et premiums peuvent créer des pubs
    // if (!isAdmin && !isPremium) {
    if (!isAdmin) {
      return Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _secondaryColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.dollar_circle, color: _secondaryColor),
                SizedBox(width: 10),
                Text('Publicité', style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _secondaryColor, borderRadius: BorderRadius.circular(12)),
                  child: Text('PREMIUM', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[900]!, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.lock, color: _hintColor, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fonctionnalité réservée', style: TextStyle(color: _hintColor, fontWeight: FontWeight.bold)),
                        Text('Passez à Premium pour créer des publicités avec boutons d\'action', style: TextStyle(color: _hintColor, fontSize: 12)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AbonnementScreen())),
                    child: Text('VOIR', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isAdvertisement ? _secondaryColor : Colors.transparent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.dollar_circle, color: _secondaryColor),
              SizedBox(width: 10),
              Text('Publicité', style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              Spacer(),
              Switch(
                value: _isAdvertisement,
                onChanged: (value) {
                  setState(() {
                    _isAdvertisement = value;
                    if (!value) {
                      _selectedActionType = null;
                      _selectedDurationDays = null;
                      _actionUrlController.clear();
                    }
                  });
                },
                activeColor: _secondaryColor,
                activeTrackColor: _secondaryColor.withOpacity(0.3),
              ),
            ],
          ),
          if (_isAdvertisement) ...[
            SizedBox(height: 16),
            // Type d'action
            Text('Type d\'action', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Row(
                children: _actionTypes.entries.map((entry) {
                  final isSelected = _selectedActionType == entry.key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedActionType = entry.key),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? _secondaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(entry.value['icon'], color: isSelected ? Colors.black : _hintColor, size: 16),
                            SizedBox(width: 4),
                            Text(
                              entry.value['label'],
                              style: TextStyle(
                                color: isSelected ? Colors.black : _hintColor,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16),
            // Lien d'action
            Text('Lien du bouton', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: TextFormField(
                controller: _actionUrlController,
                style: TextStyle(color: _textColor),
                decoration: InputDecoration(
                  hintText: _selectedActionType != null ? _actionTypes[_selectedActionType]!['hint'] : 'https://...',
                  hintStyle: TextStyle(color: _hintColor, fontSize: 14),
                  prefixIcon: Icon(Icons.link, color: _primaryColor, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  if (_isAdvertisement && (value == null || value.isEmpty)) {
                    return 'Le lien est requis';
                  }
                  if (_isAdvertisement && value != null && value.isNotEmpty && !value.startsWith('http')) {
                    return 'Le lien doit commencer par http:// ou https://';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(height: 16),
            // Durée
            Text('Durée de la publicité', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedDurationDays,
                  hint: Text('Choisir la durée', style: TextStyle(color: _hintColor)),
                  dropdownColor: _cardColor,
                  style: TextStyle(color: _textColor),
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
                  items: _durationOptions.map((days) {
                    String label;
                    if (days < 30) {
                      label = '$days jours';
                    } else if (days == 30) {
                      label = '1 mois';
                    } else if (days == 90) {
                      label = '3 mois';
                    } else if (days == 180) {
                      label = '6 mois';
                    } else if (days == 365) {
                      label = '12 mois';
                    } else {
                      label = '$days jours';
                    }
                    return DropdownMenuItem(
                      value: days,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: _secondaryColor),
                          SizedBox(width: 8),
                          Text(label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedDurationDays = value),
                ),
              ),
            ),
            if (_selectedDurationDays != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'La publicité sera active pendant ${_selectedDurationDays} jours',
                  style: TextStyle(color: _hintColor, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
          ],
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
                    Text('Temps d\'attente', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Prochain post dans: $_timeRemaining', style: TextStyle(color: _hintColor, fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _secondaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(_timeRemaining, style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: Column(
              children: [
                Divider(color: Colors.grey[800]),
                SizedBox(height: 12),
                Text('OU', style: TextStyle(color: _hintColor, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                RewardedAdWidget(
                  key: _rewardedAdKey,
                  onUserEarnedReward: (double amount, String name) {
                    print('RewardedAdWidget - amount : $amount -- name: $name');
                    setState(() {
                      _canPost = true;
                      _timeRemaining = '';
                      _showRewardedAd = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merci ! Vous pouvez poster maintenant !', style: TextStyle(color: Colors.green)), backgroundColor: _cardColor, behavior: SnackBarBehavior.floating));

                  },
                  // onUserEarnedReward: (reward) {
                  //   setState(() {
                  //     _canPost = true;
                  //     _timeRemaining = '';
                  //     _showRewardedAd = false;
                  //   });
                  //   ScaffoldMessenger.of(context).showSnackBar(
                  //     SnackBar(
                  //       content: Text('Merci ! Vous pouvez poster maintenant !', style: TextStyle(color: Colors.green)),
                  //       backgroundColor: _cardColor,
                  //       behavior: SnackBarBehavior.floating,
                  //     ),
                  //   );
                  // },
                  onAdDismissed: () => setState(() => _showRewardedAd = false),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: _secondaryColor, borderRadius: BorderRadius.circular(12)),
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
                    textAlign: TextAlign.center, style: TextStyle(color: _hintColor, fontSize: 11)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text('Type de publication', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              hintText: 'Choisir un type de publication',
              hintStyle: TextStyle(color: _hintColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[700]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[700]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor)),
              filled: true,
              fillColor: _backgroundColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            dropdownColor: _cardColor,
            style: TextStyle(color: _textColor, fontSize: 14),
            value: _selectedPostType,
            onChanged: (String? newValue) => setState(() => _selectedPostType = newValue),
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
            validator: (value) => value == null || value.isEmpty ? 'Veuillez sélectionner un type de post' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildImageCounter() {
    final isPremium = AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    String statusText;
    Color statusColor;

    if (isAdmin) {
      statusText = 'Admin • Images illimitées';
      statusColor = Colors.green;
    } else if (isPremium) {
      statusText = 'Premium • ${_selectedImages.length}/3 images';
      statusColor = Color(0xFFFDB813);
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
    Color counterColor = textLength > _maxCharacters ? Colors.red : (percentage > 0.8 ? Colors.orange : Colors.green);

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

  void _showPremiumModal({required String title, required String message, required String actionText}) {
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
                        Text('Afrolook Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Pays illimités • 3 images • 3000 caractères', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFDB813), foregroundColor: Colors.black),
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
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.timer, color: _secondaryColor),
            SizedBox(width: 10),
            Text('Temps d\'attente', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vous devez attendre $_timeRemaining avant de pouvoir publier.', style: TextStyle(color: _hintColor)),
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
                  Text('Regardez une publicité', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('et publiez immédiatement !', style: TextStyle(color: _secondaryColor, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ATTENDRE', style: TextStyle(color: _hintColor))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _showRewardedAd = true);
              RewardedAdWidget.showAd(_rewardedAdKey);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor, foregroundColor: Colors.black),
            child: Text('REGARDER LA PUB'),
          ),
        ],
      ),
    );
  }

  Future<void> _publishPost() async {
    if (!_canPost && _cooldownMinutes > 0) {
      _showRewardedAdOption();
      return;
    }

    if (widget.canal != null) {
      final currentUserId = authProvider.loginUserData.id;
      final isOwner = currentUserId == widget.canal!.userId;
      final isAdmin = widget.canal!.adminIds?.contains(currentUserId) == true;
      final canPost = widget.canal!.allowedPostersIds?.contains(currentUserId) == true;
      final isMember = widget.canal!.usersSuiviId?.contains(currentUserId) == true;

      if (!isAdmin && !canPost) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Vous n\'êtes pas autorisé à poster dans ce canal', textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
        );
        return;
      }
      if (!isMember) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Vous devez être abonné au canal pour poster', textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
        );
        return;
      }
    }

    if (_formKey.currentState!.validate()) {
      if (_selectedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner au moins une image', textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
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
          SnackBar(content: Text('Veuillez sélectionner au moins un pays', textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
        );
        return;
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
            SnackBar(content: Text('Veuillez sélectionner un type d\'action pour la publicité', textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
          );
          return;
        }
        if (_actionUrlController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Veuillez saisir le lien de la publicité', textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
          );
          return;
        }
        if (_selectedDurationDays == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Veuillez sélectionner la durée de la publicité', textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
          );
          return;
        }
      }

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
                  LoadingAnimationWidget.flickr(size: 50, leftDotColor: _primaryColor, rightDotColor: _secondaryColor),
                  SizedBox(height: 16),
                  Text('Publication en cours...', style: TextStyle(color: _textColor)),
                  SizedBox(height: 8),
                  Text(
                    '${_selectedImages.length} image(s) • ${_selectAllCountries ? 'Toute l\'Afrique' : '${_selectedCountries.length} pays'}${_isAdvertisement ? ' • Publicité' : ''}',
                    style: TextStyle(color: _hintColor, fontSize: 12),
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
          ..isAdvertisement = _isAdvertisement; // Nouveau champ

        if (_selectAllCountries) {
          post.availableCountries = ['ALL'];
        } else {
          post.availableCountries = _selectedCountries.map((c) => c.code).toList();
        }

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

        print('✅ Post créé avec ID: $postId, ${_selectedImages.length} images${_isAdvertisement ? ' (Publicité en attente)' : ''}');

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
              smallImage: widget.canal!.urlImage,
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
            smallImage: authProvider.loginUserData.imageUrl,
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
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(successMessage, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 4),
                Text('${_selectedImages.length} image(s) • $countryMessage', style: TextStyle(color: Colors.white, fontSize: 12)),
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
        print("❌ Erreur lors de la publication: $e");

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        setState(() => onTap = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la publication. Veuillez réessayer.', textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
        );
      }
    }
  }

  Widget _buildImageGrid() {
    if (_selectedImages.isEmpty) {
      return GestureDetector(
        onTap: _selectImage,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[700]!, width: 2, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 60, color: _hintColor),
              SizedBox(height: 16),
              Text('Ajouter une image', style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Cliquez pour sélectionner\n(1 image pour gratuit, 3 pour Premium)', textAlign: TextAlign.center, style: TextStyle(color: _hintColor, fontSize: 12)),
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
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
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
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.photo_library, color: Colors.white, size: 24),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Publication Image', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 18)),
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
                _buildCountrySelectionCard(),
                // NOUVEAU: Section publicité
                _buildAdvertisementCard(),
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardColor,
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
                            color: _backgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _selectedImages.isNotEmpty ? _primaryColor : Colors.grey[700]!, width: 2),
                          ),
                          child: _buildImageGrid(),
                        ),
                        SizedBox(height: 20),
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
                                  hintText: 'Décrivez votre image...',
                                  hintStyle: TextStyle(color: _hintColor),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                ),
                                maxLines: 5,
                                onChanged: (value) => setState(() {}),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'La description est obligatoire';
                                  if (value.length < 10) return 'La description doit contenir au moins 10 caractères';
                                  if (value.length > _maxCharacters) return 'Limite de $_maxCharacters caractères dépassée';
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
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
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
                                      ? 'Mode Premium: Pays illimités • 3 images • 3000 caractères'
                                      : 'Mode Gratuit: Max 2 pays • 1 image • 300 caractères',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
                                  : [_primaryColor, Color(0xFFFF5252)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(25),
                              onTap: onTap || (!_canPost && _cooldownMinutes > 0) ? null : _publishPost,
                              child: Center(
                                child: onTap
                                    ? LoadingAnimationWidget.flickr(size: 30, leftDotColor: Colors.white, rightDotColor: _secondaryColor)
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
                                      decoration: BoxDecoration(color: _secondaryColor, borderRadius: BorderRadius.circular(12)),
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
                                        decoration: BoxDecoration(color: _secondaryColor, borderRadius: BorderRadius.circular(8)),
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


