// lib/pages/admin/admin_dating_profiles_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/dating_data.dart';
import 'admin_profile_detail_page.dart'; // à créer
import 'package:csc_picker_plus/csc_picker_plus.dart';

class AdminDatingProfilesPage extends StatefulWidget {
  const AdminDatingProfilesPage({Key? key}) : super(key: key);

  @override
  State<AdminDatingProfilesPage> createState() => _AdminDatingProfilesPageState();
}

class _AdminDatingProfilesPageState extends State<AdminDatingProfilesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProfiles();
    }
  }

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

      // Filtre par sexe (en minuscules)
      if (_selectedGender != 'tous') {
        query = query.where('sexe', isEqualTo: _selectedGender);
      }

      // Filtre par pays
      if (_selectedCountry.isNotEmpty) {
        query = query.where('pays', isEqualTo: _selectedCountry);
      }

      // Note : Firestore ne permet pas de filtrer sur région et ville directement car ce sont des champs optionnels.
      // On pourrait les filtrer côté client après récupération, ou ajouter des index composites.
      // Pour simplifier, on filtrera côté client après chargement.

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
      print('Erreur chargement profils admin: $e');
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
    // Reset pagination
    _profiles = [];
    _lastDocument = null;
    _hasMore = true;
    _loadProfiles();
    Navigator.pop(context); // fermer le modal
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
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    selectedItemStyle: const TextStyle(fontSize: 14),
                    onCountryChanged: (value) => setStateDialog(() => _tempCountry = value ?? ''),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Appliquer'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des profils Dating'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadProfiles(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Aucun profil trouvé', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Essayez de modifier les filtres', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Section statistiques (simples)
        _buildStatsSection(),
        const SizedBox(height: 16),
        // Grille
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _profiles.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _profiles.length) {
                return _buildLoadingMore();
              }
              return _buildProfileCard(_profiles[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    // On calcule les stats à partir des profils chargés (pas idéal, mais pour l'instant)
    // On pourrait aussi faire des requêtes Firestore count.
    int total = _profiles.length;
    int complete = _profiles.where((p) => p.isProfileComplete).length;
    int incomplete = total - complete;
    int hommes = _profiles.where((p) => p.sexe == 'homme').length;
    int femmes = _profiles.where((p) => p.sexe == 'femme').length;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard('Total', total.toString(), Icons.people, Colors.blue),
          _buildStatCard('Complets', complete.toString(), Icons.check_circle, Colors.green),
          _buildStatCard('Incomplets', incomplete.toString(), Icons.warning, Colors.orange),
          _buildStatCard('Hommes', hommes.toString(), Icons.male, Colors.blue),
          _buildStatCard('Femmes', femmes.toString(), Icons.female, Colors.pink),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLoadingMore() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildProfileCard(DatingProfile profile) {
    return GestureDetector(
      onTap: () => _navigateToProfileDetail(profile),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  profile.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.person, size: 40),
                  ),
                ),
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
                      Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          profile.ville.isNotEmpty ? profile.ville : profile.pays,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text('Score: ${profile.popularityScore}', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (!profile.isProfileComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
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

  void _navigateToProfileDetail(DatingProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminProfileDetailPage(profile: profile),
      ),
    );
  }
}