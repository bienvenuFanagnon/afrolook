import 'package:flutter/material.dart';

class NotificationToast {
  static OverlayEntry? _entry;
  static bool _isVisible = false;

  static void show({
    required BuildContext context,
    required int count,
    required VoidCallback onTap,
  }) {
    if (_isVisible) return;
    _isVisible = true;

    _entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        count: count,
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
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.count,
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

    Future.delayed(const Duration(seconds: 2), () {
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 8;

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_active,
                        color: Color(0xFFE8B86D), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tu as ${widget.count} notification${widget.count > 1 ? 's' : ''} non lue${widget.count > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white54, size: 12),
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
