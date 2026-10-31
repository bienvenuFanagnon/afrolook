import 'package:afrotok/services/api/compte_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'user_ad_detail_page.dart';
import 'user_create_advertisement_page.dart';

/// Mes annonces de la régie Afrolook Ads (GET /ads/account/ads). En cas d'erreur : message + « Réessayer », jamais de repli.
class UserMyAdvertisementsPage extends StatefulWidget {
  const UserMyAdvertisementsPage({Key? key}) : super(key: key);

  @override
  State<UserMyAdvertisementsPage> createState() => _UserMyAdvertisementsPageState();
}

class _UserMyAdvertisementsPageState extends State<UserMyAdvertisementsPage> {
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
      final ads = await CompteApi.myAds();
      if (!mounted) return;
      setState(() {
        _ads = ads;
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

  String _date(dynamic iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Mes publicités'),
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserCreateAdvertisementPage())),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle publicité'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
                      const SizedBox(height: 14),
                      ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                    ]),
                  ),
                )
              : _ads.isEmpty
                  ? Center(child: Text('Aucune publicité pour le moment.', style: TextStyle(color: c.textSecondary)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                        itemCount: _ads.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final a = _ads[i];
                          final imgs = CompteApi.adImages(a);
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserAdDetailPage(advertisementId: '${a['id']}'))),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                              child: Row(children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: imgs.isEmpty
                                        ? Container(color: c.surfaceVariant, child: Icon(Icons.campaign_outlined, color: c.textSecondary))
                                        : CachedNetworkImage(imageUrl: imgs.first, fit: BoxFit.cover),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${a['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(CompteApi.statusLabel(a['status'] as String?), style: TextStyle(color: c.textSecondary, fontSize: 12)),
                                    if (a['ends_at'] != null) Text("Jusqu'au ${_date(a['ends_at'])}", style: TextStyle(color: c.textSecondary, fontSize: 12)),
                                  ]),
                                ),
                                Icon(Icons.chevron_right, color: c.textSecondary),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
