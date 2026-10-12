# Connexion : e-mails de validation et Google

## E-mails (validation d'adresse, mot de passe oublié)
- Fonctions `authSendVerificationEmail` (connecté) et `authSendPasswordReset` (public) : le lien est généré par Firebase (Admin SDK) et envoyé par notre SMTP LWS (`functions/src/auth/authEmails.ts`). Expéditeur = le compte SMTP (le serveur refuse tout autre expéditeur).
- Si l'envoi serveur échoue, l'application se rabat sur l'envoi natif de Firebase (`lib/services/auth/auth_email_service.dart`) : l'e-mail n'est jamais perdu.
- Suivi : collection `AuthEmailLog` (adresse masquée, `ok`, `error`) ; limites : `AuthEmailLimits` (6 renvois/h par compte, 4/h par adresse, 30/h par IP).
- Les anciennes versions de l'application gardent l'envoi natif de Firebase.

## Connexion avec Google
- Code : `lib/services/auth/google_auth_service.dart`, `lib/pages/auth/authTest/components/google_sign_in_button.dart` (bouton sur Connexion et Inscription).
- Compte Google déjà complet → connexion directe. Sans profil Afrolook → `SignUpScreen(googleUser)` puis `SignUpFormEtap3(googleUser)` : pas d'e-mail ni de mot de passe à saisir, pas de validation d'e-mail, même profil qu'une inscription classique. Le retour en arrière supprime le compte Google sans profil (pour que l'adresse puisse s'inscrire ensuite avec un mot de passe).
- Même adresse qu'un compte e-mail existant : Firebase rattache Google à ce compte (adresse Google vérifiée), la personne retrouve son profil.
- Configuration faite le 12/10/2026 : Google activé dans Firebase, `google-services.json` et `GoogleService-Info.plist` mis à jour, schéma d’URL iPhone ajouté dans `Info.plist`. Le bouton n’apparaît sur iPhone que si `GoogleService-Info.plist` contient `CLIENT_ID`.

### Configuration requise (console Firebase, projet afrolooki)
1. Authentication → Méthode de connexion → **Google** → Activer (e-mail d'assistance) → Enregistrer.
2. Réglages du projet → télécharger de nouveau `android/app/google-services.json` (doit contenir des `oauth_client`) et `ios/Runner/GoogleService-Info.plist` (doit contenir `CLIENT_ID` et `REVERSED_CLIENT_ID`).
3. iPhone : ajouter dans `ios/Runner/Info.plist` un `CFBundleURLTypes` avec le `REVERSED_CLIENT_ID` comme schéma d'URL.
4. Web : Authentication → Paramètres → Domaines autorisés : afrolookmedia.com et afrolooki.web.app.
5. Android : les empreintes SHA-1/SHA-256 de débogage, de publication et **de la signature Play Store** (Play Console → Intégrité de l'application) doivent être dans l'application Android Firebase.

### iPhone : bouton Google masqué (décision du 12/10/2026)
Règle App Store 4.8 : une app qui propose Google doit aussi proposer « Se connecter avec Apple » (ou équivalent respectueux de la vie privée). Pour ne pas risquer un refus, `GoogleAuthService.isAvailable` renvoie `false` sur iPhone. Android et web gardent le bouton. Pour rouvrir : ajouter Sign in with Apple (capacité sur l'identifiant d'app, fournisseur Apple dans Firebase, package `sign_in_with_apple`), puis remettre `true` sur iOS. La configuration iOS Google (plist, schéma d'URL) reste en place.
