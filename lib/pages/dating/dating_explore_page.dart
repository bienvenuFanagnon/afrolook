// lib/pages/dating/dating_explore_page.dart
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../pub/native_ad_widget.dart';
import 'dating_profile_detail_page.dart';
import 'dating_subscription_page.dart';

// Énumération pour les types d'éléments dans la liste
enum ExploreItemType { profileRow, adBanner }

class ExploreItem {
  final ExploreItemType type;
  final List<DatingProfile>? profiles; // pour type profileRow (max 2)
  final String? adKey; // pour type adBanner

  ExploreItem.profileRow(this.profiles) : type = ExploreItemType.profileRow, adKey = null;
  ExploreItem.adBanner(this.adKey) : type = ExploreItemType.adBanner, profiles = null;
}

class DatingExplorePage extends StatefulWidget {
  const DatingExplorePage({Key? key}) : super(key: key);

  @override
  State<DatingExplorePage> createState() => _DatingExplorePageState();
}

class _DatingExplorePageState extends State<DatingExplorePage> {
  List<DatingProfile> _profiles = [];
  List<ExploreItem> _displayItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  String? _currentUserId;
  DatingProfile? _currentUserProfile;
  String? _subscriptionPlan;
  int _maxVisibleProfiles = 10;
  bool _useSearchFilter = false;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static const int _batchSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      _currentUserId = authProvider.loginUserData.id;
      _loadUserSubscription();
      _loadCurrentUserProfile();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Met à jour la liste d'affichage à partir de _profiles
  void _rebuildDisplayItems() {
    final List<ExploreItem> items = [];
    for (int i = 0; i < _profiles.length; i += 2) {
      final end = (i + 2 < _profiles.length) ? i + 2 : _profiles.length;
      final rowProfiles = _profiles.sublist(i, end);
      items.add(ExploreItem.profileRow(rowProfiles));

      final rowNumber = (i / 2).floor(); // 0 pour la première ligne, 1 pour la deuxième, etc.
      // Bannière après la 2ème ligne (rowNumber=1), 4ème ligne (rowNumber=3), ...
      if (rowNumber % 2 == 1) {
        items.add(ExploreItem.adBanner('ad_row_$rowNumber'));
      }
    }
    setState(() {
      _displayItems = items;
    });
  }
  Future<void> _loadUserSubscription() async {
    if (_currentUserId == null) return;
    try {
      final snapshot = await firestore
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final subscription = snapshot.docs.first;
        _subscriptionPlan = subscription['planCode'];
        if (_subscriptionPlan == 'gratuit') {
          _maxVisibleProfiles = 10;
        } else if (_subscriptionPlan == 'plus') {
          _maxVisibleProfiles = 200;
        } else if (_subscriptionPlan == 'gold') {
          _maxVisibleProfiles = -1;
        }
      } else {
        _subscriptionPlan = 'gratuit';
        _maxVisibleProfiles = 10;
      }
      if (mounted) setState(() {});
    } catch (e) {
      print('❌ Erreur chargement abonnement: $e');
      _subscriptionPlan = 'gratuit';
      _maxVisibleProfiles = 10;
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final snapshot = await firestore
          .collection('dating_profiles')
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        _currentUserProfile = DatingProfile.fromJson(snapshot.docs.first.data());
      } else {
        if (mounted) Navigator.pop(context);
        return;
      }
      await _loadProfiles(reset: true);
    } catch (e) {
      print('❌ Erreur chargement profil: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfiles({bool reset = false}) async {
    if (_isLoadingMore) return;
    if (_maxVisibleProfiles != -1 && _profiles.length >= _maxVisibleProfiles) {
      setState(() => _hasMore = false);
      return;
    }
    if (reset) {
      _profiles.clear();
      _lastDocument = null;
      _hasMore = true;
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }
    try {
      Query query = firestore
          .collection('dating_profiles')
          .where('isActive', isEqualTo: true);
      if (_useSearchFilter && _currentUserProfile != null) {
        final rechercheSexe = _currentUserProfile!.rechercheSexe;
        if (rechercheSexe != 'tous') {
          query = query.where('sexe', isEqualTo: rechercheSexe);
        }
      }
      query = query
          .orderBy('popularityScore', descending: true)
          .orderBy(FieldPath.documentId);
      if (!reset && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      final snapshot = await query.limit(_batchSize).get();
      if (snapshot.docs.isEmpty) {
        _hasMore = false;
        if (reset) setState(() => _isLoading = false);
        else setState(() => _isLoadingMore = false);
        return;
      }
      _lastDocument = snapshot.docs.last;
      List<DatingProfile> allProfiles = snapshot.docs
          .map((doc) => DatingProfile.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      allProfiles = allProfiles.where((p) => p.userId != _currentUserId).toList();
      if (allProfiles.isEmpty) {
        if (!reset) {
          await _loadProfiles(reset: false);
        } else {
          setState(() => _isLoading = false);
          _hasMore = false;
        }
        return;
      }
      final mixed = _mixProfiles(allProfiles);
      if (reset) {
        _profiles = mixed;
        setState(() => _isLoading = false);
      } else {
        _profiles.addAll(mixed);
        setState(() => _isLoadingMore = false);
      }
      if (_maxVisibleProfiles != -1 && _profiles.length >= _maxVisibleProfiles) {
        _hasMore = false;
      } else {
        _hasMore = true;
      }
      _rebuildDisplayItems(); // Mettre à jour l'affichage
    } catch (e) {
      print('❌ Erreur chargement profils explore: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  List<DatingProfile> _mixProfiles(List<DatingProfile> profiles) {
    final sorted = List<DatingProfile>.from(profiles);
    sorted.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
    final total = sorted.length;
    final highCount = (total * 0.4).toInt();
    final midCount = (total * 0.3).toInt();
    final lowCount = total - highCount - midCount;
    List<DatingProfile> high = sorted.take(highCount).toList();
    List<DatingProfile> mid = sorted.skip(highCount).take(midCount).toList();
    List<DatingProfile> low = sorted.skip(highCount + midCount).toList();
    high.shuffle();
    mid.shuffle();
    low.shuffle();
    List<DatingProfile> mixed = [];
    int hi = 0, mi = 0, lo = 0;
    while (hi < high.length || mi < mid.length || lo < low.length) {
      for (int i = 0; i < 5 && hi < high.length; i++) mixed.add(high[hi++]);
      for (int i = 0; i < 3 && mi < mid.length; i++) mixed.add(mid[mi++]);
      for (int i = 0; i < 2 && lo < low.length; i++) mixed.add(low[lo++]);
    }
    return mixed;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_isLoadingMore &&
        (_maxVisibleProfiles == -1 || _profiles.length < _maxVisibleProfiles)) {
      _loadProfiles();
    }
  }

  void _toggleSearchFilter() {
    setState(() {
      _useSearchFilter = !_useSearchFilter;
      _loadProfiles(reset: true);
    });
  }

  void _showUpgradeMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Découvrez plus de profils', style: TextStyle(color: Colors.pink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 50, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              _subscriptionPlan == 'gratuit'
                  ? 'Votre plan gratuit vous limite à 10 profils. Passez à AfroLove Plus ou Gold pour voir jusqu’à 200 profils ou plus !'
                  : _subscriptionPlan == 'plus'
                  ? 'Vous avez atteint la limite de 200 profils de votre plan Plus. Passez à Gold pour un accès illimité !'
                  : 'Profitez de l’illimité avec votre plan Gold !',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DatingSubscriptionPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Voir les offres'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdBanner({required String key}) {
    return Container(
      key: ValueKey(key),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent!),
      ),
      child: MrecAdWidget(
        key: ValueKey(key),
        // templateType: TemplateType.medium,
        onAdLoaded: () {
          print('✅ Native Ad Afrolook chargée: $key');
        },

      ),
    );
  }

  Widget _buildProfileRow(List<DatingProfile> profiles) {
    if (profiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: _buildProfileCard(profiles[0])),
          if (profiles.length > 1) ...[
            const SizedBox(width: 12),
            Expanded(child: _buildProfileCard(profiles[1])),
          ] else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildProfileCard(DatingProfile profile) {
    final imageUrl = profile.photosUrls.isNotEmpty ? profile.photosUrls.first : profile.imageUrl;
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => DatingProfileDetailPage(profile: profile)));
      },
      child: AspectRatio(
        aspectRatio: 0.7, // correspond au childAspectRatio du GridView d'origine
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand, // important pour que le Stack prenne toute la place
              children: [
                // Image de fond
                Positioned.fill(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.person, size: 50, color: Colors.grey)),
                  ),
                ),
                // Overlay pour le texte
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${profile.pseudo}, ${profile.age}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile.isVerified) const Icon(Icons.verified, size: 14, color: Colors.blue),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 12, color: Colors.white70),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '${profile.ville}, ${profile.pays}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Badge de popularité
                if (profile.popularityScore > 100)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                      child: const Icon(Icons.whatshot, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final hasSubscription = _subscriptionPlan == 'plus' || _subscriptionPlan == 'gold';
    final showUpgradeButton = !hasSubscription ||
        (_subscriptionPlan == 'plus' && _profiles.length >= _maxVisibleProfiles && _maxVisibleProfiles != -1);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            const Text('Explorer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        backgroundColor: Colors.pink.shade400,
        elevation: 0,
        centerTitle: false,
        actions: [
          Row(
            children: [
              const Text('Filtre recherche genre', style: TextStyle(color: Colors.white, fontSize: 12)),
              Switch(
                value: _useSearchFilter,
                onChanged: (_) => _toggleSearchFilter(),
                activeColor: Colors.white,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.white70,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Aucun profil trouvé', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Essayez plus tard ou modifiez vos critères', style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: ValueKey('explore_list_${_displayItems.length}'),
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _displayItems.length,
              itemBuilder: (context, index) {
                final item = _displayItems[index];
                if (item.type == ExploreItemType.profileRow) {
                  return _buildProfileRow(item.profiles!);
                } else {
                  return _buildAdBanner(key: item.adKey!);
                }
              },
            ),
          ),
          if (_isLoadingMore)
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: CircularProgressIndicator()),
          if (!_hasMore && showUpgradeButton)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: _showUpgradeMessage,
                icon: const Icon(Icons.star, color: Colors.white),
                label: Text(
                  _subscriptionPlan == 'gratuit' ? 'Débloquez plus de profils avec AfroLove Plus' : 'Passez à Gold pour un accès illimité',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}