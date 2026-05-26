// widgets/post_gifts_list.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/coin_pack.dart';
import '../../providers/coin_gift_provider.dart';

enum CompactLevel {
  none,      // Version complète (icône + label + nombre)
  light,     // Version semi-compacte (icône + nombre)
  ultra,     // Version ultra-compacte (seulement icônes)
}

class PostGiftsList extends StatefulWidget {
  final String postId;
  final CompactLevel compactLevel;
  final bool sortByValue;
  final int maxDisplayItems;

  const PostGiftsList({
    Key? key,
    required this.postId,
    this.compactLevel = CompactLevel.light,
    this.sortByValue = true,
    this.maxDisplayItems = 10,
  }) : super(key: key);

  @override
  State<PostGiftsList> createState() => _PostGiftsListState();
}

class _PostGiftsListState extends State<PostGiftsList> {
  List<PostGift> _gifts = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  @override
  void didUpdateWidget(PostGiftsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      _loadGifts();
    }
  }

  Future<void> _loadGifts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
      final gifts = await coinProvider.getPostGifts(widget.postId);

      if (mounted) {
        setState(() {
          _gifts = gifts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur chargement cadeaux: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.compactLevel == CompactLevel.none
          ? const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
        ),
      )
          : const SizedBox.shrink();
    }

    if (_hasError || _gifts.isEmpty) {
      return const SizedBox.shrink();
    }

    switch (widget.compactLevel) {
      case CompactLevel.ultra:
        return _buildUltraCompactGiftsList(_gifts);
      case CompactLevel.light:
        return _buildLightCompactGiftsList(_gifts);
      case CompactLevel.none:
        return _buildFullGiftsList(_gifts);
    }
  }

  /// Grouper et trier les cadeaux
  List<PostGift> _groupAndSortGifts(List<PostGift> gifts) {
    final Map<String, PostGift> aggregated = {};

    for (var gift in gifts) {
      final key = '${gift.giftIcon}_${gift.giftLabel}_${gift.coinsAmount}';

      if (aggregated.containsKey(key)) {
        aggregated[key]!.quantity = (aggregated[key]!.quantity ?? 0) + 1;
      } else {
        aggregated[key] = PostGift(
          giftIcon: gift.giftIcon,
          giftLabel: gift.giftLabel,
          coinsAmount: gift.coinsAmount,
          quantity: 1,
        );
      }
    }

    var giftsList = aggregated.values.toList();

    if (widget.sortByValue) {
      giftsList.sort((a, b) {
        final aValue = (a.coinsAmount ?? 0) * (a.quantity ?? 1);
        final bValue = (b.coinsAmount ?? 0) * (b.quantity ?? 1);
        return bValue.compareTo(aValue);
      });
    }

    if (giftsList.length > widget.maxDisplayItems) {
      giftsList = giftsList.take(widget.maxDisplayItems).toList();
    }

    return giftsList;
  }

  /// ULTRA COMPACT : seulement les icônes (sans nombre)
  Widget _buildUltraCompactGiftsList(List<PostGift> gifts) {
    final groupedGifts = _groupAndSortGifts(gifts);
    final remainingCount = _getRemainingItemsCount(gifts);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          ...groupedGifts.map((gift) {
            return Container(
              padding: const EdgeInsets.all(2),
              child: Text(
                gift.giftIcon ?? '🎁',
                style: const TextStyle(fontSize: 10),
              ),
            );
          }),
          if (remainingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '+$remainingCount',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// LIGHT COMPACT : icône + nombre (petit format)
  Widget _buildLightCompactGiftsList(List<PostGift> gifts) {
    final groupedGifts = _groupAndSortGifts(gifts);
    final remainingCount = _getRemainingItemsCount(gifts);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          ...groupedGifts.map((gift) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(gift.giftIcon ?? '🎁', style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                  Text(
                    '${gift.quantity}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (remainingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
              ),
              child: Text(
                '+$remainingCount',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Version complète : icône + label + nombre
  Widget _buildFullGiftsList(List<PostGift> gifts) {
    final groupedGifts = _groupAndSortGifts(gifts);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.card_giftcard, color: Color(0xFFFFD700), size: 16),
              SizedBox(width: 8),
              Text(
                '🎁 Cadeaux reçus',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: groupedGifts.map((gift) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(gift.giftIcon ?? '🎁', style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      gift.giftLabel ?? 'Cadeau',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'x${gift.quantity}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Compter les items supplémentaires non affichés
  int _getRemainingItemsCount(List<PostGift> gifts) {
    final uniqueGifts = _groupAndSortGifts(gifts);
    final originalCount = _getUniqueGiftTypesCount(gifts);
    return originalCount - uniqueGifts.length;
  }

  int _getUniqueGiftTypesCount(List<PostGift> gifts) {
    final uniqueKeys = <String>{};
    for (var gift in gifts) {
      final key = '${gift.giftIcon}_${gift.giftLabel}_${gift.coinsAmount}';
      uniqueKeys.add(key);
    }
    return uniqueKeys.length;
  }
}

// // widgets/post_gifts_list.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../../models/coin_pack.dart';
// import '../../providers/coin_gift_provider.dart';
//
// enum CompactLevel {
//   none,      // Version complète (icône + label + nombre)
//   light,     // Version semi-compacte (icône + nombre)
//   ultra,     // Version ultra-compacte (seulement icônes)
// }
//
// class PostGiftsList extends StatelessWidget {
//   final String postId;
//   final CompactLevel compactLevel;  // 🔥 Niveau de compactage
//   final bool sortByValue;           // Trier par valeur
//   final int maxDisplayItems;        // Nombre max d'items à afficher
//
//   const PostGiftsList({
//     Key? key,
//     required this.postId,
//     this.compactLevel = CompactLevel.light,
//     this.sortByValue = true,
//     this.maxDisplayItems = 10,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final coinProvider = Provider.of<CoinGiftUserProvider>(context);
//
//     return StreamBuilder<List<PostGift>>(
//       stream: coinProvider.getPostGiftsStream(postId),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return compactLevel == CompactLevel.none
//               ? const Center(
//             child: SizedBox(
//               width: 24,
//               height: 24,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
//               ),
//             ),
//           )
//               : const SizedBox.shrink();
//         }
//
//         if (snapshot.hasError || !snapshot.hasData) {
//           return const SizedBox.shrink();
//         }
//
//         final gifts = snapshot.data!;
//         if (gifts.isEmpty) return const SizedBox.shrink();
//
//         // Choix du rendu selon le niveau de compactage
//         switch (compactLevel) {
//           case CompactLevel.ultra:
//             return _buildUltraCompactGiftsList(gifts);
//           case CompactLevel.light:
//             return _buildLightCompactGiftsList(gifts);
//           case CompactLevel.none:
//             return _buildFullGiftsList(gifts);
//         }
//       },
//     );
//   }
//
//   /// Grouper et trier les cadeaux
//   List<PostGift> _groupAndSortGifts(List<PostGift> gifts) {
//     final Map<String, PostGift> aggregated = {};
//
//     for (var gift in gifts) {
//       final key = '${gift.giftIcon}_${gift.giftLabel}_${gift.coinsAmount}';
//
//       if (aggregated.containsKey(key)) {
//         aggregated[key]!.quantity = (aggregated[key]!.quantity ?? 0) + 1;
//       } else {
//         aggregated[key] = PostGift(
//           giftIcon: gift.giftIcon,
//           giftLabel: gift.giftLabel,
//           coinsAmount: gift.coinsAmount,
//           quantity: 1,
//         );
//       }
//     }
//
//     var giftsList = aggregated.values.toList();
//
//     if (sortByValue) {
//       giftsList.sort((a, b) {
//         final aValue = (a.coinsAmount ?? 0) * (a.quantity ?? 1);
//         final bValue = (b.coinsAmount ?? 0) * (b.quantity ?? 1);
//         return bValue.compareTo(aValue);
//       });
//     }
//
//     if (giftsList.length > maxDisplayItems) {
//       giftsList = giftsList.take(maxDisplayItems).toList();
//     }
//
//     return giftsList;
//   }
//
//   /// 🔥 ULTRA COMPACT : seulement les icônes (sans nombre)
//   Widget _buildUltraCompactGiftsList(List<PostGift> gifts) {
//     final groupedGifts = _groupAndSortGifts(gifts);
//     final remainingCount = _getRemainingItemsCount(gifts);
//
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 2),
//       child: Wrap(
//         spacing: 2,
//         runSpacing: 2,
//         children: [
//           ...groupedGifts.map((gift) {
//             return Container(
//               padding: const EdgeInsets.all(2),
//               child: Text(
//                 gift.giftIcon ?? '🎁',
//                 style: const TextStyle(fontSize: 10),
//               ),
//             );
//           }),
//           if (remainingCount > 0)
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//               child: Text(
//                 '+$remainingCount',
//                 style: const TextStyle(
//                   color: Color(0xFFFFD700),
//                   fontSize: 8,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   /// 🔥 LIGHT COMPACT : icône + nombre (petit format)
//   Widget _buildLightCompactGiftsList(List<PostGift> gifts) {
//     final groupedGifts = _groupAndSortGifts(gifts);
//     final remainingCount = _getRemainingItemsCount(gifts);
//
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Wrap(
//         spacing: 4,
//         runSpacing: 4,
//         children: [
//           ...groupedGifts.map((gift) {
//             return Container(
//               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFFFD700).withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(gift.giftIcon ?? '🎁', style: const TextStyle(fontSize: 11)),
//                   const SizedBox(width: 3),
//                   Text(
//                     '${gift.quantity}',
//                     style: const TextStyle(
//                       color: Color(0xFFFFD700),
//                       fontSize: 10,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           }),
//           if (remainingCount > 0)
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//               decoration: BoxDecoration(
//                 color: Colors.black,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
//               ),
//               child: Text(
//                 '+$remainingCount',
//                 style: const TextStyle(
//                   color: Color(0xFFFFD700),
//                   fontSize: 10,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   /// Version complète : icône + label + nombre
//   Widget _buildFullGiftsList(List<PostGift> gifts) {
//     final groupedGifts = _groupAndSortGifts(gifts);
//
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF1A1A1A),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(Icons.card_giftcard, color: Color(0xFFFFD700), size: 16),
//               SizedBox(width: 8),
//               Text(
//                 '🎁 Cadeaux reçus',
//                 style: TextStyle(
//                   color: Color(0xFFFFD700),
//                   fontWeight: FontWeight.bold,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Wrap(
//             spacing: 12,
//             runSpacing: 10,
//             children: groupedGifts.map((gift) {
//               return Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: Colors.black,
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(gift.giftIcon ?? '🎁', style: const TextStyle(fontSize: 18)),
//                     const SizedBox(width: 8),
//                     Text(
//                       gift.giftLabel ?? 'Cadeau',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w500,
//                         fontSize: 13,
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFFFD700).withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Text(
//                         'x${gift.quantity}',
//                         style: const TextStyle(
//                           color: Color(0xFFFFD700),
//                           fontWeight: FontWeight.bold,
//                           fontSize: 12,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             }).toList(),
//           ),
//         ],
//       ),
//     );
//   }
//
//   /// Compter les items supplémentaires non affichés
//   int _getRemainingItemsCount(List<PostGift> gifts) {
//     final uniqueGifts = _groupAndSortGifts(gifts);
//     final originalCount = _getUniqueGiftTypesCount(gifts);
//     return originalCount - uniqueGifts.length;
//   }
//
//   int _getUniqueGiftTypesCount(List<PostGift> gifts) {
//     final uniqueKeys = <String>{};
//     for (var gift in gifts) {
//       final key = '${gift.giftIcon}_${gift.giftLabel}_${gift.coinsAmount}';
//       uniqueKeys.add(key);
//     }
//     return uniqueKeys.length;
//   }
// }