// user_ad_detail_page.dart
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/user/userPubs/user_create_advertisement_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// user_ad_detail_page.dart
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/user/userPubs/user_create_advertisement_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class UserAdDetailPage extends StatefulWidget {
  final String advertisementId;
  const UserAdDetailPage({Key? key, required this.advertisementId}) : super(key: key);

  @override
  State<UserAdDetailPage> createState() => _UserAdDetailPageState();
}

class _UserAdDetailPageState extends State<UserAdDetailPage> {
  late Future<Map<String, dynamic>> _dataFuture;

  // Contrôleurs pour l'édition
  late TextEditingController _descriptionController;
  late TextEditingController _actionUrlController;
  String? _selectedActionType;
  bool _isEditing = false;
  bool _isSaving = false;

  // Pour la vidéo
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  final Color _primaryColor = const Color(0xFFE21221);
  final Color _secondaryColor = const Color(0xFFFFD600);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;

  final Map<String, Map<String, dynamic>> _actionTypes = {
    'download': {'label': 'Télécharger', 'icon': Icons.download, 'hint': 'https://play.google.com/...'},
    'visit': {'label': 'Visiter', 'icon': Icons.language, 'hint': 'https://monsite.com'},
    'learn_more': {'label': 'En savoir plus', 'icon': Icons.info, 'hint': 'https://...'},
    'whatsapp': {'label': 'WhatsApp', 'icon': Icons.chat, 'hint': 'Numéro WhatsApp'},
  };

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _actionUrlController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final adDoc = await FirebaseFirestore.instance.collection('Advertisements').doc(widget.advertisementId).get();
    if (!adDoc.exists) throw Exception('Publicité introuvable');
    final ad = Advertisement.fromJson(adDoc.data()!);
    DocumentSnapshot? postDoc;
    if (ad.postId != null) {
      postDoc = await FirebaseFirestore.instance.collection('Posts').doc(ad.postId).get();
    }
    // Initialiser les contrôleurs avec les valeurs existantes
    Map<String, dynamic>? postData = postDoc?.data() as Map<String, dynamic>?;
    _descriptionController = TextEditingController(text: postData?['description'] ?? '');
    _actionUrlController = TextEditingController(text: ad.actionUrl ?? '');
    _selectedActionType = ad.actionType;
    return {'ad': ad, 'post': postDoc};
  }

  Future<void> _saveChanges(Advertisement ad, String postId) async {
    setState(() => _isSaving = true);
    try {
      // Mettre à jour le post (description)
      await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
        'description': _descriptionController.text.trim(),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      // Mettre à jour l'advertisement (action)
      await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).update({
        'actionType': _selectedActionType,
        'actionUrl': _actionUrlController.text.trim(),
        'actionButtonText': _getActionButtonText(),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Modifications enregistrées'), backgroundColor: Colors.green),
      );
      setState(() => _isEditing = false);
      // Recharger les données
      _dataFuture = _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: _primaryColor),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _getActionButtonText() {
    switch (_selectedActionType) {
      case 'download': return 'Télécharger';
      case 'visit': return 'Visiter';
      case 'learn_more': return 'En savoir plus';
      case 'whatsapp': return 'WhatsApp';
      default: return 'Action';
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  // Afficher les images en plein écran
  void _showFullScreenImage(List<String> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
          body: PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: images.length,
            itemBuilder: (context, i) => InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 5.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: images[i],
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(child: CircularProgressIndicator(color: _primaryColor)),
                  errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent(Map<String, dynamic> postData) {
    final dataType = postData['dataType'];
    final imagesRaw = postData['images'];
    final List<String> images = (imagesRaw != null && imagesRaw is List)
        ? List<String>.from(imagesRaw)
        : [];
    final videoUrl = postData['url_media'];

    if (dataType == 'VIDEO' && videoUrl != null) {
      // Initialisation du lecteur vidéo avec gestion d'erreur
      if (_videoController == null) {
        _videoController = VideoPlayerController.network(videoUrl);
        _videoController!.initialize().then((_) {
          if (mounted) {
            setState(() => _isVideoInitialized = true);
            _chewieController = ChewieController(
              videoPlayerController: _videoController!,
              autoPlay: false,
              looping: false,
              showControls: true,
              allowFullScreen: true,
              materialProgressColors: ChewieProgressColors(
                playedColor: _primaryColor,
                handleColor: _primaryColor,
                backgroundColor: Colors.grey[800]!,
                bufferedColor: Colors.grey[600]!,
              ),
            );
          }
        }).catchError((error) {
          print('Erreur chargement vidéo: $error');
          if (mounted) {
            setState(() => _isVideoInitialized = false);
            _showVideoErrorDialog(videoUrl);
          }
        });
      }

      // Affichage du lecteur ou d'un message d'erreur
      if (_isVideoInitialized && _chewieController != null) {
        return Container(
          height: 250,
          margin: EdgeInsets.symmetric(vertical: 8),
          child: Chewie(controller: _chewieController!),
        );
      } else if (!_isVideoInitialized && _videoController != null) {
        // En cours de chargement
        return Container(
          height: 250,
          margin: EdgeInsets.symmetric(vertical: 8),
          color: Colors.grey[900],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _primaryColor),
                SizedBox(height: 8),
                Text('Chargement de la vidéo...', style: TextStyle(color: _hintColor)),
              ],
            ),
          ),
        );
      } else if (!_isVideoInitialized && _videoController == null) {
        // Échec de chargement - afficher un bouton pour ouvrir dans le navigateur
        return Container(
          height: 250,
          margin: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 64, color: _secondaryColor),
                SizedBox(height: 16),
                Text(
                  'Lecture vidéo non disponible',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Le format vidéo n\'est pas supporté par votre appareil.',
                  style: TextStyle(color: _hintColor, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openVideoInBrowser(videoUrl),
                  icon: Icon(Icons.open_in_browser),
                  label: Text('Ouvrir dans le navigateur'),
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                ),
              ],
            ),
          ),
        );
      }
      return SizedBox.shrink();
    } else if (images.isNotEmpty) {
      // Carrousel d'images (inchangé)
      return Container(
        height: 250,
        margin: EdgeInsets.symmetric(vertical: 8),
        child: ImageSlideshow(
          initialPage: 0,
          indicatorColor: _secondaryColor,
          indicatorBackgroundColor: Colors.grey,
          isLoop: true,
          children: images.asMap().entries.map((entry) {
            int index = entry.key;
            String imageUrl = entry.value;
            return GestureDetector(
              onTap: () => _showFullScreenImage(images, index),
              child: Hero(
                tag: imageUrl,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: Center(child: CircularProgressIndicator(color: _primaryColor)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.error, color: Colors.red),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }
    return SizedBox.shrink();
  }

// Ajoutez ces deux méthodes dans la classe :

  void _showVideoErrorDialog(String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Erreur de lecture', style: TextStyle(color: _secondaryColor)),
        content: Text(
          'La vidéo ne peut pas être lue sur cet appareil.\n\n'
              'Vous pouvez essayer de l\'ouvrir dans votre navigateur.',
          style: TextStyle(color: _textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: _hintColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openVideoInBrowser(videoUrl);
            },
            child: Text('Ouvrir'),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
          ),
        ],
      ),
    );
  }

  Future<void> _openVideoInBrowser(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir le lien'), backgroundColor: Colors.red),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        title: Text('Détail de la publicité', style: TextStyle(color: _secondaryColor)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: _secondaryColor), onPressed: () => Navigator.pop(context)),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: _secondaryColor),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: Colors.red)));
          }
          final ad = snapshot.data!['ad'] as Advertisement;
          final postDoc = snapshot.data!['post'] as DocumentSnapshot?;
          Map<String, dynamic>? postData = postDoc?.data() as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Média (vidéo ou carrousel d'images)
                if (postData != null) _buildMediaContent(postData),
                SizedBox(height: 16),

                // Statut
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(_getStatusIcon(ad.status), color: _getStatusColor(ad.status), size: 24),
                      SizedBox(width: 12),
                      Text('Statut: ', style: TextStyle(color: _hintColor)),
                      Text(_getStatusText(ad.status), style: TextStyle(color: _getStatusColor(ad.status), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Description (éditable)
                Card(
                  color: _cardColor,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Description', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        if (_isEditing)
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            style: TextStyle(color: _textColor),
                            decoration: InputDecoration(
                              hintText: 'Description...',
                              hintStyle: TextStyle(color: _hintColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          )
                        else
                          Text(postData?['description'] ?? '', style: TextStyle(color: _textColor)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Type d'action (éditable)
                Card(
                  color: _cardColor,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Action', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        if (_isEditing) ...[
                          Wrap(
                            spacing: 8,
                            children: _actionTypes.entries.map((entry) {
                              return ChoiceChip(
                                label: Text(entry.value['label']),
                                selected: _selectedActionType == entry.key,
                                onSelected: (selected) => setState(() => _selectedActionType = selected ? entry.key : null),
                                selectedColor: _primaryColor,
                                backgroundColor: Colors.grey[800],
                                labelStyle: TextStyle(color: _selectedActionType == entry.key ? Colors.white : _hintColor),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 12),
                          if (_selectedActionType == 'whatsapp')
                            TextFormField(
                              controller: _actionUrlController,
                              style: TextStyle(color: _textColor),
                              decoration: InputDecoration(
                                hintText: 'Numéro WhatsApp (ex: +22890123456)',
                                hintStyle: TextStyle(color: _hintColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          else
                            TextFormField(
                              controller: _actionUrlController,
                              style: TextStyle(color: _textColor),
                              decoration: InputDecoration(
                                hintText: 'https://...',
                                hintStyle: TextStyle(color: _hintColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(ad.getActionIcon(), color: _primaryColor),
                              SizedBox(width: 8),
                              Text(ad.getActionButtonText(), style: TextStyle(color: _textColor)),
                            ],
                          ),
                          SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final url = Uri.parse(ad.actionUrl ?? '');
                              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                            },
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Icon(Icons.link, color: _secondaryColor, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(child: Text(ad.actionUrl ?? '', style: TextStyle(color: _secondaryColor, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Statistiques
                Card(
                  color: _cardColor,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Statistiques', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Vues', _formatNumber(ad.views ?? 0), Icons.remove_red_eye, Colors.blue),
                            _buildStatItem('Clics', _formatNumber(ad.clicks ?? 0), Icons.ads_click, _secondaryColor),
                            _buildStatItem('CTR', '${ad.ctr.toStringAsFixed(1)}%', Icons.trending_up, ad.ctr > 5 ? Colors.green : Colors.orange),
                            _buildStatItem('Clics uniques', _formatNumber(ad.uniqueClicks ?? 0), Icons.person, Colors.purple),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Dates
                Card(
                  color: _cardColor,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Période', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.play_arrow, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Text('Début: ${ad.startDate != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMicrosecondsSinceEpoch(ad.startDate!)) : 'N/A'}', style: TextStyle(color: _textColor)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.stop, color: Colors.red, size: 16),
                            SizedBox(width: 8),
                            Text('Fin: ${ad.endDate != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMicrosecondsSinceEpoch(ad.endDate!)) : 'N/A'}', style: TextStyle(color: _textColor)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.update, color: _secondaryColor, size: 16),
                            SizedBox(width: 8),
                            Text('Renouvellements: ${ad.renewalCount}', style: TextStyle(color: _textColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                if (ad.rejectionReason != null)
                  Card(
                    color: Colors.red.withOpacity(0.1),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(child: Text('Motif du rejet: ${ad.rejectionReason}', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  ),

                // Boutons d'action (édition ou création)
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
                          child: Text('Annuler'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : () => _saveChanges(ad, postDoc!.id),
                          child: _isSaving ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Enregistrer'),
                          style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const UserCreateAdvertisementPage()));
                      },
                      icon: Icon(Icons.add_circle),
                      label: Text('Créer une nouvelle publicité'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: _hintColor, fontSize: 11)),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'pending': return Colors.orange;
      case 'expired': return Colors.grey;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'active': return 'Active';
      case 'pending': return 'En attente';
      case 'expired': return 'Expirée';
      case 'rejected': return 'Rejetée';
      default: return 'Inconnu';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'active': return Icons.check_circle;
      case 'pending': return Icons.hourglass_empty;
      case 'expired': return Icons.timer_off;
      case 'rejected': return Icons.cancel;
      default: return Icons.help;
    }
  }
}