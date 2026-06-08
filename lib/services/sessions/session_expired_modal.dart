import 'package:flutter/material.dart';

import '../../providers/authProvider.dart';


class SessionExpiredModal extends StatelessWidget {
  final UserAuthProvider authProvider;

  const SessionExpiredModal({
    Key? key,
    required this.authProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône d'expiration
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer_outlined,
                size: 60,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 20),

            // Titre
            const Text(
              'Session expirée',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF112C56),
              ),
            ),
            const SizedBox(height: 10),

            // Message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: const Text(
                'Votre session a expiré.\nVeuillez vous reconnecter pour continuer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Bouton de reconnexion
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Fermer le dialogue


                  // Appeler la déconnexion
                  await authProvider.logout(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Se reconnecter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Bouton de fermeture
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Fermer',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}