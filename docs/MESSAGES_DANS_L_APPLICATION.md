# Messages dans l'application (Firebase In-App Messaging) : mode d'emploi et exemple de campagne

Préparé le 04/11/2026. Le code est dans `lib/services/app_messaging.dart` (commit `477e999a`). **Il faut une version de l'application publiée sur les stores** pour que les messages s'affichent (modules natifs : Shorebird ne peut pas les envoyer). Ils ne s'affichent **pas** sur le site web.

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

Images prêtes (déjà dans le dépôt, moins de 1 Mo chacune) :
- **portrait** (1080 × 1350) : `site/static/img/ads/affiche-jobs.png`
- **paysage** (1200 × 630) : `site/static/img/ads/og-jobs.png`

### Dans la console Firebase
Console Firebase, projet **afrolooki**, menu **Engagement** puis **In-App Messaging**, bouton **Create your first campaign** (ou **New campaign**).

**Étape 1 : Style et contenu**
- Type de message : **Card** (deux images, deux boutons) ou **Modal** (une image).
- Nom de la campagne : `Jobs et tâches - FR - 2026-11`
- Titre : `Gagne de l'argent avec Afrolook`
- Texte : `Partage des annonces sur WhatsApp, Telegram ou Facebook et gagne environ 5 F par clic valide, jusqu'à 500 F par jour. Ouvre la page Travail pour voir les missions.`
- Image portrait : `affiche-jobs.png` ; image paysage : `og-jobs.png`.
- Bouton principal : texte `Voir comment ça marche` ; action **Open URL** : `https://afrolookmedia.com/gagner/#jobs`
- Bouton secondaire (type Card) : texte `Plus tard` ; action **Dismiss** (fermer).

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
- Nom : `Jobs and tasks - EN - 2026-11` ; ciblage `app_lang` = `en`.
- Titre : `Earn money with Afrolook`
- Texte : `Share ads on WhatsApp, Telegram or Facebook and earn about 5 F per valid click, up to 500 F a day. Open the Work page to see the missions.`
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
