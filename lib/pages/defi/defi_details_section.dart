import 'dart:math' as math;
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:afrotok/pages/userPosts/userPostForm.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postWidgetPage.dart';
import 'package:afrotok/pages/userPosts/youTube_video_card.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';
import 'package:afrotok/pages/pub/afrolook_inline_ad.dart';
import 'package:afrotok/pages/coins/coin_recharge_screen.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

const Color _yellow = Color(0xFFFF9500);
const Color _yellowBg = Color(0x22FF9500);

// ── Section principale — info card d'un post DÉFI ────────────────────────────
class DefiDetailsSection extends StatelessWidget {
  final Post defiPost;
  final String currentUserId;

  const DefiDetailsSection({
    super.key,
    required this.defiPost,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cfg = defiPost.defiConfig;
    if (cfg == null) return const SizedBox.shrink();

    final endDate = DateTime.fromMillisecondsSinceEpoch(cfg.endDate);
    final isOver = endDate.isBefore(DateTime.now()) || cfg.isTermine;
    final daysLeft = endDate.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _yellow.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _yellowBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: _yellow, size: 22),
                const SizedBox(width: 8),
                const Text('DÉFI', style: TextStyle(color: _yellow, fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOver ? Colors.grey.withOpacity(0.2) : const Color(0x33FFE14D),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isOver ? Colors.grey.withOpacity(0.4) : _yellow.withOpacity(0.5)),
                  ),
                  child: Text(
                    isOver ? 'Terminé' : (daysLeft <= 0 ? 'Dernier jour' : '$daysLeft j restants'),
                    style: TextStyle(
                      color: isOver ? Colors.grey : _yellow,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isOver) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final auth = Provider.of<UserAuthProvider>(context, listen: false);
                      if (defiPost.defiParticipantIds?.contains(auth.loginUserData.id) ?? false) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vous participez déjà à ce DÉFI.'), duration: Duration(seconds: 2)),
                        );
                        return;
                      }
                      final balance = auth.loginUserData.giftCoinsBalance ?? 0;
                      final fee = cfg.participationFee;
                      if (fee > 0 && balance < fee) {
                        _showInsufficientBalanceDialog(context);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UserPostForm(defiPostId: defiPost.id!)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _yellow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sports_score, color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text('Participer',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Statistiques ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statChip(c, '🪙', '${cfg.cagnottePieces}', 'Cagnotte'),
                    const SizedBox(width: 10),
                    _statChip(c, '👥', cfg.winnersCount > 1 ? '${cfg.winnersCount} prix' : '1 prix', 'Gagnants'),
                    const SizedBox(width: 10),
                    _statChip(c, '🗓', DateFormat('dd/MM/yy').format(endDate), 'Fin'),
                  ],
                ),
                if (cfg.isPayantParticipation || cfg.isPayantVote) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (cfg.isPayantParticipation)
                        _infoBadge('Participation: ${cfg.participationFee} 🪙'),
                      if (cfg.isPayantParticipation && cfg.isPayantVote)
                        const SizedBox(width: 8),
                      if (cfg.isPayantVote)
                        _infoBadge('Vote: ${cfg.voteFee} 🪙'),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Répartition gains
                Text('Répartition des gains', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(cfg.rewardSplit.length, (i) {
                    final pct = cfg.rewardSplit[i];
                    return Expanded(
                      flex: pct,
                      child: Container(
                        margin: EdgeInsets.only(right: i < cfg.rewardSplit.length - 1 ? 4 : 0),
                        height: 8,
                        decoration: BoxDecoration(
                          color: [_yellow, const Color(0xFFB8B8B8), const Color(0xFFCD7F32)][i < 3 ? i : 2],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  cfg.rewardSplit.asMap().entries.map((e) => '${e.key + 1}e: ${e.value}%').join(' • '),
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInsufficientBalanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.monetization_on, color: _yellow),
            SizedBox(width: 8),
            Text('Solde insuffisant', style: TextStyle(color: _yellow, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Vous n\'avez pas assez de pièces pour participer à ce DÉFI.\nRechargez votre solde pour continuer.',
          style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: AppColors.of(context).textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _yellow, foregroundColor: Colors.white, shape: StadiumBorder()),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
            },
            child: const Text('Recharger', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _statChip(AppColors c, String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _yellowBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _yellow.withOpacity(0.4)),
      ),
      child: Text(label, style: const TextStyle(color: _yellow, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Feed des participations — remplace les suggestions sur les pages de détails ─
class DefiResponsesFeed extends StatefulWidget {
  final String defiPostId;
  final String currentUserId;
  final bool isDefiOver;

  const DefiResponsesFeed({
    super.key,
    required this.defiPostId,
    required this.currentUserId,
    this.isDefiOver = false,
  });

  @override
  State<DefiResponsesFeed> createState() => _DefiResponsesFeedState();
}

class _DefiResponsesFeedState extends State<DefiResponsesFeed> {
  List<Post> _responses = [];
  bool _loading = true;
  final Map<String, int> _localVoteMap = {};
  final Set<String> _votedInSession = {};
  bool _isVoting = false;
  final Map<String, GlobalKey> _voteKeys = {};

  void _triggerVoteAnimation(GlobalKey btnKey) {
    final box = btnKey.currentContext?.findRenderObject() as RenderBox?;
    final pos = box != null
        ? box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2))
        : Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height * 0.6);
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _VoteSuccessOverlay(start: pos, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  @override
  void initState() {
    super.initState();
    _loadResponses();
  }

  Future<void> _loadResponses() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Posts')
          .where('defi_response_to_post_id', isEqualTo: widget.defiPostId)
          .limit(50)
          .get();

      final posts = snap.docs.map((d) => Post.fromJson(d.data())).toList();

      // Classement : votes DESC → postScore DESC → likes DESC
      posts.sort((a, b) {
        final vA = a.defiVotes ?? 0;
        final vB = b.defiVotes ?? 0;
        if (vA != vB) return vB.compareTo(vA);
        final sA = a.postScore ?? 0.0;
        final sB = b.postScore ?? 0.0;
        if (sA != sB) return sB.compareTo(sA);
        return (b.likes ?? 0).compareTo(a.likes ?? 0);
      });

      if (mounted) setState(() { _responses = posts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _voteForResponse(Post response, GlobalKey btnKey) async {
    if (_isVoting) return;
    final postId = response.id;
    if (postId == null) return;

    // already-voted : contrôle local avant appel réseau
    final alreadyVotedLocally = _votedInSession.contains(postId)
        || (response.defiVoterIds?.contains(widget.currentUserId) ?? false);
    if (alreadyVotedLocally) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous avez déjà voté pour ce post.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() {
      _isVoting = true;
      _votedInSession.add(postId);
      _localVoteMap[postId] = (response.defiVotes ?? 0) + 1;
    });

    try {
      await FirebaseFunctions.instance.httpsCallable('handleDefiAction').call({
        'action': 'vote',
        'postId': postId,
      });
      // ✅ Succès — animation vote
      if (mounted) _triggerVoteAnimation(btnKey);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _votedInSession.remove(postId);
          _localVoteMap.remove(postId);
        });
        if (e.code == 'resource-exhausted') {
          _showInsufficientBalanceDialog();
        } else if (e.code == 'already-exists') {
          // Firebase confirme le double-vote : garder l'état voté mais montrer message
          setState(() => _votedInSession.add(postId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous avez déjà voté pour ce post.'), duration: Duration(seconds: 2)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors du vote. Réessaie plus tard.'), duration: Duration(seconds: 3)),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _votedInSession.remove(postId);
          _localVoteMap.remove(postId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du vote. Réessaie plus tard.'), duration: Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _yellow, width: 2),
          ),
          title: const Text(
            'Solde insuffisant 🪙',
            style: TextStyle(color: _yellow, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Votre solde Afrcoins est insuffisant pour voter. Rechargez votre compte pour continuer.',
            style: TextStyle(color: c.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: c.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: _yellow),
              child: const Text('Recharger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: _yellow)),
      );
    }

    if (_responses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text(
          "Aucune participation pour l'instant. Sois le premier !",
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Titre section ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: _yellow, size: 18),
              const SizedBox(width: 6),
              Text(
                'Participants (${_responses.length})',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        // ── Liste des participations (pub après le 1er, puis /3) ───
        ...List.generate(_responses.length, (i) {
          final showAd = i == 0 || (i > 0 && i % 3 == 0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDefiResponseItem(c, i + 1, _responses[i]),
              if (showAd)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AfrolookInlineAd(key: ValueKey('ad_defi_$i')),
                ),
            ],
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDefiResponseItem(AppColors c, int rank, Post post) {
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank.';
    final postId = post.id ?? '';
    final displayVotes = _localVoteMap[postId] ?? post.defiVotes ?? 0;
    final alreadyVoted = _votedInSession.contains(postId)
        || (post.defiVoterIds?.contains(widget.currentUserId) ?? false);
    final canVote = !widget.isDefiOver && !alreadyVoted && !_isVoting && widget.currentUserId.isNotEmpty;
    final btnKey = _voteKeys.putIfAbsent(postId, () => GlobalKey());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Rang + Votes + Bouton Voter ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Text(medal, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Icon(Icons.how_to_vote, color: _yellow, size: 15),
              const SizedBox(width: 3),
              Text('$displayVotes', style: const TextStyle(color: _yellow, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => _voteForResponse(post, btnKey),
                child: AnimatedContainer(
                  key: btnKey,
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: alreadyVoted ? _yellowBg : canVote ? _yellow : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: alreadyVoted || canVote ? _yellow : c.border),
                  ),
                  child: Text(
                    alreadyVoted ? '✓ Voté' : 'Voter',
                    style: TextStyle(
                      color: alreadyVoted ? _yellow : canVote ? Colors.black : c.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Widget du post (identique au feed) ───────────────────────
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            if (post.type == PostType.POST.name && post.dataType == PostDataType.VIDEO.name) {
              return YouTubeVideoCard(
                key: ValueKey('defi_yt_${post.id}'),
                post: post,
                index: rank,
                suppressInlineAd: true,
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => VideoYoutubePageDetails(initialPost: post),
                  ),
                ),
              );
            }
            return HomePostUsersWidget(
              key: ValueKey('defi_post_${post.id}'),
              post: post,
              index: rank,
              height: w * 0.85,
              width: w,
              isDegrade: false,
              suppressInlineAd: true,
            );
          },
        ),
      ],
    );
  }
}

// ── Bannière réponse — affichée sur les pages de détails d'une réponse ────────
class DefiResponseBanner extends StatefulWidget {
  final Post responsePost;
  final void Function(Post defiPost)? onTap;
  final String currentUserId;

  const DefiResponseBanner({
    super.key,
    required this.responsePost,
    this.onTap,
    this.currentUserId = '',
  });

  @override
  State<DefiResponseBanner> createState() => _DefiResponseBannerState();
}

class _DefiResponseBannerState extends State<DefiResponseBanner> {
  Post? _defiPost;
  bool _loading = true;
  bool _isVoting = false;
  late int _localVotes;
  late bool _hasVoted;
  final GlobalKey _voteBtnKey = GlobalKey();

  void _triggerVoteAnimation() {
    final box = _voteBtnKey.currentContext?.findRenderObject() as RenderBox?;
    final pos = box != null
        ? box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2))
        : Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height * 0.6);
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _VoteSuccessOverlay(start: pos, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  @override
  void initState() {
    super.initState();
    _localVotes = widget.responsePost.defiVotes ?? 0;
    _hasVoted = widget.responsePost.defiVoterIds?.contains(widget.currentUserId) ?? false;
    _loadDefiPost();
  }

  Future<void> _loadDefiPost() async {
    final parentId = widget.responsePost.defiResponseToPostId;
    if (parentId == null) { setState(() => _loading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('Posts').doc(parentId).get();
      if (doc.exists && mounted) {
        setState(() { _defiPost = Post.fromJson(doc.data()!); _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleVote() async {
    if (_isVoting) return;
    final postId = widget.responsePost.id;
    if (postId == null || widget.currentUserId.isEmpty) return;

    // already-voted : contrôle local avant appel réseau
    if (_hasVoted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous avez déjà voté pour ce post.'), duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() { _isVoting = true; _hasVoted = true; _localVotes++; });

    try {
      await FirebaseFunctions.instance.httpsCallable('handleDefiAction').call({
        'action': 'vote',
        'postId': postId,
      });
      // ✅ Succès — animation vote
      if (mounted) _triggerVoteAnimation();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        if (e.code == 'resource-exhausted') {
          setState(() { _hasVoted = false; _localVotes = (_localVotes - 1).clamp(0, 999999); });
          _showInsufficientDialog();
        } else if (e.code == 'already-exists') {
          // Firebase confirme : garder _hasVoted = true, juste informer
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous avez déjà voté pour ce post.'), duration: Duration(seconds: 2)),
          );
        } else {
          setState(() { _hasVoted = false; _localVotes = (_localVotes - 1).clamp(0, 999999); });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors du vote. Réessaie plus tard.'), duration: Duration(seconds: 3)),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() { _hasVoted = false; _localVotes = (_localVotes - 1).clamp(0, 999999); });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du vote. Réessaie plus tard.'), duration: Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  void _showInsufficientDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _yellow, width: 2)),
          title: const Text('Solde insuffisant 🪙', style: TextStyle(color: _yellow, fontWeight: FontWeight.bold)),
          content: Text('Votre solde est insuffisant pour voter. Rechargez pour continuer.', style: TextStyle(color: c.textPrimary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CoinRechargeScreen())); },
              style: ElevatedButton.styleFrom(backgroundColor: _yellow),
              child: const Text('Recharger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.responsePost.defiResponseToPostId == null) return const SizedBox.shrink();
    final c = AppColors.of(context);

    final cfg = _defiPost?.defiConfig;
    final isOver = cfg != null && (cfg.isTermine || DateTime.fromMillisecondsSinceEpoch(cfg.endDate).isBefore(DateTime.now()));
    final canVote = widget.currentUserId.isNotEmpty && !_hasVoted && !isOver;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: _yellowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _yellow.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ligne 1 : icône + titre + bouton "Voir" ─────────────────
          Row(
            children: [
              const Icon(Icons.emoji_events, color: _yellow, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: _loading
                    ? Text('Chargement du défi...', style: TextStyle(color: c.textSecondary, fontSize: 12))
                    : const Text('Réponse à un Défi', style: TextStyle(color: _yellow, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              if (_defiPost != null)
                GestureDetector(
                  onTap: () => widget.onTap?.call(_defiPost!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _yellow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Voir', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // ── Description DÉFI ─────────────────────────────────────────
          if (!_loading && _defiPost?.description != null) ...[
            const SizedBox(height: 4),
            Text(
              _defiPost!.description!,
              style: TextStyle(color: c.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          // ── Ligne 2 : votes + bouton Voter ───────────────────────────
          Row(
            children: [
              const Icon(Icons.how_to_vote, color: _yellow, size: 15),
              const SizedBox(width: 4),
              Text('$_localVotes vote${_localVotes != 1 ? 's' : ''}',
                  style: const TextStyle(color: _yellow, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: _handleVote,
                child: AnimatedContainer(
                  key: _voteBtnKey,
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _hasVoted ? _yellowBg : (canVote ? _yellow : Colors.transparent),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (_hasVoted || canVote) ? _yellow : c.border),
                  ),
                  child: _isVoting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _yellow))
                      : Text(
                          _hasVoted ? '✓ Voté' : 'Voter',
                          style: TextStyle(
                            color: _hasVoted ? _yellow : (canVote ? Colors.black : c.textSecondary),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Animation vote réussi (trophées volants + badge "+1 Vote") ───────────────
class _VoteSuccessOverlay extends StatefulWidget {
  final Offset start;
  final VoidCallback onDone;
  const _VoteSuccessOverlay({required this.start, required this.onDone});

  @override
  State<_VoteSuccessOverlay> createState() => _VoteSuccessOverlayState();
}

class _VoteSuccessOverlayState extends State<_VoteSuccessOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _p;
  final _rnd = math.Random();
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(7, (_) => _Particle(
      dx: (_rnd.nextDouble() - 0.5) * 160,
      dy: -(90 + _rnd.nextDouble() * 140),
      rotation: (_rnd.nextDouble() - 0.5) * 0.9,
      size: 18 + _rnd.nextDouble() * 14,
      emoji: const ['🏆', '⭐', '🗳️', '✨'][_rnd.nextInt(4)],
    ));
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _p = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _opacity(double p) => p < 0.7 ? 1.0 : (1.0 - (p - 0.7) / 0.3).clamp(0.0, 1.0);

  double _scale(double p) {
    if (p < 0.25) return 0.5 + (p / 0.25) * 0.8;
    if (p < 0.7) return 1.3;
    return (1.3 - ((p - 0.7) / 0.3) * 0.6).clamp(0.3, 1.5);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _p,
        builder: (_, __) {
          final p = _p.value;
          final op = _opacity(p);
          return Stack(
            children: [
              ..._particles.map((pt) => Positioned(
                    left: widget.start.dx + pt.dx * p - pt.size / 2,
                    top: widget.start.dy + pt.dy * p - pt.size / 2,
                    child: Opacity(
                      opacity: op,
                      child: Transform.rotate(
                        angle: pt.rotation * (p < 0.5 ? p * 2 : (1 - p) * 2),
                        child: Transform.scale(
                          scale: _scale(p),
                          child: Text(pt.emoji, style: TextStyle(fontSize: pt.size, decoration: TextDecoration.none)),
                        ),
                      ),
                    ),
                  )),
              Positioned(
                left: widget.start.dx - 60,
                top: widget.start.dy - 30 - 110 * p,
                width: 120,
                child: Opacity(
                  opacity: op,
                  child: Transform.scale(
                    scale: _scale(p),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _yellow,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: _yellow.withOpacity(0.5), blurRadius: 14)],
                        ),
                        child: const Text(
                          '+1 Vote',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  final double dx, dy, rotation, size;
  final String emoji;
  const _Particle({required this.dx, required this.dy, required this.rotation, required this.size, required this.emoji});
}
