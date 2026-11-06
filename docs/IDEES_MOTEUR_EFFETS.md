# Moteur d'effets Afrolook : ce qu'on peut faire, combiner et inventer

> Fiche vivante (06/11/2026). Le moteur est **maison et gratuit** : caméra (CameraX) + suivi du visage (MediaPipe, 478 points, sur le téléphone) + dessin OpenGL. Tout est calculé en direct, sans serveur, sans abonnement, et rien n'est envoyé ni gardé.
> Légende : ✅ fait · 🔧 en cours · 📋 à faire · 💡 idée à valider avec le propriétaire.

## 1. Ce que le moteur sait déjà faire (briques)

| Brique | État | Détail |
|---|---|---|
| Suivi du visage fluide | ✅ | 478 points, filtre « One Euro » (stable à l'arrêt, sans retard en mouvement), réglage appris par visage, taux de détection affiché dans le labo |
| Déformations | ✅ | gros yeux, grande bouche, gros nez, visage fin (chaque effet suit son élément) |
| Beauté en direct | ✅ | peau lissée sur les tons de peau seulement (contours nets), lumière, chaleur |
| Masques qui suivent la tête | ✅ | lunettes, couronne, nez, cœurs, singe, chat, robot, clown, héros, barre : position, taille et inclinaison suivent le visage |
| Photo et vidéo avec effets | ✅ | l'image enregistrée est exactement celle de l'écran (son du micro inclus) |
| Caméra avant et arrière, paysage | ✅ | le sens « selfie » est celui par défaut ; l'image reste droite quand le téléphone tourne |
| Looks (couleurs) | 🔧 | noir et blanc, sépia, vintage, cinéma, néon, pop |

## 2. Combinaisons possibles (ce qui rend l'application unique)

Un seul geste, plusieurs effets ensemble : **beauté + look + déformation + masque**.
- « Star de cinéma » : beauté + look cinéma + lunettes.
- « Dessin animé » : gros yeux + visage fin + look pop.
- « Souvenir » : look vintage + beauté douce + cœurs.
- « Super-héros » : masque héros + look cinéma + voix grave (Studio).
- **Recettes à partager** 💡 : une combinaison s'enregistre sous un nom, se partage par lien (« essaie ma recette ») et s'ouvre directement dans la caméra. C'est un moteur de viralité : chaque recette partagée ramène des gens dans la caméra Afrolook.

## 3. Effets d'expression (le visage commande l'effet) 💡 📋

Le moteur voit si la bouche est ouverte, si on sourit, si on lève les sourcils, si on cligne des yeux, si la tête tourne.
- **Bouche ouverte** → pluie de cœurs, d'étoiles ou de pièces Afrolook qui sortent de la bouche.
- **Sourcils levés** → couronne ou halo qui s'allume.
- **Clin d'œil** → étincelle et photo prise toute seule.
- **Sourire** → beauté qui monte d'un cran.
- **Tête tournée à gauche / droite** → change de masque ou de look (navigation sans toucher l'écran).
- **Bisou** (bouche en avant) → envoie un cœur à l'ami mis en avant.

## 4. Effets de temps : « accélérer, rembobiner, rouler vite une vidéo » 💡 📋

À appliquer pendant ou après le tournage (le Studio sait déjà couper, régler la voix, mettre des sous-titres) :
- **Accéléré** (×2, ×4), **ralenti** (×0,5), **rampe de vitesse** (lent → très vite → lent, sur le rythme de la musique).
- **Rembobinage** : la vidéo repart en arrière avec le bruit de cassette.
- **Boucle** (3 secondes en boucle, style « boomerang »).
- **Écho / traînée** : le mouvement laisse des copies fantômes.
- **Saut dans le temps** (« flash-back ») : un look noir et blanc court, puis retour à la couleur.
- **Arrêt sur image** avec flash.
- **Coupe sur le mouvement** : coupe automatique quand la personne bouge fort (rythme du montage sans effort).

## 5. Fond et décor 📋 💡

- **Fond virtuel / flou du fond** (segmentation de la personne, modèle gratuit de MediaPipe) : fond flou, fond de ville, fond du drapeau du pays, fond « salon Afrolook ».
- **Fonds animés africains** : savane, marché, coucher de soleil, stade (selon les pays de l'application).
- **Mur d'amis** : les amis qui ont déjà répondu à la vidéo apparaissent en petites bulles autour du visage (réponses vidéo).

## 6. Mains et corps 💡 (plus tard)

- **Gestes de la main** (pouce levé, paix, main ouverte) → effets (cœur qui s'envole, « like » géant, déclenchement de la prise de vue).
- **Pose du corps** (bras levés) → confettis.

## 7. Idées uniques à Afrolook (liées à l'application, pas copiables telles quelles) 💡

1. **Pièces Afrolook en effet** : une pluie de pièces sur la vidéo = invitation à offrir un cadeau (le spectateur envoie des pièces en touchant l'effet).
2. **Duo de réponse vidéo** : deux visages côte à côte avec le même effet, un seul clic pour répondre à une vidéo d'un ami.
3. **Défi du jour** : un effet imposé par jour (« gros yeux + look pop »), classement des meilleures vidéos du défi, récompense en pièces.
4. **Recettes d'effets de créateurs** : un créateur vend ou offre sa recette (revenu en pièces) ; le spectateur « utilise cet effet » depuis la vidéo.
5. **Masques de la culture locale** : masques et motifs (wax, kente, bogolan, peintures de visage traditionnelles) dessinés avec les artistes de chaque pays.
6. **Voix + visage assortis** : choisir un personnage = masque + voix du Studio (déjà prête) pour parler « dans le rôle ».
7. **Traduction visible** : sous-titres auto traduits en 8 langues posés sur la vidéo, avec le style de l'effet.
8. **Photo-roman** : plusieurs photos avec des effets différents, assemblées en histoire courte avec la musique des Chroniques.

## 8. Ordre de réalisation proposé

1. ✅ Brancher le moteur sur la caméra de création (photo, vidéo, beauté, masques, déformations).
2. 🔧 Looks de couleur (cheap, très visibles, se combinent avec tout).
3. 📋 Effets d'expression : bouche ouverte, sourcils, clin d'œil (les 478 points suffisent, rien à télécharger).
4. 📋 Effets de temps côté Studio (accéléré, ralenti, rembobinage, boucle) : traitement ffmpeg sur l'API.
5. 📋 Recettes d'effets partageables + défi du jour.
6. 📋 Fond virtuel (nécessite le modèle de segmentation, ~250 Ko).
7. 💡 Gestes de la main, mur d'amis, pièces en effet.

## 9. Décisions à demander au propriétaire (recommandation par défaut en gras)

- Activer le moteur pour **tous** les utilisateurs Android après quelques jours de test, ou seulement un groupe d'abord ? **Groupe d'abord (10 %), puis tous.**
- iPhone : le moteur est Android. Pour l'iPhone, faire un moteur équivalent avec Vision/Core Image ? **Oui, après la stabilisation Android.**
- Les recettes partagées sont-elles gratuites ou vendables en pièces ? **Gratuites au début, vente ensuite.**
