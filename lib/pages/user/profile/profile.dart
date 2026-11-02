import 'package:afrotok/services/read_meter.dart';
import 'package:afrotok/widgets/pseudo_tag.dart';
import 'package:afrotok/widgets/user_badge_widget.dart';
import 'package:afrotok/services/followers_count_service.dart';
import 'package:afrotok/utils/count_format.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/utils/platform_guard.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import '../../../constant/logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../theme/app_colors.dart';
import '../../admin/admin_dashboard_page.dart';
import '../../admin/team/team_admin_page.dart';
import '../../team/team_hub_page.dart';
import '../official_account/request_official_account_page.dart';
import '../../../models/official_account/official_account_enums.dart';
import '../../../models/official_account/official_account_request.dart';
import '../../../services/official_account/official_account_service.dart';
import '../../canaux/listCanauxByUser.dart';
import '../../contenuPayant/profileScreenContent.dart';
import '../../userPosts/favorites_posts.dart';
import '../otherUser/otherUser.dart';
import '../monetisation.dart';
import '../../stickers/sticker_studio_page.dart';
import '../userAbonnementPage.dart';
import '../userPubs/user_my_advertisements_page.dart';
import '../userPubs/user_profile_boost_page.dart';
import 'adminprofil.dart';
import '../account_deletion_page.dart';
import '../../../l10n/tr.dart';
import '../../studio/artist_marketplace.dart';
import '../../../services/currency_service.dart';
import '../currency_picker_page.dart';
class UserProfil extends StatefulWidget {
  const UserProfil({super.key});

  @override
  State<UserProfil> createState() => _UserProfilState();
}

class _UserProfilState extends State<UserProfil> {
  late AppColors _colors;

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  /// Demande de compte officiel en cours.
  OfficialAccountRequest? _officialRequest;
  bool _officialRequestLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOfficialRequest());
  }

  Future<bool> _checkTeamMember(String uid) async {
    if (uid.isEmpty) return false;
    try {
      return (await UsersApi.capabilities())['is_staff'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadOfficialRequest() async {
    try {
      final myId = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
      if (myId == null) return;
      final req = await OfficialAccountService.instance.getMyRequest(myId);
      if (mounted) setState(() { _officialRequest = req; _officialRequestLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _officialRequestLoaded = true);
    }
  }

  String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return "${(number / 1000).toStringAsFixed(1)}k";
    } else if (number < 1000000000) {
      return "${(number / 1000000).toStringAsFixed(1)}M";
    } else {
      return "${(number / 1000000000).toStringAsFixed(1)}B";
    }
  }

  // ── Design : un seul style de tuile (grille 3 colonnes) et un seul style de ligne ; une seule couleur d'accent (le vert de l'application), pas de dégradés ──

  /// Tuile de la grille : même taille partout, icône dans une pastille de la couleur d'accent, libellé sur 2 lignes au plus.
  Widget _tile({required double width, required IconData icon, required String label, required VoidCallback onTap}) {
    final c = _colors;
    return SizedBox(
      width: width,
      height: 88,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: c.primary.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: c.primary, size: 19),
                ),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ligne pleine largeur : même hauteur et même style pour tout (compte officiel, outils, administration).
  Widget _row({required IconData icon, required String label, String? subtitle, VoidCallback? onTap, Color? tone, String? chip, bool chevron = true}) {
    final c = _colors;
    final color = tone ?? c.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  if (subtitle != null) Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3)),
                ]),
              ),
              if (chip != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                  child: Text(chip, style: TextStyle(color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
              if (chevron && onTap != null) Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 22),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8, left: 2),
        child: Text(t, style: TextStyle(color: _colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      );

  Widget _stat(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _colors.textPrimary)),
          Text(label, style: TextStyle(fontSize: 11.5, color: _colors.textSecondary)),
        ],
      );

  /// Entreprise : ouvre la page de l'entreprise, ou propose d'en créer une.
  Future<void> _openEnterprise(AppLocalizations l10n) async {
    final c = _colors;
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: c.background, body: Center(child: CircularProgressIndicator(color: c.primary)))));
    try {
      final value = await userProvider.getUserEntreprise(authProvider.loginUserData.id!);
      if (!mounted) return;
      Navigator.pop(context);
      if (value) {
        Navigator.pushNamed(context, '/profile_entreprise');
      } else {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(radius: 30, backgroundColor: c.primary.withOpacity(0.12), child: Icon(Icons.store, color: c.primary, size: 30)),
                const SizedBox(height: 12),
                Text(l10n.profileEnterpriseCreateTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                const SizedBox(height: 8),
                Text(l10n.profileEnterpriseCreateDesc, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.textSecondary)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: c.primary, minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/new_entreprise');
                    },
                    child: Text(l10n.profileEnterpriseCreateBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileEnterpriseLoadError), backgroundColor: c.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final c = _colors;
    final l10n = AppLocalizations.of(context);
    final me = authProvider.loginUserData;
    final isAdmin = me.role == UserRole.ADM.name;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(l10n.profileTitle, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: c.textPrimary)),
        actions: [
          // Réglages du compte : suppression accessible depuis le profil (exigence App Store 5.1.1(v))
          PopupMenuButton<String>(
            icon: Icon(Icons.settings_rounded, color: c.textPrimary),
            tooltip: context.tr('Paramètres'),
            onSelected: (v) {
              if (v == 'delete') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountDeletionPage()));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_forever_rounded, color: c.danger),
                  const SizedBox(width: 10),
                  Text(context.tr('Supprimer mon compte'), style: TextStyle(color: c.danger)),
                ]),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14.0, left: 2),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
              child: Logo(),
            ),
          ),
        ],
      ),
      body: CenteredContent(
        maxWidth: AppLayout.isDesktop(context) ? 800 : AppLayout.maxFeedWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête : photo, pseudo, chiffres ; toucher = mes informations ──
              Material(
                color: c.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.pushNamed(context, '/profil_detail_user'),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Stack(children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.primary, width: 2)),
                          child: CircleAvatar(onBackgroundImageError: (_, __) {}, radius: 32, backgroundImage: NetworkImage('${me.imageUrl!}'), backgroundColor: c.surfaceVariant),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                            child: const Icon(Icons.edit, size: 11, color: Colors.white),
                          ),
                        ),
                      ]),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: PseudoTag(label: '@${me.pseudo}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 5),
                            UserBadgeWidget(user: me, size: 17),   // badge de l'abonnement / certification
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            FollowersCountBuilder(
                              userId: me.id,
                              fallback: me.followersCount,
                              builder: (_, n) => _stat(formatCompactCount(n), l10n.profileFollowers),
                            ),
                            Container(height: 28, width: 1, margin: const EdgeInsets.symmetric(horizontal: 18), color: c.divider),
                            _stat(formatNumber(me.userlikes ?? 0), l10n.profileLikesShort),
                          ]),
                        ]),
                      ),
                      Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _row(icon: Icons.style, label: l10n.profileMyLooks, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserPage(otherUser: me)))),

              // ── Mon espace : grille de 3 colonnes, toutes les tuiles identiques ──
              _sectionTitle(context.tr('Mon espace')),
              LayoutBuilder(builder: (context, box) {
                final w = (box.maxWidth - 20) / 3;
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  _tile(width: w, icon: Icons.person, label: l10n.profileMenuMyInfos, onTap: () => Navigator.pushNamed(context, '/profil_detail_user')),
                  _tile(width: w, icon: Icons.account_balance_wallet_rounded, label: context.tr('Mon portefeuille'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MonetisationPage()))),
                  _tile(width: w, icon: Icons.card_membership, label: l10n.profileMenuSubscription, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AbonnementScreen()))),
                  _tile(width: w, icon: Icons.bookmark_border, label: l10n.profileMenuFavorites, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritePostsPage()))),
                  _tile(width: w, icon: FontAwesome.forumbee, label: l10n.profileMenuChannels, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanalListPageByUser()))),
                  _tile(width: w, icon: Icons.store, label: l10n.profileMenuEnterprise, onTap: () => _openEnterprise(l10n)),
                  _tile(width: w, icon: Icons.public, label: l10n.profileMenuAds, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserMyAdvertisementsPage()))),
                  _tile(width: w, icon: Icons.rocket_launch_outlined, label: context.tr('Booster mon profil'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileBoostPage()))),
                  if (me.isCreatorProfileEnabled == true && !kIsAppleStore)
                    _tile(width: w, icon: Icons.storefront_rounded, label: context.tr('Mon Business'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreenContenu(userId: me.id)))),
                  _tile(width: w, icon: Icons.emoji_emotions_outlined, label: context.tr('Studio stickers'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StickerStudioPage()))),
                ]);
              }),

              // ── Compte et outils ──
              _sectionTitle(context.tr('Compte et outils')),
              if (_officialRequestLoaded) (me.isOfficialAccount ? _buildOfficialBadge(me) : _buildOfficialAccountButton(_officialRequest)),
              _row(icon: Icons.mic_rounded, label: context.tr('Espace artiste : mes sons et mes gains'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyArtistSoundsPage()))),
              Consumer<CurrencyService>(
                builder: (context, cur, _) => _row(
                  icon: Icons.currency_exchange_rounded,
                  label: context.tr('Devise d\'affichage'),
                  subtitle: '${cur.currency}${cur.override == null ? ' (${context.tr('auto')})' : ''}',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CurrencyPickerPage())),
                ),
              ),

              // ── Équipe ──
              if (isAdmin) ...[
                _sectionTitle(context.tr('Équipe')),
                _row(icon: Icons.admin_panel_settings_rounded, label: context.tr('Tableau de bord admin'), chip: 'ADMIN', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage()))),
                _row(icon: Icons.group_outlined, label: context.tr('Gestion d\'équipe'), chip: 'ADMIN', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamAdminPage()))),
              ] else
                FutureBuilder<bool>(
                  future: _checkTeamMember(me.id ?? ''),
                  builder: (ctx, snap) {
                    if (snap.data != true) return const SizedBox.shrink();
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionTitle(context.tr('Équipe')),
                      _row(icon: Icons.dashboard_rounded, label: context.tr('Hub Équipe'), chip: context.tr('ÉQUIPE'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamHubPage()))),
                    ]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compte officiel : une ligne selon l'état de la demande (demander, en cours, à compléter, refusée, suspendue).
  Widget _buildOfficialAccountButton(OfficialAccountRequest? req) {
    final c = _colors;
    void openRequest([OfficialAccountRequest? existing]) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => existing == null ? const RequestOfficialAccountPage() : RequestOfficialAccountPage(existingRequest: existing)),
        ).then((_) => _loadOfficialRequest());

    if (req == null) {
      return _row(icon: Icons.verified_rounded, label: context.tr('Demander un compte officiel'), onTap: () => openRequest());
    }
    // Informations complémentaires demandées : message de l'équipe + bouton pour mettre à jour la demande
    if (req.status == OfficialAccountStatus.moreInfoNeeded) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.warning.withOpacity(0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.warning.withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, color: c.warning, size: 19),
            const SizedBox(width: 8),
            Expanded(child: Text(context.tr('Informations complémentaires requises'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            if (req.adminNote?.isNotEmpty == true) ...[
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40), side: BorderSide(color: c.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => _showAdminNoteDialog(context, req.adminNote!),
                icon: Icon(Icons.message_outlined, size: 16, color: c.textPrimary),
                label: Text(context.tr('Message'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              )),
              const SizedBox(width: 8),
            ],
            Expanded(child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c.primary, minimumSize: const Size.fromHeight(40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => openRequest(req),
              icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
              label: Text(context.tr('Mettre à jour'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            )),
          ]),
        ]),
      );
    }
    return switch (req.status) {
      OfficialAccountStatus.pending => _row(icon: Icons.hourglass_top_rounded, label: context.tr('Compte officiel'), subtitle: context.tr('Demande en cours d\'examen...'), tone: c.textSecondary, chevron: false),
      OfficialAccountStatus.underReview => _row(icon: Icons.manage_search_rounded, label: context.tr('Compte officiel'), subtitle: context.tr('En cours d\'analyse par l\'équipe'), tone: c.info, chevron: false),
      OfficialAccountStatus.rejected => _row(icon: Icons.refresh_rounded, label: context.tr('Renouveler ma demande'), subtitle: context.tr('Compte officiel'), onTap: () => openRequest()),
      OfficialAccountStatus.suspended => _row(icon: Icons.block_rounded, label: context.tr('Compte officiel'), subtitle: context.tr('Compte officiel suspendu'), tone: c.danger, chevron: false),
      _ => const SizedBox.shrink(),
    };
  }

  void _showAdminNoteDialog(BuildContext context, String note) {
    final c = _colors;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: c.warning.withOpacity(0.14), shape: BoxShape.circle), child: Icon(Icons.info_rounded, color: c.warning, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr('Message de l\'administrateur'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15))),
            ]),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
              child: Text(note, style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.55)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: c.primary, minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(context.tr('Fermer'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildOfficialBadge(UserData me) {
    return _row(
      icon: Icons.verified_rounded,
      label: me.officialName?.isNotEmpty == true ? me.officialName! : context.tr('Compte officiel vérifié'),
      subtitle: context.tr('Compte officiel'),
      chevron: false,
    );
  }
}
