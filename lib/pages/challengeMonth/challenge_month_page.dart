// lib/pages/challenge/challenge_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/challengeMonh/challenge_month_service.dart';
import '../pub/native_ad_widget.dart';
import 'challenge_month_post_card.dart';

// lib/pages/challenge/challenge_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/challengeMonh/challenge_month_service.dart';
import '../pub/native_ad_widget.dart';
import 'challenge_month_post_card.dart';

// lib/pages/challenge/challenge_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/challengeMonh/challenge_month_service.dart';
import '../pub/native_ad_widget.dart';
import 'challenge_month_post_card.dart';

class ChallengeMonthPage extends StatefulWidget {
  const ChallengeMonthPage({Key? key}) : super(key: key);

  @override
  State<ChallengeMonthPage> createState() => _ChallengeMonthPageState();
}

class _ChallengeMonthPageState extends State<ChallengeMonthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChallengeMonthService _challengeService = ChallengeMonthService();

  // Variables pour la pagination des posts du mois courant
  List<Post> _currentMonthPosts = [];
  bool _loadingCurrent = true;
  bool _hasMoreCurrent = true;
  DocumentSnapshot? _lastDocumentCurrent;
  bool _isLoadingMoreCurrent = false;
  final int _batchSize = 5;

  // Variables pour l'historique
  List<ChallengeValidation> _historyValidations = [];
  List<DateTime> _monthsWithoutValidation = [];
  bool _loadingHistory = true;

  UserAuthProvider? _authProvider;
  String? _currentUserId;
  bool _isAdmin = false;
  ChallengeValidation? _currentMonthValidation;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  void _onScroll() {
    if (_tabController.index == 0) {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 &&
          !_isLoadingMoreCurrent &&
          _hasMoreCurrent &&
          !_loadingCurrent) {
        _loadMoreCurrentMonth();
      }
    }
  }

  Future<void> _loadData() async {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    _authProvider = auth;
    _currentUserId = auth.loginUserData.id;
    _isAdmin = auth.loginUserData.role == UserRole.ADM.name;

    await Future.wait([
      _loadCurrentMonth(),
      _loadHistory(),
    ]);
  }

  Future<void> _loadCurrentMonth() async {
    setState(() {
      _loadingCurrent = true;
      _currentMonthPosts.clear();
      _hasMoreCurrent = true;
      _lastDocumentCurrent = null;
    });

    try {
      final now = DateTime.now();
      final posts = await _challengeService.getPostsForMonthBatch(
        month: now,
        lastDocument: null,
        limit: _batchSize,
      );
      final validation = await _challengeService.getValidationForMonth(now);

      setState(() {
        _currentMonthPosts = posts;
        _currentMonthValidation = validation;
        _hasMoreCurrent = posts.length == _batchSize;
        if (posts.isNotEmpty) {
          _updateLastDocument(posts.last.id!);
        }
        _loadingCurrent = false;
      });
    } catch (e) {
      print('Erreur chargement mois courant: $e');
      setState(() => _loadingCurrent = false);
    }
  }

  Future<void> _loadMoreCurrentMonth() async {
    if (_isLoadingMoreCurrent || !_hasMoreCurrent || _lastDocumentCurrent == null) return;

    setState(() => _isLoadingMoreCurrent = true);

    try {
      final now = DateTime.now();
      final posts = await _challengeService.getPostsForMonthBatch(
        month: now,
        lastDocument: _lastDocumentCurrent,
        limit: _batchSize,
      );

      if (posts.isNotEmpty) {
        setState(() {
          _currentMonthPosts.addAll(posts);
          _hasMoreCurrent = posts.length == _batchSize;
          if (posts.isNotEmpty) {
            _updateLastDocument(posts.last.id!);
          }
        });
      } else {
        setState(() => _hasMoreCurrent = false);
      }
    } catch (e) {
      print('Erreur chargement plus: $e');
    } finally {
      setState(() => _isLoadingMoreCurrent = false);
    }
  }

  Future<void> _updateLastDocument(String postId) async {
    final doc = await FirebaseFirestore.instance.collection('Posts').doc(postId).get();
    _lastDocumentCurrent = doc;
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final validations = await _challengeService.getHistoryValidations();
      final monthsWithout = await _challengeService.getMonthsWithoutValidation();
      setState(() {
        _historyValidations = validations;
        _monthsWithoutValidation = monthsWithout;
        _loadingHistory = false;
      });
    } catch (e) {
      print('Erreur chargement historique: $e');
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _validateWinnerForMonth(Post winnerPost, DateTime month) async {
    if (!_isAdmin) return;
    if (!_challengeService.isMonthOver(month)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de valider un mois non terminé'), backgroundColor: Colors.orange),
      );
      return;
    }

    final prizeController = TextEditingController(text: '5000');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Valider le gagnant', style: TextStyle(color: Color(0xFFFFD600))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mois : ${DateFormat('MMMM yyyy').format(month)}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Post de @${winnerPost.user?.pseudo ?? winnerPost.canal?.titre}', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(
              controller: prizeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Montant du prix (FCFA)',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), foregroundColor: Colors.black),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prize = double.tryParse(prizeController.text) ?? 5000;
      try {
        await _challengeService.validateWinner(
          month: month,
          winnerPostId: winnerPost.id!,
          winnerUserId: winnerPost.user_id!,
          prizeAmount: prize,
          adminId: _currentUserId!,
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Gagnant validé !'), backgroundColor: Colors.green));
        await _loadCurrentMonth();
        await _loadHistory();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _cancelWinnerForMonth(DateTime month) async {
    if (!_isAdmin) return;

    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Annuler le gagnant', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mois : ${DateFormat('MMMM yyyy').format(month)}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Motif d\'annulation',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm == true && reasonController.text.isNotEmpty) {
      try {
        await _challengeService.cancelWinnerForMonth(month, reasonController.text, _currentUserId!);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Gagnant annulé'), backgroundColor: Colors.orange));
        await _loadCurrentMonth();
        await _loadHistory();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _payoutWinner(Post winnerPost, DateTime month) async {
    try {
      await _challengeService.payoutWinner(
        winnerPost: winnerPost,
        currentUser: _authProvider!.loginUserData,
        authProvider: _authProvider!,
        month: month,
      );
      final validation = await _challengeService.getValidationForMonth(month);
      final amount = validation?.prizeAmount ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💰 ${amount.toInt()} FCFA ajoutés à votre solde !'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadCurrentMonth();
      await _loadHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur encaissement: $e'), backgroundColor: Colors.red));
    }
  }

  Future<Post?> _getPostById(String postId) async {
    final doc = await FirebaseFirestore.instance.collection('Posts').doc(postId).get();
    if (doc.exists) return Post.fromJson(doc.data()!);
    return null;
  }

  String _monthName(int month) {
    const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Challenge du mois', style: TextStyle(color: Color(0xFFFFD600))),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD600),
          labelColor: const Color(0xFFFFD600),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Ce mois', icon: Icon(Icons.emoji_events)),
            Tab(text: 'Historique', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurrentMonthTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  // =================== ONGLET CE MOIS ===================
  Widget _buildCurrentMonthTab() {
    if (_loadingCurrent) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD600)));
    }

    final isWinnerValidated = _currentMonthValidation != null && _currentMonthValidation!.status == 'validated';
    final winnerPostId = _currentMonthValidation?.winnerPostId;
    final prizeAmount = _currentMonthValidation?.prizeAmount ?? 5000;
    final isPayoutCompleted = _currentMonthValidation?.payoutCompleted ?? false;
    final bool isMonthFinished = _challengeService.isMonthOver(DateTime.now());

    if (_currentMonthPosts.isEmpty && !_loadingCurrent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Aucun post éligible ce mois', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            FutureBuilder<DateTime>(
              future: _challengeService.getChallengeStartDate(),
              builder: (context, snapshot) {
                final date = snapshot.data ?? DateTime(2026, 4, 12);
                return Text(
                  'Les posts doivent être créés après ${DateFormat('dd/MM/yyyy').format(date)}',
                  style: const TextStyle(color: Colors.grey),
                );
              },
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCurrentMonth,
      color: const Color(0xFFFFD600),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Carte info
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD600), Color(0xFFF9A825)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('🏆 PRINCIPE DU CHALLENGE 🏆', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                const Text(
                  'Chaque mois, le post avec le plus d\'interactions (vues, likes, commentaires, partages) remporte un prix. '
                      'Seuls les posts originaux (non publicitaires) sont éligibles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  '💰 Prix du mois : ${prizeAmount.toInt()} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ],
            ),
          ),
          const MrecAdWidget(useBanner: true, showLessAdsButton: false),
          const SizedBox(height: 8),

          // 🔥 Liste des posts (déjà dans l'ordre du plus d'interactions au moins)
          ..._currentMonthPosts.asMap().entries.map((entry) {
            final index = entry.key;
            final post = entry.value;
            final isWinner = isWinnerValidated && winnerPostId == post.id;
            final showPayoutButton = isWinner &&
                post.user_id == _currentUserId &&
                !isPayoutCompleted;

            return ChallengePostCard(
              post: post,
              rank: index + 1,
              isWinner: isWinner,
              onPayout: showPayoutButton ? () => _payoutWinner(post, DateTime.now()) : null,
            );
          }).toList(),

          // Indicateur de chargement
          if (_isLoadingMoreCurrent)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD600))),
            ),

          if (!_hasMoreCurrent && _currentMonthPosts.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Fin du classement', style: TextStyle(color: Colors.grey))),
            ),

          // Section admin
          if (_isAdmin && _currentMonthPosts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: !isMonthFinished
                  ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La validation du gagnant sera possible à partir du 1er du mois prochain.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              )
                  : Row(
                children: [
                  if (!isWinnerValidated)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _validateWinnerForMonth(_currentMonthPosts.first, DateTime.now()),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('VALIDER LE GAGNANT'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), foregroundColor: Colors.black),
                      ),
                    ),
                  if (isWinnerValidated)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelWinnerForMonth(DateTime.now()),
                        icon: const Icon(Icons.cancel),
                        label: const Text('ANNULER LE GAGNANT'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // =================== ONGLET HISTORIQUE ===================

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD600)));
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFFFFD600),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Mois déjà validés (gagnants historiques)
          if (_historyValidations.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('🏆 GAGNANTS DES MOIS PRÉCÉDENTS', style: TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold)),
            ),
            ..._historyValidations.map((validation) {
              return FutureBuilder<Post?>(
                future: _getPostById(validation.winnerPostId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final post = snapshot.data!;
                  final isOwner = post.user_id == _currentUserId;
                  final canPayout = isOwner && !validation.payoutCompleted;
                  final monthDate = DateTime(validation.year, validation.month);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD600),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '🏆 ${_monthName(validation.month)} ${validation.year}',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '💰 ${validation.prizeAmount.toInt()} FCFA',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        ChallengePostCard(
                          post: post,
                          rank: 1,
                          isWinner: true,
                          onPayout: canPayout ? () => _payoutWinner(post, monthDate) : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    validation.payoutCompleted ? Icons.check_circle : Icons.pending,
                                    color: validation.payoutCompleted ? Colors.green : Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    validation.payoutCompleted
                                        ? 'Encaissé le ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(validation.payoutDate!))}'
                                        : 'En attente d\'encaissement',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                              if (_isAdmin && validation.status == 'validated')
                                TextButton.icon(
                                  onPressed: () => _cancelWinnerForMonth(monthDate),
                                  icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                                  label: const Text('Annuler', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ],

          // 🔥 MOIS SANS VALIDATION - VERSION AVEC CARTES COMPLÈTES
          if (_isAdmin && _monthsWithoutValidation.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Text('⏳ MOIS EN ATTENTE DE VALIDATION', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
            ..._monthsWithoutValidation.map((month) {
              if (!_challengeService.isMonthOver(month)) return const SizedBox.shrink();
              return FutureBuilder<List<Post>>(
                future: _challengeService.getTopPostsForMonthAdmin(month),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Card(
                      color: const Color(0xFF1A1A1A),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: const ListTile(
                        title: Text('Chargement...', style: TextStyle(color: Colors.white70)),
                      ),
                    );
                  }
                  final posts = snapshot.data!;
                  if (posts.isEmpty) {
                    return Card(
                      color: const Color(0xFF1A1A1A),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text('${_monthName(month.month)} ${month.year}', style: const TextStyle(color: Colors.white70)),
                        subtitle: const Text('Aucun post éligible ce mois', style: TextStyle(color: Colors.grey)),
                        trailing: const Icon(Icons.block, color: Colors.grey),
                      ),
                    );
                  }

                  // Afficher les posts en cartes complètes
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête du mois
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.access_time, color: Colors.orange, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_monthName(month.month)} ${month.year}',
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final winner = await _showWinnerPicker(posts, month);
                                  if (winner != null) {
                                    await _validateWinnerForMonth(winner, month);
                                  }
                                },
                                icon: const Icon(Icons.emoji_events, size: 18),
                                label: const Text('Valider le gagnant'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD600),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Liste des posts du mois
                        ...posts.asMap().entries.map((entry) {
                          final index = entry.key;
                          final post = entry.value;
                          return ChallengePostCard(
                            post: post,
                            rank: index + 1,
                            isWinner: false,
                            onPayout: null,
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ],

          if (_historyValidations.isEmpty && _monthsWithoutValidation.isEmpty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucun challenge terminé', style: TextStyle(color: Colors.white)),
                  MrecAdWidget(),
                ],
              ),
            ),

          const MrecAdWidget(useBanner: true, showLessAdsButton: false),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
// Ajouter cette méthode dans la classe _ChallengeMonthPageState
  Future<UserData?> _getUserForPost(Post post) async {
    // Si l'utilisateur est déjà chargé
    if (post.user != null) return post.user;

    // Si c'est un canal, retourner null (ou gérer différemment)
    if (post.canal_id != null && post.canal_id!.isNotEmpty) return null;

    // Si pas d'user_id
    if (post.user_id == null || post.user_id!.isEmpty) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(post.user_id)
          .get();

      if (doc.exists) {
        final user = UserData.fromJson(doc.data()!);
        post.user = user; // Mettre en cache
        return user;
      }
    } catch (e) {
      print('Erreur chargement user: $e');
    }
    return null;
  }
  Future<Post?> _showWinnerPicker(List<Post> posts, DateTime month) async {
    return showDialog<Post>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Choisir le gagnant - ${_monthName(month.month)} ${month.year}', style: const TextStyle(color: Color(0xFFFFD600))),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final score = post.totalInteractions ?? 0;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFFD600),
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.black)),
                ),
                title: Text('@${post.user?.pseudo ?? post.canal?.titre}', style: const TextStyle(color: Colors.white)),
                subtitle: Text('Score: $score interactions', style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.emoji_events, color: Color(0xFFFFD600)),
                onTap: () => Navigator.pop(context, post),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
