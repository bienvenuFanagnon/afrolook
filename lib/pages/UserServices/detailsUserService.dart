import 'package:afrotok/l10n/tr.dart';
import '../../theme/app_colors.dart';
import 'package:afrotok/services/api/publications_api.dart';
import 'package:afrotok/services/api/services_api.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../component/consoleWidget.dart';
import '../component/showUserDetails.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'newUserService.dart';

class DetailUserServicePage extends StatefulWidget {
  final UserServiceData data;

  DetailUserServicePage({required this.data});

  @override
  _DetailUserServicePageState createState() => _DetailUserServicePageState();
}

class _DetailUserServicePageState extends State<DetailUserServicePage> {
  late PostProvider postProvider;
  late UserAuthProvider authProvider;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    postProvider = Provider.of<PostProvider>(context, listen: false);
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _refreshAndCountView();
  }

  /// Relit le service (compteurs et « j'aime » à jour) puis compte la vue : le serveur n'en compte qu'une par personne, jamais celle du créateur.
  Future<void> _refreshAndCountView() async {
    final id = widget.data.id;
    if (id == null) return;
    try {
      final fresh = await PubApi.service(id);
      if (fresh != null && mounted) setState(() => ServicesApi.merge(widget.data, fresh));
    } catch (e) {
      printVm('Lecture du service impossible : $e');
    }
    try {
      final views = await ServicesApi.view(id);
      if (views != null && mounted) setState(() => widget.data.vues = views);
    } catch (e) {
      printVm('Vue du service non comptée : $e');
    }
  }

  void _showError(Object e, String fallback, {VoidCallback? retry}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.of(context).danger,
        content: Text(ServicesApi.message(e, fallback: fallback)),
        duration: const Duration(seconds: 6),
        action: retry == null ? null : SnackBarAction(label: context.tr('Réessayer'), textColor: Colors.white, onPressed: retry),
      ),
    );
  }

  /// Partage du service : lien Afrolook, puis le serveur compte le partage.
  Future<void> _shareService() async {
    final id = widget.data.id;
    if (id == null) return;
    try {
      final url = await authProvider.createServiceLink(true, widget.data);
      final res = await Share.share('${widget.data.titre ?? ''}\n$url');
      if (res.status == ShareResultStatus.dismissed) return;
      final shares = await ServicesApi.share(id);
      if (shares != null && mounted) setState(() => widget.data.partage = shares);
    } catch (e) {
      _showError(e, context.tr('Impossible de partager ce service pour le moment.'), retry: _shareService);
    }
  }

  Future<void> _launchWhatsApp(String phone, UserServiceData data, String urlService) async {
    String url = "whatsapp://send?phone=" + phone + "&text="
        + "Bonjour *${data.user!.nom!}*,\n\n"
        + "Je m'appelle *@${authProvider.loginUserData!.pseudo!.toUpperCase()}* et je suis sur Afrolook.\n"
        + "Je vous contacte concernant votre service :\n\n"
        + "*Titre* : *${data.titre!.toUpperCase()}*\n"
        + "*Description* : *${data.description}*\n\n"
        + "Je suis très intéressé(e) par ce que vous proposez et j'aimerais en savoir plus.\n"
        + "Vous pouvez voir le service ici : ${urlService}\n\n"
        + "Merci et à bientôt !";

    if (!await launchUrl(Uri.parse(url))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 2),
          content: Text(
            context.tr("Impossible d'ouvrir WhatsApp"),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.of(context).danger),
          ),
        ),
      );
      throw Exception('Impossible d\'ouvrir WhatsApp');
    } else {
      // Le clic est compté par le serveur, qui prévient le créateur (une seule fois par personne). Sans effet bloquant : WhatsApp est déjà ouvert.
      try {
        final contacts = await ServicesApi.contact(data.id!);
        if (contacts != null && mounted) setState(() => widget.data.contactWhatsapp = contacts);
      } catch (e) {
        printVm('Contact du service non compté : $e');
      }
    }
  }

  void _showFullScreenImage() {
    if (widget.data.imageCourverture == null ||
        !widget.data.imageCourverture!.startsWith('http')) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(0),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Hero(
                    tag: 'service_image_${widget.data.id}',
                    child: CachedNetworkImage(
                      imageUrl: widget.data.imageCourverture!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.of(context).primary),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.error,
                        color: AppColors.of(context).danger,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _contactService() async {
    setState(() { _isLoading = true; });

    try {
      await authProvider.createServiceLink(true, widget.data).then((url) async {
        await _launchWhatsApp(widget.data.contact!, widget.data, url);
      });
    } catch (e) {
      printVm('Error contacting service: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _deleteService() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: AppColors.of(context).supportAccent),
            SizedBox(width: 10),
            Text(
              context.tr('Confirmer'),
              style: TextStyle(color: AppColors.of(context).supportAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          context.tr('Êtes-vous sûr de vouloir supprimer définitivement ce service ?'),
          style: TextStyle(color: AppColors.of(context).textPrimary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.tr('ANNULER'),
              style: TextStyle(color: AppColors.of(context).primary, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              context.tr('SUPPRIMER'),
              style: TextStyle(color: AppColors.of(context).danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) await _deleteServiceConfirmed();
  }

  Future<void> _deleteServiceConfirmed() async {
    setState(() { _isLoading = true; });

    try {
      // Suppression par le serveur (propriétaire ou équipe) : DELETE /services/{id}
      await ServicesApi.delete(widget.data.id!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(context.tr('Service supprimé avec succès !')),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      _showError(e, context.tr('Erreur lors de la suppression'), retry: _deleteServiceConfirmed);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _editService() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserServiceForm(
          existingService: widget.data,
          isEditing: true,
        ),
      ),
    );
  }

  bool _liking = false;

  /// Un utilisateur = un seul like par service, une seule fois (pas de like multiple, pas de retrait).
  bool get _alreadyLiked =>
      widget.data.usersLikeId?.contains(authProvider.loginUserData.id) ?? false;

  Future<void> _toggleLike() async {
    final uid = authProvider.loginUserData.id;
    final serviceId = widget.data.id;
    if (uid == null || serviceId == null || _liking) return;
    if (_alreadyLiked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Vous avez déjà aimé ce service')), duration: const Duration(seconds: 1)),
      );
      return;
    }
    _liking = true;
    // Affichage immédiat, confirmé (ou annulé) par le serveur
    setState(() {
      widget.data.usersLikeId ??= [];
      widget.data.usersLikeId!.add(uid);
      widget.data.like = (widget.data.like ?? 0) + 1;
    });
    try {
      final r = await ServicesApi.like(serviceId);
      if (mounted) {
        setState(() {
          widget.data.like = r.like;
          if (!r.liked) widget.data.usersLikeId?.remove(uid);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          widget.data.usersLikeId?.remove(uid);
          widget.data.like = ((widget.data.like ?? 1) - 1).clamp(0, 1 << 30);
        });
        _showError(e, context.tr('Impossible d\'aimer ce service pour le moment.'), retry: _toggleLike);
      }
    } finally {
      _liking = false;
    }
  }

  bool get _canEditOrDelete {
    return authProvider.loginUserData.id == widget.data.userId ||
        authProvider.loginUserData.role == UserRole.ADM.name;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: _isLoading
          ? _buildLoadingState()
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.of(context).background,
            expandedHeight: 300,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroImage(),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.of(context).supportAccent),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: context.tr('Partager'),
                icon: Icon(Icons.share, color: AppColors.of(context).supportAccent),
                onPressed: _shareService,
              ),
              if (_canEditOrDelete) _buildActionMenu(),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildServiceHeader(),
                  SizedBox(height: 20),
                  _buildServiceStats(),
                  SizedBox(height: 20),
                  _buildServiceDetails(),
                  SizedBox(height: 20),
                  _buildContactSection(),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.of(context).primary),
          ),
          SizedBox(height: 16),
          Text(
            context.tr('Chargement...'),
            style: TextStyle(color: AppColors.of(context).supportAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return GestureDetector(
      onTap: _showFullScreenImage,
      child: Stack(
        children: [
          Hero(
            tag: 'service_image_${widget.data.id}',
            child: Container(
              width: double.infinity,
              child: widget.data.imageCourverture != null &&
                  widget.data.imageCourverture!.startsWith('http')
                  ? CachedNetworkImage(
                imageUrl: widget.data.imageCourverture!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.of(context).surfaceVariant,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.of(context).primary),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.of(context).surfaceVariant,
                  child: Icon(Icons.work_outline, color: AppColors.of(context).primary, size: 60),
                ),
              )
                  : Container(
                color: AppColors.of(context).surfaceVariant,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_outline, color: AppColors.of(context).primary, size: 60),
                      SizedBox(height: 8),
                      Text(
                        context.tr('SERVICE'),
                        style: TextStyle(
                          color: AppColors.of(context).primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.zoom_in, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: AppColors.of(context).supportAccent),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _editService();
            break;
          case 'delete':
            _deleteService();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, color: AppColors.of(context).supportAccent),
              SizedBox(width: 8),
              Text(context.tr('Modifier')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: AppColors.of(context).danger),
              SizedBox(width: 8),
              Text(context.tr('Supprimer'), style: TextStyle(color: AppColors.of(context).danger)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Catégorie et badge
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.of(context).supportAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.of(context).supportAccent),
              ),
              child: Text(
                widget.data.category ?? 'Autre',
                style: TextStyle(
                  color: AppColors.of(context).supportAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Spacer(),
            // Like button
            GestureDetector(
              onTap: _toggleLike,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.of(context).danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.of(context).danger),
                ),
                child: Row(
                  children: [
                    Icon(_alreadyLiked ? FontAwesome.heart : FontAwesome.heart_o, color: AppColors.of(context).danger, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${widget.data.like ?? 0}',
                      style: TextStyle(
                        color: AppColors.of(context).danger,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        // Titre
        Text(
          widget.data.titre?.toUpperCase() ?? context.tr('TITRE DU SERVICE'),
          style: TextStyle(
            color: AppColors.of(context).supportAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        SizedBox(height: 8),
        // Localisation
        Row(
          children: [
            Icon(Icons.location_on, color: AppColors.of(context).primary, size: 16),
            SizedBox(width: 6),
            Text(
              '${widget.data.city ?? ''}${widget.data.city != null && widget.data.country != null ? ', ' : ''}${widget.data.country ?? ''}',
              style: TextStyle(
                color: AppColors.of(context).primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceStats() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.of(context).primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.remove_red_eye,
            value: widget.data.vues ?? 0,
            label: context.tr('Vues'),
            color: AppColors.of(context).primary,
          ),
          _buildStatItem(
            icon: FontAwesome.whatsapp,
            value: widget.data.contactWhatsapp ?? 0,
            label: context.tr('Contacts'),
            color: AppColors.of(context).primary,
          ),
          _buildStatItem(
            icon: FontAwesome.heart,
            value: widget.data.like ?? 0,
            label: context.tr('Likes'),
            color: AppColors.of(context).danger,
          ),
          _buildStatItem(
            icon: Icons.share,
            value: widget.data.partage ?? 0,
            label: context.tr('Partages'),
            color: AppColors.of(context).info,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 6),
        Text(
          value.toString(),
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Description du service'),
          style: TextStyle(
            color: AppColors.of(context).supportAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.data.description ?? context.tr('Aucune description disponible'),
            style: TextStyle(
              color: AppColors.of(context).textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Contact'),
          style: TextStyle(
            color: AppColors.of(context).supportAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        // Bouton de contact principal
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _contactService,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(FontAwesome.whatsapp, size: 24),
            label: Text(
              context.tr('CONTACTER SUR WHATSAPP'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        // Numéro de contact
        if (widget.data.contact != null)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.phone, color: AppColors.of(context).primary, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.data.contact!,
                    style: TextStyle(
                      color: AppColors.of(context).textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.content_copy, color: AppColors.of(context).supportAccent, size: 16),
                  onPressed: () {
                    // Copier le numéro
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16),
        SizedBox(width: 4),
        // Text(text),
      ],
    );
  }
}