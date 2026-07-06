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

  static const List<String> _encouragements = [
    'La star de la semaine ! Un contenu exceptionnel que vous ne pouvez pas manquer.',
    'Une créativité remarquable cette semaine. Abonnez-vous pour ne rien rater !',
    'Top 3 cette semaine ! Des posts qui ont fait parler de toute la communauté.',
    'Une présence forte cette semaine. Découvrez son univers unique.',
    'Actif et inspirant ! Rejoignez sa communauté qui grandit chaque semaine.',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
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
        height: 420,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    if (_entries.isEmpty) return const SizedBox.shrink();

    final range = WeeklyTopCreatorsWidget._lastWeekRangeMicros();
    final startDate =
        DateTime.fromMicrosecondsSinceEpoch(range['start']!);
    final endDate = DateTime.fromMicrosecondsSinceEpoch(range['end']!)
        .subtract(const Duration(days: 1));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top créateurs de la semaine',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Du ${_fmtDate(startDate)} au ${_fmtDate(endDate)}',
                        style: TextStyle(
                            fontSize: 10, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD400).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFFD400), width: 0.8),
                  ),
                  child: Text(
                    DateTime.now().weekday == DateTime.monday
                        ? 'Lundi'
                        : 'Mardi',
                    style: const TextStyle(
                      color: Color(0xFFFFD400),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Carousel
          SizedBox(
            height: 440,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _entries.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (ctx, i) => _buildCard(_entries[i], i, colors),
            ),
          ),

          // Dots
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_entries.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFFFD400)
                      : colors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
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
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(entry, rank, colors),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom @pseudo ou #canal + vérifié
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${entry.isCanal ? '#' : '@'}${entry.displayName}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isVerified(entry)) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              color: Colors.blue, size: 13),
                        ],
                      ],
                    ),
                    if (entry.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.description,
                        style: TextStyle(
                            fontSize: 10, color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    _buildStatsRow(entry, colors),
                    const SizedBox(height: 5),
                    Text(
                      _encouragements[rank.clamp(0, 4)],
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textSecondary,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    _buildFollowButton(entry, colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header image ──────────────────────────────────────────────────────────

  Widget _buildCardHeader(_TopEntry entry, int rank, AppColors colors) {
    return Stack(
      children: [
        Container(
          height: 230,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            color: colors.surfaceVariant,
          ),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: entry.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: entry.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorWidget: (_, __, ___) =>
                        _buildAvatarFallback(entry, colors),
                  )
                : _buildAvatarFallback(entry, colors),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.55),
                ],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _rankColor(rank), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_rankEmoji(rank),
                    style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 3),
                Text('#${rank + 1}',
                    style: TextStyle(
                        color: _rankColor(rank),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: entry.isCanal
                  ? Colors.purple.withOpacity(0.8)
                  : Colors.blue.withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              entry.isCanal ? 'Canal' : 'Créateur',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 10,
          child: Row(
            children: [
              const Icon(Icons.people_outline,
                  color: Colors.white70, size: 11),
              const SizedBox(width: 3),
              Text(
                '${_fmtCount(entry.followerCount)} abonnés',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 8,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline,
                color: Colors.white70, size: 12),
          ),
        ),
      ],
    );
  }

  // ── Stats compactes ───────────────────────────────────────────────────────

  Widget _buildStatsRow(_TopEntry entry, AppColors colors) {
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: [
        _miniStat(Icons.article_outlined, '${entry.postCount}p', colors),
        _miniStat(Icons.favorite_border, entry.uniqueLovers.toString(), colors),
        _miniStat(Icons.chat_bubble_outline,
            entry.uniqueCommenters.toString(), colors),
        _miniStat(Icons.remove_red_eye_outlined,
            _fmtCount(entry.totalViews), colors),
      ],
    );
  }

  Widget _miniStat(IconData icon, String value, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: colors.textSecondary),
          const SizedBox(width: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary)),
        ],
      ),
    );
  }

  // ── Bouton S'abonner ──────────────────────────────────────────────────────

  Widget _buildFollowButton(_TopEntry entry, AppColors colors) {
    final isOwn = _isOwnEntry(entry);
    final isFollowing = entry.isCanal
        ? _isFollowingCanal(entry.canal!)
        : _isFollowingUser(entry.userData!.id ?? '');

    if (isOwn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('Votre profil',
              style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
      );
    }

    if (isFollowing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFFFD400), width: 1),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                color: Color(0xFFFFD400), size: 14),
            SizedBox(width: 5),
            Text('Abonné(e)',
                style: TextStyle(
                    color: Color(0xFFFFD400),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final isPaid =
        entry.isCanal && (entry.canal!.subscriptionPrice > 0);

    return GestureDetector(
      onTap: () {
        if (entry.isCanal) {
          _followCanal(entry.canal!);
        } else {
          _followUser(entry.userData!);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Colors.black, size: 16),
            const SizedBox(width: 5),
            Text(
              isPaid
                  ? 'S\'abonner · ${entry.canal!.subscriptionPrice.toStringAsFixed(0)} FCFA'
                  : 'S\'abonner',
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ],
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
