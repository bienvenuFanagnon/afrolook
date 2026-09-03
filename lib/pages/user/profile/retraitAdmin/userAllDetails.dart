// pages/admin/user_management_page.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../widgets/interests_selector_widget.dart';
import '../../mes_gains_post_page.dart';
import '../../userTransactionListe.dart';

// ── Palette admin ────────────────────────────────────────────────────────────
const _bg      = Color(0xFF0D0D14);
const _surface = Color(0xFF16161F);
const _card    = Color(0xFF1C1C27);
const _border  = Color(0xFF2A2A3A);
const _gold    = Color(0xFFF0B429);
const _green   = Color(0xFF34C759);
const _amber   = Color(0xFFFF9F0A);
const _blue    = Color(0xFF3B82F6);
const _red     = Color(0xFFFF453A);
const _textP   = Color(0xFFE8E8F0);
const _textS   = Color(0xFF8891A6);

class UserManagementPage extends StatefulWidget {
  final String userId;
  const UserManagementPage({Key? key, required this.userId}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _firestore = FirebaseFirestore.instance;
  UserData? _userData;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _infoExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _firestore.collection('Users').doc(widget.userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        setState(() { _userData = UserData.fromJson(data); _isLoading = false; });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      printVm('Erreur chargement user: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Opérations solde FCFA ─────────────────────────────────────────────────

  Future<void> _updateUserBalance(
    double amount, String type, String description, String raison, {
    String balanceField = 'votre_solde_principal',
  }) async {
    if (_userData == null) return;
    final adminId = Provider.of<UserAuthProvider>(context, listen: false).userId;
    setState(() => _isUpdating = true);
    try {
      final current = balanceField == 'votre_solde_depot'
          ? (_userData!.votre_solde_depot ?? 0.0)
          : (_userData!.votre_solde_principal ?? 0.0);
      final newBal = current + amount;

      await _firestore.collection('Users').doc(widget.userId).update({
        balanceField: newBal,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      await _firestore.collection('TransactionSoldes').add({
        'user_id': _userData!.id,
        'montant': amount.abs(),
        'type': type,
        'description': description,
        'raison': raison,
        'balance_field': balanceField,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
        'processed_by': adminId,
      });
      setState(() {
        if (balanceField == 'votre_solde_depot') {
          _userData!.votre_solde_depot = newBal;
        } else {
          _userData!.votre_solde_principal = newBal;
        }
      });
      _showSnack('Opération effectuée !', _green);
    } catch (e) {
      _showSnack('Erreur : $e', _red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // ── Opérations pièces ─────────────────────────────────────────────────────

  Future<void> _updateCoinsBalance(int amount, String raison) async {
    if (_userData == null) return;
    final adminId = Provider.of<UserAuthProvider>(context, listen: false).userId;
    setState(() => _isUpdating = true);
    try {
      await _firestore.collection('Users').doc(widget.userId).update({
        'giftCoinsBalance': FieldValue.increment(amount),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      await _firestore.collection('TransactionSoldes').add({
        'user_id': _userData!.id,
        'montant': amount.abs(),
        'type': amount > 0 ? 'GAIN_PIECES' : 'DEBIT_PIECES',
        'description': amount > 0 ? 'Crédit pièces (admin)' : 'Débit pièces (admin)',
        'raison': raison,
        'balance_field': 'giftCoinsBalance',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
        'processed_by': adminId,
      });
      setState(() {
        _userData!.giftCoinsBalance = (_userData!.giftCoinsBalance ?? 0) + amount;
      });
      _showSnack('${amount > 0 ? '+' : ''}$amount pièce(s) appliqués !', _gold);
    } catch (e) {
      _showSnack('Erreur : $e', _red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showBalanceDialog({required bool isDeposit, required String field}) {
    final montantCtrl     = TextEditingController();
    final raisonCtrl      = TextEditingController();
    final descCtrl        = TextEditingController();
    final isDepotField    = field == 'votre_solde_depot';
    final color           = isDeposit ? _green : _amber;
    final label           = isDepotField ? 'Dépôt' : 'Gains';

    showDialog(
      context: context,
      builder: (_) => _AdminDialog(
        title: isDeposit ? 'Dépôt — Solde $label' : 'Retrait — Solde $label',
        accentColor: color,
        icon: isDeposit ? Iconsax.add_circle : Iconsax.minus_cirlce,
        currentAmount: isDepotField
            ? (_userData!.votre_solde_depot ?? 0).toStringAsFixed(2)
            : (_userData!.votre_solde_principal ?? 0).toStringAsFixed(2),
        unit: 'FCFA',
        onConfirm: (montant, raison, desc) {
          final val = double.tryParse(montant) ?? 0;
          if (val <= 0) return;
          _updateUserBalance(
            isDeposit ? val : -val,
            isDeposit ? TypeTransaction.DEPOTADMIN.name : TypeTransaction.RETRAITADMIN.name,
            desc.isNotEmpty ? desc : (isDeposit ? 'Dépôt administratif' : 'Retrait administratif'),
            raison,
            balanceField: field,
          );
        },
        montantCtrl: montantCtrl,
        raisonCtrl: raisonCtrl,
        descCtrl: descCtrl,
      ),
    );
  }

  void _showCoinsDialog({required bool isDeposit}) {
    final montantCtrl = TextEditingController();
    final raisonCtrl  = TextEditingController();
    final descCtrl    = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => _AdminDialog(
        title: isDeposit ? 'Crédit pièces' : 'Débit pièces',
        accentColor: _gold,
        icon: isDeposit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
        currentAmount: (_userData!.giftCoinsBalance ?? 0).toString(),
        unit: 'pièces',
        onConfirm: (montant, raison, desc) {
          final val = int.tryParse(montant) ?? 0;
          if (val <= 0) return;
          _updateCoinsBalance(isDeposit ? val : -val, raison);
        },
        montantCtrl: montantCtrl,
        raisonCtrl: raisonCtrl,
        descCtrl: descCtrl,
        isInt: true,
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatDate(int ts) {
    if (ts == 0) return '—';
    final ms = ts > 9999999999999 ? ts ~/ 1000 : ts;
    return DateFormat('dd MMM yyyy  HH:mm', 'fr').format(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _gold)),
      );
    }
    if (_userData == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: _bg, foregroundColor: _textP),
        body: const Center(
          child: Text('Utilisateur introuvable', style: TextStyle(color: _textS)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  _buildBalancesSection(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 16),
                  _buildInfoSection(),
                  if ((_userData!.interests ?? []).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildInterestsCard(),
                  ],
                ],
              ),
            ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final pseudo = _userData?.pseudo ?? widget.userId;
    return AppBar(
      backgroundColor: _surface,
      foregroundColor: _textP,
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('@$pseudo',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textP)),
          Text('Gestion utilisateur',
              style: const TextStyle(fontSize: 11, color: _textS, fontWeight: FontWeight.w400)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Iconsax.refresh, size: 20),
          tooltip: 'Actualiser',
          onPressed: () { setState(() => _isLoading = true); _loadUserData(); },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 22),
          color: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (v) {
            if (v == 'transactions') {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => UserTransactionsPage(userId: widget.userId)));
            } else if (v == 'monetisation') {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => MesGainsPage(userId: widget.userId, isAdminView: true)));
            } else if (v == 'profil') {
              showUserDetailsModalDialog(
                _userData!, MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height, context);
            } else if (v == 'copier') {
              Clipboard.setData(ClipboardData(text: widget.userId));
              _showSnack('ID copié', _blue);
            }
          },
          itemBuilder: (_) => [
            _menuItem('profil',       Icons.person_outline,        'Voir le profil'),
            _menuItem('transactions', Iconsax.receipt,             'Transactions'),
            _menuItem('monetisation', Iconsax.money,               'Monétisation posts'),
            const PopupMenuDivider(),
            _menuItem('copier',       Icons.copy_rounded,          'Copier l\'ID utilisateur'),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: _textS),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: _textP, fontSize: 14)),
      ]),
    );
  }

  // ── Profil ────────────────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    final isBlocked  = _userData!.isBlocked == true;
    final isVerified = _userData!.isVerify  == true;
    final role       = _userData!.role ?? '';
    final imgUrl     = _userData!.imageUrl ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isBlocked ? _red : _gold, width: 2.5),
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: _surface,
              backgroundImage: imgUrl.isNotEmpty ? NetworkImage(imgUrl) : null,
              child: imgUrl.isEmpty ? const Icon(Icons.person, size: 36, color: _textS) : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData!.pseudo ?? '—',
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _textP, height: 1.1),
                ),
                const SizedBox(height: 3),
                if ((_userData!.email ?? '').isNotEmpty)
                  Text(_userData!.email!, style: const TextStyle(fontSize: 12, color: _textS)),
                if ((_userData!.numeroDeTelephone ?? '').isNotEmpty)
                  Text(_userData!.numeroDeTelephone!, style: const TextStyle(fontSize: 12, color: _textS)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _StatusChip(
                    label: isVerified ? 'Vérifié' : 'Non vérifié',
                    color: isVerified ? _green : _textS,
                    icon: isVerified ? Icons.verified_rounded : Icons.help_outline_rounded,
                  ),
                  _StatusChip(
                    label: isBlocked ? 'Bloqué' : 'Actif',
                    color: isBlocked ? _red : _green,
                    icon: isBlocked ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                  ),
                  if (role.isNotEmpty)
                    _StatusChip(
                      label: role == 'ADM' ? 'Admin' : role,
                      color: _gold,
                      icon: Icons.shield_outlined,
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Soldes ────────────────────────────────────────────────────────────────

  Widget _buildBalancesSection() {
    final depot    = _userData!.votre_solde_depot    ?? 0.0;
    final gains    = _userData!.votre_solde_principal ?? 0.0;
    final pieces   = _userData!.giftCoinsBalance     ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SOLDES'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _BalanceCard(
            label: 'Dépôt',
            amount: depot.toStringAsFixed(2),
            unit: 'FCFA',
            accentColor: _green,
            isNegative: depot < 0,
            onAdd:    () => _showBalanceDialog(isDeposit: true,  field: 'votre_solde_depot'),
            onRemove: () => _showBalanceDialog(isDeposit: false, field: 'votre_solde_depot'),
          )),
          const SizedBox(width: 12),
          Expanded(child: _BalanceCard(
            label: 'Gains',
            amount: gains.toStringAsFixed(2),
            unit: 'FCFA',
            accentColor: _amber,
            isNegative: gains < 0,
            onAdd:    () => _showBalanceDialog(isDeposit: true,  field: 'votre_solde_principal'),
            onRemove: () => _showBalanceDialog(isDeposit: false, field: 'votre_solde_principal'),
          )),
        ]),
        const SizedBox(height: 12),
        _BalanceCard(
          label: 'Pièces',
          amount: '$pieces',
          unit: 'pièces',
          accentColor: _gold,
          emoji: '🪙',
          isNegative: false,
          onAdd:    () => _showCoinsDialog(isDeposit: true),
          onRemove: () => _showCoinsDialog(isDeposit: false),
        ),
      ],
    );
  }

  // ── Statistiques ──────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final abonnes = (_userData!.userAbonnesIds ?? []).length;
    final pubs    = _userData!.mesPubs ?? 0;
    final likes   = _userData!.likes   ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('STATISTIQUES'),
        const SizedBox(height: 10),
        Row(children: [
          _StatCell(label: 'Abonnés',      value: _fmtNum(abonnes), icon: Iconsax.people),
          const SizedBox(width: 10),
          _StatCell(label: 'Publications', value: _fmtNum(pubs),    icon: Iconsax.gallery),
          const SizedBox(width: 10),
          _StatCell(label: 'Likes',        value: _fmtNum(likes),   icon: Iconsax.heart),
        ]),
      ],
    );
  }

  // ── Informations ──────────────────────────────────────────────────────────

  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // En-tête cliquable
          InkWell(
            onTap: () => setState(() => _infoExpanded = !_infoExpanded),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                _sectionLabel('INFORMATIONS', inline: true),
                const Spacer(),
                Icon(
                  _infoExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: _textS, size: 22,
                ),
              ]),
            ),
          ),
          if (_infoExpanded) ...[
            Divider(color: _border, height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _InfoRow('Nom complet',    '${_userData!.nom ?? ''} ${_userData!.prenom ?? ''}'.trim()),
                  _InfoRow('Genre',          _userData!.genre ?? '—'),
                  _InfoRow('Adresse',        _userData!.adresse ?? '—'),
                  _InfoRow('Code parrainage',_userData!.codeParrainage ?? '—'),
                  _InfoRow('Code parrain',   _userData!.codeParrain ?? '—'),
                  _InfoRow('Rôle',           _userData!.role?.isNotEmpty == true ? _userData!.role! : 'Utilisateur'),
                  _InfoRow('Créé le',        _formatDate(_userData!.createdAt ?? 0)),
                  _InfoRow('Dernière activité', _formatDate(_userData!.last_time_active ?? 0)),
                  _InfoRow('ID',             widget.userId, mono: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Intérêts ──────────────────────────────────────────────────────────────

  Widget _buildInterestsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('CENTRES D\'INTÉRÊT'),
          const SizedBox(height: 12),
          InterestsDisplayWidget(codes: _userData!.interests ?? [], compact: true),
        ],
      ),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, {bool inline = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: _textS,
        height: inline ? 1 : null,
      ),
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Composants réutilisables ─────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color  color;
  final IconData icon;
  const _StatusChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final String amount;
  final String unit;
  final Color  accentColor;
  final String? emoji;
  final bool   isNegative;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _BalanceCard({
    required this.label,
    required this.amount,
    required this.unit,
    required this.accentColor,
    required this.isNegative,
    required this.onAdd,
    required this.onRemove,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = isNegative ? _red : accentColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNegative ? _red.withOpacity(0.4) : displayColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + boutons
          Row(children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(label.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: _textS,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const Spacer(),
            _ActionBtn(icon: Icons.remove_rounded, color: displayColor, onTap: onRemove),
            const SizedBox(width: 4),
            _ActionBtn(icon: Icons.add_rounded,    color: displayColor, onTap: onAdd,  filled: true),
          ]),
          const SizedBox(height: 10),
          // Montant
          Text(
            amount,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: displayColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(unit,
              style: const TextStyle(fontSize: 11, color: _textS, fontWeight: FontWeight.w500)),
          if (isNegative)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: const [
                Icon(Icons.warning_amber_rounded, size: 12, color: _red),
                SizedBox(width: 4),
                Text('Solde négatif', style: TextStyle(fontSize: 10, color: _red)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;
  final bool     filled;
  const _ActionBtn({required this.icon, required this.color, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(filled ? 0 : 0.3)),
        ),
        child: Icon(icon, size: 16, color: filled ? Colors.white : color),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCell({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: _textS),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: _textP, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: _textS),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   mono;
  const _InfoRow(this.label, this.value, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: _textS, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 13,
                color: _textP,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog admin générique ────────────────────────────────────────────────────

class _AdminDialog extends StatelessWidget {
  final String     title;
  final Color      accentColor;
  final IconData   icon;
  final String     currentAmount;
  final String     unit;
  final bool       isInt;
  final Function(String montant, String raison, String desc) onConfirm;
  final TextEditingController montantCtrl;
  final TextEditingController raisonCtrl;
  final TextEditingController descCtrl;

  const _AdminDialog({
    required this.title,
    required this.accentColor,
    required this.icon,
    required this.currentAmount,
    required this.unit,
    required this.onConfirm,
    required this.montantCtrl,
    required this.raisonCtrl,
    required this.descCtrl,
    this.isInt = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              style: TextStyle(color: accentColor, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Text('Solde actuel', style: TextStyle(color: _textS, fontSize: 12)),
                const Spacer(),
                Text('$currentAmount $unit',
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
            const SizedBox(height: 14),
            _DialogField(
              controller: montantCtrl,
              label: 'Montant',
              hint: '0',
              keyboardType: isInt
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true),
              suffix: unit,
              accentColor: accentColor,
            ),
            const SizedBox(height: 10),
            _DialogField(
              controller: raisonCtrl,
              label: 'Raison *',
              hint: 'Motif obligatoire',
              accentColor: accentColor,
            ),
            const SizedBox(height: 10),
            _DialogField(
              controller: descCtrl,
              label: 'Description',
              hint: 'Optionnel',
              maxLines: 2,
              accentColor: accentColor,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: _textS)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () {
            if (raisonCtrl.text.trim().isEmpty) return;
            Navigator.pop(context);
            onConfirm(montantCtrl.text.trim(), raisonCtrl.text.trim(), descCtrl.text.trim());
          },
          child: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? suffix;
  final int maxLines;
  final TextInputType keyboardType;
  final Color accentColor;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.accentColor,
    this.suffix,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _textS, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: _textP, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _textS, fontSize: 13),
            suffixText: suffix,
            suffixStyle: TextStyle(color: accentColor, fontWeight: FontWeight.w600),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor.withOpacity(0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
