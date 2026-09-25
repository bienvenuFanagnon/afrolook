import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Page « Contact » : support WhatsApp, e-mails et réseaux officiels.
/// S'adapte aux thèmes clair et sombre via [AppColors].
class ContactPage extends StatelessWidget {
  const ContactPage({Key? key}) : super(key: key);

  static const _whatsappNumber = '22871645403';
  static const _whatsappDisplay = '+228 71 64 54 03';
  static const _whatsappGreen = Color(0xFF25D366);
  static const _facebookBlue = Color(0xFF1877F2);
  static const _youtubeRed = Color(0xFFFF0033);

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _snack(context, "Impossible d'ouvrir le lien");
  }

  Future<void> _email(BuildContext context, String address, String subject) async {
    try {
      await FlutterEmailSender.send(Email(recipients: [address], subject: subject, body: ''));
    } catch (e) {
      printVm(e);
      // Pas d'application mail configurée : on tente le lien mailto
      final ok = await launchUrl(Uri(scheme: 'mailto', path: address, query: 'subject=${Uri.encodeComponent(subject)}'));
      if (!ok && context.mounted) {
        await Clipboard.setData(ClipboardData(text: address));
        if (context.mounted) _snack(context, 'Adresse copiée : $address');
      }
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('Contact', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Besoin d\'aide ?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              const SizedBox(height: 4),
              Text('Écris-nous, notre équipe te répond rapidement.',
                  style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(height: 16),
              _whatsappCard(context, c),
              _section(c, 'Par e-mail'),
              _group(c, [
                _row(context, c,
                    icon: Icons.support_agent_rounded,
                    color: c.primary,
                    title: 'Support général',
                    subtitle: 'officiel.afrolook@gmail.com',
                    onTap: () => _email(context, 'officiel.afrolook@gmail.com', "Demande d'aide")),
                _row(context, c,
                    icon: Icons.campaign_rounded,
                    color: c.warning,
                    title: 'Publicité',
                    subtitle: 'officiel.afrolook.annonce@gmail.com',
                    onTap: () => _email(context, 'officiel.afrolook.annonce@gmail.com', 'Publicité Afrolook')),
                _row(context, c,
                    icon: Icons.handshake_rounded,
                    color: c.info,
                    title: 'Investissements',
                    subtitle: 'officiel.afrolook.investissement@gmail.com',
                    onTap: () => _email(context, 'officiel.afrolook.investissement@gmail.com', 'Investissement Afrolook')),
              ]),
              _section(c, 'Suis-nous'),
              _group(c, [
                _row(context, c,
                    icon: FontAwesome.whatsapp,
                    color: _whatsappGreen,
                    title: 'Canal WhatsApp',
                    subtitle: 'Les dernières actualités',
                    onTap: () => _open(context, 'https://whatsapp.com/channel/0029VaxfuwYISTkF3o42e60V')),
                _row(context, c,
                    icon: FontAwesome.facebook_square,
                    color: _facebookBlue,
                    title: 'Page Facebook',
                    subtitle: 'Écris-nous en message privé',
                    onTap: () => _open(context, 'https://www.facebook.com/profile.php?id=61554481360821')),
                _row(context, c,
                    icon: FontAwesome.users,
                    color: _facebookBlue,
                    title: 'Groupe Facebook',
                    subtitle: "Entraide entre membres",
                    onTap: () => _open(context, 'https://facebook.com/groups/28745647531687196/')),
                _row(context, c,
                    icon: FontAwesome.youtube_play,
                    color: _youtubeRed,
                    title: 'YouTube',
                    subtitle: 'Tutoriels et guides vidéo',
                    onTap: () => _open(context, 'https://youtube.com/@afrolookstudioofficiel?si=3wWf802tZbGVEeC_')),
                _row(context, c,
                    icon: FontAwesome.twitter,
                    color: c.textPrimary,
                    title: 'X (Twitter)',
                    subtitle: '@Afrolook2',
                    onTap: () => _open(context, 'https://x.com/Afrolook2?t=_Sv_PF1PnaE58CnlqiSKuQ&s=09')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whatsappCard(BuildContext context, AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _whatsappGreen.withOpacity(c.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _whatsappGreen.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: _whatsappGreen, shape: BoxShape.circle),
            child: const Icon(FontAwesome.whatsapp, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Support WhatsApp',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(_whatsappDisplay,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _open(context, 'https://wa.me/$_whatsappNumber'),
            style: FilledButton.styleFrom(
              backgroundColor: _whatsappGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 38),
              shape: const StadiumBorder(),
            ),
            child: const Text('Écrire', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _section(AppColors c, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: c.textSecondary,
          )),
    );
  }

  Widget _group(AppColors c, List<Widget> rows) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 0.5, indent: 58, color: c.border),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AppColors c, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(c.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
