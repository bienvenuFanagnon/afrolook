import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Affiche un BottomSheet sur mobile/tablette étroite,
/// et une Dialog centrée (max 560px) sur desktop/tablette large.
///
/// Drop-in replacement de showModalBottomSheet — mêmes paramètres nommés.
Future<T?> showResponsiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  bool showDragHandle = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  double? elevation,
  BoxConstraints? constraints,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
}) {
  if (AppLayout.isWide(context)) {
    final colors = AppColors.of(context);
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      routeSettings: routeSettings,
      builder: (ctx) => Dialog(
        backgroundColor: backgroundColor ?? colors.surface,
        elevation: elevation ?? 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: builder(ctx),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    elevation: elevation,
    shape: shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
    constraints: constraints,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    builder: builder,
  );
}
