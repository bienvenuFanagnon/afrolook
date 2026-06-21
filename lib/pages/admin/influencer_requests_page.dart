import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';

class InfluencerRequestsPage extends StatefulWidget {
  const InfluencerRequestsPage({super.key});

  @override
  State<InfluencerRequestsPage> createState() => _InfluencerRequestsPageState();
}

class _InfluencerRequestsPageState extends State<InfluencerRequestsPage>
    with SingleTickerProviderStateMixin {
  late AppColors _colors;
  late TabController _tabController;
  late UserAuthProvider _auth;

  final _firestore = FirebaseFirestore.instance;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<UserAuthProvider>(context, listen: false);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamRequests(String status) {
    return _firestore
        .collection('InfluenceurRequests')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _processRequest(
    Map<String, dynamic> data,
    String docId,
    bool approve,
    String note,
  ) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final newStatus = approve ? 'approved' : 'rejected';

      await _firestore.collection('InfluenceurRequests').doc(docId).update({
        'status': newStatus,
        'adminNote': note,
        'processedAt': now,
        'processedBy': _auth.loginUserData.id,
      });

      if (approve) {
        await _firestore.collection('Users').doc(data['userId'] as String).update({
          'is_influencer': true,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve
              ? 'Demande approuvée — compte influenceur activé'
              : 'Demande refusée'),
          backgroundColor: approve ? Colors.green : Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showActionDialog(Map<String, dynamic> data, String docId) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Traiter la demande',
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRequestSummary(data),
            const SizedBox(height: 16),
            Text('Note admin (optionnel)',
                style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                hintText: 'Raison du refus ou message...',
                hintStyle: TextStyle(color: _colors.textSecondary),
                filled: true,
                fillColor: _colors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: _colors.textPrimary, fontSize: 13),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              _processRequest(data, docId, false, noteCtrl.text.trim());
            },
            child: const Text('Refuser'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              _processRequest(data, docId, true, noteCtrl.text.trim());
            },
            child: const Text('Approuver'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSummary(Map<String, dynamic> data) {
    final imageUrl = data['imageUrl'] as String? ?? '';
    final pseudo = data['pseudo'] as String? ?? '';
    final followers = data['followerCount'] as int? ?? 0;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _colors.surfaceVariant,
          backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
          child: imageUrl.isEmpty ? Icon(Icons.person, color: _colors.textSecondary) : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@$pseudo',
                style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            Text('$followers abonné${followers > 1 ? 's' : ''}',
                style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Demandes Influenceur',
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _colors.primary,
          unselectedLabelColor: _colors.textSecondary,
          indicatorColor: _colors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'En attente'),
            Tab(text: 'Approuvées'),
            Tab(text: 'Refusées'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList('pending'),
          _buildList('approved'),
          _buildList('rejected'),
        ],
      ),
    );
  }

  Widget _buildList(String status) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamRequests(status),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border_rounded, size: 56, color: _colors.textSecondary),
                const SizedBox(height: 12),
                Text('Aucune demande',
                    style: TextStyle(color: _colors.textSecondary, fontSize: 15)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) => _buildRequestCard(docs[i]),
        );
      },
    );
  }

  Widget _buildRequestCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final imageUrl = data['imageUrl'] as String? ?? '';
    final pseudo = data['pseudo'] as String? ?? '';
    final followers = data['followerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'pending';
    final adminNote = data['adminNote'] as String?;
    final createdAt = data['createdAt'] as int? ?? 0;

    final date = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final dateStr = '${date.day}/${date.month}/${date.year}';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.border.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _colors.surfaceVariant,
                  backgroundImage:
                      imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
                  child: imageUrl.isEmpty
                      ? Icon(Icons.person, color: _colors.textSecondary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@$pseudo',
                          style: TextStyle(
                              color: _colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text('$followers abonné${followers > 1 ? 's' : ''}',
                          style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status == 'pending'
                            ? 'En attente'
                            : status == 'approved'
                                ? 'Approuvée'
                                : 'Refusée',
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: _colors.textSecondary),
                const SizedBox(width: 4),
                Text('Demande du $dateStr',
                    style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
              ],
            ),
            if (adminNote != null && adminNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notes_rounded, size: 14, color: _colors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(adminNote,
                          style: TextStyle(color: _colors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.gavel_rounded, size: 18),
                  label: const Text('Traiter cette demande',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: _processing ? null : () => _showActionDialog(data, doc.id),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
