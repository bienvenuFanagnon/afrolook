# Afficher les médias vite

## Aperçu des vidéos (chroniques et fil)
- À la publication d'une chronique vidéo, l'image d'aperçu est tirée de la vidéo **encore sur le téléphone de l'auteur** (`VideoPoster.fromFile`),
  envoyée dans `chronique_posters/` (quelques Ko, servie par le CDN) et son adresse est gardée dans le champ `posterUrl` de la chronique.
- Tout le monde affiche cette image tout de suite (`VideoPosterImage`) : plus aucun téléchargement de vidéo juste pour fabriquer une vignette.
- Chroniques sans `posterUrl` (publiées avant cette version, 24 h de vie au plus) : l'image est tirée de la vidéo une seule fois, 2 à la fois
  (`VideoPoster.fromUrl`), gardée en mémoire puis sur le disque.
- Cartes vidéo du fil : l'aperçu reste visible pendant que la vidéo se prépare (voile léger au lieu d'un écran noir), il est mis en cache disque
  (`CachedNetworkImage`) et passe par le CDN.
- Lecteur de chroniques : l'aperçu reste affiché jusqu'au démarrage de la vidéo ; la chronique suivante est préparée pendant qu'on regarde celle-ci.

## Pubs chargées d'avance
- `AdmobNativePool` garde 2 pubs natives moyennes (fil) et 1 petite (commentaires, listes) déjà chargées. Un emplacement en prend une
  (affichage immédiat) et le réservoir en recharge une autre. Elles ne sont jamais gardées plus de 50 minutes (expiration Google à 1 h).
- Réchauffement : ouverture de l'accueil, puis chaque apparition d'un emplacement natif. Rien n'est demandé si la personne ne voit pas de pubs
  (Gold, pubs coupées, compte neuf).
- Pubs Afrolook : l'image (ou l'aperçu de la vidéo) est mise en cache disque dès le chargement des pubs ; 4 vidéos au plus sont préparées en
  mémoire, les autres sont mises en cache disque.

## Son sur iPhone / iPad
Cause principale trouvée : le lien d'écoute d'un titre complet était une copie du fichier d'origine **étiquetée « m4a / audio/mp4 »** quel que soit son
vrai format. Android lit quand même (il reconnaît le contenu), iOS refuse un mp3 ou un wav annoncé comme mp4.
- Serveur (`tempListenUrl`) : le vrai format est reconnu (`sniffAudio`), le bon type et la bonne extension sont donnés ; ogg / webm / amr (illisibles
  sur Apple) sont convertis en AAC (m4a).
- Worker CDN : un fichier rangé sans type (`application/octet-stream`) reçoit le type de son extension.
- Application : session audio « musique » remise avant chaque titre (les messages vocaux et le montage la modifient) ; type réel pour les titres
  téléchargés ; si le lecteur refuse une adresse, le titre est téléchargé, reconnu et lu depuis le disque sous la bonne extension ; la raison
  technique d'un échec est ajoutée au message d'erreur pour nous aider à comprendre un cas résiduel.

## Premier « Lecture » instantané (MusicHead)
- Pour les titres qu'on peut écouter en entier (achetés, gratuits, à soi), le **début** (640 Ko ≈ 40 s) est gardé d'avance sur l'appareil :
  chiffré AES-256-GCM, clé dans le Keystore / Keychain, fichier `.bin` au nom sans rapport dans l'espace privé de l'application, déchiffré en
  mémoire seulement, effacé à la déconnexion. 40 titres au plus, 24 préparés par lancement.
- Au « Lecture », `HeadStartSource` sert le début depuis l'appareil (le son part tout de suite) ; le lien d'écoute et la suite sont demandés au
  réseau pendant qu'on écoute (Range). Lien périmé : un nouveau est demandé, une seule fois.
- Titres payants non achetés : seul l'extrait public de 30 s est préchargé (comme avant), jamais le début du titre complet.
