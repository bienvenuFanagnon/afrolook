// lib/pages/admin/dating/admin_dating_profiles_page.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/dating_data.dart';
import '../../../theme/app_colors.dart';
import 'admin_profile_detail_page.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';

class AdminDatingProfilesPage extends StatefulWidget {
  const AdminDatingProfilesPage({Key? key}) : super(key: key);

  @override
  State<AdminDatingProfilesPage> createState() => _AdminDatingProfilesPageState();
}

class _AdminDatingProfilesPageState extends State<AdminDatingProfilesPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  // --- Profils (onglet "Profils") ---
  List<DatingProfile> _profiles = [];
  bool _isLoading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;

  // Filtres
  String _selectedGender = 'tous';
  String _selectedCountry = '';
  String _selectedRegion = '';
  String _selectedCity = '';
  String _completionStatus = 'tous'; // 'complet', 'incomplet', 'tous'

  // Controllers pour les filtres (pour le dialog)
  String _tempGender = 'tous';
  String _tempCountry = '';
  String _tempRegion = '';
  String _tempCity = '';
  String _tempCompletion = 'tous';

  final ScrollController _scrollController = ScrollController();

  // --- Statistiques (onglet "Statistiques") ---
  bool _statsLoading = true;
  Map<String, int> _stats = {};

  // --- Vérifications (onglet "Vérifications") ---
  List<DatingProfile> _pendingVerifications = [];
  bool _verificationsLoading = true;
  final Set<String> _processingVerificationIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfiles();
    _loadStats();
    _loadPendingVerifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProfiles();
    }
  }

  // ---------------------------------------------------------------------
  // Statistiques globales
  // ---------------------------------------------------------------------
  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final profilesCol = _firestore.collection('dating_profiles');
      final subsCol = _firestore.collection('user_dating_subscriptions');

      final results = await Future.wait([
        profilesCol.count().get(),
        profilesCol.where('isActive', isEqualTo: true).count().get(),
        profilesCol.where('isVerified', isEqualTo: true).count().get(),
        profilesCol.where('verificationRequested', isEqualTo: true).count().get(),
        profilesCol.where('isProfileComplete', isEqualTo: true).count().get(),
        profilesCol.where('sexe', isEqualTo: 'homme').count().get(),
        profilesCol.where('sexe', isEqualTo: 'femme').count().get(),
        subsCol.where('isActive', isEqualTo: true).where('planCode', isEqualTo: 'gratuit').count().get(),
        subsCol.where('isActive', isEqualTo: true).where('planCode', isEqualTo: 'plus').count().get(),
        subsCol.where('isActive', isEqualTo: true).where('planCode', isEqualTo: 'gold').count().get(),
      ]);

      final total = results[0].count ?? 0;
      final complete = results[4].count ?? 0;

      setState(() {
        _stats = {
          'total': total,
          'active': results[1].count ?? 0,
          'verified': results[2].count ?? 0,
          'pendingVerification': results[3].count ?? 0,
          'complete': complete,
          'incomplete': total - complete,
          'hommes': results[5].count ?? 0,
          'femmes': results[6].count ?? 0,
          'planGratuit': results[7].count ?? 0,
          'planPlus': results[8].count ?? 0,
          'planGold': results[9].count ?? 0,
        };
        _statsLoading = false;
      });
    } catch (e) {
      printVm('Erreur chargement statistiques admin dating: $e');
      setState(() => _statsLoading = false);
    }
  }

  // ---------------------------------------------------------------------
  // Demandes de vérification
  // ---------------------------------------------------------------------
  Future<void> _loadPendingVerifications() async {
    setState(() => _verificationsLoading = true);
    try {
      final snapshot = await _firestore
          .collection('dating_profiles')
          .where('verificationRequested', isEqualTo: true)
          .get();

      final profiles = snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data()))
          .toList()
        ..sort((a, b) => (b.verificationRequestedAt ?? 0).compareTo(a.verificationRequestedAt ?? 0));

      setState(() {
        _pendingVerifications = profiles;
        _verificationsLoading = false;
      });
    } catch (e) {
      printVm('Erreur chargement demandes de vérification: $e');
      setState(() => _verificationsLoading = false);
    }
  }

  Future<void> _approveVerification(DatingProfile profile) async {
    setState(() => _processingVerificationIds.add(profile.id));
    try {
      await _firestore.collection('dating_profiles').doc(profile.id).update({
        'isVerified': true,
        'verificationRequested': false,
        'verificationRequestedAt': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() {
        _pendingVerifications.removeWhere((p) => p.id == profile.id);
        _processingVerificationIds.remove(profile.id);
        _stats['verified'] = (_stats['verified'] ?? 0) + 1;
        _stats['pendingVerification'] = (_stats['pendingVerification'] ?? 1) - 1;
      });
      _profiles = _profiles.map((p) {
        if (p.id == profile.id) {
          return p.copyWith(isVerified: true, verificationRequested: false);
        }
        return p;
      }).toList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil "${profile.pseudo}" vérifié ✅')),
        );
      }
    } catch (e) {
      setState(() => _processingVerificationIds.remove(profile.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _rejectVerification(DatingProfile profile) async {
    setState(() => _processingVerificationIds.add(profile.id));
    try {
      await _firestore.collection('dating_profiles').doc(profile.id).update({
        'verificationRequested': false,
        'verificationRequestedAt': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() {
        _pendingVerifications.removeWhere((p) => p.id == profile.id);
        _processingVerificationIds.remove(profile.id);
        _stats['pendingVerification'] = (_stats['pendingVerification'] ?? 1) - 1;
      });
      _profiles = _profiles.map((p) {
        if (p.id == profile.id) {
          return p.copyWith(verificationRequested: false);
        }
        return p;
      }).toList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Demande de "${profile.pseudo}" rejetée')),
        );
      }
    } catch (e) {
      setState(() => _processingVerificationIds.remove(profile.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Liste des profils
  // ---------------------------------------------------------------------
  Future<void> _loadProfiles({bool reset = true}) async {
    if (reset) {
      setState(() {
        _profiles = [];
        _hasMore = true;
        _lastDocument = null;
        _isLoading = true;
      });
    }

    try {
      Query query = _firestore.collection('dating_profiles');

      if (_selectedGender != 'tous') {
        query = query.where('sexe', isEqualTo: _selectedGender);
      }

      if (_selectedCountry.isNotEmpty) {
        query = query.where('pays', isEqualTo: _selectedCountry);
      }

      query = query.orderBy('popularityScore', descending: true).orderBy(FieldPath.documentId);

      if (_lastDocument != null && !reset) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.limit(20).get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      _lastDocument = snapshot.docs.last;

      List<DatingProfile> newProfiles = snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Filtrage côté client pour région, ville et statut de complétion
      if (_selectedRegion.isNotEmpty) {
        newProfiles = newProfiles.where((p) => p.region == _selectedRegion).toList();
      }
      if (_selectedCity.isNotEmpty) {
        newProfiles = newProfiles.where((p) => p.ville == _selectedCity).toList();
      }
      if (_completionStatus != 'tous') {
        bool isComplete = _completionStatus == 'complet';
        newProfiles = newProfiles.where((p) => p.isProfileComplete == isComplete).toList();
      }

      if (reset) {
        _profiles = newProfiles;
      } else {
        _profiles.addAll(newProfiles);
      }

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      printVm('Erreur chargement profils admin: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _loadMoreProfiles() {
    if (_hasMore && !_isLoadingMore && !_isLoading) {
      setState(() => _isLoadingMore = true);
      _loadProfiles(reset: false);
    }
  }

  void _applyFilters() {
    setState(() {
      _selectedGender = _tempGender;
      _selectedCountry = _tempCountry;
      _selectedRegion = _tempRegion;
      _selectedCity = _tempCity;
      _completionStatus = _tempCompletion;
    });
    _profiles = [];
    _lastDocument = null;
    _hasMore = true;
    _loadProfiles();
    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      _tempGender = 'tous';
      _tempCountry = '';
      _tempRegion = '';
      _tempCity = '';
      _tempCompletion = 'tous';
    });
  }

  void _showFilterDialog() {
    final colors = AppColors.of(context);
    _tempGender = _selectedGender;
    _tempCountry = _selectedCountry;
    _tempRegion = _selectedRegion;
    _tempCity = _selectedCity;
    _tempCompletion = _completionStatus;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Filtres'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _tempGender,
                    items: const [
                      DropdownMenuItem(value: 'tous', child: Text('Tous')),
                      DropdownMenuItem(value: 'homme', child: Text('Hommes')),
                      DropdownMenuItem(value: 'femme', child: Text('Femmes')),
                    ],
                    onChanged: (value) => setStateDialog(() => _tempGender = value!),
                    decoration: const InputDecoration(labelText: 'Genre'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _tempCompletion,
                    items: const [
                      DropdownMenuItem(value: 'tous', child: Text('Tous')),
                      DropdownMenuItem(value: 'complet', child: Text('Complets')),
                      DropdownMenuItem(value: 'incomplet', child: Text('Incomplets')),
                    ],
                    onChanged: (value) => setStateDialog(() => _tempCompletion = value!),
                    decoration: const InputDecoration(labelText: 'État du profil'),
                  ),
                  const SizedBox(height: 16),
                  CSCPickerPlus(
                    showStates: true,
                    showCities: true,
                    defaultCountry: CscCountry.Togo,
                    flagState: CountryFlag.SHOW_IN_DROP_DOWN_ONLY,
                    dropdownDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    selectedItemStyle: const TextStyle(fontSize: 14),
                    onCountryChanged: (value) => setStateDialog(() => _tempCountry = value),
                    onStateChanged: (value) => setStateDialog(() => _tempRegion = value ?? ''),
                    onCityChanged: (value) => setStateDialog(() => _tempCity = value ?? ''),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _resetFilters();
                  Navigator.pop(context);
                },
                child: const Text('Réinitialiser'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(backgroundColor: colors.danger, foregroundColor: Colors.white),
                child: const Text('Appliquer'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final pendingCount = _stats['pendingVerification'] ?? _pendingVerifications.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Administration Dating'),
        backgroundColor: colors.danger,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadProfiles();
              _loadStats();
              _loadPendingVerifications();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(icon: Icon(Icons.bar_chart), text: 'Statistiques'),
            Tab(
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                child: const Icon(Icons.verified_user),
              ),
              text: 'Vérifications',
            ),
            const Tab(icon: Icon(Icons.people), text: 'Profils'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatsTab(colors),
          _buildVerificationsTab(colors),
          _buildProfilesTab(colors),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Onglet Statistiques
  // ---------------------------------------------------------------------
  Widget _buildStatsTab(AppColors colors) {
    if (_statsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _stats['total'] ?? 0;
    final planTotal = (_stats['planGratuit'] ?? 0) + (_stats['planPlus'] ?? 0) + (_stats['planGold'] ?? 0);

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Vue d\'ensemble', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildStatTile(colors, 'Profils totaux', total, Icons.people, colors.info),
              _buildStatTile(colors, 'Profils actifs', _stats['active'] ?? 0, Icons.check_circle, colors.success),
              _buildStatTile(colors, 'Profils vérifiés', _stats['verified'] ?? 0, Icons.verified, colors.primary),
              _buildStatTile(colors, 'Demandes en attente', _stats['pendingVerification'] ?? 0, Icons.hourglass_top, colors.warning),
              _buildStatTile(colors, 'Profils complets', _stats['complete'] ?? 0, Icons.task_alt, colors.success),
              _buildStatTile(colors, 'Profils incomplets', _stats['incomplete'] ?? 0, Icons.warning_amber, colors.danger),
            ],
          ),
          const SizedBox(height: 24),
          Text('Répartition par genre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 12),
          _buildBreakdownBar(colors, [
            _BreakdownItem('Hommes', _stats['hommes'] ?? 0, colors.info),
            _BreakdownItem('Femmes', _stats['femmes'] ?? 0, Colors.pinkAccent),
          ], total),
          const SizedBox(height: 24),
          Text('Répartition par abonnement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 12),
          _buildBreakdownBar(colors, [
            _BreakdownItem('Gratuit', _stats['planGratuit'] ?? 0, colors.textSecondary),
            _BreakdownItem('Plus', _stats['planPlus'] ?? 0, colors.info),
            _BreakdownItem('Gold', _stats['planGold'] ?? 0, colors.accent),
          ], planTotal),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStatTile(AppColors colors, String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownBar(AppColors colors, List<_BreakdownItem> items, int total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: items.map((item) {
                  final ratio = total > 0 ? item.value / total : 0.0;
                  return Expanded(
                    flex: (ratio * 1000).round().clamp(1, 1000),
                    child: Container(color: item.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final pct = total > 0 ? (item.value / total * 100).toStringAsFixed(0) : '0';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.label, style: TextStyle(color: colors.textPrimary))),
                  Text('${item.value} ($pct%)', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Onglet Vérifications
  // ---------------------------------------------------------------------
  Widget _buildVerificationsTab(AppColors colors) {
    if (_verificationsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingVerifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPendingVerifications,
        child: ListView(
          children: [
            SizedBox(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_outlined, size: 72, color: colors.textSecondary),
                    const SizedBox(height: 16),
                    Text('Aucune demande de vérification', style: TextStyle(fontSize: 16, color: colors.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingVerifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pendingVerifications.length,
        itemBuilder: (context, index) {
          final profile = _pendingVerifications[index];
          final isProcessing = _processingVerificationIds.contains(profile.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      profile.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: colors.surfaceVariant,
                        child: const Icon(Icons.person),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${profile.pseudo}, ${profile.age}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('${profile.ville.isNotEmpty ? profile.ville : profile.pays}', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        if (profile.verificationRequestedAt != null)
                          Text(
                            'Demandé le ${_formatDate(profile.verificationRequestedAt!)}',
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isProcessing)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.visibility, color: colors.info),
                              tooltip: 'Voir le profil',
                              onPressed: () => _navigateToProfileDetail(profile),
                            ),
                            IconButton(
                              icon: Icon(Icons.check_circle, color: colors.success),
                              tooltip: 'Valider',
                              onPressed: () => _approveVerification(profile),
                            ),
                            IconButton(
                              icon: Icon(Icons.cancel, color: colors.danger),
                              tooltip: 'Rejeter',
                              onPressed: () => _rejectVerification(profile),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ---------------------------------------------------------------------
  // Onglet Profils
  // ---------------------------------------------------------------------
  Widget _buildProfilesTab(AppColors colors) {
    if (_isLoading && _profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filtres'),
                ),
              ),
            ],
          ),
        ),
        if (_profiles.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: colors.textSecondary),
                  const SizedBox(height: 16),
                  Text('Aucun profil trouvé', style: TextStyle(fontSize: 18, color: colors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Essayez de modifier les filtres', style: TextStyle(color: colors.textSecondary)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _profiles.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _profiles.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return _buildProfileCard(colors, _profiles[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProfileCard(AppColors colors, DatingProfile profile) {
    return GestureDetector(
      onTap: () => _navigateToProfileDetail(profile),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      profile.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: colors.surfaceVariant,
                        child: const Icon(Icons.person, size: 40),
                      ),
                    ),
                  ),
                  if (profile.isVerified)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.verified, color: colors.info, size: 20),
                    ),
                  if (profile.verificationRequested)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.warning,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Vérif. en attente', style: TextStyle(fontSize: 9, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.pseudo}, ${profile.age}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: colors.textSecondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          profile.ville.isNotEmpty ? profile.ville : profile.pays,
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.star, size: 12, color: colors.accent),
                      const SizedBox(width: 2),
                      Text('Score: ${profile.popularityScore}', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (!profile.isProfileComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.warning,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Incomplet', style: TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfileDetail(DatingProfile profile) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminProfileDetailPage(profile: profile),
      ),
    );
    if (result == true) {
      _loadProfiles();
      _loadStats();
      _loadPendingVerifications();
    }
  }
}

class _BreakdownItem {
  final String label;
  final int value;
  final Color color;
  _BreakdownItem(this.label, this.value, this.color);
}
