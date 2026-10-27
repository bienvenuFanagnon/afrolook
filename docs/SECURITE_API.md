# Sécurité d'Afrolook : failles actuelles et sécurité de la nouvelle plateforme

Dernière mise à jour : **27 octobre 2026**. Statut : **plan à valider** ; aucune correction n'est encore appliquée.
Fait partie du plan de migration (`docs/MIGRATION_API_LARAVEL.md`) ; l'avancement est suivi dans `docs/PROJET_MEMOIRE.md`.

> **Nature de l'audit** : lecture des règles Firestore et Storage, analyse statique des fonctions serveur et recherche de secrets dans l'application. **Ce n'est pas un test d'intrusion.** Un test d'intrusion externe est prévu avant la bascule de l'argent (voir §6).
> Aucun secret n'est recopié dans ce fichier (les clés citées sont désignées par leur emplacement).

---

## 1. Principes (non négociables pour la nouvelle plateforme)

1. **Tout est refusé par défaut** ; on autorise explicitement, ressource par ressource.
2. **Le téléphone n'est jamais digne de confiance** : montants, prix, rôles, identifiants d'autrui, tout est recalculé et vérifié par le serveur.
3. **Aucun secret dans l'application** (clé de paiement, clé de notification, clé d'API tierce).
4. **Moindre privilège** : chaque compte, chaque conteneur, chaque clé n'a que ce dont il a besoin.
5. **Défense en profondeur** : Cloudflare, puis Laravel, puis la base ; une couche qui cède ne suffit pas.
6. **L'argent est transactionnel** : grand livre à écriture double, idempotence, verrous, rapprochement quotidien.
7. **Tout ce qui est sensible est journalisé** (qui, quoi, quand, depuis où) et alerté.
8. **Tout est testé** : chaque point d'API a des tests « anonyme / autre utilisateur / administrateur ».

---

## 2. Registre des failles de la version actuelle (constatées le 27/10/2026)

Gravité : 🔴 critique · 🟠 élevée · 🟡 moyenne · 🟢 faible. Statut de toutes les lignes : **ouverte** (rien n'est encore corrigé).

| # | Gravité | Faille | Preuve | Conséquence possible | Correction prévue |
|---|---|---|---|---|---|
| F1 | 🔴 | **Règle générale Firestore trop ouverte** : tout compte connecté peut **lire et écrire** toutes les collections non listées en exception | `firestore.rules`, bloc `match /{collection}/{docId}` (la règle elle-même l'avoue en commentaire). Users, Notifications, TransactionSoldes, Chats, Messages, GroupChats, Canaux, Advertisements, Invitations, retraits, wallets des créateurs, AppData… sont concernés. **L'inscription est ouverte à tous** | Un inconnu qui crée un compte peut : lire les messages privés et les données personnelles de tous, modifier des profils et des soldes, falsifier des transactions et des demandes de retrait, créer de fausses notifications | **Urgence** (§5) : fermer collection par collection, tests d'abord. **Définitif** : tout passe par l'API ; Firestore ne garde que les chats, avec des règles strictes |
| F2 | 🔴 | **Le rôle administrateur est un simple champ du profil** (`Users.role == 'ADM'`), lu par les règles **et** par toutes les fonctions serveur d'administration | `firestore.rules` (`isAdmin()`), `functions/src/news/adminAuth.ts` et ~12 autres fonctions | Combiné à F1 : n'importe quel compte peut se promouvoir administrateur (gérer retraits, contenu, utilisateurs). *Contrôle du jour : seuls 2 comptes ont ce rôle, tous deux attendus ; aucune trace d'abus à ce jour* | **Aucun droit dans un champ modifiable** : table de droits écrite par le serveur seulement, permissions fines, 2FA, validation à deux personnes, comptes d'équipe dédiés, panneau admin séparé (§3.2 et `docs/AGENTS_ET_ORGANISATION.md` §4). Intermédiaire : U8 |
| F3 | 🟠 | **Storage : règle générale permissive** : tout compte connecté peut écrire n'importe où hors dossiers listés, **sans limite de taille ni de type**, et lire tout | `storage.rules` (blocs `match /{folder}/{allPaths=**}` et `match /{rootFile}`) | Écrasement ou remplacement de fichiers d'autres utilisateurs, hébergement de contenu illégal ou de fichiers lourds (coût), détournement des médias affichés | Envoi **uniquement par URL signée R2** émise par l'API après contrôle (taille, type réel, quotas) ; plus d'écriture directe |
| F4 | 🟠 | **Clé REST OneSignal distribuée à toutes les applications** : stockée dans `AppData` (lisible par tout compte connecté, F1) et chargée dans le modèle de l'application | `lib/models/model_data.dart` (`one_signal_api_key`), `lib/services/cache/startup_cache_service.dart`, document `AppData` | Quiconque extrait la clé peut **envoyer des notifications à tous les utilisateurs** (hameçonnage, spam) | **Changer la clé OneSignal maintenant** ; retirer le champ de l'application ; envoi uniquement par le serveur (FCM) ; supprimer OneSignal à terme |
| F5 | 🟠 | **Clé secrète de paiement (CinetPay) écrite en dur dans l'application**, avec la signature calculée **sur le téléphone** | `lib/pages/paiement/depotPaiment.dart` (clé et identifiant de site) ; la clé reste dans l'historique Git et dans les APK déjà publiés | Extraction de la clé depuis l'APK ; forgerie de paiements ou de signatures ; usurpation | **Changer la clé chez CinetPay** ; toute initiation de paiement **côté serveur seulement**. La page semble **non utilisée** (classe `DepotPageTransaction` dans l'inventaire des pages orphelines) : la supprimer |
| F6 | 🟡 | **Écriture sans connexion dans Storage** (`user_profile/`) : règle « temporaire » du 25/09 pour les anciennes versions | `storage.rules` (bloc `user_profile`) | Envoi massif de fichiers de 5 Mo par n'importe qui (coût, abus) ; lecture libre | Retirer dès que les versions corrigées sont diffusées ; limiter par IP côté Cloudflare en attendant |
| F7 | 🟡 | **Jetons et données sensibles non chiffrés sur le téléphone** (`SharedPreferences`) | `SECURITY_FINDINGS.md` point 6 ; `lib/providers/authProvider.dart` | Vol de session sur téléphone rooté ou sauvegarde extraite | `flutter_secure_storage` (Keystore / Keychain) |
| F8 | 🟡 | **Journaux de données sensibles en production** (`print` de montants, identifiants, transactions) | `SECURITY_FINDINGS.md` point 8 | Fuite par journaux de l'appareil | Journalisation désactivée en release |
| F9 | 🟡 | **Autorisation par le client** pour des actions d'argent et d'administration (identifiant de l'administrateur passé en paramètre par le téléphone ; débit sans contrôle de l'expéditeur) | `SECURITY_FINDINGS.md` points 2, 3, 4 (en grande partie traités depuis : paiements en pièces par fonctions serveur ; à **revérifier module par module**) | Falsification de montants ou d'identités depuis un client modifié | Aucune logique d'argent dans l'application ; vérification serveur systématique |
| F10 | 🟡 | **Clés d'API Firebase de l'application** (publiques par nature) sans restriction vérifiée, et **App Check** non imposé (à vérifier) | `lib/firebase_options.dart` | Utilisation de votre projet Firebase depuis des applications tierces | Restreindre les clés (empreinte Android, identifiant iOS) ; **imposer App Check** sur Firebase et sur l'API |
| F11 | 🟡 | **Pas de limitation de débit généralisée** ni de protection contre les faux comptes à l'inscription (à vérifier hors e-mails de réinitialisation, qui sont bien limités) | Analyse statique | Création en masse de faux comptes pour gagner des pièces (parrainage, récompenses), abus des fonctions d'IA (coût) | Anti-bot à l'inscription, limites par appareil/IP/utilisateur, plafonds de coût sur les fonctions d'IA (§3) |
| F12 | 🟢 | **Rapport `SECURITY_FINDINGS.md` périmé** (annonce l'absence de règles, qui existent désormais) | Racine du dépôt | Confusion | Remplacé par ce document |
| F13 | 🟠 | **Les collections d'équipe (`TeamMembers`, `TeamProfiles`) ne sont pas dans les règles** : elles tombent sous la règle générale (F1) | `firestore.rules` (aucune mention) ; `functions/src/team/teamHub.ts` | Tout compte connecté peut s'**inscrire lui-même comme membre d'équipe** et modifier les profils d'équipe ; aujourd'hui seuls des widgets de statistiques sont concernés, mais le modèle est celui des droits | Fermer en écriture (serveur seulement) ; remplacer par la table de droits (U8, §3.2) |
| — | ✅ | **Ce qui est correct** : fonctions serveur d'appel contrôlent l'identité (la quasi-totalité des 34 signalées par l'analyse automatique utilisent un utilitaire de contrôle ; faux positifs), réinitialisation de mot de passe limitée et sans fuite d'existence du compte, notifications Apple vérifiées par signature, formulaire de contact avec piège à robots et origines autorisées, collections de quiz/étude/paiements fermées | Lecture du code | — | À conserver comme modèle |

**Reste à vérifier** (pas encore regardé) : cohérence des règles pour les collections `Chats`/`Messages` une fois F1 corrigé (l'application lit certains documents d'autrui), restrictions des clés Google Cloud, droits des comptes de service, paramètres de l'e-mail SMTP, journaux d'accès aux données Firestore.

---

## 3. Sécurité de la nouvelle plateforme

### 3.1 Comptes utilisateurs
- **Identité** : Firebase Auth (e-mail vérifié, Google, Apple). Jamais de mot de passe chez nous.
- **E-mail vérifié obligatoire** pour toute action qui rapporte ou coûte de l'argent (retrait, cadeau, achat, parrainage).
- **Anti-bot et faux comptes** : App Check obligatoire (Play Integrity, App Attest) ; limites par appareil, par IP et par réseau ; empreinte d'appareil hachée pour repérer les comptes multiples ; récompenses de parrainage versées seulement après des signes d'usage réel.
- **Réauthentification récente** (moins de 5 minutes) pour changer d'e-mail, supprimer le compte, demander un retrait, changer un moyen de paiement.
- **Révocation** : en cas de suspicion, révocation de tous les jetons du compte (`revokeRefreshTokens`), blocage immédiat côté API (liste de refus en Redis).
- **Pas d'énumération** : messages identiques que le compte existe ou non (déjà fait pour la réinitialisation).

### 3.2 Comptes administrateurs (séparés des comptes utilisateurs)
- **Rôles hors du profil** : table `admin_accounts` + **permissions fines** (RBAC) : `super_admin`, `finance`, `moderation`, `contenu`, `support`, `lecture_seule`. Une personne = un compte nominatif, **jamais de compte partagé**.
- **Équipe (stagiaires, collaborateurs) et administrateurs : mêmes principes, une seule table de droits écrite par le serveur** (`staff_accounts`, permissions fines, échéance obligatoire pour les stagiaires, attribution par un super administrateur avec 2FA récente, validation à deux personnes pour le niveau administrateur, **comptes d'équipe dédiés**, élévation par réauthentification 2FA). Modèle complet : `docs/AGENTS_ET_ORGANISATION.md` §4.2. **L'application publique ne lit jamais un champ « rôle »** : elle demande à l'API la liste de ses droits (`GET /v1/me/capabilities`).
- **Revendications Firebase** (`admin`, `role`) posées **uniquement par une commande serveur** ; l'API les revérifie à chaque requête dans sa table.
- **Double authentification obligatoire** (TOTP ou clé d'accès) ; session d'administration courte (15 minutes d'inactivité).
- **Panneau d'administration sur un sous-domaine séparé** `admin.afrolookmedia.com`, derrière **Cloudflare Access** (Zero Trust : identité + 2FA avant même d'atteindre le serveur), avec liste d'adresses autorisées en option.
- **Règle des quatre yeux** pour les actions critiques : validation d'un retrait au-dessus d'un seuil, crédit manuel de pièces, changement de rôle, suppression d'un compte, modification d'une règle de commission.
- **Journal d'audit infalsifiable** (table en ajout seul + copie hors serveur) : qui, quoi, avant/après, adresse IP, appareil.
- **Alertes e-mail** : création d'un administrateur, connexion depuis un nouvel appareil, échecs répétés, action critique.
- **Procédure de secours** (« break-glass ») : un compte de dernier recours dont les identifiants sont gardés hors ligne, utilisé et journalisé seulement en cas de perte d'accès.
- **Aucune action d'administration depuis l'application publique** : tout passe par le panneau séparé (les pages admin actuelles de l'application sont à retirer de l'application grand public à terme).

### 3.3 Autorisation et validation
- **Une Policy Laravel par ressource**, reprenant les règles de `firestore.rules`, avec une **matrice « règle → Policy → test »** tenue à jour.
- **Aucune confiance aux champs du client** : `role`, prix, montants, `user_id`, soldes sont ignorés s'ils sont envoyés ; la liste des champs modifiables est explicite (`fillable`).
- **Validation stricte** de chaque requête (FormRequest), taille maximale des corps, types, longueurs.
- **Tests d'accès aux objets d'autrui** (IDOR) automatisés sur chaque point d'API.

### 3.4 Argent (portefeuille, paiements, retraits)
- Grand livre à **écriture double**, entiers uniquement, transactions SQL avec verrou de ligne, **`Idempotency-Key`** obligatoire.
- **Webhooks** (FeexPay, CinetPay, PayGate, Apple, Google) : signature vérifiée, adresses IP vérifiées quand le fournisseur les publie, rejeu impossible, traitement idempotent.
- **Aucune clé de paiement dans l'application** ; le téléphone ne fait que demander un paiement et afficher le résultat.
- **Détection d'anomalies** : vitesse (trop d'opérations), montants inhabituels, comptes neufs qui retirent ; mise en attente pour revue manuelle.
- **Retraits : demandes manuelles** (règle du propriétaire), validées par **deux administrateurs** au-delà d'un seuil ; rapprochement quotidien des soldes ; alerte sur tout écart.

### 3.5 Contre le piratage de l'application
- **App Check imposé** sur l'API et sur Firebase : un client modifié, un émulateur ou un script sans jeton valide est refusé.
- **Obfuscation** (`--obfuscate --split-debug-info`), R8 activé, aucun secret embarqué (rien à extraire).
- **Épinglage de certificat** du domaine de l'API, avec clé de secours (rotation sans coupure).
- **Version minimale** imposée par l'API (ancien client vulnérable = écran de mise à jour).
- **Signaux** (téléphone rooté / jailbreaké, débogueur) : transmis au serveur comme indices de risque, pas comme blocage aveugle.
- Stockage local sensible dans le Keystore/Keychain (F7).

### 3.6 Attaques sur l'API et le web
- **Cloudflare** devant tout : proxy, protection contre les attaques par saturation, **règles WAF** (OWASP), limitation de débit par adresse, **Turnstile** sur les pages web publiques (contact, partage).
- **Limitation de débit dans Laravel** (Redis) par utilisateur, par adresse et par point d'API (plus strict pour connexion, réinitialisation, retrait, cadeau, IA).
- **TLS 1.2+**, HSTS, CORS strict (seuls vos domaines), en-têtes de sécurité, **CSP** sur les pages de partage.
- **Pages de partage et d'aperçu** (domaine `afrolookmedia.com`, déjà à vous, pas de Firebase Dynamic Links) : gabarits Blade avec échappement systématique, aucune donnée sensible, protection contre l'injection de balises ; l'aperçu de liens (LinkPreview) est protégé contre **SSRF** (adresses privées et locales interdites).
- **Envois de fichiers** : URL signée courte, taille et type imposés, **vérification du vrai type** (octets de tête), **ré-encodage des images** (retire les données cachées et la géolocalisation), noms aléatoires, aucun fichier exécutable, antivirus optionnel (ClamAV) pour les non-images, analyse de contenu pour la modération.
- **Dépendances** : `composer audit` et Dependabot en intégration continue, analyse statique (Larastan), images Docker analysées (Trivy), versions épinglées.

### 3.7 Serveur (VPS LWS) et conteneurs
- **L'adresse du VPS n'est jamais exposée** : accès uniquement via **Cloudflare Tunnel** (ou pare-feu qui n'accepte que les adresses Cloudflare sur 80/443).
- **SSH** : clé uniquement, pas de connexion root, `fail2ban`, accès restreint à vos adresses ou à un VPN (Tailscale / Cloudflare WARP).
- **Pare-feu** (`nftables`/`ufw`) en refus par défaut ; PostgreSQL et Redis **jamais** exposés hors du réseau Docker.
- **Docker** : conteneurs sans droits root, système de fichiers en lecture seule quand possible, aucun accès au socket Docker, images minimales.
- **Mises à jour de sécurité automatiques** du système (`unattended-upgrades`), fenêtre de redémarrage planifiée.
- **Secrets** : fichier `.env` hors Git, chiffré (sops/age) dans le dépôt privé, ou secrets Docker ; **rotation** planifiée de toutes les clés ; une clé par environnement (dev, préproduction, production).
- **Sauvegardes chiffrées** (PostgreSQL + archivage continu) envoyées vers R2 hors du VPS, **restauration testée chaque mois**.
- **Journaux** centralisés et conservés hors serveur.
- *Note sur l'hébergeur* : choisir chez LWS un **VPS à accès administrateur complet (racine)** et non un hébergement mutualisé (Docker impossible) ; vérifier l'emplacement des données, les sauvegardes proposées et les options de pare-feu. Ne pas compter sur les sauvegardes de l'hébergeur : garder les nôtres hors site.

### 3.8 Données personnelles
- Collecter le minimum ; chiffrer les champs les plus sensibles (téléphone, pièces justificatives éventuelles) ; durée de conservation définie ; export et suppression (J+15, purge de **toutes** les tables liées à l'utilisateur) ; journaux d'accès aux données personnelles.
- Politique de confidentialité et conditions à jour ; conformité à la loi togolaise sur la protection des données personnelles et au RGPD pour les utilisateurs européens (**à faire valider par un juriste**).

### 3.9 Chats (restent sur Firebase)
- Règles Firestore **en refus par défaut**, accès aux seuls participants, création contrôlée, aucun accès en lecture aux conversations d'autrui.
- Le chiffrement de bout en bout existant (`UserKeys`, `encryption_service.dart`) est conservé ; revue de sa mise en œuvre prévue.

### 3.10 Surveillance et réponse aux incidents
- **Sentry** (erreurs), **Pulse/Horizon** (lenteurs, files), **Uptime Kuma** (disponibilité), alertes : pics de 401/403, échecs de webhooks, connexions administrateur, retraits, espace disque, sauvegarde manquante.
- **Plan d'incident** écrit : qui prévenir, comment révoquer les jetons, changer toutes les clés, couper une fonctionnalité par interrupteur, informer les utilisateurs.
- **security.txt** et adresse de signalement de vulnérabilités ; exercice de restauration et d'incident une fois par trimestre.

---

## 4. Ce que la migration corrige d'office (et ce qui demande un geste de plus)

| Faille | Corrigée par la migration ? | Geste supplémentaire |
|---|---|---|
| F1 règle générale Firestore | **Oui, progressivement** : chaque module migré ferme sa collection (`allow read, write: if false`) ; à la fin il ne reste que les chats | **Urgence en attendant** (§5) |
| F2 rôle administrateur dans le profil | Oui (rôles dans une table dédiée) | Revendications posées par le serveur ; 2FA |
| F3 Storage permissif | Oui (R2 par URL signée) | Retirer les règles Storage après la copie |
| F4 clé OneSignal dans l'application | Oui si l'envoi est fait par le serveur | **Changer la clé maintenant** |
| F5 clé de paiement dans l'application | Oui (paiement serveur) | **Changer la clé maintenant** |
| F6 règle `user_profile` | Oui | Version minimale de l'application |
| F7, F8 | Non (c'est l'application) | À faire dans l'application, pendant la phase 0 |
| F10 App Check | Non | À activer en mode « imposé » |

---

## 5. Correctifs d'urgence proposés (indépendants de la migration, à valider avant d'agir)

Ces points protègent la version **déjà en production**. Aucun n'est appliqué ; chacun demande votre accord.

| # | Action | Risque pour l'application | Comment le maîtriser |
|---|---|---|---|
| U1 | **Changer la clé OneSignal** et celle de **CinetPay** (et celles de tout fournisseur dont une clé a été embarquée) | Les anciennes versions qui utilisent encore la clé cessent d'envoyer ; le dépôt CinetPay côté téléphone cesse de fonctionner (page probablement inutilisée) | Faire changer la clé par vous (je ne manipule pas les secrets) ; mettre la nouvelle clé dans les secrets du serveur seulement |
| U2 | **Protéger `role` et les soldes** dans le profil, et **fermer en premier** les collections critiques de la règle générale : Users (par règle propre), retraits, TransactionSoldes, wallets, AppData, Notifications d'autrui | Des fonctions de l'application écrivent peut-être encore chez autrui : certaines pourraient échouer | **Tests des règles dans l'émulateur** avec les scénarios de l'application, déploiement par lots, surveillance des erreurs « permission refusée » pendant 24 h, retour arrière immédiat |
| U3 | **Retirer `AppData` de la lecture libre** et déplacer ses secrets vers le serveur | L'application lit `AppData` au démarrage (identifiants OneSignal) | Publier d'abord une version qui n'en a plus besoin ; la règle suit |
| U4 | **Resserrer Storage** : dossiers dédiés, taille et type imposés, plus d'écriture générale | Envois d'images qui passent par un dossier non prévu | Inventaire des dossiers réellement utilisés (journaux), règle par dossier |
| U5 | **Supprimer la page de dépôt CinetPay** inutilisée (`depotPaiment.dart`) | Aucun si elle est bien orpheline | Vérification manuelle avec vous |
| U6 | **Limiter par IP** (Cloudflare) l'envoi dans `user_profile/` en attendant le retrait de la règle | Aucun | — |
| U7 | **Contrôle de compromission** : comptes administrateurs (fait : 2, attendus), soldes anormaux, transactions suspectes, notifications envoyées | Aucun (lecture seule) | Je peux le faire sur demande |
| U8 | **Sortir les droits administrateur/équipe du profil** : collection `Staff` écrite par le serveur seulement ; un seul utilitaire de contrôle remplaçant les ~12 vérifications `role == 'ADM'` des fonctions et des règles ; fermer `TeamMembers`/`TeamProfiles` | Des fonctions d'administration cessent de reconnaître un administrateur si la collection est mal remplie | Remplir `Staff` d'abord (2 administrateurs actuels, vérifiés par le propriétaire), tests dans l'émulateur, bascule par lots, retour arrière immédiat |

Ordre recommandé : **U1 → U7 → U5 → U8 → U2 → U3 → U4 → U6**, chaque étape après votre accord. (U8 avant U2 : une fois les droits sortis du profil, fermer le profil ne casse plus l'administration.)

---

## 6. Tests de sécurité et mise en production

- **Tests automatiques** : chaque point d'API testé en anonyme, avec un autre utilisateur, avec un administrateur ; tests de rejeu des paiements ; tests de limites de débit.
- **Tests de règles Firestore** (émulateur) pour les chats : participants seulement.
- **Analyse** à chaque modification : Larastan, `composer audit`, Trivy, secret scanning (gitleaks) en intégration continue.
- **Préproduction** : analyse dynamique (OWASP ZAP / Nuclei) avant chaque phase importante.
- **Test d'intrusion externe** avant la bascule de la **phase 5 (argent)**, et revue de sécurité du code avant la mise en production.
- **Revue de la matrice des règles** à chaque module migré : aucune règle Firestore retirée tant que sa Policy et ses tests n'existent pas.

## 7. Décisions de sécurité à valider
1. Ordre des correctifs d'urgence (§5) et accord pour commencer par U1 (changement des clés par vos soins) et U7 (contrôle).
2. **2FA obligatoire** pour tous les comptes administrateurs.
3. Mise en place de **Cloudflare Access** pour `admin.afrolookmedia.com` (gratuit jusqu'à 50 personnes).
4. **Cloudflare Tunnel** pour cacher l'adresse du VPS (recommandé) ou simple pare-feu sur les adresses Cloudflare.
5. **App Check imposé** (les très anciennes versions sans App Check seront refusées : lié à la version minimale).
6. Seuil de la **règle des quatre yeux** pour les retraits et crédits manuels (en pièces ou en FCFA).
8. **Modèle des administrateurs et de l'équipe** : niveaux et permissions, comptes d'équipe dédiés, échéance des stagiaires, qui peut accorder quoi (`docs/AGENTS_ET_ORGANISATION.md` §4.2).
9. Accord sur le correctif intermédiaire **U8**.
7. Qui reçoit les **alertes de sécurité** (adresse e-mail et, si voulu, messagerie) ?
