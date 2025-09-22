import 'dart:io';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/profileScreenContent.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

import '../../providers/contenuPayantProvider.dart';
import '../../providers/userProvider.dart';
import 'contentDetails.dart';
import 'contentForm.dart';
import 'contentSerie.dart';

class DashboardContentScreen extends StatefulWidget {
  @override
  _DashboardContentScreenState createState() => _DashboardContentScreenState();
}

class _DashboardContentScreenState extends State<DashboardContentScreen> {
  final Map<String, Uint8List?> _videoThumbnails = {};
  int _currentTabIndex = 0; // 0: Accueil, 1: Séries, 2: À la demande

  @override
  void initState() {
    super.initState();

    _preloadThumbnails();
  }

  Future<void> _preloadThumbnails() async {
    final authProvider = Provider.of<UserAuthProvider>(context,listen: false);

    authProvider.checkAppVersionAndProceed(context, () {
    });
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    await contentProvider.loadInitialData();
  }

  Widget _buildContentImage(ContentPaie content) {
    return Stack(
      children: [
        Container(
          color: Colors.grey[900],
          child: content.thumbnailUrl != null && content.thumbnailUrl!.isNotEmpty
              ? ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: content.thumbnailUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Container(
                color: Colors.grey[800],
                child: Center(child: CircularProgressIndicator(color: Colors.green)),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[800],
                child: Icon(Icons.error, color: Colors.white),
              ),
            ),
          )
              : Center(child: Icon(Icons.videocam, color: Colors.grey[600], size: 40)),
        ),
        // Badge pour contenu payant
        if (!content.isFree)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${content.price} F',
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        // Badge pour les séries
        if (content.isSeries)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.playlist_play, color: Colors.blue, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Série',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Indicateur de durée pour les vidéos
        if (content.videoUrl != null && content.videoUrl!.isNotEmpty && content.views != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                spacing: 5,
                children: [
                  Icon(Icons.remove_red_eye,color: Colors.white,size: 15,),
                  Text(
                    content.views!.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentProvider = Provider.of<ContentProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,

        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showSearch(context: context, delegate: ContentSearchDelegate());
            },
          ),
          IconButton(
            icon: Icon(Icons.person, color: Colors.white),
            onPressed: () {
              final authProvider = Provider.of<UserAuthProvider>(context,listen: false);

              authProvider.checkAppVersionAndProceed(context, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreenContenu()));

              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: () {
          final authProvider = Provider.of<UserAuthProvider>(context,listen: false);

          authProvider.checkAppVersionAndProceed(context, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ContentFormScreen()));

          });
        },
        child: Icon(Icons.add, size: 28),
      ),
      body: Column(
        children: [
          // Barre d'onglets style YouTube
          Container(
            color: Colors.black,
            height: 50,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildTabItem('Toutes', 0),
                      _buildTabItem('Séries', 1),
                      _buildTabItem('À la demande', 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[800]),
          SizedBox(height: 10,),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _preloadThumbnails();
              },
              child: _buildContentForTab(_currentTabIndex, contentProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: isSelected
              ? Border(
            bottom: BorderSide(color: Colors.red, width: 2),
          )
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildContentForTab(int tabIndex, ContentProvider contentProvider) {
    switch (tabIndex) {
      case 0: // Accueil
        return _buildHomeTab(contentProvider);
      case 1: // Séries
        return _buildSeriesTab(contentProvider);
      case 2: // À la demande
        return _buildOnDemandTab(contentProvider);
      default:
        return _buildHomeTab(contentProvider);
    }
  }

  Widget _buildHomeTab(ContentProvider contentProvider) {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contenus vedette (nouveautés)
          _buildFeaturedContent(contentProvider.featuredContentPaies),
          SizedBox(height: 24),

          // Contenus récents (toutes catégories)
          _buildRecentContent(contentProvider.allContentPaies),

          // Contenus par catégorie
          for (var category in contentProvider.categories)
            _buildCategorySection(
              category.name,
              contentProvider.contentPaiesByCategory[category.id] ?? [],
            ),

          if (contentProvider.categories.isEmpty) _buildNoDataSection(),

          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSeriesTab(ContentProvider contentProvider) {
    // Filtrer seulement les séries
    final seriesContent = contentProvider.allContentPaies.where((content) => content.isSeries).toList();

    return seriesContent.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_play, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucune série disponible',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    )
        : GridView.builder(
      padding: EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: seriesContent.length,
      itemBuilder: (context, index) {
        final content = seriesContent[index];
        return GestureDetector(
          onTap: () {
            final authProvider = Provider.of<UserAuthProvider>(context,listen: false);

            authProvider.checkAppVersionAndProceed(context, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SeriesEpisodesScreen(series: content),
                ),
              );
            });

          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildContentImage(content),
                ),
              ),
              SizedBox(height: 8),
              Text(
                content.title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                'Série • ${ 0} épisodes',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnDemandTab(ContentProvider contentProvider) {
    // Contenus payants uniquement
    final paidContent = contentProvider.allContentPaies.where((content) => !content.isFree).toList();

    return paidContent.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monetization_on, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucun contenu payant disponible',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    )
        : GridView.builder(
      padding: EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: paidContent.length,
      itemBuilder: (context, index) {
        final content = paidContent[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentDetailScreen(content: content),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildContentImage(content),
                ),
              ),
              SizedBox(height: 8),
              Text(
                content.title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                '${content.price} F',
                style: TextStyle(
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentContent(List<ContentPaie> contents) {
    if (contents.isEmpty) return SizedBox();

    // Trier par date de création (les plus récents d'abord)
    contents.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

    // Prendre les 10 plus récents
    final recentContents = contents.take(10).toList();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Nouveautés', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          SizedBox(height: 12),
          Container(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemCount: recentContents.length,
              itemBuilder: (context, index) {
                final content = recentContents[index];
                return Container(
                  width: 320,
                  margin: EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () {
                      if (content.isSeries) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SeriesEpisodesScreen(series: content),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContentDetailScreen(content: content),
                          ),
                        );
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildContentImage(content),
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            content.title,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Text(
                                content.isSeries ? 'Série' : 'Film',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              SizedBox(width: 8),
                              Text(
                                content.isFree ? 'Gratuit' : '${content.price} F',
                                style: TextStyle(
                                  color: content.isFree ? Colors.green : Colors.yellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedContent(List<ContentPaie> contents) {
    if (contents.isEmpty) return _buildFeaturedPlaceholder();

    return Container(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12),
        itemCount: contents.length,
        itemBuilder: (context, index) {
          final content = contents[index];
          return GestureDetector(
            onTap: () {

              final authProvider = Provider.of<UserAuthProvider>(context,listen: false);

              authProvider.checkAppVersionAndProceed(context, () {
                if (content.isSeries) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SeriesEpisodesScreen(series: content),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContentDetailScreen(content: content),
                    ),
                  );
                }
              });
              // if (content.isSeries) {
              //   Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //       builder: (_) => SeriesEpisodesScreen(series: content),
              //     ),
              //   );
              // } else {
              //   Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //       builder: (_) => ContentDetailScreen(content: content),
              //     ),
              //   );
              // }
            },
            child: Container(
              width: 320,
              margin: EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          _buildContentImage(content),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                                  stops: [0.1, 0.6],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      content.title,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Text(
                          content.isSeries ? 'Série' : 'Film',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        SizedBox(width: 8),
                        Text(
                          content.isFree ? 'Gratuit' : '${content.price} F',
                          style: TextStyle(
                            color: content.isFree ? Colors.green : Colors.yellow,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (content.views > 0) ...[
                          SizedBox(width: 8),
                          Text(
                            '${content.views} vues',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(String title, List<ContentPaie> contents) {
    if (contents.isEmpty) return SizedBox();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(title, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                GestureDetector(
                  onTap: () {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryContentScreen(categoryTitle: title, contents: contents),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text('Tout voir', style: TextStyle(color: Colors.red, fontSize: 14)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, color: Colors.red, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Container(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemCount: contents.length,
              itemBuilder: (context, index) {
                final content = contents[index];
                return Container(
                  width: 140,
                  margin: EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () {
                      final authProvider = Provider.of<UserAuthProvider>(context,listen: false);

                      authProvider.checkAppVersionAndProceed(context, () {
                        if (content.isSeries) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SeriesEpisodesScreen(series: content),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContentDetailScreen(content: content),
                            ),
                          );
                        }
                      });

                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildContentImage(content),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          content.title,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          content.isFree ? 'Gratuit' : '${content.price} F',
                          style: TextStyle(
                            color: content.isFree ? Colors.green : Colors.yellow,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedPlaceholder() => Container(
    height: 220,
    margin: EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[900]),
    child: Center(child: Icon(Icons.videocam_off, color: Colors.grey[700], size: 50)),
  );

  Widget _buildNoDataSection() => Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Text('Aucun contenu disponible', style: TextStyle(color: Colors.white70, fontSize: 18)),
    ),
  );
}



class CategoryContentScreen extends StatefulWidget {
  final String categoryTitle;
  final List<ContentPaie> contents;

  const CategoryContentScreen({Key? key, required this.categoryTitle, required this.contents}) : super(key: key);

  @override
  _CategoryContentScreenState createState() => _CategoryContentScreenState();
}

class _CategoryContentScreenState extends State<CategoryContentScreen> {
  final Map<String, Uint8List?> _thumbnails = {};

  @override
  void initState() {
    super.initState();
    // _preloadThumbnails();
  }

  Future<void> _preloadThumbnails() async {
    for (var content in widget.contents) {
      if (content.videoUrl != null && content.videoUrl!.isNotEmpty) {
        _thumbnails[content.id!] = await _generateThumbnail(content.videoUrl!);
      }
    }
    setState(() {});
  }

  Future<Uint8List?> _generateThumbnail(String videoUrl) async {
    try {
      final path = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        quality: 50,
      );
      if (path != null) return await File(path).readAsBytes();
    } catch (e) {
      print('Erreur génération thumbnail: $e');
    }
    return null;
  }

  Widget _buildThumbnail(ContentPaie content) {
    // final bytes = _thumbnails[content.id!];
    final bytes = content.thumbnailUrl!;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[900],
          ),
          child: bytes != null
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(bytes, fit: BoxFit.cover, width: double.infinity))
              : Center(child: CircularProgressIndicator(color: Colors.green)),
        ),
        if (!content.isFree)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: Icon(Icons.monetization_on, color: Colors.yellow, size: 16),
            ),
          ),
        Positioned(
          bottom: 4,
          left: 4,
          right: 4,
          child: Container(
            color: Colors.black54,
            padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Text(
              content.title,
              style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.categoryTitle, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: Colors.green),
      ),
      body: widget.contents.isEmpty
          ? Center(
        child: Text('Aucun contenu disponible', style: TextStyle(color: Colors.white70, fontSize: 18)),
      )
          : Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: widget.contents.length,
          itemBuilder: (context, index) {
            final content = widget.contents[index];
            return GestureDetector(
              onTap: () {
                final authProvider = Provider.of<UserAuthProvider>(context,listen: false);

                authProvider.checkAppVersionAndProceed(context, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContentDetailScreen(content: content),
                    ),
                  );
                });

              },
              child: _buildThumbnail(content),
            );
          },
        ),
      ),
    );
  }
}

// Delegate pour la recherche
class ContentSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear, color: Colors.white),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);

    return Container(
      color: Colors.black,
      child: FutureBuilder<List<ContentPaie>>(
        future: contentProvider.searchContentPaies(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.red));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucun résultat trouvé pour "$query"',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Essayez avec d\'autres termes',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final results = snapshot.data!;

          return ListView.builder(
            padding: EdgeInsets.only(top: 16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final content = results[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: content.thumbnailUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: Icon(Icons.error, color: Colors.white),
                    ),
                  ),
                ),
                title: Text(
                  content.title,
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  content.description,
                  style: TextStyle(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: !content.isFree
                    ? Text(
                  '${content.price} F',
                  style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                )
                    : Text(
                  'Gratuit',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  final authProvider = Provider.of<UserAuthProvider>(context,listen: false);

                  authProvider.checkAppVersionAndProceed(context, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContentDetailScreen(content: content),
                      ),
                    );
                  });

                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Recherchez des vidéos par titre ou hashtag',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white70),
        border: InputBorder.none,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: Colors.white),
      ),
    );
  }
}