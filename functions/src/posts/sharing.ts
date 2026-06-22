import { onRequest } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";

export const sharePostLink = onRequest(
  { timeoutSeconds: 15, cors: true, region: "us-central1" },
  async (req, res) => {
    try {
      console.log("--- [DEBUG] NOUVELLE REQUÊTE DE PARTAGE ---");
      console.log("URL Complète reçue:", req.originalUrl);
      console.log("Path reçu:", req.path);

      const fullPath = req.originalUrl.split("?")[0];
      const segments = fullPath.split("/").filter(s => s.length > 0);

      console.log("Segments extraits:", segments);

      if (segments.length < 3) {
        console.warn("URL malformée : Pas assez de segments");
        res.redirect("https://afrolooki.web.app");
        return;
      }

      const type = segments[1];
      const id = segments[2];

      console.log(`TYPE DÉTECTÉ: ${type}`);
      console.log(`ID DÉTECTÉ: ${id}`);

      let title = "Afrolook";
      let description = "Regardez ce contenu sur Afrolook";
      let previewImage = "https://play-lh.googleusercontent.com/g5_LdDrb8s5Kvw0-dFc8o8RgFLHUxLlsG0yd-DXXzceX9qPrYwZvfHQ2M2jTFqxnEBUo=w240-h480-rw";
      let collectionName = "";
      let isVideo = false;
      const deepLink = `afrolook://${type}/${id}`;

      switch (type) {
        case "article": collectionName = "Articles"; break;
        case "contentpaie": collectionName = "ContentPaies"; break;
        case "profil": collectionName = "Users"; break;
        case "post": collectionName = "Posts"; break;
        default: collectionName = "Posts";
      }

      console.log(`COLLECTION CIBLE: ${collectionName}`);

      const doc = await db.collection(collectionName).doc(id).get();
      const data = doc.data();

      if (!doc.exists || !data) {
        console.error(`Document introuvable dans ${collectionName} avec ID: ${id}`);
      } else {
        console.log("+++ [SUCCÈS] Données récupérées avec succès");

        if (type === "article") {
          title = data.titre || "Article";
          const prix = data.prix || 0;
          description = prix > 0 ? `Prix : ${prix} XOF` : "Prix : Gratuit";
          previewImage = (data.images && data.images.length > 0) ? data.images[0] : previewImage;
        } else if (type === "contentpaie") {
          title = data.title || "Contenu";
          const isFree = data.isFree ?? false;
          const price = data.price || 0;
          description = isFree ? "Gratuit" : `Prix : ${price} XOF`;
          previewImage = data.thumbnailUrl || previewImage;
        } else if (type === "post") {
          title = data.description ? (data.description.substring(0, 100) + "...") : "Nouveau post";
          if (data.dataType === "VIDEO") {
            description = "▶️ Regardez cette vidéo 🎬 sur Afrolook";
            isVideo = true;
            previewImage = data.thumbnail || (data.images && data.images[0]) || previewImage;
          } else {
            if (data.type === "PRONOSTIC") {
              description = "⚽Gagnez plus de 💰 50 000 FCFA avec les pronostics sur AfroLook ⚽";
            } else {
              description = "Regardez ce post sur Afrolook";
            }
            previewImage = (data.images && data.images[0]) || previewImage;
          }
        } else if (type === "profil") {
          const pseudo = data.pseudo || "Utilisateur";
          title = `@${pseudo}`;
          description = `Rejoignez-moi sur AfroLook 🌍 ! Abonnez-vous à mon profil pour découvrir mes contenus exclusifs. ✨`;
          previewImage = data.imageUrl || previewImage;
        }
      }

      console.log("IMAGE FINALE:", previewImage);
      console.log("TITRE FINAL:", title);
      console.log("DEEP LINK:", deepLink);
      console.log("EST UNE VIDÉO:", isVideo);

      if (previewImage && previewImage.startsWith("http:")) {
        previewImage = previewImage.replace("http:", "https:");
      }

      res.set("Cache-Control", "public, max-age=3600, s-maxage=3600");

      const videoWidth = 1280;
      const videoHeight = 720;

      const html = `<!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>${title}</title>

        <!-- Balises Open Graph de base -->
        <meta property="og:title" content="${title}">
        <meta property="og:description" content="${description}">
        <meta property="og:url" content="https://afrolooki.web.app/share/${type}/${id}">
        <meta property="og:site_name" content="Afrolook">
        <meta property="og:image" content="${previewImage}">

        ${isVideo ? `
        <!-- Balises spécifiques pour les vidéos - Open Graph -->
        <meta property="og:type" content="video.other">
        <meta property="og:video" content="${previewImage}">
        <meta property="og:video:type" content="video/mp4">
        <meta property="og:video:width" content="${videoWidth}">
        <meta property="og:video:height" content="${videoHeight}">
        <meta property="og:image:width" content="${videoWidth}">
        <meta property="og:image:height" content="${videoHeight}">

        <!-- Balises Twitter Cards pour les vidéos -->
        <meta name="twitter:card" content="player">
        <meta name="twitter:site" content="@afrolook">
        <meta name="twitter:title" content="${title}">
        <meta name="twitter:description" content="${description}">
        <meta name="twitter:image" content="${previewImage}">
        <meta name="twitter:player" content="https://afrolooki.web.app/share/${type}/${id}">
        <meta name="twitter:player:width" content="${videoWidth}">
        <meta name="twitter:player:height" content="${videoHeight}">

        <!-- Balises supplémentaires pour Facebook -->
        <meta property="al:ios:url" content="${deepLink}">
        <meta property="al:ios:app_store_id" content="com.afrotok.afrotok">
        <meta property="al:ios:app_name" content="Afrolook">
        <meta property="al:android:url" content="${deepLink}">
        <meta property="al:android:package" content="com.afrotok.afrotok">
        <meta property="al:android:app_name" content="Afrolook">
        ` : `
        <!-- Balises pour les contenus non-vidéo -->
        <meta property="og:type" content="article">
        <meta name="twitter:card" content="summary_large_image">
        <meta name="twitter:image" content="${previewImage}">
        `}

        <!-- Script de redirection -->
        <script>
          window.location.href = "${deepLink}";
          setTimeout(function() {
             window.location.href = "https://play.google.com/store/apps/details?id=com.afrotok.afrotok";
          }, 2500);
        </script>

        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            background: linear-gradient(135deg, #1a1a1a 0%, #000000 100%);
            color: #fff;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
          }
          .container { max-width: 500px; width: 100%; text-align: center; }
          .image-container {
            position: relative;
            width: 100%;
            margin-bottom: 30px;
            border-radius: 20px;
            overflow: hidden;
            box-shadow: 0 20px 40px rgba(0,0,0,0.5);
          }
          .preview-image { width: 100%; height: auto; display: block; transition: transform 0.3s ease; }
          .image-container:hover .preview-image { transform: scale(1.05); }
          .video-overlay {
            position: absolute; top: 0; left: 0; width: 100%; height: 100%;
            background-color: rgba(0,0,0,0.2); display: flex;
            align-items: center; justify-content: center; pointer-events: none;
          }
          .play-button {
            width: 80px; height: 80px; border-radius: 50%;
            background: rgba(255,215,0,0.7); backdrop-filter: blur(2px);
            display: flex; align-items: center; justify-content: center;
            box-shadow: 0 4px 15px rgba(0,0,0,0.3); animation: pulse 2s infinite;
          }
          .play-button::after {
            content: ''; display: block; width: 0; height: 0; border-style: solid;
            border-width: 15px 0 15px 25px;
            border-color: transparent transparent transparent #ffffff; margin-left: 5px;
          }
          .video-badge {
            position: absolute; bottom: 15px; right: 15px;
            background: rgba(0,0,0,0.6); backdrop-filter: blur(5px);
            padding: 8px 15px; border-radius: 20px; font-size: 14px;
            font-weight: bold; color: #FFD700;
            border: 1px solid rgba(255,215,0,0.3); pointer-events: none; z-index: 2;
          }
          .content-info {
            background: rgba(255,255,255,0.05); backdrop-filter: blur(10px);
            border-radius: 20px; padding: 25px; border: 1px solid rgba(255,255,255,0.1);
          }
          h2 { margin-bottom: 15px; font-size: 24px; font-weight: 600; color: #fff; }
          .description { color: #FFD700; font-size: 16px; line-height: 1.6; margin-bottom: 20px; opacity: 0.9; }
          .loading-text { color: rgba(255,255,255,0.7); font-size: 14px; letter-spacing: 1px; }
          @keyframes pulse {
            0% { transform: scale(1); box-shadow: 0 4px 15px rgba(255,215,0,0.3); }
            50% { transform: scale(1.1); box-shadow: 0 4px 25px rgba(255,215,0,0.5); }
            100% { transform: scale(1); box-shadow: 0 4px 15px rgba(255,215,0,0.3); }
          }
          @media (max-width: 480px) {
            .play-button { width: 60px; height: 60px; }
            .play-button::after { border-width: 12px 0 12px 20px; }
            h2 { font-size: 20px; }
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="image-container">
            <img src="${previewImage}" alt="${title}" class="preview-image">
            ${isVideo ? `
            <div class="video-overlay">
              <div class="play-button"></div>
            </div>
            <div class="video-badge">
              📽️ Voir la vidéo sur Afrolook
            </div>
            ` : ""}
          </div>
          <div class="content-info">
            <h2>${title}</h2>
            <p class="description">${description}</p>
            <p class="loading-text">Ouverture de Afrolook Media...</p>
          </div>
        </div>
      </body>
      </html>`;

      res.status(200).send(html);
    } catch (error) {
      console.error("Erreur fatale dans sharePostLink:", error);
      res.status(500).send("Erreur interne");
    }
  }
);
