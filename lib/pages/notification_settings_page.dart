import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../providers/authProvider.dart';
import '../theme/app_colors.dart';

/// Préférences des notifications push : la personne choisit ce qu'elle reçoit. Les messages directs, invitations, cadeaux, gains et paiements restent
/// toujours envoyés. Enregistré dans `Users/{id}.pushPrefs` ; le serveur applique ces choix à chaque envoi (functions/src/notifications/policy_logic.ts).
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _reminders = true;
  bool _activity = true;
  bool _news = true;
  bool _loading = true;
  String? _error;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<UserAuthProvider>().loginUserData.id;
    _uid = uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // Préférences lues sur l'API (GET /me/notification-preferences) ; par défaut du serveur : tout activé
      final prefs = await ChatApi.notificationPreferences();
      _reminders = prefs['reminders'] != false;
      _activity = prefs['activity'] != false;
      _news = prefs['news'] != false;
    } catch (e) {
      _error = ChatApi.message(e, fallback: 'Tes préférences ne se chargent pas pour le moment.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await UsersApi.updateNotificationPreferences(reminders: _reminders, activity: _activity, news: _news);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Enregistrement impossible pour le moment.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        title: Text(context.tr('Mes notifications')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 52, color: colors.danger),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colors.textPrimary)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _tile(
                  colors,
                  Icons.lightbulb_outline_rounded,
                  context.tr('Rappels et idées'),
                  context.tr('Quiz, étude, contes, nouveautés de vos créateurs, astuces pour gagner sur Afrolook (3 par jour au plus).'),
                  _reminders,
                  (v) {
                    setState(() => _reminders = v);
                    _save();
                  },
                ),
                const SizedBox(height: 10),
                _tile(
                  colors,
                  Icons.newspaper_rounded,
                  context.tr('Actualités'),
                  context.tr('Le journal du matin, la semaine en quelques infos et les grandes nouvelles du moment, pour ton pays, ton continent et le monde.'),
                  _news,
                  (v) {
                    setState(() => _news = v);
                    _save();
                  },
                ),
                const SizedBox(height: 10),
                _tile(
                  colors,
                  Icons.favorite_border_rounded,
                  context.tr('Activité'),
                  context.tr('J\'aime, commentaires, nouveaux abonnés, nouveaux posts et musiques des créateurs que vous suivez.'),
                  _activity,
                  (v) {
                    setState(() => _activity = v);
                    _save();
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.border)),
                  child: Text(
                    context.tr('Toujours envoyés : messages, invitations, cadeaux, gains et paiements.\nHeures calmes : aucune notification d\'activité ni de rappel entre 22 h et 7 h 30 (heure de votre téléphone).'),
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tile(AppColors colors, IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.border)),
      child: SwitchListTile(
        secondary: Icon(icon, color: colors.primary),
        title: Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
        value: value,
        onChanged: onChanged,
        activeColor: colors.primary,
      ),
    );
  }
}
