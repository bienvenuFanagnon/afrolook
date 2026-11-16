# Clés locales de l'application (non versionnées)

Le fichier `ayet.env` de ce dossier (ignoré par Git, comme `functions/.env`) contient les réglages du SDK ayeT-Studios :

```
AYET_PLACEMENT_ID_ANDROID=...
AYET_PLACEMENT_ID_IOS=...
AYET_ADSLOT=...
```

L'application le lit toute seule au lancement. Sans ce fichier, la fonction est simplement cachée.
Tapjoy a été retiré de l'application le 16/11/2026 : un ancien `tapjoy.env` local peut être supprimé.
