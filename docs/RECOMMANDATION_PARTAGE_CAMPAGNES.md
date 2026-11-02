# Partage et gagne : quel système pour les liens de campagne ? (recommandation à valider)

Rédigé le 02/11/2026. **VALIDÉE par le propriétaire le 02/11/2026** (toutes les propositions ci-dessous, y compris le seuil et la majoration). Rien à changer dans le code pour le lancement : option A. L'option C ne sera développée que si le seuil de qualité est dépassé après 2 semaines de mesure.

## 1. Ce qui existe aujourd'hui (vérifié dans le code et sur le serveur de test)

1. Le partageur choisit une mission et un canal (statut WhatsApp, Telegram, groupe…). Le serveur crée un **lien personnel suivi** : `…/p/CODE/`.
2. Le lien est collé dans WhatsApp avec le texte de la campagne. **WhatsApp affiche tout seul l'aperçu** (image, titre, description) : c'est la carte que tu as vue. Ces informations viennent de la page du lien (balises `og:`). Personne n'a encore cliqué.
3. Quand une vraie personne ouvre le lien : une page très courte « Redirection… » compte la visite, puis l'envoie au site de l'annonceur (environ 1 seconde).
4. Le clic est **valide** (le partageur gagne, l'annonceur paie) seulement si : ce n'est pas un robot d'aperçu, la visite dure plus de 0,7 s, ce n'est pas la même connexion internet que le créateur du lien, c'est un visiteur nouveau ce jour-là pour la campagne, le pays est bon, et les plafonds (par lien, par jour, budget) ne sont pas atteints. Les gains sont retenus 72 h.

Constaté lors de ton test : 6 visites reçues, toutes refusées comme « auto-clic » (même connexion que le créateur du lien). Le système marche comme prévu.

## 2. Les options

| | A. Redirection (actuel) | B. Page d'aperçu puis clic sur l'image | C. Mixte (recommandé) |
|---|---|---|---|
| Parcours | Aperçu WhatsApp → touche le lien → site de l'annonceur | Aperçu WhatsApp → touche le lien → page Afrolook avec l'image → touche l'image → site | A par défaut ; B pour les campagnes qui le demandent |
| Ce qui est compté et payé | La visite du lien | Le **second** geste : l'ouverture voulue du site | Selon la campagne |
| Clics perdus | Peu | Beaucoup (une étape de plus) | Choix par campagne |
| Qualité pour l'annonceur | Bonne, mais un clic peut être une personne qui referme tout de suite | Très bonne : chaque clic est un choix | Les deux niveaux de prix |
| Gain du partageur par lien partagé | Plus élevé | Plus bas | Aligné sur le prix de la campagne |
| Risque de fraude | Robots filtrés par le délai, le jeton à usage unique, les agents d'aperçu | Idem, plus un geste humain à imiter | Idem |
| Travail à faire | Aucun | Moyen (page + comptage du second geste + règles) | Moyen, B est réutilisé |

## 3. Recommandation

1. **Lancer avec l'option A, sans rien changer.** C'est le plus simple, il est déjà testé (1 090 tests), et l'aperçu avec l'image existe déjà dans WhatsApp. Le risque principal d'un lancement est un manque de clics, pas un excès : l'option B les réduirait encore.
2. **Mesurer pendant 2 semaines**, par campagne, trois chiffres que le serveur sait déjà compter : clics valides, part des clics refusés, et (côté annonceur) les visites réelles arrivées sur son site. Si l'annonceur voit moins de la moitié des clics payés arriver sur son site, le clic « visite du lien » est trop généreux.
3. **Si ce seuil est dépassé, ajouter l'option C** : un réglage « mode » sur chaque campagne (`redirection` ou `aperçu puis clic`). En mode `aperçu puis clic`, le clic n'est compté qu'au second geste, et le prix par clic est plus élevé (proposition de départ : +40 %, à ajuster avec les premières données). Le partageur voit le mode et le gain avant de partager.
4. **Quoi qu'il arrive** : garder la retenue de 72 h, l'interdiction de cliquer ses propres liens et les plafonds. Ce sont eux qui protègent l'annonceur, pas la forme de la page.

## 4. Ce que tu décides

- [x] Accord pour lancer avec l'option A.
- [x] Seuil de qualité qui déclenche l'option C (proposé : moins de 50 % des clics payés visibles chez l'annonceur).
- [x] Majoration du prix en mode `aperçu puis clic` (proposé : +40 %).
- [x] Première campagne de test avec un vrai annonceur (SlashAtlas) et durée de l'essai (proposé : 2 semaines).

## 5. Ce que je ne peux pas affirmer

Je n'ai aucune donnée réelle d'annonceurs ni de partageurs : les écarts de clics entre A et B sont des ordres de grandeur de raisonnement, pas des mesures. C'est pour cela que je propose de mesurer avant de compliquer.
