import 'dart:async';
import 'dart:io';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../providers/authProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import '../../theme/app_colors.dart';


class ContentFormScreen extends StatefulWidget {
  final ContentPaie? content;
  final bool isEpisode;
  final String? seriesId;
  final ContentType? seriesType;

  ContentFormScreen({
    this.content,
    this.isEpisode = false,
    this.seriesId,
    this.seriesType
  });

  @override
  _ContentFormScreenState createState() => _ContentFormScreenState();
}

class _ContentFormScreenState extends State<ContentFormScreen> {
  late AppColors _colors;

  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _hashtagsController = TextEditingController();
  final _seriesNameController = TextEditingController();
  final _episodeNumberController = TextEditingController();

  int _currentStep = 0; // Stepper 3 étapes

  bool _isFree = false;
  bool _isSeries = false;
  ContentType _contentType = ContentType.VIDEO;
  List<String> _selectedCategories = [];
  String? _videoUrl;
  String? _pdfUrl;
  String? _thumbnailUrl;
  File? _videoFile;
  File? _pdfFile;
  File? _thumbnailFile;
  // Nouveaux champs
  File? _genericFile;       // TEMPLATE, PACK_ZIP, AUDIO, PRESET, BUNDLE
  String? _genericFileUrl;
  String? _genericFileSize;
  File? _tutorialVideoFile; // tuto vidéo optionnel
  String? _tutorialVideoUrl;
  bool _affiliationEnabled = false;
  double _affiliationRate = 0.10; // 10% par défaut
  bool _flashSaleEnabled = false;
  final _flashPriceCtrl = TextEditingController();
  DateTime? _flashSaleEndDate;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  bool _isSaving = false;
  String _uploadMessage = '';
  int _episodeNumber = 1;
  int _pageCount = 0;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();

    if (widget.isEpisode && widget.seriesType != null) {
      _contentType = widget.seriesType!;
    }

    if (widget.content != null) {
      _titleController.text = widget.content!.title;
      _descriptionController.text = widget.content!.description;
      _priceController.text = widget.content!.price.toString();
      _isFree = widget.content!.isFree;
      _isSeries = widget.content!.isSeries; // CONSERVÉ
      _contentType = widget.content!.contentType;
      _selectedCategories = widget.content!.categories;
      _videoUrl = widget.content!.videoUrl;
      _pdfUrl = widget.content!.pdfUrl;
      _thumbnailUrl = widget.content!.thumbnailUrl;
      _hashtagsController.text = widget.content!.hashtags.join(', ');
      _pageCount = widget.content!.pageCount;
      _genericFileUrl = widget.content!.fileUrl;
      _genericFileSize = widget.content!.fileSize;
      _tutorialVideoUrl = widget.content!.tutorialVideoUrl;
      _affiliationEnabled = widget.content!.affiliationEnabled;
      _affiliationRate = widget.content!.affiliationRate.clamp(0.05, 0.40);
      if (widget.content!.flashSalePrice != null) {
        _flashSaleEnabled = true;
        _flashPriceCtrl.text = widget.content!.flashSalePrice!.toInt().toString();
        if (widget.content!.flashSaleEndDate != null) {
          _flashSaleEndDate = DateTime.fromMillisecondsSinceEpoch(widget.content!.flashSaleEndDate!);
        }
      }

      if (widget.isEpisode) {
        _episodeNumberController.text = widget.content?.title.split('Épisode').last.trim() ?? '1';
      }
    } else {
      _priceController.text = '100';
    }
  }

  // Méthode pour sélectionner une vidéo
  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        File file = File(pickedFile.path);
        final fileSize = await file.length();
        final fileSizeMB = fileSize / (1024 * 1024);
        final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
        final isGoldVideo = authProvider.loginUserData.abonnement?.estGold ?? false;
        final maxMB = isGoldVideo ? 200.0 : 100.0;

        if (fileSizeMB > maxMB) {
          final limitLabel = isGoldVideo ? '200 Mo' : '100 Mo (200 Mo avec Gold)';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('La vidéo ne doit pas dépasser $limitLabel'),
              backgroundColor: _colors.danger,
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
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection de la vidéo: $e'),
          backgroundColor: _colors.danger,
        ),
      );
    }
  }

  // Méthode pour sélectionner un PDF
  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        final fileSize = await file.length();
        final fileSizeMB = fileSize / (1024 * 1024);

        if (fileSizeMB > 20) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Le PDF ne doit pas dépasser 20 Mo'),
              backgroundColor: _colors.danger,
            ),
          );
          return;
        }

        setState(() {
          _pdfFile = file;
          _pdfUrl = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection du PDF: $e'),
          backgroundColor: _colors.danger,
        ),
      );
    }
  }

  // Méthode pour sélectionner une image de couverture
  Future<void> _pickThumbnail() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        File file = File(pickedFile.path);
        setState(() {
          _thumbnailFile = file;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection de l\'image: $e'),
          backgroundColor: _colors.danger,
        ),
      );
    }
  }

  bool get _needsGenericFile =>
      _contentType == ContentType.TEMPLATE ||
      _contentType == ContentType.PACK_ZIP ||
      _contentType == ContentType.AUDIO ||
      _contentType == ContentType.PRESET ||
      _contentType == ContentType.BUNDLE ||
      _contentType == ContentType.FORMATION;

  List<String> get _allowedExtensionsForType {
    switch (_contentType) {
      case ContentType.AUDIO:
        return ['mp3', 'wav', 'aac'];
      case ContentType.PRESET:
        return ['zip', 'xmp', 'cube', 'lut'];
      case ContentType.PACK_ZIP:
      case ContentType.FORMATION:
      case ContentType.TEMPLATE:
      case ContentType.BUNDLE:
        return ['zip'];
      default:
        return ['zip'];
    }
  }

  double get _maxFileSizeMB {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final isGold = authProvider.loginUserData.abonnement?.estGold ?? false;
    switch (_contentType) {
      case ContentType.AUDIO:
      case ContentType.PRESET:
        return 50.0;
      case ContentType.EBOOK:
        return 50.0;
      default:
        return isGold ? 200.0 : 100.0;
    }
  }

  Future<void> _pickGenericFile() async {
    try {
      final extensions = _allowedExtensionsForType;
      final maxMB = _maxFileSizeMB;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final ext = result.files.single.extension?.toLowerCase() ?? '';
      if (!extensions.contains(ext)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Format non accepté. Formats attendus : ${extensions.join(', ')}'),
            backgroundColor: _colors.danger));
        return;
      }

      final sizeBytes = await file.length();
      final sizeMB = sizeBytes / (1024 * 1024);
      if (sizeMB > maxMB) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Le fichier dépasse la limite de ${maxMB.toInt()} Mo'),
            backgroundColor: _colors.danger));
        return;
      }
      setState(() {
        _genericFile = file;
        _genericFileUrl = null;
        _genericFileSize = '${sizeMB.toStringAsFixed(1)} Mo';
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'), backgroundColor: _colors.danger));
    }
  }

  Future<void> _pickTutorialVideo() async {
    try {
      final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      final file = File(picked.path);
      final sizeMB = (await file.length()) / (1024 * 1024);
      if (sizeMB > 20) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('La vidéo tuto ne doit pas dépasser 20 Mo'),
            backgroundColor: _colors.danger));
        return;
      }
      setState(() => _tutorialVideoFile = file);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'), backgroundColor: _colors.danger));
    }
  }

  Future<Map<String, String>> _uploadFiles() async {
    String? finalVideoUrl;
    String? finalPdfUrl;
    String? finalThumbnailUrl;
    String? finalFileUrl;
    String? finalTutorialUrl;

    // Validation
    if (_contentType == ContentType.VIDEO && _videoFile == null && _videoUrl == null) {
      throw Exception('Aucune vidéo sélectionnée');
    } else if (_contentType == ContentType.EBOOK && _pdfFile == null && _pdfUrl == null) {
      throw Exception('Aucun PDF sélectionné');
    } else if (_needsGenericFile && _genericFile == null && _genericFileUrl == null) {
      throw Exception('Veuillez sélectionner le fichier principal');
    }

    try {
      // Upload vidéo
      if (_contentType == ContentType.VIDEO && _videoFile != null) {
        final name = 'video_${DateTime.now().millisecondsSinceEpoch}${path.extension(_videoFile!.path)}';
        finalVideoUrl = await _uploadFile(_videoFile!, name, 'videos');
        if (finalVideoUrl == null) throw Exception('Échec upload vidéo');
      } else {
        finalVideoUrl = _videoUrl;
      }

      // Upload PDF
      if (_contentType == ContentType.EBOOK && _pdfFile != null) {
        final name = 'ebook_${DateTime.now().millisecondsSinceEpoch}.pdf';
        finalPdfUrl = await _uploadFile(_pdfFile!, name, 'ebooks');
        if (finalPdfUrl == null) throw Exception('Échec upload PDF');
      } else {
        finalPdfUrl = _pdfUrl;
      }

      // Upload fichier générique (template, pack, audio, preset, bundle, formation)
      if (_needsGenericFile && _genericFile != null) {
        final ext = path.extension(_genericFile!.path);
        final name = 'file_${DateTime.now().millisecondsSinceEpoch}$ext';
        finalFileUrl = await _uploadFile(_genericFile!, name, 'content_files');
        if (finalFileUrl == null) throw Exception('Échec upload fichier');
      } else {
        finalFileUrl = _genericFileUrl;
      }

      // Upload tuto vidéo
      if (_tutorialVideoFile != null) {
        final ext = path.extension(_tutorialVideoFile!.path);
        final name = 'tuto_${DateTime.now().millisecondsSinceEpoch}$ext';
        finalTutorialUrl = await _uploadFile(_tutorialVideoFile!, name, 'tutorial_videos');
      } else {
        finalTutorialUrl = _tutorialVideoUrl;
      }

      // Miniature
      if (_thumbnailFile != null) {
        final name = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.png';
        finalThumbnailUrl = await _uploadFile(_thumbnailFile!, name, 'thumbnails');
      } else if (_thumbnailUrl == null) {
        if (_contentType == ContentType.VIDEO && _videoFile != null) {
          try {
            final thumb = await _getVideoThumbnail(_videoFile!);
            final name = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.png';
            finalThumbnailUrl = await _uploadFile(thumb, name, 'thumbnails');
          } catch (e) {
            throw Exception('Échec génération miniature: $e');
          }
        } else {
          throw Exception('Une image de couverture est obligatoire');
        }
      } else {
        finalThumbnailUrl = _thumbnailUrl;
      }

      if (finalThumbnailUrl == null) throw Exception('Échec upload miniature');

      return {
        'videoUrl': finalVideoUrl ?? '',
        'pdfUrl': finalPdfUrl ?? '',
        'thumbnailUrl': finalThumbnailUrl,
        'fileUrl': finalFileUrl ?? '',
        'tutorialVideoUrl': finalTutorialUrl ?? '',
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> _uploadFile(File file, String fileName, String folder) async {
    try {
      final Reference storageRef = _storage.ref().child('$folder/$fileName');
      final UploadTask uploadTask = storageRef.putFile(file);

      final completer = Completer<TaskSnapshot>();

      uploadTask.snapshotEvents.listen(
              (TaskSnapshot snapshot) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            setState(() {
              _uploadProgress = progress;
              _uploadMessage = 'Upload ${_getUploadMessage(folder)}... ${(progress * 100).toStringAsFixed(0)}%';
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
      return null;
    }
  }

  String _getUploadMessage(String folder) {
    switch (folder) {
      case 'videos': return 'vidéo';
      case 'ebooks': return 'PDF';
      case 'thumbnails': return 'miniature';
      default: return 'fichier';
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
      throw Exception('Erreur lors de la génération de la miniature: $e');
    }
  }

// Fonction pour récupérer un ContentPaie par ID et envoyer une notification
  Future<void> notifyNewEpisode(String serieId,UserAuthProvider userProvider) async {
    try {
      // Récupérer le document depuis Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection('ContentPaies')
          .doc(serieId)
          .get();

      if (!docSnapshot.exists) {
        printVm('Document $serieId non trouvé');
        return;
      }

      // Convertir le snapshot en objet ContentPaie
      final content = ContentPaie.fromJson(docSnapshot.data()!);

      // Préparer le message de notification
      final message = "Business 🔥 - Nouvel épisode ajouté à la série '${content.title}' ! Regardez maintenant.";

      // Récupérer les utilisateurs à notifier
      final userIds = await userProvider.getAllUsersOneSignaUserId();

      if (userIds.isNotEmpty) {
        await userProvider.sendNotification(
          userIds: userIds,
          smallImage: content.thumbnailUrl,
          send_user_id: userProvider.loginUserData!.id!,
          recever_user_id: '',
          message: message,
          type_notif: NotificationType.POST.name,
          post_id: content.id ?? '',
          post_type: _getPostType(content.contentType),
          chat_id: '',
        );
      }

      printVm("Notification envoyée pour l'épisode: ${content.title}");
    } catch (e) {
      printVm("Erreur lors de l'envoi de la notification: $e");
    }
  }

  Future<void> _saveContent() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation du prix — minimum 500 FCFA
    if (!_isFree) {
      final price = double.tryParse(_priceController.text);
      if (price == null || price < 500) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Le prix minimum est de 500 FCFA'),
            backgroundColor: _colors.danger,
          ),
        );
        return;
      }
    }

    // Validation selon le type de contenu
    if (_contentType == ContentType.VIDEO && _videoUrl == null && _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez sélectionner une vidéo'),
          backgroundColor: _colors.danger,
        ),
      );
      return;
    } else if (_contentType == ContentType.EBOOK) {
      if (_pdfUrl == null && _pdfFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Veuillez sélectionner un PDF'),
            backgroundColor: _colors.danger,
          ),
        );
        return;
      }
      if (_thumbnailUrl == null && _thumbnailFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Une image de couverture est obligatoire pour les ebooks'),
            backgroundColor: _colors.danger,
          ),
        );
        return;
      }
    }

    // Validation catégories
    if (!widget.isEpisode && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez sélectionner au moins une catégorie'),
          backgroundColor: _colors.danger,
        ),
      );
      return;
    }

    // Validation nom de série
    if (_isSeries && !widget.isEpisode && _seriesNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez entrer un nom de série'),
          backgroundColor: _colors.danger,
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
      final String pdfUrl = uploadedUrls['pdfUrl']!;
      final String thumbnailUrl = uploadedUrls['thumbnailUrl']!;
      final String fileUrl = uploadedUrls['fileUrl']!;
      final String tutorialVideoUrl = uploadedUrls['tutorialVideoUrl']!;

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
          videoUrl: _contentType == ContentType.VIDEO ? videoUrl : null,
          pdfUrl: _contentType == ContentType.EBOOK ? pdfUrl : null,
          thumbnailUrl: thumbnailUrl,
          duration: 0,
          pageCount: _contentType == ContentType.EBOOK ? _pageCount : 0,
          episodeNumber: _episodeNumber,
          price: _isFree ? 0 : double.parse(_priceController.text),
          isFree: _isFree,
          contentType: _contentType,
        );

        success = await contentProvider.addEpisode(episode);
        notifyNewEpisode(widget.seriesId!,userProvider);
      } else {
        // Création/mise à jour d'un contenu
        final flashPrice = _flashSaleEnabled && _flashPriceCtrl.text.isNotEmpty
            ? double.tryParse(_flashPriceCtrl.text)
            : null;
        final flashEnd = _flashSaleEnabled && _flashSaleEndDate != null
            ? _flashSaleEndDate!.millisecondsSinceEpoch
            : null;

        final content = ContentPaie(
          id: widget.content?.id,
          ownerId: userProvider.loginUserData?.id ?? '',
          title: _isSeries ? _seriesNameController.text : _titleController.text,
          description: _descriptionController.text,
          videoUrl: _contentType == ContentType.VIDEO ? videoUrl : null,
          pdfUrl: _contentType == ContentType.EBOOK ? pdfUrl : null,
          thumbnailUrl: thumbnailUrl,
          fileUrl: fileUrl.isNotEmpty ? fileUrl : null,
          fileSize: _genericFileSize,
          tutorialVideoUrl: tutorialVideoUrl.isNotEmpty ? tutorialVideoUrl : null,
          categories: _selectedCategories,
          hashtags: hashtags,
          isSeries: _isSeries,
          contentType: _contentType,
          price: _isFree ? 0 : double.parse(_priceController.text),
          isFree: _isFree,
          pageCount: _contentType == ContentType.EBOOK ? _pageCount : 0,
          affiliationEnabled: _affiliationEnabled,
          affiliationRate: _affiliationEnabled ? _affiliationRate : 0.0,
          flashSalePrice: flashPrice,
          flashSaleEndDate: flashEnd,
          views: widget.content?.views ?? 0,
          likes: widget.content?.likes ?? 0,
          comments: widget.content?.comments ?? 0,
          duration: 0,
          createdAt: widget.content?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        if (widget.content == null) {
          success = await contentProvider.addContentPaie(content);
          // Envoi de notification
           userProvider.getAllUsersOneSignaUserId().then((userIds) async {
            if (userIds.isNotEmpty) {
              String message = _getNotificationMessage(content);

              await userProvider.sendNotification(
                userIds: userIds,
                smallImage: content.thumbnailUrl,
                send_user_id: userProvider.loginUserData!.id!,
                recever_user_id: '',
                message: message,
                type_notif: NotificationType.POST.name,
                post_id: content.id ?? '',
                post_type: _getPostType(content.contentType),
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
            backgroundColor: _colors.primary,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de la sauvegarde'),
            backgroundColor: _colors.danger,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _isSaving = false;
      });
      printVm('Erreur contentpaie: ${e.toString()}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: _colors.danger,
        ),
      );
    }
  }

  String _getNotificationMessage(ContentPaie content) {
    if (content.isSeries) {
      if (content.isVideo) {
        return "Business 🔥 -🎬 Nouvelle série vidéo: ${content.title} !";
      } else {
        return "Business 🔥 -📖 Nouvelle série de livres: ${content.title} !";
      }
    } else {
      if (content.isVideo) {
        return "Business 🔥 - 🎥 ${content.title} est en ligne et fait sensation !";
      } else {
        return "Business 🔥 - 📚 ${content.title} est disponible maintenant !";
      }
    }
  }

  String _getPostType(ContentType contentType) {
    switch (contentType) {
      case ContentType.VIDEO:
        return PostDataType.VIDEO.name;
      case ContentType.EBOOK:
        return PostDataType.EBOOK.name;
      default:
        return PostDataType.VIDEO.name;
    }
  }

  // WIDGETS DE L'INTERFACE

  Widget _buildUserInfoSection(UserData? user) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: _colors.primary,
            backgroundImage: user?.imageUrl != null && user!.imageUrl!.isNotEmpty
                ? NetworkImage(_cdnUrl(user.imageUrl))
                : null,
            child: user?.imageUrl == null || user!.imageUrl!.isEmpty
                ? Icon(Icons.person, color: _colors.onPrimary)
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
                    color: _colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${user?.abonnes ?? 0} abonnés',
                  style: TextStyle(
                    color: _colors.primary,
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
          style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildContentTypeChip('🎬 Vidéo', ContentType.VIDEO, Icons.videocam),
            _buildContentTypeChip('📘 Ebook', ContentType.EBOOK, Icons.book),
            _buildContentTypeChip('🎓 Formation', ContentType.FORMATION, Icons.school_outlined),
            _buildContentTypeChip('🎨 Template', ContentType.TEMPLATE, Icons.dashboard_customize_outlined),
            _buildContentTypeChip('📦 Pack ZIP', ContentType.PACK_ZIP, Icons.folder_zip_outlined),
            _buildContentTypeChip('🎵 Audio', ContentType.AUDIO, Icons.audiotrack_outlined),
            _buildContentTypeChip('🎛️ Preset', ContentType.PRESET, Icons.tune_outlined),
            _buildContentTypeChip('🗂️ Bundle', ContentType.BUNDLE, Icons.layers_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildContentTypeChip(String label, ContentType type, IconData icon) {
    final isSelected = _contentType == type;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? _colors.onPrimary : _colors.textPrimary),
          SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _contentType = type;
          if (type == ContentType.EBOOK) {
            // Réinitialiser la série si on passe à ebook
            _isSeries = false;
          }
        });
      },
      selectedColor: _colors.primary,
      labelStyle: TextStyle(
        color: isSelected ? _colors.onPrimary : _colors.textPrimary,
      ),
    );
  }

  Widget _buildSeriesTypeSelector() {
    if (widget.isEpisode) return const SizedBox();

    final isVideo = _contentType == ContentType.VIDEO;
    final isEbook = _contentType == ContentType.EBOOK;
    if (!isVideo && !isEbook) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVideo ? 'Format vidéo' : 'Format ebook',
          style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(isVideo ? 'Vidéo simple' : 'Ebook simple'),
                selected: !_isSeries,
                onSelected: (selected) {
                  if (selected) setState(() => _isSeries = false);
                },
                selectedColor: _colors.primary,
                labelStyle: TextStyle(
                  color: !_isSeries ? _colors.onPrimary : _colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: Text(isVideo ? 'Série vidéo' : 'Série ebook'),
                selected: _isSeries,
                onSelected: (selected) {
                  if (selected) setState(() => _isSeries = true);
                },
                selectedColor: _colors.primary,
                labelStyle: TextStyle(
                  color: _isSeries ? _colors.onPrimary : _colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFileUploadSection() {
    if (_contentType == ContentType.VIDEO) {
      return _buildVideoUploadSection();
    } else if (_contentType == ContentType.EBOOK) {
      return _buildPDFUploadSection();
    } else if (_needsGenericFile) {
      return _buildGenericFileSection();
    }
    return const SizedBox();
  }

  Widget _buildGenericFileSection() {
    final (label, icon) = _genericFileLabel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text('Max 200 Mo', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                foregroundColor: _colors.onPrimary,
                backgroundColor: _colors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isUploading ? null : _pickGenericFile,
              icon: Icon(icon, size: 18),
              label: Text(_genericFile != null || _genericFileUrl != null ? 'Changer' : 'Choisir'),
            ),
            if (_genericFile != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_genericFile!.path.split('/').last} · ${_genericFileSize ?? ""}',
                  style: TextStyle(fontSize: 11, color: _colors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else if (_genericFileUrl != null) ...[
              const SizedBox(width: 10),
              Icon(Icons.check_circle_outline, color: _colors.primary, size: 18),
              const SizedBox(width: 4),
              Text('Fichier déjà uploadé', style: TextStyle(fontSize: 11, color: _colors.textSecondary)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // Tuto vidéo optionnel
        Text(
          'Vidéo tutoriel (optionnelle)',
          style: TextStyle(color: _colors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text('Max 20 Mo — MP4 recommandé', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _colors.primary,
                side: BorderSide(color: _colors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isUploading ? null : _pickTutorialVideo,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: Text(_tutorialVideoFile != null || _tutorialVideoUrl != null ? 'Changer' : 'Ajouter'),
            ),
            if (_tutorialVideoFile != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tutorialVideoFile!.path.split('/').last,
                  style: TextStyle(fontSize: 11, color: _colors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else if (_tutorialVideoUrl != null) ...[
              const SizedBox(width: 10),
              Icon(Icons.check_circle_outline, color: _colors.primary, size: 18),
              const SizedBox(width: 4),
              Text('Tuto déjà uploadé', style: TextStyle(fontSize: 11, color: _colors.textSecondary)),
            ],
          ],
        ),
      ],
    );
  }

  (String, IconData) _genericFileLabel() {
    switch (_contentType) {
      case ContentType.AUDIO: return ('Fichier audio', Icons.audiotrack_outlined);
      case ContentType.TEMPLATE: return ('Fichier template', Icons.dashboard_customize_outlined);
      case ContentType.PACK_ZIP: return ('Archive ZIP', Icons.folder_zip_outlined);
      case ContentType.PRESET: return ('Fichier preset', Icons.tune_outlined);
      case ContentType.BUNDLE: return ('Bundle (ZIP)', Icons.layers_outlined);
      case ContentType.FORMATION: return ('Fichier de formation', Icons.school_outlined);
      default: return ('Fichier principal', Icons.attach_file_outlined);
    }
  }

  Widget _buildAffiliationSection() {
    if (_isFree || widget.isEpisode) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF25D366).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline, color: Color(0xFF25D366), size: 18),
              const SizedBox(width: 6),
              Text('Affiliation', style: TextStyle(
                  color: _colors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: _affiliationEnabled,
                onChanged: (v) => setState(() => _affiliationEnabled = v),
                activeColor: const Color(0xFF25D366),
              ),
            ],
          ),
          if (_affiliationEnabled) ...[
            const SizedBox(height: 8),
            Text(
              'Commission affilié : ${(_affiliationRate * 100).toInt()}%',
              style: TextStyle(color: _colors.textSecondary, fontSize: 13),
            ),
            Slider(
              value: _affiliationRate,
              min: 0.05,
              max: 0.40,
              divisions: 7,
              activeColor: const Color(0xFF25D366),
              label: '${(_affiliationRate * 100).toInt()}%',
              onChanged: (v) => setState(() => _affiliationRate = v),
            ),
            Text(
              'Tu gardes ${((0.88 - _affiliationRate) * 100).toInt()}% des ventes',
              style: TextStyle(fontSize: 11, color: _colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlashSaleSection() {
    if (_isFree || widget.isEpisode) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_outlined, color: Colors.red, size: 18),
              const SizedBox(width: 6),
              Text('Flash sale', style: TextStyle(
                  color: _colors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: _flashSaleEnabled,
                onChanged: (v) => setState(() => _flashSaleEnabled = v),
                activeColor: Colors.red,
              ),
            ],
          ),
          if (_flashSaleEnabled) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _flashPriceCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: _colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Prix flash (FCFA)',
                labelStyle: const TextStyle(color: Colors.red),
                suffixText: 'FCFA',
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red.withOpacity(0.4))),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined, color: Colors.red, size: 18),
              title: Text(
                _flashSaleEndDate != null
                    ? 'Expire le ${_flashSaleEndDate!.day}/${_flashSaleEndDate!.month}/${_flashSaleEndDate!.year}'
                    : 'Choisir une date d\'expiration',
                style: TextStyle(
                    fontSize: 13,
                    color: _flashSaleEndDate != null ? _colors.textPrimary : _colors.textSecondary),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _flashSaleEndDate = picked);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vidéo *',
          style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'Taille maximale: 50 Mo',
          style: TextStyle(color: _colors.textSecondary, fontSize: 12),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: _colors.onPrimary,
            backgroundColor: _colors.primary,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isUploading ? null : _pickVideo,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam),
              SizedBox(width: 8),
              Text('Choisir une vidéo'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPDFUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fichier PDF *',
          style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'Taille maximale: 20 Mo',
          style: TextStyle(color: _colors.textSecondary, fontSize: 12),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: _colors.onPrimary,
            backgroundColor: _colors.primary,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isUploading ? null : _pickPDF,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf),
              SizedBox(width: 8),
              Text('Choisir un PDF'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Image de couverture ${_contentType == ContentType.EBOOK ? '*' : ''}',
          style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        if (_contentType == ContentType.EBOOK)
          Text(
            'Obligatoire pour les ebooks',
            style: TextStyle(color: _colors.danger, fontSize: 12),
          ),
        SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: _colors.onPrimary,
            backgroundColor: _colors.background,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isUploading ? null : _pickThumbnail,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image),
              SizedBox(width: 8),
              Text('Choisir une image'),
            ],
          ),
        ),
        _buildThumbnailPreview(),
      ],
    );
  }

  Widget _buildFilePreview() {
    if (_contentType == ContentType.VIDEO) {
      return _buildVideoPreview();
    } else if (_contentType == ContentType.EBOOK) {
      return _buildPDFPreview();
    }
    return SizedBox();
  }

  Widget _buildVideoPreview() {
    if (_videoFile != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            'Aperçu de la vidéo:',
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _colors.textPrimary,
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
                      color: _colors.surfaceVariant,
                      child: Icon(Icons.videocam, size: 50, color: _colors.textSecondary),
                    );
                  },
                ),
                Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 50,
                    color: _colors.surface.withOpacity(0.9),
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
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _colors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library, size: 40, color: _colors.textSecondary),
                SizedBox(height: 8),
                Text(
                  'Vidéo disponible',
                  style: TextStyle(color: _colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return SizedBox();
  }

  Widget _buildPDFPreview() {
    if (_pdfFile != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            'Fichier PDF sélectionné:',
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _colors.primary),
            ),
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf, color: _colors.primary, size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pdfFile!.path.split('/').last,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      FutureBuilder<int>(
                        future: _pdfFile!.length(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final sizeMB = snapshot.data! / (1024 * 1024);
                            return Text(
                              '${sizeMB.toStringAsFixed(2)} Mo',
                              style: TextStyle(color: _colors.textSecondary),
                            );
                          }
                          return Text('Calcul...', style: TextStyle(color: _colors.textSecondary));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_pdfUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            'PDF déjà uploadé:',
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _colors.textSecondary),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, size: 40, color: _colors.textSecondary),
                SizedBox(height: 8),
                Text(
                  'PDF disponible',
                  style: TextStyle(color: _colors.textSecondary),
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
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _colors.textSecondary),
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
                    color: _colors.surfaceVariant,
                    child: Icon(Icons.image, size: 50, color: _colors.textSecondary),
                  );
                },
              ),
            ),
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
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _colors.textSecondary),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _cdnUrl(_thumbnailUrl),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: _colors.surfaceVariant,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 40, color: _colors.textSecondary),
                        SizedBox(height: 8),
                        Text(
                          'Erreur de chargement',
                          style: TextStyle(color: _colors.textSecondary),
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
          backgroundColor: _colors.surfaceVariant,
          valueColor: AlwaysStoppedAnimation<Color>(_colors.primary),
        ),
        SizedBox(height: 8),
        Text(
          _uploadMessage,
          style: TextStyle(color: _colors.textPrimary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCategoriesSelector(ContentProvider contentProvider) {
    return Wrap(
      spacing: 8,
      children: contentProvider.categories.map((category) {
        final isSelected = _selectedCategories.contains(category.name);

        return FilterChip(
          label: Text(
            category.name,
            style: TextStyle(color: isSelected ? _colors.onPrimary : _colors.textPrimary),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedCategories.add(category.name);
              } else {
                _selectedCategories.remove(category.name);
              }
            });
          },
          selectedColor: _colors.primary,
          backgroundColor: _colors.surfaceVariant,
          checkmarkColor: _colors.onPrimary,
        );
      }).toList(),
    );
  }

  // ── Validation par étape ────────────────────────────────────────────────────
  bool _validateStep0() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Le titre est obligatoire'),
          backgroundColor: _colors.danger));
      return false;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('La description est obligatoire'),
          backgroundColor: _colors.danger));
      return false;
    }
    if (_isSeries && !widget.isEpisode && _seriesNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Le nom de la série est obligatoire'),
          backgroundColor: _colors.danger));
      return false;
    }
    return true;
  }

  bool _validateStep1() {
    final hasFile = _thumbnailFile != null || _thumbnailUrl != null;
    if (!hasFile) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Veuillez ajouter une image de couverture'),
          backgroundColor: _colors.danger));
      return false;
    }
    if (_contentType == ContentType.VIDEO && _videoFile == null && _videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Veuillez sélectionner une vidéo'),
          backgroundColor: _colors.danger));
      return false;
    }
    if (_contentType == ContentType.EBOOK && _pdfFile == null && _pdfUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Veuillez sélectionner un PDF'),
          backgroundColor: _colors.danger));
      return false;
    }
    if (_needsGenericFile && _genericFile == null && _genericFileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Veuillez sélectionner le fichier (${_allowedExtensionsForType.join(', ')})'),
          backgroundColor: _colors.danger));
      return false;
    }
    return true;
  }

  // ── Helpers visuels Stepper ──────────────────────────────────────────────────
  Widget _stepCard(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _colors.border),
        ),
        child: child,
      );

  InputDecoration _inputDeco(String label, {String? suffix}) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _colors.primary),
        suffixText: suffix,
        filled: true,
        fillColor: _colors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _colors.primary, width: 2),
        ),
      );

  // ── Étape 0 : Type + Infos ────────────────────────────────────────────────
  Widget _buildStep0(ContentProvider contentProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isEpisode) ...[
          _stepCard(_buildContentTypeSelector()),
          _stepCard(_buildSeriesTypeSelector()),
          if (_isSeries) ...[
            TextFormField(
              controller: _seriesNameController,
              style: TextStyle(color: _colors.textPrimary),
              decoration: _inputDeco('Nom de la série *'),
            ),
            const SizedBox(height: 12),
          ],
        ],
        if (widget.isEpisode) ...[
          _stepCard(_buildContentTypeSelector()),
          TextFormField(
            controller: _episodeNumberController,
            style: TextStyle(color: _colors.textPrimary),
            decoration: _inputDeco('Numéro d\'épisode *'),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _episodeNumber = int.tryParse(v) ?? 1),
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: _titleController,
          style: TextStyle(color: _colors.textPrimary),
          decoration: _inputDeco(widget.isEpisode ? 'Titre de l\'épisode *' : 'Titre *'),
          maxLength: 80,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          style: TextStyle(color: _colors.textPrimary),
          decoration: _inputDeco('Description *'),
          maxLines: 3,
          maxLength: 500,
        ),
        const SizedBox(height: 12),
        if (!widget.isEpisode) ...[
          Text('Catégories', style: TextStyle(color: _colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildCategoriesSelector(contentProvider),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: _hashtagsController,
          style: TextStyle(color: _colors.textPrimary),
          decoration: _inputDeco('Hashtags (séparés par des virgules)'),
        ),
      ],
    );
  }

  // ── Étape 1 : Fichiers ────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepCard(_buildThumbnailSection()),
        const SizedBox(height: 4),
        _stepCard(_buildFileUploadSection()),
        if (_videoFile != null || _pdfFile != null || _genericFile != null) ...[
          const SizedBox(height: 8),
          _buildFilePreview(),
        ],
      ],
    );
  }

  // ── Étape 2 : Prix + Distribution ────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepCard(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Switch(
                  value: _isFree,
                  onChanged: _isUploading ? null : (v) => setState(() => _isFree = v),
                  activeColor: _colors.primary,
                ),
                const SizedBox(width: 8),
                Text('Contenu gratuit', style: TextStyle(color: _colors.textPrimary, fontSize: 15)),
              ],
            ),
            if (!_isFree) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                style: TextStyle(color: _colors.textPrimary),
                decoration: _inputDeco('Prix *', suffix: 'FCFA'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 6),
              Text('Minimum : 500 FCFA', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
            ],
          ],
        )),
        _stepCard(_buildAffiliationSection()),
        _stepCard(_buildFlashSaleSection()),
        if (_isUploading) ...[
          const SizedBox(height: 8),
          _buildProgressIndicator(),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: _colors.onPrimary,
              backgroundColor: _colors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isUploading ? null : _saveContent,
            child: _isSaving
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_colors.onPrimary)),
                  )
                : Text(
                    widget.isEpisode
                        ? 'AJOUTER L\'ÉPISODE'
                        : widget.content == null
                            ? 'PUBLIER LE CONTENU'
                            : 'METTRE À JOUR',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final contentProvider = Provider.of<ContentProvider>(context);
    final userAuthProvider = Provider.of<UserAuthProvider>(context);

    final stepTitles = ['Informations', 'Fichiers', 'Prix & diffusion'];
    final stepIcons = [Icons.info_outline, Icons.upload_file, Icons.sell_outlined];

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        title: Text(
          widget.isEpisode
              ? 'Ajouter un épisode'
              : widget.content == null
                  ? 'Créer du contenu payant'
                  : 'Modifier le contenu',
          style: TextStyle(color: _colors.onPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _colors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: _colors.onPrimary),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Indicateur d'étapes custom ─────────────────────────────
              Container(
                color: _colors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: List.generate(stepTitles.length, (i) {
                    final isDone = i < _currentStep;
                    final isActive = i == _currentStep;
                    return Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: i < _currentStep ? () => setState(() => _currentStep = i) : null,
                              child: Column(
                                children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDone
                                          ? _colors.primary
                                          : isActive
                                              ? _colors.primary.withOpacity(0.15)
                                              : _colors.border,
                                      border: isActive
                                          ? Border.all(color: _colors.primary, width: 2)
                                          : null,
                                    ),
                                    child: Icon(
                                      isDone ? Icons.check : stepIcons[i],
                                      size: 18,
                                      color: isDone
                                          ? _colors.onPrimary
                                          : isActive
                                              ? _colors.primary
                                              : _colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stepTitles[i],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isActive ? _colors.primary : _colors.textSecondary,
                                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (i < stepTitles.length - 1)
                            Expanded(
                              child: Container(
                                height: 2,
                                margin: const EdgeInsets.only(bottom: 20),
                                color: i < _currentStep ? _colors.primary : _colors.border,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              // ── Contenu de l'étape ──────────────────────────────────────
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête créateur
                        _buildUserInfoSection(userAuthProvider.loginUserData),
                        const SizedBox(height: 16),

                        if (_currentStep == 0) _buildStep0(contentProvider),
                        if (_currentStep == 1) _buildStep1(),
                        if (_currentStep == 2) _buildStep2(),

                        const SizedBox(height: 16),

                        // Boutons navigation Précédent / Suivant
                        if (_currentStep < 2)
                          Row(
                            children: [
                              if (_currentStep > 0)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => setState(() => _currentStep--),
                                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                                    label: const Text('Précédent'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _colors.textPrimary,
                                      side: BorderSide(color: _colors.border),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              if (_currentStep > 0) const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (_currentStep == 0 && !_validateStep0()) return;
                                    if (_currentStep == 1 && !_validateStep1()) return;
                                    setState(() => _currentStep++);
                                  },
                                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                                  label: Text(_currentStep == 1 ? 'Prix & diffusion' : 'Fichiers'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _colors.primary,
                                    foregroundColor: _colors.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Overlay upload ───────────────────────────────────────────────
          if (_isSaving)
            Container(
              color: _colors.background.withOpacity(0.85),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: _colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _colors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_colors.primary)),
                      const SizedBox(height: 20),
                      Text('Publication en cours…',
                          style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_uploadMessage.isNotEmpty)
                        Text(_uploadMessage,
                            style: TextStyle(color: _colors.textSecondary, fontSize: 13),
                            textAlign: TextAlign.center),
                      if (_uploadProgress > 0) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: _colors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(_colors.primary),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        Text('${(_uploadProgress * 100).toInt()}%',
                            style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
                      ],
                    ],
                  ),
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
    _flashPriceCtrl.dispose();
    super.dispose();
  }
}


