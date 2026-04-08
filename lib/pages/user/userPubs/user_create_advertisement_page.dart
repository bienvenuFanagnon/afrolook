// user_create_advertisement_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:iconsax/iconsax.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../paiement/depotPaiment.dart';
import '../../paiement/newDepot.dart'; // à adapter selon votre chemin


// user_create_advertisement_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../paiement/depotPaiment.dart';

class UserCreateAdvertisementPage extends StatefulWidget {
  const UserCreateAdvertisementPage({Key? key}) : super(key: key);

  @override
  State<UserCreateAdvertisementPage> createState() => _UserCreateAdvertisementPageState();
}

class _UserCreateAdvertisementPageState extends State<UserCreateAdvertisementPage> {
  // Controllers
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _actionUrlController = TextEditingController();
  final TextEditingController _countrySearchController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final FocusNode _countrySearchFocus = FocusNode();

  // Types
  String? _selectedAdType; // 'image' ou 'video'
  String? _selectedActionType; // 'download', 'visit', 'learn_more', 'whatsapp'
  int? _selectedDurationWeeks; // 2, 4, 12, 24, 52 (semaines)

  // Pays
  List<AfricanCountry> _selectedCountries = [];
  List<AfricanCountry> _filteredCountries = [];
  bool _showCountrySelection = false;
  bool _selectAllCountries = false;

  // Médias (images)
  List<Uint8List> _selectedImages = [];
  List<String> _imageNames = [];

  // Vidéo
  XFile? _videoFile;
  Uint8List? _videoBytes;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  String? _localThumbnailPath;
  String? _generatedThumbnailUrl;
  bool _isGeneratingThumbnail = false;
  bool _isUploadingThumbnail = false;
  bool _useCustomThumbnail = false;
  XFile? _customThumbnailFile;
  Uint8List? _customThumbnailBytes;
  bool _isUploadingCustomThumbnail = false;
  bool _isPickingVideo = false;

  bool _isUploading = false;
  double _uploadProgress = 0;

  // Tarifs (semaines)
  final Map<int, int> _durationPrices = {
    2: 2500,   // 2 semaines
    4: 4500,   // 1 mois
    12: 10000, // 3 mois
    24: 18000, // 6 mois
    52: 30000, // 12 mois
  };
  final List<int> _durationOptions = [2, 4, 12, 24, 52];

  // Couleurs
  final Color _primaryColor = const Color(0xFFE21221);
  final Color _secondaryColor = const Color(0xFFFFD600);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;

  late UserAuthProvider authProvider;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _filteredCountries = List.from(AfricanCountry.allCountries);
    _countrySearchController.addListener(_filterCountries);
  }

  @override
  void dispose() {
    _countrySearchController.dispose();
    _countrySearchFocus.dispose();
    _actionUrlController.dispose();
    _whatsappController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
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

  // ========== GESTION DES IMAGES ==========
  int get maxImagesForDuration {
    if (_selectedDurationWeeks == null) return 3;
    return _selectedDurationWeeks! >= 4 ? 5 : 3;
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= maxImagesForDuration) {
      _showError('Maximum $maxImagesForDuration images pour cette durée');
      return;
    }
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 85, maxWidth: 1920, maxHeight: 1080);
    if (images != null) {
      for (var img in images) {
        final bytes = await img.readAsBytes();
        final compressed = await _compressImage(bytes);
        setState(() {
          _selectedImages.add(compressed);
          _imageNames.add(img.name);
        });
        if (_selectedImages.length >= maxImagesForDuration) break;
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
      return bytes;
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageNames.removeAt(index);
    });
  }

  // ========== GESTION DE LA VIDÉO ==========
  Future<void> _pickVideo() async {
    if (_isPickingVideo) return;
    _isPickingVideo = true;

    // Afficher le dialogue de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
              SizedBox(height: 16),
              Text('Traitement de la vidéo...', style: TextStyle(color: _textColor)),
              SizedBox(height: 8),
              Text('Initialisation et génération de la miniature', style: TextStyle(color: _hintColor, fontSize: 12)),
            ],
          ),
        );
      },
    );

    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) {
        _isPickingVideo = false;
        Navigator.pop(context);
        return;
      }

      // Vérifier la durée
      final controller = VideoPlayerController.file(File(video.path));
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();

      if (duration.inSeconds > 240) {
        Navigator.pop(context);
        _showError('La vidéo ne doit pas dépasser 4 minutes');
        _isPickingVideo = false;
        return;
      }
      if (duration.inSeconds > 30) {
        _showDurationWarning();
      }

      // Initialiser le lecteur vidéo pour l'aperçu
      _videoController = VideoPlayerController.file(File(video.path));
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _primaryColor,
          handleColor: _primaryColor,
          backgroundColor: _hintColor.withOpacity(0.3),
          bufferedColor: _hintColor.withOpacity(0.1),
        ),
        placeholder: Container(
          color: _backgroundColor,
          child: Center(child: CircularProgressIndicator(color: _primaryColor)),
        ),
      );

      setState(() {
        _videoFile = video;
        _videoBytes = null;
        _isVideoInitialized = true;
      });

      // Générer la miniature
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 1000,
      );
      setState(() {
        _localThumbnailPath = thumbnailPath;
        _generatedThumbnailUrl = null;
      });

      Navigator.pop(context); // fermer le loader
    } catch (e) {
      print("Erreur sélection vidéo: $e");
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showError('Erreur lors du traitement de la vidéo');
    } finally {
      _isPickingVideo = false;
    }
  }

  void _showDurationWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Recommandation', style: TextStyle(color: _secondaryColor)),
        content: Text(
          'Les publicités de 15 à 30 secondes sont les plus efficaces.\n\n'
              'Votre vidéo dépasse 30 secondes, ce qui peut réduire son efficacité.',
          style: TextStyle(color: _textColor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('OK', style: TextStyle(color: _primaryColor))),
        ],
      ),
    );
  }

  Future<void> _selectCustomThumbnail() async {
    try {
      final image = await ImagePicker().pickImage(
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
      setState(() => _isUploadingCustomThumbnail = false);
    }
  }

  Future<String?> _uploadCustomThumbnail() async {
    try {
      if (_customThumbnailFile == null && _customThumbnailBytes == null) return null;
      final fileName = 'ad_thumbnails/custom_thumb_${authProvider.loginUserData.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      print('Erreur upload miniature personnalisée: $e');
      return null;
    }
  }

  // ========== SÉLECTION DES PAYS ==========
  void _toggleCountrySelection(AfricanCountry country) {
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
    setState(() {
      if (_selectAllCountries) {
        _selectedCountries.clear();
        _selectAllCountries = false;
      } else {
        _selectedCountries = List.from(AfricanCountry.allCountries);
        _selectAllCountries = true;
      }
    });
  }


  // ========== PUBLICATION ==========
  Future<void> _publishAdvertisement() async {
    // Validations
    if (_selectedAdType == null) { _showError('Choisissez le type de publicité'); return; }
    if (_selectedActionType == null) { _showError('Choisissez un type d\'action'); return; }
    if (_selectedDurationWeeks == null) { _showError('Choisissez la durée'); return; }
    if (_descriptionController.text.trim().isEmpty) { _showError('La description est obligatoire'); return; }

    if (_selectedActionType == 'whatsapp') {
      if (_whatsappController.text.isEmpty) { _showError('Numéro WhatsApp requis'); return; }
    } else {
      if (_actionUrlController.text.isEmpty || !_actionUrlController.text.startsWith('http')) {
        _showError('Lien valide requis (http:// ou https://)');
        return;
      }
    }

    if (_selectedAdType == 'image' && _selectedImages.isEmpty) { _showError('Sélectionnez au moins une image'); return; }
    if (_selectedAdType == 'video' && _videoFile == null && _videoBytes == null) { _showError('Sélectionnez une vidéo'); return; }
    if (!_selectAllCountries && _selectedCountries.isEmpty) { _showError('Sélectionnez au moins un pays'); return; }

    final int price = _durationPrices[_selectedDurationWeeks!]!;
    final currentBalance = authProvider.loginUserData.votre_solde_principal ?? 0;
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    if (!isAdmin && currentBalance < price) {
      _showInsufficientBalanceDialog();
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Débiter (sauf admin) et mettre à jour le solde local
      if (!isAdmin) {
        await FirebaseFirestore.instance.collection('Users').doc(authProvider.loginUserData.id).update({
          'votre_solde_principal': FieldValue.increment(-price),
        });
        authProvider.loginUserData.votre_solde_principal = (authProvider.loginUserData.votre_solde_principal ?? 0) - price;
        await _createTransaction(price, 'Publicité ${_getDurationLabel(_selectedDurationWeeks!)}');
      }

      // 2. Upload des médias
      List<String> mediaUrls = [];
      String? videoUrl;
      String? thumbnailUrl;

      if (_selectedAdType == 'image') {
        for (var img in _selectedImages) {
          final fileName = 'ad_images/${Uuid().v4()}.jpg';
          final ref = FirebaseStorage.instance.ref().child(fileName);
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/${Uuid().v4()}.jpg');
          await file.writeAsBytes(img);
          await ref.putFile(file);
          final url = await ref.getDownloadURL();
          mediaUrls.add(url);
        }
      } else {
        // Upload vidéo
        final videoFileName = 'ad_videos/${Uuid().v4()}.mp4';
        final videoRef = FirebaseStorage.instance.ref().child(videoFileName);
        UploadTask uploadTask;
        if (_videoFile != null) {
          uploadTask = videoRef.putFile(File(_videoFile!.path));
        } else {
          uploadTask = videoRef.putData(_videoBytes!);
        }
        uploadTask.snapshotEvents.listen((snap) {
          if (mounted) setState(() => _uploadProgress = snap.bytesTransferred / snap.totalBytes);
        });
        final videoSnapshot = await uploadTask;
        videoUrl = await videoSnapshot.ref.getDownloadURL();

        // Upload miniature
        if (_useCustomThumbnail && (_customThumbnailFile != null || _customThumbnailBytes != null)) {
          thumbnailUrl = await _uploadCustomThumbnail();
        } else if (_localThumbnailPath != null) {
          final thumbFileName = 'ad_thumbnails/${Uuid().v4()}.jpg';
          final thumbRef = FirebaseStorage.instance.ref().child(thumbFileName);
          await thumbRef.putFile(File(_localThumbnailPath!));
          thumbnailUrl = await thumbRef.getDownloadURL();
        }
      }

      // 3. Créer le post
      final String postId = FirebaseFirestore.instance.collection('Posts').doc().id;
      final now = DateTime.now().microsecondsSinceEpoch;
      Post post = Post()
        ..id = postId
        ..user_id = authProvider.loginUserData.id
        ..description = _descriptionController.text.trim()
        ..createdAt = now
        ..updatedAt = now
        ..status = PostStatus.VALIDE.name
        ..type = PostType.POST.name
        ..dataType = _selectedAdType == 'image' ? PostDataType.IMAGE.name : PostDataType.VIDEO.name
        ..typeTabbar = 'OFFRES'
        ..isAdvertisement = true
        ..availableCountries = _selectAllCountries
            ? AfricanCountry.allCountries.map((c) => c.code).toList()
            : _selectedCountries.map((c) => c.code).toList();

      if (_selectedAdType == 'image') {
        post.images = mediaUrls;
      } else {
        post.url_media = videoUrl;
        post.thumbnail = thumbnailUrl;
      }

      await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());

      // 4. Créer l'annonce publicitaire
      final String adId = FirebaseFirestore.instance.collection('Advertisements').doc().id;
      final String actionUrl = _selectedActionType == 'whatsapp'
          ? 'https://wa.me/${_whatsappController.text.replaceAll(RegExp(r'[^0-9+]'), '')}'
          : _actionUrlController.text;

      final int durationDays = _selectedDurationWeeks! * 7;

      Advertisement ad = Advertisement(
        id: adId,
        postId: postId,
        actionType: _selectedActionType,
        actionUrl: actionUrl,
        actionButtonText: _getActionButtonText(),
        durationDays: durationDays,
        startDate: now,
        endDate: now + (durationDays * 24 * 60 * 60 * 1000000),
        status: 'pending',
        isRenewable: true,
        renewalCount: 0,
        pricePaid: _durationPrices[_selectedDurationWeeks],

        createdBy: authProvider.loginUserData.id,
        createdAt: now,
        updatedAt: now,
      );
      await FirebaseFirestore.instance.collection('Advertisements').doc(adId).set(ad.toJson());
      await FirebaseFirestore.instance.collection('Posts').doc(postId).update({'advertisementId': adId});

      // 5. Succès
      _showSuccessDialog();
    } catch (e) {
      print('Erreur publication: $e');
      _showError('Erreur lors de la publication. Veuillez réessayer.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _getActionButtonText() {
    switch (_selectedActionType) {
      case 'download': return 'Télécharger';
      case 'visit': return 'Visiter';
      case 'learn_more': return 'En savoir plus';
      case 'whatsapp': return 'WhatsApp';
      default: return 'Action';
    }
  }

  Future<void> _createTransaction(int amount, String reason) async {
    final transaction = TransactionSolde()
      ..id = FirebaseFirestore.instance.collection('TransactionSoldes').doc().id
      ..user_id = authProvider.loginUserData.id
      ..type = TypeTransaction.DEPENSE.name
      ..statut = StatutTransaction.VALIDER.name
      ..description = reason
      ..montant = amount.toDouble()
      ..methode_paiement = "publicité"
      ..createdAt = DateTime.now().millisecondsSinceEpoch
      ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    await FirebaseFirestore.instance.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Solde insuffisant', style: TextStyle(color: _secondaryColor)),
        content: Text('Crédits insuffisants. Veuillez recharger.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
            },
            child: Text('Recharger'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text('Publicité soumise !', style: TextStyle(color: _textColor))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Votre publicité sera diffusée après validation par notre équipe.', style: TextStyle(color: _hintColor)),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: _secondaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.contact_support, color: _secondaryColor),
                  SizedBox(width: 12),
                  Expanded(child: Text('Pour accélérer la validation, contactez notre service client.', style: TextStyle(color: _textColor, fontSize: 12))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _contactSupport();
            },
            child: Text('CONTACTER LE SERVICE CLIENT'),
            style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor, foregroundColor: Colors.black),
          ),
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: Text('PLUS TARD'),
          ),
        ],
      ),
    );
  }

  void _contactSupport() async {
    const whatsappNumber = "22890000000"; // À remplacer par le vrai numéro
    final url = Uri.parse("https://wa.me/$whatsappNumber");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showError("Impossible d'ouvrir WhatsApp");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  // ========== BUILD ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Créer une publicité', style: TextStyle(color: _secondaryColor)),
        backgroundColor: _cardColor,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: _secondaryColor), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _isUploading
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(value: _uploadProgress, color: _primaryColor),
                SizedBox(height: 16),
                Text('Publication en cours...', style: TextStyle(color: _textColor)),
              ],
            ),
          )
              : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoBanner(),
                SizedBox(height: 16),
                _buildAdTypeCard(),
                SizedBox(height: 16),
                _buildDescriptionCard(),
                SizedBox(height: 16),
                _buildDurationCard(),
                SizedBox(height: 16),
                _buildActionCard(),
                SizedBox(height: 16),
                _buildCountrySelectionCard(),
                SizedBox(height: 16),
                _buildMediaCard(),
                SizedBox(height: 32),
                _buildSubmitButton(),
                SizedBox(height: 20),
              ],
            ),
          ),
          if (_showCountrySelection) _buildCountrySelectionModal(),
        ],
      ),
    );
  }

  // ========== WIDGETS UI ==========
  Widget _buildInfoBanner() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryColor, _primaryColor.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(children: [Icon(Icons.public, color: _secondaryColor), SizedBox(width: 8), Expanded(child: Text('Vue par +10 000 utilisateurs en Afrique !', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
          SizedBox(height: 8),
          Text('Choisissez vos pays cibles. Plus vous ciblez large, plus vous touchez de personnes.', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAdTypeCard() {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Type de publicité', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildChoiceChip('Image', 'image', Icons.image)),
                SizedBox(width: 12),
                Expanded(child: _buildChoiceChip('Vidéo', 'video', Icons.videocam)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value, IconData icon) {
    final isSelected = _selectedAdType == value;
    return ChoiceChip(
      label: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18), SizedBox(width: 6), Text(label)]),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedAdType = selected ? value : null),
      selectedColor: _primaryColor,
      backgroundColor: Colors.grey[800],
      labelStyle: TextStyle(color: isSelected ? Colors.white : _hintColor),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: TextField(
          controller: _descriptionController,
          maxLines: 3,
          style: TextStyle(color: _textColor),
          decoration: InputDecoration(
            hintText: 'Description de votre publicité (obligatoire)',
            hintStyle: TextStyle(color: _hintColor),
            border: InputBorder.none,
            filled: true,
            fillColor: _backgroundColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationCard() {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Durée de la campagne', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _durationOptions.map((weeks) {
                final isSelected = _selectedDurationWeeks == weeks;
                return ChoiceChip(
                  label: Column(
                    children: [
                      Text(_getDurationLabel(weeks), style: TextStyle(fontSize: 12)),
                      Text('${_durationPrices[weeks]} FCFA', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _selectedDurationWeeks = selected ? weeks : null),
                  selectedColor: _primaryColor,
                  backgroundColor: Colors.grey[800],
                  labelStyle: TextStyle(color: isSelected ? Colors.white : _hintColor),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Action du bouton', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _buildActionChip('Télécharger', 'download', Icons.download),
              _buildActionChip('Visiter', 'visit', Icons.language),
              _buildActionChip('En savoir plus', 'learn_more', Icons.info),
              _buildActionChip('WhatsApp', 'whatsapp', MaterialCommunityIcons.whatsapp),
            ]),
            if (_selectedActionType == 'whatsapp')
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: IntlPhoneField(
                  // controller: _whatsappController,
                  decoration: InputDecoration(
                    labelText: 'Numéro WhatsApp',
                    labelStyle: TextStyle(color: _hintColor),
                    border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                    filled: true,
                    fillColor: _backgroundColor,
                  ),
                  style: TextStyle(color: _textColor),
                  initialCountryCode: 'TG',
                  onChanged: (value) {
                    _whatsappController.text = value.completeNumber;
                    print("Numero complet: ${_whatsappController.text}");
                  },
                ),
              )
            else if (_selectedActionType != null)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: TextField(
                  controller: _actionUrlController,
                  style: TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    hintStyle: TextStyle(color: _hintColor),
                    prefixIcon: Icon(Icons.link, color: _primaryColor),
                    border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                    filled: true,
                    fillColor: _backgroundColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(String label, String value, IconData icon) {
    final isSelected = _selectedActionType == value;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), SizedBox(width: 4), Text(label)]),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedActionType = selected ? value : null),
      selectedColor: _primaryColor,
      backgroundColor: Colors.grey[800],
      labelStyle: TextStyle(color: isSelected ? Colors.white : _hintColor),
    );
  }

  Widget _buildMediaCard() {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (_selectedAdType == 'image') ...[
              Text('Images (max $maxImagesForDuration)', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _selectedImages.isEmpty
                  ? ElevatedButton.icon(onPressed: _pickImages, icon: Icon(Icons.add_photo_alternate), label: Text('Ajouter des images'))
                  : Column(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) => Stack(
                      children: [
                        Image.memory(_selectedImages[index], fit: BoxFit.cover),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(icon: Icon(Icons.close, size: 16), onPressed: () => _removeImage(index)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(onPressed: _pickImages, icon: Icon(Icons.add), label: Text('Ajouter plus')),
                ],
              ),
            ] else if (_selectedAdType == 'video') ...[
              Text('Vidéo (max 4 minutes, recommandé 15-30s)', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              if (_videoFile == null && _videoBytes == null)
                ElevatedButton.icon(onPressed: _pickVideo, icon: Icon(Icons.video_library), label: Text('Choisir une vidéo'))
              else if (_isVideoInitialized && _chewieController != null)
                Column(
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
                      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Chewie(controller: _chewieController!)),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: ElevatedButton.icon(onPressed: _pickVideo, icon: Icon(Icons.refresh), label: Text('Changer la vidéo'))),
                        SizedBox(width: 8),
                        Expanded(child: ElevatedButton.icon(onPressed: _selectCustomThumbnail, icon: Icon(Icons.image), label: Text(_useCustomThumbnail ? 'Changer miniature' : 'Miniature perso'))),
                      ],
                    ),
                    if (_useCustomThumbnail && (_customThumbnailFile != null || _customThumbnailBytes != null))
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _primaryColor),
                            image: DecorationImage(
                              image: kIsWeb && _customThumbnailBytes != null
                                  ? MemoryImage(_customThumbnailBytes!)
                                  : FileImage(File(_customThumbnailFile!.path)) as ImageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    else if (_localThumbnailPath != null && !_useCustomThumbnail)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[700]!),
                            image: DecorationImage(image: FileImage(File(_localThumbnailPath!)), fit: BoxFit.cover),
                          ),
                        ),
                      ),
                  ],
                )
              else
                Center(child: CircularProgressIndicator(color: _primaryColor)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _publishAdvertisement,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        minimumSize: Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: Text('PUBLIER LA PUBLICITÉ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  String _getDurationLabel(int weeks) {
    switch (weeks) {
      case 2: return '2 sem.';
      case 4: return '1 mois';
      case 12: return '3 mois';
      case 24: return '6 mois';
      case 52: return '12 mois';
      default: return '$weeks sem.';
    }
  }

  // Les widgets de sélection des pays (à copier depuis la version précédente)
  Widget _buildCountrySelectionCard() {
    String displayMessage;
    if (_selectAllCountries) {
      displayMessage = '🌍 Tous les pays africains (${AfricanCountry.allCountries.length} pays)';
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
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.public, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Visibilité de la publicité', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(displayMessage, style: TextStyle(color: _selectedCountries.isEmpty && !_selectAllCountries ? Colors.orange : _hintColor, fontSize: 14)),
                ],
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
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showCountrySelection = true),
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

  Widget _buildCountrySelectionModal() {
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
                      onPressed: () => setState(() => _showCountrySelection = false),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectAllCountries ? _secondaryColor.withOpacity(0.2) : _primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _selectAllCountries ? _secondaryColor : _primaryColor),
                      ),
                      child: Text(
                        _selectAllCountries ? 'Tous les pays' : 'Sélection manuelle',
                        style: TextStyle(color: _selectAllCountries ? _secondaryColor : _primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      '${_selectedCountries.length} pays sélectionné(s)',
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
                  color: _selectAllCountries ? _secondaryColor : Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.public, color: _selectAllCountries ? Colors.white : _hintColor),
              ),
              title: Row(
                children: [
                  Text('Tous les pays africains', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _secondaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text('RECOMMANDÉ', style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              subtitle: Text('Votre publicité sera visible dans toute l\'Afrique', style: TextStyle(color: _hintColor)),
              trailing: _selectAllCountries
                  ? Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: Icon(Icons.check, color: Colors.white, size: 20))
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
                return Material(
                  color: isSelected ? _primaryColor.withOpacity(0.1) : _cardColor,
                  child: ListTile(
                    onTap: () => _toggleCountrySelection(country),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryColor : Colors.grey[800],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text(country.flag, style: TextStyle(fontSize: 20))),
                    ),
                    title: Text(country.name, style: TextStyle(color: isSelected ? _textColor : _textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('Code: ${country.code}', style: TextStyle(color: _hintColor)),
                    trailing: isSelected
                        ? Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: _primaryColor, shape: BoxShape.circle), child: Icon(Icons.check, color: Colors.white, size: 16))
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
}