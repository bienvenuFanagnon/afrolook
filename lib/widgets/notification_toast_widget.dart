import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';

class NotificationToast {
  static OverlayEntry? _entry;
  static bool _isVisible = false;

  static void show({
    required BuildContext context,
    required int count,
    required VoidCallback onTap,
    List<NotificationData> latestNotifs = const [],
  }) {
    if (_isVisible) return;
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

    Overlay.of(context).insert(_entry!);
  }

  static void dismiss() {
    if (!_isVisible) return;
    _entry?.remove();
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
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _notifLabel(NotificationData n) {
    final desc = n.description ?? '';
    if (desc.isNotEmpty) return desc;
    switch (n.type ?? '') {
      case 'FOLLOW_CANAL': return 'Quelqu\'un suit votre canal';
      case 'FOLLOW': return 'Quelqu\'un vous suit';
      case 'COMMENT':
      case 'COMMENTAIRE': return 'Nouveau commentaire sur votre post';
      case 'FAVORITE': return 'Quelqu\'un a aimé votre post';
      case 'MESSAGE': return 'Nouveau message';
      case 'LIVE': return 'Un live vient de démarrer';
      default: return 'Nouvelle notification';
    }
  }

  IconData _notifIcon(NotificationData n) {
    switch (n.type ?? '') {
      case 'FOLLOW_CANAL':
      case 'FOLLOW': return Icons.person_add_alt_1;
      case 'COMMENT':
      case 'COMMENTAIRE': return Icons.chat_bubble_outline;
      case 'FAVORITE': return Icons.favorite;
      case 'MESSAGE': return Icons.message_outlined;
      case 'LIVE': return Icons.live_tv;
      default: return Icons.notifications_active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 8;
    final colors = AppColors.of(widget.hostContext);
    final shown = widget.latestNotifs.take(2).toList();
    final remaining = widget.count - shown.length;

    // Fond : surface légèrement plus sombre en dark, blanc cassé en light
    final bgColor = colors.isDark
        ? const Color(0xFF1E1E2A)
        : const Color(0xFFFFFFFF);
    final accentColor = colors.accent;
    final textMain = colors.textPrimary;
    final textSub = colors.textSecondary;
    final dividerColor = colors.border;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colors.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: colors.isDark ? 0.4 : 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête : icône cloche + compteur + flèche
                    Row(
                      children: [
                        Icon(Icons.notifications_active,
                            color: accentColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.count} notification${widget.count > 1 ? 's' : ''} non lue${widget.count > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: textSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios,
                            color: textSub, size: 13),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Les 2 notifs
                    ...shown.asMap().entries.map((entry) {
                      final i = entry.key;
                      final n = entry.value;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i > 0)
                            Divider(color: dividerColor, height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_notifIcon(n),
                                  color: accentColor, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _notifLabel(n),
                                  style: TextStyle(
                                    color: textMain,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                    // Mention des autres
                    if (remaining > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '+ $remaining autre${remaining > 1 ? 's' : ''} notification${remaining > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: textSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
