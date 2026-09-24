import 'package:flutter/material.dart';

import '../pages/coins/apple_coin_store_view.dart';
import '../theme/app_colors.dart';

// Règle App Store 3.1.1 : sur iOS, un contenu numérique ne peut être débloqué que par
// In-App Purchase. Les options encore payées en FCFA sont donc indisponibles sur iPhone.
// Ne jamais renvoyer vers le web, Android ou le Mobile Money ici : Apple l'interdit aussi.
const String _iosUnavailableMessage =
    "Cette option n'est pas encore disponible dans l'app iPhone. "
    "Tes pièces restent utilisables pour les cadeaux, les votes et les DÉFI.";

class IosPurchaseUnavailableScreen extends StatelessWidget {
  final String title;
  const IosPurchaseUnavailableScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_iphone, size: 48, color: colors.textSecondary),
              const SizedBox(height: 16),
              Text(
                _iosUnavailableMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AppleCoinStoreView()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Acheter des pièces', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showIosPurchaseUnavailable(BuildContext context) {
  final colors = AppColors.of(context);
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Non disponible sur iPhone',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
      content: Text(_iosUnavailableMessage, style: TextStyle(color: colors.textSecondary)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}
