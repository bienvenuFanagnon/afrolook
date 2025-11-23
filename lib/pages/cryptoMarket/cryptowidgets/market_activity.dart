import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class MarketActivity extends StatefulWidget {
  @override
  _MarketActivityState createState() => _MarketActivityState();
}

class _MarketActivityState extends State<MarketActivity> {
  final List<Map<String, dynamic>> _activities = [
    {
      'user': 'Alexandre M.',
      'action': 'a acheté',
      'amount': '0.5 BTC',
      'profit': '2,500',
      'time': '2 min',
      'type': 'buy',
      'avatar': 'A',
    },
    {
      'user': 'Sophie K.',
      'action': 'a vendu',
      'amount': '150 ETH',
      'profit': '15,000',
      'time': '5 min',
      'type': 'sell',
      'avatar': 'S',
    },
    {
      'user': 'Mohamed D.',
      'action': 'a acheté',
      'amount': '5,000 ADA',
      'profit': '750',
      'time': '8 min',
      'type': 'buy',
      'avatar': 'M',
    },
    {
      'user': 'Isabelle S.',
      'action': 'a vendu',
      'amount': '1.2 BNB',
      'profit': '320',
      'time': '12 min',
      'type': 'sell',
      'avatar': 'I',
    },
    {
      'user': 'David L.',
      'action': 'a acheté',
      'amount': '25,000 XRP',
      'profit': '1,250',
      'time': '15 min',
      'type': 'buy',
      'avatar': 'D',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.activity,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'ACTIVITÉ RÉCENTE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF2A3649).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    color: Color(0xFF00B894),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Color(0xFF1A202C).withOpacity(0.8),
            ),
            child: Column(
              children: _activities.map((activity) => _buildActivityItem(activity)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final isBuy = activity['type'] == 'buy';
    final avatarColors = [
      [Color(0xFFFF6B9D), Color(0xFFF54B64)],
      [Color(0xFF667EEA), Color(0xFF764BA2)],
      [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      [Color(0xFF43E97B), Color(0xFF38F9D7)],
      [Color(0xFFFA709A), Color(0xFFFEE140)],
    ];

    final colors = avatarColors[_activities.indexOf(activity) % avatarColors.length];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: _activities.indexOf(activity) < _activities.length - 1
              ? BorderSide(
            color: Color(0xFF2A3649).withOpacity(0.5),
            width: 1,
          )
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                activity['avatar'],
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),

          // Activity details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${activity['user']} ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: '${activity['action']} ',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: activity['amount'],
                        style: TextStyle(
                          color: isBuy ? Color(0xFF00B894) : Color(0xFFE84393),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  activity['time'],
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Profit
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+\$${activity['profit']}',
                style: TextStyle(
                  color: Color(0xFF00B894),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isBuy
                      ? Color(0xFF00B894).withOpacity(0.1)
                      : Color(0xFFE84393).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isBuy
                        ? Color(0xFF00B894).withOpacity(0.3)
                        : Color(0xFFE84393).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isBuy ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                      color: isBuy ? Color(0xFF00B894) : Color(0xFFE84393),
                      size: 10,
                    ),
                    SizedBox(width: 4),
                    Text(
                      isBuy ? 'ACHAT' : 'VENTE',
                      style: TextStyle(
                        color: isBuy ? Color(0xFF00B894) : Color(0xFFE84393),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}