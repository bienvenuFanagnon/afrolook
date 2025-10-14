import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    postProvider = Provider.of<PostProvider>(context, listen: false);
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _incrementViews();
  }

  void _incrementViews() async {
    await postProvider.getUserServiceById(widget.data.id!).then((value) async {
      if (value.isNotEmpty) {
        final service = value.first;
        service.vues = (service.vues ?? 0) + 1;

        if (!_isIn(service.usersViewId!, authProvider.loginUserData.id!)) {
          service.usersViewId!.add(authProvider.loginUserData.id!);
        }

        await postProvider.updateUserService(service, context);
      }
    });
  }

  bool _isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
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
            "Impossible d'ouvrir WhatsApp",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      throw Exception('Impossible d\'ouvrir WhatsApp');
    } else {
      await postProvider.getUserServiceById(data.id!).then((value) async {
        if (value.isNotEmpty) {
          final updatedService = value.first;
          updatedService.contactWhatsapp = (updatedService.contactWhatsapp ?? 0) + 1;

          if (!_isIn(updatedService.usersContactId!, authProvider.loginUserData.id!)) {
            updatedService.usersContactId!.add(authProvider.loginUserData.id!);
          }

          await postProvider.updateUserService(updatedService, context);
          setState(() {
            widget.data.contactWhatsapp = updatedService.contactWhatsapp;
          });
        }
      });
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.error,
                        color: Colors.red,
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

        // Notification au créateur du service
        CollectionReference userCollect = FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await userCollect
            .where("id", isEqualTo: widget.data.user!.id!)
            .get();

        List<UserData> listUsers = querySnapshotUser.docs
            .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
            .toList();

        if (listUsers.isNotEmpty && listUsers.first.oneIgnalUserid != null) {
          NotificationData notif = NotificationData();
          notif.id = firestore.collection('Notifications').doc().id;
          notif.titre = "🛠️ Nouvelle demande de service";
          notif.media_url = authProvider.loginUserData.imageUrl;
          notif.type = NotificationType.SERVICE.name;
          notif.description = "@${authProvider.loginUserData.pseudo!} est intéressé(e) par votre service";
          notif.users_id_view = [];
          notif.user_id = authProvider.loginUserData.id;
          notif.receiver_id = widget.data.user!.id!;
          notif.post_id = widget.data.id!;
          notif.post_data_type = PostDataType.IMAGE.name!;
          notif.updatedAt = DateTime.now().millisecondsSinceEpoch;
          notif.createdAt = DateTime.now().millisecondsSinceEpoch;
          notif.status = PostStatus.VALIDE.name;

          await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

          await authProvider.sendNotification(
            userIds: [widget.data.user!.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: widget.data.user!.id!,
            message: "📢 @${authProvider.loginUserData.pseudo!} veut votre service 💼",
            type_notif: NotificationType.SERVICE.name,
            post_id: widget.data.id!,
            post_type: PostDataType.IMAGE.name,
            chat_id: '',
          );
        }
      });
    } catch (e) {
      print('Error contacting service: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _deleteService() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.yellow),
            SizedBox(width: 10),
            Text(
              'Confirmer',
              style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer définitivement ce service ?',
          style: TextStyle(color: Colors.white, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'ANNULER',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'SUPPRIMER',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() { _isLoading = true; });

      try {
        widget.data.disponible = false;
        await postProvider.updateUserService(widget.data, context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Service supprimé avec succès !'),
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erreur lors de la suppression'),
          ),
        );
      } finally {
        setState(() { _isLoading = false; });
      }
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

  void _toggleLike() async {
    await postProvider.getUserServiceById(widget.data.id!).then((value) async {
      if (value.isNotEmpty) {
        final service = value.first;
        service.like = (service.like ?? 0) + 1;

        if (!_isIn(service.usersLikeId!, authProvider.loginUserData.id!)) {
          service.usersLikeId!.add(authProvider.loginUserData.id!);
        }

        await postProvider.updateUserService(service, context);
        setState(() {
          widget.data.like = service.like;
        });
      }
    });
  }

  bool get _canEditOrDelete {
    return authProvider.loginUserData.id == widget.data.userId ||
        authProvider.loginUserData.role == UserRole.ADM.name;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? _buildLoadingState()
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            expandedHeight: 300,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroImage(),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.yellow),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          SizedBox(height: 16),
          Text(
            'Chargement...',
            style: TextStyle(color: Colors.yellow),
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
                  color: Colors.grey[800],
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: Icon(Icons.work_outline, color: Colors.green, size: 60),
                ),
              )
                  : Container(
                color: Colors.grey[800],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_outline, color: Colors.green, size: 60),
                      SizedBox(height: 8),
                      Text(
                        'SERVICE',
                        style: TextStyle(
                          color: Colors.green,
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
      icon: Icon(Icons.more_vert, color: Colors.yellow),
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
              Icon(Icons.edit, color: Colors.yellow),
              SizedBox(width: 8),
              Text('Modifier'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Supprimer', style: TextStyle(color: Colors.red)),
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
                color: Colors.yellow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.yellow),
              ),
              child: Text(
                widget.data.category ?? 'Autre',
                style: TextStyle(
                  color: Colors.yellow,
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(FontAwesome.heart, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${widget.data.like ?? 0}',
                      style: TextStyle(
                        color: Colors.red,
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
          widget.data.titre?.toUpperCase() ?? 'TITRE DU SERVICE',
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        SizedBox(height: 8),
        // Localisation
        Row(
          children: [
            Icon(Icons.location_on, color: Colors.green, size: 16),
            SizedBox(width: 6),
            Text(
              '${widget.data.city ?? ''}${widget.data.city != null && widget.data.country != null ? ', ' : ''}${widget.data.country ?? ''}',
              style: TextStyle(
                color: Colors.green,
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
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.remove_red_eye,
            value: widget.data.vues ?? 0,
            label: 'Vues',
            color: Colors.green,
          ),
          _buildStatItem(
            icon: FontAwesome.whatsapp,
            value: widget.data.contactWhatsapp ?? 0,
            label: 'Contacts',
            color: Colors.green,
          ),
          _buildStatItem(
            icon: FontAwesome.heart,
            value: widget.data.like ?? 0,
            label: 'Likes',
            color: Colors.red,
          ),
          _buildStatItem(
            icon: Icons.share,
            value: widget.data.usersPartageId?.length ?? 0,
            label: 'Partages',
            color: Colors.blue,
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
            color: Colors.white,
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
          'Description du service',
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.data.description ?? 'Aucune description disponible',
            style: TextStyle(
              color: Colors.white,
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
          'Contact',
          style: TextStyle(
            color: Colors.yellow,
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
              'CONTACTER SUR WHATSAPP',
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
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.phone, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.data.contact!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.content_copy, color: Colors.yellow, size: 16),
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