// lib/pages/admin/dating/admin_profile_detail_page.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/dating_data.dart';
import '../../../models/model_data.dart';
import '../../../theme/app_colors.dart';

class AdminProfileDetailPage extends StatefulWidget {
  final DatingProfile profile;

  const AdminProfileDetailPage({Key? key, required this.profile}) : super(key: key);

  @override
  State<AdminProfileDetailPage> createState() => _AdminProfileDetailPageState();
}

class _AdminProfileDetailPageState extends State<AdminProfileDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late DatingProfile _profile;
  int _likesCount = 0;
  int _coupsDeCoeurCount = 0;
  int _connectionsCount = 0;
  int _messagesCount = 0;
  UserData? _userData;
  String? _subscriptionPlan;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _loadStats();
    _loadUserData();
    _loadSubscription();
  }

  Future<void> _loadStats() async {
    final likesSnapshot = await _firestore
        .collection('dating_likes')
        .where('toUserId', isEqualTo: _profile.userId)
        .count()
        .get();
    _likesCount = likesSnapshot.count ?? 0;

    final coupsSnapshot = await _firestore
        .collection('dating_coup_de_coeurs')
        .where('toUserId', isEqualTo: _profile.userId)
        .count()
        .get();
    _coupsDeCoeurCount = coupsSnapshot.count ?? 0;

    final connSnapshot = await _firestore
        .collection('dating_connections')
        .where('userId1', isEqualTo: _profile.userId)
        .count()
        .get();
    final connSnapshot2 = await _firestore
        .collection('dating_connections')
        .where('userId2', isEqualTo: _profile.userId)
        .count()
        .get();
    _connectionsCount = (connSnapshot.count ?? 0) + (connSnapshot2.count ?? 0);

    final messagesSnapshot = await _firestore
        .collection('dating_messages')
        .where('senderUserId', isEqualTo: _profile.userId)
        .count()
        .get();
    final messagesSnapshot2 = await _firestore
        .collection('dating_messages')
        .where('receiverUserId', isEqualTo: _profile.userId)
        .count()
        .get();
    _messagesCount = (messagesSnapshot.count ?? 0) + (messagesSnapshot2.count ?? 0);

    if (mounted) setState(() {});
  }

  Future<void> _loadUserData() async {
    final doc = await _firestore.collection('Users').doc(_profile.userId).get();
    if (doc.exists) {
      setState(() {
        _userData = UserData.fromJson(doc.data()!);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSubscription() async {
    try {
      final snapshot = await _firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: _profile.userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty && mounted) {
        setState(() => _subscriptionPlan = snapshot.docs.first.data()['planCode']?.toString());
      }
    } catch (e) {
      printVm('Erreur chargement abonnement: $e');
    }
  }

  Future<void> _approveVerification() async {
    setState(() => _isProcessing = true);
    try {
      await _firestore.collection('dating_profiles').doc(_profile.id).update({
        'isVerified': true,
        'verificationRequested': false,
        'verificationRequestedAt': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() {
        _profile = _profile.copyWith(isVerified: true, verificationRequested: false);
        _isProcessing = false;
        _changed = true;
      });
      _showSnack('Profil vérifié ✅');
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnack('Erreur: $e');
    }
  }

  Future<void> _rejectVerification() async {
    setState(() => _isProcessing = true);
    try {
      await _firestore.collection('dating_profiles').doc(_profile.id).update({
        'verificationRequested': false,
        'verificationRequestedAt': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() {
        _profile = _profile.copyWith(verificationRequested: false);
        _isProcessing = false;
        _changed = true;
      });
      _showSnack('Demande de vérification rejetée');
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnack('Erreur: $e');
    }
  }

  Future<void> _revokeVerification() async {
    setState(() => _isProcessing = true);
    try {
      await _firestore.collection('dating_profiles').doc(_profile.id).update({
        'isVerified': false,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() {
        _profile = _profile.copyWith(isVerified: false);
        _isProcessing = false;
        _changed = true;
      });
      _showSnack('Vérification retirée');
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnack('Erreur: $e');
    }
  }

  Future<void> _toggleActive() async {
    setState(() => _isProcessing = true);
    try {
      final newValue = !_profile.isActive;
      await _firestore.collection('dating_profiles').doc(_profile.id).update({
        'isActive': newValue,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() {
        _profile = _profile.copyWith(isActive: newValue);
        _isProcessing = false;
        _changed = true;
      });
      _showSnack(newValue ? 'Profil réactivé' : 'Profil suspendu');
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnack('Erreur: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final photos = <String>[
      if (_profile.imageUrl.isNotEmpty) _profile.imageUrl,
      ..._profile.photosUrls.where((p) => p != _profile.imageUrl),
    ];

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(_profile.pseudo),
          backgroundColor: colors.danger,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPhotosCarousel(colors, photos),
                  const SizedBox(height: 16),
                  _buildVerificationCard(colors),
                  const SizedBox(height: 16),
                  _buildInfoCard(colors),
                  const SizedBox(height: 16),
                  _buildStatsCard(colors),
                  const SizedBox(height: 16),
                  if (_profile.centresInteret.isNotEmpty) _buildInterestsCard(colors),
                  if (_profile.centresInteret.isNotEmpty) const SizedBox(height: 16),
                  _buildSearchPrefsCard(colors),
                  const SizedBox(height: 16),
                  if (_userData != null) _buildUserDataCard(colors),
                  const SizedBox(height: 16),
                  _buildAdminActionsCard(colors),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _buildPhotosCarousel(AppColors colors, List<String> photos) {
    if (photos.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 240,
          color: colors.surfaceVariant,
          child: const Icon(Icons.person, size: 80),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 280,
        child: PageView.builder(
          itemCount: photos.length,
          itemBuilder: (context, index) => Image.network(
            photos[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: colors.surfaceVariant,
              child: const Icon(Icons.person, size: 80),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(AppColors colors, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _buildSectionTitle(AppColors colors, String title) {
    return Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary));
  }

  Widget _buildVerificationCard(AppColors colors) {
    return _buildCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _profile.isVerified ? Icons.verified : Icons.verified_outlined,
                color: _profile.isVerified ? colors.info : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                _profile.isVerified ? 'Profil vérifié' : 'Profil non vérifié',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ],
          ),
          if (_profile.verificationRequested) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: colors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top, size: 16, color: colors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _profile.verificationRequestedAt != null
                          ? 'Demande de vérification envoyée le ${_formatTimestamp(_profile.verificationRequestedAt)}'
                          : 'Demande de vérification en attente',
                      style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _approveVerification,
                      icon: const Icon(Icons.check),
                      label: const Text('Valider'),
                      style: ElevatedButton.styleFrom(backgroundColor: colors.success, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _rejectVerification,
                      icon: Icon(Icons.close, color: colors.danger),
                      label: Text('Rejeter', style: TextStyle(color: colors.danger)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: colors.danger)),
                    ),
                  ),
                ],
              ),
          ] else if (_profile.isVerified) ...[
            const SizedBox(height: 10),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _revokeVerification,
                  icon: Icon(Icons.remove_circle_outline, color: colors.danger),
                  label: Text('Retirer la vérification', style: TextStyle(color: colors.danger)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: colors.danger)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(AppColors colors) {
    return _buildCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_profile.pseudo}, ${_profile.age} ans',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
              ),
              if (_subscriptionPlan != null) _buildPlanBadge(colors, _subscriptionPlan!),
            ],
          ),
          const SizedBox(height: 6),
          _buildInfoRow(colors, Icons.wc, 'Sexe', _profile.sexe),
          _buildInfoRow(colors, Icons.location_on, 'Localisation',
              '${_profile.ville.isNotEmpty ? '${_profile.ville}, ' : ''}${_profile.pays}'),
          if (_profile.profession != null && _profile.profession!.isNotEmpty)
            _buildInfoRow(colors, Icons.work, 'Profession', _profile.profession!),
          if (_profile.bio.isNotEmpty) _buildInfoRow(colors, Icons.notes, 'Bio', _profile.bio),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _profile.isProfileComplete ? Icons.check_circle : Icons.error_outline,
                size: 16,
                color: _profile.isProfileComplete ? colors.success : colors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                _profile.isProfileComplete
                    ? 'Profil complet'
                    : 'Profil incomplet (${(_profile.completionPercentage * 100).toStringAsFixed(0)}%)',
                style: TextStyle(color: colors.textPrimary),
              ),
              const SizedBox(width: 12),
              Icon(
                _profile.isActive ? Icons.toggle_on : Icons.toggle_off,
                size: 18,
                color: _profile.isActive ? colors.success : colors.danger,
              ),
              const SizedBox(width: 4),
              Text(_profile.isActive ? 'Actif' : 'Suspendu', style: TextStyle(color: colors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBadge(AppColors colors, String plan) {
    Color color;
    String label;
    switch (plan) {
      case 'gold':
        color = colors.accent;
        label = 'Gold';
        break;
      case 'plus':
        color = colors.info;
        label = 'Plus';
        break;
      default:
        color = colors.textSecondary;
        label = 'Gratuit';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildInfoRow(AppColors colors, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatsCard(AppColors colors) {
    return _buildCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(colors, 'Statistiques'),
          const SizedBox(height: 8),
          _buildStatRow(colors, Icons.favorite, 'Likes reçus', _likesCount.toString()),
          _buildStatRow(colors, Icons.star, 'Coups de cœur reçus', _coupsDeCoeurCount.toString()),
          _buildStatRow(colors, Icons.people, 'Matchs', _connectionsCount.toString()),
          _buildStatRow(colors, Icons.chat, 'Messages', _messagesCount.toString()),
          _buildStatRow(colors, Icons.visibility, 'Visites reçues', _profile.visitorsCount.toString()),
          _buildStatRow(colors, Icons.trending_up, 'Score de popularité', _profile.popularityScore.toString()),
          if (_profile.isBoosted) _buildStatRow(colors, Icons.rocket_launch, 'Boost actif jusqu\'à', _formatTimestamp(_profile.boostUntil)),
        ],
      ),
    );
  }

  Widget _buildStatRow(AppColors colors, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: colors.textPrimary))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildInterestsCard(AppColors colors) {
    return _buildCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(colors, 'Centres d\'intérêt'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _profile.centresInteret.map((i) => Chip(label: Text(i))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPrefsCard(AppColors colors) {
    return _buildCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(colors, 'Préférences de recherche'),
          const SizedBox(height: 8),
          _buildInfoRow(colors, Icons.search, 'Recherche', _profile.rechercheSexe),
          _buildInfoRow(colors, Icons.cake, 'Âge', '${_profile.rechercheAgeMin} - ${_profile.rechercheAgeMax} ans'),
          _buildInfoRow(colors, Icons.public, 'Pays', _profile.recherchePays),
        ],
      ),
    );
  }

  Widget _buildUserDataCard(AppColors colors) {
    return _buildCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(colors, 'Compte utilisateur'),
          const SizedBox(height: 8),
          _buildInfoRow(colors, Icons.email, 'Email', _userData!.email ?? 'Non renseigné'),
          _buildInfoRow(colors, Icons.phone, 'Téléphone', _userData!.numeroDeTelephone ?? 'Non renseigné'),
          _buildInfoRow(colors, Icons.calendar_today, 'Inscrit le', _formatTimestamp(_userData!.createdAt)),
        ],
      ),
    );
  }

  Widget _buildAdminActionsCard(AppColors colors) {
    return _buildCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(colors, 'Actions administrateur'),
          const SizedBox(height: 8),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _toggleActive,
                icon: Icon(_profile.isActive ? Icons.block : Icons.restart_alt, color: _profile.isActive ? colors.danger : colors.success),
                label: Text(
                  _profile.isActive ? 'Suspendre ce profil' : 'Réactiver ce profil',
                  style: TextStyle(color: _profile.isActive ? colors.danger : colors.success),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _profile.isActive ? colors.danger : colors.success),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return 'Inconnu';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
