// lib/pages/creator/creator_content_form_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../providers/authProvider.dart';
import '../../providers/dating/creator_provider.dart';

class CreatorContentFormPage extends StatefulWidget {
  final CreatorContent? existingContent;

  const CreatorContentFormPage({Key? key, this.existingContent}) : super(key: key);

  @override
  State<CreatorContentFormPage> createState() => _CreatorContentFormPageState();
}

class _CreatorContentFormPageState extends State<CreatorContentFormPage>
    with SingleTickerProviderStateMixin {
  // Controllers
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  // États
  bool _isLoading = false;
  bool _isPaid = false;
  MediaType _mediaType = MediaType.image;
  File? _selectedMedia;
  String? _existingMediaUrl;
  String? _thumbnailUrl;
  bool _isVideoInitialized = false;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Couleurs
  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color primaryBlack = Colors.black;

  @override
  void initState() {
    super.initState();
    _loadExistingContent();
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _loadExistingContent() {
    if (widget.existingContent != null) {
      _titreController.text = widget.existingContent!.titre;
      _descriptionController.text = widget.existingContent!.description;
      _isPaid = widget.existingContent!.isPaid;
      _priceController.text = widget.existingContent!.priceCoins?.toString() ?? '';
      _mediaType = widget.existingContent!.mediaType;
      _existingMediaUrl = widget.existingContent!.mediaUrl;
      _thumbnailUrl = widget.existingContent!.thumbnailUrl;

      if (_mediaType == MediaType.video && _existingMediaUrl != null) {
        _initVideoPlayer(_existingMediaUrl!);
      }

      print('📱 Chargement du contenu existant: ${widget.existingContent!.titre}');
    }
  }

  Future<void> _initVideoPlayer(String url) async {
    _videoController = VideoPlayerController.network(url);
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: primaryRed,
        handleColor: primaryRed,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.shade300,
      ),
    );
    setState(() => _isVideoInitialized = true);
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();

    if (_mediaType == MediaType.image) {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedMedia = File(pickedFile.path);
          _existingMediaUrl = null;
        });
      }
    } else {
      final XFile? pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedMedia = File(pickedFile.path);
          _existingMediaUrl = null;
          _isVideoInitialized = false;
        });

        // Initialiser le lecteur vidéo pour la preview
        _videoController = VideoPlayerController.file(File(pickedFile.path));
        await _videoController!.initialize();
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          showControls: true,
        );
        setState(() => _isVideoInitialized = true);
      }
    }
  }

  Future<String?> _uploadMedia() async {
    if (_selectedMedia == null && _existingMediaUrl != null) {
      return _existingMediaUrl;
    }

    if (_selectedMedia == null) return null;

    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = 'creator_contents/${_mediaType == MediaType.image ? 'images' : 'videos'}/$fileName';
      final Reference ref = _storage.ref().child(filePath);

      print('📤 Upload du fichier vers: $filePath');

      if (_mediaType == MediaType.image) {
        await ref.putFile(_selectedMedia!);
      } else {
        await ref.putFile(_selectedMedia!);
      }

      final downloadUrl = await ref.getDownloadURL();
      print('✅ Fichier uploadé: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Erreur upload: $e');
      return null;
    }
  }

  Future<String?> _generateThumbnail() async {
    if (_mediaType == MediaType.image && _selectedMedia != null) {
      return null; // Pas besoin de thumbnail pour les images
    }

    if (_mediaType == MediaType.video && _selectedMedia != null) {
      // Pour une vidéo, on pourrait générer une miniature
      // Pour simplifier, on retourne null et on utilisera l'URL de la vidéo comme fallback
      return null;
    }

    return _thumbnailUrl;
  }

  Future<void> _saveContent() async {
    if (_titreController.text.trim().isEmpty) {
      _showError('Veuillez saisir un titre');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showError('Veuillez saisir une description');
      return;
    }

    if (_selectedMedia == null && _existingMediaUrl == null) {
      _showError('Veuillez sélectionner un média (image ou vidéo)');
      return;
    }

    if (_isPaid) {
      final price = int.tryParse(_priceController.text.trim());
      if (price == null || price <= 0) {
        _showError('Veuillez saisir un prix valide (minimum 1 coin)');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final userId = authProvider.loginUserData.id;

      if (userId == null) {
        _showError('Utilisateur non connecté');
        return;
      }

      // Récupérer le profil créateur
      final creatorSnapshot = await _firestore
          .collection('creator_profiles')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (creatorSnapshot.docs.isEmpty) {
        _showError('Vous n\'êtes pas enregistré comme créateur');
        setState(() => _isLoading = false);
        return;
      }

      final creatorProfile = CreatorProfile.fromJson(creatorSnapshot.docs.first.data());

      // Upload du média
      final mediaUrl = await _uploadMedia();
      if (mediaUrl == null && _existingMediaUrl == null) {
        _showError('Erreur lors de l\'upload du média');
        setState(() => _isLoading = false);
        return;
      }

      final thumbnailUrl = await _generateThumbnail();
      final now = DateTime.now().millisecondsSinceEpoch;

      final content = CreatorContent(
        id: widget.existingContent?.id ?? _firestore.collection('creator_contents').doc().id,
        creatorId: creatorProfile.id,
        creatorUserId: userId,
        titre: _titreController.text.trim(),
        description: _descriptionController.text.trim(),
        mediaUrl: mediaUrl ?? _existingMediaUrl!,
        mediaType: _mediaType,
        thumbnailUrl: thumbnailUrl ?? _existingMediaUrl,
        isPaid: _isPaid,
        priceCoins: _isPaid ? int.tryParse(_priceController.text.trim()) : null,
        currency: 'coins',
        isPublished: true,
        likesCount: widget.existingContent?.likesCount ?? 0,
        lovesCount: widget.existingContent?.lovesCount ?? 0,
        unlikesCount: widget.existingContent?.unlikesCount ?? 0,
        viewsCount: widget.existingContent?.viewsCount ?? 0,
        interactionsCount: widget.existingContent?.interactionsCount ?? 0,
        sharesCount: widget.existingContent?.sharesCount ?? 0,
        createdAt: widget.existingContent?.createdAt ?? now,
        updatedAt: now,
      );

      await _firestore
          .collection('creator_contents')
          .doc(content.id)
          .set(content.toJson());

      print('✅ Contenu ${widget.existingContent == null ? 'créé' : 'mis à jour'}: ${content.titre}');

      // Mettre à jour le compteur du créateur
      if (widget.existingContent == null) {
        final fieldToUpdate = _isPaid ? 'paidContentsCount' : 'freeContentsCount';
        await _firestore
            .collection('creator_profiles')
            .doc(creatorProfile.id)
            .update({
          fieldToUpdate: FieldValue.increment(1),
          'updatedAt': now,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingContent == null
                  ? 'Contenu publié avec succès !'
                  : 'Contenu mis à jour !',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.pop(context, true);
      }

    } catch (e) {
      print('❌ Erreur sauvegarde: $e');
      _showError('Erreur: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        title: Text(
          widget.existingContent == null ? 'Créer un contenu' : 'Modifier le contenu',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryRed,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveContent,
              child: Text(
                'Publier',
                style: TextStyle(
                  color: primaryYellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryRed),
            const SizedBox(height: 16),
            Text(
              'Publication en cours...',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type de média
            _buildMediaTypeSelector(),
            const SizedBox(height: 24),

            // Aperçu du média
            _buildMediaPreview(),
            const SizedBox(height: 24),

            // Bouton pour sélectionner le média
            _buildSelectMediaButton(),
            const SizedBox(height: 24),

            // Titre
            TextFormField(
              controller: _titreController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Titre',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.title, color: primaryRed),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.description, color: primaryRed),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Switch payant/gratuit
            _buildPaidSwitch(),
            const SizedBox(height: 16),

            // Prix (si payant)
            if (_isPaid)
              _buildPriceField(),
            const SizedBox(height: 32),

            // Avertissement
            _buildWarningMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de contenu',
          style: TextStyle(
            color: primaryYellow,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _mediaType = MediaType.image),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _mediaType == MediaType.image
                        ? primaryRed.withOpacity(0.2)
                        : Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _mediaType == MediaType.image
                          ? primaryRed
                          : Colors.grey[800]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image,
                        color: _mediaType == MediaType.image ? primaryRed : Colors.grey[600],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Image',
                        style: TextStyle(
                          color: _mediaType == MediaType.image ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _mediaType = MediaType.video),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _mediaType == MediaType.video
                        ? primaryRed.withOpacity(0.2)
                        : Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _mediaType == MediaType.video
                          ? primaryRed
                          : Colors.grey[800]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam,
                        color: _mediaType == MediaType.video ? primaryRed : Colors.grey[600],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Vidéo',
                        style: TextStyle(
                          color: _mediaType == MediaType.video ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia != null) {
      if (_mediaType == MediaType.image) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _selectedMedia!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      } else if (_mediaType == MediaType.video && _isVideoInitialized && _chewieController != null) {
        return Container(
          height: 200,
          color: Colors.black,
          child: Chewie(controller: _chewieController!),
        );
      }
    } else if (_existingMediaUrl != null) {
      if (_mediaType == MediaType.image) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            _existingMediaUrl!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              );
            },
          ),
        );
      } else if (_mediaType == MediaType.video && !_isVideoInitialized) {
        _initVideoPlayer(_existingMediaUrl!);
        return Container(
          height: 200,
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      } else if (_mediaType == MediaType.video && _isVideoInitialized && _chewieController != null) {
        return Container(
          height: 200,
          color: Colors.black,
          child: Chewie(controller: _chewieController!),
        );
      }
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _mediaType == MediaType.image ? Icons.image : Icons.videocam,
            size: 50,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            'Aucun média sélectionné',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectMediaButton() {
    return ElevatedButton.icon(
      onPressed: _pickMedia,
      icon: Icon(Icons.add_photo_alternate, color: primaryBlack),
      label: Text(
        _selectedMedia != null || _existingMediaUrl != null
            ? 'Changer de média'
            : 'Sélectionner un ${_mediaType == MediaType.image ? 'image' : 'vidéo'}',
        style: TextStyle(color: primaryBlack, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryYellow,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Widget _buildPaidSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isPaid ? Icons.lock : Icons.lock_open,
                color: _isPaid ? primaryYellow : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isPaid ? 'Contenu payant' : 'Contenu gratuit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isPaid
                        ? 'Les utilisateurs doivent payer pour y accéder'
                        : 'Accessible à tous gratuitement',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: _isPaid,
            onChanged: (value) => setState(() => _isPaid = value),
            activeColor: primaryYellow,
            activeTrackColor: primaryYellow.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Prix (en pièces)',
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(Icons.monetization_on, color: primaryYellow),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        helperText: 'Minimum 1 pièce',
        helperStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
      ),
    );
  }

  Widget _buildWarningMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryYellow, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les contenus publiés seront visibles par tous les utilisateurs. '
                  'Assurez-vous de respecter les conditions d\'utilisation.',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}