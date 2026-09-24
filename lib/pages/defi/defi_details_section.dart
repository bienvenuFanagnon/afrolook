import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postWidgetPage.dart';
import 'package:afrotok/pages/userPosts/youTube_video_card.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';
import 'package:afrotok/pages/pub/afrolook_inline_ad.dart';
import 'package:afrotok/pages/defi/defi_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
                    onTap: () => openDefiParticipation(context, defiPost),
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
                if (isOver) ...[
                  const SizedBox(height: 12),
                  _buildResults(c, cfg),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Résultat après la clôture : gagnants et gains, ou état du versement en cours.
  Widget _buildResults(AppColors c, DefiConfig cfg) {
    final winners = defiPost.defiWinners;

    Widget notice(IconData icon, String text) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _yellow, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 12))),
          ],
        );

    if (!cfg.isTermine) {
      return notice(
        cfg.isPayoutWaitingFunds ? Icons.hourglass_top : Icons.schedule,
        cfg.isPayoutWaitingFunds
            ? 'Versement des gains en attente : le créateur doit recharger son solde pour financer la cagnotte.'
            : 'DÉFI terminé : calcul du classement et versement des gains en cours (quelques minutes).',
      );
    }
    if (winners.isEmpty) {
      return notice(Icons.info_outline, 'DÉFI terminé sans gagnant : la cagnotte a été rendue au créateur.');
    }

    const medals = ['🥇', '🥈', '🥉'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🏆 Gagnants', style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...winners.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(w.rank >= 1 && w.rank <= 3 ? medals[w.rank - 1] : '${w.rank}.', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _yellowBg,
                    backgroundImage: w.imageUrl.isNotEmpty ? NetworkImage(w.imageUrl) : null,
                    child: w.imageUrl.isEmpty ? const Icon(Icons.person, size: 16, color: _yellow) : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      w.pseudo.isNotEmpty ? '@${w.pseudo}' : 'Participant',
                      style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${w.votes} vote${w.votes > 1 ? 's' : ''}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                  const SizedBox(width: 10),
                  Text('+${w.coins} 🪙', style: const TextStyle(color: _yellow, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
      ],
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

    if (widget.isDefiOver) {
      DefiDialogs.defiEnded(context);
      return;
    }
    final alreadyVotedLocally = _votedInSession.contains(postId)
        || (response.defiVoterIds?.contains(widget.currentUserId) ?? false);
    if (alreadyVotedLocally) {
      DefiDialogs.alreadyVoted(context);
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
      if (mounted) showDefiVoteAnimation(context, anchor: btnKey);
    } catch (e) {
      if (!mounted) return;
      final alreadyVoted = e is FirebaseFunctionsException && e.code == 'already-exists';
      setState(() {
        _localVoteMap.remove(postId);
        if (!alreadyVoted) _votedInSession.remove(postId);
      });
      DefiDialogs.handleError(context, e, isVote: true);
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
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

    final cfg = _defiPost?.defiConfig;
    if (cfg != null && (cfg.isTermine || DateTime.fromMillisecondsSinceEpoch(cfg.endDate).isBefore(DateTime.now()))) {
      DefiDialogs.defiEnded(context);
      return;
    }
    if (_hasVoted) {
      DefiDialogs.alreadyVoted(context);
      return;
    }

    setState(() { _isVoting = true; _hasVoted = true; _localVotes++; });

    try {
      await FirebaseFunctions.instance.httpsCallable('handleDefiAction').call({
        'action': 'vote',
        'postId': postId,
      });
      if (mounted) showDefiVoteAnimation(context, anchor: _voteBtnKey);
    } catch (e) {
      if (!mounted) return;
      final alreadyVoted = e is FirebaseFunctionsException && e.code == 'already-exists';
      setState(() {
        _localVotes = (_localVotes - 1).clamp(0, 999999);
        _hasVoted = alreadyVoted;
      });
      DefiDialogs.handleError(context, e, isVote: true);
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
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

