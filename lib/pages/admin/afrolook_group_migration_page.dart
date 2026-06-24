import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/utils/afrolook_defaults.dart';
import '../../theme/app_colors.dart';

/// Page admin : gestion de tous les groupes officiels Afrolook.
/// Créer de nouveaux groupes officiels + migrer tous les utilisateurs.
class AfrolookGroupMigrationPage extends StatefulWidget {
  const AfrolookGroupMigrationPage({super.key});

  @override
  State<AfrolookGroupMigrationPage> createState() =>
      _AfrolookGroupMigrationPageState();
}

class _AfrolookGroupMigrationPageState
    extends State<AfrolookGroupMigrationPage> {
  late AppColors _colors;

  // ── Groupe Afrolook principal ───────────────────────────────────────────────
  bool _groupExists = false;
  bool _checkingGroup = true;
  Map<String, dynamic>? _groupData;

  // ── Groupes officiels (tous) ────────────────────────────────────────────────
  List<Map<String, dynamic>> _officialGroups = [];
  bool _loadingOfficialGroups = false;

  // ── Migration utilisateurs (par groupe) ────────────────────────────────────
  String? _migratingGroupId;
  int _processedUsers = 0;
  int _totalUsers = 0;
  int _alreadyMember = 0;
  int _newlyAdded = 0;
  String _statusMessage = '';
  bool _migrationDone = false;

  // ── Création d'un nouveau groupe officiel ─────────────────────────────────
  final _newGroupNameCtrl = TextEditingController();
  final _newGroupDescCtrl = TextEditingController();
  bool _creatingGroup = false;
  String _createStatus = '';

  // ── Correction des noms en doublon ─────────────────────────────────────────
  bool _fixingNames = false;
  int _renamedCount = 0;
  String _fixStatus = '';
  bool _fixDone = false;

  // ── Migration admins → Gold à vie ──────────────────────────────────────────
  bool _migratingAdmins = false;
  int _adminsUpdated = 0;
  String _adminGoldStatus = '';
  bool _adminGoldDone = false;

  @override
  void initState() {
    super.initState();
    _checkGroupExists();
    _loadOfficialGroups();
  }

  @override
  void dispose() {
    _newGroupNameCtrl.dispose();
    _newGroupDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkGroupExists() async {
    setState(() => _checkingGroup = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(kAfrolookGroupId)
          .get();
      if (mounted) {
        setState(() {
          _groupExists = doc.exists;
          _groupData = doc.data();
          _checkingGroup = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingGroup = false);
    }
  }

  Future<void> _loadOfficialGroups() async {
    setState(() => _loadingOfficialGroups = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('GroupChats')
          .where('is_official', isEqualTo: true)
          .get();
      if (mounted) {
        setState(() {
          _officialGroups = snap.docs
              .map((d) => {'__id': d.id, ...d.data()})
              .toList()
            ..sort((a, b) =>
                (a['created_at'] as int? ?? 0)
                    .compareTo(b['created_at'] as int? ?? 0));
          _loadingOfficialGroups = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOfficialGroups = false);
    }
  }

  Future<void> _createAfrolookGroup() async {
    final auth = context.read<UserAuthProvider>();
    final myId = auth.loginUserData.id ?? '';
    final myPseudo = auth.loginUserData.pseudo ?? '';
    final myImage = auth.loginUserData.imageUrl ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = FirebaseFirestore.instance;

    setState(() {
      _migratingGroupId = kAfrolookGroupId;
      _statusMessage = 'Création du groupe Afrolook...';
    });

    try {
      await db.collection('GroupChats').doc(kAfrolookGroupId).set({
        'id': kAfrolookGroupId,
        'name': kAfrolookGroupName,
        'description':
            'Groupe officiel Afrolook — actualités, mises à jour et annonces de la plateforme.',
        'image_url': null,
        'owner_id': myId,
        'member_ids': [myId],
        'member_count': 1,
        'is_frozen': false,
        'is_private': false,
        'subscription_price': 0.0,
        'join_code': null,
        'join_code_expires_at': null,
        'paid_subscribers': {},
        'created_at': now,
        'updated_at': now,
        'last_message': '🎉 Groupe officiel Afrolook créé',
        'last_message_at': now,
        'ephemeral_duration': 0,
        'default_can_write': false,
        'default_can_share': true,
        'is_official': true,
        'cannot_leave': true,
      });

      await db.collection('GroupKeys').doc(kAfrolookGroupId).set({
        'group_id': kAfrolookGroupId,
        'key_data': DateTime.now().microsecondsSinceEpoch.toRadixString(16) * 2,
        'created_at': now,
      });

      await db
          .collection('GroupChats')
          .doc(kAfrolookGroupId)
          .collection('members')
          .doc(myId)
          .set({
        'user_id': myId,
        'pseudo': myPseudo,
        'image_url': myImage,
        'role': 'owner',
        'joined_at': now,
      });

      final msgId = db.collection('GroupMessages').doc().id;
      await db.collection('GroupMessages').doc(msgId).set({
        'id': msgId,
        'group_id': kAfrolookGroupId,
        'send_by': 'system',
        'message': '🎉 Bienvenue dans le groupe officiel Afrolook !',
        'message_type': 'text',
        'is_valide': true,
        'is_encrypted': false,
        'create_at_time_spam': now,
        'message_state': 'LU',
      });

      if (mounted) {
        setState(() {
          _groupExists = true;
          _migratingGroupId = null;
          _statusMessage = '✅ Groupe créé avec succès !';
        });
        await _checkGroupExists();
        await _loadOfficialGroups();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _migratingGroupId = null;
          _statusMessage = '❌ Erreur : $e';
        });
      }
    }
  }

  Future<void> _createNewOfficialGroup() async {
    final name = _newGroupNameCtrl.text.trim();
    if (name.isEmpty) return;

    final auth = context.read<UserAuthProvider>();
    final myId = auth.loginUserData.id ?? '';
    final myPseudo = auth.loginUserData.pseudo ?? '';
    final myImage = auth.loginUserData.imageUrl ?? '';
    final desc = _newGroupDescCtrl.text.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = FirebaseFirestore.instance;

    // Vérifier unicité du nom
    final existing = await db
        .collection('GroupChats')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    if (!mounted) return;
    if (existing.docs.isNotEmpty) {
      setState(() => _createStatus = '❌ Ce nom est déjà pris — choisissez un autre.');
      return;
    }

    setState(() {
      _creatingGroup = true;
      _createStatus = 'Création du groupe "$name"...';
    });

    try {
      final newDocRef = db.collection('GroupChats').doc();
      final groupId = newDocRef.id;

      await newDocRef.set({
        'id': groupId,
        'name': name,
        'description': desc.isEmpty
            ? 'Groupe officiel Afrolook — $name'
            : desc,
        'image_url': null,
        'owner_id': myId,
        'member_ids': [myId],
        'member_count': 1,
        'is_frozen': false,
        'is_private': false,
        'subscription_price': 0.0,
        'join_code': null,
        'join_code_expires_at': null,
        'paid_subscribers': {},
        'created_at': now,
        'updated_at': now,
        'last_message': '🎉 Groupe officiel "$name" créé',
        'last_message_at': now,
        'ephemeral_duration': 0,
        'default_can_write': false,
        'default_can_share': true,
        'is_official': true,
        'cannot_leave': true,
      });

      await db.collection('GroupKeys').doc(groupId).set({
        'group_id': groupId,
        'key_data': DateTime.now().microsecondsSinceEpoch.toRadixString(16) * 2,
        'created_at': now,
      });

      await newDocRef.collection('members').doc(myId).set({
        'user_id': myId,
        'pseudo': myPseudo,
        'image_url': myImage,
        'role': 'owner',
        'joined_at': now,
      });

      final msgId = db.collection('GroupMessages').doc().id;
      await db.collection('GroupMessages').doc(msgId).set({
        'id': msgId,
        'group_id': groupId,
        'send_by': 'system',
        'message': '🎉 Bienvenue dans le groupe officiel "$name" !',
        'message_type': 'text',
        'is_valide': true,
        'is_encrypted': false,
        'create_at_time_spam': now,
        'message_state': 'LU',
      });

      if (mounted) {
        _newGroupNameCtrl.clear();
        _newGroupDescCtrl.clear();
        setState(() {
          _creatingGroup = false;
          _createStatus = '✅ Groupe "$name" créé avec succès !';
        });
        await _loadOfficialGroups();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creatingGroup = false;
          _createStatus = '❌ Erreur : $e';
        });
      }
    }
  }

  Future<void> _migrateAllUsers(String groupId) async {
    setState(() {
      _migratingGroupId = groupId;
      _processedUsers = 0;
      _totalUsers = 0;
      _alreadyMember = 0;
      _newlyAdded = 0;
      _migrationDone = false;
      _statusMessage = 'Comptage des utilisateurs...';
    });

    final db = FirebaseFirestore.instance;

    try {
      final groupDoc = await db.collection('GroupChats').doc(groupId).get();
      final existingIds =
          (groupDoc.data()?['member_ids'] as List<dynamic>? ?? [])
              .cast<String>()
              .toSet();

      final countSnap = await db.collection('Users').count().get();
      final total = countSnap.count ?? 0;
      if (mounted) setState(() { _totalUsers = total; _statusMessage = 'Migration de $total utilisateurs...'; });

      const batchSize = 100;
      DocumentSnapshot? lastDoc;
      int processed = 0;

      while (true) {
        Query query = db.collection('Users').limit(batchSize);
        if (lastDoc != null) query = query.startAfterDocument(lastDoc);

        final snap = await query.get();
        if (snap.docs.isEmpty) break;

        lastDoc = snap.docs.last;

        final batch = db.batch();
        final now = DateTime.now().millisecondsSinceEpoch;
        final newIds = <String>[];

        for (final doc in snap.docs) {
          final userId = doc.id;
          final ud = doc.data() as Map<String, dynamic>;

          if (existingIds.contains(userId)) {
            _alreadyMember++;
          } else {
            final memberRef = db
                .collection('GroupChats')
                .doc(groupId)
                .collection('members')
                .doc(userId);
            batch.set(memberRef, {
              'user_id': userId,
              'pseudo': ud['pseudo'] ?? '',
              'image_url': ud['imageUrl'] ?? '',
              'role': 'member',
              'joined_at': now,
            });
            newIds.add(userId);
            existingIds.add(userId);
            _newlyAdded++;
          }
          processed++;
        }

        await batch.commit();

        if (newIds.isNotEmpty) {
          await db.collection('GroupChats').doc(groupId).update({
            'member_ids': FieldValue.arrayUnion(newIds),
            'member_count': FieldValue.increment(newIds.length),
          });
        }

        if (mounted) {
          setState(() {
            _processedUsers = processed;
            _statusMessage =
                '$processed / $total traités · +$_newlyAdded ajoutés';
          });
        }

        if (snap.docs.length < batchSize) break;
      }

      if (mounted) {
        setState(() {
          _migratingGroupId = null;
          _migrationDone = true;
          _statusMessage =
              '✅ Migration terminée : $_newlyAdded ajoutés, $_alreadyMember déjà membres.';
        });
        if (groupId == kAfrolookGroupId) await _checkGroupExists();
        await _loadOfficialGroups();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _migratingGroupId = null;
          _statusMessage = '❌ Erreur : $e';
        });
      }
    }
  }

  Future<void> _migrateAdminsToGoldForLife() async {
    setState(() {
      _migratingAdmins = true;
      _adminsUpdated = 0;
      _adminGoldDone = false;
      _adminGoldStatus = 'Recherche des comptes admin...';
    });

    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final dateFinGold = DateTime(2099, 12, 31, 23, 59, 59);

    final goldAbonnement = {
      'type': 'gold',
      'prix': 0.0,
      'dateDebut': now.toIso8601String(),
      'dateFin': dateFinGold.toIso8601String(),
      'estActif': true,
      'transactionId': 'admin_lifetime',
      'dureeMois': 0,
      'montantPaye': 0.0,
      'methodePaiement': 'admin',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'avantagesActives': AfrolookAbonnement.getAvantagesGold(),
    };

    try {
      final adminSnap = await db
          .collection('Users')
          .where('role', isEqualTo: 'ADM')
          .get();

      final admins = adminSnap.docs;
      if (admins.isEmpty) {
        if (mounted) setState(() {
          _migratingAdmins = false;
          _adminGoldDone = true;
          _adminGoldStatus = '✅ Aucun compte admin trouvé.';
        });
        return;
      }

      if (mounted) setState(() => _adminGoldStatus = '${admins.length} admin(s) trouvé(s) — mise à jour en cours...');

      int updated = 0;
      for (final doc in admins) {
        await db.collection('Users').doc(doc.id).update({
          'abonnement': goldAbonnement,
        });
        updated++;
        if (mounted) setState(() {
          _adminsUpdated = updated;
          _adminGoldStatus = '$updated / ${admins.length} admin(s) mis à jour...';
        });
      }

      if (mounted) setState(() {
        _migratingAdmins = false;
        _adminGoldDone = true;
        _adminGoldStatus = '✅ $updated compte(s) admin passé(s) au plan Gold à vie (jusqu\'au 31/12/2099).';
      });
    } catch (e) {
      if (mounted) setState(() {
        _migratingAdmins = false;
        _adminGoldStatus = '❌ Erreur : $e';
      });
    }
  }

  Future<void> _fixDuplicateGroupNames() async {
    setState(() {
      _fixingNames = true;
      _renamedCount = 0;
      _fixDone = false;
      _fixStatus = 'Chargement de tous les groupes...';
    });

    final db = FirebaseFirestore.instance;

    try {
      final allGroups = <Map<String, dynamic>>[];
      DocumentSnapshot? lastDoc;
      while (true) {
        Query q = db.collection('GroupChats').orderBy('created_at').limit(100);
        if (lastDoc != null) q = q.startAfterDocument(lastDoc);
        final snap = await q.get();
        if (snap.docs.isEmpty) break;
        for (final doc in snap.docs) {
          allGroups.add({'__id': doc.id, ...doc.data() as Map<String, dynamic>});
        }
        lastDoc = snap.docs.last;
        if (snap.docs.length < 100) break;
      }

      if (mounted) setState(() => _fixStatus = '${allGroups.length} groupes chargés — recherche des doublons...');

      final byName = <String, List<Map<String, dynamic>>>{};
      for (final g in allGroups) {
        final name = (g['name'] as String? ?? '').trim();
        byName.putIfAbsent(name, () => []).add(g);
      }

      int renamed = 0;
      for (final entry in byName.entries) {
        final duplicates = entry.value;
        if (duplicates.length <= 1) continue;

        for (int i = 1; i < duplicates.length; i++) {
          final group = duplicates[i];
          final groupId = group['__id'] as String;
          final baseName = entry.key;

          String newName = '';
          for (int suffix = 1; suffix <= 99; suffix++) {
            final candidate = '${baseName}_${suffix.toString().padLeft(2, '0')}';
            if (!byName.containsKey(candidate)) {
              newName = candidate;
              byName[candidate] = [group];
              break;
            }
          }
          if (newName.isEmpty) continue;

          await db.collection('GroupChats').doc(groupId).update({'name': newName});
          renamed++;
          if (mounted) setState(() {
            _renamedCount = renamed;
            _fixStatus = 'Renommage en cours... $renamed groupe(s) corrigé(s)';
          });
        }
      }

      if (mounted) setState(() {
        _fixingNames = false;
        _fixDone = true;
        _fixStatus = renamed == 0
            ? '✅ Aucun doublon trouvé — tous les noms sont uniques.'
            : '✅ Terminé : $renamed groupe(s) renommé(s) avec succès.';
      });
    } catch (e) {
      if (mounted) setState(() {
        _fixingNames = false;
        _fixStatus = '❌ Erreur : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: _colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Groupes officiels Afrolook',
          style: TextStyle(
              color: _colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _colors.primary),
            onPressed: () {
              _checkGroupExists();
              _loadOfficialGroups();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkGroupExists();
          await _loadOfficialGroups();
        },
        color: _colors.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Status groupe principal ─────────────────────────────────────
            _GroupStatusCard(
              groupExists: _groupExists,
              groupData: _groupData,
              checking: _checkingGroup,
              colors: _colors,
            ),
            const SizedBox(height: 20),

            // ── Créer groupe principal (si pas encore créé) ─────────────────
            if (!_checkingGroup && !_groupExists) ...[
              _SectionTitle('Étape 1 — Créer le groupe principal', _colors),
              const SizedBox(height: 10),
              _InfoBox(
                icon: Icons.info_outline_rounded,
                text:
                    'Le groupe "Afrolook" sera créé avec l\'ID fixe "$kAfrolookGroupId". '
                    'Seuls les admins pourront écrire. Les membres ne peuvent pas quitter ce groupe.',
                colors: _colors,
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'Créer le groupe Afrolook',
                icon: Icons.group_add_rounded,
                color: _colors.primary,
                loading: _migratingGroupId == kAfrolookGroupId,
                onPressed: _createAfrolookGroup,
              ),
            ],

            // ── Section : tous les groupes officiels ────────────────────────
            _SectionTitle('Groupes officiels', _colors),
            const SizedBox(height: 10),

            if (_loadingOfficialGroups)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_officialGroups.isEmpty)
              _InfoBox(
                icon: Icons.info_outline_rounded,
                text: 'Aucun groupe officiel trouvé.',
                colors: _colors,
              )
            else
              ...(_officialGroups.map((group) {
                final gId = group['__id'] as String;
                final gName = group['name'] as String? ?? gId;
                final gMembers = group['member_count'] as int? ?? 0;
                final isMigratingThis = _migratingGroupId == gId;
                return _OfficialGroupCard(
                  groupId: gId,
                  name: gName,
                  memberCount: gMembers,
                  isMigrating: isMigratingThis,
                  migrationDone: _migrationDone && _migratingGroupId == null && _officialGroups.any((g) => g['__id'] == gId),
                  statusMessage: isMigratingThis
                      ? _statusMessage
                      : (_migrationDone && _migratingGroupId == null ? _statusMessage : ''),
                  processedUsers: _processedUsers,
                  totalUsers: _totalUsers,
                  alreadyMember: _alreadyMember,
                  newlyAdded: _newlyAdded,
                  colors: _colors,
                  onMigrate: _migratingGroupId != null
                      ? null
                      : () => _migrateAllUsers(gId),
                );
              }).toList()),

            const SizedBox(height: 20),

            // ── Créer un nouveau groupe officiel ────────────────────────────
            _SectionTitle('Créer un nouveau groupe officiel', _colors),
            const SizedBox(height: 10),
            _InfoBox(
              icon: Icons.stars_rounded,
              text:
                  'Exemples : "Afrolook Pub", "Afrolook VIBE", "Afrolook MUSIC".\n'
                  'Ces groupes sont officiels (seuls les admins écrivent, on ne peut pas les quitter) '
                  'et peuvent cibler des messages par pays.',
              colors: _colors,
            ),
            const SizedBox(height: 12),
            _buildCreateGroupForm(),

            if (_createStatus.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _createStatus,
                style: TextStyle(
                  color: _createStatus.startsWith('✅')
                      ? const Color(0xFF1FAA59)
                      : _createStatus.startsWith('❌')
                          ? Colors.red
                          : _colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Migration admins → Gold à vie ───────────────────────────────
            _SectionTitle('Admins — Plan Gold à vie', _colors),
            const SizedBox(height: 10),
            _InfoBox(
              icon: Icons.workspace_premium_rounded,
              text: 'Attribue le plan Gold permanent (jusqu\'au 31/12/2099) à tous les comptes avec le rôle ADM.',
              colors: _colors,
            ),
            const SizedBox(height: 12),

            if (_migratingAdmins || _adminGoldDone) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _colors.border.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_migratingAdmins)
                      LinearProgressIndicator(
                        color: const Color(0xFFFFD700),
                        backgroundColor: const Color(0xFFFFD700).withOpacity(0.2),
                      ),
                    if (_adminGoldDone && _adminsUpdated > 0) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 16),
                        const SizedBox(width: 6),
                        Text('$_adminsUpdated admin(s) mis à jour',
                            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 6),
                    ],
                    const SizedBox(height: 4),
                    Text(_adminGoldStatus,
                        style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (!_migratingAdmins)
              _ActionButton(
                label: _adminGoldDone ? 'Relancer la migration' : 'Attribuer Gold à vie aux admins',
                icon: Icons.workspace_premium_rounded,
                color: const Color(0xFFB8860B),
                loading: false,
                onPressed: _migrateAdminsToGoldForLife,
              ),

            const SizedBox(height: 32),

            // ── Correction des noms en doublon ──────────────────────────────
            _SectionTitle('Corriger les noms en doublon', _colors),
            const SizedBox(height: 10),
            _InfoBox(
              icon: Icons.drive_file_rename_outline_rounded,
              text: 'Parcourt tous les groupes et renomme les doublons '
                  'en ajoutant _01, _02… Le groupe le plus ancien conserve son nom original.',
              colors: _colors,
            ),
            const SizedBox(height: 12),

            if (_fixingNames || _fixDone) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _colors.border.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_fixingNames) const LinearProgressIndicator(),
                    if (!_fixingNames && _fixDone && _renamedCount > 0) ...[
                      Text('Groupes renommés : $_renamedCount',
                          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                    ],
                    const SizedBox(height: 8),
                    Text(_fixStatus,
                        style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (!_fixingNames)
              _ActionButton(
                label: _fixDone ? 'Relancer la correction' : 'Corriger les noms en doublon',
                icon: Icons.auto_fix_high_rounded,
                color: const Color(0xFF7B3FA0),
                loading: false,
                onPressed: _fixDuplicateGroupNames,
              ),

            const SizedBox(height: 32),

            _InfoBox(
              icon: Icons.code_rounded,
              text: 'ID Firestore principal : $kAfrolookGroupId\n'
                  'Nom exact : $kAfrolookGroupName\n'
                  'Collection : GroupChats',
              colors: _colors,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateGroupForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.border.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _newGroupNameCtrl,
            style: TextStyle(color: _colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Nom du groupe officiel',
              labelStyle: TextStyle(color: _colors.textSecondary, fontSize: 13),
              hintText: 'ex: Afrolook Pub',
              hintStyle: TextStyle(color: _colors.textSecondary.withOpacity(0.5), fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _colors.border.withOpacity(0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _colors.border.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _colors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newGroupDescCtrl,
            style: TextStyle(color: _colors.textPrimary),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description (optionnel)',
              labelStyle: TextStyle(color: _colors.textSecondary, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _colors.border.withOpacity(0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _colors.border.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _colors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Créer le groupe officiel',
            icon: Icons.add_rounded,
            color: _colors.primary,
            loading: _creatingGroup,
            onPressed: _createNewOfficialGroup,
          ),
        ],
      ),
    );
  }
}

// ── Carte par groupe officiel ──────────────────────────────────────────────────

class _OfficialGroupCard extends StatelessWidget {
  final String groupId;
  final String name;
  final int memberCount;
  final bool isMigrating;
  final bool migrationDone;
  final String statusMessage;
  final int processedUsers;
  final int totalUsers;
  final int alreadyMember;
  final int newlyAdded;
  final AppColors colors;
  final VoidCallback? onMigrate;

  const _OfficialGroupCard({
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.isMigrating,
    required this.migrationDone,
    required this.statusMessage,
    required this.processedUsers,
    required this.totalUsers,
    required this.alreadyMember,
    required this.newlyAdded,
    required this.colors,
    required this.onMigrate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF185FA5).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded,
                    color: Color(0xFF185FA5), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    Text(
                      '$memberCount membres',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isMigrating && statusMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ProgressCard(
              processed: processedUsers,
              total: totalUsers,
              alreadyMember: alreadyMember,
              newlyAdded: newlyAdded,
              status: statusMessage,
              done: false,
              colors: colors,
            ),
          ],

          if (!isMigrating && migrationDone && statusMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(statusMessage,
                style: const TextStyle(color: Color(0xFF1FAA59), fontSize: 12)),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onMigrate,
              icon: isMigrating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.group_add_rounded, size: 16),
              label: Text(
                isMigrating ? 'Migration en cours...' : 'Migrer tous les utilisateurs',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF185FA5),
                side: const BorderSide(color: Color(0xFF185FA5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets locaux ─────────────────────────────────────────────────────────────

class _GroupStatusCard extends StatelessWidget {
  final bool groupExists, checking;
  final Map<String, dynamic>? groupData;
  final AppColors colors;

  const _GroupStatusCard({
    required this.groupExists,
    required this.groupData,
    required this.checking,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withOpacity(0.3)),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final memberCount = groupData?['member_count'] as int? ?? 0;
    final isGreen = groupExists;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGreen
            ? const Color(0xFF1FAA59).withOpacity(0.08)
            : Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGreen
              ? const Color(0xFF1FAA59).withOpacity(0.4)
              : Colors.orange.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isGreen ? const Color(0xFF1FAA59) : Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGreen ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGreen ? 'Groupe Afrolook principal ✅' : 'Groupe principal non créé',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (isGreen)
                  Text(
                    '$memberCount membres actuels',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  )
                else
                  Text(
                    'Créez le groupe avant de migrer',
                    style: const TextStyle(color: Colors.orange, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int processed, total, alreadyMember, newlyAdded;
  final String status;
  final bool done;
  final AppColors colors;

  const _ProgressCard({
    required this.processed,
    required this.total,
    required this.alreadyMember,
    required this.newlyAdded,
    required this.status,
    required this.done,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? processed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status,
              style: TextStyle(
                  color: done ? const Color(0xFF1FAA59) : colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done ? 1.0 : (total > 0 ? progress : null),
              minHeight: 6,
              backgroundColor: colors.border.withOpacity(0.2),
              color: done ? const Color(0xFF1FAA59) : const Color(0xFF185FA5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Stat(label: 'Traités', value: '$processed / $total', colors: colors),
              const SizedBox(width: 14),
              _Stat(label: 'Ajoutés', value: '+$newlyAdded', colors: colors, highlight: true),
              const SizedBox(width: 14),
              _Stat(label: 'Déjà membres', value: '$alreadyMember', colors: colors),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final AppColors colors;
  final bool highlight;

  const _Stat({required this.label, required this.value, required this.colors, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: highlight ? const Color(0xFF1FAA59) : colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final AppColors colors;

  const _SectionTitle(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final AppColors colors;
  final bool isWarning;

  const _InfoBox({
    required this.icon,
    required this.text,
    required this.colors,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? Colors.orange : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isWarning ? Colors.orange : colors.primary).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (isWarning ? Colors.orange : colors.primary).withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}
