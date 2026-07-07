import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/model_data.dart' show NotificationType;
import '../../models/official_account/official_account_enums.dart';
import '../../models/official_account/official_account_request.dart';
import '../../providers/authProvider.dart';
import '../../services/official_account/official_account_service.dart';
import '../../theme/app_colors.dart';

class OfficialAccountsPage extends StatefulWidget {
  const OfficialAccountsPage({super.key});

  @override
  State<OfficialAccountsPage> createState() => _OfficialAccountsPageState();
}

class _OfficialAccountsPageState extends State<OfficialAccountsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  OfficialAccountCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: OfficialAccountStatus.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text('Comptes officiels',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: colors.textPrimary),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: colors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: OfficialAccountStatus.values
              .map((s) => Tab(text: s.label))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: OfficialAccountStatus.values
            .map((s) => _RequestList(status: s, category: _filterCategory))
            .toList(),
      ),
    );
  }

  void _showFilterSheet() {
    final colors = AppColors.of(context);
    showResponsiveBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filtrer par catégorie',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                      label: 'Toutes',
                      selected: _filterCategory == null,
                      colors: colors,
                      onTap: () { setState(() => _filterCategory = null); Navigator.pop(context); }),
                  ...OfficialAccountCategory.values.map((c) => _FilterChip(
                      label: '${c.emoji} ${c.label}',
                      selected: _filterCategory == c,
                      colors: colors,
                      onTap: () { setState(() => _filterCategory = c); Navigator.pop(context); })),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }),
    );
  }
}

// ── Liste des demandes par statut ────────────────────────────────────────────

class _RequestList extends StatelessWidget {
  final OfficialAccountStatus status;
  final OfficialAccountCategory? category;

  const _RequestList({required this.status, required this.category});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return StreamBuilder<List<OfficialAccountRequest>>(
      stream: OfficialAccountService.instance.watchFiltered(
          status: status, category: category),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 48, color: colors.textSecondary.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text('Aucune demande', style: TextStyle(color: colors.textSecondary)),
              ],
            ),
          );
        }
        return CenteredContent(child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _RequestCard(request: requests[i]),
        ));
      },
    );
  }
}

// ── Card demande ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final OfficialAccountRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cat = request.category;
    final statusColor = Color(request.status.color);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _RequestDetailPage(request: request)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colors.surfaceVariant,
                    backgroundImage: request.imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(request.imageUrl)
                        : null,
                    child: request.imageUrl.isEmpty
                        ? Text(cat.emoji, style: const TextStyle(fontSize: 20))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@${request.pseudo}',
                            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(request.officialName,
                            style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(request.status.label,
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(
                            DateTime.fromMillisecondsSinceEpoch(request.createdAt)),
                        style: TextStyle(color: colors.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Catégorie + domaines
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Chip(label: '${cat.emoji} ${cat.label}', colors: colors, color: colors.primary),
                  ...request.broadcastDomains.take(3).map(
                      (d) => _Chip(label: d.label, colors: colors)),
                  if (request.broadcastDomains.length > 3)
                    _Chip(label: '+${request.broadcastDomains.length - 3}', colors: colors),
                ],
              ),
            ),

            // Note admin si présente
            if (request.adminNote?.isNotEmpty == true)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.comment_rounded, size: 14, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(request.adminNote!,
                          style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Page de détail et actions admin ─────────────────────────────────────────

class _RequestDetailPage extends StatelessWidget {
  final OfficialAccountRequest request;

  const _RequestDetailPage({required this.request});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cat = request.category;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text('Demande de ${request.pseudo}',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profil
          _Section(
            title: 'Demandeur',
            colors: colors,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.surfaceVariant,
                  backgroundImage: request.imageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(request.imageUrl)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@${request.pseudo}',
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
                      Text(request.officialName,
                          style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                      Text('${cat.emoji} ${cat.label}',
                          style: TextStyle(color: colors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(request.status.color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(request.status.label,
                      style: TextStyle(color: Color(request.status.color), fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ],
            ),
          ),

          // Informations générales
          _Section(
            title: 'Informations',
            colors: colors,
            child: Column(
              children: [
                _InfoRow('Description', request.description, colors),
                _InfoRow('Pays', request.country, colors),
                _InfoRow('Ville', request.city, colors),
                _InfoRow('Téléphone', request.phone, colors),
                _InfoRow('Email', request.email, colors),
                if (request.website.isNotEmpty) _InfoRow('Site web', request.website, colors),
              ],
            ),
          ),

          // Domaines
          _Section(
            title: 'Domaines de diffusion',
            colors: colors,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: request.broadcastDomains
                  .map((d) => _Chip(label: d.label, colors: colors))
                  .toList(),
            ),
          ),

          // Réseaux sociaux
          if (request.socialNetworks.isNotEmpty)
            _Section(
              title: 'Réseaux sociaux',
              colors: colors,
              child: Column(
                children: request.socialNetworks
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    s.type.label.substring(0, 1),
                                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.type.label,
                                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                    Text(s.link,
                                        style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (s.followers > 0)
                                Text(_fmtNum(s.followers),
                                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

          // Identité
          if (cat.requiresIdVerification && request.birthDate != null)
            _Section(
              title: 'Vérification d\'identité',
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow('Date de naissance', request.birthDate!, colors),
                  if (request.idDocumentType != null)
                    _InfoRow('Type de pièce', request.idDocumentType!.label, colors),
                  if (request.idNumber != null)
                    _InfoRow('Numéro', request.idNumber!, colors),
                  if (request.idDocumentUrl != null) ...[
                    const SizedBox(height: 12),
                    _IdDocumentViewer(url: request.idDocumentUrl!, colors: colors),
                  ],
                ],
              ),
            ),

          // Monétisation
          _Section(
            title: 'Monétisation',
            colors: colors,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cat.canMonetize
                    ? Colors.green.withOpacity(0.08)
                    : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    cat.canMonetize ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: cat.canMonetize ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cat.canMonetize
                          ? 'Ce compte peut bénéficier de la monétisation, des commissions cadeaux et du parrainage.'
                          : 'Ce type de compte ne bénéficie pas de la monétisation. Les cadeaux reçus en live sont reversés intégralement à la plateforme.',
                      style: TextStyle(
                          color: cat.canMonetize ? Colors.green.shade700 : Colors.red.shade700,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Historique
          if (request.actionHistory.isNotEmpty)
            _Section(
              title: 'Historique des actions',
              colors: colors,
              child: Column(
                children: request.actionHistory.reversed
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8, height: 8,
                                margin: const EdgeInsets.only(top: 4, right: 10),
                                decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50), shape: BoxShape.circle),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.action,
                                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                    Text(
                                      DateFormat('dd/MM/yyyy à HH:mm').format(
                                          DateTime.fromMillisecondsSinceEpoch(a.timestamp)),
                                      style: TextStyle(color: colors.textSecondary, fontSize: 11),
                                    ),
                                    if (a.note?.isNotEmpty == true)
                                      Text(a.note!,
                                          style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

          const SizedBox(height: 12),

          // Boutons d'action
          _AdminActions(request: request),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── Boutons d'action admin ────────────────────────────────────────────────────

class _AdminActions extends StatefulWidget {
  final OfficialAccountRequest request;
  const _AdminActions({required this.request});

  @override
  State<_AdminActions> createState() => _AdminActionsState();
}

class _AdminActionsState extends State<_AdminActions> {
  bool _loading = false;

  Future<void> _act(OfficialAccountStatus status, {String? note}) async {
    setState(() => _loading = true);
    try {
      final auth = context.read<UserAuthProvider>();
      final adminId = auth.loginUserData.id ?? '';
      await OfficialAccountService.instance.updateStatus(
        request: widget.request,
        newStatus: status,
        adminId: adminId,
        note: note,
      );

      // Notification push + data vers l'utilisateur concerné
      _sendStatusNotification(auth, status, note);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demande marquée : ${status.label}'),
            backgroundColor: Color(status.color),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sendStatusNotification(
      UserAuthProvider auth, OfficialAccountStatus status, String? note) async {
    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.request.userId)
          .get();
      final oneSignalId = userSnap.data()?['oneIgnalUserid'] as String?;
      if (oneSignalId == null || oneSignalId.length <= 5) return;

      final message = switch (status) {
        OfficialAccountStatus.approved =>
          'Félicitations ! Votre demande de compte officiel "${widget.request.officialName}" a été acceptée.',
        OfficialAccountStatus.rejected =>
          'Votre demande de compte officiel "${widget.request.officialName}" a été refusée.${note != null ? ' Motif : $note' : ''}',
        OfficialAccountStatus.moreInfoNeeded =>
          'Des informations complémentaires sont demandées pour votre compte officiel "${widget.request.officialName}".${note != null ? ' Détails : $note' : ''}',
        OfficialAccountStatus.underReview =>
          'Votre demande de compte officiel "${widget.request.officialName}" est en cours d\'analyse.',
        OfficialAccountStatus.suspended =>
          'Votre compte officiel "${widget.request.officialName}" a été suspendu.${note != null ? ' Motif : $note' : ''}',
        _ => 'Mise à jour de votre demande de compte officiel.',
      };

      auth.sendNotification(
        appName: 'Compte Officiel',
        userIds: [oneSignalId],
        smallImage: widget.request.imageUrl,
        send_user_id: auth.loginUserData.id ?? '',
        recever_user_id: widget.request.userId,
        message: message,
        type_notif: NotificationType.COMPTE_OFFICIEL.name,
        post_id: widget.request.id,
        post_type: '',
        chat_id: '',
      );
    } catch (_) {
      // Notification non bloquante — on ignore les erreurs silencieusement
    }
  }

  Future<String?> _promptNote({required String title, bool required = false}) async {
    final ctrl = TextEditingController();
    final colors = AppColors.of(context);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(title, style: TextStyle(color: colors.textPrimary, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: required ? 'Motif obligatoire…' : 'Note (optionnelle)…',
            hintStyle: TextStyle(color: colors.textSecondary),
            filled: true,
            fillColor: colors.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
            onPressed: () {
              if (required && ctrl.text.trim().isEmpty) return;
              Navigator.pop(context, ctrl.text.trim());
            },
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final s = widget.request.status;

    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }

    final actions = <Widget>[];

    if (s == OfficialAccountStatus.pending) {
      actions.add(_ActionBtn(
        label: 'Commencer l\'analyse',
        icon: Icons.manage_search_rounded,
        color: const Color(0xFF2196F3),
        colors: colors,
        onTap: () => _act(OfficialAccountStatus.underReview),
      ));
    }

    if (s != OfficialAccountStatus.approved) {
      actions.add(_ActionBtn(
        label: 'Accepter',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF4CAF50),
        colors: colors,
        onTap: () async {
          final note = await _promptNote(title: 'Note pour l\'acceptation (optionnelle)');
          if (note != null) _act(OfficialAccountStatus.approved, note: note.isEmpty ? null : note);
        },
      ));
    }

    if (s != OfficialAccountStatus.rejected) {
      actions.add(_ActionBtn(
        label: 'Refuser',
        icon: Icons.cancel_rounded,
        color: const Color(0xFFF44336),
        colors: colors,
        onTap: () async {
          final note = await _promptNote(title: 'Motif du refus', required: true);
          if (note != null && note.isNotEmpty) {
            _act(OfficialAccountStatus.rejected, note: note);
          }
        },
      ));
    }

    if (s != OfficialAccountStatus.moreInfoNeeded) {
      actions.add(_ActionBtn(
        label: 'Demander des informations',
        icon: Icons.help_outline_rounded,
        color: const Color(0xFF9C27B0),
        colors: colors,
        onTap: () async {
          final note = await _promptNote(title: 'Informations demandées', required: true);
          if (note != null && note.isNotEmpty) {
            _act(OfficialAccountStatus.moreInfoNeeded, note: note);
          }
        },
      ));
    }

    if (s == OfficialAccountStatus.approved) {
      actions.add(_ActionBtn(
        label: 'Suspendre',
        icon: Icons.pause_circle_rounded,
        color: const Color(0xFF607D8B),
        colors: colors,
        onTap: () async {
          final note = await _promptNote(title: 'Motif de la suspension', required: true);
          if (note != null && note.isNotEmpty) {
            _act(OfficialAccountStatus.suspended, note: note);
          }
        },
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: actions,
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final AppColors colors;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18, color: Colors.white),
          label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}

// ── Visualiseur de pièce d'identité ─────────────────────────────────────────

class _IdDocumentViewer extends StatelessWidget {
  final String url;
  final AppColors colors;

  const _IdDocumentViewer({required this.url, required this.colors});

  bool get _isPdf => url.toLowerCase().contains('.pdf') ||
      url.toLowerCase().contains('%2fpdf') ||
      url.toLowerCase().contains('pdf');

  Future<void> _openUrl() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(_),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Document joint',
            style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
        const SizedBox(height: 8),
        if (_isPdf)
          // PDF — bouton ouvrir dans le navigateur
          GestureDetector(
            onTap: _openUrl,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE53935), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Document PDF',
                            style: TextStyle(
                                color: Color(0xFFE53935),
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        Text('Appuyer pour ouvrir dans le navigateur',
                            style: TextStyle(color: Color(0xFFE53935), fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new_rounded, color: Color(0xFFE53935), size: 18),
                ],
              ),
            ),
          )
        else
          // Image — aperçu cliquable + bouton plein écran
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showFullImage(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: colors.surfaceVariant,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 180,
                      color: colors.surfaceVariant,
                      child: Icon(Icons.broken_image, color: colors.textSecondary, size: 40),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showFullImage(context),
                      icon: const Icon(Icons.zoom_in_rounded, size: 16),
                      label: const Text('Plein écran'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openUrl,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Ouvrir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.border.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

// ── Widgets utilitaires ──────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final AppColors colors;

  const _Section({required this.title, required this.child, required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(color: colors.textSecondary, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final AppColors colors;

  const _InfoRow(this.label, this.value, this.colors);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final AppColors colors;
  final Color? color;

  const _Chip({required this.label, required this.colors, this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (color ?? colors.textSecondary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (color ?? colors.border).withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color ?? colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ),
      );
}
