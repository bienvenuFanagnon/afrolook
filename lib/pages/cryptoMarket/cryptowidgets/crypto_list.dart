import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../models/crypto_model.dart';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class CryptoList extends StatelessWidget {
  final List<CryptoCurrency> cryptos;

  const CryptoList({Key? key, required this.cryptos}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final crypto = cryptos[index];
          return _buildCryptoItem(crypto, index);
        },
        childCount: cryptos.length,
      ),
    );
  }

  Widget _buildCryptoItem(CryptoCurrency crypto, int index) {
    final isPositive = crypto.dailyPriceChange >= 0;
    final rankColors = [
      Color(0xFFFFD700), // Gold for #1
      Color(0xFFC0C0C0), // Silver for #2
      Color(0xFFCD7F32), // Bronze for #3
      Color(0xFF00B894), // Green for others
    ];

    final rankColor = crypto.rank <= 3 ? rankColors[crypto.rank - 1] : rankColors[3];

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to crypto detail
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: rankColor.withOpacity(0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${crypto.rank}',
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Logo
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: crypto.imageUrl.isNotEmpty
                        ? DecorationImage(
                      image: NetworkImage(crypto.imageUrl),
                      fit: BoxFit.cover,
                    )
                        : null,
                    color: crypto.imageUrl.isEmpty ? Color(0xFF2A3649) : null,
                  ),
                  child: crypto.imageUrl.isEmpty
                      ? Center(
                    child: Icon(
                      Iconsax.coin,
                      color: Colors.white,
                      size: 20,
                    ),
                  )
                      : null,
                ),
                SizedBox(width: 12),

                // Name and Symbol
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crypto.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        crypto.symbol.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Price and Change
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${crypto.currentPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isPositive ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                          color: isPositive ? Color(0xFF00B894) : Color(0xFFE84393),
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${(crypto.dailyPriceChange * 100).toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: isPositive ? Color(0xFF00B894) : Color(0xFFE84393),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
}