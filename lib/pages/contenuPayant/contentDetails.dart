import 'package:afrotok/pages/contenuPayant/userAbonnerInfos.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:lottie/lottie.dart';

import '../../models/model_data.dart';
import '../../providers/contenuPayantProvider.dart';
import '../../providers/userProvider.dart';
import '../../providers/authProvider.dart';

import '../../services/linkService.dart';

class ContentDetailScreen extends StatefulWidget {
  final ContentPaie content;
  final Episode? episode;

  ContentDetailScreen({required this.content, this.episode});

  @override
  _ContentDetailScreenState createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;
  bool _isVideoInitialized = false;
  bool _isPurchasing = false;
  bool _isLiked = false;
  bool _showLikeAnimation = false;
  late AnimationController _likeAnimationController;
  bool _isLikedAnimation = false;
  Episode? _currentEpisode;

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    _initializeVideo();
    _incrementViews();

    _likeAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
  }


  void _showDeleteModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Supprimer le contenu ?'),
        content: Text(
          widget.content.isSeries
              ? 'Êtes-vous sûr de vouloir supprimer cette série et tous ses épisodes ? Cette action est irréversible.'
              : 'Êtes-vous sûr de vouloir supprimer ce contenu ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // fermer le modal

              bool success = false;
              final contentProvider = Provider.of<ContentProvider>(context, listen: false);

              if (widget.content.isSeries) {
                // Supprimer série + épisodes
                success = await contentProvider.deleteContentPaie(widget.content.id!);
              } else if (widget.episode != null) {
                // Supprimer un épisode spécifique
                success = await contentProvider.deleteEpisode(widget.episode!.id!);
              } else {
                // Supprimer un contenu simple
                success = await contentProvider.deleteContentPaie(widget.content.id!);
              }

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Suppression réussie !'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context); // revenir à la page précédente
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la suppression.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }


  void _triggerLikeAnimation() {
    Future.delayed(Duration(milliseconds: 1000), () {
      setState(() {
        _showLikeAnimation = false;
      });
    });
  }

  void _initializeVideo() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);

    // Vérifier si l'utilisateur a acheté le contenu
    bool hasPurchased = contentProvider.userPurchases
        .any((purchase) => purchase.contentId == widget.content.id);

    // Déterminer si c'est une série avec épisodes
    bool isSeries = widget.content.isSeries;
    String? videoUrl = isSeries && _currentEpisode != null
        ? _currentEpisode!.videoUrl
        : widget.content.videoUrl ?? '';
    final userProvider = Provider.of<UserAuthProvider>(context,listen: false);
    final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
        userProvider.loginUserData?.id == widget.content.ownerId;

    bool canWatch = (isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree)
        || hasPurchased
        || isAdminOrOwner; // ajouté

    // bool canWatch = (isSeries ? _currentEpisode?.isFree ?? false : widget.content.isFree) || hasPurchased;

    if (canWatch && videoUrl!.isNotEmpty) {
      _videoPlayerController = VideoPlayerController.network(videoUrl);
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _afroGreen,
          handleColor: _afroGreen,
          backgroundColor: Colors.grey[700]!,
          bufferedColor: Colors.grey[500]!,
        ),
        placeholder: Container(
          color: _afroBlack,
          child: Center(
            child: CircularProgressIndicator(color: _afroGreen),
          ),
        ),
      );

      setState(() {
        _isVideoInitialized = true;
      });
    }
  }

  void _incrementViews() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);

    // Incrémenter les vues de l'épisode si c'est une série, sinon du contenu
    if (widget.content.isSeries && _currentEpisode != null) {
      await contentProvider.incrementViews(_currentEpisode!.id!,isEpisode: true);
    } else {
      await contentProvider.incrementViews(widget.content.id!);
    }
  }

  void _handleLike() async {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);

    setState(() {
      _isLiked = !_isLiked;
      _showLikeAnimation = true;
    });

    _likeAnimationController.reset();
    _likeAnimationController.forward();
    _triggerLikeAnimation();

    // Gérer le like selon qu'il s'agit d'un épisode ou d'un contenu simple
    if (widget.content.isSeries && _currentEpisode != null) {
      await contentProvider.toggleLike(_currentEpisode!.id!,isEpisode: true );
    } else {
      await contentProvider.toggleLike(widget.content.id!);
    }
  }

  @override
  void dispose() {
    if (_isVideoInitialized) {
      _videoPlayerController.dispose();
      _chewieController.dispose();
    }
    _likeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handlePurchase() async {
    setState(() {
      _isPurchasing = true;
    });

    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);

    final result = await contentProvider.purchaseContentPaie(
        userProvider.loginUserData!,
        widget.content,
        context
    );

    setState(() {
      _isPurchasing = false;
    });

    if (result == PurchaseResult.success) {
      contentProvider.loadUserPurchases();
      _showSuccessModal();
      setState(() {});
    } else if (result == PurchaseResult.alreadyPurchased) {
      _showAlreadyPurchasedModal();
    }
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _afroBlack,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: _afroGreen,
                  size: 60,
                ),
                SizedBox(height: 20),
                Text(
                  'Achat Réussi!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Le contenu a été débloqué avec succès.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _afroGreen,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: Text('Regarder maintenant'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAlreadyPurchasedModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _afroBlack,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  color: _afroYellow,
                  size: 60,
                ),
                SizedBox(height: 20),
                Text(
                  'Déjà Acheté',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Vous avez déjà acheté ce contenu.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _afroYellow,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
                    setState(() {
                      contentProvider.loadUserPurchases();
                    });
                  },
                  child: Text('Actualiser'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectEpisode(Episode episode) {
    setState(() {
      _currentEpisode = episode;
      _isVideoInitialized = false;
    });
    _initializeVideo();
  }

  Widget _buildSeriesInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.content.title!,
          style: TextStyle(
            color: _afroWhite,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Série',
          style: TextStyle(
            color: _afroYellow,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 16),
        if (_currentEpisode != null) ...[
          Text(
            'Épisode: ${_currentEpisode!.title}',
            style: TextStyle(
              color: _afroWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            // 'Saison ${_currentEpisode!.}, Épisode ${_currentEpisode!.episodeNumber}',
            'Épisode ${_currentEpisode!.episodeNumber}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSimpleContentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.content.title!,
          style: TextStyle(
            color: _afroWhite,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }

  // Widget _buildEpisodeSelector() {
  //   if (!widget.content.isSeries || widget.content.episodes == null || widget.content.episodes!.isEmpty) {
  //     return SizedBox();
  //   }
  //
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'Épisodes:',
  //         style: TextStyle(
  //           color: _afroWhite,
  //           fontSize: 18,
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //       SizedBox(height: 12),
  //       Container(
  //         height: 120,
  //         child: ListView.builder(
  //           scrollDirection: Axis.horizontal,
  //           itemCount: widget.content.episodes!.length,
  //           itemBuilder: (context, index) {
  //             final episode = widget.content.episodes![index];
  //             final isSelected = _currentEpisode?.id == episode.id;
  //
  //             return GestureDetector(
  //               onTap: () => _selectEpisode(episode),
  //               child: Container(
  //                 width: 160,
  //                 margin: EdgeInsets.only(right: 12),
  //                 decoration: BoxDecoration(
  //                   color: isSelected ? _afroGreen.withOpacity(0.2) : _afroBlack.withOpacity(0.5),
  //                   borderRadius: BorderRadius.circular(8),
  //                   border: Border.all(
  //                     color: isSelected ? _afroGreen : Colors.transparent,
  //                     width: 2,
  //                   ),
  //                 ),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Expanded(
  //                       child: ClipRRect(
  //                         borderRadius: BorderRadius.only(
  //                           topLeft: Radius.circular(8),
  //                           topRight: Radius.circular(8),
  //                         ),
  //                         child: CachedNetworkImage(
  //                           imageUrl: episode.thumbnailUrl,
  //                           fit: BoxFit.cover,
  //                           width: double.infinity,
  //                           placeholder: (context, url) => Container(
  //                             color: Colors.grey[900],
  //                           ),
  //                           errorWidget: (context, url, error) => Container(
  //                             color: Colors.grey[900],
  //                             child: Icon(Icons.error, color: Colors.white),
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                     Padding(
  //                       padding: EdgeInsets.all(8),
  //                       child: Text(
  //                         'E${episode.episodeNumber}: ${episode.title}',
  //                         style: TextStyle(
  //                           color: _afroWhite,
  //                           fontSize: 12,
  //                           fontWeight: FontWeight.w500,
  //                         ),
  //                         maxLines: 1,
  //                         overflow: TextOverflow.ellipsis,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             );
  //           },
  //         ),
  //       ),
  //       SizedBox(height: 20),
  //     ],
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final contentProvider = Provider.of<ContentProvider>(context,listen: false);
    final userProvider = Provider.of<UserAuthProvider>(context,listen: false);
    final isAdminOrOwner = userProvider.loginUserData?.role == UserRole.ADM.name ||
        userProvider.loginUserData?.id == widget.content.ownerId;
    final hasPurchased = contentProvider.userPurchases
        .any((purchase) => purchase.contentId == widget.content.id);

    final isSeries = widget.content.isSeries;
    // final canWatch = (isSeries
    //     ? (_currentEpisode?.isFree ?? false)
    //     : widget.content.isFree) || hasPurchased;

    bool canWatch = (isSeries ? (_currentEpisode?.isFree ?? false) : widget.content.isFree)
        || hasPurchased
        || isAdminOrOwner; // ajouté

    // Déterminer l'URL de la miniature
    String thumbnailUrl = isSeries && _currentEpisode != null
        ? _currentEpisode!.thumbnailUrl!
        : widget.content.thumbnailUrl ?? '';

    return Scaffold(
      backgroundColor: _afroBlack,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                floating: false,
                pinned: true,
                backgroundColor: _afroBlack,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[900],
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          child: Icon(Icons.error, color: Colors.white),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              _afroBlack.withOpacity(0.9),
                              _afroBlack.withOpacity(0.3),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      if (canWatch && _isVideoInitialized)
                        Positioned.fill(
                          child: Chewie(controller: _chewieController),
                        )
                      else if (!canWatch && !isAdminOrOwner) // Modifié ici
                        Positioned.fill(
                          child: Container(
                            color: _afroBlack.withOpacity(0.7),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 60,
                                    color: _afroWhite,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Contenu verrouillé',
                                    style: TextStyle(
                                      color: _afroWhite,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Débloquez ce contenu pour le regarder',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Votre soutien aide les artistes à créer plus de contenu',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (isAdminOrOwner) // Nouveau bloc pour admin/propriétaire
                          Positioned.fill(
                            child: Container(
                              color: _afroBlack.withOpacity(0.5),
                              child: Center(
                                child: Text(
                                  'Vous pouvez visionner ce contenu gratuitement (Admin/Propriétaire)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),

                    ],
                  ),
                ),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: _afroWhite),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (isAdminOrOwner)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _showDeleteModal,
                    ),

                  // IconButton(
                  //   icon: Icon(Icons.share, color: _afroWhite),
                  //   onPressed: () {},
                  // ),
                  // IconButton(
                  //   icon: Icon(Icons.bookmark_border, color: _afroWhite),
                  //   onPressed: () {},
                  // ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Affichage des informations selon le type de contenu
                      widget.content.isSeries ? _buildSeriesInfo() : _buildSimpleContentInfo(),
                      SizedBox(height: 10),

                      // --- Ici on affiche le widget ContentOwnerInfo ---
                      ContentOwnerInfo(ownerId: widget.content.ownerId),
                      // Actions rapides (Like, Vue, etc.)
                      Row(
                        children: [
                          // Bouton Like avec animation
                          GestureDetector(
                            onTap: () {
                              final AppLinkService _appLinkService = AppLinkService();
                              if(widget.episode==null){
                                _appLinkService.shareContent(
                                  type: AppLinkType.contentpaie,
                                  id: widget.content.id!,
                                  message: " ${widget.content.description}",
                                  mediaUrl: widget.content.thumbnailUrl!.isNotEmpty?"${widget.content.thumbnailUrl!}":"",
                                );
                              }else{
                                _appLinkService.shareContent(
                                  type: AppLinkType.contentpaie,
                                  id: widget.content.id!,

                                  // id: widget.episode!.id!,
                                  message: " ${widget.episode!.description}",
                                  mediaUrl: widget.episode!.thumbnailUrl!.isNotEmpty?"${widget.episode!.thumbnailUrl!}":"",
                                );
                              }

                            },
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _afroBlack.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.share,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),

                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: _handleLike,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _afroBlack.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isLiked ? Icons.favorite : Icons.favorite_border,
                                color: _isLiked ? Colors.red : _afroWhite,
                                size: 24,
                              ),
                            ),
                          ),
                          SizedBox(width: 1),
                          Text(
                            widget.content.isSeries && _currentEpisode != null
                                ? '${_currentEpisode!.likes}'
                                : '${widget.content.likes}',
                            style: TextStyle(color: _afroWhite, fontSize: 16),
                          ),
                          SizedBox(width: 15),

                          // Affichage des vues
                          Icon(Icons.visibility, color: _afroWhite, size: 24),
                          SizedBox(width: 2),
                          Text(
                            widget.content.isSeries && _currentEpisode != null
                                ? '${_currentEpisode!.views}'
                                : '${widget.content.views}',
                            style: TextStyle(color: _afroWhite, fontSize: 16),
                          ),
                          Spacer(),

                          if (!widget.content.isFree && (!widget.content.isSeries ||
                              (widget.content.isSeries && _currentEpisode != null && !_currentEpisode!.isFree)))
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _afroYellow.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _afroYellow),
                              ),
                              child: Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: _afroYellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 10),

                      // Sélecteur d'épisodes pour les séries
                      // if (widget.content.isSeries) _buildEpisodeSelector(),

                      Text(
                        widget.content.isSeries && _currentEpisode != null
                            ? _currentEpisode!.description
                            : widget.content.description!,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Message de soutien aux artistes
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _afroGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _afroGreen.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.favorite, color: _afroGreen, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Soutenez les créateurs',
                                  style: TextStyle(
                                    color: _afroGreen,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'En achetant ce contenu, vous soutenez directement les artistes et leur permettez de créer plus de vidéos de qualité.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      if (!canWatch)
                        Container(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: _afroBlack,
                              backgroundColor: _afroYellow,
                              padding: EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _isPurchasing ? null : _handlePurchase,
                            child: _isPurchasing
                                ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: _afroBlack,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              'SOUTENIR LES CRÉATEURS - ${widget.content.price} F',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else if (_isVideoInitialized)
                        Container(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: _afroWhite,
                              backgroundColor: _afroGreen,
                              padding: EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () {
                              if (_chewieController.isPlaying) {
                                _chewieController.pause();
                              } else {
                                _chewieController.play();
                              }
                            },
                            child: Text(
                              _chewieController.isPlaying ? 'PAUSER' : 'JOUER',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: 20),

                      if ((widget.content.isSeries ? widget.content.hashtags!: widget.content.hashtags) != null &&
                          (widget.content.isSeries ? widget.content.hashtags!.isNotEmpty : widget.content.hashtags!.isNotEmpty))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tags:',
                              style: TextStyle(
                                color: _afroWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: (widget.content.isSeries && _currentEpisode != null
                                  ? widget.content.hashtags!
                                  : widget.content.hashtags!).map((hashtag) {
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _afroGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _afroGreen),
                                  ),
                                  child: Text(
                                    '#$hashtag',
                                    style: TextStyle(color: _afroGreen),
                                  ),
                                );
                              }).toList(),
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

          // Animation like au centre de l'écran
          if (_showLikeAnimation)
            Positioned.fill(
              child: Center(
                child: IgnorePointer(
                  child: AnimatedScale(
                    scale: _isLikedAnimation ? 1.5 : 1.0,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 100,
                    ),
                  ),
                ),
              ),
            ),

          // Animation de vue discrète en haut
          Positioned(
            top: 100,
            right: 20,
            child: Visibility(
              visible: (widget.content.isSeries && _currentEpisode != null
                  ? _currentEpisode!.views > 0
                  : widget.content.views != null && widget.content.views! > 0),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _afroBlack.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: _afroWhite, size: 14),
                    SizedBox(width: 4),
                    Text(
                      widget.content.isSeries && _currentEpisode != null
                          ? '${_currentEpisode!.views}'
                          : '${widget.content.views}',
                      style: TextStyle(color: _afroWhite, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Couleurs thématiques (à adapter selon votre thème)
const Color _afroBlack = Color(0xFF121212);
const Color _afroWhite = Color(0xFFFFFFFF);
const Color _afroGreen = Color(0xFF00C853);
const Color _afroYellow = Color(0xFFFFD600);
// Couleurs de l'application AfroLook
// const _afroGreen = Color(0xFF2ECC71);
// const _afroDarkGreen = Color(0xFF27AE60);
// const _afroYellow = Color(0xFFF1C40F);
// const _afroBlack = Color(0xFF2C3E50);
// const _afroWhite = Color(0xFFFFFFFF);

// Ajoutez cet enum dans votre fichier model_data.dart ou contentProvider.dart
enum PurchaseResult {
  success,
  insufficientBalance,
  alreadyPurchased,
  error
}