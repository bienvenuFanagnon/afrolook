import 'dart:typed_data';

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/contenuPayant/userAbonnerInfos.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdfx/pdfx.dart';

import '../../models/model_data.dart';
import '../../providers/contenuPayantProvider.dart';
import '../../providers/authProvider.dart';
import '../../services/linkService.dart';
import 'contentDetails.dart';
import 'ebookPadReader.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

class EbookDetailScreen extends StatefulWidget {
  final ContentPaie content;
  final Episode? episode;

  EbookDetailScreen({required this.content, this.episode});

  @override
  _EbookDetailScreenState createState() => _EbookDetailScreenState();
}

class _EbookDetailScreenState extends State<EbookDetailScreen> with SingleTickerProviderStateMixin {
  PdfControllerPinch? _pdfController;
  bool _isPdfInitialized = false;
  bool _isPurchasing = false;
  bool _isLiked = false;
  bool _showLikeAnimation = false;
  late AnimationController _likeAnimationController;
  bool _isLikedAnimation = false;
  Episode? _currentEpisode;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _showPdfViewer = false;
  bool _isLoadingPdf = false;

  // Variables pour le téléchargement
  bool _isDownloading = false;
  String? _currentDownloadTaskId;
  ReceivePort _port = ReceivePort();
  String _downloadPath = '';

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    _incrementViews();

    _likeAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    // Initialiser la communication entre isolates pour le téléchargement
    _initializeDownloader();
  }

  void _initializeDownloader() async {
    // Vérifier si le plugin est initialisé
    if (!FlutterDownloader.initialized) {
      if (kReleaseMode) {
        await FlutterDownloader.initialize(
          debug: false,
          ignoreSsl: false,
        );      } else {
        await FlutterDownloader.initialize(
          debug: true,
          ignoreSsl: true,
        );      }

    }
 _port = ReceivePort();

    // Enregistrer le port pour la communication entre isolates
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      printVm("listen data start");
      printVm("listen data start : ${data}");

      String taskId = data[0];
      DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
      int progress = data[2];

      printVm("listen DownloadTaskStatus : ${DownloadTaskStatus}");

      if (taskId == _currentDownloadTaskId) {
        if (status == DownloadTaskStatus.complete) {
          setState(() {
            _isDownloading = false;
          });
          _showDownloadSuccessModal();
        } else if (status == DownloadTaskStatus.failed) {
          setState(() {
            _isDownloading = false;
          });
          _showDownloadError();
        }
        // On ignore la progression pour ne pas l'afficher
      }
    });

    // Enregistrer le callback de téléchargement
    FlutterDownloader.registerCallback(downloadCallback);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  void _showDeleteModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Supprimer l\'ebook ?'),
        content: Text(
          widget.content.isSeries
              ? 'Êtes-vous sûr de vouloir supprimer cette série d\'ebooks et tous ses épisodes ? Cette action est irréversible.'
              : 'Êtes-vous sûr de vouloir supprimer cet ebook ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);

              bool success = false;
              final contentProvider = Provider.of<ContentProvider>(context, listen: false);

              if (widget.content.isSeries) {
                success = await contentProvider.deleteContentPaie(widget.content.id!);
              } else if (widget.episode != null) {
                success = await contentProvider.deleteEpisode(widget.episode!.id!);
              } else {
                success = await contentProvider.deleteContentPaie(widget.content.id!);
              }

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Suppression réussie !'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la suppression.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _triggerLikeAnimation() {
    Future.delayed(Duration(milliseconds: 1000), () {
      setState(() {
        _showLikeAnimation = false;
      });
    });
  }

  Future<void> _initializePdf() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);

    // Vérifier si l'utilisateur a acheté le contenu
    bool hasPurchased = contentProvider.userPurchases
        .any((purchase) => purchase.contentId == widget.content.id);

    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
        userProvider.loginUserData?.id == widget.content.ownerId;

    bool canRead = (widget.content.isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree) ||
        hasPurchased ||
        isAdminOrOwner;

    String? pdfUrl = widget.content.isSeries && _currentEpisode != null
        ? _currentEpisode!.pdfUrl
        : widget.content.pdfUrl ?? '';

    if (canRead && pdfUrl!.isNotEmpty) {
      try {
        setState(() {
          _isLoadingPdf = true;
        });

        _pdfController = PdfControllerPinch(
          document: PdfDocument.openData(
            await _loadPdfData(pdfUrl),
          ),
          initialPage: 1,
        );

        // Écouter les changements de page
        _pdfController!.addListener(() {
          if (_pdfController!.page != null) {
            setState(() {
              _currentPage = _pdfController!.page!;
              _totalPages = _pdfController!.pagesCount ?? 0;
            });
          }
        });

        setState(() {
          _isPdfInitialized = true;
          _isLoadingPdf = false;
        });
      } catch (e) {
        print('Erreur initialisation PDF: $e');
        setState(() {
          _isLoadingPdf = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Uint8List> _loadPdfData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to load PDF: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load PDF: $e');
    }
  }

  void _incrementViews() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);

    if (widget.content.isSeries && _currentEpisode != null) {
      await contentProvider.incrementViews(_currentEpisode!.id!, isEpisode: true);
    } else {
      await contentProvider.incrementViews(widget.content.id!);
    }
  }

  void _handleLike() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);

    setState(() {
      _isLiked = !_isLiked;
      _showLikeAnimation = true;
    });

    _likeAnimationController.reset();
    _likeAnimationController.forward();
    _triggerLikeAnimation();

    if (widget.content.isSeries && _currentEpisode != null) {
      await contentProvider.toggleLike(_currentEpisode!.id!, isEpisode: true);
    } else {
      await contentProvider.toggleLike(widget.content.id!);
    }
  }

  Future<void> _downloadEbook() async {
    try {
      final pdfUrl = widget.content.isSeries && widget.episode != null
          ? widget.episode!.pdfUrl
          : widget.content.pdfUrl;

      if (pdfUrl == null || pdfUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aucun ebook disponible pour le téléchargement'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Vérifier l'initialisation du plugin
      if (!FlutterDownloader.initialized) {
        if (kReleaseMode) {
          await FlutterDownloader.initialize(
            debug: false,
            ignoreSsl: false,
          );      } else {
          await FlutterDownloader.initialize(
            debug: true,
            ignoreSsl: true,
          );      }      }

      // --- DEMANDE DE PERMISSIONS ---
      bool permissionGranted = false;
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        if (sdkInt >= 33) {
          // Android 13 et +
          final photos = await Permission.photos.request();
          final videos = await Permission.videos.request();

          permissionGranted = photos.isGranted || videos.isGranted;
        } else if (sdkInt >= 30) {
          // Android 11 et 12
          final storage = await Permission.storage.request();
          permissionGranted = storage.isGranted;
        } else {
          // Android <11
          final storage = await Permission.storage.request();
          permissionGranted = storage.isGranted;
        }
      } else {
        // iOS
        final status = await Permission.storage.request();
        permissionGranted = status.isGranted;
      }
      // if (Platform.isAndroid) {
      //   final androidInfo = await DeviceInfoPlugin().androidInfo;
      //   if (androidInfo.version.sdkInt >= 33) {
      //     // Android 13+
      //     final status = await Permission.manageExternalStorage.request();
      //     permissionGranted = status.isGranted;
      //   } else if (androidInfo.version.sdkInt >= 30) {
      //     // Android 11 et 12
      //     final status = await Permission.manageExternalStorage.request();
      //     permissionGranted = status.isGranted;
      //   } else {
      //     // Android <11
      //     final status = await Permission.storage.request();
      //     permissionGranted = status.isGranted;
      //   }
      // } else {
      //   // iOS
      //   final status = await Permission.storage.request();
      //   permissionGranted = status.isGranted;
      // }

      if (!permissionGranted) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Permissions requises'),
            content: Text(
              'Pour télécharger l\'ebook, vous devez autoriser l\'accès au stockage.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Ouvrir les paramètres'),
              ),
            ],
          ),
        );

        if (openSettings == true) {
          await openAppSettings();
        }
        return;
      }

      // --- CHEMIN DE TELECHARGEMENT ---
      String downloadPath;
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        downloadPath = '${directory?.path}/Download';
        // Créer le dossier s'il n'existe pas
        await Directory(downloadPath).create(recursive: true);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        downloadPath = directory.path;
      }

      _downloadPath = downloadPath;

      final fileName = '${widget.content.title?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'ebook'}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Afficher le loading de démarrage
      _startDownloadAndShowModals();

      // --- TELECHARGEMENT ---
      setState(() {
        _isDownloading = true;
      });

      final taskId = await FlutterDownloader.enqueue(
        url: pdfUrl,
        savedDir: downloadPath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
      );

      if (taskId != null) {
        setState(() {
          _currentDownloadTaskId = taskId;
        });
      } else {
        setState(() {
          _isDownloading = false;
        });
        _showDownloadError();
      }

    } catch (e) {
      print('❌ Erreur téléchargement ebook: $e');
      setState(() {
        _isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du téléchargement: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startDownloadAndShowModals() {
    // Affiche le modal de téléchargement
    _showDownloadStartModal();

    // Simule le téléchargement ou attends la vraie fin du téléchargement
    Future.delayed(Duration(seconds: 2), () {
      // Ferme le modal de téléchargement avant d'ouvrir celui de succès
      Navigator.of(context, rootNavigator: true).pop();

      // Affiche le modal de succès
      _showDownloadSuccessModal();
    });
  }

// Modal de téléchargement en cours
  void _showDownloadStartModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _afroBlack,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: _afroGreen,
                  strokeWidth: 3,
                ),
                SizedBox(height: 20),
                Text(
                  'Téléchargement en cours',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Votre ebook est en cours de téléchargement...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Vous serez notifié lorsque le téléchargement sera terminé.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void _showDownloadSuccessModal() {
    // Fermer d'abord le modal de chargement
    Navigator.of(context, rootNavigator: true).pop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _afroBlack,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: _afroGreen,
                  size: 60,
                ),
                SizedBox(height: 20),
                Text(
                  'Téléchargement Réussi!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Votre ebook a été téléchargé avec succès.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _afroGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _afroGreen.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Emplacement du fichier:',
                        style: TextStyle(
                          color: _afroGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _downloadPath,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _afroWhite,
                          side: BorderSide(color: _afroWhite),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text('Fermer'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: _afroBlack,
                          backgroundColor: _afroGreen,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          if (_currentDownloadTaskId != null) {
                            await FlutterDownloader.open(taskId: _currentDownloadTaskId!);
                          }
                          Navigator.pop(context);
                        },
                        child: Text('Ouvrir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDownloadError() {
    // Fermer d'abord le modal de chargement
    Navigator.of(context, rootNavigator: true).pop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _afroBlack,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                SizedBox(height: 20),
                Text(
                  'Échec du Téléchargement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Une erreur est survenue lors du téléchargement de l\'ebook.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Fermer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReadingOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _afroBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Options de lecture',
              style: TextStyle(
                color: _afroWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.visibility, color: _afroGreen),
              title: Text('Lire en ligne', style: TextStyle(color: _afroWhite)),
              subtitle: Text('Lire directement dans l\'application', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EbookReaderScreen(
                      content: widget.content,
                      episode: widget.episode,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.download, color: _afroYellow),
              title: Text('Télécharger', style: TextStyle(color: _afroWhite)),
              subtitle: Text('Télécharger l\'ebook sur votre appareil', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _downloadEbook();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openPdfViewer() async {
    setState(() {
      _isLoadingPdf = true;
    });

    await _initializePdf();

    if (_isPdfInitialized) {
      setState(() {
        _showPdfViewer = true;
        _isLoadingPdf = false;
      });
    } else {
      setState(() {
        _isLoadingPdf = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _likeAnimationController.dispose();
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    _port.close();
    super.dispose();
  }

  Future<void> _handlePurchase() async {
    setState(() {
      _isPurchasing = true;
    });

    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);

    final result = await contentProvider.purchaseContentPaie(
        userProvider.loginUserData!,
        widget.content,
        context
    );

    setState(() {
      _isPurchasing = false;
    });

    if (result == PurchaseResult.success) {
      contentProvider.loadUserPurchases();
      _showSuccessModal();
      setState(() {});
    } else if (result == PurchaseResult.alreadyPurchased) {
      _showAlreadyPurchasedModal();
    }
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _afroBlack,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: _afroGreen,
                  size: 60,
                ),
                SizedBox(height: 20),
                Text(
                  'Achat Réussi!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'L\'ebook a été débloqué avec succès.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _afroGreen,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _initializePdf();
                    });
                  },
                  child: Text('Lire maintenant'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAlreadyPurchasedModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _afroBlack,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  color: _afroYellow,
                  size: 60,
                ),
                SizedBox(height: 20),
                Text(
                  'Déjà Acheté',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Vous avez déjà acheté cet ebook.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _afroYellow,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
                    setState(() {
                      contentProvider.loadUserPurchases();
                    });
                  },
                  child: Text('Actualiser'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectEpisode(Episode episode) {
    setState(() {
      _currentEpisode = episode;
      _isPdfInitialized = false;
      _showPdfViewer = false;
    });
    _initializePdf();
  }

  Widget _buildSeriesInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.content.title!,
          style: TextStyle(
            color: _afroWhite,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Série Ebook',
          style: TextStyle(
            color: _afroYellow,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 16),
        if (_currentEpisode != null) ...[
          Text(
            'Épisode: ${_currentEpisode!.title}',
            style: TextStyle(
              color: _afroWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Épisode ${_currentEpisode!.episodeNumber}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSimpleContentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.content.title!,
          style: TextStyle(
            color: _afroWhite,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPdfViewer() {
    if (_isLoadingPdf) {
      return Container(
        height: 500,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _afroGreen),
              SizedBox(height: 16),
              Text(
                'Chargement du PDF...',
                style: TextStyle(color: _afroWhite),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isPdfInitialized || _pdfController == null) {
      return Container(
        height: 500,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              SizedBox(height: 16),
              Text(
                'Erreur de chargement du PDF',
                style: TextStyle(color: _afroWhite),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Contrôles de navigation
        Container(
          padding: EdgeInsets.all(16),
          color: _afroBlack,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios, color: _afroWhite),
                onPressed: _currentPage > 1
                    ? () {
                  _pdfController!.previousPage(
                    curve: Curves.easeInOut,
                    duration: Duration(milliseconds: 300),
                  );
                }
                    : null,
              ),

              PdfPageNumber(
                controller: _pdfController!,
                builder: (_, loadingState, page, pagesCount) => Container(
                  alignment: Alignment.center,
                  child: Text(
                    '${page ?? 0}/${pagesCount ?? 0}',
                    style: TextStyle(color: _afroWhite, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),

              IconButton(
                icon: Icon(Icons.arrow_forward_ios, color: _afroWhite),
                onPressed: _currentPage < _totalPages
                    ? () {
                  _pdfController!.nextPage(
                    curve: Curves.easeInOut,
                    duration: Duration(milliseconds: 300),
                  );
                }
                    : null,
              ),
            ],
          ),
        ),

        // Vue PDF
        Expanded(
          child: PdfViewPinch(
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => Center(
                child: CircularProgressIndicator(color: _afroGreen),
              ),
              pageLoaderBuilder: (_) => Center(
                child: CircularProgressIndicator(color: _afroGreen),
              ),
              errorBuilder: (_, error) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 60),
                    SizedBox(height: 16),
                    Text(
                      'Erreur: $error',
                      style: TextStyle(color: _afroWhite),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            controller: _pdfController!,
          ),
        ),

        // Bouton de fermeture
        Container(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: _afroBlack,
              backgroundColor: _afroGreen,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () {
              setState(() {
                _showPdfViewer = false;
              });
            },
            child: Text('Retour aux détails'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
        userProvider.loginUserData?.id == widget.content.ownerId;
    final hasPurchased = contentProvider.userPurchases
        .any((purchase) => purchase.contentId == widget.content.id);

    final isSeries = widget.content.isSeries;
    bool canRead = (isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree) ||
        hasPurchased ||
        isAdminOrOwner;

    // Déterminer l'URL de la couverture
    String thumbnailUrl = isSeries && _currentEpisode != null
        ? _currentEpisode!.thumbnailUrl!
        : widget.content.thumbnailUrl ?? '';

    // Déterminer le nombre de pages
    int pageCount = isSeries && _currentEpisode != null
        ? _currentEpisode!.pageCount
        : widget.content.pageCount;

    if (_showPdfViewer) {
      return Scaffold(
        backgroundColor: _afroBlack,
        appBar: AppBar(
          backgroundColor: _afroBlack,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _afroWhite),
            onPressed: () {
              setState(() {
                _showPdfViewer = false;
              });
            },
          ),
          title: Text(
            'Lecture de l\'ebook',
            style: TextStyle(color: _afroWhite),
          ),
        ),
        body: _buildPdfViewer(),
      );
    }

    return Scaffold(
      backgroundColor: _afroBlack,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                floating: false,
                pinned: true,
                backgroundColor: _afroBlack,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[900],
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          child: Icon(Icons.book, color: Colors.white, size: 60),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              _afroBlack.withOpacity(0.9),
                              _afroBlack.withOpacity(0.3),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      if (!canRead && !isAdminOrOwner)
                        Positioned.fill(
                          child: Container(
                            color: _afroBlack.withOpacity(0.7),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 60,
                                    color: _afroWhite,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Ebook verrouillé',
                                    style: TextStyle(
                                      color: _afroWhite,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Débloquez cet ebook pour le lire',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Votre soutien aide les auteurs à créer plus de contenu',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (isAdminOrOwner)
                        Positioned.fill(
                          child: Container(
                            color: _afroBlack.withOpacity(0.5),
                            child: Center(
                              child: Text(
                                'Vous pouvez lire cet ebook gratuitement (Admin/Propriétaire)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: _afroWhite),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (isAdminOrOwner)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _showDeleteModal,
                    ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      widget.content.isSeries ? _buildSeriesInfo() : _buildSimpleContentInfo(),
                      SizedBox(height: 10),

                      // Informations du propriétaire
                      ContentOwnerInfo(ownerId: widget.content.ownerId),

                      // Actions rapides
                      Row(
                        children: [
                          // Bouton Partage
                          GestureDetector(
                            onTap: () {
                              final AppLinkService _appLinkService = AppLinkService();
                              if (widget.episode == null) {
                                _appLinkService.shareContent(
                                  type: AppLinkType.contentpaie,
                                  id: widget.content.id!,
                                  message: " ${widget.content.description}",
                                  mediaUrl: widget.content.thumbnailUrl!.isNotEmpty ? "${widget.content.thumbnailUrl!}" : "",
                                );
                              } else {
                                _appLinkService.shareContent(
                                  type: AppLinkType.contentpaie,
                                  id: widget.content.id!,
                                  message: " ${widget.episode!.description}",
                                  mediaUrl: widget.episode!.thumbnailUrl!.isNotEmpty ? "${widget.episode!.thumbnailUrl!}" : "",
                                );
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _afroBlack.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.share,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),

                          SizedBox(width: 8),
                          // Bouton Like
                          GestureDetector(
                            onTap: _handleLike,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _afroBlack.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isLiked ? Icons.favorite : Icons.favorite_border,
                                color: _isLiked ? Colors.red : _afroWhite,
                                size: 24,
                              ),
                            ),
                          ),
                          SizedBox(width: 1),
                          Text(
                            widget.content.isSeries && _currentEpisode != null
                                ? '${_currentEpisode!.likes}'
                                : '${widget.content.likes}',
                            style: TextStyle(color: _afroWhite, fontSize: 16),
                          ),
                          SizedBox(width: 15),

                          // Affichage des vues
                          Icon(Icons.visibility, color: _afroWhite, size: 24),
                          SizedBox(width: 2),
                          Text(
                            widget.content.isSeries && _currentEpisode != null
                                ? '${_currentEpisode!.views}'
                                : '${widget.content.views}',
                            style: TextStyle(color: _afroWhite, fontSize: 16),
                          ),
                          Spacer(),

                          // Badge pages
                          if (pageCount > 0)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _afroGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$pageCount pages',
                                style: TextStyle(
                                  color: _afroGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          SizedBox(width: 8),

                          if (!widget.content.isFree && (!widget.content.isSeries ||
                              (widget.content.isSeries && _currentEpisode != null && !_currentEpisode!.isFree)))
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _afroYellow.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _afroYellow),
                              ),
                              child: Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: _afroYellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 10),

                      // Description
                      Text(
                        widget.content.isSeries && _currentEpisode != null
                            ? _currentEpisode!.description
                            : widget.content.description!,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Message de soutien aux auteurs
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _afroGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _afroGreen.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.favorite, color: _afroGreen, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Soutenez les auteurs',
                                  style: TextStyle(
                                    color: _afroGreen,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'En achetant cet ebook, vous soutenez directement les auteurs et leur permettez de créer plus de contenu de qualité.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      if (!canRead)
                        Container(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: _afroBlack,
                              backgroundColor: _afroYellow,
                              padding: EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _isPurchasing ? null : _handlePurchase,
                            child: _isPurchasing
                                ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: _afroBlack,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              'SOUTENIR LES AUTEURS - ${widget.content.price} F',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            Container(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: _afroWhite,
                                  backgroundColor: _afroGreen,
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _showReadingOptions,
                                child: Text(
                                  'LIRE L\'EBOOK',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            if (canRead && (widget.content.isFree || hasPurchased || isAdminOrOwner))
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _afroYellow,
                                  side: BorderSide(color: _afroYellow),
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _downloadEbook,
                                child: Text(
                                  'TÉLÉCHARGER L\'EBOOK',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      SizedBox(height: 20),

                      if ((widget.content.isSeries ? widget.content.hashtags! : widget.content.hashtags) != null &&
                          (widget.content.isSeries ? widget.content.hashtags!.isNotEmpty : widget.content.hashtags!.isNotEmpty))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tags:',
                              style: TextStyle(
                                color: _afroWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: (widget.content.isSeries && _currentEpisode != null
                                  ? widget.content.hashtags!
                                  : widget.content.hashtags!).map((hashtag) {
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _afroGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _afroGreen),
                                  ),
                                  child: Text(
                                    '#$hashtag',
                                    style: TextStyle(color: _afroGreen),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Animation like
          if (_showLikeAnimation)
            Positioned.fill(
              child: Center(
                child: IgnorePointer(
                  child: AnimatedScale(
                    scale: _isLikedAnimation ? 1.5 : 1.0,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 100,
                    ),
                  ),
                ),
              ),
            ),

          // Indicateur de vue
          Positioned(
            top: 100,
            right: 20,
            child: Visibility(
              visible: (widget.content.isSeries && _currentEpisode != null
                  ? _currentEpisode!.views > 0
                  : widget.content.views != null && widget.content.views! > 0),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _afroBlack.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: _afroWhite, size: 14),
                    SizedBox(width: 4),
                    Text(
                      widget.content.isSeries && _currentEpisode != null
                          ? '${_currentEpisode!.views}'
                          : '${widget.content.views}',
                      style: TextStyle(color: _afroWhite, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Couleurs thématiques
const Color _afroBlack = Color(0xFF121212);
const Color _afroWhite = Color(0xFFFFFFFF);
const Color _afroGreen = Color(0xFF00C853);
const Color _afroYellow = Color(0xFFFFD600);

// class EbookDetailScreen extends StatefulWidget {
//   final ContentPaie content;
//   final Episode? episode;
//
//   EbookDetailScreen({required this.content, this.episode});
//
//   @override
//   _EbookDetailScreenState createState() => _EbookDetailScreenState();
// }
//
// class _EbookDetailScreenState extends State<EbookDetailScreen> with SingleTickerProviderStateMixin {
//   PdfControllerPinch? _pdfController;
//   bool _isPdfInitialized = false;
//   bool _isPurchasing = false;
//   bool _isLiked = false;
//   bool _showLikeAnimation = false;
//   late AnimationController _likeAnimationController;
//   bool _isLikedAnimation = false;
//   Episode? _currentEpisode;
//   int _currentPage = 1;
//   int _totalPages = 0;
//   bool _showPdfViewer = false;
//   bool _isLoadingPdf = false;
//
//   // Variables pour le téléchargement
//   bool _isDownloading = false;
//   int _downloadProgress = 0;
//   String? _currentDownloadTaskId;
//   ReceivePort _port = ReceivePort();
//
//   @override
//   void initState() {
//     super.initState();
//     _currentEpisode = widget.episode;
//     _incrementViews();
//
//     _likeAnimationController = AnimationController(
//       vsync: this,
//       duration: Duration(milliseconds: 1500),
//     );
//
//     // Initialiser la communication entre isolates pour le téléchargement
//     _initializeDownloader();
//   }
//
//   void _initializeDownloader() async {
//     // Vérifier si le plugin est initialisé
//     if (!FlutterDownloader.initialized) {
//       await FlutterDownloader.initialize(
//         debug: true,
//         ignoreSsl: true,
//       );
//     }
//
//     // Enregistrer le port pour la communication entre isolates
//     IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
//     _port.listen((dynamic data) {
//       String taskId = data[0];
//       DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
//       int progress = data[2];
//
//       if (taskId == _currentDownloadTaskId) {
//         setState(() {
//           _downloadProgress = progress;
//         });
//
//         if (status == DownloadTaskStatus.complete) {
//           setState(() {
//             _isDownloading = false;
//             _downloadProgress = 0;
//           });
//           _showDownloadSuccess();
//         } else if (status == DownloadTaskStatus.failed) {
//           setState(() {
//             _isDownloading = false;
//             _downloadProgress = 0;
//           });
//           _showDownloadError();
//         } else if (status == DownloadTaskStatus.running) {
//           setState(() {
//             _isDownloading = true;
//           });
//         }
//       }
//     });
//
//     // Enregistrer le callback de téléchargement
//     FlutterDownloader.registerCallback(downloadCallback);
//   }
//
//   @pragma('vm:entry-point')
//   static void downloadCallback(String id, int status, int progress) {
//     final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
//     send?.send([id, status, progress]);
//   }
//   void _showDeleteModal() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         title: Text('Supprimer l\'ebook ?'),
//         content: Text(
//           widget.content.isSeries
//               ? 'Êtes-vous sûr de vouloir supprimer cette série d\'ebooks et tous ses épisodes ? Cette action est irréversible.'
//               : 'Êtes-vous sûr de vouloir supprimer cet ebook ? Cette action est irréversible.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Annuler'),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () async {
//               Navigator.pop(context);
//
//               bool success = false;
//               final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//
//               if (widget.content.isSeries) {
//                 success = await contentProvider.deleteContentPaie(widget.content.id!);
//               } else if (widget.episode != null) {
//                 success = await contentProvider.deleteEpisode(widget.episode!.id!);
//               } else {
//                 success = await contentProvider.deleteContentPaie(widget.content.id!);
//               }
//
//               if (success) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Suppression réussie !'),
//                     backgroundColor: Colors.green,
//                   ),
//                 );
//                 Navigator.pop(context);
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Erreur lors de la suppression.'),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//               }
//             },
//             child: Text('Supprimer'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _triggerLikeAnimation() {
//     Future.delayed(Duration(milliseconds: 1000), () {
//       setState(() {
//         _showLikeAnimation = false;
//       });
//     });
//   }
//
//   Future<void> _initializePdf() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//
//     // Vérifier si l'utilisateur a acheté le contenu
//     bool hasPurchased = contentProvider.userPurchases
//         .any((purchase) => purchase.contentId == widget.content.id);
//
//     final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
//         userProvider.loginUserData?.id == widget.content.ownerId;
//
//     bool canRead = (widget.content.isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree) ||
//         hasPurchased ||
//         isAdminOrOwner;
//
//     String? pdfUrl = widget.content.isSeries && _currentEpisode != null
//         ? _currentEpisode!.pdfUrl
//         : widget.content.pdfUrl ?? '';
//
//     if (canRead && pdfUrl!.isNotEmpty) {
//       try {
//         setState(() {
//           _isLoadingPdf = true;
//         });
//
//         _pdfController = PdfControllerPinch(
//           document: PdfDocument.openData(
//             await _loadPdfData(pdfUrl),
//           ),
//           initialPage: 1,
//         );
//
//         // Écouter les changements de page
//         _pdfController!.addListener(() {
//           if (_pdfController!.page != null) {
//             setState(() {
//               _currentPage = _pdfController!.page!;
//               _totalPages = _pdfController!.pagesCount ?? 0;
//             });
//           }
//         });
//
//         setState(() {
//           _isPdfInitialized = true;
//           _isLoadingPdf = false;
//         });
//       } catch (e) {
//         print('Erreur initialisation PDF: $e');
//         setState(() {
//           _isLoadingPdf = false;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Erreur lors du chargement du PDF: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//   Future<Uint8List> _loadPdfData(String url) async {
//     try {
//       final response = await http.get(Uri.parse(url));
//       if (response.statusCode == 200) {
//         return response.bodyBytes;
//       } else {
//         throw Exception('Failed to load PDF: ${response.statusCode}');
//       }
//     } catch (e) {
//       throw Exception('Failed to load PDF: $e');
//     }
//   }
//
//   void _incrementViews() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//
//     if (widget.content.isSeries && _currentEpisode != null) {
//       await contentProvider.incrementViews(_currentEpisode!.id!, isEpisode: true);
//     } else {
//       await contentProvider.incrementViews(widget.content.id!);
//     }
//   }
//
//   void _handleLike() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//
//     setState(() {
//       _isLiked = !_isLiked;
//       _showLikeAnimation = true;
//     });
//
//     _likeAnimationController.reset();
//     _likeAnimationController.forward();
//     _triggerLikeAnimation();
//
//     if (widget.content.isSeries && _currentEpisode != null) {
//       await contentProvider.toggleLike(_currentEpisode!.id!, isEpisode: true);
//     } else {
//       await contentProvider.toggleLike(widget.content.id!);
//     }
//   }
//
//   Future<void> _downloadEbook() async {
//     try {
//       final pdfUrl = widget.content.isSeries && widget.episode != null
//           ? widget.episode!.pdfUrl
//           : widget.content.pdfUrl;
//
//       if (pdfUrl == null || pdfUrl.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Aucun ebook disponible pour le téléchargement'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         return;
//       }
//
//       // Vérifier l'initialisation du plugin
//       if (!FlutterDownloader.initialized) {
//         await FlutterDownloader.initialize(debug: true);
//       }
//
//       // --- DEMANDE DE PERMISSIONS ---
//       bool permissionGranted = false;
//
//       if (Platform.isAndroid) {
//         final androidInfo = await DeviceInfoPlugin().androidInfo;
//         if (androidInfo.version.sdkInt >= 33) {
//           // Android 13+
//           final status = await Permission.manageExternalStorage.request();
//           permissionGranted = status.isGranted;
//         } else if (androidInfo.version.sdkInt >= 30) {
//           // Android 11 et 12
//           final status = await Permission.manageExternalStorage.request();
//           permissionGranted = status.isGranted;
//         } else {
//           // Android <11
//           final status = await Permission.storage.request();
//           permissionGranted = status.isGranted;
//         }
//       } else {
//         // iOS
//         final status = await Permission.storage.request();
//         permissionGranted = status.isGranted;
//       }
//
//       if (!permissionGranted) {
//         final openSettings = await showDialog<bool>(
//           context: context,
//           builder: (_) => AlertDialog(
//             title: Text('Permissions requises'),
//             content: Text(
//               'Pour télécharger l\'ebook, vous devez autoriser l\'accès au stockage.',
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context, false),
//                 child: Text('Annuler'),
//               ),
//               ElevatedButton(
//                 onPressed: () => Navigator.pop(context, true),
//                 child: Text('Ouvrir les paramètres'),
//               ),
//             ],
//           ),
//         );
//
//         if (openSettings == true) {
//           await openAppSettings();
//         }
//         return;
//       }
//
//       // --- CHEMIN DE TELECHARGEMENT ---
//       String downloadPath;
//       if (Platform.isAndroid) {
//         final directory = await getExternalStorageDirectory();
//         downloadPath = '${directory?.path}/Download';
//         // Créer le dossier s'il n'existe pas
//         await Directory(downloadPath).create(recursive: true);
//       } else {
//         final directory = await getApplicationDocumentsDirectory();
//         downloadPath = directory.path;
//       }
//
//       final fileName = '${widget.content.title?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'ebook'}_${DateTime.now().millisecondsSinceEpoch}.pdf';
//
//       // --- TELECHARGEMENT ---
//       setState(() {
//         _isDownloading = true;
//         _downloadProgress = 0;
//       });
//
//       final taskId = await FlutterDownloader.enqueue(
//         url: pdfUrl,
//         savedDir: downloadPath,
//         fileName: fileName,
//         showNotification: true,
//         openFileFromNotification: true,
//         saveInPublicStorage: true,
//       );
//
//       if (taskId != null) {
//         setState(() {
//           _currentDownloadTaskId = taskId;
//         });
//       } else {
//         setState(() {
//           _isDownloading = false;
//         });
//         _showDownloadError();
//       }
//
//     } catch (e) {
//       print('❌ Erreur téléchargement ebook: $e');
//       setState(() {
//         _isDownloading = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Erreur lors du téléchargement: ${e.toString()}'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   void _showDownloadSuccess() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Ebook téléchargé avec succès!'),
//         backgroundColor: Colors.green,
//         duration: Duration(seconds: 3),
//         action: SnackBarAction(
//           label: 'Ouvrir',
//           textColor: Colors.white,
//           onPressed: () async {
//             if (_currentDownloadTaskId != null) {
//               await FlutterDownloader.open(taskId: _currentDownloadTaskId!);
//             }
//           },
//         ),
//       ),
//     );
//   }
//
//   void _showDownloadError() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Échec du téléchargement'),
//         backgroundColor: Colors.red,
//         duration: Duration(seconds: 3),
//       ),
//     );
//   }
//
//   void _cancelDownload() async {
//     if (_currentDownloadTaskId != null) {
//       await FlutterDownloader.cancel(taskId: _currentDownloadTaskId!);
//       setState(() {
//         _isDownloading = false;
//         _downloadProgress = 0;
//         _currentDownloadTaskId = null;
//       });
//     }
//   }
//
//   void _showReadingOptions() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: _afroBlack,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (context) => Container(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'Options de lecture',
//               style: TextStyle(
//                 color: _afroWhite,
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 16),
//             ListTile(
//               leading: Icon(Icons.visibility, color: _afroGreen),
//               title: Text('Lire en ligne', style: TextStyle(color: _afroWhite)),
//               subtitle: Text('Lire directement dans l\'application', style: TextStyle(color: Colors.white70)),
//               onTap: () {
//                 Navigator.pop(context);
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => EbookReaderScreen(
//                       content: widget.content,
//                       episode: widget.episode,
//                     ),
//                   ),
//                 );
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.download, color: _afroYellow),
//               title: Text('Télécharger', style: TextStyle(color: _afroWhite)),
//               subtitle: Text('Télécharger l\'ebook sur votre appareil', style: TextStyle(color: Colors.white70)),
//               onTap: () {
//                 Navigator.pop(context);
//                 _downloadEbook();
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _openPdfViewer() async {
//     setState(() {
//       _isLoadingPdf = true;
//     });
//
//     await _initializePdf();
//
//     if (_isPdfInitialized) {
//       setState(() {
//         _showPdfViewer = true;
//         _isLoadingPdf = false;
//       });
//     } else {
//       setState(() {
//         _isLoadingPdf = false;
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     _pdfController?.dispose();
//     _likeAnimationController.dispose();
//     IsolateNameServer.removePortNameMapping('downloader_send_port');
//     _port.close();
//     super.dispose();
//   }
//
//   Future<void> _handlePurchase() async {
//     setState(() {
//       _isPurchasing = true;
//     });
//
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//     final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
//
//     final result = await contentProvider.purchaseContentPaie(
//         userProvider.loginUserData!,
//         widget.content,
//         context
//     );
//
//     setState(() {
//       _isPurchasing = false;
//     });
//
//     if (result == PurchaseResult.success) {
//       contentProvider.loadUserPurchases();
//       _showSuccessModal();
//       setState(() {});
//     } else if (result == PurchaseResult.alreadyPurchased) {
//       _showAlreadyPurchasedModal();
//     }
//   }
//
//   void _showSuccessModal() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           child: Container(
//             decoration: BoxDecoration(
//               color: _afroBlack,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.check_circle,
//                   color: _afroGreen,
//                   size: 60,
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   'Achat Réussi!',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 SizedBox(height: 12),
//                 Text(
//                   'L\'ebook a été débloqué avec succès.',
//                   style: TextStyle(
//                     color: Colors.white70,
//                     fontSize: 16,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 24),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: _afroGreen,
//                     padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   onPressed: () {
//                     Navigator.pop(context);
//                     setState(() {
//                       _initializePdf();
//                     });
//                   },
//                   child: Text('Lire maintenant'),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void _showAlreadyPurchasedModal() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           child: Container(
//             decoration: BoxDecoration(
//               color: _afroBlack,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.info_outline,
//                   color: _afroYellow,
//                   size: 60,
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   'Déjà Acheté',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 SizedBox(height: 12),
//                 Text(
//                   'Vous avez déjà acheté cet ebook.',
//                   style: TextStyle(
//                     color: Colors.white70,
//                     fontSize: 16,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 24),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: _afroYellow,
//                     padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   onPressed: () {
//                     Navigator.pop(context);
//                     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//                     setState(() {
//                       contentProvider.loadUserPurchases();
//                     });
//                   },
//                   child: Text('Actualiser'),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void _selectEpisode(Episode episode) {
//     setState(() {
//       _currentEpisode = episode;
//       _isPdfInitialized = false;
//       _showPdfViewer = false;
//     });
//     _initializePdf();
//   }
//
//   Widget _buildSeriesInfo() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.content.title!,
//           style: TextStyle(
//             color: _afroWhite,
//             fontSize: 28,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         SizedBox(height: 8),
//         Text(
//           'Série Ebook',
//           style: TextStyle(
//             color: _afroYellow,
//             fontSize: 16,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         SizedBox(height: 16),
//         if (_currentEpisode != null) ...[
//           Text(
//             'Épisode: ${_currentEpisode!.title}',
//             style: TextStyle(
//               color: _afroWhite,
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Épisode ${_currentEpisode!.episodeNumber}',
//             style: TextStyle(
//               color: Colors.white70,
//               fontSize: 14,
//             ),
//           ),
//         ],
//         SizedBox(height: 16),
//       ],
//     );
//   }
//
//   Widget _buildSimpleContentInfo() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.content.title!,
//           style: TextStyle(
//             color: _afroWhite,
//             fontSize: 28,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         SizedBox(height: 12),
//       ],
//     );
//   }
//
//   Widget _buildPdfViewer() {
//     if (_isLoadingPdf) {
//       return Container(
//         height: 500,
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(color: _afroGreen),
//               SizedBox(height: 16),
//               Text(
//                 'Chargement du PDF...',
//                 style: TextStyle(color: _afroWhite),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     if (!_isPdfInitialized || _pdfController == null) {
//       return Container(
//         height: 500,
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(Icons.error_outline, color: Colors.red, size: 60),
//               SizedBox(height: 16),
//               Text(
//                 'Erreur de chargement du PDF',
//                 style: TextStyle(color: _afroWhite),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return Column(
//       children: [
//         // Contrôles de navigation
//         Container(
//           padding: EdgeInsets.all(16),
//           color: _afroBlack,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               IconButton(
//                 icon: Icon(Icons.arrow_back_ios, color: _afroWhite),
//                 onPressed: _currentPage > 1
//                     ? () {
//                   _pdfController!.previousPage(
//                     curve: Curves.easeInOut,
//                     duration: Duration(milliseconds: 300),
//                   );
//                 }
//                     : null,
//               ),
//
//               PdfPageNumber(
//                 controller: _pdfController!,
//                 builder: (_, loadingState, page, pagesCount) => Container(
//                   alignment: Alignment.center,
//                   child: Text(
//                     '${page ?? 0}/${pagesCount ?? 0}',
//                     style: TextStyle(color: _afroWhite, fontWeight: FontWeight.bold, fontSize: 16),
//                   ),
//                 ),
//               ),
//
//               IconButton(
//                 icon: Icon(Icons.arrow_forward_ios, color: _afroWhite),
//                 onPressed: _currentPage < _totalPages
//                     ? () {
//                   _pdfController!.nextPage(
//                     curve: Curves.easeInOut,
//                     duration: Duration(milliseconds: 300),
//                   );
//                 }
//                     : null,
//               ),
//             ],
//           ),
//         ),
//
//         // Vue PDF
//         Expanded(
//           child: PdfViewPinch(
//             builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
//               options: const DefaultBuilderOptions(),
//               documentLoaderBuilder: (_) => Center(
//                 child: CircularProgressIndicator(color: _afroGreen),
//               ),
//               pageLoaderBuilder: (_) => Center(
//                 child: CircularProgressIndicator(color: _afroGreen),
//               ),
//               errorBuilder: (_, error) => Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.error_outline, color: Colors.red, size: 60),
//                     SizedBox(height: 16),
//                     Text(
//                       'Erreur: $error',
//                       style: TextStyle(color: _afroWhite),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             controller: _pdfController!,
//           ),
//         ),
//
//         // Bouton de fermeture
//         Container(
//           padding: EdgeInsets.all(16),
//           child: ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               foregroundColor: _afroBlack,
//               backgroundColor: _afroGreen,
//               padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
//             ),
//             onPressed: () {
//               setState(() {
//                 _showPdfViewer = false;
//               });
//             },
//             child: Text('Retour aux détails'),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildDownloadProgress() {
//     if (!_isDownloading) return SizedBox();
//
//     return Positioned(
//       bottom: 20,
//       left: 20,
//       right: 20,
//       child: Container(
//         padding: EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: _afroBlack.withOpacity(0.9),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: _afroGreen),
//         ),
//         child: Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'Téléchargement en cours...',
//                   style: TextStyle(
//                     color: _afroWhite,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 Text(
//                   '$_downloadProgress%',
//                   style: TextStyle(
//                     color: _afroGreen,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 8),
//             LinearProgressIndicator(
//               value: _downloadProgress / 100,
//               backgroundColor: Colors.grey[800],
//               color: _afroGreen,
//             ),
//             SizedBox(height: 8),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 TextButton(
//                   onPressed: _cancelDownload,
//                   child: Text(
//                     'ANNULER',
//                     style: TextStyle(
//                       color: Colors.red,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//     final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
//         userProvider.loginUserData?.id == widget.content.ownerId;
//     final hasPurchased = contentProvider.userPurchases
//         .any((purchase) => purchase.contentId == widget.content.id);
//
//     final isSeries = widget.content.isSeries;
//     bool canRead = (isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree) ||
//         hasPurchased ||
//         isAdminOrOwner;
//
//     // Déterminer l'URL de la couverture
//     String thumbnailUrl = isSeries && _currentEpisode != null
//         ? _currentEpisode!.thumbnailUrl!
//         : widget.content.thumbnailUrl ?? '';
//
//     // Déterminer le nombre de pages
//     int pageCount = isSeries && _currentEpisode != null
//         ? _currentEpisode!.pageCount
//         : widget.content.pageCount;
//
//     if (_showPdfViewer) {
//       return Scaffold(
//         backgroundColor: _afroBlack,
//         appBar: AppBar(
//           backgroundColor: _afroBlack,
//           leading: IconButton(
//             icon: Icon(Icons.arrow_back, color: _afroWhite),
//             onPressed: () {
//               setState(() {
//                 _showPdfViewer = false;
//               });
//             },
//           ),
//           title: Text(
//             'Lecture de l\'ebook',
//             style: TextStyle(color: _afroWhite),
//           ),
//         ),
//         body: _buildPdfViewer(),
//       );
//     }
//
//     return Scaffold(
//       backgroundColor: _afroBlack,
//       body: Stack(
//         children: [
//           CustomScrollView(
//             slivers: [
//               SliverAppBar(
//                 expandedHeight: 400,
//                 floating: false,
//                 pinned: true,
//                 backgroundColor: _afroBlack,
//                 flexibleSpace: FlexibleSpaceBar(
//                   background: Stack(
//                     children: [
//                       CachedNetworkImage(
//                         imageUrl: thumbnailUrl,
//                         fit: BoxFit.cover,
//                         width: double.infinity,
//                         placeholder: (context, url) => Container(
//                           color: Colors.grey[900],
//                         ),
//                         errorWidget: (context, url, error) => Container(
//                           color: Colors.grey[900],
//                           child: Icon(Icons.book, color: Colors.white, size: 60),
//                         ),
//                       ),
//                       Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.bottomCenter,
//                             end: Alignment.topCenter,
//                             colors: [
//                               _afroBlack.withOpacity(0.9),
//                               _afroBlack.withOpacity(0.3),
//                               Colors.transparent,
//                             ],
//                             stops: [0.0, 0.5, 1.0],
//                           ),
//                         ),
//                       ),
//                       if (!canRead && !isAdminOrOwner)
//                         Positioned.fill(
//                           child: Container(
//                             color: _afroBlack.withOpacity(0.7),
//                             child: Center(
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.lock_outline,
//                                     size: 60,
//                                     color: _afroWhite,
//                                   ),
//                                   SizedBox(height: 16),
//                                   Text(
//                                     'Ebook verrouillé',
//                                     style: TextStyle(
//                                       color: _afroWhite,
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   SizedBox(height: 8),
//                                   Text(
//                                     'Débloquez cet ebook pour le lire',
//                                     style: TextStyle(
//                                       color: Colors.white70,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   SizedBox(height: 8),
//                                   Text(
//                                     'Votre soutien aide les auteurs à créer plus de contenu',
//                                     style: TextStyle(
//                                       color: Colors.white70,
//                                       fontSize: 14,
//                                       fontStyle: FontStyle.italic,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         )
//                       else if (isAdminOrOwner)
//                         Positioned.fill(
//                           child: Container(
//                             color: _afroBlack.withOpacity(0.5),
//                             child: Center(
//                               child: Text(
//                                 'Vous pouvez lire cet ebook gratuitement (Admin/Propriétaire)',
//                                 style: TextStyle(
//                                   color: Colors.white70,
//                                   fontSize: 16,
//                                   fontStyle: FontStyle.italic,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 leading: IconButton(
//                   icon: Icon(Icons.arrow_back, color: _afroWhite),
//                   onPressed: () => Navigator.pop(context),
//                 ),
//                 actions: [
//                   if (isAdminOrOwner)
//                     IconButton(
//                       icon: Icon(Icons.delete_outline, color: Colors.red),
//                       onPressed: _showDeleteModal,
//                     ),
//                 ],
//               ),
//
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: EdgeInsets.all(20),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       widget.content.isSeries ? _buildSeriesInfo() : _buildSimpleContentInfo(),
//                       SizedBox(height: 10),
//
//                       // Informations du propriétaire
//                       ContentOwnerInfo(ownerId: widget.content.ownerId),
//
//                       // Actions rapides
//                       Row(
//                         children: [
//                           // Bouton Partage
//                           GestureDetector(
//                             onTap: () {
//                               final AppLinkService _appLinkService = AppLinkService();
//                               if (widget.episode == null) {
//                                 _appLinkService.shareContent(
//                                   type: AppLinkType.contentpaie,
//                                   id: widget.content.id!,
//                                   message: " ${widget.content.description}",
//                                   mediaUrl: widget.content.thumbnailUrl!.isNotEmpty ? "${widget.content.thumbnailUrl!}" : "",
//                                 );
//                               } else {
//                                 _appLinkService.shareContent(
//                                   type: AppLinkType.contentpaie,
//                                   id: widget.content.id!,
//                                   message: " ${widget.episode!.description}",
//                                   mediaUrl: widget.episode!.thumbnailUrl!.isNotEmpty ? "${widget.episode!.thumbnailUrl!}" : "",
//                                 );
//                               }
//                             },
//                             child: Container(
//                               padding: EdgeInsets.all(8),
//                               decoration: BoxDecoration(
//                                 color: _afroBlack.withOpacity(0.5),
//                                 shape: BoxShape.circle,
//                               ),
//                               child: Icon(
//                                 Icons.share,
//                                 color: Colors.white,
//                                 size: 24,
//                               ),
//                             ),
//                           ),
//
//                           SizedBox(width: 8),
//                           // Bouton Like
//                           GestureDetector(
//                             onTap: _handleLike,
//                             child: Container(
//                               padding: EdgeInsets.all(8),
//                               decoration: BoxDecoration(
//                                 color: _afroBlack.withOpacity(0.5),
//                                 shape: BoxShape.circle,
//                               ),
//                               child: Icon(
//                                 _isLiked ? Icons.favorite : Icons.favorite_border,
//                                 color: _isLiked ? Colors.red : _afroWhite,
//                                 size: 24,
//                               ),
//                             ),
//                           ),
//                           SizedBox(width: 1),
//                           Text(
//                             widget.content.isSeries && _currentEpisode != null
//                                 ? '${_currentEpisode!.likes}'
//                                 : '${widget.content.likes}',
//                             style: TextStyle(color: _afroWhite, fontSize: 16),
//                           ),
//                           SizedBox(width: 15),
//
//                           // Affichage des vues
//                           Icon(Icons.visibility, color: _afroWhite, size: 24),
//                           SizedBox(width: 2),
//                           Text(
//                             widget.content.isSeries && _currentEpisode != null
//                                 ? '${_currentEpisode!.views}'
//                                 : '${widget.content.views}',
//                             style: TextStyle(color: _afroWhite, fontSize: 16),
//                           ),
//                           Spacer(),
//
//                           // Badge pages
//                           if (pageCount > 0)
//                             Container(
//                               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                               decoration: BoxDecoration(
//                                 color: _afroGreen.withOpacity(0.2),
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               child: Text(
//                                 '$pageCount pages',
//                                 style: TextStyle(
//                                   color: _afroGreen,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           SizedBox(width: 8),
//
//                           if (!widget.content.isFree && (!widget.content.isSeries ||
//                               (widget.content.isSeries && _currentEpisode != null && !_currentEpisode!.isFree)))
//                             Container(
//                               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                               decoration: BoxDecoration(
//                                 color: _afroYellow.withOpacity(0.2),
//                                 borderRadius: BorderRadius.circular(4),
//                                 border: Border.all(color: _afroYellow),
//                               ),
//                               child: Text(
//                                 'PREMIUM',
//                                 style: TextStyle(
//                                   color: _afroYellow,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                       SizedBox(height: 10),
//
//                       // Description
//                       Text(
//                         widget.content.isSeries && _currentEpisode != null
//                             ? _currentEpisode!.description
//                             : widget.content.description!,
//                         style: TextStyle(
//                           color: Colors.white70,
//                           fontSize: 16,
//                           height: 1.5,
//                         ),
//                       ),
//                       SizedBox(height: 20),
//
//                       // Message de soutien aux auteurs
//                       Container(
//                         width: double.infinity,
//                         padding: EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: _afroGreen.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: _afroGreen.withOpacity(0.3)),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               children: [
//                                 Icon(Icons.favorite, color: _afroGreen, size: 16),
//                                 SizedBox(width: 8),
//                                 Text(
//                                   'Soutenez les auteurs',
//                                   style: TextStyle(
//                                     color: _afroGreen,
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             SizedBox(height: 8),
//                             Text(
//                               'En achetant cet ebook, vous soutenez directement les auteurs et leur permettez de créer plus de contenu de qualité.',
//                               style: TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       SizedBox(height: 20),
//
//                       if (!canRead)
//                         Container(
//                           width: double.infinity,
//                           child: ElevatedButton(
//                             style: ElevatedButton.styleFrom(
//                               foregroundColor: _afroBlack,
//                               backgroundColor: _afroYellow,
//                               padding: EdgeInsets.symmetric(vertical: 18),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               elevation: 2,
//                             ),
//                             onPressed: _isPurchasing ? null : _handlePurchase,
//                             child: _isPurchasing
//                                 ? SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(
//                                 color: _afroBlack,
//                                 strokeWidth: 2,
//                               ),
//                             )
//                                 : Text(
//                               'SOUTENIR LES AUTEURS - ${widget.content.price} F',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         )
//                       else
//                         Column(
//                           children: [
//                             Container(
//                               width: double.infinity,
//                               child: ElevatedButton(
//                                 style: ElevatedButton.styleFrom(
//                                   foregroundColor: _afroWhite,
//                                   backgroundColor: _afroGreen,
//                                   padding: EdgeInsets.symmetric(vertical: 18),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                   elevation: 2,
//                                 ),
//                                 onPressed: _showReadingOptions,
//                                 child: Text(
//                                   'LIRE L\'EBOOK',
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             SizedBox(height: 12),
//                             if (canRead && (widget.content.isFree || hasPurchased || isAdminOrOwner))
//                               OutlinedButton(
//                                 style: OutlinedButton.styleFrom(
//                                   foregroundColor: _afroYellow,
//                                   side: BorderSide(color: _afroYellow),
//                                   padding: EdgeInsets.symmetric(vertical: 16),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                                 onPressed: _downloadEbook,
//                                 child: Text(
//                                   'TÉLÉCHARGER L\'EBOOK',
//                                   style: TextStyle(
//                                     fontSize: 14,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       SizedBox(height: 20),
//
//                       if ((widget.content.isSeries ? widget.content.hashtags! : widget.content.hashtags) != null &&
//                           (widget.content.isSeries ? widget.content.hashtags!.isNotEmpty : widget.content.hashtags!.isNotEmpty))
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Tags:',
//                               style: TextStyle(
//                                 color: _afroWhite,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             Wrap(
//                               spacing: 8,
//                               runSpacing: 4,
//                               children: (widget.content.isSeries && _currentEpisode != null
//                                   ? widget.content.hashtags!
//                                   : widget.content.hashtags!).map((hashtag) {
//                                 return Container(
//                                   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                                   decoration: BoxDecoration(
//                                     color: _afroGreen.withOpacity(0.2),
//                                     borderRadius: BorderRadius.circular(16),
//                                     border: Border.all(color: _afroGreen),
//                                   ),
//                                   child: Text(
//                                     '#$hashtag',
//                                     style: TextStyle(color: _afroGreen),
//                                   ),
//                                 );
//                               }).toList(),
//                             ),
//                           ],
//                         ),
//                       SizedBox(height: 24),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           // Animation like
//           if (_showLikeAnimation)
//             Positioned.fill(
//               child: Center(
//                 child: IgnorePointer(
//                   child: AnimatedScale(
//                     scale: _isLikedAnimation ? 1.5 : 1.0,
//                     duration: Duration(milliseconds: 300),
//                     curve: Curves.easeOutBack,
//                     child: Icon(
//                       Icons.favorite,
//                       color: Colors.red,
//                       size: 100,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//
//           // Indicateur de vue
//           Positioned(
//             top: 100,
//             right: 20,
//             child: Visibility(
//               visible: (widget.content.isSeries && _currentEpisode != null
//                   ? _currentEpisode!.views > 0
//                   : widget.content.views != null && widget.content.views! > 0),
//               child: Container(
//                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: _afroBlack.withOpacity(0.7),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.visibility, color: _afroWhite, size: 14),
//                     SizedBox(width: 4),
//                     Text(
//                       widget.content.isSeries && _currentEpisode != null
//                           ? '${_currentEpisode!.views}'
//                           : '${widget.content.views}',
//                       style: TextStyle(color: _afroWhite, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//
//           // Indicateur de progression du téléchargement
//           _buildDownloadProgress(),
//         ],
//       ),
//     );
//   }
// }
//
// // Couleurs thématiques
// const Color _afroBlack = Color(0xFF121212);
// const Color _afroWhite = Color(0xFFFFFFFF);
// const Color _afroGreen = Color(0xFF00C853);
// const Color _afroYellow = Color(0xFFFFD600);