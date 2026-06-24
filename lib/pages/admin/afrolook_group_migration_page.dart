import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../services/utils/afrolook_defaults.dart';
import '../../theme/app_colors.dart';

/// Page admin : création et migration du groupe officiel Afrolook.
/// Accessible depuis le tableau de bord admin uniquement.
class AfrolookGroupMigrationPage extends StatefulWidget {
  const AfrolookGroupMigrationPage({super.key});

  @override
  State<AfrolookGroupMigrationPage> createState() =>
      _AfrolookGroupMigrationPageState();
}

class _AfrolookGroupMigrationPageState
    extends State<AfrolookGroupMigrationPage> {
  late AppColors _colors;

  bool _groupExists = false;
  bool _checkingGroup = true;
  Map<String, dynamic>? _groupData;

  bool _migrating = false;
  int _processedUsers = 0;
  int _totalUsers = 0;
  int _alreadyMember = 0;
  int _newlyAdded = 0;
  String _statusMessage = '';
  bool _migrationDone = false;

  @override
  void initState() {
    super.initState();
    _checkGroupExists();
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

  Future<void> _createAfrolookGroup() async {
    final auth = context.read<UserAuthProvider>();
    final myId = auth.loginUserData.id ?? '';
    final myPseudo = auth.loginUserData.pseudo ?? '';
    final myImage = auth.loginUserData.imageUrl ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = FirebaseFirestore.instance;

    setState(() {
      _migrating = true;
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
        // Groupes officiels — seuls les admins peuvent écrire
        'default_can_write': false,
        'default_can_share': true,
        'is_official': true,
        'cannot_leave': true,
      });

      // Clé de chiffrement
      await db.collection('GroupKeys').doc(kAfrolookGroupId).set({
        'group_id': kAfrolookGroupId,
        'key_data': DateTime.now().microsecondsSinceEpoch.toRadixString(16) * 2,
        'created_at': now,
      });

      // Ajouter l'admin comme owner
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

      // Message système
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
          _migrating = false;
          _statusMessage = '✅ Groupe créé avec succès !';
        });
        await _checkGroupExists();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _migrating = false;
          _statusMessage = '❌ Erreur : $e';
        });
      }
    }
  }

  Future<void> _migrateAllUsers() async {
    setState(() {
      _migrating = true;
      _processedUsers = 0;
      _totalUsers = 0;
      _alreadyMember = 0;
      _newlyAdded = 0;
      _migrationDone = false;
      _statusMessage = 'Comptage des utilisateurs...';
    });

    final db = FirebaseFirestore.instance;

    try {
      // Récupérer les member_ids actuels
      final groupDoc =
          await db.collection('GroupChats').doc(kAfrolookGroupId).get();
      final existingIds =
          (groupDoc.data()?['member_ids'] as List<dynamic>? ?? [])
              .cast<String>()
              .toSet();

      // Compter les utilisateurs
      final countSnap = await db.collection('Users').count().get();
      final total = countSnap.count ?? 0;
      if (mounted) setState(() { _totalUsers = total; _statusMessage = 'Migration de $total utilisateurs...'; });

      // Traitement par batch de 100
      const batchSize = 100;
      DocumentSnapshot? lastDoc;
      int processed = 0;

      while (true) {
        Query query = db.collection('Users').limit(batchSize);
        if (lastDoc != null) query = query.startAfterDocument(lastDoc);

        final snap = await query.get();
        if (snap.docs.isEmpty) break;

        lastDoc = snap.docs.last;

        // Batch Firestore pour les membres à ajouter
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
                .doc(kAfrolookGroupId)
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

        // Commit le batch members
        await batch.commit();

        // Mettre à jour member_ids et member_count en une seule fois par batch
        if (newIds.isNotEmpty) {
          await db.collection('GroupChats').doc(kAfrolookGroupId).update({
            'member_ids': FieldValue.arrayUnion(newIds),
            'member_count': FieldValue.increment(newIds.length),
          });
        }

        if (mounted) {
          setState(() {
            _processedUsers = processed;
            _statusMessage =
                '$processed / $total utilisateurs traités · +$_newlyAdded ajoutés';
          });
        }

        if (snap.docs.length < batchSize) break;
      }

      if (mounted) {
        setState(() {
          _migrating = false;
          _migrationDone = true;
          _statusMessage =
              '✅ Migration terminée : $_newlyAdded ajoutés, $_alreadyMember déjà membres.';
        });
        await _checkGroupExists();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _migrating = false;
          _statusMessage = '❌ Erreur : $e';
        });
      }
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
          'Groupe Afrolook officiel',
          style: TextStyle(
              color: _colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _checkGroupExists,
        color: _colors.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Status carte groupe ─────────────────────────────────────────
            _GroupStatusCard(
              groupExists: _groupExists,
              groupData: _groupData,
              checking: _checkingGroup,
              colors: _colors,
            ),
            const SizedBox(height: 20),

            // ── Créer le groupe ─────────────────────────────────────────────
            if (!_checkingGroup && !_groupExists) ...[
              _SectionTitle('Étape 1 — Créer le groupe', _colors),
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
                loading: _migrating,
                onPressed: _createAfrolookGroup,
              ),
            ],

            // ── Migrer les utilisateurs ─────────────────────────────────────
            if (!_checkingGroup && _groupExists) ...[
              _SectionTitle('Migration des utilisateurs', _colors),
              const SizedBox(height: 10),
              _InfoBox(
                icon: Icons.warning_amber_rounded,
                text:
                    'Cette opération ajoute TOUS les utilisateurs existants au groupe Afrolook. '
                    'Les membres déjà présents sont ignorés. Opération idempotente — sûre à relancer.',
                colors: _colors,
                isWarning: true,
              ),
              const SizedBox(height: 12),

              // Progression
              if (_migrating || _migrationDone) ...[
                _ProgressCard(
                  processed: _processedUsers,
                  total: _totalUsers,
                  alreadyMember: _alreadyMember,
                  newlyAdded: _newlyAdded,
                  status: _statusMessage,
                  done: _migrationDone,
                  colors: _colors,
                ),
                const SizedBox(height: 16),
              ],

              if (!_migrating)
                _ActionButton(
                  label: _migrationDone
                      ? 'Relancer la migration'
                      : 'Migrer tous les utilisateurs',
                  icon: Icons.group_rounded,
                  color: const Color(0xFF185FA5),
                  loading: false,
                  onPressed: _migrateAllUsers,
                ),
            ],

            const SizedBox(height: 32),

            // ── Info technique ──────────────────────────────────────────────
            _InfoBox(
              icon: Icons.code_rounded,
              text: 'ID Firestore fixe : $kAfrolookGroupId\n'
                  'Nom exact : $kAfrolookGroupName\n'
                  'Collection : GroupChats',
              colors: _colors,
            ),
          ],
        ),
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
                  isGreen ? 'Groupe Afrolook créé ✅' : 'Groupe non créé',
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
                    style:
                        TextStyle(color: Colors.orange, fontSize: 13),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status,
              style: TextStyle(
                  color: done ? const Color(0xFF1FAA59) : colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done ? 1.0 : (total > 0 ? progress : null),
              minHeight: 8,
              backgroundColor: colors.border.withOpacity(0.2),
              color: done ? const Color(0xFF1FAA59) : const Color(0xFF185FA5),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(label: 'Traités', value: '$processed / $total', colors: colors),
              const SizedBox(width: 16),
              _Stat(label: 'Ajoutés', value: '+$newlyAdded', colors: colors, highlight: true),
              const SizedBox(width: 16),
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
                fontSize: 16)),
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
