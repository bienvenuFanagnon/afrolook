import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../models/crypto_model.dart';

class FeaturedCryptos extends StatelessWidget {
  final List<CryptoCurrency> cryptos;

  const FeaturedCryptos({Key? key, required this.cryptos}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B894), Color(0xFF00D4AA)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.star1,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'RECOMMANDÉS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Container(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: cryptos.length,
            itemBuilder: (context, index) {
              final crypto = cryptos[index];
              return _buildFeaturedCard(crypto);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(CryptoCurrency crypto) {
    final isPositive = crypto.dailyPriceChange >= 0;

    return Container(
      width: 280,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E2A3B),
            Color(0xFF131A26),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF2A3649).withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            // Logo and basic info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: crypto.imageUrl.isNotEmpty
                              ? DecorationImage(
                            image: NetworkImage(crypto.imageUrl),
                            fit: BoxFit.cover,
                          )
                              : null,
                          color: crypto.imageUrl.isEmpty ? Color(0xFF2A3649) : null,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            crypto.symbol.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            crypto.name,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF00B894).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Color(0xFF00B894).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '#${crypto.rank} Rank',
                      style: TextStyle(
                        color: Color(0xFF00B894),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Price and change
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '\$${crypto.currentPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isPositive ? Color(0xFF00B894) : Color(0xFFE84393),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
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
                SizedBox(height: 4),
                Text(
                  'Market Cap: \$${_formatMarketCap(crypto.marketCap)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatMarketCap(double marketCap) {
    if (marketCap >= 1e12) {
      return '${(marketCap / 1e12).toStringAsFixed(2)}T';
    } else if (marketCap >= 1e9) {
      return '${(marketCap / 1e9).toStringAsFixed(2)}B';
    }
    return '${(marketCap / 1e6).toStringAsFixed(2)}M';
  }
}