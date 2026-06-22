import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'livesAgora.dart';

class LiveEndedPage extends StatelessWidget {
  final PostLive live;

  const LiveEndedPage({super.key, required this.live});

  String _formatDuration() {
    if (live.endTime == null) return '--';
    final d = live.endTime!.difference(live.startTime);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(live.startTime);
    final totalViewers = live.totalspectateurs.length;
    final coins = live.giftCoinsTotal > 0 ? live.giftCoinsTotal : live.giftTotal.toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Stack(
        children: [
          // Fond dégradé
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // AppBar custom
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Bannière live terminé
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Ce live est terminé', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 14)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Avatar hôte
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white12,
                          backgroundImage: live.hostImage != null && live.hostImage!.isNotEmpty
                              ? CachedNetworkImageProvider(live.hostImage!)
                              : null,
                          child: live.hostImage == null || live.hostImage!.isEmpty
                              ? const Icon(Icons.person, color: Colors.white54, size: 40)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '@${live.hostName ?? ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          live.title,
                          style: const TextStyle(color: Colors.white60, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 12)),

                        const SizedBox(height: 28),

                        // Stats grid
                        _StatGrid(children: [
                          _StatTile(icon: Icons.people_rounded, label: 'Spectateurs', value: '$totalViewers', color: Colors.blueAccent),
                          _StatTile(icon: Icons.favorite_rounded, label: 'Likes', value: '${live.likeCount ?? 0}', color: Colors.pinkAccent),
                          _StatTile(icon: Icons.stars_rounded, label: 'Pièces', value: '$coins pcs', color: const Color(0xFFF9A825)),
                          _StatTile(icon: Icons.share_rounded, label: 'Partages', value: '${live.shareCount}', color: Colors.greenAccent),
                          _StatTile(icon: Icons.timer_rounded, label: 'Durée', value: _formatDuration(), color: Colors.purpleAccent),
                          _StatTile(icon: Icons.mic_rounded, label: 'Participants', value: '${live.participants.length}', color: Colors.tealAccent),
                        ]),

                        if (live.paidParticipationTotal > 0) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.payment, color: Colors.greenAccent, size: 18),
                                const SizedBox(width: 10),
                                const Text('Entrées payantes', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                const Spacer(),
                                Text(
                                  '${live.paidParticipationTotal.toStringAsFixed(0)} FCFA',
                                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final List<Widget> children;
  const _StatGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: children,
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
