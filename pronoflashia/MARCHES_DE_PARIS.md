# PronoFlash IA — Marchés de paris couverts (complément au cahier des charges)

Décision du propriétaire : les pronostics ne se limitent pas au résultat et aux buts. Le site calcule **tous les types de paris que proposent les plateformes**, pour que les visiteurs découvrent des paris plus sûrs qu'ils ne voient pas. Le visiteur peut aussi composer un coupon de 2 à 5 sélections (onglet Coupon de la maquette).

Rappel des règles : aucune mise, aucune cote affichée, aucun gain promis, 18+, « on n'engage rien ». Dire « mieux préparer », jamais « garantir » ni « augmenter tes chances de gagner ».

## 1. Principe : une matrice de scores, puis tout en découle

Pour chaque match, on calcule la matrice `P(buts dom = i, buts ext = j)` (Poisson, correction Dixon-Coles pour les petits scores, avantage du terrain, mélange avec les probabilités déduites des cotes si l'API en fournit). À partir de cette seule matrice on obtient exactement :

| Marché | Calcul |
|---|---|
| 1 / N / 2, double chance (1N, 12, N2) | somme des cases concernées |
| Remboursé si nul (« draw no bet ») | P(1) / (P(1) + P(2)) |
| Plus / moins de X buts, buts par équipe, les 2 marquent, cage inviolée | sommes par ligne, colonne, total |
| Handicap européen et asiatique, marge de victoire | sommes selon l'écart `i - j` |
| Victoire sans encaisser, score exact | cases `j = 0`, case `(i, j)` |
| Combinaisons dans un même match | somme des cases qui satisfont les deux conditions : la corrélation est prise en compte (on ne multiplie pas) |

## 2. Autres familles

| Famille | Modèle | Données (API-Football : statistiques de match, joueurs, compositions) | Fiabilité |
|---|---|---|---|
| Mi-temps | même modèle appliqué par mi-temps (part des buts de la 1re mi-temps estimée sur l'historique des deux équipes) ; mi-temps / fin de match via les deux périodes | buts par période | Moyenne |
| Corners, tirs, tirs cadrés | loi de comptage (Poisson ou binomiale négative) : taux pour et contre de chaque équipe sur N matchs, ajusté à l'adversaire et au domicile | statistiques de match | Haute |
| Cartons, fautes, hors-jeux | loi de comptage + effet de l'arbitre (moyenne de ses matchs) | statistiques + arbitre désigné | Moyenne (arbitre souvent connu tard) |
| Joueurs : buteur, tirs cadrés, averti | taux par 90 minutes × temps de jeu attendu | statistiques joueurs ; **uniquement après publication des compositions (environ 1 h avant)** | Moyenne, faible pour le buteur |
| Spéciaux : premier but, minute du but, penalty, carton rouge | taux de référence du championnat et des équipes | historique | Faible |
| Touches (rentrées en touche) | loi de comptage | **rarement fournies par les API sportives** : à vérifier avant de promettre ce marché | Limitée |

## 3. Règles de présentation

- Chaque ligne affiche `probabilité` + `fiabilité` (Haute / Moyenne / Faible). Les paris à fiabilité faible s'affichent à titre indicatif et ne sont **jamais** repris dans les coupons proposés par l'IA.
- Couleurs : sûr (75 % et plus), équilibré (60 à 74 %), risqué (moins de 60 %).
- Les probabilités viennent du calcul, jamais de l'IA. L'IA rédige seulement le texte d'analyse (voir § 4.2 du cahier des charges).
- Les coupons proposés (Prudent 2, Équilibré 3, Audacieux 5) prennent le meilleur choix de chaque match en variant les types de pari quand c'est possible.
- Probabilité d'un coupon : produit des probabilités quand les sélections viennent de matchs différents ; calcul exact via la matrice quand elles viennent du même match.

## 4. Phases proposées

1. **Phase 1** : résultat, double chance, remboursé si nul, buts, les 2 marquent, handicap, score. Tout sort de la matrice de scores.
2. **Phase 2** : mi-temps, corners, tirs, cartons, fautes, hors-jeux.
3. **Phase 3** : joueurs, spéciaux, touches (si une source de données existe), coupons dans un même match.

## 5. Modèle Firestore (ajout à `matches/{matchId}.prono`)

```
prono.marches: [
  { famille:"Handicap", cle:"ext+1.5", libelle:"Marseille +1,5", pct:62, fiabilite:"haute" },
  ...
]
prono.matrice: [[...], ...]   // matrice de scores tronquée (0 à 6 buts), pour recalculer les combinaisons côté serveur
```

Le coupon se compose côté navigateur à partir de `marches` ; les combinaisons dans un même match passent par une fonction qui lit `matrice`.
