import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../models/crypto_model.dart';

class TrendingCryptos extends StatelessWidget {
  final List<CryptoCurrency> cryptos;

  const TrendingCryptos({Key? key, required this.cryptos}) : super(key: key);

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
                    colors: [Color(0xFFFF6B9D), Color(0xFFF54B64)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.trend_up,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'TRENDING NOW',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
              Spacer(),
              Text(
                'Voir tout',
                style: TextStyle(
                  color: Color(0xFF00B894),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Container(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: cryptos.length,
            itemBuilder: (context, index) {
              final crypto = cryptos[index];
              return _buildTrendingCard(crypto, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingCard(CryptoCurrency crypto, int index) {
    final isPositive = crypto.dailyPriceChange >= 0;
    final colors = [
      [Color(0xFF667EEA), Color(0xFF764BA2)],
      [Color(0xFFF093FB), Color(0xFFF5576C)],
      [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      [Color(0xFF43E97B), Color(0xFF38F9D7)],
      [Color(0xFFFA709A), Color(0xFFFEE140)],
    ];

    final cardColors = colors[index % colors.length];

    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12, left: index == 0 ? 4 : 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColors[0].withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        image: crypto.imageUrl.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(crypto.imageUrl),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: crypto.imageUrl.isEmpty
                          ? Center(
                        child: Text(
                          crypto.symbol.substring(0, 2),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                          : null,
                    ),
                    SizedBox(height: 12),
                    Text(
                      crypto.symbol.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      crypto.name,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                            color: Colors.white,
                            size: 10,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${(crypto.dailyPriceChange * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}