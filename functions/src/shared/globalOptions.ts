import { setGlobalOptions } from "firebase-functions/v2";

/**
 * Options communes à toutes les fonctions (surchargées fonction par fonction si besoin).
 *
 * - cpu "gcf_gen1" : fraction de processeur (0,167 pour 256 Mio, 0,33 pour 512 Mio…) au lieu de 1 processeur entier,
 *   valeur par défaut du SDK v6. Avec 125 fonctions à 1 processeur chacune, le quota régional Cloud Run
 *   (20 processeurs) était atteint aux heures de pointe → erreurs « quota cpu_allocation » côté utilisateurs.
 *   Conséquence : 1 requête à la fois par instance → plafond d'instances explicite (maxInstances).
 * - Les instances inactives comptent aussi dans le quota : ne garder `cpu: 1` (concurrence 80) que pour ce qui
 *   le justifie (webhooks de paiement). Au trafic actuel, une fraction de CPU suffit partout ailleurs ; quand le quota
 *   aura été relevé et que le trafic aura grossi, repasser `cpu: 1` sur les fonctions les plus sollicitées.
 */
setGlobalOptions({ cpu: "gcf_gen1", maxInstances: 30 });
