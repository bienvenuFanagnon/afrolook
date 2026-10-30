# Clés locales de l'application (non versionnées)

Le fichier `tapjoy.env` de ce dossier (ignoré par Git, comme `functions/.env`) contient les clés du SDK Tapjoy, une par plateforme :

```
TAPJOY_SDK_KEY_ANDROID=...
TAPJOY_SDK_KEY_IOS=...
```

L'application le lit toute seule au lancement. Sans ce fichier, la fonction « Gagne des pièces » est simplement cachée.
La clé de REPORTING Tapjoy n'a rien à faire ici : c'est un secret du serveur.
