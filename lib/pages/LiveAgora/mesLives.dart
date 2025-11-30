import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';

import '../../providers/authProvider.dart';
import 'livePage.dart';
import 'livesAgora.dart';

// Models
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';

import '../../providers/authProvider.dart';
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
  Map<String, bool> _processingWithdrawal = {};
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

  Future<void> _deleteLive(PostLive live) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _processingDeletion[live.liveId!] = true;
    });

    try {
      // Vérifier que le live n'est pas en cours
      if (live.isLive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Impossible de supprimer un live en cours'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Supprimer le live de Firestore
      await _firestore.collection('lives').doc(live.liveId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Live supprimé avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      // Recharger la liste
      await _loadUserLives();

    } catch (e) {
      print("❌ Erreur suppression live: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de la suppression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _processingDeletion.remove(live.liveId);
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

  void _showDeleteConfirmation(PostLive live) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Supprimer le live', style: TextStyle(color: Colors.white)),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer définitivement ce live?\n'
              'Cette action est irréversible.',
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
              _deleteLive(live);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Supprimer', style: TextStyle(color: Colors.white)),
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

  Widget _buildLiveItem(PostLive live) {
    final authProvider = context.watch<UserAuthProvider>();
    final isLive = live.isLive;
    final isInvited = live.invitedUsers.contains(authProvider.userId);
    final isHost = live.hostId == authProvider.userId;
    final earningsWithdrawn = live.earningsWithdrawn ?? false;
    final canWithdraw = !isLive && live.giftTotal > 0 && !earningsWithdrawn;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isPaidLive = live.isPaidLive;
    final hasPinnedText = live.pinnedText != null && live.pinnedText!.isNotEmpty;

    // Calcul des totaux pour les lives terminés
    final totalSpectateurs = live.totalspectateurs.length;
    final totalParticipants = live.participants.length;
    final totalSpectateursSeuls = live.spectators.length;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? Colors.red : Colors.grey[700]!,
          width: isLive ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // En-tête avec image et badges
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  image: DecorationImage(
                    image: NetworkImage(live.hostImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Overlay pour lives terminés
              if (!isLive)
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),

              // Badges
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLive ? Colors.red : Colors.grey[700]!,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLive ? Icons.circle : Icons.check_circle,
                        color: Colors.white,
                        size: 8,
                      ),
                      SizedBox(width: 4),
                      Text(
                        isLive ? 'LIVE' : 'TERMINÉ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Badge Live Privé
              if (isPaidLive)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, color: Colors.white, size: 10),
                        SizedBox(width: 2),
                        Text(
                          'PRIVÉ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Contenu principal
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre et date
                Row(
                  children: [
                    if (hasPinnedText)
                      Icon(Icons.push_pin, color: Color(0xFFF9A825), size: 12),
                    SizedBox(width: hasPinnedText ? 4 : 0),
                    Expanded(
                      child: Text(
                        live.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 4),

                Text(
                  '${dateFormat.format(live.startTime)}',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),

                SizedBox(height: 12),

                // Statistiques principales
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                        Icons.people,
                        isLive ? 'Spectateurs' : 'Total spectateurs',
                        isLive ? '${live.viewerCount}' : '$totalSpectateurs',
                        Colors.blue
                    ),
                    _buildStatItem(
                        Icons.favorite,
                        'Likes',
                        '${live.likeCount ?? 0}',
                        Colors.pink
                    ),
                    _buildStatItem(
                        Icons.card_giftcard,
                        'Cadeaux',
                        '${live.gifts.length}',
                        Color(0xFFF9A825)
                    ),
                    _buildStatItem(
                        Icons.share,
                        'Partages',
                        '${live.shareCount}',
                        Colors.green
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Boutons d'action
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (isLive) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LivePage(
                                  liveId: live.liveId!,
                                  isHost: isHost,
                                  hostName: live.hostName!,
                                  hostImage: live.hostImage!,
                                  isInvited: isInvited,
                                  postLive: live,
                                ),
                              ),
                            );
                          } else {
                            _showLiveDetailsDialog(live);
                          }
                        },
                        icon: Icon(isLive ? Icons.play_arrow : Icons.visibility, size: 16),
                        label: Text(isLive ? 'Rejoindre' : 'Voir détails'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLive ? Colors.red : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),

                    SizedBox(width: 8),

                    // Bouton suppression pour les lives terminés
                    if (!isLive)
                      _processingDeletion[live.liveId] == true
                          ? Container(
                        width: 40,
                        height: 40,
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          color: Colors.red,
                          strokeWidth: 2,
                        ),
                      )
                          : IconButton(
                        onPressed: () => _showDeleteConfirmation(live),
                        icon: Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Supprimer le live',
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Section gains et encaissement
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gains totaux',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      '${live.giftTotal.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        color: Color(0xFFF9A825),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (live.paidParticipationTotal > 0)
                      Text(
                        '+ ${live.paidParticipationTotal.toStringAsFixed(0)} FCFA (participations)',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
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
                      style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (earningsWithdrawn)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[800],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '✅ Encaissé',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                else if (live.giftTotal == 0)
                    Text(
                      'Aucun gain',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  void _showLiveDetailsDialog(PostLive live) {
    final duration = _calculateDuration(live);
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');

    // Calcul des totaux
    final totalSpectateurs = live.totalspectateurs.length;
    final totalParticipants = live.participants.length;
    final totalSpectateursSeuls = live.spectators.length;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey[700]!, width: 1)
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Center(
                child: Text(
                  '📊 Détails du Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Titre
              Text(
                live.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 15),

              // Informations hôte
              _buildDetailRow('👤 Hôte:', live.hostName!),
              _buildDetailRow('📅 Début:', dateFormat.format(live.startTime)),
              if (live.endTime != null)
                _buildDetailRow('⏱️ Durée:', duration),

              SizedBox(height: 15),

              // Statistiques d'audience
              Text(
                '👥 Audience',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildStatCard('👥 Total spectateurs', '$totalSpectateurs', Icons.people, Colors.blue),
                  // _buildStatCard('🎤 Participants', '$totalParticipants', Icons.mic, Colors.green),
                  _buildStatCard('👀 Spectateurs', '$totalSpectateursSeuls', Icons.visibility, Colors.orange),
                  _buildStatCard('❤️ Likes', '${live.likeCount ?? 0}', Icons.favorite, Colors.pink),
                ],
              ),

              SizedBox(height: 15),

              // Autres statistiques
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildStatCard('🎁 Cadeaux', '${live.gifts.length}', Icons.card_giftcard, Color(0xFFF9A825)),
                  _buildStatCard('📤 Partages', '${live.shareCount}', Icons.share, Colors.green),
                  if (live.isPaidLive)
                    _buildStatCard('💰 Participations', '${live.paidParticipationTotal.toStringAsFixed(0)} FCFA', Icons.payment, Colors.purple),
                  // _buildStatCard('👥 Invités', '${live.invitedUsers.length}', Icons.mail, Colors.cyan),
                ],
              ),

              SizedBox(height: 15),

              // Revenus
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[900]!.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    Text(
                      '💰 Revenus générés',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '${live.giftTotal.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (live.paidParticipationTotal > 0)
                      Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Text(
                          '+ ${live.paidParticipationTotal.toStringAsFixed(0)} FCFA (participations)',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 15),

              // Type de live
              if (live.isPaidLive)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple[900]!.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: Colors.purpleAccent, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Live Privé - Accès payant',
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 20),

              // Bouton fermer
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text(
                    'Fermer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        )
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

// class UserLivesPage extends StatefulWidget {
//   @override
//   _UserLivesPageState createState() => _UserLivesPageState();
// }
//
// class _UserLivesPageState extends State<UserLivesPage> {
//   final RefreshController _refreshController = RefreshController(initialRefresh: false);
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   List<PostLive> _userLives = [];
//   bool _isLoading = true;
//   Map<String, bool> _processingWithdrawal = {};
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserLives();
//   }
//
//   Future<void> _loadUserLives() async {
//     try {
//       final user = _auth.currentUser;
//       if (user == null) return;
//
//       final querySnapshot = await _firestore
//           .collection('lives')
//           .where('hostId', isEqualTo: user.uid)
//           .orderBy('startTime', descending: true)
//           .get();
//
//       setState(() {
//         _userLives = querySnapshot.docs.map((doc) {
//           return PostLive.fromMap(doc.data());
//         }).toList();
//         _isLoading = false;
//       });
//     } catch (e) {
//       print("❌ Erreur chargement lives utilisateur: $e");
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   void _onRefresh() async {
//     await _loadUserLives();
//     _refreshController.refreshCompleted();
//   }
//
//   Future<void> _withdrawEarnings(PostLive live) async {
//     final user = _auth.currentUser;
//     if (user == null || live.giftTotal <= 0) return;
//
//     setState(() {
//       _processingWithdrawal[live.liveId!] = true;
//     });
//
//     try {
//       final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//
//       // Vérifier si le live a déjà été encaissé
//       final liveDoc = await _firestore.collection('lives').doc(live.liveId).get();
//       if (liveDoc.exists && liveDoc.data()!['earningsWithdrawn'] == true) {
//         ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Les gains de ce live ont déjà été encaissés.'))
//         );
//         return;
//       }
//
//       // Créer la transaction
//       final transactionId = _firestore.collection('TransactionSoldes').doc().id;
//       final transactionSolde = {
//         'id': transactionId,
//         'user_id': user.uid,
//         'type': 'DEPOT',
//         'statut': 'VALIDER',
//         'description': 'Encaissement gains live: ${live.title}',
//         'montant': live.giftTotal,
//         'methode_paiement': 'live_earnings',
//         'live_id': live.liveId,
//         'createdAt': DateTime.now().millisecondsSinceEpoch,
//         'updatedAt': DateTime.now().millisecondsSinceEpoch,
//       };
//
//       // Mettre à jour le solde de l'utilisateur
//       final newBalance = (authProvider.loginUserData.votre_solde_principal ?? 0) + live.giftTotal;
//
//       // Exécuter la transaction Firestore
//       await _firestore.runTransaction((transaction) async {
//         // Ajouter la transaction
//         transaction.set(
//             _firestore.collection('TransactionSoldes').doc(transactionId),
//             transactionSolde
//         );
//
//         // Mettre à jour le solde utilisateur
//         transaction.update(
//             _firestore.collection('Users').doc(user.uid),
//             {'votre_solde_principal': newBalance}
//         );
//
//         // Marquer les gains comme encaissés
//         transaction.update(
//             _firestore.collection('lives').doc(live.liveId),
//             {
//               'earningsWithdrawn': true,
//               'withdrawalDate': DateTime.now(),
//               'withdrawalTransactionId': transactionId
//             }
//         );
//       });
//
//       // Mettre à jour les données locales
//       // authProvider.updateUserBalance(newBalance);
//
//       ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('✅ ${live.giftTotal} FCFA encaissés avec succès!'),
//             backgroundColor: Colors.green,
//           )
//       );
//
//       // Recharger la liste
//       await _loadUserLives();
//
//     } catch (e) {
//       print("❌ Erreur encaissement: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Erreur lors de l\'encaissement: $e'),
//             backgroundColor: Colors.red,
//           )
//       );
//     } finally {
//       setState(() {
//         _processingWithdrawal.remove(live.liveId);
//       });
//     }
//   }
//
//   void _showWithdrawalConfirmation(PostLive live) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         title: Text('Encaisser les gains', style: TextStyle(color: Colors.white)),
//         content: Text(
//           'Voulez-vous encaisser ${live.giftTotal} FCFA de gains de ce live? '
//               'Le montant sera ajouté à votre solde principal.',
//           style: TextStyle(color: Colors.white70),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Annuler', style: TextStyle(color: Colors.grey)),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _withdrawEarnings(live);
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Color(0xFFF9A825),
//             ),
//             child: Text('Encaisser', style: TextStyle(color: Colors.black)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Mes Lives', style: TextStyle(color: Color(0xFFF9A825))),
//         backgroundColor: Colors.black,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh, color: Color(0xFFF9A825)),
//             onPressed: _loadUserLives,
//           ),
//         ],
//       ),
//       backgroundColor: Colors.black,
//       body: SmartRefresher(
//         controller: _refreshController,
//         onRefresh: _onRefresh,
//         enablePullDown: true,
//         header: WaterDropHeader(
//           waterDropColor: Color(0xFFF9A825),
//           complete: Icon(Icons.check, color: Color(0xFFF9A825)),
//         ),
//         child: _isLoading
//             ? _buildLoadingState()
//             : _userLives.isEmpty
//             ? _buildEmptyState()
//             : _buildLivesList(),
//       ),
//     );
//   }
//
//   Widget _buildLoadingState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(color: Color(0xFFF9A825)),
//           SizedBox(height: 16),
//           Text('Chargement de vos lives...', style: TextStyle(color: Colors.white)),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.videocam_off, size: 64, color: Colors.grey),
//           SizedBox(height: 16),
//           Text(
//             'Aucun live créé',
//             style: TextStyle(color: Colors.white, fontSize: 18),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Commencez par créer votre premier live!',
//             style: TextStyle(color: Colors.grey, fontSize: 14),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLivesList() {
//     return ListView.builder(
//       padding: EdgeInsets.all(16),
//       itemCount: _userLives.length,
//       itemBuilder: (context, index) {
//         final live = _userLives[index];
//         return _buildLiveItem(live);
//       },
//     );
//   }
//   void _showLiveEndedDialog(PostLive live) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         title: Text('Live terminé', style: TextStyle(color: Colors.white)),
//         content: Text(
//           'Ce live s\'est terminé le ${_formatDate(live.startTime)}.\n\n'
//               '${live.viewerCount} personnes y ont assisté.',
//           style: TextStyle(color: Colors.white70),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Fermer', style: TextStyle(color: Color(0xFFF9A825))),
//           ),
//         ],
//       ),
//     );
//   }
//   String _formatDate(DateTime date) {
//     return '${date.day}/${date.month}/${date.year}';
//   }
//   Widget _buildLiveItem(PostLive live) {
//     final authProvider = context.watch<UserAuthProvider>();
//     final isLive = live.isLive;
//     final isInvited = live.invitedUsers.contains(authProvider.userId);
//     final isHost = live.hostId == authProvider.userId;
//     final earningsWithdrawn = live.earningsWithdrawn ?? false;
//     final canWithdraw = !isLive && live.giftTotal > 0 && !earningsWithdrawn;
//     final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
//
//     printVm('Live love account: ${live.toMap()}');
//
//     return Container(
//       margin: EdgeInsets.only(bottom: 16),
//       decoration: BoxDecoration(
//         color: Colors.grey[900],
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: isLive ? Colors.red : Colors.grey,
//           width: isLive ? 2 : 1,
//         ),
//       ),
//       child: Column(
//         children: [
//           ListTile(
//             contentPadding: EdgeInsets.all(12),
//             leading: CircleAvatar(
//               radius: 25,
//               backgroundImage: NetworkImage(live.hostImage!),
//               backgroundColor: Colors.grey,
//             ),
//             title: Text(
//               live.title,
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             subtitle: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   '${dateFormat.format(live.startTime)}',
//                   style: TextStyle(color: Colors.grey, fontSize: 12),
//                 ),
//                 SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Icon(Icons.people, size: 14, color: Colors.grey),
//                     SizedBox(width: 4),
//                     Text('${live.viewerCount}', style: TextStyle(color: Colors.grey, fontSize: 12)),
//                     SizedBox(width: 12),
//                     Icon(Icons.favorite, size: 14, color: Colors.grey),
//                     SizedBox(width: 4),
//                     Text('${live.likeCount ?? 0}', style: TextStyle(color: Colors.grey, fontSize: 12)),
//                   ],
//                 ),
//               ],
//             ),
//             trailing: isLive
//                 ? Container(
//               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.red,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 'VOIR EN DIRECT',
//                 style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
//               ),
//             )
//                 : null,
//             onTap: () {
//               if (isLive) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => LivePage(
//                       liveId: live.liveId!,
//                       isHost: isHost,
//                       hostName: live.hostName!,
//                       hostImage: live.hostImage!,
//                       isInvited: isInvited, postLive: live,
//                     ),
//                   ),
//                 );
//               } else {
//                 // Option: Naviguer vers une page de replay si disponible
//                 _showLiveEndedDialog(live);
//               }
//             },
//
//           ),
//
//           // Section gains et encaissement
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Gains',
//                       style: TextStyle(color: Colors.grey, fontSize: 12),
//                     ),
//                     Text(
//                       '${live.giftTotal} FCFA',
//                       style: TextStyle(
//                         color: Color(0xFFF9A825),
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//
//                 if (canWithdraw)
//                   _processingWithdrawal[live.liveId] == true
//                       ? CircularProgressIndicator(color: Color(0xFFF9A825), strokeWidth: 2)
//                       : ElevatedButton(
//                     onPressed: () => _showWithdrawalConfirmation(live),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Color(0xFFF9A825),
//                       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     ),
//                     child: Text(
//                       'Encaisser',
//                       style: TextStyle(color: Colors.black, fontSize: 12),
//                     ),
//                   )
//                 else if (earningsWithdrawn)
//                   Text(
//                     '✅ Encaissé',
//                     style: TextStyle(color: Colors.green, fontSize: 12),
//                   )
//                 else if (live.giftTotal == 0)
//                     Text(
//                       'Aucun gain',
//                       style: TextStyle(color: Colors.grey, fontSize: 12),
//                     ),
//               ],
//             ),
//           ),
//
//           // Informations supplémentaires pour les lives terminés
//           if (!isLive) ...[
//             Divider(color: Colors.grey[700], height: 1),
//             Padding(
//               padding: EdgeInsets.all(12),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _buildStatItem(Icons.schedule, 'Durée', _calculateDuration(live)),
//                   _buildStatItem(Icons.card_giftcard, 'Cadeaux', '${live.giftCount}'),
//                   _buildStatItem(Icons.people, 'Audiences', '${live.viewerCount}'),
//                   _buildStatItem(AntDesign.heart, 'Likes', '${live.likeCount}'),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatItem(IconData icon, String label, String value) {
//     return Column(
//       children: [
//         Icon(icon, size: 16, color: Colors.grey),
//         SizedBox(height: 4),
//         Text(value, style: TextStyle(color: Colors.white, fontSize: 12)),
//         Text(label, style: TextStyle(color: Colors.grey, fontSize: 10)),
//       ],
//     );
//   }
//
//   String _calculateDuration(PostLive live) {
//     final end = live.endTime ?? DateTime.now();
//     final duration = end.difference(live.startTime);
//
//     if (duration.inHours > 0) {
//       return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
//     } else {
//       return '${duration.inMinutes}m';
//     }
//   }
// }

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