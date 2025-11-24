// pages/chronique/add_chronique_page.dart
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
  int commentCount = 0; // Ajouter cette ligne


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
}

// models/chronique_message_model.dart

class ChroniqueMessage {
  String? id;
  String chroniqueId;
  String userId;
  String userPseudo;
  String userImageUrl;
  String message;
  Timestamp createdAt;

  ChroniqueMessage({
    this.id,
    required this.chroniqueId,
    required this.userId,
    required this.userPseudo,
    required this.userImageUrl,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'chroniqueId': chroniqueId,
      'userId': userId,
      'userPseudo': userPseudo,
      'userImageUrl': userImageUrl,
      'message': message,
      'createdAt': createdAt,
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
  Color _selectedColor = Colors.black;
  File? _selectedMedia;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Couleurs Afro
  final List<Color> _afroColors = [
    Colors.black,
    Color(0xFF8B0000), // Rouge foncé
    Color(0xFFB22222), // Rouge brique
    Color(0xFFFFD700), // Jaune or
    Color(0xFFDAA520), // Jaune doré
    Color(0xFF8B4513), // Marron
    Color(0xFF2F4F4F), // Gris ardoise foncé
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

      // Vérifier la durée
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
    return stat.size / (1024 * 1024); // Convertir en MB
  }

  Future<double> _getVideoDuration(File file) async {
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    final duration = controller.value.duration.inSeconds.toDouble();
    await controller.dispose();
    return duration;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('Erreur', style: TextStyle(color: Color(0xFFFFD700))),
        content: Text(message, style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Color(0xFFFFD700))),
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
      // Vérifier le nombre de chroniques actives
      final activeCount = await chroniqueProvider.getUserActiveChroniquesCount(authProvider.loginUserData.id!);
      if (activeCount >= 5) {
        _showErrorDialog('Vous avez déjà 5 chroniques actives. Attendez que certaines expirent.');
        setState(() => _isUploading = false);
        return;
      }

      // Créer et publier la chronique
      await chroniqueProvider.publishChronique(
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
      // Envoyer notification
      await _sendNotification(authProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Color(0xFF8B0000),
          content: Text(
            '🎉 Chronique publiée avec succès !',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Erreur chronique form : $e");
      _showErrorDialog('Erreur lors de la publication: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _sendNotification(UserAuthProvider authProvider) async {
    final userIds = await authProvider.getAllUsersOneSignaUserId();
    if (userIds.isNotEmpty) {
      await authProvider.sendNotification(
        appName: '@${authProvider.loginUserData.pseudo!}',
        userIds: userIds,
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: "",
        message: "📢 ${authProvider.loginUserData.pseudo!} a partagé une chronique: ${_getNotificationText()}",
        type_notif: 'CHRONIQUE',
        post_id: "",
        post_type: _selectedType.toString(),
        chat_id: '',
      );
    }
  }

  String _getNotificationText() {
    switch (_selectedType) {
      case ChroniqueType.TEXT:
        return _textController.text.length > 100
            ? '${_textController.text.substring(0, 100)}...'
            : _textController.text;
      case ChroniqueType.IMAGE:
        return '📷 ${_textController.text }';
      case ChroniqueType.VIDEO:
        return '🎥 ${_textController.text }';
      default:
        return 'Nouvelle chronique';
    }
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia == null) return SizedBox();

    switch (_selectedType) {
      case ChroniqueType.IMAGE:
        return Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Color(0xFFFFD700), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.file(_selectedMedia!, fit: BoxFit.cover),
          ),
        );
      case ChroniqueType.VIDEO:
        return Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Color(0xFFFFD700), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: _videoController != null && _videoController!.value.isInitialized
                ? VideoPlayer(_videoController!)
                : Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
          ),
        );
      default:
        return SizedBox();
    }
  }

  Widget _buildTextPreview() {
    if (_selectedType != ChroniqueType.TEXT || _textController.text.isEmpty) {
      return SizedBox();
    }

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: _selectedColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Color(0xFFFFD700), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _textController.text,
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontFamily: 'AfroFont', // Remplacez par votre police Afro
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Nouvelle Chronique Afro',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFFFFD700)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Sélection du type
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Color(0xFFFFD700)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type de Chronique',
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      _buildTypeOption(ChroniqueType.TEXT, Icons.text_fields, 'Texte'),
                      SizedBox(width: 10),
                      _buildTypeOption(ChroniqueType.IMAGE, Icons.photo, 'Image'),
                      SizedBox(width: 10),
                      _buildTypeOption(ChroniqueType.VIDEO, Icons.videocam, 'Vidéo'),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Champ texte
            if (_selectedType != ChroniqueType.TEXT)
              TextField(
                controller: _textController,
                maxLines: 2,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'Description (optionnelle - max 100 caractères)',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFFFD700)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFFFD700), width: 2),
                  ),
                  filled: true,
                  fillColor: Color(0xFF1A1A1A),
                  counterStyle: TextStyle(color: Colors.grey),
                ),
                style: TextStyle(color: Colors.white),
              ),

            if (_selectedType == ChroniqueType.TEXT) ...[
              TextField(
                controller: _textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Écrivez votre chronique...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFFFD700)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFFFD700), width: 2),
                  ),
                  filled: true,
                  fillColor: Color(0xFF1A1A1A),
                ),
                style: TextStyle(color: Colors.white),
              ),

              SizedBox(height: 20),

              // Sélection couleur
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Color(0xFFFFD700)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Couleur du fond',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _afroColors.map((color) => _buildColorOption(color)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Boutons média
            if (_selectedType != ChroniqueType.TEXT) ...[
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.photo_library, color: Colors.white),
                      label: Text('Galerie', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF8B0000),
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  if (_selectedType == ChroniqueType.VIDEO)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickVideo,
                        icon: Icon(Icons.video_library, color: Colors.white),
                        label: Text('Vidéo', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFB22222),
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
              ),
            ],

            SizedBox(height: 20),

            // Preview
            if (_selectedType == ChroniqueType.TEXT) _buildTextPreview(),
            if (_selectedType != ChroniqueType.TEXT) _buildMediaPreview(),

            SizedBox(height: 20),

            // Barre de progression
            if (_isUploading)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey[800],
                    color: Color(0xFFFFD700),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: Color(0xFFFFD700)),
                  ),
                ],
              ),

            SizedBox(height: 20),

            // Bouton publier
            ElevatedButton(
              onPressed: _isUploading || !_isFormValid ? null : _publishChronique,
              child: Text(
                'PUBLIER LA CHRONIQUE',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFormValid ? Color(0xFFFFD700) : Colors.grey,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 5,
                shadowColor: Color(0xFFFFD700).withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(ChroniqueType type, IconData icon, String label) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedMedia = null;
            _videoController?.dispose();
            _videoController = null;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFFFFD700) : Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? Color(0xFFFFD700) : Colors.grey),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.black : Color(0xFFFFD700)),
              SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 40,
        height: 40,
        margin: EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Color(0xFFFFD700) : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}