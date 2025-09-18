import 'dart:async';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../../providers/authProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import '../../providers/userProvider.dart';

class ContentFormScreen extends StatefulWidget {
  final ContentPaie? content;
  final bool isEpisode;
  final String? seriesId;

  ContentFormScreen({this.content, this.isEpisode = false, this.seriesId});

  @override
  _ContentFormScreenState createState() => _ContentFormScreenState();
}

class _ContentFormScreenState extends State<ContentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _hashtagsController = TextEditingController();
  final _seriesNameController = TextEditingController();
  final _episodeNumberController = TextEditingController();

  bool _isFree = false;
  bool _isSeries = false;
  List<String> _selectedCategories = [];
  String? _videoUrl;
  String? _thumbnailUrl;
  File? _videoFile;
  File? _thumbnailFile;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  bool _isSaving = false;
  String _uploadMessage = '';
  int _episodeNumber = 1;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();

    if (widget.content != null) {
      _titleController.text = widget.content!.title;
      _descriptionController.text = widget.content!.description;
      _priceController.text = widget.content!.price.toString();
      _isFree = widget.content!.isFree;
      _isSeries = widget.content!.isSeries;
      _selectedCategories = widget.content!.categories;
      _videoUrl = widget.content!.videoUrl;
      _thumbnailUrl = widget.content!.thumbnailUrl;
      _hashtagsController.text = widget.content!.hashtags.join(', ');

      if (widget.isEpisode) {
        _episodeNumberController.text = widget.content?.title.split('Épisode').last.trim() ?? '1';
      }
    } else {
      _priceController.text = '100';
    }
  }

  Future<void> _pickVideo2() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        File file = File(pickedFile.path);
        final fileSize = await file.length();
        final fileSizeMB = fileSize / (1024 * 1024);

        if (fileSizeMB > 50) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('La vidéo ne doit pas dépasser 50 Mo'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final directory = await getApplicationDocumentsDirectory();
        final newPath = path.join(directory.path, path.basename(file.path));
        final newFile = await file.copy(newPath);

        setState(() {
          _videoFile = newFile;
          _videoUrl = null;
        });
        //
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Vidéo sélectionnée: ${file.path.split('/').last}'),
        //     backgroundColor: Colors.green,
        //   ),
        // );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection de la vidéo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        File file = File(pickedFile.path);

        // Taille originale
        final originalSize = await file.length();
        final originalSizeMB = originalSize / (1024 * 1024);
        debugPrint("Taille originale : ${originalSizeMB.toStringAsFixed(2)} Mo");

        File finalFile = file;

        // Compression si > 3 Mo
        if (originalSizeMB > 9) {
          // Afficher un loading pendant la compression
          showDialog(
            context: context,
            barrierDismissible: false, // L'utilisateur ne peut pas fermer le dialog
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Traitement en cours, merci de patienter...\nNe quittez pas la page",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );


          // Choix dynamique de la qualité
          VideoQuality quality = VideoQuality.Res640x480Quality;
          if (originalSizeMB < 10) {
            quality = VideoQuality.LowQuality;
          } else if (originalSizeMB > 30) {
            quality = VideoQuality.Res640x480Quality;
          }

          final info = await VideoCompress.compressVideo(
            file.path,
            quality: quality,
            deleteOrigin: false,
            includeAudio: true,
          );

          Navigator.of(context).pop(); // Fermer le loading

          if (info == null || info.file == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Erreur de compression")),
            );
            return;
          }

          finalFile = info.file!;

          // Taille après compression
          final compressedSize = await finalFile.length();
          final compressedSizeMB = compressedSize / (1024 * 1024);
          debugPrint("Taille compressée : ${compressedSizeMB.toStringAsFixed(2)} Mo");
          debugPrint("Taille originale : ${originalSizeMB.toStringAsFixed(2)} Mo");

          if (compressedSizeMB > 50) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("La vidéo compressée dépasse toujours 50 Mo"),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        // Copier le fichier final (compressé ou original)
        final directory = await getApplicationDocumentsDirectory();
        final newPath = path.join(directory.path, path.basename(finalFile.path));
        final newFile = await finalFile.copy(newPath);

        setState(() {
          _videoFile = newFile;
          _videoUrl = null;
        });

        final finalSizeMB = (await newFile.length()) / (1024 * 1024);
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text("Vidéo prête (${finalSizeMB.toStringAsFixed(2)} Mo)"),
        //     backgroundColor: Colors.green,
        //   ),
        // );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sélection de la vidéo: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, String>> _uploadFiles() async {
    String? finalVideoUrl;
    String? finalThumbnailUrl;

    if (_videoFile == null && _videoUrl == null) {
      throw Exception('Aucune vidéo sélectionnée');
    }

    try {
      // Upload de la vidéo en premier (si nouveau fichier)
      if (_videoFile != null) {
        final String videoFileName = 'video_${DateTime.now().millisecondsSinceEpoch}${path.extension(_videoFile!.path)}';
        finalVideoUrl = await _uploadFile(_videoFile!, videoFileName, 'videos');
        if (finalVideoUrl == null) {
          throw Exception('Échec de l\'upload de la vidéo');
        }
        print('✅ Upload vidéo réussi: $finalVideoUrl');
      } else {
        finalVideoUrl = _videoUrl;
        print('✅ Utilisation vidéo existante: $finalVideoUrl');
      }

      // Ensuite, gestion de la miniature
      if (_thumbnailFile != null) {
        // Upload de la miniature personnalisée
        print('📸 Upload miniature personnalisée...');
        final String thumbnailFileName = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.png';
        finalThumbnailUrl = await _uploadFile(_thumbnailFile!, thumbnailFileName, 'thumbnails');
        print('✅ Upload miniature personnalisée réussi');
      } else if (_thumbnailUrl == null && _videoFile != null) {
        // Génération automatique de miniature
        print('🎞️ Génération miniature depuis vidéo...');
        try {
          final File thumbnail = await _getVideoThumbnail(_videoFile!);
          final String thumbnailFileName = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.png';
          finalThumbnailUrl = await _uploadFile(thumbnail, thumbnailFileName, 'thumbnails');
          print('✅ Génération et upload miniature automatique réussi');
        } catch (e) {
          print('❌ Erreur génération miniature: $e');
          throw Exception('Échec de la génération de la miniature: $e');
        }
      } else {
        finalThumbnailUrl = _thumbnailUrl;
        print('✅ Utilisation miniature existante: $finalThumbnailUrl');
      }

      if (finalThumbnailUrl == null) {
        throw Exception('Échec de l\'upload de la miniature');
      }

      return {
        'videoUrl': finalVideoUrl!,
        'thumbnailUrl': finalThumbnailUrl,
      };

    } catch (e) {
      print('❌ Erreur globale dans _uploadFiles: $e');
      rethrow;
    }
  }

  Future<String?> _uploadFile(File file, String fileName, String folder) async {
    try {
      final Reference storageRef = _storage.ref().child('$folder/$fileName');
      final UploadTask uploadTask = storageRef.putFile(file);

      // Créer un completer pour attendre la fin de l'upload
      final completer = Completer<TaskSnapshot>();

      uploadTask.snapshotEvents.listen(
              (TaskSnapshot snapshot) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            setState(() {
              _uploadProgress = progress;
              _uploadMessage = 'Upload ${folder == 'videos' ? 'vidéo' : 'miniature'}... ${(progress * 100).toStringAsFixed(0)}%';
            });

            if (snapshot.state == TaskState.success) {
              completer.complete(snapshot);
            }
          },
          onError: (error) {
            completer.completeError(error);
          }
      );

      final TaskSnapshot snapshot = await completer.future;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('❌ Erreur upload $folder: $e');
      print('❌ Fichier: $fileName, Taille: ${file.lengthSync()} bytes');
      return null;
    }
  }
  Future<File> _getVideoThumbnail(File videoFile) async {
    try {
      final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.PNG,
        quality: 25,
        timeMs: 1000,
      );

      if (thumbnailPath != null) {
        return File(thumbnailPath);
      }
      throw Exception('Impossible de générer la miniature');
    } catch (e) {
      print('Erreur génération thumbnail: $e');
      throw Exception('Erreur lors de la génération de la miniature: $e');
    }
  }



  Future<void> _saveContent() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation du prix
    if (!_isFree) {
      final price = double.tryParse(_priceController.text);
      if (price == null || price < 50) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le prix minimum est de 50 FCFA'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validation vidéo
    if (_videoUrl == null && _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une vidéo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation catégories
    if (!widget.isEpisode && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins une catégorie'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation nom de série
    if (_isSeries && !widget.isEpisode && _seriesNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un nom de série'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _isSaving = true;
      _uploadProgress = 0.0;
      _uploadMessage = 'Préparation de l\'upload...';
    });

    try {
      final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final contentProvider = Provider.of<ContentProvider>(context, listen: false);

      // Étape 1: Upload des fichiers
      final Map<String, String> uploadedUrls = await _uploadFiles();
      final String videoUrl = uploadedUrls['videoUrl']!;
      final String thumbnailUrl = uploadedUrls['thumbnailUrl']!;

      printVm("videoUrl: ${videoUrl}");
      printVm("thumbnailUrl: ${thumbnailUrl}");

      // Étape 2: Préparation des données
      final hashtags = _hashtagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Étape 3: Sauvegarde selon le type
      bool success = false;

      if (widget.isEpisode) {
        // Création d'un épisode
        final episode = Episode(
          seriesId: widget.seriesId!,
          title: _titleController.text,
          description: _descriptionController.text,
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          duration: 0,
          episodeNumber: _episodeNumber,
          price: _isFree ? 0 : double.parse(_priceController.text),
          isFree: _isFree,
        );

        success = await contentProvider.addEpisode(episode);
        await userProvider.getAllUsersOneSignaUserId().then((userIds) async {
          if (userIds.isNotEmpty) {
            await userProvider.sendNotification(
              userIds: userIds,
              smallImage: episode.thumbnailUrl!,
              send_user_id: userProvider.loginUserData!.id!,
              recever_user_id: '',
              message: "🔥🎥 ${episode.title} est en ligne et fait sensation !",
              type_notif: NotificationType.POST.name,
              post_id: episode.id ?? '',
              post_type: PostDataType.VIDEO.name,
              chat_id: '',
            );
          }
        });

      } else {
        // Création/mise à jour d'un contenu
        final content = ContentPaie(
          id: widget.content?.id,
          ownerId: userProvider.loginUserData?.id ?? '',
          title: _isSeries ? _seriesNameController.text : _titleController.text,
          description: _descriptionController.text,
          videoUrl: _isSeries ? videoUrl : videoUrl, // Les séries n'ont pas de videoUrl direct
          thumbnailUrl: thumbnailUrl,
          categories: _selectedCategories,
          hashtags: hashtags,
          isSeries: _isSeries,
          price: _isFree ? 0 : double.parse(_priceController.text),
          isFree: _isFree,
          views: widget.content?.views ?? 0,
          likes: widget.content?.likes ?? 0,
          comments: widget.content?.comments ?? 0,
          duration: 0,
          createdAt: widget.content?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        if (widget.content == null) {
          success = await contentProvider.addContentPaie(content);
          await userProvider.getAllUsersOneSignaUserId().then((userIds) async {
            if (userIds.isNotEmpty) {
              await userProvider.sendNotification(
                userIds: userIds,
                smallImage: content.thumbnailUrl,
                send_user_id: userProvider.loginUserData!.id!,
                recever_user_id: '',
                message: "🔥🎥 ${content.title} est en ligne et fait sensation !",
                type_notif: NotificationType.POST.name,
                post_id: content.id ?? '',
                post_type: PostDataType.VIDEO.name,
                chat_id: '',
              );
            }
          });

        } else {
          success = await contentProvider.updateContentPaie(content);
        }
      }

      setState(() {
        _isUploading = false;
        _isSaving = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEpisode
                ? 'Épisode ajouté avec succès'
                : widget.content == null
                ? 'Contenu créé avec succès'
                : 'Contenu mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sauvegarde'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Les méthodes build restent inchangées...
  Widget _buildUserInfoSection(UserData? user) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.red[800],
            backgroundImage: user?.imageUrl != null && user!.imageUrl!.isNotEmpty
                ? NetworkImage(user.imageUrl!)
                : null,
            child: user?.imageUrl == null || user!.imageUrl!.isEmpty
                ? Icon(Icons.person, color: Colors.white)
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.pseudo ?? 'Utilisateur',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${user?.abonnes ?? 0} abonnés',
                  style: TextStyle(
                    color: Colors.red[800],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de contenu *',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text('Vidéo simple'),
                selected: !_isSeries,
                onSelected: (selected) {
                  setState(() {
                    _isSeries = !selected;
                  });
                },
                selectedColor: Colors.red[800],
                labelStyle: TextStyle(
                  color: !_isSeries ? Colors.white : Colors.black,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: Text('Série'),
                selected: _isSeries,
                onSelected: (selected) {
                  setState(() {
                    _isSeries = selected;
                  });
                },
                selectedColor: Colors.red[800],
                labelStyle: TextStyle(
                  color: _isSeries ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vidéo *',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'Taille maximale: 50 Mo',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.red[800],
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isUploading ? null : _pickVideo,
          child: Text('Choisir une vidéo'),
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    if (_videoFile != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            'Aperçu de la vidéo:',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                FutureBuilder<File>(
                  future: _getVideoThumbnail(_videoFile!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          snapshot.data!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      );
                    }
                    return Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.videocam, size: 50, color: Colors.grey),
                    );
                  },
                ),
                Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 50,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_videoFile!.path.split('/').last}',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_videoUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            'Vidéo déjà uploadée:',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Vidéo disponible',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return SizedBox();
  }

  Widget _buildThumbnailPreview() {
    if (_thumbnailFile != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            'Aperçu de la miniature:',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _thumbnailFile!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.image, size: 50, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Miniature: ${_thumbnailFile!.path.split('/').last}',
            style: TextStyle(color: Colors.green, fontSize: 12),
          ),
        ],
      );
    } else if (_thumbnailUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            'Miniature déjà uploadée:',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _thumbnailUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Erreur de chargement',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }
    return SizedBox();
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _uploadProgress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
        ),
        SizedBox(height: 8),
        Text(
          _uploadMessage,
          style: TextStyle(color: Colors.black, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCategoriesSelector(ContentProvider contentProvider) {
    return Wrap(
      spacing: 8,
      children: contentProvider.categories.map((category) {
        final isSelected = _selectedCategories.contains(category.id);

        return FilterChip(
          label: Text(
            category.name,
            style: TextStyle(color: isSelected ? Colors.white : Colors.black),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedCategories.add(category.id!);
              } else {
                _selectedCategories.remove(category.id);
              }
            });
          },
          selectedColor: Colors.red[800],
          backgroundColor: Colors.grey[200],
          checkmarkColor: Colors.white,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentProvider = Provider.of<ContentProvider>(context);
    final userAuthProvider = Provider.of<UserAuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isEpisode
              ? 'Ajouter un épisode'
              : widget.content == null
              ? 'Créer du contenu payant'
              : 'Modifier le contenu',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red[800],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.save, color: Colors.white),
              onPressed: _saveContent,
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _buildUserInfoSection(userAuthProvider.loginUserData),
                  SizedBox(height: 20),

                  if (!widget.isEpisode) ...[
                    _buildContentTypeSelector(),
                    SizedBox(height: 16),
                  ],

                  if (_isSeries && !widget.isEpisode) ...[
                    TextFormField(
                      controller: _seriesNameController,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Nom de la série *',
                        labelStyle: TextStyle(color: Colors.red),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      validator: (value) {
                        if (_isSeries && (value == null || value.isEmpty)) {
                          return 'Veuillez entrer un nom de série';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                  ],

                  if (widget.isEpisode) ...[
                    TextFormField(
                      controller: _episodeNumberController,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Numéro d\'épisode *',
                        labelStyle: TextStyle(color: Colors.red),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (widget.isEpisode && (value == null || value.isEmpty || int.tryParse(value) == null)) {
                          return 'Veuillez entrer un numéro d\'épisode valide';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          _episodeNumber = int.tryParse(value) ?? 1;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: widget.isEpisode ? 'Titre de l\'épisode *' : 'Titre *',
                      labelStyle: TextStyle(color: Colors.red),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un titre';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      labelStyle: TextStyle(color: Colors.red),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer une description';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  Row(
                    children: [
                      Checkbox(
                        value: _isFree,
                        onChanged: _isUploading ? null : (value) {
                          setState(() {
                            _isFree = value!;
                          });
                        },
                        activeColor: Colors.red,
                      ),
                      Text('Contenu gratuit', style: TextStyle(color: Colors.black)),
                    ],
                  ),

                  if (!_isFree) ...[
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Prix (FCFA) *',
                        labelStyle: TextStyle(color: Colors.red),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                        suffixText: 'FCFA',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (!_isFree) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un prix';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price < 50) {
                            return 'Le prix minimum est de 50 FCFA';
                          }
                        }
                        return null;
                      },
                    ),
                  ],

                  SizedBox(height: 16),

                  if (!widget.isEpisode) ...[
                    Text(
                      'Catégories *',
                      style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    _buildCategoriesSelector(contentProvider),
                    SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _hashtagsController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Hashtags (séparés par des virgules)',
                      labelStyle: TextStyle(color: Colors.red),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  _buildVideoUploadSection(),

                  SizedBox(height: 16),

                  _buildVideoPreview(),

                  // SizedBox(height: 16),
                  //
                  // ElevatedButton(
                  //   style: ElevatedButton.styleFrom(
                  //     foregroundColor: Colors.white,
                  //     backgroundColor: Colors.black,
                  //     padding: EdgeInsets.symmetric(vertical: 16),
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(8),
                  //     ),
                  //   ),
                  //   onPressed: _isUploading ? null : _pickThumbnail,
                  //   child: Text('Choisir une miniature'),
                  // ),

                  SizedBox(height: 16),

                  _buildThumbnailPreview(),

                  SizedBox(height: 16),

                  if (_isUploading) _buildProgressIndicator(),

                  SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.red[800],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isUploading ? null : _saveContent,
                      child: Text(
                        widget.isEpisode
                            ? 'AJOUTER L\'ÉPISODE'
                            : widget.content == null
                            ? 'PUBLIER LE CONTENU PAYANT'
                            : 'METTRE À JOUR',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Upload en cours...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _uploadMessage,
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _hashtagsController.dispose();
    _seriesNameController.dispose();
    _episodeNumberController.dispose();
    super.dispose();
  }
}


