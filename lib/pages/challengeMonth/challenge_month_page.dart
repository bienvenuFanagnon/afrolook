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
  List<Post> _currentMonthPosts = [];
  bool _loadingCurrent = true;
  List<ChallengeValidation> _historyValidations = [];
  List<DateTime> _monthsWithoutValidation = [];
  bool _loadingHistory = true;
  UserAuthProvider? _authProvider;
  String? _currentUserId;
  bool _isAdmin = false;
  ChallengeValidation? _currentMonthValidation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
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
    setState(() => _loadingCurrent = true);
    try {
      final now = DateTime.now();
      final posts = await _challengeService.getTopPostsForMonth(now);
      final validation = await _challengeService.getValidationForMonth(now);
      setState(() {
        _currentMonthPosts = posts;
        _currentMonthValidation = validation;
      });
    } catch (e) {
      print('Erreur chargement mois courant: $e');
    } finally {
      setState(() => _loadingCurrent = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final validations = await _challengeService.getHistoryValidations();
      final monthsWithout = await _challengeService.getMonthsWithoutValidation();
      setState(() {
        _historyValidations = validations;
        _monthsWithoutValidation = monthsWithout;
      });
    } catch (e) {
      print('Erreur chargement historique: $e');
    } finally {
      setState(() => _loadingHistory = false);
    }
  }

  // Valider un gagnant pour un mois donné (uniquement si mois terminé)
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

  // Annuler un gagnant pour un mois donné (admin)
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

  // Encaissement par l'utilisateur gagnant
  Future<void> _payoutWinner(Post winnerPost, DateTime month) async {
    try {
      await _challengeService.payoutWinner(
        winnerPost: winnerPost,
        currentUser: _authProvider!.loginUserData,
        authProvider: _authProvider!,
        month: month,
      );
      // Récupérer le montant pour l'affichage
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

    if (_currentMonthPosts.isEmpty) {
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

    final isWinnerValidated = _currentMonthValidation != null && _currentMonthValidation!.status == 'validated';
    final winnerPostId = _currentMonthValidation?.winnerPostId;
    final prizeAmount = _currentMonthValidation?.prizeAmount ?? 5000;
    final isPayoutCompleted = _currentMonthValidation?.payoutCompleted ?? false;
    final bool isMonthFinished = _challengeService.isMonthOver(DateTime.now());

    return RefreshIndicator(
      onRefresh: _loadCurrentMonth,
      color: const Color(0xFFFFD600),
      child: ListView(
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
          ...List.generate(_currentMonthPosts.length, (index) {
            final post = _currentMonthPosts[index];
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
          }),
          // Section admin pour le mois courant
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
          // Mois déjà validés
          if (_historyValidations.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('🏅 Mois avec gagnant validé', style: TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold)),
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
                                '${_monthName(validation.month)} ${validation.year}',
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

          // Mois sans validation (admin uniquement, et uniquement si mois terminé)
          if (_isAdmin && _monthsWithoutValidation.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Text('⏳ Mois sans validation (en attente)', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
            ..._monthsWithoutValidation.map((month) {
              // Ne proposer que les mois terminés (normalement tous le sont par définition de getMonthsWithoutValidation)
              if (!_challengeService.isMonthOver(month)) return const SizedBox.shrink();
              return FutureBuilder<List<Post>>(
                future: _challengeService.getTopPostsForMonth(month),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
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
                  return Card(
                    color: const Color(0xFF1A1A1A),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text('${_monthName(month.month)} ${month.year}', style: const TextStyle(color: Color(0xFFFFD600))),
                          subtitle: const Text('Cliquez pour choisir le gagnant', style: TextStyle(color: Colors.grey)),
                          trailing: ElevatedButton.icon(
                            onPressed: () async {
                              final winner = await _showWinnerPicker(posts, month);
                              if (winner != null) {
                                await _validateWinnerForMonth(winner, month);
                              }
                            },
                            icon: const Icon(Icons.emoji_events, size: 18),
                            label: const Text('Valider'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), foregroundColor: Colors.black),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Wrap(
                            spacing: 8,
                            children: posts.take(3).map((post) {
                              final score = (post.totalInteractions ?? 0) + (post.loves ?? 0) + (post.favoritesCount ?? 0) + (post.uniqueViewsCount ?? 0);
                              return Chip(
                                label: Text('@${post.user?.pseudo ?? "?"} - $score pts'),
                                backgroundColor: Colors.grey[800],
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 10),
                              );
                            }).toList(),
                          ),
                        ),
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

  // Dialogue pour choisir le gagnant parmi les posts d'un mois
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
              final score = (post.totalInteractions ?? 0) + (post.loves ?? 0) + (post.favoritesCount ?? 0) + (post.uniqueViewsCount ?? 0);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFFD600),
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.black)),
                ),
                title: Text('@${post.user?.pseudo ?? post.canal?.titre}', style: const TextStyle(color: Colors.white)),
                subtitle: Text('Score: $score pts', style: const TextStyle(color: Colors.white70)),
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

  Future<Post?> _getPostById(String postId) async {
    final doc = await FirebaseFirestore.instance.collection('Posts').doc(postId).get();
    if (doc.exists) return Post.fromJson(doc.data()!);
    return null;
  }

  String _monthName(int month) {
    const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return months[month - 1];
  }
}

// // lib/pages/challenge/challenge_page.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../../models/model_data.dart';
// import '../../providers/authProvider.dart';
// import '../../services/challengeMonh/challenge_month_service.dart';
// import '../pub/native_ad_widget.dart';
// import 'challenge_month_post_card.dart';
//
// class ChallengeMonthPage extends StatefulWidget {
//   const ChallengeMonthPage({Key? key}) : super(key: key);
//
//   @override
//   State<ChallengeMonthPage> createState() => _ChallengeMonthPageState();
// }
//
// class _ChallengeMonthPageState extends State<ChallengeMonthPage> with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   final ChallengeMonthService _challengeService = ChallengeMonthService();
//   List<Post> _currentMonthPosts = [];
//   bool _loadingCurrent = true;
//   List<ChallengeValidation> _historyValidations = [];
//   bool _loadingHistory = true;
//   UserAuthProvider? _authProvider;
//   String? _currentUserId;
//   bool _isAdmin = false;
//   ChallengeValidation? _currentMonthValidation;
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _loadData();
//   }
//
//   Future<void> _loadData() async {
//     final auth = Provider.of<UserAuthProvider>(context, listen: false);
//     _authProvider = auth;
//     _currentUserId = auth.loginUserData.id;
//     _isAdmin = auth.loginUserData.role == UserRole.ADM.name;
//
//     await Future.wait([
//       _loadCurrentMonth(),
//       _loadHistory(),
//     ]);
//   }
//
//   Future<void> _loadCurrentMonth() async {
//     setState(() => _loadingCurrent = true);
//     try {
//       final now = DateTime.now();
//       final posts = await _challengeService.getTopPostsForMonth(now);
//       final validation = await _challengeService.getValidationForMonth(now);
//       setState(() {
//         _currentMonthPosts = posts;
//         _currentMonthValidation = validation;
//       });
//     } catch (e) {
//       print('Erreur chargement mois courant: $e');
//     } finally {
//       setState(() => _loadingCurrent = false);
//     }
//   }
//
//   Future<void> _loadHistory() async {
//     setState(() => _loadingHistory = true);
//     try {
//       final validations = await _challengeService.getHistoryValidations();
//       setState(() => _historyValidations = validations);
//     } catch (e) {
//       print('Erreur chargement historique: $e');
//     } finally {
//       setState(() => _loadingHistory = false);
//     }
//   }
//
//   Future<void> _validateWinner(Post winnerPost) async {
//     if (!_isAdmin) return;
//
//     final prizeController = TextEditingController(text: '5000');
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: const Color(0xFF1A1A1A),
//         title: const Text('Valider le gagnant', style: TextStyle(color: Color(0xFFFFD600))),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Post de @${winnerPost.user?.pseudo ?? winnerPost.canal?.titre}', style: const TextStyle(color: Colors.white)),
//             const SizedBox(height: 12),
//             TextField(
//               controller: prizeController,
//               keyboardType: TextInputType.number,
//               style: const TextStyle(color: Colors.white),
//               decoration: const InputDecoration(
//                 labelText: 'Montant du prix (FCFA)',
//                 labelStyle: TextStyle(color: Colors.grey),
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), foregroundColor: Colors.black),
//             child: const Text('Valider'),
//           ),
//         ],
//       ),
//     );
//
//     if (confirm == true) {
//       final prize = double.tryParse(prizeController.text) ?? 5000;
//       try {
//         await _challengeService.validateWinner(
//           month: DateTime.now(),
//           winnerPostId: winnerPost.id!,
//           winnerUserId: winnerPost.user_id!,
//           prizeAmount: prize,
//           adminId: _currentUserId!,
//         );
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Gagnant validé !'), backgroundColor: Colors.green));
//         await _loadCurrentMonth();
//         _loadHistory();
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
//       }
//     }
//   }
//
//   Future<void> _cancelWinner(DateTime month) async {
//     if (!_isAdmin) return;
//
//     final reasonController = TextEditingController();
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: const Color(0xFF1A1A1A),
//         title: const Text('Annuler le gagnant', style: TextStyle(color: Colors.red)),
//         content: TextField(
//           controller: reasonController,
//           maxLines: 3,
//           style: const TextStyle(color: Colors.white),
//           decoration: const InputDecoration(
//             labelText: 'Motif d\'annulation',
//             labelStyle: TextStyle(color: Colors.grey),
//             border: OutlineInputBorder(),
//           ),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non', style: TextStyle(color: Colors.grey))),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text('Oui, annuler'),
//           ),
//         ],
//       ),
//     );
//
//     if (confirm == true && reasonController.text.isNotEmpty) {
//       try {
//         await _challengeService.cancelWinner(month, reasonController.text, _currentUserId!);
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Gagnant annulé'), backgroundColor: Colors.orange));
//         await _loadCurrentMonth();
//         _loadHistory();
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
//       }
//     }
//   }
//
//   Future<void> _payoutWinner(Post winnerPost) async {
//     try {
//       await _challengeService.payoutWinner(
//         winnerPost: winnerPost,
//         currentUser: _authProvider!.loginUserData,
//         authProvider: _authProvider!,
//         month: DateTime.now(),
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('💰 ${_currentMonthValidation!.prizeAmount.toInt()} FCFA ajoutés à votre solde !'),
//           backgroundColor: Colors.green,
//         ),
//       );
//       await _loadCurrentMonth();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur encaissement: $e'), backgroundColor: Colors.red));
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: const Text('Challenge du mois', style: TextStyle(color: Color(0xFFFFD600))),
//         backgroundColor: Colors.black,
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: const Color(0xFFFFD600),
//           labelColor: const Color(0xFFFFD600),
//           unselectedLabelColor: Colors.grey,
//           tabs: const [
//             Tab(text: 'Ce mois', icon: Icon(Icons.emoji_events)),
//             Tab(text: 'Historique', icon: Icon(Icons.history)),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           _buildCurrentMonthTab(),
//           _buildHistoryTab(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCurrentMonthTab() {
//     if (_loadingCurrent) {
//       return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD600)));
//     }
//
//     if (_currentMonthPosts.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.emoji_events, size: 64, color: Colors.grey),
//             const SizedBox(height: 16),
//             const Text('Aucun post éligible ce mois', style: TextStyle(color: Colors.white)),
//             const SizedBox(height: 8),
//             FutureBuilder<DateTime>(
//               future: _challengeService.getChallengeStartDate(),
//               builder: (context, snapshot) {
//                 final date = snapshot.data ?? DateTime(2026, 4, 12);
//                 return Text(
//                   'Les posts doivent être créés après ${DateFormat('dd/MM/yyyy').format(date)}',
//                   style: const TextStyle(color: Colors.grey),
//                 );
//               },
//             ),
//           ],
//         ),
//       );
//     }
//
//     final isWinnerValidated = _currentMonthValidation != null && _currentMonthValidation!.status == 'validated';
//     final winnerPostId = _currentMonthValidation?.winnerPostId;
//     final prizeAmount = _currentMonthValidation?.prizeAmount ?? 5000;
//     final isPayoutCompleted = _currentMonthValidation?.payoutCompleted ?? false;
//
//     return RefreshIndicator(
//       onRefresh: _loadCurrentMonth,
//       color: const Color(0xFFFFD600),
//       child: ListView(
//         padding: const EdgeInsets.symmetric(vertical: 12),
//         children: [
//           // Carte d'information
//           Container(
//             margin: const EdgeInsets.all(12),
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(colors: [Color(0xFFFFD600), Color(0xFFF9A825)]),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Column(
//               children: [
//                 const Text('🏆 PRINCIPE DU CHALLENGE 🏆', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
//                 const SizedBox(height: 8),
//                 const Text(
//                   'Chaque mois, le post avec le plus d\'interactions (vues, likes, commentaires, partages) remporte un prix. '
//                       'Seuls les posts originaux (non publicitaires) sont éligibles.',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: Colors.black87),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   '💰 Prix du mois : ${prizeAmount.toInt()} FCFA',
//                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
//                 ),
//               ],
//             ),
//           ),
//           // 🔥 BANNIÈRE PUBLICITAIRE (discrète mais visible)
//           const MrecAdWidget(
//             useBanner: true,
//             showLessAdsButton: false, // Désactiver le bouton "moins de pub" pour rester discret
//           ),
//           const SizedBox(height: 8),
//           // Top 10
//           ...List.generate(_currentMonthPosts.length, (index) {
//             final post = _currentMonthPosts[index];
//             final isWinner = isWinnerValidated && winnerPostId == post.id;
//             final showPayoutButton = isWinner &&
//                 post.user_id == _currentUserId &&
//                 !isPayoutCompleted;
//             return ChallengePostCard(
//               post: post,
//               rank: index + 1,
//               isWinner: isWinner,
//               onPayout: showPayoutButton ? () => _payoutWinner(post) : null,
//             );
//           }),
//           // Boutons admin
//           if (_isAdmin && _currentMonthPosts.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.all(12),
//               child: Row(
//                 children: [
//                   if (!isWinnerValidated)
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () => _validateWinner(_currentMonthPosts.first),
//                         icon: const Icon(Icons.check_circle),
//                         label: const Text('VALIDER LE GAGNANT'),
//                         style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), foregroundColor: Colors.black),
//                       ),
//                     ),
//                   if (isWinnerValidated)
//                     Expanded(
//                       child: OutlinedButton.icon(
//                         onPressed: () => _cancelWinner(DateTime.now()),
//                         icon: const Icon(Icons.cancel),
//                         label: const Text('ANNULER LE GAGNANT'),
//                         style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildHistoryTab() {
//     if (_loadingHistory) {
//       return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD600)));
//     }
//
//     if (_historyValidations.isEmpty) {
//       return const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.history, size: 64, color: Colors.grey),
//             SizedBox(height: 16),
//             Text('Aucun challenge terminé', style: TextStyle(color: Colors.white)),
//             MrecAdWidget()
//           ],
//         ),
//       );
//     }
//
//     return RefreshIndicator(
//       onRefresh: _loadHistory,
//       color: const Color(0xFFFFD600),
//       child: ListView(
//         padding: const EdgeInsets.all(12),
//         children: [
//           // Liste des validations historiques
//           ..._historyValidations.map((validation) {
//             return FutureBuilder<Post?>(
//               future: _getPostById(validation.winnerPostId),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) return const SizedBox.shrink();
//                 final post = snapshot.data!;
//                 final isOwner = post.user_id == _currentUserId;
//                 final canPayout = isOwner && !validation.payoutCompleted;
//                 return Container(
//                   margin: const EdgeInsets.only(bottom: 16),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFF1A1A1A),
//                     borderRadius: BorderRadius.circular(16),
//                     border: Border.all(color: Colors.grey[800]!),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                         decoration: const BoxDecoration(
//                           color: Color(0xFFFFD600),
//                           borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
//                         ),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               '${_monthName(validation.month)} ${validation.year}',
//                               style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//                             ),
//                             Text(
//                               '💰 ${validation.prizeAmount.toInt()} FCFA',
//                               style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//                             ),
//                           ],
//                         ),
//                       ),
//                       ChallengePostCard(
//                         post: post,
//                         rank: 1,
//                         isWinner: true,
//                         onPayout: canPayout ? () => _payoutWinnerFromHistory(post, validation) : null,
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.all(12),
//                         child: Row(
//                           children: [
//                             Icon(
//                               validation.payoutCompleted ? Icons.check_circle : Icons.pending,
//                               color: validation.payoutCompleted ? Colors.green : Colors.orange,
//                               size: 16,
//                             ),
//                             const SizedBox(width: 6),
//                             Text(
//                               validation.payoutCompleted
//                                   ? 'Encaissé le ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(validation.payoutDate!))}'
//                                   : 'En attente d\'encaissement',
//                               style: const TextStyle(color: Colors.white70, fontSize: 12),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             );
//           }).toList(),
//           // 🔥 BANNIÈRE PUBLICITAIRE EN BAS DE L'HISTORIQUE
//           const MrecAdWidget(
//             useBanner: true,
//             showLessAdsButton: false,
//           ),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _payoutWinnerFromHistory(Post winnerPost, ChallengeValidation validation) async {
//     try {
//       await _challengeService.payoutWinner(
//         winnerPost: winnerPost,
//         currentUser: _authProvider!.loginUserData,
//         authProvider: _authProvider!,
//         month: DateTime(validation.year, validation.month),
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('💰 ${validation.prizeAmount.toInt()} FCFA ajoutés à votre solde !'),
//           backgroundColor: Colors.green,
//         ),
//       );
//       _loadHistory();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur encaissement: $e'), backgroundColor: Colors.red));
//     }
//   }
//
//   Future<Post?> _getPostById(String postId) async {
//     final doc = await FirebaseFirestore.instance.collection('Posts').doc(postId).get();
//     if (doc.exists) return Post.fromJson(doc.data()!);
//     return null;
//   }
//
//   String _monthName(int month) {
//     const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
//     return months[month - 1];
//   }
// }