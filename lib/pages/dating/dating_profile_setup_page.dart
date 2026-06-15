// lib/pages/creator/creator_profile_page.dart
import 'package:afrotok/pages/dating/dating_entry_page.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dating_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/creator_provider.dart';
import 'creator_content_detail_page.dart';
import 'creator_subscription_page.dart';
// lib/pages/dating/dating_profile_setup_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List, debugPrint;

import '../../models/dating_data.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

import 'package:flutter/foundation.dart' show kIsWeb;


class DatingProfileSetupPage extends StatefulWidget {
  final DatingProfile? profile;

  const DatingProfileSetupPage({Key? key, this.profile}) : super(key: key);

  @override
  State<DatingProfileSetupPage> createState() => _DatingProfileSetupPageState();
}

class _DatingProfileSetupPageState extends State<DatingProfileSetupPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  late TextEditingController _pseudoController;
  late TextEditingController _bioController;
  late TextEditingController _ageController;
  late TextEditingController _professionController;

  // Sélecteurs
  String _selectedSexe = 'femme';
  String _selectedRechercheSexe = 'homme';
  int _rechercheAgeMin = 18;
  int _rechercheAgeMax = 50;
  List<String> _centresInteret = [];
  final List<String> _availableInterets = [
    '🎵 Musique', '🎬 Cinéma', '📚 Lecture', '🏃 Sport', '✈️ Voyage',
    '🍳 Cuisine', '📸 Photo', '🎮 Jeux vidéo', '🎨 Art', '🐾 Animaux',
    '🌿 Nature', '💃 Danse', '🧘 Yoga', '💻 Tech', '📝 Écriture',
    '🎭 Théâtre', '🏊 Natation', '🚴 Vélo', '🏋️ Fitness', '🧩 Puzzles',
  ];

  // Localisation
  String _selectedCountry = "";
  String _selectedRegion = "";
  String _selectedCity = "";
  String? _detectedCountryCode;
  String? _detectedCountryName;
  double? _detectedLatitude;
  double? _detectedLongitude;
  bool _isLoadingLocation = false;
  bool _hasRequestedLocation = false;
  bool _locationPermissionDenied = false;

  // Images - Support Web et Mobile
  List<Uint8List> _selectedImagesBytes = []; // Pour le web
  List<XFile> _selectedImagesFiles = []; // Pour mobile
  List<String> _existingImages = [];
  bool _isUploading = false;
  static const int _maxPhotos = 3; // Limite à 3 photos maximum

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Couleurs
  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color primaryBlack = Colors.black;
  final Color secondaryGrey = const Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initAnimations();
    _loadExistingData();
    _detectLocationInBackground();
  }

  void _initControllers() {
    _pseudoController = TextEditingController(text: widget.profile?.pseudo ?? '');
    _bioController = TextEditingController(text: widget.profile?.bio ?? '');
    _ageController = TextEditingController(text: widget.profile?.age.toString() ?? '');
    _professionController = TextEditingController(text: widget.profile?.profession ?? '');
    _selectedSexe = (widget.profile?.sexe ?? 'femme').toLowerCase();
    _selectedRechercheSexe = widget.profile?.rechercheSexe ?? 'homme';
    _rechercheAgeMin = widget.profile?.rechercheAgeMin ?? 18;
    _rechercheAgeMax = widget.profile?.rechercheAgeMax ?? 50;
    _centresInteret = widget.profile?.centresInteret ?? [];
    _existingImages = widget.profile?.photosUrls ?? [];
    _selectedCountry = widget.profile?.pays ?? '';
    _selectedRegion = widget.profile?.region ?? '';
    _selectedCity = widget.profile?.ville ?? '';
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  void _loadExistingData() {
    if (widget.profile != null) {
      _selectedCountry = widget.profile!.pays;
      _selectedRegion = widget.profile!.region ?? '';
      _selectedCity = widget.profile!.ville;
    }
  }

  Future<void> _detectLocationInBackground() async {
    if (kIsWeb || _hasRequestedLocation) return;

    setState(() {
      _hasRequestedLocation = true;
      _isLoadingLocation = true;
    });

    PermissionStatus permission = await Permission.location.request();

    setState(() => _locationPermissionDenied = !permission.isGranted);

    if (permission.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        setState(() {
          _detectedLatitude = position.latitude;
          _detectedLongitude = position.longitude;
        });

        if (placemarks.isNotEmpty) {
          setState(() {
            _detectedCountryCode = placemarks[0].isoCountryCode;
            _detectedCountryName = placemarks[0].country;
            if (_selectedCountry.isEmpty) {
              _selectedCountry = _detectedCountryName ?? '';
            }
          });
          debugPrint("📍 Localisation détectée: $_detectedCountryName ($_detectedCountryCode) - lat: $_detectedLatitude, lng: $_detectedLongitude");
        }
      } catch (e) {
        print("❌ Erreur localisation: $e");
      }
    }

    setState(() => _isLoadingLocation = false);
  }

  Future<void> _pickImages() async {
    // Vérifier la limite de photos
    final currentTotal = _existingImages.length +
        (_selectedImagesBytes.length + _selectedImagesFiles.length);

    if (currentTotal >= _maxPhotos) {
      _showError(AppLocalizations.of(context).datingMaxPhotosError.replaceAll('{max}', '$_maxPhotos'));
      return;
    }

    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        final remainingSlots = _maxPhotos - currentTotal;
        final filesToAdd = pickedFiles.take(remainingSlots).toList();

        if (pickedFiles.length > remainingSlots) {
          _showError(AppLocalizations.of(context).datingPhotoLimitInfo
              .replaceAll('{max}', '$_maxPhotos')
              .replaceAll('{count}', '${filesToAdd.length}'));
        }

        if (kIsWeb) {
          // Web: Convertir en Uint8List
          for (var file in filesToAdd) {
            final bytes = await file.readAsBytes();
            setState(() {
              _selectedImagesBytes.add(bytes);
            });
          }
        } else {
          // Mobile: Garder les XFile
          setState(() {
            _selectedImagesFiles.addAll(filesToAdd);
          });
        }

        print('✅ ${filesToAdd.length} photos sélectionnées');
      }
    } catch (e) {
      print('❌ Erreur sélection image: $e');
      _showError(AppLocalizations.of(context).datingErrorSelectImages);
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> uploadedUrls = [];
    setState(() => _isUploading = true);

    try {
      // Upload des images existantes (déjà en ligne, rien à faire)
      uploadedUrls.addAll(_existingImages);

      // Upload des nouvelles images
      // Pour mobile (XFile)
      for (int i = 0; i < _selectedImagesFiles.length; i++) {
        final file = _selectedImagesFiles[i];
        final fileName = 'dating_profile_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('dating_profiles')
            .child(fileName);

        if (kIsWeb) {
          // Web: utiliser les bytes
          final bytes = await file.readAsBytes();
          await ref.putData(bytes);
        } else {
          // Mobile: utiliser File
          await ref.putFile(File(file.path));
        }

        final url = await ref.getDownloadURL();
        uploadedUrls.add(url);
        print("✅ Image uploadée: $url");
      }

      // Upload des images web (Uint8List)
      for (int i = 0; i < _selectedImagesBytes.length; i++) {
        final bytes = _selectedImagesBytes[i];
        final fileName = 'dating_profile_${DateTime.now().millisecondsSinceEpoch}_web_$i.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('dating_profiles')
            .child(fileName);

        await ref.putData(bytes);
        final url = await ref.getDownloadURL();
        uploadedUrls.add(url);
        print("✅ Image web uploadée: $url");
      }

    } catch (e) {
      print("❌ Erreur upload image: $e");
      _showError(AppLocalizations.of(context).datingErrorUploadImages);
    }

    setState(() => _isUploading = false);
    return uploadedUrls;
  }

  void _removeImage(int index, bool isExisting, {bool isBytes = false}) {
    setState(() {
      if (isExisting) {
        _existingImages.removeAt(index);
      } else if (isBytes && kIsWeb) {
        _selectedImagesBytes.removeAt(index);
      } else {
        _selectedImagesFiles.removeAt(index);
      }
    });
  }

  int _getTotalImageCount() {
    return _existingImages.length +
        _selectedImagesFiles.length +
        _selectedImagesBytes.length;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCountry.isEmpty) {
      _showError(AppLocalizations.of(context).datingSelectCountryRequired);
      return;
    }

    if (_getTotalImageCount() == 0) {
      _showError(AppLocalizations.of(context).datingAddAtLeastOnePhoto);
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload des images
      final allPhotosUrls = await _uploadImages();

      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final userId = authProvider.loginUserData.id;
      if (userId == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final isEditing = widget.profile != null;

      final datingProfile = DatingProfile(
        id: widget.profile?.id ?? _firestore.collection('dating_profiles').doc().id,
        userId: userId,
        pseudo: _pseudoController.text.trim(),
        imageUrl: allPhotosUrls.isNotEmpty ? allPhotosUrls.first : '',
        photosUrls: allPhotosUrls,
        bio: _bioController.text.trim(),
        age: int.parse(_ageController.text),
        sexe: _selectedSexe.toLowerCase(),
        ville: _selectedCity,
        pays: _selectedCountry,
        profession: _professionController.text.trim().isEmpty
            ? null
            : _professionController.text.trim(),
        centresInteret: _centresInteret,
        rechercheSexe: _selectedRechercheSexe.toLowerCase(),
        rechercheAgeMin: _rechercheAgeMin,
        rechercheAgeMax: _rechercheAgeMax,
        recherchePays: _selectedCountry,
        isVerified: widget.profile?.isVerified ?? false,
        isActive: true,
        isProfileComplete: true,
        completionPercentage: 100,
        createdByMigration: widget.profile?.createdByMigration ?? false,
        likesCount: widget.profile?.likesCount ?? 0,
        coupsDeCoeurCount: widget.profile?.coupsDeCoeurCount ?? 0,
        connexionsCount: widget.profile?.connexionsCount ?? 0,
        visitorsCount: widget.profile?.visitorsCount ?? 0,
        createdAt: widget.profile?.createdAt ?? now,
        updatedAt: now,
        countryCode: _detectedCountryCode ?? widget.profile?.countryCode,
        region: _selectedRegion.isNotEmpty ? _selectedRegion : null,
        city: _selectedCity.isNotEmpty ? _selectedCity : null,
        latitude: _detectedLatitude ?? widget.profile?.latitude,
        longitude: _detectedLongitude ?? widget.profile?.longitude,
        popularityScore: widget.profile?.popularityScore ?? 0,
      );

      await _firestore
          .collection('dating_profiles')
          .doc(datingProfile.id)
          .set(datingProfile.toJson());

      print("✅ Profil dating enregistré avec succès");

      if (mounted) {
        _showSuccess(isEditing ? AppLocalizations.of(context).datingProfileUpdated : AppLocalizations.of(context).datingProfileCreated);
        Navigator.pushReplacement(context, MaterialPageRoute(builder:(context) => DatingSwipePage(),));
      }
    } catch (e) {
      print("❌ Erreur sauvegarde profil: $e");
      _showError(AppLocalizations.of(context).datingErrorGeneric.replaceAll('{error}', e.toString()));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }

  void _toggleInteret(String interet) {
    setState(() {
      if (_centresInteret.contains(interet)) {
        _centresInteret.remove(interet);
      } else {
        _centresInteret.add(interet);
      }
    });
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _professionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Widget pour afficher une image (compatible web et mobile)
  Widget _buildImagePreview(dynamic image, int index, bool isExisting) {
    ImageProvider imageProvider;

    if (isExisting) {
      imageProvider = NetworkImage(_cdnUrl(image));
    } else if (kIsWeb && image is Uint8List) {
      imageProvider = MemoryImage(image);
    } else if (!kIsWeb && image is XFile) {
      imageProvider = FileImage(File(image.path));
    } else {
      imageProvider = const AssetImage('assets/placeholder.png');
    }

    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: GestureDetector(
            onTap: () {
              if (isExisting) {
                _removeImage(index, true);
              } else if (kIsWeb && image is Uint8List) {
                _removeImage(index, false, isBytes: true);
              } else {
                _removeImage(index, false);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildPhotoSection(),
                      const SizedBox(height: 24),
                      _buildPersonalInfoSection(),
                      const SizedBox(height: 24),
                      _buildLocationSection(),
                      const SizedBox(height: 24),
                      _buildInterestsSection(),
                      const SizedBox(height: 24),
                      _buildSearchPreferencesSection(),
                      const SizedBox(height: 32),
                      _buildSaveButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final t = AppLocalizations.of(context);
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryRed, primaryYellow],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.profile == null ? Icons.person_add : Icons.edit,
            size: 40,
            color: primaryBlack,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.profile == null ? t.datingCreateYourProfile : t.datingEditMyProfile,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.datingMeetPeopleSubtitle,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final totalPhotos = _getTotalImageCount();
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t.datingPhotosLabel,
              style: TextStyle(
                color: primaryYellow,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$totalPhotos/$_maxPhotos',
                style: TextStyle(
                  color: primaryYellow,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t.datingAddUpToPhotos.replaceAll('{max}', '$_maxPhotos'),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: totalPhotos + (totalPhotos < _maxPhotos ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == totalPhotos) {
                return _buildAddPhotoButton();
              }

              // Afficher les images existantes
              if (index < _existingImages.length) {
                return _buildImagePreview(_existingImages[index], index, true);
              }

              // Afficher les nouvelles images web (Uint8List)
              final webIndex = index - _existingImages.length;
              if (kIsWeb && webIndex < _selectedImagesBytes.length) {
                return _buildImagePreview(_selectedImagesBytes[webIndex], webIndex, false);
              }

              // Afficher les nouvelles images mobile (XFile)
              final mobileIndex = index - _existingImages.length;
              if (!kIsWeb && mobileIndex < _selectedImagesFiles.length) {
                return _buildImagePreview(_selectedImagesFiles[mobileIndex], mobileIndex, false);
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: secondaryGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryRed.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: primaryYellow, size: 30),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).datingAddLabel,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.datingPersonalInfoSection,
          style: TextStyle(
            color: primaryYellow,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pseudoController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: t.datingPseudoLabel,
            labelStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.person, color: primaryRed),
            filled: true,
            fillColor: secondaryGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) =>
          value == null || value.isEmpty ? t.datingFieldRequired : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ageController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: t.datingAgeLabel,
            labelStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.cake, color: primaryRed),
            filled: true,
            fillColor: secondaryGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return t.datingFieldRequired;
            final age = int.tryParse(value);
            if (age == null || age < 18 || age > 100) {
              return t.datingInvalidAge;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedSexe,
          style: const TextStyle(color: Colors.white),
          dropdownColor: secondaryGrey,
          decoration: InputDecoration(
            labelText: t.datingIAmLabel,
            labelStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.people, color: primaryRed),
            filled: true,
            fillColor: secondaryGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: [
            DropdownMenuItem(value: 'femme', child: Text(t.datingFemale)),
            DropdownMenuItem(value: 'homme', child: Text(t.datingMale)),
          ],
          onChanged: (value) => setState(() => _selectedSexe = value!),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _professionController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: t.datingProfessionOptional,
            labelStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.work, color: primaryRed),
            filled: true,
            fillColor: secondaryGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bioController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            labelText: t.datingBioLabel,
            labelStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.description, color: primaryRed),
            filled: true,
            fillColor: secondaryGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) =>
          value == null || value.isEmpty ? t.datingFieldRequired : null,
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.datingLocationSection,
          style: TextStyle(
            color: primaryYellow,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          kIsWeb
              ? t.datingSelectCountryRegion
              : t.datingSelectCountryRegionAuto,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryYellow.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: primaryYellow),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.datingLocationWhyDesc,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_locationPermissionDenied) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryRed.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_off, size: 16, color: primaryRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.datingLocationPermissionDeniedTitle,
                        style: TextStyle(color: primaryRed, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  t.datingLocationPermissionDeniedDesc,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: Icon(Icons.settings, size: 16, color: primaryYellow),
                    label: Text(t.datingOpenSettings, style: TextStyle(color: primaryYellow)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryYellow.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        CSCPickerPlus(
          showStates: true,
          showCities: true,
          defaultCountry: _selectedCountry.isEmpty ? CscCountry.Togo : null,
          currentCountry: _selectedCountry.isNotEmpty ? _selectedCountry : null,
          currentState: _selectedRegion.isNotEmpty ? _selectedRegion : null,
          currentCity: _selectedCity.isNotEmpty ? _selectedCity : null,
          flagState: CountryFlag.SHOW_IN_DROP_DOWN_ONLY,
          dropdownDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: secondaryGrey,
            border: Border.all(color: primaryRed.withOpacity(0.5)),
          ),
          disabledDropdownDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[800],
            border: Border.all(color: Colors.grey[700]!),
          ),
          countrySearchPlaceholder: t.datingSearchCountryPlaceholder,
          stateSearchPlaceholder: t.datingSearchRegionPlaceholder,
          citySearchPlaceholder: t.datingSearchCityPlaceholder,
          countryDropdownLabel: t.datingSelectCountryDropdownLabel,
          stateDropdownLabel: t.datingSelectRegionDropdownLabel,
          cityDropdownLabel: t.datingSelectCityDropdownLabel,
          selectedItemStyle: TextStyle(color: primaryYellow, fontSize: 14),
          dropdownHeadingStyle: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
          dropdownItemStyle: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
          dropdownDialogRadius: 16.0,
          searchBarRadius: 12.0,
          onCountryChanged: (value) => setState(() => _selectedCountry = value),
          onStateChanged: (value) => setState(() => _selectedRegion = value ?? ""),
          onCityChanged: (value) => setState(() => _selectedCity = value ?? ""),
        ),
        if (_isLoadingLocation)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryYellow,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t.datingDetectingLocation,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        if (_detectedCountryName != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, size: 14, color: primaryYellow),
                  const SizedBox(width: 4),
                  Text(
                    t.datingLocationDetected.replaceAll('{country}', '$_detectedCountryName'),
                    style: TextStyle(color: primaryYellow, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInterestsSection() {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.datingInterests,
          style: TextStyle(
            color: primaryYellow,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.datingSelectAtLeast3Interests,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _availableInterets.map((interet) {
            final isSelected = _centresInteret.contains(interet);
            return FilterChip(
              label: Text(interet),
              selected: isSelected,
              onSelected: (_) => _toggleInteret(interet),
              backgroundColor: secondaryGrey,
              selectedColor: primaryRed,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[300],
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? primaryRed : Colors.grey[700]!,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchPreferencesSection() {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.datingSearchSection,
          style: TextStyle(
            color: primaryYellow,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedRechercheSexe,
          style: const TextStyle(color: Colors.white),
          dropdownColor: secondaryGrey,
          decoration: InputDecoration(
            labelText: t.datingSearchingForLabel,
            labelStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.favorite, color: primaryRed),
            filled: true,
            fillColor: secondaryGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: [
            DropdownMenuItem(value: 'homme', child: Text(t.datingMen)),
            DropdownMenuItem(value: 'femme', child: Text(t.datingWomen)),
            DropdownMenuItem(value: 'tous', child: Text(t.datingAll)),
          ],
          onChanged: (value) => setState(() => _selectedRechercheSexe = value!),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.datingMinAgeLabel,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: secondaryGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _rechercheAgeMin,
                        dropdownColor: secondaryGrey,
                        style: const TextStyle(color: Colors.white),
                        items: List.generate(83, (i) => i + 18).map((age) {
                          return DropdownMenuItem(
                            value: age,
                            child: Text(t.datingAgeYears.replaceAll('{age}', '$age')),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _rechercheAgeMin = value!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.datingMaxAgeLabel,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: secondaryGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _rechercheAgeMax,
                        dropdownColor: secondaryGrey,
                        style: const TextStyle(color: Colors.white),
                        items: List.generate(83, (i) => i + 18).map((age) {
                          return DropdownMenuItem(
                            value: age,
                            child: Text(t.datingAgeYears.replaceAll('{age}', '$age')),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _rechercheAgeMax = value!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _saveProfile,
        child: _isUploading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: primaryBlack,
          ),
        )
            : Text(
          widget.profile == null ? AppLocalizations.of(context).datingCreateProfileButton : AppLocalizations.of(context).datingSaveButton,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryYellow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}