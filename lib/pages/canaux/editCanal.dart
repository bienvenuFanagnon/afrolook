import 'dart:io';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'package:provider/provider.dart';

import 'package:path/path.dart' as Path;

import '../../../providers/authProvider.dart';

import '../../../providers/userProvider.dart';

import '../../theme/app_colors.dart';

import '../../l10n/app_localizations.dart';

class EditCanal extends StatefulWidget {
  final Canal canal;

  EditCanal({required this.canal});

  @override
  _EditCanalState createState() => _EditCanalState();
}

class _EditCanalState extends State<EditCanal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTapUpdate = false;

  late AppColors _colors;
  late AppLocalizations _l10n;

  XFile? imageProfile;
  XFile? imageCouverture;
  bool _isPrivate = false;
  // 'gratuit' | 'unique' | 'mensuel'
  String _subscriptionType = 'unique';
  String? _selectedMainCategory;

  static const _mainCategoryOptions = [
    {'value': 'SPORT',      'label': 'Sport',       'emoji': '⚽'},
    {'value': 'ACTUALITES', 'label': 'Actualités',  'emoji': '📰'},
    {'value': 'LOOKS',      'label': 'Looks',       'emoji': '👗'},
    {'value': 'EVENEMENT',  'label': 'Événement',   'emoji': '🎉'},
    {'value': 'OFFRES',     'label': 'Offres',      'emoji': '🛍️'},
    {'value': 'GAMER',      'label': 'Gaming',      'emoji': '🎮'},
    {'value': 'VIBE',       'label': 'Vibe',        'emoji': '🎵'},
    {'value': 'GENERAL',    'label': 'Général',     'emoji': '📌'},
  ];

  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titreController.text = widget.canal.titre!;
    _descriptionController.text = widget.canal.description!;
    _isPrivate = widget.canal.isPrivate ?? false;
    _subscriptionType = widget.canal.subscriptionType;
    _selectedMainCategory = widget.canal.mainCategory;
    if (_isPrivate) {
      _priceController.text = widget.canal.subscriptionPrice?.toString() ?? '0';
    }
  }

  bool get _categoryLocked {
    final ts = widget.canal.categoryUpdatedAt;
    if (ts == null) return false;
    final lastChange = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(lastChange).inDays < 7;
  }

  DateTime? get _categoryUnlocksAt {
    final ts = widget.canal.categoryUpdatedAt;
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts).add(const Duration(days: 7));
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  Future<void> _getImageProfile() async {
    final image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      imageProfile = image;
    });
  }

  Future<void> _getImageCouverture() async {
    final image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      imageCouverture = image;
    });
  }

  Widget _buildImageSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            _l10n.canalFieldEditProfile + ' & ' + _l10n.canalFieldEditCover,
            style: TextStyle(
              color: _colors.accent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: _colors.primary),
                          ),
                          child: imageProfile != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(File(imageProfile!.path), fit: BoxFit.cover),
                          )
                              : widget.canal.urlImage != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(widget.canal.urlImage!, fit: BoxFit.cover),
                          )
                              : Icon(Icons.person, color: _colors.primary, size: 40),
                        ),
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _colors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit, color: _colors.onPrimary, size: 12),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _getImageProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        _l10n.canalFieldEditProfile,
                        style: TextStyle(color: _colors.onPrimary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: _colors.accent),
                          ),
                          child: imageCouverture != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(File(imageCouverture!.path), fit: BoxFit.cover),
                          )
                              : widget.canal.urlCouverture != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(widget.canal.urlCouverture!, fit: BoxFit.cover),
                          )
                              : Icon(Icons.photo_library, color: _colors.accent, size: 40),
                        ),
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _colors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit, color: _colors.onAccent, size: 12),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _getImageCouverture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        _l10n.canalFieldEditCover,
                        style: TextStyle(color: _colors.onAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            _l10n.canalFieldClickToEdit,
            style: TextStyle(
              color: _colors.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: _colors.primary),
              SizedBox(width: 10),
              Text(
                _l10n.canalTypeTitle,
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildPrivacyOption(
                  title: _l10n.canalPublic,
                  subtitle: _l10n.canalPublicSubtitle,
                  icon: Icons.public,
                  isSelected: !_isPrivate,
                  isPrivateOption: false,
                  color: _colors.primary,
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: _buildPrivacyOption(
                  title: _l10n.canalPrivate,
                  subtitle: _l10n.canalPrivateSubtitle,
                  icon: Icons.lock,
                  isSelected: _isPrivate,
                  isPrivateOption: true,
                  color: _colors.accent,
                ),
              ),
            ],
          ),
          if (_isPrivate) ...[
            SizedBox(height: 20),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: _colors.textPrimary),
              decoration: InputDecoration(
                labelText: _l10n.canalSubscriptionPrice,
                labelStyle: TextStyle(color: _colors.accent),
                prefixIcon: Icon(Icons.attach_money, color: _colors.accent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.accent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.accent.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.accent),
                ),
                filled: true,
                fillColor: _colors.surfaceVariant,
              ),
              validator: _isPrivate ? (value) {
                if (value == null || value.isEmpty) {
                  return _l10n.canalValidPrice;
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return _l10n.canalValidPriceInvalid;
                }
                return null;
              } : null,
            ),
            SizedBox(height: 16),
            Text(
              'Type d\'abonnement',
              style: TextStyle(color: _colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _buildSubTypeOption('unique', Icons.all_inclusive_rounded, 'Unique', 'Accès à vie'),
                SizedBox(width: 10),
                _buildSubTypeOption('mensuel', Icons.autorenew_rounded, 'Mensuel', 'Renouvellement/mois'),
              ],
            ),
          ],
          SizedBox(height: 10),
          _buildSubscribersInfo(),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isPrivateOption,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPrivate = isPrivateOption;
          if (!_isPrivate) {
            _priceController.clear();
          }
        });
      },
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? color : _colors.border,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : _colors.textSecondary, size: 30),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? color : _colors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? color : _colors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTypeOption(String type, IconData icon, String title, String subtitle) {
    final isSelected = _subscriptionType == type;
    final color = _colors.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _subscriptionType = type),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : _colors.border, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : _colors.textSecondary, size: 24),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: isSelected ? color : _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: TextStyle(color: _colors.textSecondary, fontSize: 11), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscribersInfo() {
    final subscribersCount = widget.canal.subscribersId?.length ?? 0;
    if (_isPrivate && subscribersCount > 0) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _colors.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _colors.accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.people, color: _colors.accent, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '$subscribersCount abonné(s) actuel(s) seront affectés par ce changement',
                style: TextStyle(
                  color: _colors.accent,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox();
  }

  Widget _buildFormField() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          TextFormField(
            style: TextStyle(color: _colors.textPrimary),
            decoration: InputDecoration(
              labelText: _l10n.canalFieldTitle,
              labelStyle: TextStyle(color: _colors.primary),
              prefixIcon: Icon(Icons.title, color: _colors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _colors.primary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _colors.primary.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _colors.primary),
              ),
              filled: true,
              fillColor: _colors.surfaceVariant,
            ),
            validator: (value) {
              if (value!.isEmpty) {
                return _l10n.canalValidTitle;
              }
              return null;
            },
            controller: _titreController,
          ),
          SizedBox(height: 20),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            style: TextStyle(color: _colors.textPrimary),
            decoration: InputDecoration(
              labelText: _l10n.canalFieldDescription,
              labelStyle: TextStyle(color: _colors.accent),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _colors.accent),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _colors.accent.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _colors.accent),
              ),
              filled: true,
              fillColor: _colors.surfaceVariant,
            ),
            validator: (value) {
              if (value!.isEmpty) {
                return _l10n.canalValidDescription;
              }
              if (value.length < 10) {
                return _l10n.canalValidDescriptionMin;
              }
              return null;
            },
          ),
          SizedBox(height: 20),
          _buildMainCategoryPicker(),
        ],
      ),
    );
  }

  Widget _buildMainCategoryPicker() {
    final locked = _categoryLocked;
    final unlocksAt = _categoryUnlocksAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.category_outlined, color: _colors.primary, size: 18),
          SizedBox(width: 6),
          Text(
            'Catégorie principale',
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          if (locked && unlocksAt != null) ...[
            SizedBox(width: 8),
            Icon(Icons.lock_outline, color: Colors.orange, size: 14),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'Modifiable le ${_formatDate(unlocksAt)}',
                style: TextStyle(color: Colors.orange, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ]),
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _mainCategoryOptions.map((opt) {
            final val = opt['value'] as String;
            final selected = _selectedMainCategory == val;
            return GestureDetector(
              onTap: locked ? null : () => setState(() => _selectedMainCategory = val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _colors.primary.withOpacity(0.15) : _colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? _colors.primary : _colors.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  '${opt['emoji']} ${opt['label']}',
                  style: TextStyle(
                    color: locked
                        ? _colors.textSecondary.withOpacity(0.5)
                        : (selected ? _colors.primary : _colors.textSecondary),
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Statistiques du Canal',
            style: TextStyle(
              color: _colors.accent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.people,
                value: '${widget.canal.usersSuiviId?.length ?? 0}',
                label: _l10n.canalFollowers,
                color: _colors.primary,
              ),
              _buildStatItem(
                icon: Icons.post_add,
                value: '${widget.canal.publication ?? 0}',
                label: _l10n.canalPublications,
                color: _colors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: _colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
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

  Widget _buildUpdateButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_colors.primary, _colors.accent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _colors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTapUpdate ? null : _updateCanal,
          child: Center(
            child: onTapUpdate
                ? LoadingAnimationWidget.flickr(
              size: 30,
              leftDotColor: _colors.primary,
              rightDotColor: _colors.background,
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.update, color: _colors.onAccent),
                SizedBox(width: 10),
                Text(
                  _l10n.canalEditBtn,
                  style: TextStyle(
                    color: _colors.onAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateCanal() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          onTapUpdate = true;
        });

        // Upload nouvelle image de profil si modifiée
        if (imageProfile != null) {
          Reference storageReferenceProfile = FirebaseStorage.instance
              .ref()
              .child('canal_media/${Path.basename(File(imageProfile!.path).path)}');
          UploadTask uploadTaskProfile = storageReferenceProfile.putFile(File(imageProfile!.path));
          await uploadTaskProfile.whenComplete(() async {
            await storageReferenceProfile.getDownloadURL().then((fileURL) {
              widget.canal.urlImage = fileURL;
            });
          });
        }

        // Upload nouvelle image de couverture si modifiée
        if (imageCouverture != null) {
          Reference storageReferenceCouverture = FirebaseStorage.instance
              .ref()
              .child('canal_media/${Path.basename(File(imageCouverture!.path).path)}');
          UploadTask uploadTaskCouverture = storageReferenceCouverture.putFile(File(imageCouverture!.path));
          await uploadTaskCouverture.whenComplete(() async {
            await storageReferenceCouverture.getDownloadURL().then((fileURL) {
              widget.canal.urlCouverture = fileURL;
            });
          });
        }

        // Mise à jour des informations du canal
        widget.canal.titre = _titreController.text;
        widget.canal.description = _descriptionController.text;
        widget.canal.isPrivate = _isPrivate;
        widget.canal.subscriptionPrice = _isPrivate ? double.parse(_priceController.text) : 0.0;
        widget.canal.subscriptionType = _isPrivate ? _subscriptionType : 'gratuit';
        widget.canal.updatedAt = DateTime.now().microsecondsSinceEpoch;
        // Mettre à jour mainCategory seulement si le cooldown est passé et valeur changée
        if (!_categoryLocked && _selectedMainCategory != widget.canal.mainCategory) {
          widget.canal.mainCategory = _selectedMainCategory;
          if (_selectedMainCategory != null) {
            widget.canal.categoryUpdatedAt = DateTime.now().millisecondsSinceEpoch;
          }
        }

        // Si le canal devient public, on garde les abonnés existants mais sans frais
        if (!_isPrivate) {
          // On conserve les abonnés existants, mais le canal devient gratuit
          // Les abonnés actuels gardent l'accès gratuitement
        }

        // Sauvegarde dans Firestore
        await FirebaseFirestore.instance.collection('Canaux').doc(widget.canal.id).update(widget.canal.toJson());

        // Succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _l10n.canalEditSuccess,
              style: TextStyle(color: _colors.onPrimary, fontWeight: FontWeight.bold),
            ),
            backgroundColor: _colors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Retour à la page précédente après un délai
        Future.delayed(Duration(seconds: 2), () {
          Navigator.of(context).pop();
        });

      } catch (e) {
        printVm('Erreur mise à jour canal: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la mise à jour du canal',
              style: TextStyle(color: _colors.onPrimary),
            ),
            backgroundColor: _colors.danger,
          ),
        );
      } finally {
        setState(() {
          onTapUpdate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    _l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        iconTheme: IconThemeData(color: _colors.textPrimary),
        title: Text(
          _l10n.canalEditTitle,
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _colors.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(Icons.edit, color: _colors.accent),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Section statistiques
              _buildStatsSection(),
              SizedBox(height: 20),

              // Section images
              _buildImageSection(),
              SizedBox(height: 20),

              // Section formulaire
              _buildFormField(),
              SizedBox(height: 20),

              // Section privé/public
              _buildPrivacySection(),
              SizedBox(height: 30),

              // Bouton de mise à jour
              _buildUpdateButton(),
              SizedBox(height: 20),

              // Information importante
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: _colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _colors.accent.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: _colors.accent, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Information importante',
                          style: TextStyle(
                            color: _colors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Si vous rendez un canal privé public, tous les abonnés actuels garderont l\'accès gratuitement. '
                          'Si vous rendez un canal public privé, les nouveaux membres devront payer l\'abonnement.',
                      style: TextStyle(
                        color: _colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class EditCanal extends StatefulWidget {
//   final Canal canal;
//
//   EditCanal({required this.canal});
//
//   @override
//   _EditCanalState createState() => _EditCanalState();
// }
//
// class _EditCanalState extends State<EditCanal> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _titreController = TextEditingController();
//   final TextEditingController _descriptionController = TextEditingController();
//   late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//   late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//
//   XFile? imageProfile;
//   XFile? imageCouverture;
//
//   final ImagePicker picker = ImagePicker();
//
//   @override
//   void initState() {
//     super.initState();
//     _titreController.text = widget.canal.titre!;
//     _descriptionController.text = widget.canal.description!;
//   }
//
//   Future<void> _getImageProfile() async {
//     final image = await picker.pickImage(source: ImageSource.gallery);
//     setState(() {
//       imageProfile = image;
//     });
//   }
//
//   Future<void> _getImageCouverture() async {
//     final image = await picker.pickImage(source: ImageSource.gallery);
//     setState(() {
//       imageCouverture = image;
//     });
//   }
//
//   Future<void> _updateCanal() async {
//     if (_formKey.currentState!.validate()) {
//       try {
//         if (imageProfile != null) {
//           Reference storageReferenceProfile = FirebaseStorage.instance
//               .ref()
//               .child('canal_media/${Path.basename(File(imageProfile!.path).path)}');
//           UploadTask uploadTaskProfile = storageReferenceProfile.putFile(File(imageProfile!.path));
//           await uploadTaskProfile.whenComplete(() async {
//             await storageReferenceProfile.getDownloadURL().then((fileURL) {
//               widget.canal.urlImage = fileURL;
//             });
//           });
//         }
//
//         if (imageCouverture != null) {
//           Reference storageReferenceCouverture = FirebaseStorage.instance
//               .ref()
//               .child('canal_media/${Path.basename(File(imageCouverture!.path).path)}');
//           UploadTask uploadTaskCouverture = storageReferenceCouverture.putFile(File(imageCouverture!.path));
//           await uploadTaskCouverture.whenComplete(() async {
//             await storageReferenceCouverture.getDownloadURL().then((fileURL) {
//               widget.canal.urlCouverture = fileURL;
//             });
//           });
//         }
//
//         widget.canal.titre = _titreController.text;
//         widget.canal.description = _descriptionController.text;
//
//         await FirebaseFirestore.instance.collection('Canaux').doc(widget.canal.id).update(widget.canal.toJson());
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Le Canal a été mis à jour avec succès !',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.green),
//             ),
//           ),
//         );
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Erreur de mise à jour.',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Détails du Canal'),
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CircleAvatar(
//                       radius: 50,
//                       backgroundImage: imageProfile != null
//                           ? FileImage(File(imageProfile!.path)) as ImageProvider<Object>
//                           : widget.canal.urlImage != null
//                           ? NetworkImage(widget.canal.urlImage!) as ImageProvider<Object>
//                           : null,
//                       child: imageProfile == null && widget.canal.urlImage == null
//                           ? const Icon(Icons.person)
//                           : null,
//                     ),
//                     const SizedBox(height: 20),
//                     ElevatedButton(
//                       onPressed: _getImageProfile,
//                       child: const Text('Modifier l\'image de profil'),
//                     ),
//                     const SizedBox(height: 20),
//                     imageCouverture != null
//                         ? Image.file(File(imageCouverture!.path))
//                         : widget.canal.urlCouverture != null
//                         ? Image.network(widget.canal.urlCouverture!)
//                         : Container(
//                       height: 150,
//                       width: double.infinity,
//                       color: Colors.grey[300],
//                       child: const Icon(Icons.image),
//                     ),
//                     const SizedBox(height: 20),
//                     ElevatedButton(
//                       onPressed: _getImageCouverture,
//                       child: const Text('Modifier l\'image de couverture'),
//                     ),
//                   ],
//                 ),
//               ),
//               Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     TextFormField(
//                       decoration: InputDecoration(labelText: 'Titre'),
//                       validator: (value) {
//                         if (value!.isEmpty) {
//                           return 'Veuillez entrer un titre';
//                         }
//                         return null;
//                       },
//                       controller: _titreController,
//                     ),
//                     SizedBox(height: 20),
//                     TextFormField(
//                       controller: _descriptionController,
//                       decoration: InputDecoration(labelText: 'Description'),
//                       validator: (value) {
//                         if (value!.isEmpty) {
//                           return 'Veuillez entrer une description';
//                         }
//                         return null;
//                       },
//                     ),
//                     SizedBox(height: 50),
//                     ElevatedButton(
//                       onPressed: _updateCanal,
//                       child: Text('Mettre à jour le canal'),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }