import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/canaux/detailsCanal.dart' show CanalDetails;
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Modèle interne ─────────────────────────────────────────────────────────

class _TopEntry {
  final bool isCanal;
  final UserData? userData;
  final Canal? canal;
  final double score;
  final int postCount;
  final int uniqueLovers;
  final int uniqueCommenters;
  final int totalViews;

  _TopEntry({
    required this.isCanal,
    this.userData,
    this.canal,
    required this.score,
    required this.postCount,
    required this.uniqueLovers,
    required this.uniqueCommenters,
    required this.totalViews,
  });

  String get id => isCanal ? (canal?.id ?? '') : (userData?.id ?? '');
  String get displayName =>
      isCanal ? (canal?.titre ?? '') : (userData?.pseudo ?? '');
  String get imageUrl =>
      isCanal ? (canal?.urlImage ?? '') : (userData?.imageUrl ?? '');
  String get description =>
      isCanal ? (canal?.description ?? '') : (userData?.apropos ?? '');
  int get followerCount =>
      isCanal
          ? (canal?.usersSuiviId?.length ?? canal?.suivi ?? 0)
          : (userData?.userAbonnesIds?.length ?? userData?.abonnes ?? 0);
}

// ─── Widget principal ────────────────────────────────────────────────────────

/// Affiché le lundi et mardi, après le 2e post du feed.
/// Chargement en parallèle via [preload]. Suivi du temps de vue :
/// disparaît définitivement pour la journée une fois 8 secondes cumulées.
class WeeklyTopCreatorsWidget extends StatefulWidget {
  const WeeklyTopCreatorsWidget({Key? key}) : super(key: key);

  // ── Cache statique (chargement en avance, partagé entre instances) ──────

  static Future<List<_TopEntry>>? _sharedFuture;
  static String _sharedFutureDate = '';

  /// Appeler depuis le feed parent dès son initState pour démarrer le
  /// chargement en parallèle avec les autres données.
  static void preload() {
    final weekday = DateTime.now().weekday;
    if (weekday != DateTime.monday && weekday != DateTime.tuesday) return;
    final today = _staticTodayKey();
    if (_sharedFutureDate == today && _sharedFuture != null) return;
    _sharedFutureDate = today;
    _sharedFuture = _fetchTopEntries();
  }

  static String _staticTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ── Logique Firestore (statique, sans setState) ──────────────────────────

  static Map<String, int> _lastWeekRangeMicros() {
    final now = DateTime.now();
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final startOfThisWeek =
        DateTime(thisMonday.year, thisMonday.month, thisMonday.day);
    final startOfLastWeek =
        startOfThisWeek.subtract(const Duration(days: 7));
    return {
      'start': startOfLastWeek.microsecondsSinceEpoch,
      'end': startOfThisWeek.microsecondsSinceEpoch,
    };
  }

  static Future<List<_TopEntry>> _fetchTopEntries() async {
    try {
      final range = _lastWeekRangeMicros();

      final snap = await FirebaseFirestore.instance
          .collection('Posts')
          .where('created_at', isGreaterThanOrEqualTo: range['start'])
          .where('created_at', isLessThan: range['end'])
          .limit(300)
          .get();

      if (snap.docs.isEmpty) return [];

      // Grouper par entité (canal > user) + scorer
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        final canalId = (data['canal_id'] as String? ?? '').trim();
        final userId = (data['user_id'] as String? ?? '').trim();
        final entityId = canalId.isNotEmpty ? canalId : userId;
        if (entityId.isEmpty) continue;
        final isCanal = canalId.isNotEmpty;

        final loves = (data['loves'] as int? ?? 0);
        final comments = (data['comments'] as int? ?? 0);
        final vues = (data['vues'] as int? ?? 0);
        final giftCount = (data['giftCount'] as int? ?? 0);
        final partage = (data['partage'] as int? ?? 0);
        final totalInteractions = (data['totalInteractions'] as int? ?? 0);
        final uniqueLovers =
            (data['users_love_id'] as List<dynamic>? ?? []).length;
        final uniqueCommenters =
            (data['users_comments_id'] as List<dynamic>? ?? []).length;
        final uniqueViewers =
            (data['users_vue_id'] as List<dynamic>? ?? []).length;

        final double postScore = 5.0 +
            uniqueLovers * 3.0 +
            loves * 0.3 +
            uniqueCommenters * 4.0 +
            comments * 0.3 +
            uniqueViewers * 1.0 +
            vues * 0.05 +
            giftCount * 2.0 +
            partage * 1.5 +
            totalInteractions * 0.2;

        grouped.putIfAbsent(entityId, () => {
          'isCanal': isCanal,
          'score': 0.0,
          'postCount': 0,
          'uniqueLovers': 0,
          'uniqueCommenters': 0,
          'totalViews': 0,
        });
        grouped[entityId]!['score'] =
            (grouped[entityId]!['score'] as double) + postScore;
        grouped[entityId]!['postCount'] =
            (grouped[entityId]!['postCount'] as int) + 1;
        grouped[entityId]!['uniqueLovers'] =
            (grouped[entityId]!['uniqueLovers'] as int) + uniqueLovers;
        grouped[entityId]!['uniqueCommenters'] =
            (grouped[entityId]!['uniqueCommenters'] as int) + uniqueCommenters;
        grouped[entityId]!['totalViews'] =
            (grouped[entityId]!['totalViews'] as int) + uniqueViewers;
      }

      // Top 5
      final sorted = grouped.entries.toList()
        ..sort((a, b) => (b.value['score'] as double)
            .compareTo(a.value['score'] as double));
      final top5 = sorted.take(5).toList();

      // Charger détails Users / Canaux en parallèle
      final List<_TopEntry> entries = [];
      await Future.wait(top5.map((entry) async {
        final entityId = entry.key;
        final isCanal = entry.value['isCanal'] as bool;
        try {
          if (isCanal) {
            final doc = await FirebaseFirestore.instance
                .collection('Canaux')
                .doc(entityId)
                .get();
            if (!doc.exists) return;
            entries.add(_TopEntry(
              isCanal: true,
              canal: Canal.fromJson({...doc.data()!, 'id': doc.id}),
              score: entry.value['score'] as double,
              postCount: entry.value['postCount'] as int,
              uniqueLovers: entry.value['uniqueLovers'] as int,
              uniqueCommenters: entry.value['uniqueCommenters'] as int,
              totalViews: entry.value['totalViews'] as int,
            ));
          } else {
            final doc = await FirebaseFirestore.instance
                .collection('Users')
                .doc(entityId)
                .get();
            if (!doc.exists) return;
            entries.add(_TopEntry(
              isCanal: false,
              userData: UserData.fromJson(doc.data()!),
              score: entry.value['score'] as double,
              postCount: entry.value['postCount'] as int,
              uniqueLovers: entry.value['uniqueLovers'] as int,
              uniqueCommenters: entry.value['uniqueCommenters'] as int,
              totalViews: entry.value['totalViews'] as int,
            ));
          }
        } catch (_) {}
      }));

      entries.sort((a, b) => b.score.compareTo(a.score));
      return entries;
    } catch (_) {
      return [];
    }
  }

  @override
  State<WeeklyTopCreatorsWidget> createState() =>
      _WeeklyTopCreatorsWidgetState();
}

// ─── State ───────────────────────────────────────────────────────────────────

class _WeeklyTopCreatorsWidgetState extends State<WeeklyTopCreatorsWidget> {
  List<_TopEntry> _entries = [];
  // null = vérification en cours | false = ne pas afficher | true = afficher
  bool? _shouldRender;
  bool _isLoading = false;
  int _currentPage = 0;
  late PageController _pageController;

  final Stopwatch _stopwatch = Stopwatch();
  int _accumulatedMs = 0;

  static const String _prefKeyMs = 'weekly_view_ms';
  static const String _prefKeyDate = 'weekly_view_date';
  static const int _maxViewMs = 8000; // 8 secondes cumulées


  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.37);
    _init();
  }

  Future<void> _init() async {
    if (!_isWeekday()) {
      if (mounted) setState(() => _shouldRender = false);
      return;
    }

    // Lire le temps de vue accumulé pour aujourd'hui
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDate = prefs.getString(_prefKeyDate) ?? '';

    if (savedDate != today) {
      // Nouveau jour → réinitialiser le compteur
      await prefs.setString(_prefKeyDate, today);
      await prefs.setInt(_prefKeyMs, 0);
      _accumulatedMs = 0;
    } else {
      _accumulatedMs = prefs.getInt(_prefKeyMs) ?? 0;
    }

    // 8 secondes cumulées déjà atteintes → ne plus afficher
    if (_accumulatedMs >= _maxViewMs) {
      if (mounted) setState(() => _shouldRender = false);
      return;
    }

    // Doit afficher : démarrer le chrono et le chargement
    if (mounted) setState(() { _shouldRender = true; _isLoading = true; });
    _stopwatch.start();

    // Utiliser le futur préchargé (ou le déclencher si pas encore fait)
    WeeklyTopCreatorsWidget.preload();
    final entries = await (WeeklyTopCreatorsWidget._sharedFuture ??
        Future.value(<_TopEntry>[]));

    if (mounted) {
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _persistViewTime();
    }
    _pageController.dispose();
    super.dispose();
  }

  // Fire-and-forget : persiste le temps accumulé sans bloquer dispose()
  void _persistViewTime() {
    final elapsed = _stopwatch.elapsedMilliseconds;
    if (elapsed == 0) return;
    SharedPreferences.getInstance().then((prefs) {
      final total = _accumulatedMs + elapsed;
      prefs.setInt(_prefKeyMs, total);
      prefs.setString(_prefKeyDate, _todayKey());
    });
  }

  bool _isWeekday() {
    final w = DateTime.now().weekday;
    return w == DateTime.monday || w == DateTime.tuesday;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_shouldRender == null) return const SizedBox.shrink();
    if (_shouldRender == false) return const SizedBox.shrink();

    final colors = AppColors.of(context);

    if (_isLoading) {
      return Container(
        height: 190,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2),
        ),
      );
    }

    if (_entries.isEmpty) return const SizedBox.shrink();

    final range = WeeklyTopCreatorsWidget._lastWeekRangeMicros();
    final startDate = DateTime.fromMicrosecondsSinceEpoch(range['start']!);
    final endDate = DateTime.fromMicrosecondsSinceEpoch(range['end']!)
        .subtract(const Duration(days: 1));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête compact
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top créateurs de la semaine',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Du ${_fmtDate(startDate)} au ${_fmtDate(endDate)}',
                        style: TextStyle(fontSize: 9, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD400).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD400), width: 0.8),
                  ),
                  child: const Text(
                    'Semaine',
                    style: TextStyle(
                      color: Color(0xFFFFD400),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Carousel compact
          SizedBox(
            height: 210,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _entries.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (ctx, i) => _buildCard(_entries[i], i, colors),
            ),
          ),

          // Dots
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_entries.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: active ? 12 : 4,
                height: 4,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFFFD400)
                      : colors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Ouvrir profil ─────────────────────────────────────────────────────────

  void _openProfile(_TopEntry entry) {
    final size = MediaQuery.of(context).size;
    if (entry.isCanal) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => CanalDetails(canal: entry.canal!)));
    } else {
      showUserDetailsModalDialog(
          entry.userData!, size.width, size.height, context);
    }
  }

  // ── Carte ─────────────────────────────────────────────────────────────────

  Widget _buildCard(_TopEntry entry, int rank, AppColors colors) {
    return GestureDetector(
      onTap: () => _openProfile(entry),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image plein-card
              entry.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: entry.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildAvatarFallback(entry, colors),
                    )
                  : _buildAvatarFallback(entry, colors),

              // Overlay sombre en bas
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  color: const Color(0xBF0A0A0A),
                  padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${entry.isCanal ? '#' : '@'}${entry.displayName}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isVerified(entry)) ...[
                            const SizedBox(width: 2),
                            const Icon(Icons.verified, color: Colors.blue, size: 11),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.people_outline, color: Colors.white.withOpacity(0.65), size: 10),
                          const SizedBox(width: 2),
                          Text(
                            '${_fmtCount(entry.followerCount)} abonnés',
                            style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.65)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      _buildOverlayStats(entry),
                      const SizedBox(height: 5),
                      _buildOverlayFollowButton(entry, colors),
                    ],
                  ),
                ),
              ),

              // Badge rang (haut gauche)
              Positioned(
                top: 7, left: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.68),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _rankColor(rank), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_rankEmoji(rank), style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 2),
                      Text('#${rank + 1}',
                          style: TextStyle(color: _rankColor(rank), fontSize: 9, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),

              // Badge type (haut droit)
              Positioned(
                top: 7, right: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.isCanal
                        ? Colors.purple.withOpacity(0.82)
                        : Colors.blue.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.isCanal ? 'Canal' : 'Créateur',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayStats(_TopEntry entry) {
    return Row(
      children: [
        _overlayStatChip(Icons.article_outlined, '${entry.postCount}p'),
        const SizedBox(width: 5),
        _overlayStatChip(Icons.favorite_border, entry.uniqueLovers.toString()),
        const SizedBox(width: 5),
        _overlayStatChip(Icons.chat_bubble_outline, entry.uniqueCommenters.toString()),
        const SizedBox(width: 5),
        _overlayStatChip(Icons.remove_red_eye_outlined, _fmtCount(entry.totalViews)),
      ],
    );
  }

  Widget _overlayStatChip(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 9, color: Colors.white.withOpacity(0.6)),
        const SizedBox(width: 2),
        Text(value, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.6))),
      ],
    );
  }

  Widget _buildOverlayFollowButton(_TopEntry entry, AppColors colors) {
    final isOwn = _isOwnEntry(entry);
    final isFollowing = entry.isCanal
        ? _isFollowingCanal(entry.canal!)
        : _isFollowingUser(entry.userData!.id ?? '');

    if (isOwn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Votre profil',
              style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500)),
        ),
      );
    }

    if (isFollowing) {
      return GestureDetector(
        onTap: () => _openProfile(entry),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFD700), width: 0.8),
          ),
          child: const Center(
            child: Text('Abonné(e)',
                style: TextStyle(fontSize: 10, color: Color(0xFFFFD700), fontWeight: FontWeight.w500)),
          ),
        ),
      );
    }

    final isPaid = entry.isCanal && (entry.canal!.subscriptionPrice > 0);
    return GestureDetector(
      onTap: () {
        if (entry.isCanal) _followCanal(entry.canal!);
        else _followUser(entry.userData!);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            isPaid
                ? 'S\'abonner · ${entry.canal!.subscriptionPrice.toStringAsFixed(0)} FCFA'
                : 'S\'abonner',
            style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }


  // ── Abonnement user ───────────────────────────────────────────────────────

  Future<void> _followUser(UserData targetUser) async {
    if (!mounted) return;
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final currentId = auth.loginUserData.id;
    if (currentId == null || currentId == targetUser.id) return;
    final alreadyFollowing =
        auth.loginUserData.followingIds?.contains(targetUser.id) ?? false;
    if (alreadyFollowing) return;
    await auth.abonner(targetUser, context);
    if (mounted) setState(() {});
  }

  // ── Abonnement canal ──────────────────────────────────────────────────────

  Future<void> _followCanal(Canal canal) async {
    if (!mounted) return;
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final currentId = auth.loginUserData.id;
    if (currentId == null || currentId == canal.userId) return;

    if (canal.isPrivate || canal.subscriptionPrice > 0) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => CanalDetails(canal: canal)));
      return;
    }

    final alreadyFollowing =
        canal.usersSuiviId?.contains(currentId) ?? false;
    if (alreadyFollowing) return;

    canal.usersSuiviId ??= [];
    canal.usersSuiviId!.add(currentId);
    canal.suivi = (canal.suivi ?? 0) + 1;
    if (mounted) setState(() {});

    final fs = FirebaseFirestore.instance;
    fs.collection('Canaux').doc(canal.id).update({
      'usersSuiviId': FieldValue.arrayUnion([currentId]),
      'suivi': FieldValue.increment(1),
    }).catchError((_) {
      canal.usersSuiviId?.remove(currentId);
      canal.suivi = (canal.suivi ?? 1) - 1;
      if (mounted) setState(() {});
    });
    fs.collection('Users').doc(currentId).update({
      'canauxSuivisIds': FieldValue.arrayUnion([canal.id]),
    }).catchError((_) {});
  }

  // ── Vérifications état ────────────────────────────────────────────────────

  bool _isFollowingUser(String userId) {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    return auth.loginUserData.followingIds?.contains(userId) ?? false;
  }

  bool _isFollowingCanal(Canal canal) {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    return canal.usersSuiviId?.contains(auth.loginUserData.id) ?? false;
  }

  bool _isOwnEntry(_TopEntry entry) {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final me = auth.loginUserData.id ?? '';
    return entry.isCanal ? entry.canal?.userId == me : entry.userData?.id == me;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildAvatarFallback(_TopEntry entry, AppColors colors) {
    final initials = entry.displayName.isNotEmpty
        ? entry.displayName.trim().split(' ').take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : '?';
    return Container(
      color: colors.surfaceVariant,
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFD400))),
      ),
    );
  }

  bool _isVerified(_TopEntry entry) =>
      entry.isCanal
          ? (entry.canal?.isVerify ?? false)
          : (entry.userData?.isVerify ?? false);

  Color _rankColor(int rank) {
    switch (rank) {
      case 0: return const Color(0xFFFFD400);
      case 1: return const Color(0xFFC0C0C0);
      case 2: return const Color(0xFFCD7F32);
      default: return Colors.white70;
    }
  }

  String _rankEmoji(int rank) =>
      const ['🥇', '🥈', '🥉', '🎖️', '🎖️'][rank.clamp(0, 4)];

  String _fmtDate(DateTime d) {
    const m = ['', 'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
        'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
    return '${d.day} ${m[d.month]}';
  }

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
