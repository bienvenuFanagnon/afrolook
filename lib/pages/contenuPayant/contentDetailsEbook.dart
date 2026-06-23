import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/contenuPayant/userAbonnerInfos.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import '../../services/linkService.dart';
import '../../theme/app_colors.dart';
import '../pub/native_ad_widget.dart';
import 'contentDetails.dart';
import 'ebookPadReader.dart';


class EbookDetailScreen extends StatefulWidget {
  final ContentPaie content;
  final Episode? episode;

  EbookDetailScreen({required this.content, this.episode});

  @override
  _EbookDetailScreenState createState() => _EbookDetailScreenState();
}

class _EbookDetailScreenState extends State<EbookDetailScreen> with SingleTickerProviderStateMixin {
  late AppColors _colors;

  // Lecteur PDF principal (ne sera utilisé que si acheté)
  PdfControllerPinch? _pdfController;
  bool _isFullPdfReady = false;

  // Variables pour les capsules (extraits PDF)
  PdfControllerPinch? _capsuleControllerStart;
  PdfControllerPinch? _capsuleControllerMiddle;
  PdfControllerPinch? _capsuleControllerEnd;
  PdfControllerPinch? _activeCapsuleController;

  bool _isCapsuleStartReady = false;
  bool _isCapsuleMiddleReady = false;
  bool _isCapsuleEndReady = false;
  bool _isCapsulePlaying = false;
  int? _capsuleTotalPages;
  int _currentCapsuleIndex = -1;
  Timer? _capsuleTimer;
  static const int _capsuleDurationSeconds = 5;

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

  bool _isDisliked = false;
  bool _showDislikeAnimation = false;

  bool _isDownloadingPdf = false;
  double _downloadProgress = 0.0;

  bool _isDownloading = false;
  String? _currentDownloadTaskId;
  ReceivePort _port = ReceivePort();
  String _downloadPath = '';

  bool _isPreviewMode = false; // true = utilisateur non acheteur

  final List<PreviewCapsule> _capsules = [
    PreviewCapsule(index: 0, label: 'Début', icon: Icons.first_page, pageType: 'first'),
    PreviewCapsule(index: 1, label: 'Milieu', icon: Icons.menu_book, pageType: 'middle'),
    PreviewCapsule(index: 2, label: 'Fin', icon: Icons.last_page, pageType: 'last'),
  ];

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    _checkAccessAndInitialize();
    _incrementViews();
    _checkUserReaction();
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _initializeDownloader();
  }

  void _initializeDownloader() async {
    if (!FlutterDownloader.initialized) {
      if (kReleaseMode) {
        await FlutterDownloader.initialize(debug: false, ignoreSsl: false);
      } else {
        await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
      }
    }
    _port = ReceivePort();
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      String taskId = data[0];
      DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
      if (taskId == _currentDownloadTaskId) {
        if (status == DownloadTaskStatus.complete) {
          setState(() => _isDownloading = false);
          _showDownloadSuccessModal();
        } else if (status == DownloadTaskStatus.failed) {
          setState(() => _isDownloading = false);
          _showDownloadError();
        }
      }
    });
    FlutterDownloader.registerCallback(downloadCallback);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  Future<void> _checkAccessAndInitialize() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);

    final hasPurchased = contentProvider.userPurchases.any((p) => p.contentId == widget.content.id);
    final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
        userProvider.loginUserData?.id == widget.content.ownerId;
    final isSeries = widget.content.isSeries;
    final isFree = isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree;

    if (hasPurchased || isAdminOrOwner || isFree) {
      setState(() => _isPreviewMode = false);
    } else {
      setState(() => _isPreviewMode = true);
      await _prepareCapsules();
    }
  }

  Future<File> _getCachedPdfFile(String url) async {
    final dir = await getTemporaryDirectory();
    final fileName = url.hashCode.toString() + '.pdf';
    return File('${dir.path}/$fileName');
  }

  Future<void> _prepareCapsules() async {
    String? pdfUrl = widget.content.isSeries && _currentEpisode != null
        ? _currentEpisode!.pdfUrl
        : widget.content.pdfUrl;
    if (pdfUrl == null || pdfUrl.isEmpty) return;

    setState(() {
      _isDownloadingPdf = true;
      _downloadProgress = 0.0;
    });

    try {
      final cacheFile = await _getCachedPdfFile(pdfUrl);
      if (!await cacheFile.exists()) {
        final uri = Uri.parse(pdfUrl);
        final request = await http.Client().send(http.Request('GET', uri));
        final contentLength = request.contentLength;
        final sink = cacheFile.openWrite();
        int received = 0;
        await request.stream.listen((chunk) {
          sink.add(chunk);
          received += chunk.length;
          if (contentLength != null) {
            setState(() => _downloadProgress = received / contentLength);
          }
        }).asFuture();
        await sink.close();
      }

      final bytes = await cacheFile.readAsBytes();
      final docFuture = PdfDocument.openData(bytes);
      final doc = await docFuture;
      final totalPages = doc.pagesCount;

      final startPage = 1;
      final middlePage = (totalPages / 2).ceil();
      final endPage = totalPages;

      _capsuleControllerStart = PdfControllerPinch(document: docFuture, initialPage: startPage);
      _capsuleControllerMiddle = PdfControllerPinch(document: docFuture, initialPage: middlePage);
      _capsuleControllerEnd = PdfControllerPinch(document: docFuture, initialPage: endPage);

      await Future.wait([
        _waitForControllerReady(_capsuleControllerStart!),
        _waitForControllerReady(_capsuleControllerMiddle!),
        _waitForControllerReady(_capsuleControllerEnd!),
      ]);

      if (mounted) {
        setState(() {
          _isCapsuleStartReady = true;
          _isCapsuleMiddleReady = true;
          _isCapsuleEndReady = true;
          _capsuleTotalPages = totalPages;
          _isDownloadingPdf = false;
        });
      }
    } catch (e) {
      printVm('Erreur préparation capsules: $e');
      setState(() => _isDownloadingPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement aperçu'), backgroundColor: _colors.danger),
      );
    }
  }

  Future<void> _waitForControllerReady(PdfControllerPinch controller) async {
    int attempts = 0;
    while (controller.pagesCount == null && attempts < 30) {
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
    }
  }

  void _playCapsule(int index) {
    if (!_isPreviewMode) return;

    PdfControllerPinch? selected;
    switch (index) {
      case 0:
        if (!_isCapsuleStartReady) return;
        selected = _capsuleControllerStart;
        break;
      case 1:
        if (!_isCapsuleMiddleReady) return;
        selected = _capsuleControllerMiddle;
        break;
      case 2:
        if (!_isCapsuleEndReady) return;
        selected = _capsuleControllerEnd;
        break;
    }
    if (selected == null) return;

    _stopCapsule();
    _activeCapsuleController = selected;

    setState(() {
      _isCapsulePlaying = true;
      _currentCapsuleIndex = index;
    });

    _capsuleTimer = Timer(Duration(seconds: _capsuleDurationSeconds), () {
      _stopCapsuleAndShowModal();
    });
  }

  void _stopCapsule() {
    _capsuleTimer?.cancel();
    setState(() {
      _isCapsulePlaying = false;
      _currentCapsuleIndex = -1;
      _activeCapsuleController = null;
    });
  }

  void _stopCapsuleAndShowModal() {
    _stopCapsule();
    _showPurchaseIncentiveModal();
  }

  void _showPurchaseIncentiveModal() {
    final selectedCapsule = _capsules.firstWhere((c) => c.index == _currentCapsuleIndex, orElse: () => _capsules[0]);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _colors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _colors.accent, width: 2),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book, color: _colors.accent, size: 60),
              SizedBox(height: 16),
              Text('✨ Extrait visionné ! ✨', style: TextStyle(color: _colors.accent, fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Vous avez vu la page "${selectedCapsule.label}" pendant $_capsuleDurationSeconds secondes.', style: TextStyle(color: _colors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
              SizedBox(height: 20),
              Text('Convaincu ? Débloquez l\'intégralité de cet ebook !', style: TextStyle(color: _colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text('💰 ${widget.content.price.toInt()} FCFA seulement', style: TextStyle(color: _colors.accent, fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Votre soutien permet aux auteurs de créer plus de contenu', style: TextStyle(color: _colors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: _colors.textPrimary, side: BorderSide(color: _colors.border)),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Plus tard'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(foregroundColor: _colors.background, backgroundColor: _colors.accent),
                      onPressed: _isPurchasing ? null : () { Navigator.pop(context); _handlePurchase(); },
                      child: _isPurchasing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('ACHETER', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== GESTION DES INTERACTIONS ====================
  void _checkUserReaction() async {
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final currentUserId = userProvider.loginUserData?.id;
    if (currentUserId == null) return;
    try {
      bool isLiked = false;
      bool isDisliked = false;
      if (widget.content.isSeries && _currentEpisode != null) {
        isLiked = await contentProvider.isEpisodeLikedByUser(_currentEpisode!.id!, currentUserId);
        isDisliked = await contentProvider.isEpisodeDislikedByUser(_currentEpisode!.id!, currentUserId);
      } else {
        isLiked = await contentProvider.isContentLikedByUser(widget.content.id!, currentUserId);
        isDisliked = await contentProvider.isContentDislikedByUser(widget.content.id!, currentUserId);
      }
      setState(() {
        _isLiked = isLiked;
        _isDisliked = isDisliked;
      });
    } catch (e) { printVm('Error checking user reaction: $e'); }
  }

  void _handleLike() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = userProvider.loginUserData?.id;
    if (currentUserId == null) return;
    setState(() {
      if (_isDisliked) _isDisliked = false;
      _isLiked = !_isLiked;
      _showLikeAnimation = _isLiked;
    });
    if (_isLiked) {
      _likeAnimationController.reset();
      _likeAnimationController.forward();
      _triggerLikeAnimation();
    }
    if (widget.content.isSeries && _currentEpisode != null) {
      if (_isLiked) await contentProvider.likeEpisode(_currentEpisode!.id!, currentUserId);
      else await contentProvider.removeLikeEpisode(_currentEpisode!.id!, currentUserId);
    } else {
      if (_isLiked) await contentProvider.likeContent(widget.content.id!, currentUserId);
      else await contentProvider.removeLikeContent(widget.content.id!, currentUserId);
    }
    if (widget.content.isSeries && _currentEpisode != null) await contentProvider.loadEpisodes();
  }

  void _handleDislike() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = userProvider.loginUserData?.id;
    if (currentUserId == null) return;
    setState(() {
      if (_isLiked) _isLiked = false;
      _isDisliked = !_isDisliked;
      _showDislikeAnimation = _isDisliked;
    });
    if (_isDisliked) {
      _likeAnimationController.reset();
      _likeAnimationController.forward();
      _triggerDislikeAnimation();
    }
    if (widget.content.isSeries && _currentEpisode != null) {
      if (_isDisliked) await contentProvider.dislikeEpisode(_currentEpisode!.id!, currentUserId);
      else await contentProvider.removeDislikeEpisode(_currentEpisode!.id!, currentUserId);
    } else {
      if (_isDisliked) await contentProvider.dislikeContent(widget.content.id!, currentUserId);
      else await contentProvider.removeDislikeContent(widget.content.id!, currentUserId);
    }
    if (widget.content.isSeries && _currentEpisode != null) await contentProvider.loadEpisodes();
  }

  void _triggerLikeAnimation() => Future.delayed(Duration(milliseconds: 1000), () => setState(() => _showLikeAnimation = false));
  void _triggerDislikeAnimation() => Future.delayed(Duration(milliseconds: 1000), () => setState(() => _showDislikeAnimation = false));

  void _incrementViews() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    if (widget.content.isSeries && _currentEpisode != null)
      await contentProvider.incrementViews(_currentEpisode!.id!, isEpisode: true);
    else
      await contentProvider.incrementViews(widget.content.id!);
  }

  bool _isSharing = false;
  void _handleShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final contentProvider = Provider.of<ContentProvider>(context, listen: false);
      final _appLinkService = AppLinkService();
      String shareMessage = widget.content.isSeries && _currentEpisode != null ? _currentEpisode!.description : widget.content.description!;
      String? shareMediaUrl = widget.content.isSeries && _currentEpisode != null ? _currentEpisode!.thumbnailUrl : widget.content.thumbnailUrl;
      _appLinkService.shareContent(type: AppLinkType.contentpaie, id: widget.content.id!, message: shareMessage, mediaUrl: shareMediaUrl ?? "");
      if (widget.content.isSeries && _currentEpisode != null)
        contentProvider.incrementShares(_currentEpisode!.id!, isEpisode: true);
      else
        contentProvider.incrementShares(widget.content.id!);
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) { printVm('Erreur partage: $e'); }
    finally { if (mounted) setState(() => _isSharing = false); }
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _colors.danger),
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression réussie !'), backgroundColor: _colors.primary));
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la suppression.'), backgroundColor: Colors.red));
              }
            },
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isPurchasing = true);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final result = await contentProvider.purchaseContentPaie(userProvider.loginUserData!, widget.content, context);
    setState(() => _isPurchasing = false);
    if (result == PurchaseResult.success) {
      contentProvider.loadUserPurchases();
      setState(() => _isPreviewMode = false);
      _showSuccessModal();
    } else if (result == PurchaseResult.alreadyPurchased) {
      _showAlreadyPurchasedModal();
      setState(() => _isPreviewMode = false);
    }
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: _colors.background, borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: _colors.primary, size: 60),
              SizedBox(height: 20),
              Text('Achat Réussi!', style: TextStyle(color: _colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('L\'ebook a été débloqué avec succès.', style: TextStyle(color: _colors.textSecondary, fontSize: 16), textAlign: TextAlign.center),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: _colors.primary),
                onPressed: () { Navigator.pop(context); setState(() {}); },
                child: Text('Lire maintenant'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlreadyPurchasedModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: _colors.background, borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: _colors.accent, size: 60),
              SizedBox(height: 20),
              Text('Déjà Acheté', style: TextStyle(color: _colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Vous avez déjà acheté cet ebook.', style: TextStyle(color: _colors.textSecondary, fontSize: 16), textAlign: TextAlign.center),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: _colors.accent),
                onPressed: () {
                  Navigator.pop(context);
                  final contentProvider = Provider.of<ContentProvider>(context, listen: false);
                  setState(() => contentProvider.loadUserPurchases());
                },
                child: Text('Actualiser'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReadingOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Options de lecture', style: TextStyle(color: _colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.visibility, color: _colors.primary),
              title: Text('Lire en ligne', style: TextStyle(color: _colors.textPrimary)),
              subtitle: Text('Lire directement dans l\'application', style: TextStyle(color: _colors.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                _openFullPdfViewer();
              },
            ),
            ListTile(
              leading: Icon(Icons.download, color: _colors.accent),
              title: Text('Télécharger', style: TextStyle(color: _colors.textPrimary)),
              subtitle: Text('Télécharger l\'ebook sur votre appareil', style: TextStyle(color: _colors.textSecondary)),
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

  Future<void> _downloadEbook() async {
    try {
      final pdfUrl = widget.content.isSeries && _currentEpisode != null ? _currentEpisode!.pdfUrl : widget.content.pdfUrl;
      if (pdfUrl == null || pdfUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aucun ebook disponible'), backgroundColor: Colors.red));
        return;
      }

      if (!FlutterDownloader.initialized) {
        await FlutterDownloader.initialize(debug: !kReleaseMode, ignoreSsl: !kReleaseMode);
      }

      // Permission storage
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        if (sdkInt >= 33) {
          final photos = await Permission.photos.request();
          final videos = await Permission.videos.request();
          if (!photos.isGranted && !videos.isGranted) {
            await openAppSettings();
            return;
          }
        } else {
          final storage = await Permission.storage.request();
          if (!storage.isGranted) {
            await openAppSettings();
            return;
          }
        }
      } else {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          await openAppSettings();
          return;
        }
      }

      String downloadPath;
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        downloadPath = '${directory?.path}/Download';
        await Directory(downloadPath).create(recursive: true);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        downloadPath = directory.path;
      }
      _downloadPath = downloadPath;

      final fileName = '${widget.content.title?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'ebook'}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      setState(() => _isDownloading = true);
      final taskId = await FlutterDownloader.enqueue(
        url: pdfUrl,
        savedDir: downloadPath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
      );
      if (taskId != null) {
        _currentDownloadTaskId = taskId;
        _showDownloadStartModal();
      } else {
        setState(() => _isDownloading = false);
        _showDownloadError();
      }
    } catch (e) {
      printVm('Erreur téléchargement: $e');
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur téléchargement'), backgroundColor: Colors.red));
    }
  }

  void _showDownloadStartModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: _colors.background, borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _colors.primary),
              SizedBox(height: 20),
              Text('Téléchargement en cours', style: TextStyle(color: _colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Votre ebook est en cours de téléchargement...', style: TextStyle(color: _colors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadSuccessModal() {
    Navigator.of(context, rootNavigator: true).pop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: _colors.background, borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: _colors.primary, size: 60),
              SizedBox(height: 20),
              Text('Téléchargement Réussi!', style: TextStyle(color: _colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Votre ebook a été téléchargé avec succès.', style: TextStyle(color: _colors.textSecondary, fontSize: 16), textAlign: TextAlign.center),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Fermer'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_currentDownloadTaskId != null) {
                        await FlutterDownloader.open(taskId: _currentDownloadTaskId!);
                      }
                      Navigator.pop(context);
                    },
                    child: Text('Ouvrir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadError() {
    Navigator.of(context, rootNavigator: true).pop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: _colors.background, borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: _colors.danger, size: 60),
              SizedBox(height: 20),
              Text('Échec du Téléchargement', style: TextStyle(color: _colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Une erreur est survenue.', style: TextStyle(color: _colors.textSecondary, fontSize: 16), textAlign: TextAlign.center),
              SizedBox(height: 24),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('Fermer')),
            ],
          ),
        ),
      ),
    );
  }

  // Gestion du PDF complet (après achat)
  Future<void> _initializeFullPdf() async {
    String? pdfUrl = widget.content.isSeries && _currentEpisode != null ? _currentEpisode!.pdfUrl : widget.content.pdfUrl;
    if (pdfUrl == null || pdfUrl.isEmpty) return;
    try {
      setState(() => _isLoadingPdf = true);
      final bytes = await _loadPdfData(pdfUrl);
      _pdfController = PdfControllerPinch(document: PdfDocument.openData(bytes), initialPage: 1);
      _pdfController!.addListener(() {
        if (_pdfController!.page != null) {
          setState(() {
            _currentPage = _pdfController!.page!;
            _totalPages = _pdfController!.pagesCount ?? 0;
          });
        }
      });
      setState(() {
        _isFullPdfReady = true;
        _isLoadingPdf = false;
      });
    } catch (e) {
      printVm('Erreur initialisation PDF complet: $e');
      setState(() => _isLoadingPdf = false);
    }
  }

  Future<Uint8List> _loadPdfData(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('Failed to load PDF: ${response.statusCode}');
  }

  void _openFullPdfViewer() async {
    if (!_isFullPdfReady) await _initializeFullPdf();
    if (_isFullPdfReady) setState(() => _showPdfViewer = true);
  }

  Widget _buildCapsulesSection() {
    if (!_isPreviewMode) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _colors.background.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.visibility, color: _colors.accent, size: 18),
            SizedBox(width: 8),
            Text('🔍 Aperçu gratuit (5 secondes par extrait)', style: TextStyle(color: _colors.accent, fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: 12),
          Text('Cliquez sur un extrait pour voir une page de l\'ebook', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
          SizedBox(height: 12),
          if (_isDownloadingPdf)
            Column(
              children: [
                LinearProgressIndicator(value: _downloadProgress, color: _colors.primary),
                SizedBox(height: 8),
                Text('Téléchargement de l\'aperçu... ${(_downloadProgress * 100).toStringAsFixed(0)}%', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _capsules.map((capsule) {
                bool isReady = false;
                switch (capsule.index) {
                  case 0: isReady = _isCapsuleStartReady; break;
                  case 1: isReady = _isCapsuleMiddleReady; break;
                  case 2: isReady = _isCapsuleEndReady; break;
                }
                bool isLoading = _currentCapsuleIndex == capsule.index && _isCapsulePlaying;
                return Expanded(
                  child: GestureDetector(
                    onTap: (isReady && !isLoading) ? () => _playCapsule(capsule.index) : null,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isLoading ? LinearGradient(colors: [_colors.primary, _colors.primary.withOpacity(0.7)]) : null,
                        color: !isReady ? _colors.surfaceVariant : (isLoading ? null : _colors.background.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isLoading ? _colors.primary : (isReady ? _colors.accent.withOpacity(0.5) : _colors.border), width: 1),
                      ),
                      child: !isReady
                          ? Column(children: [SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _colors.accent, strokeWidth: 2)), SizedBox(height: 8), Text('Chargement...', style: TextStyle(color: _colors.accent, fontSize: 11))])
                          : isLoading
                          ? Column(children: [SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _colors.accent, strokeWidth: 2)), SizedBox(height: 8), Text('Lecture...', style: TextStyle(color: _colors.accent, fontSize: 11))])
                          : Column(children: [Icon(capsule.icon, color: _colors.accent, size: 28), SizedBox(height: 8), Text(capsule.label, style: TextStyle(color: _colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)), SizedBox(height: 4), Text('5 sec', style: TextStyle(color: _colors.textSecondary, fontSize: 10))]),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAdMrec({required String key}) {
    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(vertical: 16),
      child: MrecAdWidget(key: ValueKey(key), onAdLoaded: () => printVm('✅ Native Ad Afrolook chargée: $key')),
    );
  }

  Widget _buildSeriesInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.content.title!, style: TextStyle(color: _colors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Série Ebook', style: TextStyle(color: _colors.accent, fontSize: 16, fontWeight: FontWeight.w500)),
        SizedBox(height: 16),
        if (_currentEpisode != null) ...[
          Text('Épisode: ${_currentEpisode!.title}', style: TextStyle(color: _colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Épisode ${_currentEpisode!.episodeNumber}', style: TextStyle(color: _colors.textSecondary, fontSize: 14)),
        ],
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSimpleContentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.content.title!, style: TextStyle(color: _colors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildStatButton(IconData icon, VoidCallback? onTap, int count, bool isLoading, {bool isActive = false, Color? activeColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: _colors.background.withOpacity(0.5), shape: BoxShape.circle),
            child: isLoading ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _colors.accent, strokeWidth: 2)) : Icon(icon, color: isActive ? (activeColor ?? _colors.primary) : _colors.textPrimary, size: 24),
          ),
        ),
        SizedBox(height: 1),
        Text('$count', style: TextStyle(color: isActive ? (activeColor ?? _colors.primary) : _colors.textPrimary, fontSize: 12)),
      ],
    );
  }

  Widget _buildPdfViewer() {
    if (_isLoadingPdf) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: _colors.primary), SizedBox(height: 16), Text('Chargement du PDF...', style: TextStyle(color: _colors.textPrimary))]));
    if (!_isFullPdfReady || _pdfController == null) return Center(child: Text('Erreur de chargement du PDF', style: TextStyle(color: _colors.textPrimary)));
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: Icon(Icons.arrow_back_ios, color: _colors.textPrimary), onPressed: _currentPage > 1 ? () => _pdfController!.previousPage(curve: Curves.easeInOut, duration: Duration(milliseconds: 300)) : null),
              PdfPageNumber(controller: _pdfController!, builder: (_, __, page, pagesCount) => Container(alignment: Alignment.center, child: Text('${page ?? 0}/${pagesCount ?? 0}', style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)))),
              IconButton(icon: Icon(Icons.arrow_forward_ios, color: _colors.textPrimary), onPressed: _currentPage < _totalPages ? () => _pdfController!.nextPage(curve: Curves.easeInOut, duration: Duration(milliseconds: 300)) : null),
            ],
          ),
        ),
        Expanded(
          child: PdfViewPinch(
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => Center(child: CircularProgressIndicator(color: _colors.primary)),
              pageLoaderBuilder: (_) => Center(child: CircularProgressIndicator(color: _colors.primary)),
              errorBuilder: (_, error) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, color: _colors.danger, size: 60), SizedBox(height: 16), Text('Erreur: $error', style: TextStyle(color: _colors.textPrimary))])),
            ),
            controller: _pdfController!,
          ),
        ),
        Container(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(foregroundColor: _colors.background, backgroundColor: _colors.primary, padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
            onPressed: () => setState(() => _showPdfViewer = false),
            child: Text('Retour aux détails'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _capsuleTimer?.cancel();
    _pdfController?.dispose();
    _capsuleControllerStart?.dispose();
    _capsuleControllerMiddle?.dispose();
    _capsuleControllerEnd?.dispose();
    _likeAnimationController.dispose();
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    _port.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
        userProvider.loginUserData?.id == widget.content.ownerId;
    final hasPurchased = contentProvider.userPurchases.any((p) => p.contentId == widget.content.id);
    final isSeries = widget.content.isSeries;
    bool canRead = (isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree) || hasPurchased || isAdminOrOwner;

    String thumbnailUrl = userProvider.convertToCdnUrl(
      isSeries && _currentEpisode != null ? _currentEpisode!.thumbnailUrl! : widget.content.thumbnailUrl ?? '',
      userProvider.appDefaultData,
    );

    if (_showPdfViewer) {
      return Scaffold(
        backgroundColor: _colors.background,
        appBar: AppBar(backgroundColor: _colors.background, leading: IconButton(icon: Icon(Icons.arrow_back, color: _colors.textPrimary), onPressed: () => setState(() => _showPdfViewer = false)), title: Text('Lecture de l\'ebook', style: TextStyle(color: _colors.textPrimary))),
        body: _buildPdfViewer(),
      );
    }

    return Scaffold(
      backgroundColor: _colors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                floating: false,
                pinned: true,
                backgroundColor: _colors.background,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => Container(color: _colors.surfaceVariant),
                        errorWidget: (_, __, ___) => Container(color: _colors.surfaceVariant, child: Icon(Icons.book, color: _colors.textSecondary, size: 60)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [_colors.background.withOpacity(0.9), _colors.background.withOpacity(0.3), Colors.transparent],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      if (!canRead && !isAdminOrOwner && _isPreviewMode)
                        Positioned.fill(
                          child: Container(
                            color: _colors.background.withOpacity(0.85),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline, size: 60, color: _colors.textPrimary),
                                  SizedBox(height: 16),
                                  Text('Ebook premium', style: TextStyle(color: _colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 8),
                                  Text('Débloquez cet ebook pour le lire', style: TextStyle(color: _colors.textSecondary, fontSize: 16)),
                                  SizedBox(height: 8),
                                  Text('Utilisez les aperçus ci-dessous pour juger de la qualité', style: TextStyle(color: _colors.textSecondary, fontSize: 14, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (isAdminOrOwner)
                        Positioned.fill(
                          child: Container(
                            color: _colors.background.withOpacity(0.5),
                            child: Center(
                              child: Text('Vous pouvez lire cet ebook gratuitement (Admin/Propriétaire)', style: TextStyle(color: _colors.textSecondary, fontSize: 16, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                      if (_isPreviewMode && _isCapsulePlaying && _activeCapsuleController != null)
                        Positioned.fill(
                          child: Container(
                            color: _colors.background,
                            child: PdfViewPinch(
                              builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                                options: DefaultBuilderOptions(),
                                documentLoaderBuilder: (_) => Center(child: CircularProgressIndicator(color: _colors.primary)),
                                pageLoaderBuilder: (_) => Center(child: CircularProgressIndicator(color: _colors.primary)),
                              ),
                              controller: _activeCapsuleController!,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                leading: IconButton(icon: Icon(Icons.arrow_back, color: _colors.textPrimary), onPressed: () => Navigator.pop(context)),
                actions: [
                  if (isAdminOrOwner) IconButton(icon: Icon(Icons.delete_outline, color: _colors.danger), onPressed: _showDeleteModal),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      widget.content.isSeries ? _buildSeriesInfo() : _buildSimpleContentInfo(),
                      SizedBox(height: 5),
                      _buildAdMrec(key: 'ad_native_content_details'),
                      SizedBox(height: 5),
                      ContentOwnerInfo(ownerId: widget.content.ownerId),
                      // Ligne des stats
                      Row(
                        children: [
                          _buildStatButton(Icons.share, _isSharing ? null : _handleShare, widget.content.shares, _isSharing),
                          _buildStatButton(Icons.thumb_down, _handleDislike, widget.content.dislikes, false, isActive: _isDisliked, activeColor: _colors.info),
                          _buildStatButton(Icons.favorite, _handleLike, widget.content.likes, false, isActive: _isLiked, activeColor: _colors.danger),
                          _buildStatButton(Icons.visibility, null, widget.content.views, false),
                          Spacer(),
                          if (!widget.content.isFree && (!widget.content.isSeries || (widget.content.isSeries && _currentEpisode != null && !_currentEpisode!.isFree)))
                            Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _colors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: _colors.accent)), child: Text('PREMIUM', style: TextStyle(color: _colors.accent, fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      SizedBox(height: 20),
                      // SECTION CAPSULES (uniquement pour non-acheteurs)
                      _buildCapsulesSection(),
                      SizedBox(height: 10),
                      Text(widget.content.description ?? '', style: TextStyle(color: _colors.textSecondary, fontSize: 16, height: 1.5)),
                      SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _colors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _colors.primary.withOpacity(0.3))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [Icon(Icons.favorite, color: _colors.primary, size: 16), SizedBox(width: 8), Text('Soutenez les auteurs', style: TextStyle(color: _colors.primary, fontSize: 16, fontWeight: FontWeight.bold))]),
                            SizedBox(height: 8),
                            Text('En achetant cet ebook, vous soutenez directement les auteurs et leur permettez de créer plus de contenu de qualité.', style: TextStyle(color: _colors.textSecondary, fontSize: 14)),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      if (!canRead && _isPreviewMode)
                        Container(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(foregroundColor: _colors.background, backgroundColor: _colors.accent, padding: EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            onPressed: _isPurchasing ? null : _handlePurchase,
                            child: _isPurchasing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _colors.background, strokeWidth: 2)) : Text('SOUTENIR LES AUTEURS - ${widget.content.price} F', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        )
                      else if (canRead)
                        Column(
                          children: [
                            Container(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(foregroundColor: _colors.textPrimary, backgroundColor: _colors.primary, padding: EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                onPressed: _showReadingOptions,
                                child: Text('LIRE L\'EBOOK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            SizedBox(height: 12),
                            if (canRead)
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: _colors.accent, side: BorderSide(color: _colors.accent), padding: EdgeInsets.symmetric(vertical: 16)),
                                onPressed: _downloadEbook,
                                child: Text('TÉLÉCHARGER L\'EBOOK', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      SizedBox(height: 20),
                      if (widget.content.hashtags != null && widget.content.hashtags!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tags:', style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: widget.content.hashtags!.map((hashtag) => Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _colors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: _colors.primary)), child: Text('#$hashtag', style: TextStyle(color: _colors.primary)))).toList(),
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
          if (_showLikeAnimation)
            Positioned.fill(
              child: Center(
                child: IgnorePointer(
                  child: AnimatedScale(
                    scale: _isLikedAnimation ? 1.5 : 1.0,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Icon(Icons.favorite, color: _colors.danger, size: 100),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PreviewCapsule {
  final int index;
  final String label;
  final IconData icon;
  final String pageType;
  PreviewCapsule({required this.index, required this.label, required this.icon, required this.pageType});
}

enum PurchaseResult { success, insufficientBalance, alreadyPurchased, error }
//
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
//   // NOUVEAUX: Variables pour le système de like/dislike
//   bool _isDisliked = false;
//   bool _showDislikeAnimation = false;
//
//   // Variables pour le téléchargement
//   bool _isDownloading = false;
//   String? _currentDownloadTaskId;
//   ReceivePort _port = ReceivePort();
//   String _downloadPath = '';
//
//   @override
//   void initState() {
//     super.initState();
//     _currentEpisode = widget.episode;
//     _incrementViews();
//     // NOUVEAU: Vérifier l'état des réactions de l'utilisateur
//     _checkUserReaction();
//     _likeAnimationController = AnimationController(
//       vsync: this,
//       duration: Duration(milliseconds: 1500),
//     );
//
//     // Initialiser la communication entre isolates pour le téléchargement
//     _initializeDownloader();
//   }
//   Widget _buildAdMrec({required String key}) {
//     // return SizedBox.shrink();
//
//     return Container(
//       key: ValueKey(key),
//       margin: EdgeInsets.symmetric(vertical: 16),
//       decoration: BoxDecoration(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.transparent),
//       ),
//       child: MrecAdWidget(
//         key: ValueKey(key),
//         // templateType: TemplateType.medium, // ou TemplateType.small
//
//         onAdLoaded: () {
//           printVm('✅ Native Ad Afrolook chargée: $key');
//         },
//       ),
//       // child: BannerAdWidget(
//       //   onAdLoaded: () {
//       //     printVm('✅ Bannière Afrolook chargée: $key');
//       //   },
//       // ),
//     );
//   }
//
// // NOUVEAU: Méthode pour vérifier les réactions de l'utilisateur
//   void _checkUserReaction() async {
//     final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//     final currentUserId = userProvider.loginUserData?.id;
//
//     if (currentUserId == null) return;
//
//     try {
//       bool isLiked = false;
//       bool isDisliked = false;
//
//       if (widget.content.isSeries && _currentEpisode != null) {
//         isLiked = await contentProvider.isEpisodeLikedByUser(
//             _currentEpisode!.id!, currentUserId);
//         isDisliked = await contentProvider.isEpisodeDislikedByUser(
//             _currentEpisode!.id!, currentUserId);
//       } else {
//         isLiked = await contentProvider.isContentLikedByUser(
//             widget.content.id!, currentUserId);
//         isDisliked = await contentProvider.isContentDislikedByUser(
//             widget.content.id!, currentUserId);
//       }
//
//       setState(() {
//         _isLiked = isLiked;
//         _isDisliked = isDisliked;
//       });
//     } catch (e) {
//       printVm('Error checking user reaction: $e');
//     }
//   }
//
//   // MODIFIÉ: Nouvelle méthode pour gérer les likes
//   void _handleLike() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//     final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final currentUserId = userProvider.loginUserData?.id;
//
//     if (currentUserId == null) return;
//
//     setState(() {
//       if (_isDisliked) {
//         _isDisliked = false;
//       }
//       _isLiked = !_isLiked;
//       _showLikeAnimation = _isLiked;
//     });
//
//     if (_isLiked) {
//       _likeAnimationController.reset();
//       _likeAnimationController.forward();
//       _triggerLikeAnimation();
//     }
//
//     // Gérer le like/dislike dans Firestore
//     if (widget.content.isSeries && _currentEpisode != null) {
//       if (_isLiked) {
//         await contentProvider.likeEpisode(
//             _currentEpisode!.id!, currentUserId);
//       } else {
//         await contentProvider.removeLikeEpisode(
//             _currentEpisode!.id!, currentUserId);
//       }
//     } else {
//       if (_isLiked) {
//         await contentProvider.likeContent(
//             widget.content.id!, currentUserId);
//       } else {
//         await contentProvider.removeLikeContent(
//             widget.content.id!, currentUserId);
//       }
//     }
//
//     // Recharger les données si c'est une série
//     if (widget.content.isSeries && _currentEpisode != null) {
//       await contentProvider.loadEpisodes();
//     }
//   }
//   void _initializeDownloader() async {
//     // Vérifier si le plugin est initialisé
//     if (!FlutterDownloader.initialized) {
//       if (kReleaseMode) {
//         await FlutterDownloader.initialize(
//           debug: false,
//           ignoreSsl: false,
//         );      } else {
//         await FlutterDownloader.initialize(
//           debug: true,
//           ignoreSsl: true,
//         );      }
//
//     }
//  _port = ReceivePort();
//
//     // Enregistrer le port pour la communication entre isolates
//     IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
//     _port.listen((dynamic data) {
//       printVm("listen data start");
//       printVm("listen data start : ${data}");
//
//       String taskId = data[0];
//       DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
//       int progress = data[2];
//
//       printVm("listen DownloadTaskStatus : ${DownloadTaskStatus}");
//
//       if (taskId == _currentDownloadTaskId) {
//         if (status == DownloadTaskStatus.complete) {
//           setState(() {
//             _isDownloading = false;
//           });
//           _showDownloadSuccessModal();
//         } else if (status == DownloadTaskStatus.failed) {
//           setState(() {
//             _isDownloading = false;
//           });
//           _showDownloadError();
//         }
//         // On ignore la progression pour ne pas l'afficher
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
//
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
//             style: ElevatedButton.styleFrom(backgroundColor: _colors.danger),
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
//         printVm('Erreur initialisation PDF: $e');
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
// // NOUVEAU: Méthode pour gérer les dislikes
//   void _handleDislike() async {
//     final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//     final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final currentUserId = userProvider.loginUserData?.id;
//
//     if (currentUserId == null) return;
//
//     setState(() {
//       if (_isLiked) {
//         _isLiked = false;
//       }
//       _isDisliked = !_isDisliked;
//       _showDislikeAnimation = _isDisliked;
//     });
//
//     if (_isDisliked) {
//       _likeAnimationController.reset();
//       _likeAnimationController.forward();
//       _triggerDislikeAnimation();
//     }
//
//     // Gérer le dislike dans Firestore
//     if (widget.content.isSeries && _currentEpisode != null) {
//       if (_isDisliked) {
//         await contentProvider.dislikeEpisode(
//             _currentEpisode!.id!, currentUserId);
//       } else {
//         await contentProvider.removeDislikeEpisode(
//             _currentEpisode!.id!, currentUserId);
//       }
//     } else {
//       if (_isDisliked) {
//         await contentProvider.dislikeContent(
//             widget.content.id!, currentUserId);
//       } else {
//         await contentProvider.removeDislikeContent(
//             widget.content.id!, currentUserId);
//       }
//     }
//
//     // Recharger les données si c'est une série
//     if (widget.content.isSeries && _currentEpisode != null) {
//       await contentProvider.loadEpisodes();
//     }
//   }
//
// // NOUVEAU: Animation pour le dislike
//   void _triggerDislikeAnimation() {
//     Future.delayed(Duration(milliseconds: 1000), () {
//       setState(() {
//         _showDislikeAnimation = false;
//       });
//     });
//   }
//
//   // MODIFIÉ: Méthode pour partager avec compteur
// // Dans votre State, ajoutez cette variable
//   bool _isSharing = false;
//
// // Modifiez votre fonction _handleShare
//   void _handleShare() async {
//     // Éviter les doubles clics
//     if (_isSharing) return;
//
//     setState(() {
//       _isSharing = true;
//     });
//
//     try {
//       final contentProvider = Provider.of<ContentProvider>(context, listen: false);
//       final _appLinkService = AppLinkService();
//
//       // Préparer le message de partage
//       String shareMessage;
//       String? shareMediaUrl;
//
//       if (widget.content.isSeries && _currentEpisode != null) {
//         shareMessage = "${_currentEpisode!.description}";
//         shareMediaUrl = _currentEpisode!.thumbnailUrl?.isNotEmpty == true
//             ? "${_currentEpisode!.thumbnailUrl!}"
//             : "";
//       } else {
//         shareMessage = "${widget.content.description}";
//         shareMediaUrl = widget.content.thumbnailUrl?.isNotEmpty == true
//             ? "${widget.content.thumbnailUrl!}"
//             : "";
//       }
//
//       // Lancer le partage (ne pas attendre le retour utilisateur)
//       _appLinkService.shareContent(
//         type: AppLinkType.contentpaie,
//         id: widget.content.id!,
//         message: shareMessage,
//         mediaUrl: shareMediaUrl,
//       );
//
//       // Incrémenter le compteur en arrière-plan
//       if (widget.content.isSeries && _currentEpisode != null) {
//         contentProvider.incrementShares(_currentEpisode!.id!, isEpisode: true);
//       } else {
//         contentProvider.incrementShares(widget.content.id!);
//       }
//
//       // Petit délai pour éviter un flash trop rapide
//       await Future.delayed(Duration(milliseconds: 500));
//
//     } catch (e) {
//       // Gérer l'erreur silencieusement ou afficher un message
//       printVm('Erreur lors du partage: $e');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isSharing = false;
//         });
//       }
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
//         if (kReleaseMode) {
//           await FlutterDownloader.initialize(
//             debug: false,
//             ignoreSsl: false,
//           );      } else {
//           await FlutterDownloader.initialize(
//             debug: true,
//             ignoreSsl: true,
//           );      }      }
//
//       // --- DEMANDE DE PERMISSIONS ---
//       bool permissionGranted = false;
//       if (Platform.isAndroid) {
//         final androidInfo = await DeviceInfoPlugin().androidInfo;
//         final sdkInt = androidInfo.version.sdkInt;
//
//         if (sdkInt >= 33) {
//           // Android 13 et +
//           final photos = await Permission.photos.request();
//           final videos = await Permission.videos.request();
//
//           permissionGranted = photos.isGranted || videos.isGranted;
//         } else if (sdkInt >= 30) {
//           // Android 11 et 12
//           final storage = await Permission.storage.request();
//           permissionGranted = storage.isGranted;
//         } else {
//           // Android <11
//           final storage = await Permission.storage.request();
//           permissionGranted = storage.isGranted;
//         }
//       } else {
//         // iOS
//         final status = await Permission.storage.request();
//         permissionGranted = status.isGranted;
//       }
//       // if (Platform.isAndroid) {
//       //   final androidInfo = await DeviceInfoPlugin().androidInfo;
//       //   if (androidInfo.version.sdkInt >= 33) {
//       //     // Android 13+
//       //     final status = await Permission.manageExternalStorage.request();
//       //     permissionGranted = status.isGranted;
//       //   } else if (androidInfo.version.sdkInt >= 30) {
//       //     // Android 11 et 12
//       //     final status = await Permission.manageExternalStorage.request();
//       //     permissionGranted = status.isGranted;
//       //   } else {
//       //     // Android <11
//       //     final status = await Permission.storage.request();
//       //     permissionGranted = status.isGranted;
//       //   }
//       // } else {
//       //   // iOS
//       //   final status = await Permission.storage.request();
//       //   permissionGranted = status.isGranted;
//       // }
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
//       _downloadPath = downloadPath;
//
//       final fileName = '${widget.content.title?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'ebook'}_${DateTime.now().millisecondsSinceEpoch}.pdf';
//
//       // Afficher le loading de démarrage
//       _startDownloadAndShowModals();
//
//       // --- TELECHARGEMENT ---
//       setState(() {
//         _isDownloading = true;
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
//       printVm('❌ Erreur téléchargement ebook: $e');
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
//   void _startDownloadAndShowModals() {
//     // Affiche le modal de téléchargement
//     _showDownloadStartModal();
//
//     // Simule le téléchargement ou attends la vraie fin du téléchargement
//     Future.delayed(Duration(seconds: 2), () {
//       // Ferme le modal de téléchargement avant d'ouvrir celui de succès
//       Navigator.of(context, rootNavigator: true).pop();
//
//       // Affiche le modal de succès
//       _showDownloadSuccessModal();
//     });
//   }
//
// // Modal de téléchargement en cours
//   void _showDownloadStartModal() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           child: Container(
//             decoration: BoxDecoration(
//               color: _colors.background,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 CircularProgressIndicator(
//                   color: _colors.primary,
//                   strokeWidth: 3,
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   'Téléchargement en cours',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 SizedBox(height: 12),
//                 Text(
//                   'Votre ebook est en cours de téléchargement...',
//                   style: TextStyle(
//                     color: _colors.textSecondary,
//                     fontSize: 14,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 16),
//                 Text(
//                   'Vous serez notifié lorsque le téléchargement sera terminé.',
//                   style: TextStyle(
//                     color: Colors.white60,
//                     fontSize: 12,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//   void _showDownloadSuccessModal() {
//     // Fermer d'abord le modal de chargement
//     Navigator.of(context, rootNavigator: true).pop();
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           child: Container(
//             decoration: BoxDecoration(
//               color: _colors.background,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.check_circle,
//                   color: _colors.primary,
//                   size: 60,
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   'Téléchargement Réussi!',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 SizedBox(height: 12),
//                 Text(
//                   'Votre ebook a été téléchargé avec succès.',
//                   style: TextStyle(
//                     color: _colors.textSecondary,
//                     fontSize: 16,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 16),
//                 Container(
//                   padding: EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: _colors.primary.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: _colors.primary.withOpacity(0.3)),
//                   ),
//                   child: Column(
//                     children: [
//                       Text(
//                         'Emplacement du fichier:',
//                         style: TextStyle(
//                           color: _colors.primary,
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       SizedBox(height: 8),
//                       Text(
//                         _downloadPath,
//                         style: TextStyle(
//                           color: _colors.textSecondary,
//                           fontSize: 12,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 24),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Expanded(
//                       child: OutlinedButton(
//                         style: OutlinedButton.styleFrom(
//                           foregroundColor: _colors.textPrimary,
//                           side: BorderSide(color: _colors.textPrimary),
//                           padding: EdgeInsets.symmetric(vertical: 12),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                         ),
//                         onPressed: () {
//                           Navigator.pop(context);
//                         },
//                         child: Text('Fermer'),
//                       ),
//                     ),
//                     SizedBox(width: 12),
//                     Expanded(
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           foregroundColor: _colors.background,
//                           backgroundColor: _colors.primary,
//                           padding: EdgeInsets.symmetric(vertical: 12),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                         ),
//                         onPressed: () async {
//                           if (_currentDownloadTaskId != null) {
//                             await FlutterDownloader.open(taskId: _currentDownloadTaskId!);
//                           }
//                           Navigator.pop(context);
//                         },
//                         child: Text('Ouvrir'),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void _showDownloadError() {
//     // Fermer d'abord le modal de chargement
//     Navigator.of(context, rootNavigator: true).pop();
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           child: Container(
//             decoration: BoxDecoration(
//               color: _colors.background,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.error_outline,
//                   color: Colors.red,
//                   size: 60,
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   'Échec du Téléchargement',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 SizedBox(height: 12),
//                 Text(
//                   'Une erreur est survenue lors du téléchargement de l\'ebook.',
//                   style: TextStyle(
//                     color: _colors.textSecondary,
//                     fontSize: 16,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 24),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: Colors.red,
//                     padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   onPressed: () {
//                     Navigator.pop(context);
//                   },
//                   child: Text('Fermer'),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void _showReadingOptions() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: _colors.background,
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
//                 color: _colors.textPrimary,
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 16),
//             ListTile(
//               leading: Icon(Icons.visibility, color: _colors.primary),
//               title: Text('Lire en ligne', style: TextStyle(color: _colors.textPrimary)),
//               subtitle: Text('Lire directement dans l\'application', style: TextStyle(color: _colors.textSecondary)),
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
//               leading: Icon(Icons.download, color: _colors.accent),
//               title: Text('Télécharger', style: TextStyle(color: _colors.textPrimary)),
//               subtitle: Text('Télécharger l\'ebook sur votre appareil', style: TextStyle(color: _colors.textSecondary)),
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
//               color: _colors.background,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.check_circle,
//                   color: _colors.primary,
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
//                     color: _colors.textSecondary,
//                     fontSize: 16,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 24),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: _colors.primary,
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
//               color: _colors.background,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   Icons.info_outline,
//                   color: _colors.accent,
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
//                     color: _colors.textSecondary,
//                     fontSize: 16,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 24),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: _colors.accent,
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
//             color: _colors.textPrimary,
//             fontSize: 28,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         SizedBox(height: 8),
//         Text(
//           'Série Ebook',
//           style: TextStyle(
//             color: _colors.accent,
//             fontSize: 16,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         SizedBox(height: 16),
//         if (_currentEpisode != null) ...[
//           Text(
//             'Épisode: ${_currentEpisode!.title}',
//             style: TextStyle(
//               color: _colors.textPrimary,
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Épisode ${_currentEpisode!.episodeNumber}',
//             style: TextStyle(
//               color: _colors.textSecondary,
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
//             color: _colors.textPrimary,
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
//               CircularProgressIndicator(color: _colors.primary),
//               SizedBox(height: 16),
//               Text(
//                 'Chargement du PDF...',
//                 style: TextStyle(color: _colors.textPrimary),
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
//               Icon(Icons.error_outline, color: _colors.danger, size: 60),
//               SizedBox(height: 16),
//               Text(
//                 'Erreur de chargement du PDF',
//                 style: TextStyle(color: _colors.textPrimary),
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
//           color: _colors.background,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               IconButton(
//                 icon: Icon(Icons.arrow_back_ios, color: _colors.textPrimary),
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
//                     style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
//                   ),
//                 ),
//               ),
//
//               IconButton(
//                 icon: Icon(Icons.arrow_forward_ios, color: _colors.textPrimary),
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
//                 child: CircularProgressIndicator(color: _colors.primary),
//               ),
//               pageLoaderBuilder: (_) => Center(
//                 child: CircularProgressIndicator(color: _colors.primary),
//               ),
//               errorBuilder: (_, error) => Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.error_outline, color: _colors.danger, size: 60),
//                     SizedBox(height: 16),
//                     Text(
//                       'Erreur: $error',
//                       style: TextStyle(color: _colors.textPrimary),
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
//               foregroundColor: _colors.background,
//               backgroundColor: _colors.primary,
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
//         backgroundColor: _colors.background,
//         appBar: AppBar(
//           backgroundColor: _colors.background,
//           leading: IconButton(
//             icon: Icon(Icons.arrow_back, color: _colors.textPrimary),
//             onPressed: () {
//               setState(() {
//                 _showPdfViewer = false;
//               });
//             },
//           ),
//           title: Text(
//             'Lecture de l\'ebook',
//             style: TextStyle(color: _colors.textPrimary),
//           ),
//         ),
//         body: _buildPdfViewer(),
//       );
//     }
//
//     return Scaffold(
//       backgroundColor: _colors.background,
//       body: Stack(
//         children: [
//           CustomScrollView(
//             slivers: [
//               SliverAppBar(
//                 expandedHeight: 400,
//                 floating: false,
//                 pinned: true,
//                 backgroundColor: _colors.background,
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
//                               _colors.background.withOpacity(0.9),
//                               _colors.background.withOpacity(0.3),
//                               Colors.transparent,
//                             ],
//                             stops: [0.0, 0.5, 1.0],
//                           ),
//                         ),
//                       ),
//                       if (!canRead && !isAdminOrOwner)
//                         Positioned.fill(
//                           child: Container(
//                             color: _colors.background.withOpacity(0.7),
//                             child: Center(
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.lock_outline,
//                                     size: 60,
//                                     color: _colors.textPrimary,
//                                   ),
//                                   SizedBox(height: 16),
//                                   Text(
//                                     'Ebook verrouillé',
//                                     style: TextStyle(
//                                       color: _colors.textPrimary,
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   SizedBox(height: 8),
//                                   Text(
//                                     'Débloquez cet ebook pour le lire',
//                                     style: TextStyle(
//                                       color: _colors.textSecondary,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   SizedBox(height: 8),
//                                   Text(
//                                     'Votre soutien aide les auteurs à créer plus de contenu',
//                                     style: TextStyle(
//                                       color: _colors.textSecondary,
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
//                             color: _colors.background.withOpacity(0.5),
//                             child: Center(
//                               child: Text(
//                                 'Vous pouvez lire cet ebook gratuitement (Admin/Propriétaire)',
//                                 style: TextStyle(
//                                   color: _colors.textSecondary,
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
//                   icon: Icon(Icons.arrow_back, color: _colors.textPrimary),
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
//                       SizedBox(height: 5),
//                       _buildAdMrec(key: 'ad_native_content_details'),
//                       SizedBox(height: 5),
//
//                       // Informations du propriétaire
//                       ContentOwnerInfo(ownerId: widget.content.ownerId),
//
//                       // Actions rapides
//                       Row(
//                         children: [
//                           // Bouton Partage avec compteur
// // Dans votre SliverToBoxAdapter, modifiez le bouton de partage :
//
// // Bouton Partage avec compteur et indicateur de chargement
//                           Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               GestureDetector(
//                                 onTap: _isSharing ? null : _handleShare, // Désactive le bouton pendant le partage
//                                 child: Container(
//                                   padding: EdgeInsets.all(8),
//                                   decoration: BoxDecoration(
//                                     color: _colors.background.withOpacity(0.5),
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: _isSharing
//                                       ? SizedBox(
//                                     width: 24,
//                                     height: 24,
//                                     child: CircularProgressIndicator(
//                                       color: _colors.accent,
//                                       strokeWidth: 2,
//                                     ),
//                                   )
//                                       : Icon(
//                                     Icons.share,
//                                     color: Colors.white,
//                                     size: 24,
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(height: 1),
//
//                               // Compteur des partages
//                               Consumer<ContentProvider>(
//                                 builder: (context, contentProvider, child) {
//                                   final shares = widget.content.isSeries && _currentEpisode != null
//                                       ? _currentEpisode?.shares ?? 0
//                                       : widget.content.shares;
//                                   return Text(
//                                     '$shares',
//                                     style: TextStyle(color: _colors.textPrimary, fontSize: 16),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                           SizedBox(width: 5),
//
//                           // Bouton Dislike avec compteur
//                           Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               GestureDetector(
//                                 onTap: _handleDislike,
//                                 child: Container(
//                                   padding: EdgeInsets.all(8),
//                                   decoration: BoxDecoration(
//                                     color: _colors.background.withOpacity(0.5),
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: Icon(
//                                     _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
//                                     color: _isDisliked ? Colors.blue : _colors.textPrimary,
//                                     size: 24,
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(height: 1),
//                               Consumer<ContentProvider>(
//                                 builder: (context, contentProvider, child) {
//                                   final dislikes = widget.content.isSeries && _currentEpisode != null
//                                       ? _currentEpisode?.dislikes ?? 0
//                                       : widget.content.dislikes;
//                                   return Text(
//                                     '$dislikes',
//                                     style: TextStyle(
//                                       color: _isDisliked ? Colors.blue : _colors.textPrimary,
//                                       fontSize: 12,
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                           SizedBox(width: 5),
//
//                           // Bouton Like avec compteur
//                           Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               GestureDetector(
//                                 onTap: _handleLike,
//                                 child: Container(
//                                   padding: EdgeInsets.all(8),
//                                   decoration: BoxDecoration(
//                                     color: _colors.background.withOpacity(0.5),
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: Icon(
//                                     _isLiked ? Icons.favorite : Icons.favorite_border,
//                                     color: _isLiked ? Colors.red : _colors.textPrimary,
//                                     size: 24,
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(height: 1),
//                               Consumer<ContentProvider>(
//                                 builder: (context, contentProvider, child) {
//                                   final likes = widget.content.isSeries && _currentEpisode != null
//                                       ? _currentEpisode?.likes ?? 0
//                                       : widget.content.likes;
//                                   return Text(
//                                     '$likes',
//                                     style: TextStyle(
//                                       color: _isLiked ? Colors.red : _colors.textPrimary,
//                                       fontSize: 12,
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                           SizedBox(width: 5),
//
//                           // Affichage des vues
//                           Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(Icons.visibility, color: _colors.textPrimary, size: 24),
//                               SizedBox(height: 1),
//                               Consumer<ContentProvider>(
//                                 builder: (context, contentProvider, child) {
//                                   final views = widget.content.isSeries && _currentEpisode != null
//                                       ? _currentEpisode?.views ?? 0
//                                       : widget.content.views;
//                                   return Text(
//                                     '$views',
//                                     style: TextStyle(color: _colors.textPrimary, fontSize: 12),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                           Spacer(),
//
//                           if (!widget.content.isFree && (!widget.content.isSeries ||
//                               (widget.content.isSeries && _currentEpisode != null && !_currentEpisode!.isFree)))
//                             Container(
//                               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                               decoration: BoxDecoration(
//                                 color: _colors.accent.withOpacity(0.2),
//                                 borderRadius: BorderRadius.circular(4),
//                                 border: Border.all(color: _colors.accent),
//                               ),
//                               child: Text(
//                                 'PREMIUM',
//                                 style: TextStyle(
//                                   color: _colors.accent,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//
//                       SizedBox(height: 10),
//
//                       // Description
//                       Text(
//                         widget.content.isSeries && _currentEpisode != null
//                             ? _currentEpisode!.description
//                             : widget.content.description!,
//                         style: TextStyle(
//                           color: _colors.textSecondary,
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
//                           color: _colors.primary.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: _colors.primary.withOpacity(0.3)),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               children: [
//                                 Icon(Icons.favorite, color: _colors.primary, size: 16),
//                                 SizedBox(width: 8),
//                                 Text(
//                                   'Soutenez les auteurs',
//                                   style: TextStyle(
//                                     color: _colors.primary,
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
//                                 color: _colors.textSecondary,
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
//                               foregroundColor: _colors.background,
//                               backgroundColor: _colors.accent,
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
//                                 color: _colors.background,
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
//                                   foregroundColor: _colors.textPrimary,
//                                   backgroundColor: _colors.primary,
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
//                                   foregroundColor: _colors.accent,
//                                   side: BorderSide(color: _colors.accent),
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
//                                 color: _colors.textPrimary,
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
//                                     color: _colors.primary.withOpacity(0.2),
//                                     borderRadius: BorderRadius.circular(16),
//                                     border: Border.all(color: _colors.primary),
//                                   ),
//                                   child: Text(
//                                     '#$hashtag',
//                                     style: TextStyle(color: _colors.primary),
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
//                   color: _colors.background.withOpacity(0.7),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.visibility, color: _colors.textPrimary, size: 14),
//                     SizedBox(width: 4),
//                     Text(
//                       widget.content.isSeries && _currentEpisode != null
//                           ? '${_currentEpisode!.views}'
//                           : '${widget.content.views}',
//                       style: TextStyle(color: _colors.textPrimary, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // Couleurs thématiques
// const Color _colors.background = Color(0xFF121212);
// const Color _colors.textPrimary = Color(0xFFFFFFFF);
// const Color _colors.primary = Color(0xFF00C853);
// const Color _colors.accent = Color(0xFFFFD600);