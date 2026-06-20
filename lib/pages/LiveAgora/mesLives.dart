import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';

import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import 'livePage.dart';
import 'livesAgora.dart';

class UserLivesPage extends StatefulWidget {
  @override
  _UserLivesPageState createState() => _UserLivesPageState();
}

class _UserLivesPageState extends State<UserLivesPage> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<PostLive> _userLives = [];
  bool _isLoading = true;
  Map<String, bool> _processingDeletion = {};

  @override
  void initState() {
    super.initState();
    _loadUserLives();
  }

  Future<void> _loadUserLives() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final querySnapshot = await _firestore
          .collection('lives')
          .where('hostId', isEqualTo: user.uid)
          .orderBy('startTime', descending: true)
          .get();
      setState(() {
        _userLives = querySnapshot.docs.map((doc) => PostLive.fromMap(doc.data())).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onRefresh() async {
    await _loadUserLives();
    _refreshController.refreshCompleted();
  }

  Future<void> _deleteLive(PostLive live) async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _processingDeletion[live.liveId!] = true);
    try {
      if (live.isLive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de supprimer un live en cours'), backgroundColor: Colors.red),
        );
        return;
      }
      await _firestore.collection('lives').doc(live.liveId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live supprimé avec succès'), backgroundColor: Colors.green),
      );
      await _loadUserLives();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _processingDeletion.remove(live.liveId));
    }
  }

  void _showDeleteConfirmation(PostLive live) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
        title: Text('Supprimer le live', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer ce live ?\nCette action est irréversible.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _deleteLive(live); },
            style: ElevatedButton.styleFrom(backgroundColor: colors.danger),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Mes Lives', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700)),
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.accent),
            onPressed: _loadUserLives,
          ),
        ],
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        enablePullDown: true,
        header: WaterDropHeader(
          waterDropColor: colors.accent,
          complete: Icon(Icons.check, color: colors.accent),
        ),
        child: _isLoading
            ? _buildLoadingState(colors)
            : _userLives.isEmpty
                ? _buildEmptyState(colors)
                : _buildLivesList(colors),
      ),
    );
  }

  Widget _buildLoadingState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colors.accent),
          const SizedBox(height: 16),
          Text('Chargement de vos lives...', style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_rounded, size: 64, color: colors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('Aucun live créé', style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Commencez par créer votre premier live !', style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildLivesList(AppColors colors) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userLives.length,
      itemBuilder: (context, index) => _buildLiveItem(_userLives[index], colors),
    );
  }

  Widget _buildLiveItem(PostLive live, AppColors colors) {
    final authProvider = context.watch<UserAuthProvider>();
    final isLive = live.isLive;
    final isHost = live.hostId == authProvider.userId;
    final isInvited = live.invitedUsers.contains(authProvider.userId);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final hasPinnedText = live.pinnedText != null && live.pinnedText!.isNotEmpty;
    final totalSpectateurs = live.totalspectateurs.length;
    final totalSpectateursSeuls = live.spectators.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? colors.danger.withOpacity(0.7) : colors.border,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // En-tête image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: (live.coverImage?.isNotEmpty == true || live.hostImage?.isNotEmpty == true)
                      ? Image.network(
                          live.coverImage?.isNotEmpty == true ? live.coverImage! : live.hostImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: colors.surfaceVariant),
                        )
                      : Container(color: colors.surfaceVariant),
                ),
                if (!isLive)
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.black45,
                  ),
                // Badge statut
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLive ? colors.danger : Colors.grey[700],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isLive ? Icons.circle : Icons.check_circle, color: Colors.white, size: 8),
                        const SizedBox(width: 4),
                        Text(
                          isLive ? 'LIVE' : 'TERMINÉ',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                // Badge live privé
                if (live.isPaidLive)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, color: Colors.white, size: 10),
                          SizedBox(width: 2),
                          Text('PRIVÉ', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (hasPinnedText) Icon(Icons.push_pin, color: colors.accent, size: 12),
                    if (hasPinnedText) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        live.title,
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(live.startTime),
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(Icons.people_rounded, isLive ? 'Spectateurs' : 'Total', isLive ? '${live.viewerCount}' : '$totalSpectateurs', colors.info, colors),
                    _buildStatItem(Icons.favorite_rounded, 'Likes', '${live.likeCount ?? 0}', colors.danger, colors),
                    _buildStatItem(Icons.card_giftcard_rounded, 'Cadeaux', '${live.gifts.length}', colors.accent, colors),
                    _buildStatItem(Icons.share_rounded, 'Partages', '${live.shareCount}', colors.primary, colors),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (isLive) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => LivePage(
                                liveId: live.liveId!,
                                isHost: isHost,
                                hostName: live.hostName!,
                                hostImage: live.hostImage!,
                                isInvited: isInvited,
                                postLive: live,
                              ),
                            ));
                          } else {
                            _showLiveDetailsDialog(live);
                          }
                        },
                        icon: Icon(isLive ? Icons.play_arrow_rounded : Icons.bar_chart_rounded, size: 16),
                        label: Text(isLive ? 'Rejoindre' : 'Voir détails'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLive ? colors.danger : colors.primary,
                          foregroundColor: isLive ? Colors.white : colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (!isLive) ...[
                      const SizedBox(width: 8),
                      _processingDeletion[live.liveId] == true
                          ? SizedBox(
                              width: 40, height: 40,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: CircularProgressIndicator(color: colors.danger, strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              onPressed: () => _showDeleteConfirmation(live),
                              icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
                              tooltip: 'Supprimer le live',
                            ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Pied de carte : pièces
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.stars_rounded, color: colors.accent, size: 18),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pièces reçues', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                    Text(
                      '${live.giftCoinsTotal > 0 ? live.giftCoinsTotal : live.giftTotal.toInt()} pcs',
                      style: TextStyle(color: colors.accent, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                if (live.paidParticipationTotal > 0) ...[
                  Icon(Icons.payment_rounded, color: colors.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '+ ${live.paidParticipationTotal.toStringAsFixed(0)} FCFA',
                    style: TextStyle(color: colors.primary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color, AppColors colors) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 10)),
      ],
    );
  }

  void _showLiveDetailsDialog(PostLive live) {
    final colors = AppColors.of(context);
    final duration = _calculateDuration(live);
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final totalSpectateurs = live.totalspectateurs.length;
    final totalSpectateursSeuls = live.spectators.length;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Détails du Live',
                  style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  live.title,
                  style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 15),
              _buildDetailRow('Hôte :', live.hostName!, colors),
              _buildDetailRow('Début :', dateFormat.format(live.startTime), colors),
              if (live.endTime != null) _buildDetailRow('Durée :', duration, colors),
              const SizedBox(height: 15),
              Text('Audience', style: TextStyle(color: colors.info, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildStatCard('Total spectateurs', '$totalSpectateurs', Icons.people_rounded, colors.info, colors),
                  _buildStatCard('Spectateurs', '$totalSpectateursSeuls', Icons.visibility_rounded, colors.warning, colors),
                  _buildStatCard('Likes', '${live.likeCount ?? 0}', Icons.favorite_rounded, colors.danger, colors),
                  _buildStatCard('Cadeaux', '${live.gifts.length}', Icons.card_giftcard_rounded, colors.accent, colors),
                  _buildStatCard('Partages', '${live.shareCount}', Icons.share_rounded, colors.primary, colors),
                  if (live.isPaidLive)
                    _buildStatCard('Participations', '${live.paidParticipationTotal.toStringAsFixed(0)} FCFA', Icons.payment_rounded, Colors.purple, colors),
                ],
              ),
              const SizedBox(height: 15),
              // Pièces reçues
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.accent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars_rounded, color: colors.accent, size: 18),
                        const SizedBox(width: 6),
                        Text('Pièces reçues (cadeaux)', style: TextStyle(color: colors.accent, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${live.giftCoinsTotal > 0 ? live.giftCoinsTotal : live.giftTotal.toInt()} pcs',
                      style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (live.paidParticipationTotal > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '+ ${live.paidParticipationTotal.toStringAsFixed(0)} FCFA (entrées payantes)',
                          style: TextStyle(color: colors.primary, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              if (live.isPaidLive) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, color: Colors.purpleAccent, size: 16),
                      SizedBox(width: 8),
                      Text('Live Privé — Accès payant', style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.surfaceVariant,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text('Fermer', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, AppColors colors) {
    return Container(
      decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(color: colors.textSecondary, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _calculateDuration(PostLive live) {
    final end = live.endTime ?? DateTime.now();
    final d = end.difference(live.startTime);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}
