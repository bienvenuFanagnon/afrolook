import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/seriesDetailScreenContenu.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/authProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import '../user/profile/profile.dart';
import 'contentDetails.dart';
import 'contentForm.dart';
import 'contentSerie.dart';

class ProfileScreenContenu extends StatefulWidget {
  @override
  _ProfileScreenContenuState createState() => _ProfileScreenContenuState();
}

class _ProfileScreenContenuState extends State<ProfileScreenContenu> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final userAuthProvider = Provider.of<UserAuthProvider>(context);
    final contentProvider = Provider.of<ContentProvider>(context);
    final user = userAuthProvider.loginUserData;

    final userVideos = contentProvider.userContentPaies.where((c) => !c.isSeries).toList();
    final userSeries = contentProvider.userContentPaies.where((c) => c.isSeries).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Mon Profil de Créateur', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[800],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ContentFormScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.yellow,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Vidéos (${userVideos.length})'),
            Tab(text: 'Séries (${userSeries.length})'),
            Tab(text: 'Statistiques'),
          ],
        ),
      ),
      body: Column(
        children: [
          // En-tête avec informations utilisateur et solde
          _buildUserHeader(user),
          Divider(height: 1, color: Colors.grey[300]),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVideosTab(userVideos, contentProvider),
                _buildSeriesTab(userSeries, contentProvider),
                _buildStatsTab(user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(UserData? user) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          // Photo de profil
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: ClipOval(
              child: user?.imageUrl != null && user!.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: user.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.person, color: Colors.grey),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.person, color: Colors.grey),
                ),
              )
                  : Container(
                color: Colors.grey[300],
                child: Icon(Icons.person, color: Colors.grey, size: 40),
              ),
            ),
          ),
          SizedBox(width: 16),
          // Informations utilisateur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.pseudo ?? 'Utilisateur',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Créateur de contenu',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                // Solde principal
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.yellow[700]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.yellow[800], size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Solde : ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${user?.votre_solde_principal ?? 0} FCFA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bouton Voir plus
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.visibility, color: Colors.green),
                onPressed: () {
                  // Navigation vers la page de profil utilisateur complet
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfil()));
                },
              ),
              Text(
                'Voir plus',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideosTab(List<ContentPaie> videos, ContentProvider contentProvider) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucune vidéo publiée',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ContentFormScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Créer une vidéo'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return _buildVideoItem(video);
      },
    );
  }

  Widget _buildSeriesTab(List<ContentPaie> series, ContentProvider contentProvider) {
    if (series.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucune série créée',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ContentFormScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Créer une série'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: series.length,
      itemBuilder: (context, index) {
        final serie = series[index];
        return FutureBuilder<List<Episode>>(
          future: contentProvider.getEpisodesForSeries(serie.id!),
          builder: (context, snapshot) {
            final episodeCount = snapshot.hasData ? snapshot.data!.length : 0;

            return Card(
              margin: EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: serie.thumbnailUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      width: 60,
                      height: 60,
                      child: Icon(Icons.movie, color: Colors.grey),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      width: 60,
                      height: 60,
                      child: Icon(Icons.error, color: Colors.grey),
                    ),
                  ),
                ),
                title: Text(
                  serie.title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text(
                      '$episodeCount épisode(s)',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      serie.isFree ? 'Gratuit' : 'À partir de ${serie.price} FCFA',
                      style: TextStyle(
                        color: serie.isFree ? Colors.green : Colors.yellow[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_circle, color: Colors.green,size: 15,),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ContentFormScreen(
                              isEpisode: true,
                              seriesId: serie.id,
                            ),
                          ),
                        );
                      },
                    ),
                    // Text(
                    //   'Ajouter',
                    //   style: TextStyle(fontSize: 10, color: Colors.green),
                    // ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // builder: (context) => SeriesEpisodesScreen(series: serie),
                      builder: (context) => SeriesDetailScreen(series: serie),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatsTab(UserData? user) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mes Statistiques',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          // Cartes de statistiques
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            children: [
              // _buildStatCard('Vues totales', '${user?.userlikes ?? 0}', Icons.visibility, Colors.blue),
              _buildStatCard('Likes totaux', '${user?.likes ?? 0}', Icons.thumb_up, Colors.pink),
              _buildStatCard('Abonnés', '${user?.abonnes ?? 0}', Icons.people, Colors.purple),
              // _buildStatCard('Commentaires', '${user?.comments ?? 0}', Icons.comment, Colors.orange),
            ],
          ),
          SizedBox(height: 24),
          Text(
            'Mes Revenus',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          _buildRevenueCard('Solde Principal', '${user?.votre_solde_principal ?? 0} FCFA', Icons.account_balance_wallet, Colors.green),
        //   SizedBox(height: 12),
        //   _buildRevenueCard('Solde Contenu', '${user?.votre_solde_contenu ?? 0} FCFA', Icons.movie, Colors.yellow[700]!),
        //   SizedBox(height: 12),
        //   _buildRevenueCard('Solde Cadeau', '${user?.votre_solde_cadeau ?? 0} FCFA', Icons.card_giftcard, Colors.red),
         ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoItem(ContentPaie video) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => ContentDetailScreen(content: video)));
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image de la vidéo
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: Center(child: CircularProgressIndicator(color: Colors.green)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.error, color: Colors.grey),
                  ),
                ),
              ),
            ),
            // Contenu de la carte
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.visibility, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('${video.views}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      SizedBox(width: 12),
                      Icon(Icons.thumb_up, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('${video.likes}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: video.isFree ? Colors.green[50] : Colors.yellow[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: video.isFree ? Colors.green : Colors.yellow[700]!,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      video.isFree ? 'GRATUIT' : '${video.price} FCFA',
                      style: TextStyle(
                        color: video.isFree ? Colors.green[800] : Colors.yellow[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}