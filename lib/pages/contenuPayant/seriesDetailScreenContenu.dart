import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/content_detail_page.dart';
import 'package:afrotok/pages/contenuPayant/widgets/series_episodes_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';

/// Page d'une série : bannière, description et épisodes (`GET /paid-contents/{série}/episodes`). Un épisode gratuit est ouvert à tous ;
/// les autres demandent d'avoir acheté la SÉRIE (bouton « Voir la série et l'acheter » vers la fiche complète).
class SeriesDetailScreen extends StatelessWidget {
  final ContentPaie series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final me = auth.loginUserData;
    final isOwner = me.id != null && (me.id == series.ownerId || me.role == 'ADM');
    String cdn(String? url) => (url == null || url.isEmpty) ? '' : auth.convertToCdnUrl(url, auth.appDefaultData);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(series.title, style: TextStyle(color: colors.primary)),
        backgroundColor: colors.background,
        iconTheme: IconThemeData(color: colors.primary),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: colors.surface,
                image: cdn(series.thumbnailUrl).isEmpty ? null : DecorationImage(image: NetworkImage(cdn(series.thumbnailUrl)), fit: BoxFit.cover),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent]),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(series.title, style: TextStyle(color: colors.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(series.description, style: TextStyle(color: colors.textPrimary, fontSize: 16)),
            ),
            SeriesEpisodesSection(
              series: series,
              isOwner: isOwner,
              onNeedPurchase: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContentDetailPage(content: series))),
            ),
            const SizedBox(height: 24),
            if (!isOwner)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContentDetailPage(content: series))),
                  child: Text(tr('Voir la série et l\'acheter')),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
