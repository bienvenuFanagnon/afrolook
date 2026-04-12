import 'dart:async';
import 'dart:math';

import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/services/api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../constant/constColors.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../auth/authTest/constants.dart';
import '../../pub/native_ad_widget.dart';
import '../detailsOtherUser.dart';

class MesInvitationsPage extends StatefulWidget {
  final BuildContext context;
  const MesInvitationsPage({super.key, required this.context});

  @override
  State<MesInvitationsPage> createState() => _MesInvitationsState();
}

class _MesInvitationsState extends State<MesInvitationsPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late UserAuthProvider authProvider;
  late UserProvider userProvider;

  // Controllers
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // États de pagination
  List<Invitation> _invitations = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 10; // Pagination par 10

  // États de traitement
  final Set<String> _processingInvitations = {};
  final Map<String, bool> _acceptingState = {};
  final Map<String, bool> _refusingState = {};

  // États de chargement initial
  bool _isInitialLoading = true;
  String? _errorMessage;

  String formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(widget.context, listen: false);
    userProvider = Provider.of<UserProvider>(widget.context, listen: false);

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    _loadInitialInvitations();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final threshold = _scrollController.position.maxScrollExtent - 300;
    if (_scrollController.position.pixels >= threshold &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreInvitations();
    }
  }

  Future<void> _loadInitialInvitations() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
      _invitations.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    await _loadMoreInvitations(reset: true);
  }

  Future<void> _loadMoreInvitations({bool reset = false}) async {
    if (_isLoadingMore || (!_hasMore && !reset)) return;

    setState(() {
      _isLoadingMore = true;
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // Construire la requête
      Query query = firestore
          .collection('Invitations')
          .where('receiver_id', isEqualTo: authProvider.loginUserData.id!)
          .where('status', isEqualTo: InvitationStatus.ENCOURS.name)
          .orderBy('created_at', descending: true)
          .limit(_pageSize);

      if (!reset && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
          _isLoading = false;
          _isInitialLoading = false;
        });
        return;
      }

      // Récupérer les données des utilisateurs pour chaque invitation
      final List<Invitation> newInvitations = [];

      for (var doc in snapshot.docs) {
        try {
          final invitation = Invitation.fromJson(doc.data() as Map<String, dynamic>);

          // Récupérer les infos de l'utilisateur qui a envoyé l'invitation
          final userSnapshot = await firestore
              .collection('Users')
              .where('id', isEqualTo: invitation.senderId)
              .limit(1)
              .get();

          if (userSnapshot.docs.isNotEmpty) {
            invitation.inviteUser = UserData.fromJson(
              userSnapshot.docs.first.data() as Map<String, dynamic>,
            );
            newInvitations.add(invitation);
          }
        } catch (e) {
          print('Erreur chargement invitation: $e');
        }
      }

      setState(() {
        if (reset) {
          _invitations = newInvitations;
        } else {
          _invitations.addAll(newInvitations);
        }
        _lastDocument = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoadingMore = false;
        _isLoading = false;
        _isInitialLoading = false;
      });

      // Mettre à jour le compteur
      userProvider.countInvitations = _invitations.length;

    } catch (e) {
      print('Erreur chargement invitations: $e');
      setState(() {
        _errorMessage = 'Impossible de charger vos invitations';
        _isLoadingMore = false;
        _isLoading = false;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _refreshInvitations() async {
    setState(() {
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadInitialInvitations();
  }

  Future<void> _acceptInvitation(Invitation invitation) async {
    final invitationId = invitation.id!;

    if (_processingInvitations.contains(invitationId)) return;

    setState(() {
      _processingInvitations.add(invitationId);
      _acceptingState[invitationId] = true;
    });

    try {
      final result = await userProvider.acceptInvitation(invitation);

      if (result && mounted) {
        // Mise à jour locale
        authProvider.loginUserData.friendsIds ??= [];
        authProvider.loginUserData.friendsIds!.add(invitation.inviteUser!.id!);

        // Sauvegarde
        await userProvider.updateUser(authProvider.loginUserData);

        // Notification
        if (invitation.inviteUser!.oneIgnalUserid?.isNotEmpty ?? false) {
          await authProvider.sendNotification(
            userIds: [invitation.inviteUser!.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: invitation.inviteUser!.id!,
            message: "✅ @${authProvider.loginUserData.pseudo!} a accepté votre invitation !",
            type_notif: NotificationType.ACCEPTINVITATION.name,
            post_id: "",
            post_type: "",
            chat_id: '',
          );
        }

        // Notification dans Firestore
        final firestore = FirebaseFirestore.instance;
        final notif = NotificationData(
          id: firestore.collection('Notifications').doc().id,
          titre: "Invitation acceptée ✅",
          media_url: authProvider.loginUserData.imageUrl,
          type: NotificationType.ACCEPTINVITATION.name,
          description: "@${authProvider.loginUserData.pseudo!} a accepté votre invitation !",
          users_id_view: [],
          user_id: authProvider.loginUserData.id,
          receiver_id: invitation.inviteUser!.id!,
          post_id: "",
          post_data_type: "",
          updatedAt: DateTime.now().microsecondsSinceEpoch,
          createdAt: DateTime.now().microsecondsSinceEpoch,
          status: PostStatus.VALIDE.name,
        );

        await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

        // Retirer l'invitation de la liste
        setState(() {
          _invitations.removeWhere((inv) => inv.id == invitationId);
          userProvider.countInvitations = _invitations.length;
        });

        if (mounted) {
          _showSuccessSnackBar('✅ Invitation acceptée !');
        }

        await userProvider.getUsersProfile(authProvider.loginUserData.id!, context);
      } else if (mounted) {
        _showErrorSnackBar('❌ Erreur lors de l\'acceptation');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('❌ Une erreur est survenue');
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingInvitations.remove(invitationId);
          _acceptingState.remove(invitationId);
        });
      }
    }
  }

  Future<void> _refuseInvitation(Invitation invitation) async {
    final invitationId = invitation.id!;

    if (_processingInvitations.contains(invitationId)) return;

    setState(() {
      _processingInvitations.add(invitationId);
      _refusingState[invitationId] = true;
    });

    try {
      final result = await userProvider.refuserInvitation(invitation);

      if (result && mounted) {
        // Retirer l'invitation de la liste
        setState(() {
          _invitations.removeWhere((inv) => inv.id == invitationId);
          userProvider.countInvitations = _invitations.length;
        });

        _showSuccessSnackBar(' Invitation refusée', isSuccess: false);
        await userProvider.getUsersProfile(authProvider.loginUserData.id!, context);
      } else if (mounted) {
        _showErrorSnackBar('❌ Erreur lors du refus');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('❌ Une erreur est survenue');
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingInvitations.remove(invitationId);
          _refusingState.remove(invitationId);
        });
      }
    }
  }

  void _showSuccessSnackBar(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.info,
              color: isSuccess ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? Colors.green.shade900 : Colors.orange.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildInvitationCard(Invitation invitation) {
    final user = invitation.inviteUser!;
    final invitationId = invitation.id!;
    final isAccepting = _acceptingState[invitationId] ?? false;
    final isRefusing = _refusingState[invitationId] ?? false;
    final isProcessing = isAccepting || isRefusing;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[900]!,
              Colors.grey[850]!,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
          border: Border.all(
            color: Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!isProcessing) {
                showUserDetailsModalDialog(
                    user,
                    MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height,
                    context
                );
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar avec badge
                  Stack(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: user.isVerify!
                                ? Colors.green
                                : const Color(0xFFFFD700),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (user.isVerify!
                                  ? Colors.green
                                  : const Color(0xFFFFD700)
                              ).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.imageUrl ?? '',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFFD700),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: Icon(
                                Icons.person,
                                color: Colors.grey[600],
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (user.isVerify!)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Informations utilisateur
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '@${user.pseudo?.toLowerCase() ?? "utilisateur"}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildStatChip(
                              Icons.people,
                              formatNumber(user.userAbonnesIds?.length ?? 0),
                              Colors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Badge "En attente"
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                color: Colors.orange,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'En attente',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Boutons d'action
                  Column(
                    children: [
                      // Bouton Accepter
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: TextButton(
                          onPressed: isProcessing
                              ? null
                              : () => _acceptInvitation(invitation),
                          style: TextButton.styleFrom(
                            backgroundColor: isAccepting
                                ? Colors.green.withOpacity(0.2)
                                : Colors.green.withOpacity(0.1),
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isAccepting
                                    ? Colors.green
                                    : Colors.green.withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: isAccepting
                              ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.green,
                              strokeWidth: 2,
                            ),
                          )
                              : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Accepter',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Bouton Refuser
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: TextButton(
                          onPressed: isProcessing
                              ? null
                              : () => _refuseInvitation(invitation),
                          style: TextButton.styleFrom(
                            backgroundColor: isRefusing
                                ? Colors.red.withOpacity(0.2)
                                : Colors.red.withOpacity(0.1),
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isRefusing
                                    ? Colors.red
                                    : Colors.red.withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: isRefusing
                              ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.red,
                              strokeWidth: 2,
                            ),
                          )
                              : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Refuser',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdBanner({required String key}) {
    return Container(
      key: ValueKey(key),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[900]!,
            Colors.grey[850]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: MrecAdWidget(
          // templateType: TemplateType.small,
          onAdLoaded: () {
            print('✅ Native Ad chargée dans invitations: $key');
          },
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  color: Colors.grey[800],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 12,
                  color: Colors.grey[800],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 20,
                  color: Colors.grey[800],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 70,
                height: 30,
                color: Colors.grey[800],
              ),
              const SizedBox(height: 8),
              Container(
                width: 70,
                height: 30,
                color: Colors.grey[800],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Color(0xFFFFD700),
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Invitations',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Stack(
              children: [
                const Icon(
                  Icons.notifications_none,
                  color: Color(0xFFFFD700),
                  size: 20,
                ),
                if (_invitations.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_invitations.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshInvitations,
        color: const Color(0xFFFFD700),
        backgroundColor: Colors.grey[900],
        child: _isInitialLoading
            ? ListView.builder(
          padding: const EdgeInsets.only(top: 16),
          itemCount: 3,
          itemBuilder: (context, index) => _buildShimmerCard(),
        )
            : _errorMessage != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 50,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Erreur de chargement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInitialInvitations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        )
            : _invitations.isEmpty
            ? CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildAdBanner(key: 'invitations_empty_ad'),
            ),
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.mail_outline,
                        color: Color(0xFFFFD700),
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Aucune invitation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vous n\'avez pas d\'invitation en attente',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
            : CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildAdBanner(key: 'invitations_list_top_ad'),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    if (index >= _invitations.length) {
                      if (_isLoadingMore) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: LoadingAnimationWidget.flickr(
                              size: 30,
                              leftDotColor: const Color(0xFFFFD700),
                              rightDotColor: const Color(0xFF8B0000),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    final invitation = _invitations[index];
                    return Column(
                      children: [
                        _buildInvitationCard(invitation),
                        if (index == 2) // Pub au milieu de la liste
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: _buildAdBanner(key: 'invitations_middle_ad'),
                          ),
                        if (index == _invitations.length - 1 && _hasMore)
                          const SizedBox(height: 8),
                      ],
                    );
                  },
                  childCount: _invitations.length + (_isLoadingMore ? 1 : 0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}