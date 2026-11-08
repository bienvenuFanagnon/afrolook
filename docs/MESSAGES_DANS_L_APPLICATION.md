# Messages dans l'application (Firebase In-App Messaging) : mode d'emploi et exemple de campagne

Préparé le 04/11/2026. Le code est dans `lib/services/app_messaging.dart` (commit `477e999a`). **Il faut une version de l'application publiée sur les stores** pour que les messages s'affichent (modules natifs : Shorebird ne peut pas les envoyer). Ils ne s'affichent **pas** sur le site web.

## PRÉREQUIS BLOQUANT (constaté le 08/11/2026) : activer Google Analytics dans le projet Firebase
Les messages dans l'application utilisent les événements de Google Analytics comme déclencheurs. Or **les deux fichiers de configuration du dépôt ont été téléchargés sans Analytics** : `ios/Runner/GoogleService-Info.plist` contient `IS_ANALYTICS_ENABLED = false` et `android/app/google-services.json` n'a pas de bloc `analytics_service`. Tant que ce n'est pas corrigé, **aucune campagne ne s'affichera**, même avec la bonne version de l'application.
À faire une seule fois par le propriétaire :
1. Console Firebase, projet **afrolooki** : **Paramètres du projet** (roue dentée) → onglet **Intégrations** → **Google Analytics** → **Activer** (créer ou relier un compte Analytics ; les réglages par défaut conviennent).
2. Toujours dans les paramètres du projet, onglet **Général** : pour l'application **Android** puis pour l'application **iOS**, **retélécharger** `google-services.json` et `GoogleService-Info.plist` (les anciens fichiers ne contiennent pas Analytics).
3. Remplacer `android/app/google-services.json` et `ios/Runner/GoogleService-Info.plist` par les nouveaux fichiers ; vérifier que le plist contient `IS_ANALYTICS_ENABLED` = `true` et le json un bloc `analytics_service`. Ne pas committer d'autre changement de ces fichiers.
4. **Compiler et publier une nouvelle version** de l'application (Android et iOS). La version 2.1.2+275 déjà compilée avec les anciens fichiers n'affichera rien.
5. Mettre à jour les déclarations des stores : **App Store Connect → Confidentialité de l'app** (utilisation des produits et diagnostics, données non liées à l'identité) et **Google Play → Sécurité des données** (Analytics ajoute une collecte), avant la soumission.

## Ce que l'application envoie à Firebase pour cibler (aucune donnée personnelle)
| Propriété utilisateur | Valeurs | Exemple de ciblage |
|---|---|---|
| `app_country` | code pays en majuscules (`TG`, `BJ`, `CI`…) | seulement le Togo |
| `app_lang` | langue en minuscules (`fr`, `en`, `es`, `pt`, `de`, `ar`, `zh`, `sw`) | un texte par langue |
| `app_plan` | `free`, `premium` ou `gold` | seulement les comptes gratuits |
| `app_team` | `yes` ou `no` | exclure l'équipe (`no`) |

Événements de déclenchement : ceux de Firebase (`on_foreground` = retour au premier plan, `app_launch` = ouverture de l'application) ou un événement envoyé par le code avec `AppMessaging.trigger('nom_evenement')`.

## Règles à retenir
- **Un message n'est affiché qu'une fois par appareil par défaut** (une « impression »). On peut régler une fréquence en jours dans la console pour qu'il revienne.
- **Une campagne = un seul texte.** Pour plusieurs langues : une campagne par langue, ciblée avec `app_lang`.
- **Nos règles ne s'appliquent pas** (comptes sans pub, Gold, plafonds par jour) : tout se règle par le ciblage de la campagne.
- Ce n'est **pas** une notification push : le message apparaît quand la personne ouvre l'application.
- Le bouton ouvre une **adresse web** (navigateur) ou ferme le message : il n'ouvre pas une page précise de l'application.
- Ne jamais citer le nom du partenaire de tâches dans un message (contrat : interdiction d'annoncer le partenariat sans accord écrit).
- Les montants sont indicatifs (« environ »).

## Exemple : « Travaille et gagne de l'argent » (une campagne en français, une en anglais)

**Images prêtes aux BONNES proportions** (la console demande une image **portrait en 3:2** et une image **paysage en 1:1** ; d'autres proportions seraient rognées). Elles sont dans `docs/ads_visuels/firebase_messages/` (moins de 200 Ko chacune) :
- **portrait 3:2** : `jobs_fr_portrait_3x2_1200x800.png`
- **paysage 1:1** : `jobs_fr_paysage_1x1_1080x1080.png`
(Les affiches `affiche-jobs.png` et `og-jobs.png` du site sont à d'autres proportions : ne pas les utiliser ici.) Dans le formulaire, le bouton avec la flèche vers le haut, à droite du champ de l'adresse, **téléverse le fichier depuis l'ordinateur** : pas besoin d'adresse web.

### Dans la console Firebase
Console Firebase, projet **afrolooki**, menu **Engagement** puis **In-App Messaging**, bouton **Create your first campaign** (ou **New campaign**).

**Étape 1 : Style et contenu** (le formulaire de la capture : « Titre du message », « Corps », « Images », « Bouton principal »)
- Type de message : **Carte** (« Card »).
- Nom de la campagne (champ en haut de l'étape) : `Jobs et tâches - FR - 2026-11`
- **Titre du message** : `Gagne de l'argent avec Afrolook`
- **Corps (facultatif)** : `Partage des annonces sur WhatsApp, Telegram ou Facebook et gagne environ 5 F par clic valide, jusqu'à 10 000 F par jour. Ouvre la page Travail pour voir les missions.`
- **URL de l'image en mode portrait (format 3:2)** : téléverser `jobs_fr_portrait_3x2_1200x800.png`.
- **URL de l'image en mode paysage (format 1:1)** : **décocher** « Utiliser la même image qu'en mode portrait », puis téléverser `jobs_fr_paysage_1x1_1080x1080.png`.
- **Bouton principal** : **Texte du bouton** `Voir comment ça marche` ; **Couleur du texte** `#158246` (le vert d'Afrolook, lisible sur fond blanc). L'action du bouton (adresse web) se choisit dans le même bloc : **Ouvrir l'URL** `https://afrolookmedia.com/gagner/#jobs`.
- Bouton secondaire (facultatif) : texte `Plus tard`, action **Fermer**.
- Couleurs de la carte (si la console les propose) : fond blanc `#FFFFFF`, titre et texte `#121212`.
- Puis **Suivant** (le bouton est grisé tant que le titre ou l'image manque).

**Étape 2 : Ciblage**
- **Apps** : cocher l'application Android et l'application iOS (`com.afrotok.afrotok`).
- **Propriétés utilisateur** : `app_lang` **est exactement** `fr`  ET  `app_team` **est exactement** `no`.
- (Facultatif) ajouter `app_country` **est exactement** `TG` pour viser le Togo seulement.
- Pour exclure les comptes sans pub ou Gold : ajouter `app_plan` **n'est pas** `gold`.

**Étape 3 : Planification**
- Début : maintenant. Fin : dans deux semaines.
- **Événement déclencheur** : `on_foreground` (à chaque retour dans l'application).
- **Fréquence** : un affichage tous les **7 jours** par appareil (sinon une seule fois, par défaut).

**Étape 4 : Conversion** (facultatif) : suivre l'événement d'analyse `first_open_work_page` si on veut mesurer les visites de la page Travail (à envoyer par le code, non fait aujourd'hui).

**Étape 5 : Publier**, après avoir testé (voir plus bas).

### Version anglaise (deuxième campagne, mêmes réglages)
**À produire d'abord** : les deux images ci-dessus contiennent du texte français ; il faut une version anglaise (3:2 et 1:1) avant de publier cette campagne (non faite). En attendant, ne publier que la campagne française.
- Nom : `Jobs and tasks - EN - 2026-11` ; ciblage `app_lang` = `en`.
- Titre : `Earn money with Afrolook`
- Texte : `Share ads on WhatsApp, Telegram or Facebook and earn about 5 F per valid click, up to 10,000 F a day. Open the Work page to see the missions.`
- Bouton principal : `See how it works` → `https://afrolookmedia.com/en/earn/#jobs`
- Bouton secondaire : `Later` (Dismiss).

### Tester avant de publier
1. Console Firebase, dans la liste des campagnes : menu de la campagne, **Test on device**.
2. Récupérer l'**identifiant d'installation Firebase** du téléphone de test (affiché dans le journal de l'application en mode debug, ou dans la console Analytics / DebugView) et le coller dans la fenêtre de test.
3. Ouvrir l'application sur ce téléphone : le message doit apparaître. Vérifier le texte, les images et le bouton.

## Limites et vigilance
- Un compte Gold ou sans pub verra le message si le ciblage le permet : c'est le ciblage qui décide.
- Pour ne pas répéter le même message à un utilisateur qui l'a déjà vu, garder la fréquence par défaut (une seule fois) et changer le **nom de la campagne** pour une nouvelle version du message.
- Un message ne doit jamais couvrir un live ou un paiement : le code sait les couper (`AppMessaging.suppress(true)`), mais l'appel n'est pas encore branché sur ces écrans.
