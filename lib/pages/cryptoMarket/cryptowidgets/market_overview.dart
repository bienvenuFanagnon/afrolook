import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../../providers/crypto_market_provider.dart';

class MarketOverview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CryptoMarketProvider>(
      builder: (context, provider, child) {
        final isPositive = provider.marketChange24h >= 0;
        final marketColor = isPositive ? Color(0xFF00B894) : Color(0xFFE84393);

        return Container(
          margin: EdgeInsets.all(20),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E2A3B),
                Color(0xFF131A26),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Color(0xFF00B894).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Iconsax.chart_2,
                              color: Color(0xFF00B894),
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'MARCHÉ GLOBAL',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        '\$${_formatMarketCap(provider.totalMarketCap)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPositive
                            ? [Color(0xFF00B894).withOpacity(0.3), Color(0xFF00B894).withOpacity(0.1)]
                            : [Color(0xFFE84393).withOpacity(0.3), Color(0xFFE84393).withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: marketColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPositive ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                          color: marketColor,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${(provider.marketChange24h * 100).toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: marketColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      marketColor.withOpacity(0.8),
                      marketColor.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMarketStat('Actifs', '${provider.cryptos.length}', Iconsax.coin),
                  _buildMarketStat('Volume 24h', '\$${_formatVolume(provider.cryptos.fold(0, (sum, crypto) => sum + crypto.dailyVolume))}', Iconsax.graph),
                  _buildMarketStat('Top Gainer', '+12.5%', Iconsax.trend_up),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarketStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF2A3649).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Color(0xFF00B894),
            size: 16,
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _formatMarketCap(double marketCap) {
    if (marketCap >= 1e12) {
      return '${(marketCap / 1e12).toStringAsFixed(2)}T';
    } else if (marketCap >= 1e9) {
      return '${(marketCap / 1e9).toStringAsFixed(2)}B';
    } else if (marketCap >= 1e6) {
      return '${(marketCap / 1e6).toStringAsFixed(2)}M';
    }
    return marketCap.toStringAsFixed(0);
  }

  String _formatVolume(double volume) {
    if (volume >= 1e9) {
      return '${(volume / 1e9).toStringAsFixed(1)}B';
    } else if (volume >= 1e6) {
      return '${(volume / 1e6).toStringAsFixed(1)}M';
    }
    return volume.toStringAsFixed(0);
  }
}