import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/tr.dart';
import '../../theme/app_colors.dart';

/// Mur de tâches de nos partenaires, ouvert DANS l'application (page web intégrée, aucune nouvelle version nécessaire quand le mur change).
/// Seules les adresses https sont chargées.
class PartnerWallPage extends StatefulWidget {
  const PartnerWallPage({super.key, required this.url});
  final String url;

  @override
  State<PartnerWallPage> createState() => _PartnerWallPageState();
}

class _PartnerWallPageState extends State<PartnerWallPage> {
  WebViewController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url);
    if (uri != null && uri.scheme == 'https') {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ))
        ..loadRequest(uri);
    } else {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        title: Text(tr('Tâches de nos partenaires')),
        actions: [IconButton(tooltip: tr('Fermer'), icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop())],
      ),
      body: _controller == null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(tr('Impossible d\'ouvrir les tâches pour le moment. Réessaie plus tard.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))))
          : Stack(children: [
              WebViewWidget(controller: _controller!),
              if (_loading) Center(child: CircularProgressIndicator(color: c.primary)),
            ]),
    );
  }
}
