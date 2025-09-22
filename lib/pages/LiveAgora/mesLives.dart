import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';

import '../../providers/authProvider.dart';
import 'livesAgora.dart';

// Models


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
  Map<String, bool> _processingWithdrawal = {};

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
        _userLives = querySnapshot.docs.map((doc) {
          return PostLive.fromMap(doc.data());
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Erreur chargement lives utilisateur: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onRefresh() async {
    await _loadUserLives();
    _refreshController.refreshCompleted();
  }

  Future<void> _withdrawEarnings(PostLive live) async {
    final user = _auth.currentUser;
    if (user == null || live.giftTotal <= 0) return;

    setState(() {
      _processingWithdrawal[live.liveId!] = true;
    });

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

      // Vérifier si le live a déjà été encaissé
      final liveDoc = await _firestore.collection('lives').doc(live.liveId).get();
      if (liveDoc.exists && liveDoc.data()!['earningsWithdrawn'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Les gains de ce live ont déjà été encaissés.'))
        );
        return;
      }

      // Créer la transaction
      final transactionId = _firestore.collection('TransactionSoldes').doc().id;
      final transactionSolde = {
        'id': transactionId,
        'user_id': user.uid,
        'type': 'DEPOT',
        'statut': 'VALIDER',
        'description': 'Encaissement gains live: ${live.title}',
        'montant': live.giftTotal,
        'methode_paiement': 'live_earnings',
        'live_id': live.liveId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Mettre à jour le solde de l'utilisateur
      final newBalance = (authProvider.loginUserData.votre_solde_principal ?? 0) + live.giftTotal;

      // Exécuter la transaction Firestore
      await _firestore.runTransaction((transaction) async {
        // Ajouter la transaction
        transaction.set(
            _firestore.collection('TransactionSoldes').doc(transactionId),
            transactionSolde
        );

        // Mettre à jour le solde utilisateur
        transaction.update(
            _firestore.collection('Users').doc(user.uid),
            {'votre_solde_principal': newBalance}
        );

        // Marquer les gains comme encaissés
        transaction.update(
            _firestore.collection('lives').doc(live.liveId),
            {
              'earningsWithdrawn': true,
              'withdrawalDate': DateTime.now(),
              'withdrawalTransactionId': transactionId
            }
        );
      });

      // Mettre à jour les données locales
      // authProvider.updateUserBalance(newBalance);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${live.giftTotal} FCFA encaissés avec succès!'),
            backgroundColor: Colors.green,
          )
      );

      // Recharger la liste
      await _loadUserLives();

    } catch (e) {
      print("❌ Erreur encaissement: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de l\'encaissement: $e'),
            backgroundColor: Colors.red,
          )
      );
    } finally {
      setState(() {
        _processingWithdrawal.remove(live.liveId);
      });
    }
  }

  void _showWithdrawalConfirmation(PostLive live) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Encaisser les gains', style: TextStyle(color: Colors.white)),
        content: Text(
          'Voulez-vous encaisser ${live.giftTotal} FCFA de gains de ce live? '
              'Le montant sera ajouté à votre solde principal.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _withdrawEarnings(live);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF9A825),
            ),
            child: Text('Encaisser', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mes Lives', style: TextStyle(color: Color(0xFFF9A825))),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFFF9A825)),
            onPressed: _loadUserLives,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        enablePullDown: true,
        header: WaterDropHeader(
          waterDropColor: Color(0xFFF9A825),
          complete: Icon(Icons.check, color: Color(0xFFF9A825)),
        ),
        child: _isLoading
            ? _buildLoadingState()
            : _userLives.isEmpty
            ? _buildEmptyState()
            : _buildLivesList(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFF9A825)),
          SizedBox(height: 16),
          Text('Chargement de vos lives...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucun live créé',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Commencez par créer votre premier live!',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLivesList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _userLives.length,
      itemBuilder: (context, index) {
        final live = _userLives[index];
        return _buildLiveItem(live);
      },
    );
  }
  void _showLiveEndedDialog(PostLive live) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Live terminé', style: TextStyle(color: Colors.white)),
        content: Text(
          'Ce live s\'est terminé le ${_formatDate(live.startTime)}.\n\n'
              '${live.viewerCount} personnes y ont assisté.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: Color(0xFFF9A825))),
          ),
        ],
      ),
    );
  }
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  Widget _buildLiveItem(PostLive live) {
    final authProvider = context.watch<UserAuthProvider>();
    final isLive = live.isLive;
    final isInvited = live.invitedUsers.contains(authProvider.userId);
    final isHost = live.hostId == authProvider.userId;
    final earningsWithdrawn = live.earningsWithdrawn ?? false;
    final canWithdraw = !isLive && live.giftTotal > 0 && !earningsWithdrawn;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? Colors.red : Colors.grey,
          width: isLive ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.all(12),
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage(live.hostImage!),
              backgroundColor: Colors.grey,
            ),
            title: Text(
              live.title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dateFormat.format(live.startTime)}',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('${live.viewerCount}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    SizedBox(width: 12),
                    Icon(Icons.favorite, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('${live.giftCount ?? 0}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            trailing: isLive
                ? Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'VOIR EN DIRECT',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
                : null,
            onTap: () {
              if (isLive) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LivePage(
                      liveId: live.liveId!,
                      isHost: isHost,
                      hostName: live.hostName!,
                      hostImage: live.hostImage!,
                      isInvited: isInvited, postLive: live,
                    ),
                  ),
                );
              } else {
                // Option: Naviguer vers une page de replay si disponible
                _showLiveEndedDialog(live);
              }
            },

          ),

          // Section gains et encaissement
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gains',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      '${live.giftTotal} FCFA',
                      style: TextStyle(
                        color: Color(0xFFF9A825),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                if (canWithdraw)
                  _processingWithdrawal[live.liveId] == true
                      ? CircularProgressIndicator(color: Color(0xFFF9A825), strokeWidth: 2)
                      : ElevatedButton(
                    onPressed: () => _showWithdrawalConfirmation(live),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF9A825),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      'Encaisser',
                      style: TextStyle(color: Colors.black, fontSize: 12),
                    ),
                  )
                else if (earningsWithdrawn)
                  Text(
                    '✅ Encaissé',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  )
                else if (live.giftTotal == 0)
                    Text(
                      'Aucun gain',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
              ],
            ),
          ),

          // Informations supplémentaires pour les lives terminés
          if (!isLive) ...[
            Divider(color: Colors.grey[700], height: 1),
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(Icons.schedule, 'Durée', _calculateDuration(live)),
                  _buildStatItem(Icons.card_giftcard, 'Cadeaux', '${live.gifts.length}'),
                  _buildStatItem(Icons.people, 'Audiences', '${live.viewerCount}'),
                  // _buildStatItem(AntDesign.heart, 'Likes', '${live.}'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 12)),
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  String _calculateDuration(PostLive live) {
    final end = live.endTime ?? DateTime.now();
    final duration = end.difference(live.startTime);

    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}

// Extension pour ajouter les nouveaux champs à PostLive
extension PostLiveExtension on PostLive {
  bool? get earningsWithdrawn {
    // Cette propriété devrait être récupérée depuis Firestore
    // Pour l'instant, on retourne null
    return null;
  }

  // Méthode pour mettre à jour les données depuis un snapshot
  PostLive copyWithEarningsInfo(bool withdrawn, String? transactionId, DateTime? withdrawalDate) {
    return PostLive(
      liveId: liveId,
      hostId: hostId,
      hostName: hostName,
      hostImage: hostImage,
      title: title,
      viewerCount: viewerCount,
      giftCount: giftCount,
      startTime: startTime,
      endTime: endTime,
      isLive: isLive,
      giftTotal: giftTotal,
      gifts: gifts,
      paymentRequired: paymentRequired,
      paymentRequestTime: paymentRequestTime,
      invitedUsers: invitedUsers,
      participants: participants,
      spectators: spectators,
      participationFee: participationFee,
    );
  }
}