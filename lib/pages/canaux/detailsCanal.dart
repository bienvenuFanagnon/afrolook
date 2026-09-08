import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'dart:math';
import 'package:afrotok/pages/canaux/canalPostNew.dart';

import 'package:afrotok/pages/canaux/editCanal.dart';

import 'package:afrotok/providers/postProvider.dart';

import 'package:auto_animated/auto_animated.dart';

import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/userProvider.dart';

import 'package:afrotok/models/model_data.dart';

import '../../theme/app_colors.dart';

import '../../l10n/app_localizations.dart';

import '../component/showImage.dart';

import '../paiement/newDepot.dart';

import '../userPosts/postWidgets/postWidgetPage.dart';

import 'canal_manage_admins.dart';
import '../user/userPubs/user_profile_boost_page.dart';
import '../user/profile/retraitAdmin/userAllDetails.dart';

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
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final StreamController<List<Post>> _streamController = StreamController<List<Post>>();
  final ScrollController _scrollController = ScrollController();

  List<Post> _allPosts = [];
  int _currentPostLimit = 10;
  final int _postsLoadMoreLimit = 5;
  bool _isLoadingPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;

  bool isFollowing = false;
  bool _isProcessingSubscription = false;
  bool _isProcessingUnfollow = false;
  bool _monthlySubscriptionExpired = false;
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    checkIfFollowing();
    _checkMonthlyExpiry();
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
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
    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final posts = await postProvider.getCanalPostsLimited(_currentPostLimit, widget.canal);
      setState(() {
        _allPosts = posts;
        _hasMorePosts = posts.length == _currentPostLimit;
        _isLoadingPosts = false;
      });
      _streamController.add(_allPosts);
    } catch (e) {
      printVm('Erreur chargement posts: $e');
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMorePosts || !_hasMorePosts) return;

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      final newLimit = _currentPostLimit + _postsLoadMoreLimit;
      final morePosts = await postProvider.getCanalPostsLimited(newLimit, widget.canal);

      setState(() {
        _allPosts = morePosts;
        _currentPostLimit = newLimit;
        _hasMorePosts = morePosts.length == newLimit;
        _isLoadingMorePosts = false;
      });
      _streamController.add(_allPosts);
    } catch (e) {
      printVm('Erreur chargement posts supplémentaires: $e');
      setState(() {
        _isLoadingMorePosts = false;
      });
    }
  }

  void checkIfFollowing() {
    if (widget.canal.usersSuiviId!.contains(authProvider.loginUserData.id)) {
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
        final subscriptionPrice = widget.canal.subscriptionPrice ?? 0;

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
                'Êtes-vous sûr de vouloir vous désabonner de ce canal?',
                style: TextStyle(color: colors.textSecondary),
              ),
              SizedBox(height: 8),
              if (isPrivate)
                Text(
                  '⚠️ Attention: Si vous vous désabonnez, vous devrez repayer l\'abonnement de ${subscriptionPrice}FCFA pour y accéder à nouveau.',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
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

      // Retirer l'utilisateur des abonnés
      widget.canal.usersSuiviId!.remove(userId);
      await firestore.collection('Canaux').doc(widget.canal.id).update({
        'usersSuiviId': widget.canal.usersSuiviId,
      });
      // Supprimer du doc User (dénormalisation symétrique)
      firestore.collection('Users').doc(userId).update({
        'canauxSuivisIds': FieldValue.arrayRemove([widget.canal.id]),
      }).catchError((_) {});

      // Mettre à jour l'état local
      setState(() {
        isFollowing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Vous vous êtes désabonné de ce canal.',
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
            '❌ Erreur lors du désabonnement',
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

  Future<void> _fillSubscribersWithActiveUsers() async {
    // Saisie du nombre d'abonnés à ajouter
    final controller = TextEditingController();
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: colors.surface,
          title: Row(children: [
            Icon(Icons.group_add, color: colors.primary, size: 22),
            const SizedBox(width: 8),
            Text('Remplir les abonnés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nombre d\'utilisateurs actifs à ajouter (ex : 1000, 10 000…) :',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ex : 500',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final n = int.tryParse(controller.text.trim());
                if (n != null && n > 0) Navigator.pop(ctx, n);
              },
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary),
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (count == null || !mounted) return;

    // Capturer navigator + messenger AVANT tout await pour éviter l'erreur
    // "_dependents.isEmpty" causée par l'utilisation de context après async gap
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    bool _dialogOpen = true;
    final progressNotifier = ValueNotifier<String>('Initialisation…');
    nav.push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      pageBuilder: (ctx, _, __) => PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ValueListenableBuilder<String>(
                valueListenable: progressNotifier,
                builder: (_, msg, __) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(msg, textAlign: TextAlign.center,
                        style: TextStyle(color: _colors.textPrimary, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    void closeDialog() {
      if (_dialogOpen) {
        _dialogOpen = false;
        nav.pop();
      }
    }

    try {
      final existing = Set<String>.from(widget.canal.usersSuiviId ?? []);
      existing.add(authProvider.loginUserData.id ?? '');

      final toAdd = <String>[];
      const int pageSize = 500;
      DocumentSnapshot? lastDoc;

      outer:
      while (toAdd.length < count) {
        progressNotifier.value = 'Recherche des utilisateurs actifs… (${toAdd.length}/$count)';

        var query = firestore
            .collection('Users')
            .orderBy('abonnes', descending: true)
            .limit(pageSize);
        if (lastDoc != null) query = query.startAfterDocument(lastDoc);

        final snap = await query.get();
        if (snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          if (!existing.contains(doc.id)) {
            toAdd.add(doc.id);
            if (toAdd.length >= count) break outer;
          }
        }
        lastDoc = snap.docs.last;
        if (snap.docs.length < pageSize) break;
      }

      if (toAdd.isEmpty) {
        closeDialog();
        messenger.showSnackBar(const SnackBar(content: Text('Aucun nouvel utilisateur actif à ajouter.')));
        return;
      }

      const int batchSize = 500;
      int written = 0;
      for (int i = 0; i < toAdd.length; i += batchSize) {
        final chunk = toAdd.sublist(i, (i + batchSize).clamp(0, toAdd.length));
        progressNotifier.value = 'Écriture… ($written/${toAdd.length})';
        await firestore.collection('Canaux').doc(widget.canal.id).update({
          'usersSuiviId': FieldValue.arrayUnion(chunk),
          'suivi': FieldValue.increment(chunk.length),
        });
        written += chunk.length;
      }

      closeDialog();
      if (mounted) {
        setState(() {
          widget.canal.usersSuiviId ??= [];
          widget.canal.usersSuiviId!.addAll(toAdd);
          widget.canal.suivi = (widget.canal.suivi ?? 0) + toAdd.length;
        });
      }
      messenger.showSnackBar(SnackBar(content: Text('${toAdd.length} abonné(s) ajouté(s) avec succès ✅')));
    } catch (e) {
      closeDialog();
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
    progressNotifier.dispose();
  }

  Future<void> _deleteCanal() async {
    final myId = authProvider.loginUserData.id!;
    final isAppAdmin = authProvider.loginUserData.role == 'ADM' || authProvider.loginUserData.role == 'admin';
    final isOwner = myId == widget.canal.userId;
    if (!isOwner && !isAppAdmin) return;

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
            Text('Supprimer le canal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
          ]),
          content: Text(
            'Cette action est irréversible.\nTous les posts et abonnés seront supprimés définitivement.',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Continuer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;
    if (!step1 || !mounted) return;

    // Étape 2 : confirmation finale
    final canalName = widget.canal.titre ?? 'ce canal';
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: colors.surface,
          title: Text('Dernière confirmation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: colors.textPrimary)),
          content: Text('Supprimer définitivement le canal\n"$canalName" ?', style: TextStyle(color: colors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non, annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Oui, supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    ) ?? false;
    if (!step2 || !mounted) return;

    try {
      final canalId = widget.canal.id!;

      // Supprimer tous les posts du canal
      await _deleteBatchQuery(
        firestore.collection('Posts').where('canal_id', isEqualTo: canalId),
      );

      // Supprimer l'entrée CanalNames
      final namesSnap = await firestore
          .collection('CanalNames')
          .where('name', isEqualTo: widget.canal.titre)
          .limit(1)
          .get();
      for (final doc in namesSnap.docs) {
        await doc.reference.delete();
      }

      // Supprimer le document canal
      await firestore.collection('Canaux').doc(canalId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canal supprimé avec succès'), backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de la suppression'),
            backgroundColor: _colors.danger,
          ),
        );
      }
    }
  }

  Future<void> _deleteBatchQuery(Query<Map<String, dynamic>> query) async {
    const batchSize = 400;
    while (true) {
      final snap = await query.limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) break;
    }
  }

  Future<void> _handlePrivateCanalSubscription() async {
    final subscriptionPrice = widget.canal.subscriptionPrice ?? 0;
    final subType = widget.canal.subscriptionType;
    final isMensuel = subType == 'mensuel';
    final isAlreadySubscribed = widget.canal.usersSuiviId!.contains(authProvider.loginUserData.id);

    // Abonné unique déjà inscrit → accès maintenu
    if (isAlreadySubscribed && !isMensuel && !_requirePaymentForExistingSubscribers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Vous avez déjà accès à ce canal privé!',
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.primary,
        ),
      );
      return;
    }

    // Vérifier le solde de l'utilisateur
    final userDoc = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
    final currentBalance = (userDoc.data()?['votre_solde_principal'] ?? 0).toDouble();

    if (currentBalance < subscriptionPrice) {
      _showInsufficientBalanceDialog(userBalance: currentBalance, subscriptionPrice: subscriptionPrice);
      return;
    }

    // Libellés adaptés au type d'abonnement
    final String dialogTitle;
    final String confirmationMessage;
    if (_monthlySubscriptionExpired) {
      dialogTitle = 'Renouveler l\'abonnement';
      confirmationMessage = 'Votre abonnement mensuel a expiré.\n\n'
          'Renouvelez pour ${subscriptionPrice.toStringAsFixed(0)} FCFA/mois et continuez à accéder à ce canal.';
    } else if (isMensuel) {
      dialogTitle = 'Abonnement Mensuel';
      confirmationMessage = 'Ce canal est privé — abonnement mensuel à ${subscriptionPrice.toStringAsFixed(0)} FCFA/mois.\n\n'
          'L\'accès est valable 30 jours, puis renouvelable.';
    } else {
      dialogTitle = 'Abonnement Unique';
      confirmationMessage = 'Ce canal est privé. L\'accès à vie coûte ${subscriptionPrice.toStringAsFixed(0)} FCFA.\n\n'
          'Confirmez-vous l\'abonnement ?';
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
              child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
              child: Text(
                isMensuel ? 'S\'abonner — ${subscriptionPrice.toStringAsFixed(0)} FCFA/mois' : 'Confirmer',
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
      // Déduire le montant du solde utilisateur
      final bool deductionSuccess = await authProvider.deductFromBalance(context, price);

      if (!deductionSuccess) {
        throw Exception('Échec de la déduction du solde');
      }

      // Diviser le montant (70% créateur, 30% application)
      final double creatorShare = price * 0.7;
       double appShare = price * 0.3;

      // Créditer le créateur du canal
      await _creditCreator(creatorShare);
      if(authProvider.loginUserData!.codeParrain!=null){
         appShare = price * 0.25;
        authProvider.incrementAppGain(appShare);
        authProvider.ajouterCadeauCommissionParrain(codeParrainage: authProvider.loginUserData!.codeParrain!, montant: price);
        authProvider.ajouterCommissionParrainViaUserId(userId: widget.canal.userId!, montant: price);

      }else{
         appShare = price * 0.75;
        authProvider.incrementAppGain(appShare);
        authProvider.ajouterCommissionParrainViaUserId(userId: widget.canal.userId!, montant: price);

      }

      // // Créditer l'application
      // await authProvider.incrementAppGain(appShare);

      // Enregistrer les transactions
      await _recordTransactions(price, creatorShare, appShare, isAlreadySubscribed);

      // Pour abonnement mensuel : enregistrer la date d'expiration (+30 jours)
      if (widget.canal.subscriptionType == 'mensuel') {
        final expiresAt = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
        final userId = authProvider.loginUserData.id!;
        await firestore.collection('Canaux').doc(widget.canal.id).update({
          'monthlySubscriptions.$userId': expiresAt,
        });
        widget.canal.monthlySubscriptions ??= {};
        widget.canal.monthlySubscriptions![userId] = expiresAt;
        setState(() => _monthlySubscriptionExpired = false);
      }

      // Suivre le canal (ou maintenir l'abonnement)
      if (!isAlreadySubscribed) {
        await _followCanal();
      }

      final isMensuel = widget.canal.subscriptionType == 'mensuel';
      String successMessage = isMensuel
          ? '✅ Abonnement mensuel activé ! Accès valable 30 jours.'
          : isAlreadySubscribed && _requirePaymentForExistingSubscribers
              ? '✅ Paiement accepté! Vous conservez l\'accès au canal privé.'
              : '✅ Abonnement réussi! Canal privé ajouté.';

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
            '❌ Erreur lors de l\'abonnement',
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

  Future<void> _creditCreator(double amount) async {
    try {
      await firestore.collection('Users').doc(widget.canal.userId).update({
        'votre_solde_principal': FieldValue.increment(amount),
      });

      // Enregistrer la transaction pour le créateur
      await firestore.collection('TransactionSoldes').add({
        'user_id': widget.canal.userId!,
        'montant': amount,
        'type': TypeTransaction.GAIN.name,
        'description': 'Revenu abonnement canal ${widget.canal.id}',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
        'canal_id': widget.canal.id,
      });
    } catch (e) {
      printVm('Erreur crédit créateur: $e');
      throw e;
    }
  }

  Future<void> _recordTransactions(double totalAmount, double creatorShare, double appShare, bool isAlreadySubscribed) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String description = isAlreadySubscribed && _requirePaymentForExistingSubscribers
        ? 'Maintien accès canal privé devenu payant: ${widget.canal.titre}'
        : 'Abonnement canal privé: ${widget.canal.titre}';

    // Transaction pour l'utilisateur qui paye
    await firestore.collection('TransactionSoldes').add({
      'user_id': authProvider.loginUserData.id!,
      'montant': totalAmount,
      'type': TypeTransaction.DEPENSE.name,
      'description': description,
      'createdAt': timestamp,
      'statut': StatutTransaction.VALIDER.name,
      'canal_id': widget.canal.id,
      'is_existing_subscriber': isAlreadySubscribed,
    });

    // Transaction pour l'application
    await firestore.collection('AppTransactions').add({
      'montant': appShare,
      'type': 'GAIN_ABONNEMENT',
      'description': 'Commission $description',
      'user_id': authProvider.loginUserData.id!,
      'canal_id': widget.canal.id,
      'createdAt': timestamp,
      'is_existing_subscriber': isAlreadySubscribed,
    });
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

    // Ajouter l'utilisateur aux abonnés
    widget.canal.usersSuiviId!.add(userId);
    await firestore.collection('Canaux').doc(widget.canal.id).update({
      'usersSuiviId': widget.canal.usersSuiviId,
    });
    // Dénormalisation : stocker l'ID du canal dans le doc User pour un accès O(1)
    // (permet d'éviter la requête Canaux.where(arrayContains) aux prochaines sessions)
    firestore.collection('Users').doc(userId).update({
      'canauxSuivisIds': FieldValue.arrayUnion([widget.canal.id]),
    }).catchError((_) {});
    addPointsForAction(UserAction.abonne);
    addPointsForOtherUserAction(widget.canal.userId!, UserAction.autre);

    // Créer la notification
    final NotificationData notif = NotificationData(
      id: firestore.collection('Notifications').doc().id,
      titre: "Canal 📺",
      media_url: authProvider.loginUserData.imageUrl,
      type: NotificationType.ACCEPTINVITATION.name,
      description: "@${authProvider.loginUserData.pseudo!} suit votre canal #${widget.canal.titre!} 📺!",
      users_id_view: [],
      user_id: userId,
      receiver_id: widget.canal.userId!,
      post_id: "",
      post_data_type: "",
      updatedAt: DateTime.now().microsecondsSinceEpoch,
      createdAt: DateTime.now().microsecondsSinceEpoch,
      status: PostStatus.VALIDE.name,
    );

    await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

    // Envoyer notification push
    if (widget.canal.user != null && widget.canal.user!.oneIgnalUserid != null) {
      await authProvider.sendNotification(
        userIds: [widget.canal.user!.oneIgnalUserid!],
        smallImage: widget.canal.urlImage!,
        send_user_id: userId,
        recever_user_id: widget.canal.userId!,
        message: "📢📺 @${authProvider.loginUserData.pseudo!} suit votre canal #${widget.canal.titre!} 📺!",
        type_notif: NotificationType.ACCEPTINVITATION.name,
        post_id: "",
        post_type: "",
        chat_id: "",
      );
    }

    setState(() {
      isFollowing = true;
    });
  }

  void _showInsufficientBalanceDialog({
    required double userBalance,
    required double subscriptionPrice,
  }) {
    final double missingAmount = (subscriptionPrice - userBalance).clamp(0, double.infinity);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final colors = AppColors.of(context);
        final l10n = AppLocalizations.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: colors.background,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [colors.background, colors.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: colors.onAccent, size: 40),
                ),
                const SizedBox(height: 16),

                Text(
                  l10n.canalInsufficientBalance,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Votre solde actuel est de ${userBalance.toStringAsFixed(0)} FCFA.\n'
                      'Il vous manque ${missingAmount.toStringAsFixed(0)} FCFA pour vous abonner '
                      'à ce canal privé coûtant ${subscriptionPrice.toStringAsFixed(0)} FCFA.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, height: 1.5, fontSize: 15),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        l10n.canalLater,
                        style: TextStyle(color: colors.accent, fontWeight: FontWeight.w500),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen(defaultAmount: missingAmount)));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        elevation: 3,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: colors.onPrimary),
                          const SizedBox(width: 8),
                          Text(
                            l10n.canalRecharge,
                            style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
                showImageDetailsModalDialog(widget.canal.urlCouverture!,
                    MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height,
                    context
                );
              },
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: widget.canal.urlCouverture != null
                        ? NetworkImage(widget.canal.urlCouverture!)
                        : AssetImage('assets/default_cover.png') as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
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
              ),
            ),

            // Avatar du canal
            Positioned(
              bottom: 10,
              left: 16,
              child: GestureDetector(
                onTap: () {
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
                      child: CircleAvatar(
                        radius: 45,
                        backgroundImage: widget.canal.urlImage != null
                            ? NetworkImage(widget.canal.urlImage!)
                            : AssetImage('assets/default_profile.png') as ImageProvider,
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
    final subscribersCount = widget.canal.usersSuiviId?.length ?? 0;
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
                            child: Text(
                              "#${widget.canal.titre!}",
                              style: TextStyle(
                                color: _colors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                              value: '${widget.canal.subscriptionPrice?.toStringAsFixed(0) ?? '0'}',
                              label: 'FCFA',
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
                // Bouton Follow/Unfollow (non-propriétaire uniquement)
                if (!isOwner)
                  Expanded(
                    child: SizedBox(
                      height: 45,
                      child: ElevatedButton(
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
                                isFollowing
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
                        case 'remplir_abonnes':
                          _fillSubscribersWithActiveUsers();
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
                          Text('Modifier', style: TextStyle(color: _colors.textPrimary)),
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
                          Text('Booster ce canal', style: TextStyle(color: _colors.textPrimary)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'remplir_abonnes',
                        child: Row(children: [
                          Icon(Icons.group_add, size: 18, color: _colors.primary),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Remplir les abonnés', style: TextStyle(color: _colors.textPrimary))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _colors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Admin', style: TextStyle(color: _colors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'supprimer',
                        child: Row(children: [
                          const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                          const SizedBox(width: 10),
                          const Text('Supprimer le canal', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),

                // Menu 3-points — admin plateforme (non-propriétaire)
                if (!isOwner &&
                    (authProvider.loginUserData.role == 'ADM' ||
                        authProvider.loginUserData.role == 'admin'))
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: _colors.textPrimary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'supprimer') _deleteCanal();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'supprimer',
                        child: Row(children: [
                          Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Supprimer le canal', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),
              ],
            ),

            // Bouton POSTER (propriétaire ou admin canal)
            if (isOwner || widget.canal.adminIds?.contains(authProvider.loginUserData.id) == true) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CanalPostForm(canal: widget.canal)),
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
              GestureDetector(
                onTap: () {
                  if (widget.canal.userId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserManagementPage(userId: widget.canal.userId!),
                      ),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        'Admin — Propriétaire : ',
                        style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      if (widget.canal.user?.imageUrl != null) ...[
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: NetworkImage(widget.canal.user!.imageUrl!),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          widget.canal.user?.pseudo ?? widget.canal.userId ?? 'Inconnu',
                          style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.orange, size: 18),
                    ],
                  ),
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
                                _descriptionExpanded ? 'Voir moins' : 'Voir plus',
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
                Icon(Icons.dynamic_feed, color: _colors.accent, size: 24),
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
    final label = score >= 50 ? 'Canal populaire' : score >= 15 ? 'Canal actif' : 'Canal';
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
          '$label · ${score.toStringAsFixed(1)} pts',
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
                      'Erreur de chargement',
                      style: TextStyle(color: _colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
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
                      'Aucune publication',
                      style: TextStyle(color: _colors.textSecondary, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Soyez le premier à publier dans ce canal!',
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
                if (index == posts.length) {
                  return _buildLoadMoreIndicator();
                }

                final post = posts[index];
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: HomePostUsersWidget(
                    post: post,
                    color: _colors.primary,
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                  ),
                );
              },
              childCount: posts.length + (_isLoadingMorePosts ? 1 : 0),
            ),
          );
        }

        return SliverToBoxAdapter(
          child: SizedBox.shrink(),
        );
      },
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
          'Charger plus...',
          style: TextStyle(color: _colors.textSecondary),
        )
            : Container(
          padding: EdgeInsets.all(16),
          child: Text(
            '🎉 Vous avez vu toutes les publications!',
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
        title: Text(
          '#${widget.canal.titre ?? ''}',
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _colors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _colors.primary),
            onPressed: _loadInitialPosts,
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildHeaderSection(),
          _buildInfoSection(),
          _buildPostsSection(),
        ],
      ),
    );
  }
}

