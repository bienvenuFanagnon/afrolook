import 'package:afrotok/services/api/compte_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Détail d'une de mes annonces de la régie Afrolook Ads. En cas d'erreur : message + « Réessayer ».
class UserAdDetailPage extends StatefulWidget {
  final String advertisementId;
  const UserAdDetailPage({Key? key, required this.advertisementId}) : super(key: key);

  @override
  State<UserAdDetailPage> createState() => _UserAdDetailPageState();
}

class _UserAdDetailPageState extends State<UserAdDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _ad;
  bool _deleting = false;

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
      final a = await CompteApi.myAd(widget.advertisementId);
      if (!mounted) return;
      setState(() {
        _ad = a;
        _error = a == null ? 'Publicité introuvable.' : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = CompteApi.message(e);
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la publicité ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await CompteApi.deleteAd(widget.advertisementId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CompteApi.message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = _ad;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Ma publicité'), backgroundColor: c.surface, foregroundColor: c.textPrimary, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || a == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error ?? '', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
                      const SizedBox(height: 14),
                      ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                    ]),
                  ),
                )
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final url in CompteApi.adImages(a))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)),
                    ),
                  Text('${a['title'] ?? ''}', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('${a['text'] ?? ''}', style: TextStyle(color: c.textSecondary, height: 1.4)),
                  const SizedBox(height: 14),
                  Text('Statut : ${CompteApi.statusLabel(a['status'] as String?)}', style: TextStyle(color: c.textPrimary)),
                  if ((a['action_url'] ?? '').toString().isNotEmpty) Text('Lien : ${a['action_url']}', style: TextStyle(color: c.textSecondary)),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _deleting ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(_deleting ? 'Suppression…' : 'Supprimer'),
                  ),
                ]),
    );
  }
}
