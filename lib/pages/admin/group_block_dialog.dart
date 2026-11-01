import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/groups_b2_api.dart';
import 'package:flutter/material.dart';

/// Bloque ou débloque un groupe pour l'équipe (`PATCH /admin/groups/{id}`). Pour bloquer, un motif est OBLIGATOIRE (255 caractères au plus) ;
/// le propriétaire en est prévenu dans sa liste de notifications. Renvoie la ligne à jour, ou null si la personne a annulé ou si l'appel a échoué
/// (le message d'erreur est alors déjà affiché, avec « Réessayer »).
Future<AdminGroupRow?> toggleGroupBlock(BuildContext context, {required String groupId, required String groupName, required bool currentlyBlocked}) async {
  String? reason;
  if (!currentlyBlocked) {
    final ctrl = TextEditingController();
    reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Bloquer le groupe « {n} » ?', {'n': groupName})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Plus aucun message ne pourra être envoyé dans ce groupe ; les membres pourront encore le lire. Le propriétaire en sera prévenu.')),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 255,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: tr('Motif du blocage (obligatoire)')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
          TextButton(
            onPressed: () => ctrl.text.trim().isEmpty ? null : Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(tr('Bloquer'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || reason.isEmpty) return null;
  } else {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Débloquer le groupe « {n} » ?', {'n': groupName})),
        content: Text(tr('Les membres pourront à nouveau envoyer des messages.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Annuler'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Débloquer'))),
        ],
      ),
    );
    if (ok != true) return null;
  }
  try {
    return await GroupsB2Api.adminSetBlocked(groupId, !currentlyBlocked, reason: reason);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(GroupMessages.of(e)),
        action: SnackBarAction(label: tr('Réessayer'), onPressed: () => toggleGroupBlock(context, groupId: groupId, groupName: groupName, currentlyBlocked: currentlyBlocked)),
      ));
    }
    return null;
  }
}
