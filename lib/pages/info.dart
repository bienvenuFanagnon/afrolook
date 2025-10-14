import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/userProvider.dart';
import 'admin/addAppInfo.dart';

import 'package:linkify/linkify.dart';
import 'package:url_launcher/url_launcher.dart';


class AppInfos extends StatefulWidget {
  const AppInfos({super.key});

  @override
  State<AppInfos> createState() => _AppInfosState();
}

class _AppInfosState extends State<AppInfos> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.getAllInfos();
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  void _loadMoreData() async {
    if (_isLoadingMore) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (!userProvider.hasMore || userProvider.isLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    await userProvider.getAllInfos(loadMore: true);

    setState(() {
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "Afrolook Infos",
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Logo(),
          ),
        ],
        elevation: 0,
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewAppInfo()),
          );
        },
        backgroundColor: Colors.green,
        child: Icon(Icons.add, color: Colors.black),
      )
          : null,
      body: RefreshIndicator(
        backgroundColor: Colors.green,
        color: Colors.yellow,
        onRefresh: () async {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.getAllInfos();
        },
        child: Column(
          children: [
            if (isAdmin)
              _buildAdminStats(userProvider),
            Expanded(
              child: userProvider.listInfos.isEmpty && !userProvider.isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                controller: _scrollController,
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: userProvider.listInfos.length + 1,
                itemBuilder: (context, index) {
                  if (index == userProvider.listInfos.length) {
                    return _buildLoadMoreIndicator();
                  }
                  return InfoCard(
                    info: userProvider.listInfos[index],
                    isAdmin: isAdmin,
                    onDelete: () => _deleteInfo(userProvider.listInfos[index].id!),
                    onToggleFeatured: (featured) => _toggleFeatured(
                        userProvider.listInfos[index].id!, featured),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminStats(UserProvider userProvider) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.green)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', userProvider.listInfos.length.toString()),
          _buildStatItem(
            'En avant',
            userProvider.listInfos.where((info) => info.isFeatured == true).length.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.green,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: Colors.green,
          ),
          SizedBox(height: 16),
          Text(
            'Aucune information disponible',
            style: TextStyle(
              color: Colors.yellow,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return _isLoadingMore
        ? Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ),
    )
        : SizedBox();
  }

  void _deleteInfo(String infoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Confirmer la suppression',
          style: TextStyle(color: Colors.yellow),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer cette information ?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler', style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.deleteInfo(infoId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Information supprimée avec succès'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erreur lors de la suppression'),
          ),
        );
      }
    }
  }

  void _toggleFeatured(String infoId, bool featured) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.toggleFeatured(infoId, featured);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(featured ? 'Mis en avant' : 'Retiré des mises en avant'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Erreur lors de la modification'),
        ),
      );
    }
  }
}

class InfoCard extends StatelessWidget {
  final Information info;
  final bool isAdmin;
  final VoidCallback onDelete;
  final Function(bool) onToggleFeatured;

  const InfoCard({
    Key? key,
    required this.info,
    required this.isAdmin,
    required this.onDelete,
    required this.onToggleFeatured,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InfoDetailPage(
                  info: info,
                  isAdmin: isAdmin,
                  onDelete: onDelete,
                  onToggleFeatured: onToggleFeatured,
                ),
              ),
            );
            userProvider.incrementViews(info.id!);
          },
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête compacte avec badge et actions admin
                Row(
                  children: [
                    // Badge "En avant" compact
                    if (info.isFeatured == true)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.yellow.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.yellow, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.yellow, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'EN AVANT',
                              style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Spacer(),
                    // Actions admin compactes
                    if (isAdmin) _buildCompactAdminActions(),
                  ],
                ),

                SizedBox(height: 8),

                // Contenu principal en ligne
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image miniature
                    if (info.media_url!.isNotEmpty) ...[
                      _buildCompactImagePreview(),
                      SizedBox(width: 12),
                    ],

                    // Texte contenu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Titre
                          Text(
                            info.titre!.toUpperCase(),
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: 6),

                          // Description courte
                          Text(
                            _getShortDescription(info.description!),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: 8),

                          // Stats et actions en ligne compacte
                          _buildCompactStatsRow(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactAdminActions() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.yellow, size: 18),
      padding: EdgeInsets.zero,
      offset: Offset(0, 40),
      onSelected: (value) {
        if (value == 'delete') {
          onDelete();
        } else if (value == 'feature') {
          onToggleFeatured(true);
        } else if (value == 'unfeature') {
          onToggleFeatured(false);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: info.isFeatured == true ? 'unfeature' : 'feature',
          child: Row(
            children: [
              Icon(
                info.isFeatured == true ? Icons.star_border : Icons.star,
                color: Colors.yellow,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                info.isFeatured == true ? 'Retirer avant' : 'Mettre en avant',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text(
                'Supprimer',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactImagePreview() {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CachedNetworkImage(
          imageUrl: info.media_url!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[800],
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[800],
            child: Icon(Icons.photo, color: Colors.green, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatsRow() {
    return Row(
      children: [
        // Vues
        Row(
          children: [
            Icon(Icons.remove_red_eye, color: Colors.green, size: 12),
            SizedBox(width: 4),
            Text(
              '${info.views ?? 0}',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        SizedBox(width: 12),

        // Likes
        Row(
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 12),
            SizedBox(width: 4),
            Text(
              '${info.likes ?? 0}',
              style: TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        Spacer(),

        // Lire plus
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.yellow.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.yellow.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lire',
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward, color: Colors.yellow, size: 10),
            ],
          ),
        ),
      ],
    );
  }

  String _getShortDescription(String description) {
    // Description plus courte pour le design compact
    if (description.length <= 100) return description;
    return '${description.substring(0, 100)}...';
  }
}



class InfoDetailPage extends StatefulWidget {
  final Information info;
  final bool isAdmin;
  final VoidCallback onDelete;
  final Function(bool) onToggleFeatured;

  const InfoDetailPage({
    Key? key,
    required this.info,
    required this.isAdmin,
    required this.onDelete,
    required this.onToggleFeatured,
  }) : super(key: key);

  @override
  State<InfoDetailPage> createState() => _InfoDetailPageState();
}

class _InfoDetailPageState extends State<InfoDetailPage> {
  bool _isLiked = false;
  bool _isLoadingLike = false;
  bool _hasLiked = false;
  final double _likeAnimationSize = 60.0;
  double _likeAnimationScale = 1.0;
  double _likeAnimationOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
    _incrementViews();
  }

  void _incrementViews() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.incrementViews(widget.info.id!);
  }

  void _checkIfLiked() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    bool liked = await userProvider.isLiked(
      widget.info.id!,
      authProvider.loginUserData.id!,
    );

    if (mounted) {
      setState(() {
        _isLiked = liked;
      });
    }
  }

  void _toggleLike() async {
    if (_isLoadingLike || _hasLiked) return;

    setState(() {
      _isLoadingLike = true;
      _hasLiked = true;
      _likeAnimationScale = 1.5;
      _likeAnimationOpacity = 1.0;
    });

    // Animation de like
    await Future.delayed(Duration(milliseconds: 300));

    setState(() {
      _likeAnimationScale = 1.0;
      _likeAnimationOpacity = 0.0;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    try {
      await userProvider.toggleLike(
        widget.info.id!,
        authProvider.loginUserData.id!,
      );

      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _isLoadingLike = false;
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      if (mounted) {
        setState(() {
          _isLoadingLike = false;
          _hasLiked = false;
        });
      }
    }

    // Réinitialiser après un délai pour éviter les doubles-clics
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _hasLiked = false;
        });
      }
    });
  }

  void _showFullScreenImage() {
    if (widget.info.media_url!.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(0),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Hero(
                    tag: 'image_${widget.info.id}',
                    child: CachedNetworkImage(
                      imageUrl: widget.info.media_url!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Détails Information',
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.isAdmin) _buildAdminMenu(),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image avec possibilité de plein écran
            if (widget.info.media_url!.isNotEmpty)
              GestureDetector(
                onTap: _showFullScreenImage,
                child: Hero(
                  tag: 'image_${widget.info.id}',
                  child: Container(
                    height: 280,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.info.media_url!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Skeletonizer(
                            child: Container(color: Colors.grey[800]),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[800],
                            child: Icon(Icons.error, color: Colors.red, size: 50),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge "En avant"
                  if (widget.info.isFeatured == true)
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.yellow, Colors.orange],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.black, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'EN AVANT',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Titre
                  Text(
                    widget.info.titre!.toUpperCase(),
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),

                  SizedBox(height: 20),

                  // Statistiques
                  _buildStatsRow(),

                  SizedBox(height: 25),

                  // Description avec liens cliquables
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Linkify(
                      onOpen: (link) async {
                        if (await canLaunchUrl(Uri.parse(link.url))) {
                          await launchUrl(Uri.parse(link.url));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.red,
                              content: Text('Impossible d\'ouvrir le lien: ${link.url}'),
                            ),
                          );
                        }
                      },
                      text: widget.info.description!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.6,
                      ),
                      linkStyle: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      options: LinkifyOptions(humanize: false),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Date de publication
                  _buildPublishDate(),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bouton Like avec animation
      floatingActionButton: _buildLikeButton(),
      // floatingActionButton: widget.isAdmin ? null : _buildLikeButton(),
    );
  }

  Widget _buildAdminMenu() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.yellow, size: 28),
      onSelected: (value) async {
        switch (value) {
          case 'delete':
            _confirmDelete();
            break;
          case 'feature':
            await widget.onToggleFeatured(true);
            _showSnackBar('Information mise en avant !');
            break;
          case 'unfeature':
            await widget.onToggleFeatured(false);
            _showSnackBar('Information retirée des mises en avant');
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: widget.info.isFeatured == true ? 'unfeature' : 'feature',
          child: Row(
            children: [
              Icon(
                widget.info.isFeatured == true ? Icons.star_border : Icons.star,
                color: Colors.yellow,
              ),
              SizedBox(width: 12),
              Text(
                widget.info.isFeatured == true ? 'Retirer avant' : 'Mettre en avant',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 12),
              Text(
                'Supprimer',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.remove_red_eye,
            'Vues',
            '${widget.info.views ?? 0}',
            Colors.green,
          ),
          _buildStatItem(
            Icons.favorite,
            'Likes',
            '${widget.info.likes ?? 0}',
            Colors.red,
          ),
          _buildStatItem(
            Icons.calendar_today,
            'Publié',
            _formatDate(widget.info.createdAt!),
            Colors.yellow,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPublishDate() {
    return Row(
      children: [
        Icon(Icons.schedule, color: Colors.green, size: 16),
        SizedBox(width: 8),
        Text(
          'Publié le ${_formatDateWithTime(widget.info.createdAt!)}',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildLikeButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Animation de like
        AnimatedOpacity(
          opacity: _likeAnimationOpacity,
          duration: Duration(milliseconds: 300),
          child: AnimatedScale(
            scale: _likeAnimationScale,
            duration: Duration(milliseconds: 300),
            child: Icon(
              Icons.favorite,
              color: Colors.red,
              size: _likeAnimationSize,
            ),
          ),
        ),

        // Bouton like principal
        FloatingActionButton(
          onPressed: _toggleLike,
          backgroundColor: _isLiked ? Colors.red : Colors.green,
          child: _isLoadingLike
              ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
              size: 28,
              key: ValueKey(_isLiked),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.yellow),
            SizedBox(width: 10),
            Text(
              'Confirmer la suppression',
              style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Cette action est irréversible. Êtes-vous sûr de vouloir supprimer cette information ?',
          style: TextStyle(color: Colors.white, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'ANNULER',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete();
              Navigator.of(context).pop();
              _showSnackBar('Information supprimée avec succès');
            },
            child: Text(
              'SUPPRIMER',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateWithTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}