// lib/pages/dating/dating_creator_posts_tab.dart
import 'package:afrotok/pages/dating/creator_register_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../providers/authProvider.dart';
import 'creator_content_detail_page.dart';
import 'creator_content_form_page.dart';
import 'creator_other_profil.dart';
import 'creator_profile_page.dart';
import 'creator_subscription_page.dart'; // 🔥 Ajout de l'import

class DatingCreatorPostsPage extends StatefulWidget {
  const DatingCreatorPostsPage({Key? key}) : super(key: key);

  @override
  State<DatingCreatorPostsPage> createState() => _DatingCreatorPostsPageState();
}

class _DatingCreatorPostsPageState extends State<DatingCreatorPostsPage>
    with SingleTickerProviderStateMixin {
  bool _isSubscribed = false;
  bool _isCheckingSubscription = true;
  String? _currentUserId;
  CreatorProfile? _myCreatorProfile;
  bool _isCreator = false;
  bool _isLoadingCreatorProfile = true;

  // Animation
  late TabController _tabController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Couleurs
  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color primaryBlack = Colors.black;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      _currentUserId = authProvider.loginUserData.id;
      print('📱 DatingCreatorPostsPage - User ID: $_currentUserId');
      _checkSubscription();
      _checkIfUserIsCreator();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkSubscription() async {
    if (_currentUserId == null) {
      print('⚠️ _checkSubscription: currentUserId is null');
      setState(() => _isCheckingSubscription = false);
      return;
    }

    try {
      print('🔍 Vérification de l\'abonnement créateur pour: $_currentUserId');
      final snapshot = await _firestore
          .collection('creator_subscriptions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      setState(() {
        _isSubscribed = snapshot.docs.isNotEmpty;
        _isCheckingSubscription = false;
      });
      print('✅ Abonnement actif: $_isSubscribed');
    } catch (e) {
      print('❌ Erreur _checkSubscription: $e');
      setState(() => _isCheckingSubscription = false);
    }
  }

  Future<void> _checkIfUserIsCreator() async {
    if (_currentUserId == null) {
      print('⚠️ _checkIfUserIsCreator: currentUserId is null');
      setState(() => _isLoadingCreatorProfile = false);
      return;
    }

    try {
      print('🔍 Vérification si l\'utilisateur est créateur: $_currentUserId');
      final snapshot = await _firestore
          .collection('creator_profiles')
          .where('userId', isEqualTo: _currentUserId)
          .where('isCreatorActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _myCreatorProfile = CreatorProfile.fromJson(snapshot.docs.first.data());
        _isCreator = true;
        print('✅ Utilisateur est créateur: ${_myCreatorProfile!.pseudo}');
      } else {
        print('ℹ️ Utilisateur n\'est pas créateur');
        _isCreator = false;
      }
    } catch (e) {
      print('❌ Erreur _checkIfUserIsCreator: $e');
      _isCreator = false;
    } finally {
      setState(() => _isLoadingCreatorProfile = false);
    }
  }

  void _navigateToCreatorProfileByUserId(String userId) {
    print('📱 Navigation vers le profil créateur userid: $userId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorProfilePage(userId: userId),
      ),
    );
  }

  void _navigateToCreatorProfileByCreatorId(String creatorId) {
    print('📱 Navigation vers le profil créateur : $creatorId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorOtherProfilePage(creatorId: creatorId),
      ),
    );
  }

  void _navigateToCreateContent() {
    print('📱 Navigation vers création de contenu');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorContentFormPage(),
      ),
    ).then((_) {
      // Rafraîchir après retour
      setState(() {});
    });
  }

  void _navigateToMyCreatorProfile() {
    if (_myCreatorProfile != null) {
      _navigateToCreatorProfileByUserId(_myCreatorProfile!.userId);
    }
  }

  // ✅ Dialogue d'abonnement modifié pour le créateur
  void _showSubscriptionRequiredDialog(String creatorId, String creatorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.lock, color: primaryYellow),
            const SizedBox(width: 8),
            const Text(
              'Abonnement requis',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Pour accéder aux contenus payants de $creatorName, vous devez vous abonner à son profil créateur.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatorSubscriptionPage(
                    creatorId: creatorId,
                    creatorName: creatorName,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryYellow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'S\'abonner',
              style: TextStyle(color: primaryBlack, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.people, color: primaryYellow, size: 24),
            const SizedBox(width: 8),
            Text(
              'Créateurs',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: primaryRed,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isCreator && !_isLoadingCreatorProfile)
            IconButton(
              icon: Icon(Icons.add, color: primaryYellow, size: 28),
              onPressed: _navigateToCreateContent,
              tooltip: 'Créer un contenu',
            ),
          if (_isCreator && !_isLoadingCreatorProfile)
            IconButton(
              icon: Icon(Icons.person, color: Colors.white, size: 24),
              onPressed: _navigateToMyCreatorProfile,
              tooltip: 'Mon profil créateur',
            ),
        ],
      ),
      body: _isLoadingCreatorProfile
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryRed),
            const SizedBox(height: 16),
            Text(
              'Chargement...',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      )
          : Column(
        children: [
          if (!_isCreator)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryRed, primaryYellow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.monetization_on,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deviens créateur !',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Partage ton contenu et gagne de l\'argent',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatorRegisterPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Commencer',
                      style: TextStyle(color: primaryRed),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            color: primaryBlack,
            child: TabBar(
              controller: _tabController,
              indicatorColor: primaryYellow,
              labelColor: primaryYellow,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.lock_open), text: 'Gratuits'),
                Tab(icon: Icon(Icons.lock), text: 'Payants'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContentList(isPaid: false),
                _buildContentList(isPaid: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList({required bool isPaid}) {
    if (_isCheckingSubscription) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryRed),
            const SizedBox(height: 16),
            Text(
              'Vérification de votre abonnement...',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    print('📱 Chargement des contenus ${isPaid ? "payants" : "gratuits"}');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('creator_contents')
          .where('isPublished', isEqualTo: true)
          .where('isPaid', isEqualTo: isPaid)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('❌ Erreur chargement contenus: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${snapshot.error}',
                  style: TextStyle(color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                  ),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: primaryRed),
                const SizedBox(height: 16),
                Text(
                  'Chargement des contenus...',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        final contents = snapshot.data?.docs
            .map((doc) => CreatorContent.fromJson(doc.data() as Map<String, dynamic>))
            .toList() ?? [];

        print('📊 ${contents.length} contenus ${isPaid ? "payants" : "gratuits"} chargés');

        if (contents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPaid ? Icons.lock_outline : Icons.lock_open_outlined,
                  size: 80,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  isPaid ? 'Aucun contenu payant' : 'Aucun contenu gratuit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPaid
                      ? 'Les créateurs n\'ont pas encore publié de contenu payant'
                      : 'Les créateurs n\'ont pas encore publié de contenu gratuit',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isPaid && !_isSubscribed) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/dating/subscription');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Voir les abonnements',
                      style: TextStyle(color: primaryBlack, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                if (!_isCreator && !isPaid) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/creator/register');
                    },
                    icon: Icon(Icons.add, color: primaryYellow),
                    label: Text(
                      'Devenir créateur',
                      style: TextStyle(color: primaryYellow),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryYellow),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: contents.length,
          itemBuilder: (context, index) {
            final content = contents[index];
            final canAccess = !content.isPaid || _isSubscribed;

            return GestureDetector(
              onTap: () async {
                print('📱 Ouverture du contenu: ${content.titre} (ID: ${content.id})');
                if (canAccess) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatorContentDetailPage(content: content),
                    ),
                  );
                } else {
                  print('🔒 Contenu payant verrouillé - abonnement requis');
                  // Récupérer le nom du créateur
                  final creatorDoc = await _firestore
                      .collection('creator_profiles')
                      .doc(content.creatorId)
                      .get();
                  final creatorName = creatorDoc.exists
                      ? (creatorDoc.data()?['pseudo'] ?? 'ce créateur')
                      : 'ce créateur';
                  _showSubscriptionRequiredDialog(content.creatorId, creatorName);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.grey[900],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              content.thumbnailUrl ?? content.mediaUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('❌ Erreur chargement image: ${content.thumbnailUrl ?? content.mediaUrl}');
                                return Container(
                                  color: Colors.grey[800],
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 40,
                                    color: Colors.grey[600],
                                  ),
                                );
                              },
                            ),
                            // Badge payant/gratuit
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: content.isPaid ? Colors.amber : Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      content.isPaid ? Icons.lock : Icons.lock_open,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      content.isPaid ? '${content.priceCoins} coins' : 'Gratuit',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Overlay si contenu payant et non abonné
                            if (content.isPaid && !canAccess)
                              Container(
                                color: Colors.black54,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock, size: 30, color: Colors.white),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Abonnement requis',
                                        style: TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryYellow,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${content.priceCoins} coins',
                                          style: TextStyle(
                                            color: primaryBlack,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Informations
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.titre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Stats
                          Row(
                            children: [
                              Icon(Icons.favorite, size: 10, color: primaryRed),
                              const SizedBox(width: 2),
                              Text(
                                '${content.likesCount + content.lovesCount}',
                                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.visibility, size: 10, color: Colors.grey[500]),
                              const SizedBox(width: 2),
                              Text(
                                '${content.viewsCount}',
                                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.share, size: 10, color: Colors.grey[500]),
                              const SizedBox(width: 2),
                              Text(
                                '${content.sharesCount}',
                                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                          // Créateur
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _navigateToCreatorProfileByCreatorId(content.creatorId),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[800],
                                  ),
                                  child: const Icon(Icons.person, size: 12, color: Colors.grey),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Créateur',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}