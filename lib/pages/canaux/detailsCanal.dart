import 'package:afrotok/pages/create/create_hub_page.dart';
import 'package:afrotok/widgets/name_tag.dart';
import '../../widgets/safe_network_avatar.dart';
import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/pages/userPosts/userPostForm.dart';

import 'package:afrotok/pages/canaux/editCanal.dart';



import 'package:flutter/material.dart';
import 'package:afrotok/services/coin_checkout.dart';

import 'package:afrotok/services/api/canaux_api.dart';
import 'package:afrotok/services/api/canaux_pay.dart';

import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/userProvider.dart';

import 'package:afrotok/models/model_data.dart';

import '../../theme/app_colors.dart';

import '../../l10n/app_localizations.dart';

import '../component/showImage.dart';


import '../userPosts/postWidgets/postWidgetPage.dart';

import 'canal_manage_admins.dart';
import '../user/userPubs/user_profile_boost_page.dart';
import '../admin/admin_canal_detail_page.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import '../../l10n/tr.dart';

class CanalDetails extends StatefulWidget {
  final Canal canal;

  CanalDetails({required this.canal});

  @override
  _CanalDetailsState createState() => _CanalDetailsState();
}

class _CanalDetailsState extends State<CanalDetails> {
  late AppColors _colors;

  // CONFIGURATION - Paiement pour abonnés existants
  final bool _requirePaymentForExistingSubscribers = false;

  late UserAuthProvider authProvider;
  late UserProvider userProvider;

  final StreamController<List<Post>> _streamController = StreamController<List<Post>>();
  final ScrollController _scrollController = ScrollController();

  List<Post> _allPosts = [];
  int _currentPostLimit = 10;
  final int _postsLoadMoreLimit = 5;
  bool _isLoadingPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;
  String? _postsCursor; // curseur de la page suivante (API)
  String? _postsError; // message d'erreur de chargement (bouton « Réessayer »)
  Map<String, dynamic>? _lockedMeta; // canal privé non abonné : members_only, locked_count, price_coins, subscription_type
  Set<String> _freeIds = {}; // publications gratuites (aperçu) du canal privé

  bool isFollowing = false;
  bool _followCheckDone = false; // true dès que l'API a confirmé l'état d'abonnement
  bool _isProcessingSubscription = false;
  bool _isProcessingUnfollow = false;
  bool _monthlySubscriptionExpired = false;
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);

    checkIfFollowing();
    _checkMonthlyExpiry();
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
    // Recharger depuis l'API si le canal passé est incomplet (ex: depuis le feed)
    _reloadCanalIfIncomplete();
  }

  Future<void> _reloadCanalIfIncomplete() async {
    final canalId = widget.canal.id;
    if (canalId == null || canalId.isEmpty) return;
    // Toujours recharger depuis l'API pour avoir les données complètes et à jour (et MA situation : membre, administrateur, échéance)
    try {
      final full = await CanauxApi.get(canalId, myId: authProvider.loginUserData.id).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        widget.canal.titre = full.titre ?? widget.canal.titre;
        widget.canal.urlImage = full.urlImage ?? widget.canal.urlImage;
        widget.canal.urlCouverture = full.urlCouverture ?? widget.canal.urlCouverture;
        widget.canal.description = full.description;
        widget.canal.usersSuiviId = full.usersSuiviId ?? [];
        widget.canal.subscribersId = full.subscribersId;
        widget.canal.suivi = full.suivi ?? widget.canal.suivi;
        widget.canal.isPrivate = full.isPrivate;
        widget.canal.isBlocked = full.isBlocked;
        widget.canal.blockedAt = full.blockedAt;
        widget.canal.isVerify = full.isVerify;
        widget.canal.subscriptionPrice = full.subscriptionPrice;
        widget.canal.subscriptionPriceCoinsRaw = full.subscriptionPriceCoinsRaw;
        widget.canal.subscriptionType = full.subscriptionType;
        widget.canal.monthlySubscriptions = full.monthlySubscriptions;
        widget.canal.adminIds = full.adminIds;
        widget.canal.allowedPostersIds = full.allowedPostersIds;
        widget.canal.allowAllMembersToPost = full.allowAllMembersToPost;
        widget.canal.userId = full.userId ?? widget.canal.userId;
        widget.canal.publication = full.publication ?? widget.canal.publication;
        widget.canal.categories = full.categories;
        widget.canal.mainCategory = full.mainCategory;
        widget.canal.canalScore = full.canalScore;
        widget.canal.user = full.user ?? widget.canal.user;
        isFollowing = widget.canal.usersSuiviId?.contains(authProvider.loginUserData.id) == true;
        _monthlySubscriptionExpired = false;
      });
      _checkMonthlyExpiry();
      if (mounted) setState(() => _followCheckDone = true);
    } catch (e) {
      printVm('Erreur rechargement canal depuis l\'API: $e');
      // Même en cas d'erreur, déverrouiller le bouton pour ne pas bloquer l'UI
      if (mounted) setState(() => _followCheckDone = true);
    }
  }

  @override
  void dispose() {
    _streamController.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent &&
        _hasMorePosts &&
        !_isLoadingMorePosts) {
      _loadMorePosts();
    }
  }

  Future<void> _loadInitialPosts() async {
    final id = widget.canal.id;
    if (id == null) return;
    setState(() {
      _isLoadingPosts = true;
      _postsError = null;
    });

    try {
      final page = await CanauxApi.posts(id, limit: _currentPostLimit);
      if (!mounted) return;
      setState(() {
        _allPosts = page.posts;
        _postsCursor = page.next;
        _lockedMeta = page.meta;
        _freeIds = page.freeIds;
        _hasMorePosts = page.next != null;
        _isLoadingPosts = false;
      });
      _streamController.add(_allPosts);
    } catch (e) {
      printVm('Erreur chargement posts: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingPosts = false;
        _postsError = CanauxApi.message(e);
      });
    }
  }

  Future<void> _loadMorePosts() async {
    final id = widget.canal.id;
    if (id == null || _isLoadingMorePosts || !_hasMorePosts || _postsCursor == null) return;

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      final page = await CanauxApi.posts(id, cursor: _postsCursor, limit: _postsLoadMoreLimit + 5);
      if (!mounted) return;
      final known = _allPosts.map((p) => p.id).toSet();
      setState(() {
        _allPosts = [..._allPosts, ...page.posts.where((p) => !known.contains(p.id))];
        _postsCursor = page.next;
        _freeIds = {..._freeIds, ...page.freeIds};
        _hasMorePosts = page.next != null;
        _isLoadingMorePosts = false;
      });
      _streamController.add(_allPosts);
    } catch (e) {
      printVm('Erreur chargement posts supplémentaires: $e');
      if (mounted) {
        setState(() {
          _isLoadingMorePosts = false;
        });
      }
    }
  }

  void checkIfFollowing() {
    if (widget.canal.usersSuiviId?.contains(authProvider.loginUserData.id) == true) {
      setState(() {
        isFollowing = true;
      });
    }
  }

  void _checkMonthlyExpiry() {
    if (widget.canal.subscriptionType != 'mensuel') return;
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;
    final subs = widget.canal.monthlySubscriptions ?? {};
    final dynamic expiresAt = subs[userId];
    if (expiresAt == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((expiresAt as int) < now) {
      setState(() => _monthlySubscriptionExpired = true);
    }
  }

  Future<void> _handleFollowAction() async {
    final isPrivate = widget.canal.isPrivate == true;

    // Abonnement mensuel expiré → forcer le renouvellement
    if (_monthlySubscriptionExpired) {
      await _handlePrivateCanalSubscription();
      return;
    }

    if (isFollowing) {
      await _handleUnfollowCanal();
    } else {
      if (isPrivate) {
        await _handlePrivateCanalSubscription();
      } else {
        await _followPublicCanal();
      }
    }
  }

  Future<void> _handleUnfollowCanal() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final isPrivate = widget.canal.isPrivate == true;

        final colors = AppColors.of(context);
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            l10n.canalUnsubscribe,
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Êtes-vous sûr de vouloir vous désabonner de ce canal?'),
                style: TextStyle(color: colors.textSecondary),
              ),
              SizedBox(height: 8),
              if (isPrivate)
                Text(
                  context.tr('⚠️ Attention: Si vous vous désabonnez, vous devrez repayer l\'abonnement de {a} pièces pour y accéder à nouveau.', {'a': CoinCheckout.fmt(widget.canal.subscriptionPriceCoins)}),
                  style: TextStyle(
                    color: colors.accentText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr('Annuler'), style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.danger),
              child: Text(l10n.canalUnsubscribe, style: TextStyle(color: colors.onPrimary)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _processUnfollow();
    }
  }

  Future<void> _processUnfollow() async {
    setState(() {
      _isProcessingUnfollow = true;
    });

    try {
      final String userId = authProvider.loginUserData.id!;

      // Se désabonner (API)
      await CanauxApi.leave(widget.canal.id!);
      widget.canal.usersSuiviId!.remove(userId);
      widget.canal.suivi = ((widget.canal.suivi ?? 1) - 1).clamp(0, 1 << 30);
      if (widget.canal.isPrivate) _loadInitialPosts(); // un canal privé n'affiche plus que les publications gratuites

      // Mettre à jour l'état local
      setState(() {
        isFollowing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('✅ Vous vous êtes désabonné de ce canal.'),
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      printVm('Erreur désabonnement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CanauxApi.message(e, fallback: context.tr('❌ Erreur lors du désabonnement')),
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.danger,
        ),
      );
    } finally {
      setState(() {
        _isProcessingUnfollow = false;
      });
    }
  }

  Future<void> _deleteCanal() async {
    final myId = authProvider.loginUserData.id!;
    final isOwner = myId == widget.canal.userId;
    if (!isOwner) return; // la suppression par un admin se fait depuis Admin > Canaux

    // Étape 1 : avertissement
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: colors.surface,
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text(context.tr('Supprimer le canal'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
          ]),
          content: Text(
            context.tr('Cette action est irréversible.\nTous les posts et abonnés seront supprimés définitivement.'),
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Annuler'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(context.tr('Continuer'), style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;
    if (!step1 || !mounted) return;

    // Étape 2 : confirmation finale
    final canalName = widget.canal.titre ?? context.tr('ce canal');
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: colors.surface,
          title: Text(context.tr('Dernière confirmation'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: colors.textPrimary)),
          content: Text(context.tr('Supprimer définitivement le canal\n"{a}" ?', {'a': canalName}), style: TextStyle(color: colors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Non, annuler'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(context.tr('Oui, supprimer'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    ) ?? false;
    if (!step2 || !mounted) return;

    try {
      // Suppression par l'API (le titre redevient libre ; les publications du canal ne sont plus visibles)
      await CanauxApi.delete(widget.canal.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Canal supprimé avec succès')), backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CanauxApi.message(e, fallback: context.tr('Erreur lors de la suppression'))),
            backgroundColor: _colors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handlePrivateCanalSubscription() async {
    final subscriptionPrice = widget.canal.subscriptionPrice ?? 0;
    final subType = widget.canal.subscriptionType;
    final isMensuel = subType == 'mensuel';
    final isAlreadySubscribed = widget.canal.usersSuiviId?.contains(authProvider.loginUserData.id) == true;

    // Abonné unique déjà inscrit → accès maintenu
    if (isAlreadySubscribed && !isMensuel && !_requirePaymentForExistingSubscribers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('✅ Vous avez déjà accès à ce canal privé!'),
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.primary,
        ),
      );
      return;
    }


    // Libellés adaptés au type d'abonnement
    final String dialogTitle;
    final String confirmationMessage;
    if (_monthlySubscriptionExpired) {
      dialogTitle = context.tr('Renouveler l\'abonnement');
      confirmationMessage = context.tr('Votre abonnement mensuel a expiré.\n\nRenouvelez pour {a} par mois et continuez à accéder à ce canal.', {'a': CoinCheckout.coinsLabel(widget.canal.subscriptionPriceCoins)});
    } else if (isMensuel) {
      dialogTitle = context.tr('Abonnement Mensuel');
      confirmationMessage = context.tr('Ce canal est privé — abonnement mensuel à {a} par mois.\n\nL\'accès est valable 30 jours, puis renouvelable.', {'a': CoinCheckout.coinsLabel(widget.canal.subscriptionPriceCoins)});
    } else {
      dialogTitle = context.tr('Abonnement Unique');
      confirmationMessage = context.tr('Ce canal est privé. L\'accès à vie coûte {a}.\n\nConfirmez-vous l\'abonnement ?', {'a': CoinCheckout.coinsLabel(widget.canal.subscriptionPriceCoins)});
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final colors = AppColors.of(context);
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(dialogTitle, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          content: Text(confirmationMessage, style: TextStyle(color: colors.textSecondary, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr('Annuler'), style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
              child: Text(
                isMensuel ? context.tr('S\'abonner — {a} pièces/mois', {'a': CoinCheckout.fmt(widget.canal.subscriptionPriceCoins)}) : context.tr('Confirmer'),
                style: TextStyle(color: colors.onPrimary),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _processPrivateSubscription(subscriptionPrice, isAlreadySubscribed);
    }
  }

  Future<void> _processPrivateSubscription(double price, bool isAlreadySubscribed) async {
    setState(() {
      _isProcessingSubscription = true;
    });

    try {
      // Paiement en pièces par l'API (point d'achat unique) : le serveur débite, partage et enregistre l'abonnement (et son échéance si mensuel)
      final paid = await CanauxPay.buy(context,
          kind: 'canal', refId: widget.canal.id, coins: widget.canal.subscriptionPriceCoins, label: context.tr('Abonnement au canal'));
      if (!paid) {
        if (mounted) setState(() => _isProcessingSubscription = false);
        return;
      }
      if (mounted) setState(() => _monthlySubscriptionExpired = false);
      await _reloadCanalIfIncomplete();
      _loadInitialPosts(); // toutes les publications du canal sont maintenant visibles
      addPointsForAction(UserAction.abonne);

      final isMensuel = widget.canal.subscriptionType == 'mensuel';
      String successMessage = isMensuel
          ? context.tr('✅ Abonnement mensuel activé ! Accès valable 30 jours.')
          : isAlreadySubscribed && _requirePaymentForExistingSubscribers
              ? context.tr('✅ Paiement accepté! Vous conservez l\'accès au canal privé.')
              : context.tr('✅ Abonnement réussi! Canal privé ajouté.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successMessage,
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      printVm('Erreur abonnement privé: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CanauxApi.message(e, fallback: context.tr('❌ Erreur lors de l\'abonnement')),
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.danger,
        ),
      );
    } finally {
      setState(() {
        _isProcessingSubscription = false;
      });
    }
  }

  Future<void> _followPublicCanal() async {
    await _followCanal();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ ${AppLocalizations.of(context).canalNowFollowing}!',
          style: TextStyle(color: _colors.onPrimary),
        ),
        backgroundColor: _colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _followCanal() async {
    final String userId = authProvider.loginUserData.id!;

    if (widget.canal.usersSuiviId!.contains(userId)) {
      return;
    }

    // S'abonner (API). La notification au propriétaire est envoyée par le serveur.
    await CanauxApi.join(widget.canal.id!);
    widget.canal.usersSuiviId!.add(userId);
    widget.canal.suivi = (widget.canal.suivi ?? 0) + 1;
    addPointsForAction(UserAction.abonne);
    addPointsForOtherUserAction(widget.canal.userId!, UserAction.autre);

    setState(() {
      isFollowing = true;
    });
  }

  Widget _buildHeaderSection() {
    final isPrivate = widget.canal.isPrivate == true;
    final isOwner = authProvider.loginUserData.id == widget.canal.userId;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      sliver: SliverToBoxAdapter(
        child: Stack(
          children: [
            // Image de couverture
            GestureDetector(
              onTap: () {
                if (widget.canal.urlCouverture?.isNotEmpty != true) return;
                showImageDetailsModalDialog(widget.canal.urlCouverture!,
                    MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height,
                    context
                );
              },
              child: Container(
                height: AppLayout.isWide(context) ? 260 : 200,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: AppLayout.isWide(context) ? const BorderRadius.vertical(bottom: Radius.circular(16)) : null,
                ),
                child: Stack(fit: StackFit.expand, children: [
                  SafeNetworkCover(url: widget.canal.urlCouverture),
                  Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                ]),
              ),
            ),

            // Avatar du canal
            Positioned(
              bottom: 10,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  if (widget.canal.urlImage?.isNotEmpty != true) return;
                  showImageDetailsModalDialog(widget.canal.urlImage!,
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height,
                      context
                  );
                },
                child: Stack(
                  children: [
                    Container(
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _colors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: SafeNetworkAvatar(
                        url: widget.canal.urlImage,
                        radius: 45,
                        fallbackIcon: Icons.tv_rounded,
                        backgroundColor: _colors.surfaceVariant,
                        iconColor: _colors.textSecondary,
                      ),
                    ),
                    if (isPrivate)
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _colors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock,
                            color: _colors.onAccent,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Badge propriétaire
            if (isOwner)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _colors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppLocalizations.of(context).canalOwner,
                    style: TextStyle(
                      color: _colors.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final isPrivate = widget.canal.isPrivate == true;
    final isOwner = authProvider.loginUserData.id == widget.canal.userId;
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
    final subscribersCount = widget.canal.membersCount;
    final postsCount = widget.canal.publication ?? 0;

    return SliverPadding(
      padding: EdgeInsets.all(16),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre et badges
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: NameTag(bordered: false, label: "#${widget.canal.titre!}",
                              style: TextStyle(
                                color: _colors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          ),
                          SizedBox(width: 8),
                          if (widget.canal.isVerify == true)
                            Icon(Icons.verified, color: _colors.info, size: 24),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Statistiques
                      Row(
                        children: [
                          _buildStatItem(
                            icon: Icons.people,
                            value: subscribersCount.toString(),
                            label: AppLocalizations.of(context).canalFollowers,
                          ),
                          SizedBox(width: 16),
                          _buildStatItem(
                            icon: Icons.post_add,
                            value: postsCount.toString(),
                            label: AppLocalizations.of(context).canalPublications,
                          ),
                          if (isPrivate) ...[
                            SizedBox(width: 16),
                            _buildStatItem(
                              icon: Icons.attach_money,
                              value: CoinCheckout.fmt(widget.canal.subscriptionPriceCoins),
                              label: context.tr('pièces'),
                              color: _colors.accent,
                            ),
                          ],
                        ],
                      ),
                      if ((widget.canal.canalScore ?? 0) > 0) ...[
                        SizedBox(height: 8),
                        _buildCanalScoreBadge(widget.canal.canalScore!),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Ligne principale : Follow/Unfollow + menu 3-points
            Row(
              children: [
                // Bouton Follow/Unfollow — affiché uniquement après vérification de l'API
                if (!isOwner)
                  Expanded(
                    child: SizedBox(
                      height: 45,
                      child: !_followCheckDone
                          // Placeholder pendant le check — même taille que le bouton
                          ? Container(
                              decoration: BoxDecoration(
                                color: _colors.shimmerBase,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _colors.textSecondary),
                                ),
                              ),
                            )
                          : isFollowing && !_isProcessingUnfollow && !_monthlySubscriptionExpired
                          ? Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _colors.surface,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: _colors.border),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.check_circle_rounded, size: 18, color: _colors.primary),
                                const SizedBox(width: 6),
                                Text(context.tr('Abonné'),
                                    style: TextStyle(color: _colors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                              ]),
                            )
                          : ElevatedButton(
                              onPressed: (_isProcessingSubscription || _isProcessingUnfollow) ? null : _handleFollowAction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing
                                    ? _colors.danger
                                    : (isPrivate ? _colors.accent : _colors.primary),
                                foregroundColor: isFollowing
                                    ? _colors.onPrimary
                                    : (isPrivate ? _colors.onAccent : _colors.onPrimary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: (_isProcessingSubscription || _isProcessingUnfollow)
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isFollowing ? _colors.onPrimary : (isPrivate ? _colors.onAccent : _colors.onPrimary),
                                      ),
                                    )
                                  : Text(
                                      _monthlySubscriptionExpired
                                          ? context.tr('Renouveler l\'abonnement')
                                          : isFollowing
                                          ? AppLocalizations.of(context).canalUnsubscribeBtn
                                          : (isPrivate ? AppLocalizations.of(context).canalSubscribeBtn : AppLocalizations.of(context).canalFollowBtn),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                            ),
                    ),
                  ),

                if (!isOwner) const SizedBox(width: 8),

                // Menu 3-points — propriétaire
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: _colors.textPrimary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      switch (value) {
                        case 'modifier':
                          Navigator.push(context, MaterialPageRoute(builder: (_) => EditCanal(canal: widget.canal)));
                          break;
                        case 'admins':
                          Navigator.push(context, MaterialPageRoute(builder: (_) => CanalManageAdminsPage(canal: widget.canal)));
                          break;
                        case 'booster':
                          Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileBoostPage(canal: widget.canal)));
                          break;
                        case 'supprimer':
                          _deleteCanal();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'modifier',
                        child: Row(children: [
                          Icon(Icons.edit, size: 18, color: _colors.textPrimary),
                          const SizedBox(width: 10),
                          Text(context.tr('Modifier'), style: TextStyle(color: _colors.textPrimary)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'admins',
                        child: Row(children: [
                          Icon(Icons.admin_panel_settings, size: 18, color: _colors.textPrimary),
                          const SizedBox(width: 10),
                          Text(AppLocalizations.of(context).canalManageAdmins, style: TextStyle(color: _colors.textPrimary)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'booster',
                        child: Row(children: [
                          const Icon(Icons.rocket_launch_outlined, size: 18, color: Color(0xFFFFD700)),
                          const SizedBox(width: 10),
                          Text(context.tr('Booster ce canal'), style: TextStyle(color: _colors.textPrimary)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'supprimer',
                        child: Row(children: [
                          const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                          const SizedBox(width: 10),
                          Text(context.tr('Supprimer le canal'), style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),

                // Menu 3-points — non-propriétaire : se désabonner, et suppression pour l'admin plateforme
                if (!isOwner && isFollowing && _followCheckDone && !_monthlySubscriptionExpired)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: _colors.textPrimary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'desabonner') _handleFollowAction();
                    },
                    itemBuilder: (_) => [
                      if (isFollowing && _followCheckDone && !_monthlySubscriptionExpired)
                        PopupMenuItem(
                          value: 'desabonner',
                          child: Row(children: [
                            Icon(Icons.person_remove_rounded, size: 18, color: _colors.danger),
                            const SizedBox(width: 10),
                            Text(AppLocalizations.of(context).canalUnsubscribeBtn, style: TextStyle(color: _colors.danger)),
                          ]),
                        ),
                    ],
                  ),
              ],
            ),

            // Bouton POSTER (propriétaire ou admin canal)
            if (!widget.canal.isBlocked && (isOwner || widget.canal.adminIds?.contains(authProvider.loginUserData.id) == true)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreateHubPage(canal: widget.canal)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colors.primary,
                    foregroundColor: _colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, size: 18),
                      const SizedBox(width: 6),
                      const Text('POSTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],

            // Boost du canal pour les administrateurs du canal (le propriétaire l'a dans son menu) : l'API accepte les deux
            if (!widget.canal.isBlocked && !isOwner && widget.canal.adminIds?.contains(authProvider.loginUserData.id) == true) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileBoostPage(canal: widget.canal))),
                  icon: const Icon(Icons.rocket_launch_outlined, size: 18, color: Color(0xFFFFD700)),
                  label: Text(context.tr('Booster ce canal'), style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                ),
              ),
            ],

            // // Boutons d'action
            // Row(
            //   children: [
            //     if (!isOwner)
            //       Expanded(
            //         child: Container(
            //           height: 45,
            //           child: ElevatedButton(
            //             onPressed: (_isProcessingSubscription || _isProcessingUnfollow) ? null : _handleFollowAction,
            //             style: ElevatedButton.styleFrom(
            //               backgroundColor: isFollowing
            //                   ? Colors.red // Rouge pour se désabonner
            //                   : (isPrivate ? _primaryYellow : _primaryGreen),
            //               foregroundColor: isFollowing
            //                   ? Colors.white // Blanc pour le texte de désabonnement
            //                   : (isPrivate ? Colors.black : Colors.white),
            //               shape: RoundedRectangleBorder(
            //                 borderRadius: BorderRadius.circular(25),
            //               ),
            //             ),
            //             child: (_isProcessingSubscription || _isProcessingUnfollow)
            //                 ? SizedBox(
            //               height: 20,
            //               width: 20,
            //               child: CircularProgressIndicator(
            //                 strokeWidth: 2,
            //                 color: isFollowing ? Colors.white : (isPrivate ? Colors.black : Colors.white),
            //               ),
            //             )
            //                 : Text(
            //               isFollowing
            //                   ? 'SE DÉSABONNER'
            //                   : (isPrivate ? 'S\'ABONNER' : 'SUIVRE'),
            //               style: TextStyle(
            //                 fontSize: 14,
            //                 fontWeight: FontWeight.bold,
            //               ),
            //             ),
            //           ),
            //         ),
            //       ),
            //
            //     if (isOwner) ...[
            //       Expanded(
            //         child: Container(
            //           height: 45,
            //           child: ElevatedButton(
            //             onPressed: () {
            //               Navigator.push(
            //                 context,
            //                 MaterialPageRoute(builder: (context) => EditCanal(canal: widget.canal)),
            //               );
            //             },
            //             style: ElevatedButton.styleFrom(
            //               backgroundColor: _cardColor,
            //               foregroundColor: _textColor,
            //               shape: RoundedRectangleBorder(
            //                 borderRadius: BorderRadius.circular(25),
            //                 side: BorderSide(color: _primaryGreen),
            //               ),
            //             ),
            //             child: Row(
            //               mainAxisAlignment: MainAxisAlignment.center,
            //               children: [
            //                 Icon(Icons.edit, size: 18),
            //                 SizedBox(width: 6),
            //                 Text('MODIFIER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            //               ],
            //             ),
            //           ),
            //         ),
            //       ),
            //       SizedBox(width: 12),
            //       Expanded(
            //         child: Container(
            //           height: 45,
            //           child: ElevatedButton(
            //             onPressed: () {
            //               Navigator.push(
            //                 context,
            //                 MaterialPageRoute(builder: (context) => CanalPostForm(canal: widget.canal)),
            //               );
            //             },
            //             style: ElevatedButton.styleFrom(
            //               backgroundColor: _primaryGreen,
            //               foregroundColor: Colors.white,
            //               shape: RoundedRectangleBorder(
            //                 borderRadius: BorderRadius.circular(25),
            //               ),
            //             ),
            //             child: Row(
            //               mainAxisAlignment: MainAxisAlignment.center,
            //               children: [
            //                 Icon(Icons.add, size: 18),
            //                 SizedBox(width: 6),
            //                 Text('POSTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            //               ],
            //             ),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ],
            // ),
            //
            // // if (isOwner || isAdmin) ...[
            // if (isAdmin) ...[
            //   SizedBox(height: 12),
            //   Container(
            //     width: double.infinity,
            //     height: 45,
            //     child: ElevatedButton(
            //       onPressed: () {
            //         Navigator.push(
            //           context,
            //           MaterialPageRoute(builder: (context) => ChannelFollowersPage(userIds: widget.canal.usersSuiviId!, channelName: widget.canal.titre!,)),
            //         );
            //       },
            //       style: ElevatedButton.styleFrom(
            //         backgroundColor: _primaryYellow,
            //         foregroundColor: Colors.black,
            //         shape: RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(25),
            //         ),
            //       ),
            //       child: Row(
            //         mainAxisAlignment: MainAxisAlignment.center,
            //         children: [
            //           Icon(Icons.people, size: 18),
            //           SizedBox(width: 6),
            //           Text('VOIR MES ABONNÉS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            //         ],
            //       ),
            //     ),
            //   ),
            // ],

            SizedBox(height: 16),

            // Bandeau propriétaire — visible uniquement pour les admins plateforme
            if (authProvider.loginUserData.role == 'ADM' ||
                authProvider.loginUserData.role == 'admin') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('Propriétaire : '),
                      style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    // Photo + pseudo : ouvre la fenêtre du profil
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: widget.canal.user == null
                            ? null
                            : () => showUserDetailsModalDialog(
                                  widget.canal.user!,
                                  MediaQuery.of(context).size.width,
                                  MediaQuery.of(context).size.height,
                                  context,
                                ),
                        child: Row(children: [
                          SafeNetworkAvatar(
                            url: widget.canal.user?.imageUrl,
                            radius: 13,
                            backgroundColor: _colors.surfaceVariant,
                            iconColor: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.canal.user?.pseudo != null ? '@${widget.canal.user!.pseudo}' : context.tr('Chargement…'),
                              style: const TextStyle(color: Colors.orange, fontSize: 12.5, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                    ),
                    // Fiche admin de l'utilisateur
                    if (widget.canal.userId != null)
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AdminCanalDetailPage(canalId: widget.canal.id!)),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text(context.tr('Gérer le canal'), style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Description
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _colors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: _colors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).canalDescription,
                        style: TextStyle(
                          color: _colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Builder(builder: (context) {
                    final desc = widget.canal.description ?? AppLocalizations.of(context).canalNoDescription;
                    const maxLines = 3;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          desc,
                          style: TextStyle(color: _colors.textSecondary, fontSize: 14),
                          maxLines: _descriptionExpanded ? null : maxLines,
                          overflow: _descriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                        if (widget.canal.description != null && widget.canal.description!.length > 120)
                          GestureDetector(
                            onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _descriptionExpanded ? context.tr('Voir moins') : context.tr('Voir plus'),
                                style: TextStyle(
                                  color: _colors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Section Posts
            Row(
              children: [
                Icon(Icons.dynamic_feed, color: _colors.accentText, size: 24),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).canalPublications,
                  style: TextStyle(
                    color: _colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanalScoreBadge(double score) {
    final color = score >= 50
        ? const Color(0xFF4CAF50)
        : score >= 15
            ? const Color(0xFFFFD700)
            : _colors.textSecondary;
    final label = score >= 50 ? context.tr('Canal populaire') : score >= 15 ? context.tr('Canal actif') : context.tr('Canal');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.trending_up_rounded, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          context.tr('{a} · {b} pts', {'a': label, 'b': score.toStringAsFixed(1)}),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    Color? color,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color ?? _colors.textSecondary, size: 16),
            SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: _colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            color: _colors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPostsSection() {
    return StreamBuilder<List<Post>>(
      stream: _streamController.stream,
      builder: (context, snapshot) {
        if (_isLoadingPosts) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: _colors.primary),
              ),
            ),
          );
        } else if (_postsError != null) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: _colors.danger, size: 40),
                    const SizedBox(height: 12),
                    Text(_postsError!, textAlign: TextAlign.center, style: TextStyle(color: _colors.textSecondary)),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _loadInitialPosts, child: Text(context.tr('Réessayer'))),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: _colors.danger, size: 50),
                    SizedBox(height: 16),
                    Text(
                      context.tr('Erreur de chargement'),
                      style: TextStyle(color: _colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if ((!snapshot.hasData || snapshot.data!.isEmpty) && _lockedCount > 0) {
          return SliverToBoxAdapter(child: _buildLockedCard());
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.feed, color: _colors.textSecondary, size: 50),
                    SizedBox(height: 16),
                    Text(
                      context.tr('Aucune publication'),
                      style: TextStyle(color: _colors.textSecondary, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      context.tr('Soyez le premier à publier dans ce canal!'),
                      style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final posts = snapshot.data!;
          return SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                if (index == posts.length && _isLoadingMorePosts) {
                  return _buildLoadMoreIndicator();
                }
                if (index >= posts.length) return _buildLockedCard();

                final post = posts[index];
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFreePreviewSwitch(post),
                      HomePostUsersWidget(
                        post: post,
                        color: _colors.primary,
                        height: MediaQuery.of(context).size.height,
                        width: _contentWidth,
                      ),
                    ],
                  ),
                );
              },
              childCount: posts.length + (_isLoadingMorePosts ? 1 : 0) + (_lockedCount > 0 ? 1 : 0),
            ),
          );
        }

        return SliverToBoxAdapter(
          child: SizedBox.shrink(),
        );
      },
    );
  }

  /// Nombre de publications réservées aux abonnés que je ne peux pas voir (canal privé, personne non abonnée).
  int get _lockedCount => (_lockedMeta?['members_only'] == true) ? ((_lockedMeta?['locked_count'] as num?)?.toInt() ?? 0) : 0;

  /// « Abonne-toi pour voir N publications » : prix et type d'abonnement viennent du serveur (meta de la liste).
  Widget _buildLockedCard() {
    final n = _lockedCount;
    final coins = (_lockedMeta?['price_coins'] as num?)?.toInt() ?? widget.canal.subscriptionPriceCoins;
    final monthly = _lockedMeta?['subscription_type'] == 'monthly';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.primary.withOpacity(0.4)),
      ),
      child: Column(children: [
        Icon(Icons.lock_rounded, color: _colors.primary, size: 30),
        const SizedBox(height: 8),
        Text(
          n == 1 ? context.tr('Abonne-toi pour voir 1 publication') : context.tr('Abonne-toi pour voir {a} publications', {'a': n}),
          textAlign: TextAlign.center,
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          monthly
              ? context.tr('{a} par mois', {'a': CoinCheckout.coinsLabel(coins)})
              : context.tr('Accès à vie : {a}', {'a': CoinCheckout.coinsLabel(coins)}),
          style: TextStyle(color: _colors.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _isProcessingSubscription ? null : _handleFollowAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: _colors.primary,
              foregroundColor: _colors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            child: Text(context.tr('S\'abonner'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  /// Pour le créateur et les administrateurs d'un canal privé : choisir publication par publication ce qui est gratuit ou réservé aux abonnés.
  Widget _buildFreePreviewSwitch(Post post) {
    final me = authProvider.loginUserData.id;
    final isAdmin = me != null && (me == widget.canal.userId || widget.canal.adminIds?.contains(me) == true);
    if (!widget.canal.isPrivate || !isAdmin || post.id == null) return const SizedBox.shrink();
    final free = _freeIds.contains(post.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(free ? Icons.public : Icons.lock_outline, size: 16, color: _colors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            free ? context.tr('Gratuite : visible de tout le monde') : context.tr('Réservée aux abonnés'),
            style: TextStyle(color: _colors.textSecondary, fontSize: 12),
          ),
        ),
        Switch(
          value: free,
          activeColor: _colors.primary,
          onChanged: (v) async {
            try {
              await CanauxApi.setFreePreview(widget.canal.id!, post.id!, v);
              if (!mounted) return;
              setState(() => v ? _freeIds.add(post.id!) : _freeIds.remove(post.id));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CanauxApi.message(e))));
            }
          },
        ),
      ]),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: _isLoadingMorePosts
            ? CircularProgressIndicator(color: _colors.primary)
            : _hasMorePosts
            ? Text(
          context.tr('Charger plus...'),
          style: TextStyle(color: _colors.textSecondary),
        )
            : Container(
          padding: EdgeInsets.all(16),
          child: Text(
            context.tr('🎉 Vous avez vu toutes les publications!'),
            style: TextStyle(
              color: _colors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        iconTheme: IconThemeData(color: _colors.textPrimary),
        title: NameTag(bordered: false, label: '#${widget.canal.titre ?? ''}',
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.bold,
          )),
        backgroundColor: _colors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _colors.primary),
            onPressed: _loadInitialPosts,
          ),
        ],
      ),
      // Tablette et ordinateur : contenu centré (couverture, infos et publications)
      body: CenteredContent(
        maxWidth: _contentMaxWidth,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            if (widget.canal.isBlocked) SliverToBoxAdapter(child: _buildBlockedBanner()),
            _buildHeaderSection(),
            _buildInfoSection(),
            _buildPostsSection(),
          ],
        ),
      ),
    );
  }

  // ── Canal bloqué pour inactivité (20 jours sans publication) ─────────────────────────────

  bool _unlocking = false;

  Widget _buildBlockedBanner() {
    final isOwner = authProvider.loginUserData.id == widget.canal.userId;
    final warn = _colors.danger;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warn.withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lock_rounded, color: warn, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.tr('Canal bloqué : inactif depuis 20 jours'),
                style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          isOwner
              ? context.tr('Ton canal n\'a rien publié depuis 20 jours. Il est bloqué : personne ne peut y publier. Débloque-le avec des pièces pour le relancer.')
              : context.tr('Ce canal est temporairement bloqué : son propriétaire n\'a rien publié depuis 20 jours.'),
          style: TextStyle(color: _colors.textSecondary, fontSize: 12.5, height: 1.4),
        ),
        if (isOwner) ...[
          const SizedBox(height: 12),
          FutureBuilder<int?>(
            future: _unlockQuote(),
            builder: (context, snap) {
              final cost = snap.data;
              return SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: (_unlocking || cost == null) ? null : () => _confirmUnlock(cost),
                  icon: _unlocking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(
                    cost == null ? context.tr('Chargement…') : context.tr('Débloquer · {a} pièces', {'a': cost}),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colors.primary,
                    foregroundColor: _colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                ),
              );
            },
          ),
        ],
      ]),
    );
  }

  Future<int?>? _quoteFuture;
  Future<int?> _unlockQuote() {
    return _quoteFuture ??= () async {
      try {
        return (await CanauxApi.unlockQuote(widget.canal.id!))['coins'] as int?;
      } catch (_) {
        return null;
      }
    }();
  }

  Future<void> _confirmUnlock(int cost) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        title: Text(context.tr('Débloquer le canal ?'), style: TextStyle(color: _colors.textPrimary)),
        content: Text(
          context.tr('Le déblocage coûte {a} pièces (selon ton nombre d\'abonnés). Ton canal sera de nouveau actif et le compteur de 20 jours repart de zéro.', {'a': cost}),
          style: TextStyle(color: _colors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Débloquer'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _unlocking = true);
    try {
      final paid = await CanauxPay.buy(context, kind: 'canal_unlock', refId: widget.canal.id, coins: cost, label: context.tr('Débloquer le canal'));
      if (!mounted) return;
      setState(() {
        if (paid) widget.canal.isBlocked = false;
        _unlocking = false;
      });
      if (paid) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Canal débloqué !'))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _unlocking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CanauxApi.message(e, fallback: context.tr('Déblocage impossible')))));
    }
  }

  double get _contentMaxWidth => AppLayout.isDesktop(context) ? 820 : AppLayout.maxFeedWidth;

  /// Largeur réelle de la colonne de contenu (et non de l'écran).
  double get _contentWidth {
    final w = MediaQuery.of(context).size.width;
    return w < _contentMaxWidth ? w : _contentMaxWidth;
  }
}

