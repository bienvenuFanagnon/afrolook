// ebook_reader_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:afrotok/models/model_data.dart';

// ebook_reader_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:afrotok/models/model_data.dart';

class EbookReaderScreen extends StatefulWidget {
  final ContentPaie content;
  final Episode? episode;

  const EbookReaderScreen({
    Key? key,
    required this.content,
    this.episode,
  }) : super(key: key);

  @override
  _EbookReaderScreenState createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends State<EbookReaderScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _loadingProgress = 0;
  bool _isContentLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeWebViewController();
  }

  void _initializeWebViewController() {
    final pdfUrl = widget.content.isSeries && widget.episode != null
        ? widget.episode!.pdfUrl
        : widget.content.pdfUrl;

    print('📖 URL du PDF récupérée: $pdfUrl');

    if (pdfUrl == null || pdfUrl.isEmpty) {
      print('❌ Aucun PDF disponible');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Aucun PDF disponible pour cet ebook';
      });
      return;
    }

    // Utiliser Google Docs Viewer pour afficher le PDF
    final encodedPdfUrl = Uri.encodeComponent(pdfUrl);
    final googleDocsUrl = 'https://docs.google.com/gview?embedded=true&url=$encodedPdfUrl';
    print('🔗 URL Google Docs: $googleDocsUrl');

    // Configuration de la plateforme
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
    WebViewController.fromPlatformCreationParams(params);

    // Configuration du WebViewController
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('📊 Progression du chargement: $progress%');
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (String url) {
            print('🚀 Début du chargement: $url');
            setState(() {
              _isLoading = true;
              _hasError = false;
              _loadingProgress = 0;
              _isContentLoaded = false;
            });
          },
          onPageFinished: (String url) {
            print('✅ Chargement terminé: $url');
            setState(() {
              _isLoading = false;
              _loadingProgress = 100;
              _isContentLoaded = true;
            });

            // Vérifier si le contenu est bien chargé
            _checkIfContentLoaded();
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ Erreur WebView: ${error.errorCode} - ${error.description}');
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = 'Erreur ${error.errorCode}: ${error.description}';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            print('🧭 Navigation vers: ${request.url}');

            // Bloquer les téléchargements de PDF
            if (request.url.endsWith('.pdf') && !request.url.contains('docs.google.com')) {
              print('🚫 Téléchargement PDF bloqué: ${request.url}');
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onHttpError: (HttpResponseError error) {
            print('🌐 Erreur HTTP: ${error.response?.statusCode}');
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = 'Erreur HTTP ${error.response?.statusCode}';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(googleDocsUrl));

    _webViewController = controller;

    // Configuration spécifique à Android
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _checkIfContentLoaded() {
    // Vérifier après un délai si le contenu est vraiment chargé
    Future.delayed(Duration(seconds: 3), () {
      if (_isLoading) {
        print('⚠️ Chargement trop long, vérification...');
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Le chargement a pris trop de temps. Vérifiez votre connexion.';
        });
      }
    });
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: _afroBlack,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animation de livre
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[800]!.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                Icon(
                  Icons.menu_book_rounded,
                  size: 60,
                  color: _afroGreen,
                ),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _loadingProgress / 100,
                    strokeWidth: 4,
                    backgroundColor: Colors.grey[600],
                    valueColor: AlwaysStoppedAnimation<Color>(_afroGreen),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),

            Text(
              'Préparation de votre ebook',
              style: TextStyle(
                color: _afroWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            Text(
              '$_loadingProgress%',
              style: TextStyle(
                color: _afroGreen,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),

            Container(
              width: 200,
              child: LinearProgressIndicator(
                value: _loadingProgress / 100,
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation<Color>(_afroGreen),
                minHeight: 6,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 16),

            Text(
              _getLoadingMessage(),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getLoadingMessage() {
    if (_loadingProgress < 30) {
      return 'Connexion au serveur...';
    } else if (_loadingProgress < 60) {
      return 'Chargement du document...';
    } else if (_loadingProgress < 90) {
      return 'Préparation de l\'affichage...';
    } else {
      return 'Presque terminé...';
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      color: _afroBlack,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 60,
              ),
              SizedBox(height: 24),

              Text(
                'Impossible d\'afficher l\'ebook',
                style: TextStyle(
                  color: _afroWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              Text(
                _errorMessage,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  foregroundColor: _afroBlack,
                  backgroundColor: _afroGreen,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () {
                  _webViewController.reload();
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                    _loadingProgress = 0;
                  });
                },
                icon: Icon(Icons.refresh_rounded),
                label: Text('Réessayer'),
              ),
              SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Retour à la fiche',
                  style: TextStyle(
                    color: _afroWhite,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return WebViewWidget(controller: _webViewController);
  }

  Widget _buildSuccessOverlay() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 500),
        opacity: _isContentLoaded ? 1.0 : 0.0,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _afroGreen.withOpacity(0.9),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Ebook chargé avec succès',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _afroBlack,
      appBar: AppBar(
        backgroundColor: _afroBlack,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _afroWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.content.isSeries && widget.episode != null
              ? '${widget.episode!.title}'
              : '${widget.content.title}',
          style: TextStyle(
            color: _afroWhite,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_afroGreen),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _afroWhite),
            onPressed: () {
              _webViewController.reload();
              setState(() {
                _isLoading = true;
                _hasError = false;
                _loadingProgress = 0;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView principal
          _buildWebView(),

          // Overlay de chargement
          if (_isLoading) _buildLoadingIndicator(),

          // Overlay d'erreur
          if (_hasError && !_isLoading) _buildErrorWidget(),

          // Message de succès
          // if (_isContentLoaded && !_isLoading) _buildSuccessOverlay(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _webViewController.clearCache();
    super.dispose();
  }
}

// Couleurs thématiques
const Color _afroBlack = Color(0xFF121212);
const Color _afroWhite = Color(0xFFFFFFFF);
const Color _afroGreen = Color(0xFF00C853);