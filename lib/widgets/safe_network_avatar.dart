import 'package:flutter/material.dart';

/// Avatar réseau qui ne casse jamais : si le lien est vide, périmé (403/404) ou hors ligne,
/// l'icône de repli s'affiche et aucune exception n'est remontée dans la console.
class SafeNetworkAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? iconColor;

  const SafeNetworkAvatar({
    super.key,
    required this.url,
    required this.radius,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.grey.shade300;
    final fallback = Icon(fallbackIcon, size: radius, color: iconColor ?? Colors.grey.shade600);
    final u = url;
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: (u == null || u.isEmpty)
          ? fallback
          : ClipOval(
              child: Image.network(
                u,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }
}

/// Image de couverture réseau avec repli (dégradé/asset) en cas de lien invalide.
class SafeNetworkCover extends StatelessWidget {
  final String? url;
  final String fallbackAsset;

  const SafeNetworkCover({super.key, required this.url, this.fallbackAsset = 'assets/default_cover.png'});

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(fallbackAsset, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    final u = url;
    if (u == null || u.isEmpty) return fallback;
    return Image.network(u, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
        errorBuilder: (_, __, ___) => fallback);
  }
}
