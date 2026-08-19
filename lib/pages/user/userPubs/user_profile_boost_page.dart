import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/services/ad_config_service.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Page de boost standalone pour un profil utilisateur, un canal ou un groupe de chat.
/// Crée une Advertisement sans post (ownerType = 'user' | 'canal' | 'group'),
/// même flux d'approbation admin que les pubs de posts.
class UserProfileBoostPage extends StatefulWidget {
  /// Si null → boost du profil utilisateur.
  final Canal? canal;

  /// Si non-null → boost du groupe de chat spécifié.
  /// Attendu : {'id': String, 'name': String, 'image_url': String?, 'member_count': int?}
  final Map<String, dynamic>? group;

  const UserProfileBoostPage({Key? key, this.canal, this.group}) : super(key: key);

  @override
  State<UserProfileBoostPage> createState() => _UserProfileBoostPageState();
}

class _UserProfileBoostPageState extends State<UserProfileBoostPage> {
  late UserAuthProvider _auth;
  late AppColors _c;

  final _descController = TextEditingController();
  final _urlController = TextEditingController();
  final _countrySearchController = TextEditingController();
  final _countrySearchFocus = FocusNode();

  String? _selectedActionType;
  int? _selectedDurationWeeks;
  List<AfricanCountry> _selectedCountries = [];
  List<AfricanCountry> _filteredCountries = [];
  bool _selectAllCountries = false;
  bool _showCountrySelection = false;

  List<AdDuration> _durations = AdConfigService.defaults;
  Map<int, int> get _prices => AdConfigService.toMap(_durations);

  bool _isSubmitting = false;

  final Color _gold = const Color(0xFFFFD700);
  final Color _red = const Color(0xFFE21221);

  bool get _isCanal => widget.canal != null;
  bool get _isGroup => widget.group != null;

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<UserAuthProvider>(context, listen: false);
    _filteredCountries = List.from(AfricanCountry.allCountries);
    _countrySearchController.addListener(_filterCountries);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final d = await AdConfigService.getDurations();
    if (mounted) setState(() => _durations = d);
  }

  @override
  void dispose() {
    _descController.dispose();
    _urlController.dispose();
    _countrySearchController.dispose();
    _countrySearchFocus.dispose();
    super.dispose();
  }

  void _filterCountries() {
    final q = _countrySearchController.text.toLowerCase();
    setState(() {
      _filteredCountries = AfricanCountry.allCountries
          .where((c) => c.name.toLowerCase().contains(q) || c.code.toLowerCase().contains(q))
          .toList();
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  String _transactionLabel() {
    if (_isGroup) return 'Boost groupe (${widget.group?['name'] ?? ''})';
    if (_isCanal) return 'Boost canal (${widget.canal?.titre ?? ''})';
    return 'Boost profil';
  }

  Future<void> _createTransaction(int price, String label) async {
    final userData = _auth.loginUserData;
    final tx = TransactionSolde()
      ..id = FirebaseFirestore.instance.collection('TransactionSoldes').doc().id
      ..user_id = userData.id
      ..type = TypeTransaction.DEPENSE.name
      ..statut = StatutTransaction.VALIDER.name
      ..description = label
      ..montant = price.toDouble()
      ..methode_paiement = 'solde_depot'
      ..createdAt = DateTime.now().millisecondsSinceEpoch
      ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    await FirebaseFirestore.instance
        .collection('TransactionSoldes')
        .doc(tx.id)
        .set(tx.toJson());
  }

  Future<void> _submit() async {
    if (_selectedActionType == null) { _showError('Choisissez un type d\'action'); return; }
    if (_selectedDurationWeeks == null) { _showError('Choisissez la durée'); return; }
    if (_descController.text.trim().isEmpty) { _showError('La description est obligatoire'); return; }
    // URL auto-générée — pas de saisie manuelle pour les entités internes
    _autoSetInternalUrl();
    if (!_selectAllCountries && _selectedCountries.isEmpty) {
      _showError('Sélectionnez au moins un pays'); return;
    }

    final price = _prices[_selectedDurationWeeks!] ?? 0;
    final userData = _auth.loginUserData;
    final isAdmin = userData.role == UserRole.ADM.name;
    final balance = userData.votre_solde_depot ?? 0;

    if (!isAdmin && balance < price) {
      _showInsufficientBalanceDialog(price, balance); return;
    }

    setState(() => _isSubmitting = true);
    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final durationDays = _selectedDurationWeeks! * 7;
      final targetCountries = _selectAllCountries
          ? AfricanCountry.allCountries.map((c) => c.code).toList()
          : _selectedCountries.map((c) => c.code).toList();

      // Débiter le solde + enregistrer la transaction
      if (!isAdmin) {
        await FirebaseFirestore.instance.collection('Users').doc(userData.id).update({
          'votre_solde_depot': FieldValue.increment(-price),
        });
        _auth.loginUserData.votre_solde_depot = (balance) - price;
        await _createTransaction(price, _transactionLabel());
      }

      // Snapshot des 3 derniers posts
      List<Map<String, dynamic>> ownerRecentPosts = [];
      try {
        final snap = await FirebaseFirestore.instance
            .collection('Posts')
            .where('user_id', isEqualTo: userData.id)
            .where('isAdvertisement', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get();
        for (final doc in snap.docs) {
          final d = doc.data();
          final isVideo = (d['dataType'] as String? ?? '').toUpperCase() == 'VIDEO';
          final thumb = isVideo
              ? (d['thumbnail'] as String? ?? '')
              : ((d['images'] as List<dynamic>?)?.isNotEmpty == true
                  ? (d['images'] as List<dynamic>).first as String
                  : '');
          ownerRecentPosts.add({'thumb': thumb, 'isVideo': isVideo, 'postId': doc.id});
        }
      } catch (_) {}

      // Infos de l'entité boostée
      final String ownerType;
      final String? ownerId;
      final String ownerName;
      final String? ownerAvatar;
      final int ownerFollowers;
      final String ownerDesc;

      if (_isGroup) {
        final g = widget.group!;
        ownerType = 'group';
        ownerId = g['id'] as String?;
        ownerName = g['name'] as String? ?? 'Groupe';
        ownerAvatar = g['image_url'] as String?;
        ownerFollowers = (g['member_count'] as int?) ?? 0;
        ownerDesc = _descController.text.trim();
      } else if (_isCanal) {
        ownerType = 'canal';
        ownerId = widget.canal!.id;
        ownerName = widget.canal!.titre ?? '';
        ownerAvatar = widget.canal!.urlImage;
        ownerFollowers = widget.canal!.suivi ?? 0;
        ownerDesc = (widget.canal!.description ?? '').substring(0, (widget.canal!.description ?? '').length.clamp(0, 120));
      } else {
        ownerType = 'user';
        ownerId = userData.id;
        ownerName = '${userData.prenom ?? ''} ${userData.nom ?? ''}'.trim().isNotEmpty
            ? '${userData.prenom ?? ''} ${userData.nom ?? ''}'.trim()
            : (userData.pseudo ?? '');
        ownerAvatar = userData.imageUrl;
        ownerFollowers = userData.abonnes ?? 0;
        ownerDesc = (userData.apropos ?? '').substring(0, (userData.apropos ?? '').length.clamp(0, 120));
      }

      // Créer l'Advertisement sans postId (boost entité pure)
      final adId = FirebaseFirestore.instance.collection('Advertisements').doc().id;
      final ad = Advertisement(
        id: adId,
        postId: null,
        actionType: _selectedActionType,
        actionUrl: _urlController.text.trim(),
        actionButtonText: _actionButtonText(),
        durationDays: durationDays,
        startDate: now,
        endDate: now + (durationDays * 24 * 60 * 60 * 1000000),
        status: 'pending',
        isRenewable: true,
        renewalCount: 0,
        pricePaid: price,
        createdBy: userData.id,
        createdAt: now,
        updatedAt: now,
        ownerType: ownerType,
        ownerId: ownerId,
        ownerName: ownerName.isEmpty ? null : ownerName,
        ownerAvatar: ownerAvatar?.isEmpty == false ? ownerAvatar : null,
        ownerFollowers: ownerFollowers > 0 ? ownerFollowers : null,
        ownerDescription: ownerDesc.isNotEmpty ? ownerDesc : null,
        ownerRecentPosts: ownerRecentPosts.isNotEmpty ? ownerRecentPosts : null,
      );
      final adJson = ad.toJson();
      // Marquer explicitement comme boost entité (pas de post)
      adJson['boostType'] = ownerType;
      adJson['availableCountries'] = targetCountries;
      adJson['description'] = _descController.text.trim();
      await FirebaseFirestore.instance.collection('Advertisements').doc(adId).set(adJson);

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      debugPrint('UserProfileBoostPage._submit error: $e');
      _showError('Erreur lors de la soumission. Réessayez.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _autoSetInternalUrl() {
    if (_isGroup) {
      _urlController.text = 'afrolook://group/${widget.group!['id']}';
    } else if (_isCanal) {
      _urlController.text = 'afrolook://canal/${widget.canal!.id}';
    } else {
      _urlController.text = 'afrolook://user/${_auth.loginUserData.id}';
    }
  }

  String _actionButtonText() {
    switch (_selectedActionType) {
      case 'visit': return 'Visiter';
      case 'learn_more': return 'En savoir plus';
      case 'subscribe':
        if (_isGroup) return 'Rejoindre';
        if (_isCanal) return "S'abonner";
        return 'Suivre';
      default: return 'Voir';
    }
  }

  void _showInsufficientBalanceDialog(int price, double balance) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _c.surface,
        title: Text('Solde insuffisant', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Votre solde (${balance.toStringAsFixed(0)} FCFA) est insuffisant pour cette durée ($price FCFA).',
          style: TextStyle(color: _c.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer', style: TextStyle(color: _red))),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _c.surface,
        title: Row(children: [
          Icon(Icons.check_circle, color: _gold),
          const SizedBox(width: 8),
          Text('Demande envoyée', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Votre boost ${_isGroup ? 'de groupe' : _isCanal ? 'de canal' : 'de profil'} est en attente de validation par l\'équipe Afrolook. '
          'Vous serez notifié(e) dès son activation.',
          style: TextStyle(color: _c.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _c = AppColors.of(context);
    final entityLabel = _isGroup ? 'groupe' : _isCanal ? 'canal' : 'profil';
    final entityName = _isGroup
        ? (widget.group!['name'] as String? ?? 'Groupe')
        : _isCanal
            ? (widget.canal!.titre ?? 'Canal')
            : ('${_auth.loginUserData.prenom ?? ''} ${_auth.loginUserData.nom ?? ''}'.trim().isNotEmpty
                ? '${_auth.loginUserData.prenom ?? ''} ${_auth.loginUserData.nom ?? ''}'.trim()
                : (_auth.loginUserData.pseudo ?? 'Mon profil'));
    final entityAvatar = _isGroup
        ? (widget.group!['image_url'] as String?)
        : _isCanal ? widget.canal!.urlImage : _auth.loginUserData.imageUrl;

    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(
        backgroundColor: _c.background,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: _gold), onPressed: () => Navigator.pop(context)),
        title: Text('Booster ${_isCanal ? 'le canal' : 'mon profil'}',
          style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isSubmitting
          ? Center(child: CircularProgressIndicator(color: _gold))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    children: [
                      // ── Carte identité ──
                      _buildEntityCard(entityName, entityAvatar),
                      const SizedBox(height: 16),

                      // ── Info banner ──
                      _buildInfoBanner(entityLabel),
                      const SizedBox(height: 16),

                      // ── Description ──
                      _buildDescCard(),
                      const SizedBox(height: 16),

                      // ── Durée ──
                      _buildDurationCard(),
                      const SizedBox(height: 16),

                      // ── Action ──
                      _buildActionCard(),
                      const SizedBox(height: 16),

                      // ── Pays ──
                      _buildCountryCard(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                // ── Bouton submit fixe en bas ──
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    color: _c.background,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Text(
                        _selectedDurationWeeks != null
                            ? 'BOOSTER · ${_prices[_selectedDurationWeeks!]} FCFA'
                            : 'BOOSTER MON ${entityLabel.toUpperCase()}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                if (_showCountrySelection) _buildCountryModal(),
              ],
            ),
    );
  }

  Widget _buildEntityCard(String name, String? avatar) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 56, height: 56,
              child: avatar?.isNotEmpty == true
                  ? CachedNetworkImage(imageUrl: avatar!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _avatarFallback())
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _gold.withOpacity(0.4)),
                  ),
                  child: Text(
                    _isGroup ? 'Groupe de chat' : _isCanal ? 'Canal' : 'Profil personnel',
                    style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: _gold.withOpacity(0.2),
        child: Icon(Icons.person, color: _gold, size: 28),
      );

  Widget _buildInfoBanner(String entityLabel) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_gold.withOpacity(0.15), _red.withOpacity(0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.rocket_launch_outlined, color: _gold, size: 18),
            const SizedBox(width: 8),
            Text('Pourquoi booster votre $entityLabel ?',
              style: TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          _infoBullet('👥', 'Votre $entityLabel sera recommandé à des milliers d\'utilisateurs près de chez vous'),
          _infoBullet('🌍', 'Ciblez votre quartier, votre ville, votre pays et bien d\'autres'),
          _infoBullet('⭐', 'Gagnez de nouveaux abonnés et augmentez votre visibilité'),
          _infoBullet('✅', 'Diffusion après validation par l\'équipe Afrolook'),
        ],
      ),
    );
  }

  Widget _infoBullet(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: _c.textSecondary, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildDescCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Message de présentation', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _descController,
            maxLines: 3,
            maxLength: 200,
            style: TextStyle(color: _c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Décrivez votre profil ou votre canal en quelques mots...',
              hintStyle: TextStyle(color: _c.textSecondary),
              filled: true,
              fillColor: _c.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              counterStyle: TextStyle(color: _c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text('Durée du boost', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _durations.map((d) {
              final isSelected = _selectedDurationWeeks == d.weeks;
              return ChoiceChip(
                label: Column(children: [
                  Text(AdConfigService.labelFor(d.weeks, _durations), style: const TextStyle(fontSize: 12)),
                  Text('${d.price} FCFA', style: const TextStyle(fontSize: 10)),
                ]),
                selected: isSelected,
                onSelected: (v) => setState(() => _selectedDurationWeeks = v ? d.weeks : null),
                selectedColor: _red,
                backgroundColor: _c.surfaceVariant,
                labelStyle: TextStyle(color: isSelected ? Colors.white : _c.textSecondary),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    final options = [
      ('Visiter le profil', 'visit', Icons.open_in_new),
      ('En savoir plus', 'learn_more', Icons.info_outline),
      (_isGroup ? 'Rejoindre le groupe' : _isCanal ? "S'abonner au canal" : 'Suivre', 'subscribe', Icons.person_add_alt_1_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Action du bouton', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: options.map((opt) {
              final isSelected = _selectedActionType == opt.$2;
              return FilterChip(
                avatar: Icon(opt.$3, size: 16, color: isSelected ? Colors.white : _c.textSecondary),
                label: Text(opt.$1, style: TextStyle(color: isSelected ? Colors.white : _c.textSecondary, fontSize: 12)),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedActionType = opt.$2),
                selectedColor: _red,
                backgroundColor: _c.surfaceVariant,
                checkmarkColor: Colors.white,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryCard() {
    String displayMsg;
    if (_selectAllCountries) {
      displayMsg = '🌍 Tous les pays (${AfricanCountry.allCountries.length})';
    } else if (_selectedCountries.isEmpty) {
      displayMsg = '⚠️ Aucun pays sélectionné';
    } else {
      displayMsg = '${_selectedCountries.length} pays sélectionné(s)';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedCountries.isEmpty && !_selectAllCountries ? Colors.orange : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.public, color: _red, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Visibilité', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold)),
              Text(displayMsg,
                style: TextStyle(
                  color: _selectedCountries.isEmpty && !_selectAllCountries ? Colors.orange : _c.textSecondary,
                  fontSize: 13)),
            ])),
          ]),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showCountrySelection = true),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Choisir les pays'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryModal() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            decoration: BoxDecoration(
              color: _c.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(child: Text('Sélectionner les pays',
                        style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 16))),
                      IconButton(
                        icon: Icon(Icons.close, color: _c.textSecondary),
                        onPressed: () => setState(() => _showCountrySelection = false),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  value: _selectAllCountries,
                  onChanged: (v) => setState(() { _selectAllCountries = v; if (v) _selectedCountries.clear(); }),
                  title: Text('Tous les pays', style: TextStyle(color: _c.textPrimary)),
                  activeColor: _red,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _countrySearchController,
                    focusNode: _countrySearchFocus,
                    style: TextStyle(color: _c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un pays...',
                      hintStyle: TextStyle(color: _c.textSecondary),
                      prefixIcon: Icon(Icons.search, color: _c.textSecondary),
                      filled: true, fillColor: _c.surfaceVariant,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredCountries.length,
                    itemBuilder: (_, i) {
                      final country = _filteredCountries[i];
                      final isSelected = _selectedCountries.any((c) => c.code == country.code);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: _selectAllCountries ? null : (v) {
                          setState(() {
                            if (v == true) _selectedCountries.add(country);
                            else _selectedCountries.removeWhere((c) => c.code == country.code);
                          });
                        },
                        title: Text('${country.flag} ${country.name}',
                          style: TextStyle(color: _selectAllCountries ? _c.textSecondary : _c.textPrimary, fontSize: 14)),
                        activeColor: _red,
                        checkColor: Colors.white,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showCountrySelection = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _selectAllCountries
                          ? 'Confirmer — Tous les pays'
                          : 'Confirmer (${_selectedCountries.length} pays)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
