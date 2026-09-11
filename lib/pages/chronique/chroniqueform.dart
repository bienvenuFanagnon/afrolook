// pages/chronique/add_chronique_page.dart

import 'dart:async';

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:provider/provider.dart';
// models/chronique_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../../theme/app_colors.dart';

enum ChroniqueType { TEXT, IMAGE, VIDEO }
class Chronique {
  String? id;
  String userId;
  String userPseudo;
  String userImageUrl;
  ChroniqueType type;
  String? textContent;
  String? mediaUrl;
  String? backgroundColor;
  int duration; // en secondes
  int viewCount;
  int likeCount;
  int loveCount;
  List<String> viewers;
  List<String> likers;
  List<String> lovers;
  Timestamp createdAt;
  Timestamp expiresAt;
  double? fileSize; // en MB
  int commentCount = 0;
  // Ajouter ces nouveaux champs
  List<String> likes; // Liste des utilisateurs qui ont liké
  int totalReactions; // Somme des likes + loves

  Chronique({
    this.id,
    required this.userId,
    required this.userPseudo,
    required this.userImageUrl,
    required this.type,
    this.textContent,
    this.mediaUrl,
    this.backgroundColor,
    this.duration = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.loveCount = 0,
    this.commentCount = 0,
    this.viewers = const [],
    this.likers = const [],
    this.lovers = const [],
    required this.createdAt,
    required this.expiresAt,
    this.fileSize,
    this.likes = const [], // Initialiser la nouvelle liste
    this.totalReactions = 0, // Initialiser le total
  });

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userPseudo': userPseudo,
      'userImageUrl': userImageUrl,
      'type': type.toString(),
      'textContent': textContent,
      'mediaUrl': mediaUrl,
      'backgroundColor': backgroundColor,
      'duration': duration,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'loveCount': loveCount,
      'viewers': viewers,
      'likers': likers,
      'lovers': lovers,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'fileSize': fileSize,
      'commentCount': commentCount,
      'likes': likes, // Ajouter le nouveau champ
      'totalReactions': totalReactions, // Ajouter le nouveau champ
    };
  }

  // Créer depuis Firestore
  factory Chronique.fromMap(Map<String, dynamic> map, String id) {
    return Chronique(
      id: id,
      userId: map['userId'] ?? '',
      userPseudo: map['userPseudo'] ?? '',
      userImageUrl: map['userImageUrl'] ?? '',
      type: _stringToChroniqueType(map['type']),
      textContent: map['textContent'],
      mediaUrl: map['mediaUrl'],
      backgroundColor: map['backgroundColor'],
      duration: map['duration'] ?? 0,
      viewCount: map['viewCount'] ?? 0,
      likeCount: map['likeCount'] ?? 0,
      loveCount: map['loveCount'] ?? 0,
      viewers: List<String>.from(map['viewers'] ?? []),
      likers: List<String>.from(map['likers'] ?? []),
      lovers: List<String>.from(map['lovers'] ?? []),
      createdAt: map['createdAt'] ?? Timestamp.now(),
      expiresAt: map['expiresAt'] ?? Timestamp.fromDate(DateTime.now().add(Duration(hours: 24))),
      fileSize: map['fileSize'],
      commentCount: map['commentCount'] ?? 0,
      likes: List<String>.from(map['likes'] ?? []), // Récupérer le nouveau champ
      totalReactions: map['totalReactions'] ?? 0, // Récupérer le nouveau champ
    );
  }

  static ChroniqueType _stringToChroniqueType(String type) {
    switch (type) {
      case 'ChroniqueType.TEXT':
        return ChroniqueType.TEXT;
      case 'ChroniqueType.IMAGE':
        return ChroniqueType.IMAGE;
      case 'ChroniqueType.VIDEO':
        return ChroniqueType.VIDEO;
      default:
        return ChroniqueType.TEXT;
    }
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt.toDate());
  }

  bool get hasReachedLimit {
    return fileSize != null && fileSize! > 20.0;
  }

  bool get isVideoTooLong {
    return type == ChroniqueType.VIDEO && duration > 10;
  }

  // Méthode pour calculer le total des réactions (likes + loves)
  int get calculatedTotalReactions {
    return likeCount + loveCount;
  }
}
class ChroniqueMessage {
  String? id;
  String chroniqueId;
  String userId;
  String userPseudo;
  String userImageUrl;
  String message;
  Timestamp createdAt;
  // Nouveaux champs pour les likes sur les commentaires
  int likeCount;
  List<String> likers;

  ChroniqueMessage({
    this.id,
    required this.chroniqueId,
    required this.userId,
    required this.userPseudo,
    required this.userImageUrl,
    required this.message,
    required this.createdAt,
    this.likeCount = 0,
    this.likers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'chroniqueId': chroniqueId,
      'userId': userId,
      'userPseudo': userPseudo,
      'userImageUrl': userImageUrl,
      'message': message,
      'createdAt': createdAt,
      'likeCount': likeCount,
      'likers': likers,
    };
  }

  factory ChroniqueMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChroniqueMessage(
      id: id,
      chroniqueId: map['chroniqueId'] ?? '',
      userId: map['userId'] ?? '',
      userPseudo: map['userPseudo'] ?? '',
      userImageUrl: map['userImageUrl'] ?? '',
      message: map['message'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      likeCount: map['likeCount'] ?? 0,
      likers: List<String>.from(map['likers'] ?? []),
    );
  }
}

class AddChroniquePage extends StatefulWidget {
  @override
  State<AddChroniquePage> createState() => _AddChroniquePageState();
}

class _AddChroniquePageState extends State<AddChroniquePage> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  ChroniqueType _selectedType = ChroniqueType.TEXT;
  Color _selectedColor = const Color(0xFF1A1A2E);
  File? _selectedMedia;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Palette riche — toutes lisibles avec texte blanc
  final List<Color> _afroColors = [
    Color(0xFF000000), // Noir pur
    Color(0xFF0D1117), // Nuit
    Color(0xFF1A1A2E), // Marine nuit
    Color(0xFF16213E), // Bleu nuit
    Color(0xFF0F3460), // Bleu royal
    Color(0xFF1E3A5F), // Bleu acier
    Color(0xFF533483), // Violet profond
    Color(0xFF2D1B69), // Indigo
    Color(0xFF4C1D95), // Violet intense
    Color(0xFF4A1942), // Prune
    Color(0xFF4A0E0E), // Bordeaux nuit
    Color(0xFF8B0000), // Rouge grenat
    Color(0xFFB22222), // Rouge brique
    Color(0xFF78350F), // Ambre sombre
    Color(0xFF8B4513), // Brun terra
    Color(0xFF1B4332), // Vert forêt
    Color(0xFF134E4A), // Teal profond
    Color(0xFF2D4A22), // Olive
    Color(0xFF374151), // Ardoise
    Color(0xFF2F4F4F), // Gris ardoise
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      File file = File(image.path);
      double fileSize = await _getFileSize(file);

      if (fileSize > 20.0) {
        _showErrorDialog('L\'image est trop lourde (${fileSize.toStringAsFixed(1)} MB). Maximum 20 MB.');
        return;
      }

      setState(() {
        _selectedMedia = file;
        _selectedType = ChroniqueType.IMAGE;
        _videoController?.dispose();
        _videoController = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      File file = File(video.path);
      double fileSize = await _getFileSize(file);

      if (fileSize > 20.0) {
        _showErrorDialog('La vidéo est trop lourde (${fileSize.toStringAsFixed(1)} MB). Maximum 20 MB.');
        return;
      }

      final duration = await _getVideoDuration(file);
      if (duration > 30) {
        _showErrorDialog('La vidéo est trop longue (${duration.toStringAsFixed(1)}s). Maximum 30 secondes.');
        return;
      }

      setState(() {
        _selectedMedia = file;
        _selectedType = ChroniqueType.VIDEO;
        _videoController = VideoPlayerController.file(file)
          ..initialize().then((_) {
            setState(() {});
          });
      });
    }
  }

  Future<double> _getFileSize(File file) async {
    final stat = await file.stat();
    return stat.size / (1024 * 1024);
  }

  Future<double> _getVideoDuration(File file) async {
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    final duration = controller.value.duration.inSeconds.toDouble();
    await controller.dispose();
    return duration;
  }

  void _showErrorDialog(String message) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Erreur', style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold)),
        content: Text(message, style: TextStyle(color: colors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  bool get _isFormValid {
    switch (_selectedType) {
      case ChroniqueType.TEXT:
        return _textController.text.trim().isNotEmpty;
      case ChroniqueType.IMAGE:
      case ChroniqueType.VIDEO:
        return _selectedMedia != null &&
            (_textController.text.trim().isEmpty || _textController.text.trim().length <= 100);
      default:
        return false;
    }
  }

  Future<void> _publishChronique() async {
    if (!_isFormValid) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    try {
      final activeCount = await chroniqueProvider.getUserActiveChroniquesCount(authProvider.loginUserData.id!);
      final abonnement = authProvider.loginUserData.abonnement;
      final isPremium = abonnement?.estPremium == true;

      if (activeCount >= 2 && !isPremium) {
        final coins = authProvider.loginUserData.coinsBalance ?? 0;
        if (coins < 10) {
          _showErrorDialog(
            'Vous avez atteint la limite de 2 chroniques gratuites.\n\n'
            'Pour publier davantage, passez en Premium ou rechargez vos pièces (il vous faut 10 pièces).',
          );
          setState(() => _isUploading = false);
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Chronique supplémentaire'),
            content: const Text(
              'Vous avez déjà 2 chroniques actives (limite gratuite).\n\n'
              'Publier cette chronique coûte 10 pièces.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Payer 10 pièces'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          setState(() => _isUploading = false);
          return;
        }
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(authProvider.loginUserData.id!)
            .update({'coinsBalance': FieldValue.increment(-10)});
        authProvider.loginUserData.coinsBalance = (coins - 10);
      } else if (activeCount >= 5 && isPremium) {
        _showErrorDialog('Vous avez déjà 5 chroniques actives. Attendez que certaines expirent.');
        setState(() => _isUploading = false);
        return;
      }

      final uploadedMediaUrl = await chroniqueProvider.publishChronique(
        userId: authProvider.loginUserData.id!,
        userPseudo: authProvider.loginUserData.pseudo!,
        userImageUrl: authProvider.loginUserData.imageUrl!,
        type: _selectedType,
        textContent: _textController.text.trim(),
        mediaFile: _selectedMedia,
        backgroundColor: _selectedType == ChroniqueType.TEXT ? _selectedColor.value.toRadixString(16) : null,
        onProgress: (progress) {
          setState(() => _uploadProgress = progress);
        },
      );
      addPointsForAction(UserAction.post);
      // Notification fire-and-forget via Cloud Function (abonnés uniquement, comme les posts)
      unawaited(_sendNotification(authProvider, mediaUrl: uploadedMediaUrl));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B4332),
            content: const Text(
              '🎉 Chronique publiée avec succès !',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      printVm("Erreur chronique form : $e");
      _showErrorDialog('Erreur lors de la publication: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendNotification(UserAuthProvider authProvider, {String? mediaUrl}) async {
    // Pour image/vidéo : utiliser la miniature du média uploadé.
    // Pour texte : utiliser la photo de profil de l'auteur.
    final notifImage = (_selectedType != ChroniqueType.TEXT && mediaUrl != null && mediaUrl.isNotEmpty)
        ? mediaUrl
        : authProvider.loginUserData.imageUrl!;

    await authProvider.sendPushNotificationToUsers(
      sender: authProvider.loginUserData,
      message: "📢 ${authProvider.loginUserData.pseudo!} a partagé une chronique: ${_getNotificationText()}",
      typeNotif: 'CHRONIQUE',
      smallImage: notifImage,
      postType: _selectedType.toString(),
    );
  }

  String _getNotificationText() {
    switch (_selectedType) {
      case ChroniqueType.TEXT:
        return _textController.text.length > 100
            ? '${_textController.text.substring(0, 100)}...'
            : _textController.text;
      case ChroniqueType.IMAGE:
        return '📷 ${_textController.text}';
      case ChroniqueType.VIDEO:
        return '🎥 ${_textController.text}';
      default:
        return 'Nouvelle chronique';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nouvelle chronique',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type selector
            _buildTypeSelector(colors),
            const SizedBox(height: 20),

            // Contenu selon le type
            if (_selectedType == ChroniqueType.TEXT) _buildTextContent(colors),
            if (_selectedType != ChroniqueType.TEXT) _buildMediaContent(colors),

            const SizedBox(height: 24),

            // Barre de progression
            if (_isUploading) _buildProgressBar(colors),
            if (_isUploading) const SizedBox(height: 20),

            // Bouton publier
            _buildPublishButton(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTypeTab(ChroniqueType.TEXT, Icons.notes_rounded, 'Texte', colors),
          _buildTypeTab(ChroniqueType.IMAGE, Icons.image_rounded, 'Image', colors),
          _buildTypeTab(ChroniqueType.VIDEO, Icons.videocam_rounded, 'Vidéo', colors),
        ],
      ),
    );
  }

  Widget _buildTypeTab(ChroniqueType type, IconData icon, String label, AppColors colors) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedMedia = null;
            _videoController?.dispose();
            _videoController = null;
            _textController.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : colors.textPrimary.withOpacity(0.5), size: 16),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : colors.textPrimary.withOpacity(0.5),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Champ texte
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: TextField(
            controller: _textController,
            maxLines: 5,
            style: TextStyle(color: colors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Écrivez votre chronique...',
              hintStyle: TextStyle(color: colors.textPrimary.withOpacity(0.35)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Prévisualisation
        if (_textController.text.trim().isNotEmpty) ...[
          Text(
            'Aperçu',
            style: TextStyle(color: colors.textPrimary.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          _buildTextPreviewCard(),
          const SizedBox(height: 16),
        ],

        // Couleur de fond
        Text(
          'Couleur de fond',
          style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        _buildColorPicker(colors),
      ],
    );
  }

  Widget _buildTextPreviewCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          color: _selectedColor,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Text(
            _textController.text,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker(AppColors colors) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _afroColors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final color = _afroColors[i];
          final isSelected = _selectedColor == color;
          return GestureDetector(
            onTap: () => setState(() => _selectedColor = color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isSelected ? 44 : 40,
              height: isSelected ? 44 : 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colors.accent : Colors.transparent,
                  width: isSelected ? 3 : 0,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: colors.accent.withOpacity(0.4), blurRadius: 8)]
                    : [],
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaContent(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prévisualisation ou zone de sélection
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: _selectedMedia == null
                ? _buildMediaPlaceholder(colors)
                : _selectedType == ChroniqueType.IMAGE
                    ? Image.file(_selectedMedia!, fit: BoxFit.cover)
                    : (_videoController != null && _videoController!.value.isInitialized
                        ? VideoPlayer(_videoController!)
                        : Container(
                            color: colors.surfaceVariant,
                            child: Center(child: CircularProgressIndicator(color: colors.primary)),
                          )),
          ),
        ),
        const SizedBox(height: 16),

        // Boutons de sélection
        Row(
          children: [
            Expanded(
              child: _buildMediaButton(
                icon: Icons.photo_library_rounded,
                label: 'Galerie',
                onTap: _pickImage,
                color: const Color(0xFF0F3460),
              ),
            ),
            if (_selectedType == ChroniqueType.VIDEO) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.video_library_rounded,
                  label: 'Vidéo',
                  onTap: _pickVideo,
                  color: const Color(0xFF4A0E0E),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // Description optionnelle
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: TextField(
            controller: _textController,
            maxLines: 2,
            maxLength: 100,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Description (optionnelle)',
              hintStyle: TextStyle(color: colors.textPrimary.withOpacity(0.35)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              counterStyle: TextStyle(color: colors.textPrimary.withOpacity(0.4), fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaPlaceholder(AppColors colors) {
    return GestureDetector(
      onTap: _selectedType == ChroniqueType.IMAGE ? _pickImage : _pickVideo,
      child: Container(
        color: colors.surfaceVariant,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedType == ChroniqueType.IMAGE ? Icons.add_photo_alternate_rounded : Icons.video_call_rounded,
              size: 48,
              color: colors.textPrimary.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedType == ChroniqueType.IMAGE ? 'Appuyez pour choisir une image' : 'Appuyez pour choisir une vidéo',
              style: TextStyle(color: colors.textPrimary.withOpacity(0.4), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(AppColors colors) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _uploadProgress,
            minHeight: 6,
            backgroundColor: colors.surfaceVariant,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(_uploadProgress * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: colors.textPrimary.withOpacity(0.6), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPublishButton(AppColors colors) {
    final canPublish = !_isUploading && _isFormValid;
    return GestureDetector(
      onTap: canPublish ? _publishChronique : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: canPublish ? colors.accent : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          boxShadow: canPublish
              ? [BoxShadow(color: colors.accent.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        alignment: Alignment.center,
        child: _isUploading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
              )
            : Text(
                'Publier la chronique',
                style: TextStyle(
                  color: canPublish ? Colors.black : colors.textPrimary.withOpacity(0.3),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}