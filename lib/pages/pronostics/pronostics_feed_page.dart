// pages/pronostics/pronostics_feed_page.dart

import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/pronostic_provider.dart';
import 'package:afrotok/services/linkService.dart';
import 'package:afrotok/services/postService/feed_interaction_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import 'pronostic_detail_page.dart';

class PronosticsFeedPage extends StatefulWidget {
  const PronosticsFeedPage({Key? key}) : super(key: key);

  @override
  State<PronosticsFeedPage> createState() => _PronosticsFeedPageState();
}

class _PronosticsFeedPageState extends State<PronosticsFeedPage> with SingleTickerProviderStateMixin {
  late PronosticProvider _pronosticProvider;
  late UserAuthProvider _authProvider;
  late PostProvider _postProvider;

  // États
  bool _isLoading = false;
  bool _isLoadingHistory = false;
  bool _isInitialLoading = true;
  bool _hasMore = true;
  bool _hasMoreHistory = true;
  DocumentSnapshot? _lastDoc;
  DocumentSnapshot? _lastHistoryDoc;
  List<Pronostic> _pronostics = [];
  List<Pronostic> _historyPronostics = [];

  // Contrôleur pour le TabBar
  late TabController _tabController;

  // États pour les interactions
  final Map<String, bool> _isFavorite = {};
  final Map<String, bool> _isProcessingFavorite = {};
  final Map<String, bool> _isSharing = {};

  // Couleurs
  final Color _primaryColor = const Color(0xFFE21221); // Rouge
  final Color _secondaryColor = const Color(0xFFFFD600); // Jaune
  final Color _backgroundColor = const Color(0xFF121212); // Noir
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;
  Future<void> recordUniquePostView(Post post) async {

    String userId = _authProvider.loginUserData.id!;
    String postId = post.id!;
    try {
      final postRef = FirebaseFirestore.instance.collection('Posts').doc(postId);

      final postDoc = await postRef.get();

      if (!postDoc.exists) return;

      List usersViewed = postDoc.data()?['users_vue_id'] ?? [];

      // Vérifier si l'utilisateur a déjà vu
      if (usersViewed.contains(userId)) {
        print("⏭️ L'utilisateur a déjà vu ce post");
        return;
      }

      // Enregistrer la vue
      await postRef.update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([userId]),
      });

      print("✅ Vue enregistrée pour $userId");

    } catch (e) {
      print("Erreur enregistrement vue : $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _pronosticProvider = Provider.of<PronosticProvider>(context, listen: false);
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _postProvider = Provider.of<PostProvider>(context, listen: false);

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    _loadPronostics().then((_) {
      setState(() {
        _isInitialLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && _historyPronostics.isEmpty && !_isLoadingHistory && !_isInitialLoading) {
      _loadHistoryPronostics();
    }
  }

  // ========== CHARGEMENT DES DONNÉES ==========

  Future<void> _loadPronostics({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      setState(() {
        _pronostics = [];
        _lastDoc = null;
        _hasMore = true;
      });
    }

    if (!_hasMore && !refresh) return;

    setState(() => _isLoading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('Pronostics')
          .where('statut', whereIn: [PronosticStatut.OUVERT.name, PronosticStatut.EN_COURS.name])
          .orderBy('dateCreation', descending: true)
          .limit(3);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      List<Pronostic> nouveaux = [];
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        var pronostic = Pronostic.fromJson(data);

        if (pronostic.postId.isNotEmpty) {
          final postDoc = await FirebaseFirestore.instance
              .collection('Posts')
              .doc(pronostic.postId)
              .get();
          if (postDoc.exists) {
            pronostic.post = Post.fromJson(postDoc.data()!);
          }
        }

        nouveaux.add(pronostic);
      }

      setState(() {
        _pronostics.addAll(nouveaux);
        _lastDoc = snapshot.docs.last;
        _hasMore = snapshot.docs.length == 3;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement pronostics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistoryPronostics({bool refresh = false}) async {
    if (_isLoadingHistory) return;

    if (refresh) {
      setState(() {
        _historyPronostics = [];
        _lastHistoryDoc = null;
        _hasMoreHistory = true;
      });
    }

    if (!_hasMoreHistory && !refresh) return;

    setState(() => _isLoadingHistory = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('Pronostics')
          .where('statut', whereIn: [PronosticStatut.TERMINE.name, PronosticStatut.GAINS_DISTRIBUES.name])
          .orderBy('dateCreation', descending: true)
          .limit(3);

      if (_lastHistoryDoc != null) {
        query = query.startAfterDocument(_lastHistoryDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMoreHistory = false;
          _isLoadingHistory = false;
        });
        return;
      }

      List<Pronostic> nouveaux = [];
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        var pronostic = Pronostic.fromJson(data);

        if (pronostic.postId.isNotEmpty) {
          final postDoc = await FirebaseFirestore.instance
              .collection('Posts')
              .doc(pronostic.postId)
              .get();
          if (postDoc.exists) {
            pronostic.post = Post.fromJson(postDoc.data()!);
          }
        }

        nouveaux.add(pronostic);
      }

      setState(() {
        _historyPronostics.addAll(nouveaux);
        _lastHistoryDoc = snapshot.docs.last;
        _hasMoreHistory = snapshot.docs.length == 3;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('Erreur chargement historique: $e');
      setState(() => _isLoadingHistory = false);
    }
  }

  // ========== ACTIONS SUR LE POST ==========

  Future<void> _toggleFavorite(Post post) async {
    if (_isProcessingFavorite[post.id] == true) return;

    final userId = _authProvider.loginUserData.id!;
    final postId = post.id!;

    setState(() {
      _isProcessingFavorite[postId] = true;
    });

    try {
      final isFav = _isFavorite[postId] ?? false;

      if (isFav) {
        await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
          'users_favorite_id': FieldValue.arrayRemove([userId]),
          'favorites_count': FieldValue.increment(-1),
        });

        setState(() {
          _isFavorite[postId] = false;
          if (post.favoritesCount != null) {
            post.favoritesCount = post.favoritesCount! - 1;
          }
        });
      } else {
        await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
          'users_favorite_id': FieldValue.arrayUnion([userId]),
          'favorites_count': FieldValue.increment(1),
        });
        recordUniquePostView(post);
        setState(() {
          _isFavorite[postId] = true;
          if (post.favoritesCount != null) {
            post.favoritesCount = post.favoritesCount! + 1;
          }
        });
      }
    } catch (e) {
      print('Erreur toggle favori: $e');
    } finally {
      setState(() {
        _isProcessingFavorite[postId] = false;
      });
    }
  }

  Future<void> _handleLike(Post post) async {
    if (post.users_love_id?.contains(_authProvider.loginUserData.id) == true) return;

    try {
      setState(() {
        post.loves = (post.loves ?? 0) + 1;
        post.users_love_id ??= [];
        post.users_love_id!.add(_authProvider.loginUserData.id!);
      });

      await FirebaseFirestore.instance.collection('Posts').doc(post.id).update({
        'loves': FieldValue.increment(1),
        'users_love_id': FieldValue.arrayUnion([_authProvider.loginUserData.id]),
      });

      FeedInteractionService.onPostLoved(post, _authProvider.loginUserData.id!);
      recordUniquePostView(post);
    } catch (e) {
      print("Erreur like: $e");
    }
  }

  Future<void> _handleShare(Post post) async {
    if (_isSharing[post.id] == true) return;

    setState(() {
      _isSharing[post.id!] = true;
    });

    try {
      final AppLinkService _appLinkService = AppLinkService();
      String shareImageUrl = (post.images?.isNotEmpty ?? false)
          ? post.images!.first
          : "";

      await _appLinkService.shareContent(
        type: AppLinkType.post,
        id: post.id!,
        message: post.description ?? "Pronostic",
        mediaUrl: shareImageUrl,
      );

      setState(() {
        post.partage = (post.partage ?? 0) + 1;
        post.users_partage_id ??= [];
        post.users_partage_id!.add(_authProvider.loginUserData.id!);
      });

      await FirebaseFirestore.instance.collection('Posts').doc(post.id).update({
        'partage': FieldValue.increment(1),
        'users_partage_id': FieldValue.arrayUnion([_authProvider.loginUserData.id]),
      });
      recordUniquePostView(post);
    } catch (e) {
      print("Erreur partage: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSharing[post.id!] = false;
        });
      }
    }
  }

  // ========== FORMATAGE ==========

  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }

  String _getStatutText(PronosticStatut statut) {
    switch (statut) {
      case PronosticStatut.OUVERT:
        return '🔓 Ouvert';
      case PronosticStatut.EN_COURS:
        return '⚽ En cours';
      case PronosticStatut.TERMINE:
        return '✅ Terminé';
      case PronosticStatut.GAINS_DISTRIBUES:
        return '💰 Distribué';
    }
  }

  Color _getStatutColor(PronosticStatut statut) {
    switch (statut) {
      case PronosticStatut.OUVERT:
        return Colors.green;
      case PronosticStatut.EN_COURS:
        return Colors.orange;
      case PronosticStatut.TERMINE:
        return Colors.blue;
      case PronosticStatut.GAINS_DISTRIBUES:
        return Colors.purple;
    }
  }

  String _formatCagnotte(double cagnotte) {
    if (cagnotte >= 1000000) {
      return '${(cagnotte / 1000000).toStringAsFixed(1)}M';
    } else if (cagnotte >= 1000) {
      return '${(cagnotte / 1000).toStringAsFixed(1)}k';
    }
    return cagnotte.toStringAsFixed(0);
  }

  // ========== WIDGETS ==========

  Widget _buildLoadingWidget() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _secondaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.flickr(
            size: 50,
            leftDotColor: _primaryColor,
            rightDotColor: _secondaryColor,
          ),
          const SizedBox(height: 16),
          const Text(
            '⚽ Pronostics du moment',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mets ton pronostic et tente de remporter',
            style: TextStyle(color: _hintColor, fontSize: 13),
          ),
          Text(
            'la cagnotte de plus de 50 000 FCFA !',
            style: TextStyle(
              color: _secondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPronosticCard(Pronostic pronostic) {
    final post = pronostic.post;
    if (post == null) return const SizedBox();

    final isFav = _isFavorite[post.id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _secondaryColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec équipes
              Row(
                children: [
                  // Équipe A
                  Expanded(
                    child: Row(
                      children: [
                        _buildTeamLogo(pronostic.equipeA.urlLogo, size: 45),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pronostic.equipeA.nom,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (pronostic.scoreFinalEquipeA != null)
                                Text(
                                  'Score: ${pronostic.scoreFinalEquipeA}',
                                  style: TextStyle(
                                    color: _primaryColor,
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

                  // VS
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Équipe B
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                pronostic.equipeB.nom,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (pronostic.scoreFinalEquipeB != null)
                                Text(
                                  '${pronostic.scoreFinalEquipeB}',
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTeamLogo(pronostic.equipeB.urlLogo, size: 45),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Badges statut et cagnotte
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Badge statut
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getStatutColor(pronostic.statut).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatutColor(pronostic.statut),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pronostic.statut == PronosticStatut.OUVERT
                              ? Iconsax.lock_1
                              : Iconsax.clock,
                          size: 12,
                          color: _getStatutColor(pronostic.statut),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatutText(pronostic.statut),
                          style: TextStyle(
                            color: _getStatutColor(pronostic.statut),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cagnotte
                  if (pronostic.cagnotte > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _secondaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _secondaryColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.money, color: _secondaryColor, size: 12),
                          const SizedBox(width: 4),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${_formatCagnotte(pronostic.cagnotte)} F',
                                  style: TextStyle(
                                    color: _secondaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: ' à gagner',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Participants
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.people, color: Colors.blue, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${pronostic.nombreParticipants} participant${pronostic.nombreParticipants > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Stats du post
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Vues
                  _buildStatButton(
                    icon: Icons.remove_red_eye,
                    value: formatNumber(post.vues ?? 0),
                    color: Colors.yellow,
                    onTap: null,
                  ),

                  // Likes
                  _buildStatButton(
                    icon: Icons.favorite,
                    value: formatNumber(post.loves ?? 0),
                    color: post.users_love_id?.contains(_authProvider.loginUserData.id) == true
                        ? Colors.red
                        : Colors.yellow,
                    onTap: () => _handleLike(post),
                  ),

                  // Commentaires
                  _buildStatButton(
                    icon: Icons.comment,
                    value: formatNumber(post.comments ?? 0),
                    color: Colors.yellow,
                    onTap: () {

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostComments(post: post),
                        ),
                      );
                      recordUniquePostView(post);
                    },
                  ),

                  // Favoris
                  _buildStatButton(
                    icon: isFav ? Icons.bookmark : Icons.bookmark_border,
                    value: formatNumber(post.favoritesCount ?? 0),
                    color: isFav ? _secondaryColor : Colors.yellow,
                    onTap: () => _toggleFavorite(post),
                  ),

                  // Partages
                  _buildStatButton(
                    icon: Icons.share,
                    value: formatNumber(post.partage ?? 0),
                    color: Colors.yellow,
                    onTap: () => _handleShare(post),
                    isLoading: _isSharing[post.id] == true,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Bouton d'action
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PronosticDetailPage(
                        postId: pronostic.postId,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      pronostic.statut == PronosticStatut.TERMINE ? "VOIR RESULTAT":pronostic.statut == PronosticStatut.GAINS_DISTRIBUES ? "VOIR RESULTAT": 'JOUER MAINTENANT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamLogo(String url, {double size = 45}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: _secondaryColor.withOpacity(0.3), width: 1.5),
      ),
      child: url.isNotEmpty && url != 'https://via.placeholder.com/150'
          ? ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              MaterialIcons.sports_soccer,
              color: _hintColor,
              size: size * 0.5,
            );
          },
        ),
      )
          : Icon(
        MaterialIcons.sports_soccer,
        color: _hintColor,
        size: size * 0.5,
      ),
    );
  }

  Widget _buildStatButton({
    required IconData icon,
    required String value,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFFD600),
              ),
            )
          else
            Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.chart, size: 60, color: _hintColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: _hintColor, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Reviens plus tard pour de nouveaux pronostics !',
            style: TextStyle(color: _hintColor.withOpacity(0.7), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Iconsax.chart_2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pronostics',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _secondaryColor,
          labelColor: _secondaryColor,
          unselectedLabelColor: _hintColor,
          tabs: const [
            Tab(text: 'EN COURS'),
            Tab(text: 'HISTORIQUE'),
          ],
        ),
      ),
      body: _isInitialLoading
          ? _buildLoadingWidget()
          : TabBarView(
        controller: _tabController,
        children: [
          // Onglet "En cours"
          RefreshIndicator(
            onRefresh: () => _loadPronostics(refresh: true),
            color: _secondaryColor,
            backgroundColor: _cardColor,
            child: _pronostics.isEmpty && !_isLoading
                ? _buildEmptyState('Aucun pronostic en cours')
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pronostics.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _pronostics.length) {
                  if (_isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (_hasMore) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _loadPronostics();
                    });
                  }
                  return const SizedBox();
                }
                return _buildPronosticCard(_pronostics[index]);
              },
            ),
          ),

          // Onglet "Historique"
          RefreshIndicator(
            onRefresh: () => _loadHistoryPronostics(refresh: true),
            color: _secondaryColor,
            backgroundColor: _cardColor,
            child: _historyPronostics.isEmpty && !_isLoadingHistory
                ? _buildEmptyState('Aucun pronostic dans l\'historique')
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _historyPronostics.length + (_hasMoreHistory ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _historyPronostics.length) {
                  if (_isLoadingHistory) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (_hasMoreHistory) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _loadHistoryPronostics();
                    });
                  }
                  return const SizedBox();
                }
                return _buildPronosticCard(_historyPronostics[index]);
              },
            ),
          ),
        ],
      ),
    );
  }}