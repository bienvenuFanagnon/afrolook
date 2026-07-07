// admin_email_screen.dart

import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminEmailScreen extends StatefulWidget {
  @override
  _AdminEmailScreenState createState() => _AdminEmailScreenState();
}

class _AdminEmailScreenState extends State<AdminEmailScreen> {
  // Controllers
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // États
  bool _isSending = false;
  bool _isLoading = false;
  bool _hasMore = true;
  String _searchQuery = '';

  // Données
  List<Map<String, dynamic>> _users = [];
  DocumentSnapshot? _lastDocument;

  // Pagination
  final int _pageSize = 10;

  // Couleurs
  final Color africanBlack = Color(0xFF1A1A1A);
  final Color africanRed = Color(0xFFE63946);
  final Color africanGold = Color(0xFFFFD700);
  final Color africanGreen = Color(0xFF2ECC71);

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreUsers();
      }
    }
  }

  /// Calcule le nombre de jours d'inactivité en détectant automatiquement le format
  /// Supporte à la fois les millisecondes et les microsecondes
  int _calculateDaysInactive(int lastTimeActive) {
    if (lastTimeActive == 0) return 0;

    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    int diffMillis;

    // 🔥 DÉTECTION AUTOMATIQUE DU FORMAT
    // Si la valeur est très grande (> 10^12), c'est probablement en microsecondes
    // Sinon, c'est probablement en millisecondes
    if (lastTimeActive > 1000000000000) {
      // Format microsecondes → convertir en millisecondes
      final lastTimeActiveMillis = lastTimeActive ~/ 1000;
      diffMillis = nowMillis - lastTimeActiveMillis;
    } else {
      // Format millisecondes
      diffMillis = nowMillis - lastTimeActive;
    }

    // Vérifier si le résultat est aberrant (si oui, essayer l'autre format)
    final daysInactive = (diffMillis / 86400000).floor();

    // Si le résultat est > 500 jours (anormal pour l'application qui n'a pas 2 ans),
    // réessayer avec l'autre format
    if (daysInactive > 500 && lastTimeActive > 0) {
      if (lastTimeActive > 1000000000000) {
        // On était en μs, essayer en ms
        final lastTimeActiveMillis = lastTimeActive;
        diffMillis = nowMillis - lastTimeActiveMillis;
      } else {
        // On était en ms, essayer en μs
        final lastTimeActiveMicros = lastTimeActive * 1000;
        final lastTimeActiveMillis = lastTimeActiveMicros ~/ 1000;
        diffMillis = nowMillis - lastTimeActiveMillis;
      }
      return (diffMillis / 86400000).floor().clamp(0, 500);
    }

    return daysInactive < 0 ? 0 : daysInactive.clamp(0, 500);
  }

  Map<String, dynamic> _processUserData(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lastTimeActive = data['last_time_active'] ?? 0;
    final daysInactive = _calculateDaysInactive(lastTimeActive);

    return {
      'id': doc.id,
      'pseudo': data['pseudo'] ?? 'Sans pseudo',
      'email': data['email'] ?? '',
      'imageUrl': data['imageUrl'],
      'giftCoinsBalance': data['giftCoinsBalance'] ?? 0,
      'soldePrincipal': data['votre_solde_principal'] ?? 0,
      'totalCoinsEarned': data['totalCoinsEarnedFromLikes'] ?? 0,
      'totalLikesReceived': data['totalLikesReceived'] ?? 0,
      'totalFollowers': (data['userAbonnesIds'] as List?)?.length ?? 0,
      'daysInactive': daysInactive,
      'isInactive': daysInactive >= 3 && lastTimeActive > 0,
      'rawTimestamp': lastTimeActive, // Pour débogage (optionnel)
    };
  }

  Future<void> _loadUsers({bool reset = true}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _users.clear();
        _lastDocument = null;
        _hasMore = true;
      }
    });

    try {
      Query query;

      if (_searchQuery.isNotEmpty) {
        final endQuery = _searchQuery + '\uf8ff';
        query = FirebaseFirestore.instance
            .collection('Users')
            .where('pseudo', isGreaterThanOrEqualTo: _searchQuery)
            .where('pseudo', isLessThanOrEqualTo: endQuery)
            .limit(_pageSize);
      } else {
        query = FirebaseFirestore.instance
            .collection('Users')
            .where('email', isNotEqualTo: null)
            .where('email', isNotEqualTo: '')
            .orderBy('pseudo')
            .limit(_pageSize);

        if (_lastDocument != null) {
          query = query.startAfterDocument(_lastDocument!);
        }
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        final newUsers = snapshot.docs.map((doc) => _processUserData(doc)).toList();

        setState(() {
          if (reset) {
            _users = newUsers;
          } else {
            _users.addAll(newUsers);
          }
          _lastDocument = snapshot.docs.last;
          _hasMore = snapshot.docs.length >= _pageSize;
        });
      }
    } catch (e) {
      printVm('Erreur chargement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement: $e'), backgroundColor: africanRed),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreUsers() async {
    if (!_hasMore || _isLoading) return;
    await _loadUsers(reset: false);
  }

  void _searchUsers(String query) {
    setState(() {
      _searchQuery = query.trim();
      _lastDocument = null;
      _hasMore = true;
      _users.clear();
    });
    _loadUsers(reset: true);
  }

  Future<void> _sendReminderToUser(Map<String, dynamic> user) async {
    setState(() => _isSending = true);

    try {
      // Compter les nouveaux likes (7 derniers jours)
      final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch;
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('Posts')
          .where('user_id', isEqualTo: user['id'])
          .get();

      int newLikesCount = 0;
      for (var postDoc in postsSnapshot.docs) {
        final post = postDoc.data();
        int postCreatedAt = post['created_at'] ?? 0;

        // Normaliser le timestamp du post
        if (postCreatedAt > 1000000000000) {
          postCreatedAt = postCreatedAt ~/ 1000;
        }

        if (postCreatedAt > sevenDaysAgo) {
          newLikesCount += (post['loves'] as int? ?? 0);
        }
      }

      final userEmailData = {
        'userId': user['id'],
        'userEmail': user['email'],
        'userName': user['pseudo'],
        'pseudo': user['pseudo'],
        'giftCoinsBalance': user['giftCoinsBalance'],
        'soldePrincipal': user['soldePrincipal'],
        'totalCoinsEarned': user['totalCoinsEarned'],
        'totalLikesReceived': user['totalLikesReceived'],
        'totalFollowers': user['totalFollowers'],
        'daysInactive': user['daysInactive'],
        'newLikesOnMyPosts': newLikesCount,
        'newCommentsOnMyPosts': 0,
      };

      final functions = FirebaseFunctions.instance;
      final result = await functions
          .httpsCallable('sendInactiveUserReminder')
          .call({
        'userId': user['id'],
        'userData': userEmailData,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.data['success'] == true
                ? '✅ Email envoyé à ${user['email']}'
                : '❌ ${result.data['message']}'),
            backgroundColor: result.data['success'] == true ? Colors.green : africanRed,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: africanRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendToInactiveUsers() async {
    final inactiveUsers = _users.where((u) => u['isInactive'] == true).toList();

    if (inactiveUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun utilisateur inactif dans la liste'), backgroundColor: africanRed),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Envoyer à ${inactiveUsers.length} utilisateurs inactifs ?'),
        content: Text('Cette action enverra un email personnalisé à tous les utilisateurs inactifs (3+ jours) affichés dans la liste.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: africanRed),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);

    int success = 0;
    int failed = 0;

    for (var user in inactiveUsers) {
      try {
        await _sendReminderToUser(user);
        success++;
        await Future.delayed(Duration(milliseconds: 500));
      } catch (e) {
        failed++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $success envoyés, $failed échoués'),
          backgroundColor: success > 0 ? Colors.green : africanRed,
        ),
      );
      setState(() => _isSending = false);
    }
  }

  int get _inactiveCount => _users.where((u) => u['isInactive'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Envoi de rappels', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: africanBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [africanBlack, africanRed]),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: africanGold),
            onPressed: () => _loadUsers(reset: true),
            tooltip: 'Recharger',
          ),
        ],
      ),
      body: _isSending
          ? Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [africanBlack.withOpacity(0.9), africanRed.withOpacity(0.9)]),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: CircularProgressIndicator(color: africanGold, strokeWidth: 4),
              ),
              SizedBox(height: 30),
              Text('Envoi en cours...', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
        ),
      )
          : Column(
        children: [
          // Barre de recherche
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Rechercher par pseudo ou email...',
                prefixIcon: Icon(Icons.search, color: africanGold),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _searchUsers('');
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),

          // Stats et bouton d'envoi groupé
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: africanRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: africanRed, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '$_inactiveCount inactifs',
                        style: TextStyle(color: africanRed, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                if (_inactiveCount > 0)
                  ElevatedButton.icon(
                    onPressed: _sendToInactiveUsers,
                    icon: Icon(Icons.send, size: 18),
                    label: Text('Envoyer à tous les inactifs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: africanRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
              ],
            ),
          ),

          // Liste des utilisateurs
          Expanded(
            child: _isLoading && _users.isEmpty
                ? Center(child: CircularProgressIndicator(color: africanGold))
                : _users.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucun utilisateur trouvé', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : CenteredContent(child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(12),
              itemCount: _users.length + (_hasMore && _searchQuery.isEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _users.length) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(color: africanGold, strokeWidth: 2),
                    ),
                  );
                }

                final user = _users[index];
                final isInactive = user['isInactive'];

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isInactive
                        ? BorderSide(color: africanRed.withOpacity(0.5), width: 1)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['imageUrl'] != null ? NetworkImage(user['imageUrl']) : null,
                      backgroundColor: africanGold.withOpacity(0.2),
                      child: user['imageUrl'] == null ? Icon(Icons.person, color: africanGold) : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            user['pseudo'],
                            style: TextStyle(
                              fontWeight: isInactive ? FontWeight.bold : FontWeight.normal,
                              color: isInactive ? africanRed : africanBlack,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isInactive)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: africanRed.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${user['daysInactive']}j',
                              style: TextStyle(color: africanRed, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['email'], style: TextStyle(fontSize: 12)),
                        Row(
                          children: [
                            Icon(Icons.monetization_on, size: 12, color: africanGold),
                            SizedBox(width: 2),
                            Text(
                              '${user['giftCoinsBalance']} pièces',
                              style: TextStyle(fontSize: 10, color: africanGold),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.account_balance_wallet, size: 12, color: africanGreen),
                            SizedBox(width: 2),
                            Text(
                              '${user['soldePrincipal']} FCFA',
                              style: TextStyle(fontSize: 10, color: africanGreen),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _sendReminderToUser(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: africanGold,
                        foregroundColor: africanBlack,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text('Envoyer', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            )),
          ),
        ],
      ),
    );
  }
}