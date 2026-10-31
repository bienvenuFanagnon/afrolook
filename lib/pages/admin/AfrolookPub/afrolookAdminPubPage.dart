// afrolookAdminPubPage.dart — validation des annonces par l'équipe (Afrolook Ads), via l'API (/admin/ads/queue et /admin/ads/decisions).
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdvertisementManagementPage extends StatefulWidget {
  const AdvertisementManagementPage({Key? key}) : super(key: key);

  @override
  State<AdvertisementManagementPage> createState() => _AdvertisementManagementPageState();
}

class _AdvertisementManagementPageState extends State<AdvertisementManagementPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _ads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = await RegieApi.getMap('/admin/ads/queue');
      if (!mounted) return;
      setState(() {
        _ads = ((q['ads'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = RegieApi.err(e);
          _loading = false;
        });
      }
    }
  }

  void _toast(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<String?> _askReason() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser cette annonce'),
        content: TextField(controller: ctl, maxLength: 200, maxLines: 3, decoration: const InputDecoration(labelText: 'Motif (obligatoire)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Refuser')),
        ],
      ),
    );
    final t = ctl.text.trim();
    if (ok != true) return null;
    if (t.length < 5) {
      _toast('Le motif doit faire 5 caractères au moins.');
      return null;
    }
    return t;
  }

  Future<void> _decide(Map<String, dynamic> ad, String action) async {
    String? reason;
    if (action == 'reject') {
      reason = await _askReason();
      if (reason == null) return;
    }
    try {
      await RegieApi.post('/admin/ads/decisions', body: {'type': 'ad', 'id': '${ad['id']}', 'action': action, if (reason != null) 'reason': reason});
      _toast(action == 'approve' ? 'Annonce validée' : 'Annonce refusée');
      _load();
    } catch (e) {
      _toast(RegieApi.err(e));
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
        title: const Text('Annonces à valider'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Actualiser')],
      ),
      body: CenteredContent(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, style: TextStyle(color: c.danger), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                      ]),
                    ),
                  )
                : _ads.isEmpty
                    ? Center(child: Text('Aucune annonce en attente.', style: TextStyle(color: c.textSecondary)))
                    : ListView(padding: const EdgeInsets.all(12), children: [for (final a in _ads) _card(c, a)]),
      ),
    );
  }

  Widget _card(AppColors c, Map<String, dynamic> ad) {
    final img = '${ad['thumb_url'] ?? ad['media_url'] ?? ''}';
    final url = '${ad['action_url'] ?? ''}';
    return Card(
      color: c.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (img.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(img, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 60, child: Icon(Icons.broken_image_outlined))),
            ),
          const SizedBox(height: 8),
          Text('${ad['title'] ?? ''}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          if ('${ad['text'] ?? ''}'.isNotEmpty) Text('${ad['text']}', style: TextStyle(color: c.textSecondary)),
          const SizedBox(height: 4),
          Text('Catégorie : ${ad['category'] ?? '—'} · ${ad['paid'] == true ? 'payante' : 'gratuite'}${ad['network'] == true ? ' · offre Réseau' : ''}', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          if (url.isNotEmpty)
            InkWell(
              onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(url, style: TextStyle(color: c.info, decoration: TextDecoration.underline, fontSize: 13))),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            FilledButton(onPressed: () => _decide(ad, 'approve'), child: const Text('Valider')),
            OutlinedButton(onPressed: () => _decide(ad, 'reject'), child: const Text('Refuser')),
          ]),
        ]),
      ),
    );
  }
}
