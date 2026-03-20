// widgets/pronostics_carousel_widget.dart
import 'package:afrotok/pages/pronostics/pronostics_feed_page.dart';
import 'package:afrotok/pages/pronostics/pronostic_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../models/model_data.dart';

class PronosticsCarouselWidget extends StatefulWidget {
  const PronosticsCarouselWidget({Key? key}) : super(key: key);

  @override
  State<PronosticsCarouselWidget> createState() => _PronosticsCarouselWidgetState();
}

class _PronosticsCarouselWidgetState extends State<PronosticsCarouselWidget> {
  List<Pronostic> _pronostics = [];
  bool _isLoading = true;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  // Couleurs
  final Color _primaryColor = const Color(0xFFE21221); // Rouge
  final Color _secondaryColor = const Color(0xFFFFD600); // Jaune
  final Color _backgroundColor = const Color(0xFF121212); // Noir
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;

  @override
  void initState() {
    super.initState();
    _loadPronostics();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPronostics() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Pronostics')
          .where('statut', whereIn: ['OUVERT', 'EN_COURS'])
          .orderBy('dateCreation', descending: true)
          .limit(3)
          .get();

      List<Pronostic> pronostics = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        data['id'] = doc.id;
        var pronostic = Pronostic.fromJson(data);

        // Charger le post associé pour les stats
        if (pronostic.postId.isNotEmpty) {
          final postDoc = await FirebaseFirestore.instance
              .collection('Posts')
              .doc(pronostic.postId)
              .get();
          if (postDoc.exists) {
            pronostic.post = Post.fromJson(postDoc.data()!);
          }
        }

        pronostics.add(pronostic);
      }

      setState(() {
        _pronostics = pronostics;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement pronostics carousel: $e');
      setState(() => _isLoading = false);
    }
  }

  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
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

  double _getMaxCagnotte() {
    if (_pronostics.isEmpty) return 0;
    return _pronostics.map((p) => p.cagnotte).reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 160,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _secondaryColor.withOpacity(0.3),
            width: 1.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _cardColor,
              _cardColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animation de chargement stylisée
            LoadingAnimationWidget.flickr(
              size: 40,
              leftDotColor: _primaryColor,
              rightDotColor: _secondaryColor,
            ),
            const SizedBox(height: 12),

            // Texte accrocheur
            Text(
              '⚽ Pronostics du moment',
              style: TextStyle(
                color: _secondaryColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Jouez et gagnez jusqu\'à 50 000 FCFA',
              style: TextStyle(
                color: _hintColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    if (_pronostics.isEmpty) {
      return const SizedBox.shrink();
    }else{
      _pronostics.shuffle();
    }

    final maxCagnotte = _getMaxCagnotte();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec titre accrocheur
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.2),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _secondaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.chart, color: Colors.black, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚽ Pronostics & Betting',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (maxCagnotte > 0)
                        Text(
                          'Jouez et gagnez jusqu\'à ${_formatCagnotte(maxCagnotte)} FCFA',
                          style: TextStyle(
                            color: _secondaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PronosticsFeedPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _secondaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _secondaryColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Voir tout',
                          style: TextStyle(
                            color: _secondaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, color: _secondaryColor, size: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Carousel
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _pronostics.length,
              itemBuilder: (context, index) {
                final pronostic = _pronostics[index];
                return _buildCarouselItem(pronostic);
              },
            ),
          ),

          // Indicateurs de page
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pronostics.length,
                    (index) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? _secondaryColor
                        : _secondaryColor.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(Pronostic pronostic) {
    final post = pronostic.post;

    return GestureDetector(
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
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _secondaryColor.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Équipes
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _buildMiniLogo(pronostic.equipeA.urlLogo),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pronostic.equipeA.nom,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            pronostic.equipeB.nom,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildMiniLogo(pronostic.equipeB.urlLogo),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Cagnotte seulement si > 0
              if (pronostic.cagnotte > 0) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _secondaryColor,
                            _secondaryColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.money, color: Colors.black, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            // '${_formatCagnotte(pronostic.cagnotte)} FCFA à partager',
                            '${pronostic.cagnotte} FCFA à partager',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Stats et participants
              Row(
                children: [
                  // Participants
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.people, color: Colors.blue, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          '${pronostic.nombreParticipants}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Stats du post
                  if (post != null) ...[
                    Row(
                      children: [
                        Icon(Iconsax.eye, color: _hintColor, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          formatNumber(post.vues ?? 0),
                          style: TextStyle(color: _hintColor, fontSize: 9),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Row(
                      children: [
                        Icon(Iconsax.heart, color: Colors.red, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          formatNumber(post.loves ?? 0),
                          style: TextStyle(color: _hintColor, fontSize: 9),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Row(
                      children: [
                        Icon(Iconsax.message, color: Colors.green, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          formatNumber(post.comments ?? 0),
                          style: TextStyle(color: _hintColor, fontSize: 9),
                        ),
                      ],
                    ),
                  ],

                  const Spacer(),

                  // Badge statut
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pronostic.statut == PronosticStatut.OUVERT
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pronostic.statut == PronosticStatut.OUVERT
                            ? Colors.green
                            : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      pronostic.statut == PronosticStatut.OUVERT ? 'OUVERT' : 'EN COURS',
                      style: TextStyle(
                        color: pronostic.statut == PronosticStatut.OUVERT
                            ? Colors.green
                            : Colors.orange,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Bouton jouer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Jouer maintenant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, color: Colors.white, size: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniLogo(String url) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _secondaryColor.withOpacity(0.3), width: 0.5),
      ),
      child: url.isNotEmpty && url != 'https://via.placeholder.com/150'
          ? ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(MaterialIcons.sports_soccer, color: _hintColor, size: 12);
          },
        ),
      )
          : Icon(MaterialIcons.sports_soccer, color: _hintColor, size: 12),
    );
  }
}