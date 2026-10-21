# Notifications pédagogiques et rappels : textes à relire

Fichier généré à partir de `functions/src/notifications/tips_library.ts` (8 langues : fr, en, es, de, ar, pt, zh, sw).

**État : désactivé.** Les sujets pédagogiques ne partent que si `AppConfig/push.tipsEnabled` vaut `true` (voir « Activation » plus bas).

## Règles
- Créneaux (heure locale) : 8 h 30, 13 h 00, 19 h 30 ; 3 notifications non directes par jour au plus ; heures calmes 22 h – 7 h 30.
- Les sujets pédagogiques occupent le créneau de midi, 4 jours sur 7, un sujet différent à chaque fois.
- Ni la part de l'application (), ni date de lancement de la vente directe : uniquement « bientôt ».
- Les chiffres de l'estimation viennent de `config/monetization` (barème réel).
- Invitations à nous suivre (chaîne WhatsApp, Facebook, TikTok) : un réseau à la fois, tous les 14 jours, tant que la personne n'a pas été dirigée vers ce réseau ; le clic ouvre la page du réseau.
- Une nouveauté (musique, défis, étude, contes) tous les 3 jours.
- Ces notifications ne sont pas enregistrées dans la liste des notifications de l'application.

## Sujets (français, puis anglais)

| Sujet | Page ouverte au clic | Titre (FR) | Texte (FR) |
|---|---|---|---|
| earn | RAPPEL_MONETISATION | 💰 Gagne de l’argent avec Afrolook | Tes posts, tes lives et ta communauté peuvent te rapporter des gains. Découvre comment. |
| estimate | RAPPEL_MONETISATION | 📈 Combien peux-tu gagner ? | {views} vues peuvent rapporter jusqu’à {amount} FCFA selon ton niveau. Encaisse dès {min} FCFA. |
| creator | RAPPEL_MONETISATION | 🚀 La méthode des créateurs qui gagnent | Publie régulièrement, réponds à ta communauté et monte en niveau : plus ton niveau est haut, plus chaque vue rapporte. |
| referral | RAPPEL_PARRAINAGE | 🤝 Parraine et gagne 75 % | Reçois 75 % de commission sur chaque activation de tes filleuls. Plus tu invites tôt, plus tu gagnes. |
| live | RAPPEL_LIVE | 🔴 Passe en live | Retrouve ta communauté en direct, reçois des cadeaux et fais grandir ton audience. |
| sellLive | RAPPEL_LIVE | 🛍️ Vends en direct | Présente tes produits en live : on voit, on pose ses questions et on achète. Lance ton premier live. |
| channel | RAPPEL_CANAL | 📺 Crée ton canal | Rassemble ta communauté, publie ton contenu et fidélise tes abonnés. |
| group | RAPPEL_GROUPE | 👥 Crée ton groupe | Discute avec ta communauté. Dans un groupe privé payant, 70 % des abonnements te reviennent. |
| packs | RAPPEL_MONETISATION | 🎨 Vends tes stickers | 70 % du prix de chaque pack vendu te revient, en pièces gagnées. Crée le tien. |
| weekly | RAPPEL_CLASSEMENT | 🏆 Le top des commentateurs | Les meilleurs commentateurs de la semaine gagnent jusqu’à 500 pièces. Commente et monte au classement. |
| shop | RAPPEL_BOUTIQUE | 🛒 La vente directe arrive bientôt | Bientôt, vends tes produits en ligne directement sur Afrolook. Prépare ta communauté dès maintenant. |
| about | RAPPEL_ABOUT | 🌍 Afrolook, c’est ta communauté | Réseau social, lives, quiz, études et contes : tout au même endroit, avec des façons de gagner. |
| comment | RAPPEL_COMMENTER | 💬 Commenter, ça rapporte | Chaque semaine, les meilleurs commentateurs gagnent des pièces. Commente les posts des créateurs et monte au classement. |
| flame | RAPPEL_COMMENTER | 🔥 Allume ta flamme | Commente chaque jour pour garder ta série de flammes et grimper au classement. |
| musicUpload | RAPPEL_MUSIQUE | 🎵 Mets ta musique en ligne | Publie tes titres sur Afrolook : écoutes, ventes et utilisations dans les posts peuvent te rapporter des pièces. |
| musicEarn | RAPPEL_ARTISTE | 💿 Ce que gagnent les artistes | Tu fixes tes prix et tu touches 60 % de chaque vente et de chaque utilisation, en pièces gagnées convertibles en argent. |
| whatsapp | RAPPEL_WHATSAPP | 📲 Suis-nous sur WhatsApp | Rejoins la chaîne officielle Afrolook : actus, astuces pour gagner et nouveautés en avant-première. |
| facebook | RAPPEL_FACEBOOK | 👍 Suis-nous sur Facebook | Rejoins notre page : actus, annonces et conseils pour réussir sur Afrolook. |
| tiktok | RAPPEL_TIKTOK | 🎬 Retrouve-nous sur TikTok | Des vidéos, des astuces et les coulisses d’Afrolook t’attendent. |
| newsMusic | RAPPEL_NOUVEAUTE_MUSIQUE | 🆕 Nouveau : la musique sur Afrolook | Écoute des artistes africains, utilise leurs sons dans tes posts et soutiens-les. |
| newsDefi | RAPPEL_NOUVEAUTE_DEFI | 🆕 Les DÉFIS sont arrivés | Relève un défi, vote et fais vibrer la communauté. Viens voir. |
| newsStudy | RAPPEL_NOUVEAUTE_ETUDE | 🆕 Étudie sur Afrolook | Cours, quiz et diplômes : progresse chapitre après chapitre, à ton rythme. |
| newsContes | RAPPEL_NOUVEAUTE_CONTES | 🆕 Des contes africains à lire | De nouvelles histoires t’attendent, avec un quiz pour gagner des pièces. |

### Anglais

| Sujet | Titre | Texte |
|---|---|---|
| earn | 💰 Earn money with Afrolook | Your posts, lives and community can earn you income. Find out how. |
| estimate | 📈 How much can you earn? | {views} views can earn up to {amount} FCFA depending on your level. Cash out from {min} FCFA. |
| creator | 🚀 How top creators earn | Post regularly, engage with your community and level up: the higher your level, the more each view pays. |
| referral | 🤝 Refer and earn 75% | Get a 75% commission on each activation by your referrals. The sooner you invite, the more you earn. |
| live | 🔴 Go live | Meet your community in real time, receive gifts and grow your audience. |
| sellLive | 🛍️ Sell live | Show your products live: people see them, ask questions and buy. Start your first live. |
| channel | 📺 Create your channel | Bring your community together, publish your content and keep your followers coming back. |
| group | 👥 Create your group | Chat with your community. In a paid private group, you keep 70% of subscriptions. |
| packs | 🎨 Sell your stickers | 70% of the price of each pack sold comes to you, in earned coins. Create yours. |
| weekly | 🏆 Top commenters of the week | The week’s best commenters win up to 500 coins. Comment and climb the ranking. |
| shop | 🛒 Direct online selling is coming soon | Soon you’ll be able to sell your products online right on Afrolook. Start building your community now. |
| about | 🌍 Afrolook is your community | Social network, lives, quizzes, study and tales: all in one place, with ways to earn. |
| comment | 💬 Commenting pays off | Every week, the best commenters win coins. Comment on creators’ posts and climb the ranking. |
| flame | 🔥 Keep your flame lit | Comment every day to keep your flame streak going and climb the ranking. |
| musicUpload | 🎵 Put your music online | Publish your tracks on Afrolook: listens, sales and uses in posts can earn you coins. |
| musicEarn | 💿 What artists earn | You set your prices and keep 60% of every sale and every use, in earned coins you can convert to cash. |
| whatsapp | 📲 Follow us on WhatsApp | Join the official Afrolook channel: news, tips to earn and early updates. |
| facebook | 👍 Follow us on Facebook | Join our page: news, announcements and tips to succeed on Afrolook. |
| tiktok | 🎬 Find us on TikTok | Videos, tips and behind-the-scenes of Afrolook are waiting for you. |
| newsMusic | 🆕 New: music on Afrolook | Listen to African artists, use their sounds in your posts and support them. |
| newsDefi | 🆕 Challenges are here | Take on a challenge, vote and get the community buzzing. Come and see. |
| newsStudy | 🆕 Study on Afrolook | Lessons, quizzes and diplomas: progress chapter by chapter, at your own pace. |
| newsContes | 🆕 African tales to read | New stories are waiting for you, with a quiz to win coins. |

Les 6 autres langues sont dans le fichier source (mêmes sujets).

## Activation
Quand les textes sont relus : dans Firestore, document `AppConfig/push`, champ `tipsEnabled` = `true`. Pour couper : `false`.
