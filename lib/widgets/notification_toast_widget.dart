import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';

class NotificationToast {
  static OverlayEntry? _entry;
  static bool _isVisible = false;

  /// Réinitialise l'état statique — à appeler dans initState de HomeScreen
  /// pour garantir un état propre même après un hot-reload.
  static void reset() {
    _entry?.remove();
    _entry = null;
    _isVisible = false;
  }

  static void show({
    required BuildContext context,
    required int count,
    required VoidCallback onTap,
    List<NotificationData> latestNotifs = const [],
  }) {
    if (_isVisible) return;

    // Vérifier que l'Overlay est disponible avant d'insérer
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _isVisible = true;

    _entry = OverlayEntry(
      builder: (overlayCtx) => _ToastWidget(
        count: count,
        latestNotifs: latestNotifs,
        hostContext: context,
        onTap: () {
          dismiss();
          onTap();
        },
        onDismiss: dismiss,
      ),
    );

    try {
      overlay.insert(_entry!);
    } catch (_) {
      _entry = null;
      _isVisible = false;
    }
  }

  static void dismiss() {
    if (!_isVisible) return;
    try {
      _entry?.remove();
    } catch (_) {}
    _entry = null;
    _isVisible = false;
  }
}

class _ToastWidget extends StatefulWidget {
  final int count;
  final List<NotificationData> latestNotifs;
  final BuildContext hostContext;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.count,
    required this.latestNotifs,
    required this.hostContext,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _ctrl.reverse().then((_) => widget.onDismiss());
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Libellé court de la notification
  String _notifLabel(NotificationData n) {
    final desc = n.description ?? '';
    if (desc.isNotEmpty) return desc;
    switch (n.type ?? '') {
      case 'FOLLOW_CANAL':  return 'Quelqu\'un suit votre canal';
      case 'FOLLOW':        return 'Quelqu\'un vous suit';
      case 'COMMENT':
      case 'COMMENTAIRE':   return 'Nouveau commentaire sur votre post';
      case 'FAVORITE':      return 'Quelqu\'un a aimé votre post';
      case 'MESSAGE':       return 'Nouveau message reçu';
      case 'LIVE':          return 'Un live vient de démarrer';
      case 'CHRONIQUE':     return 'Nouvelle chronique partagée';
      case 'BOOST':         return 'Votre boost est actif';
      case 'COINS':         return 'Vous avez reçu des pièces';
      default:              return 'Nouvelle notification';
    }
  }

  // Icône selon le type
  IconData _notifIcon(NotificationData n) {
    switch (n.type ?? '') {
      case 'FOLLOW_CANAL':  return Icons.sensors_rounded;
      case 'FOLLOW':        return Icons.person_add_alt_1_rounded;
      case 'COMMENT':
      case 'COMMENTAIRE':   return Icons.chat_bubble_rounded;
      case 'FAVORITE':      return Icons.favorite_rounded;
      case 'MESSAGE':       return Icons.mail_rounded;
      case 'LIVE':          return Icons.live_tv_rounded;
      case 'CHRONIQUE':     return Icons.auto_stories_rounded;
      case 'BOOST':         return Icons.rocket_launch_rounded;
      case 'COINS':         return Icons.monetization_on_rounded;
      default:              return Icons.notifications_rounded;
    }
  }

  // Couleur de l'icône selon le type
  Color _notifColor(NotificationData n) {
    switch (n.type ?? '') {
      case 'FOLLOW_CANAL':  return const Color(0xFF00C9FF);
      case 'FOLLOW':        return const Color(0xFF2ECC71);
      case 'COMMENT':
      case 'COMMENTAIRE':   return const Color(0xFF5B8DEF);
      case 'FAVORITE':      return const Color(0xFFFF6B6B);
      case 'MESSAGE':       return const Color(0xFF9B59B6);
      case 'LIVE':          return const Color(0xFFFF4757);
      case 'CHRONIQUE':     return const Color(0xFFFFD700);
      case 'BOOST':         return const Color(0xFFFF9F43);
      case 'COINS':         return const Color(0xFFFFD700);
      default:              return const Color(0xFF8395A7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 10;
    final colors = AppColors.of(widget.hostContext);
    final shown = widget.latestNotifs.take(2).toList();
    final remaining = widget.count - shown.length;

    final bgColor = colors.isDark
        ? const Color(0xFF1C1C2E)
        : const Color(0xFFFFFFFF);
    final borderColor = colors.isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.07);

    return Positioned(
      top: topPadding,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: colors.isDark ? 0.45 : 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── En-tête compact ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.notifications_rounded,
                                color: colors.accent, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.count == 1
                                ? '1 notification non lue'
                                : '${widget.count} notifications non lues',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const Spacer(),
                          // Bouton fermer
                          GestureDetector(
                            onTap: () => _ctrl.reverse().then((_) => widget.onDismiss()),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: colors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.close_rounded,
                                  color: colors.textSecondary, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Divider fine sous le header ──────────────
                    Divider(color: colors.border, height: 1, thickness: 1),

                    // ── Notifications ────────────────────────────
                    ...shown.asMap().entries.map((entry) {
                      final i = entry.key;
                      final n = entry.value;
                      final iconColor = _notifColor(n);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Séparateur entre 2 notifs — plus visible qu'un simple Divider
                          if (i > 0)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(height: 1, color: colors.border),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'et aussi',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(height: 1, color: colors.border),
                                  ),
                                ],
                              ),
                            ),

                          // Ligne de la notification
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Icône colorée dans un pill arrondi
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_notifIcon(n), color: iconColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                // Texte
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Type badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: iconColor.withValues(alpha: 0.13),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _typeLabel(n),
                                          style: TextStyle(
                                            color: iconColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _notifLabel(n),
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right_rounded,
                                    color: colors.textSecondary.withValues(alpha: 0.5), size: 20),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),

                    // ── Footer si +N autres ──────────────────────
                    if (remaining > 0)
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        child: Text(
                          '+ $remaining autre${remaining > 1 ? 's' : ''} notification${remaining > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Label court du type (badge au-dessus du texte)
  String _typeLabel(NotificationData n) {
    switch (n.type ?? '') {
      case 'FOLLOW_CANAL':  return 'CANAL';
      case 'FOLLOW':        return 'ABONNÉ';
      case 'COMMENT':
      case 'COMMENTAIRE':   return 'COMMENTAIRE';
      case 'FAVORITE':      return 'LIKE';
      case 'MESSAGE':       return 'MESSAGE';
      case 'LIVE':          return 'LIVE';
      case 'CHRONIQUE':     return 'CHRONIQUE';
      case 'BOOST':         return 'BOOST';
      case 'COINS':         return 'PIÈCES';
      default:              return 'NOTIF';
    }
  }
}
