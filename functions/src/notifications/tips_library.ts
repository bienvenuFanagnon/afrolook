/**
 * Notifications « pédagogiques » : elles rappellent ce qu'est Afrolook et comment y gagner (monétisation, parrainage, lives, canaux, groupes,
 * stickers, vente directe à venir), dans la langue choisie par la personne dans l'application (8 langues, repli sur le français).
 *
 * Règles de contenu (décisions du propriétaire) :
 *  - le parrainage n'annonce que « 75 % » (jamais la part de l'application) ;
 *  - les parts 70 % (groupes privés payants, packs de stickers) reprennent les textes officiels de l'application ;
 *  - l'estimation des gains vient du barème réel (`config/monetization`), jamais d'un chiffre écrit ici ;
 *  - la vente directe en ligne est présentée comme « bientôt », sans date.
 * Ces envois sont désactivés tant que `AppConfig/push.tipsEnabled` n'est pas à true (le temps de relire les textes).
 */

export type Lang = "fr" | "en" | "es" | "de" | "ar" | "pt" | "zh" | "sw";
export const LANGS: Lang[] = ["fr", "en", "es", "de", "ar", "pt", "zh", "sw"];

export type TipTopic = "earn" | "estimate" | "creator" | "referral" | "live" | "sellLive" | "channel" | "group" | "packs" | "weekly" | "shop" | "about" | "comment" | "flame" | "musicUpload" | "musicEarn" | "whatsapp" | "facebook" | "tiktok" | "newsMusic" | "newsDefi" | "newsStudy" | "newsContes";

/** Variables remplies à l'envoi à partir du barème réel. */
export interface TipVars {
  views: string; // nombre de vues de l'exemple (ex. « 1 000 »)
  amount: string; // gain maximal pour ces vues, en FCFA (ex. « 1 000 »)
  min: string; // montant minimal d'encaissement, en FCFA
}

interface Text { title: string; body: string }

export interface Tip {
  topic: TipTopic;
  /** `type_notif` transmis à l'application : elle ouvre la page correspondante. */
  target: string;
  texts: Record<Lang, Text>;
}

export const TIPS: Tip[] = [
  {
    topic: "earn", target: "RAPPEL_MONETISATION",
    texts: {
      fr: { title: "💰 Gagne de l’argent avec Afrolook", body: "Tes posts, tes lives et ta communauté peuvent te rapporter des gains. Découvre comment." },
      en: { title: "💰 Earn money with Afrolook", body: "Your posts, lives and community can earn you income. Find out how." },
      es: { title: "💰 Gana dinero con Afrolook", body: "Tus publicaciones, tus directos y tu comunidad pueden darte ingresos. Descubre cómo." },
      de: { title: "💰 Verdiene Geld mit Afrolook", body: "Deine Beiträge, Lives und Community können dir Einnahmen bringen. So geht’s." },
      ar: { title: "💰 اربح المال مع أفرولوك", body: "منشوراتك وبثوثك المباشرة ومجتمعك يمكن أن تدرّ عليك أرباحًا. اكتشف كيف." },
      pt: { title: "💰 Ganhe dinheiro com o Afrolook", body: "As suas publicações, lives e comunidade podem render ganhos. Descubra como." },
      zh: { title: "💰 在 Afrolook 赚钱", body: "你的帖子、直播和社群都能带来收入。快来看看怎么做。" },
      sw: { title: "💰 Pata pesa na Afrolook", body: "Machapisho, matangazo ya moja kwa moja na jumuiya yako vinaweza kukuingizia kipato. Jua jinsi." },
    },
  },
  {
    topic: "estimate", target: "RAPPEL_MONETISATION",
    texts: {
      fr: { title: "📈 Combien peux-tu gagner ?", body: "{views} vues peuvent rapporter jusqu’à {amount} FCFA selon ton niveau. Encaisse dès {min} FCFA." },
      en: { title: "📈 How much can you earn?", body: "{views} views can earn up to {amount} FCFA depending on your level. Cash out from {min} FCFA." },
      es: { title: "📈 ¿Cuánto puedes ganar?", body: "{views} vistas pueden darte hasta {amount} FCFA según tu nivel. Cobra desde {min} FCFA." },
      de: { title: "📈 Wie viel kannst du verdienen?", body: "{views} Aufrufe bringen je nach Level bis zu {amount} FCFA. Auszahlung ab {min} FCFA." },
      ar: { title: "📈 كم يمكنك أن تربح؟", body: "{views} مشاهدة قد تدرّ عليك حتى {amount} فرنك حسب مستواك. اسحب أرباحك ابتداءً من {min} فرنك." },
      pt: { title: "📈 Quanto pode ganhar?", body: "{views} visualizações podem render até {amount} FCFA conforme o seu nível. Levante a partir de {min} FCFA." },
      zh: { title: "📈 你能赚多少？", body: "{views} 次浏览最多可赚 {amount} FCFA，取决于你的等级。满 {min} FCFA 即可提现。" },
      sw: { title: "📈 Unaweza kupata kiasi gani?", body: "Mitazamo {views} inaweza kukuletea hadi {amount} FCFA kulingana na kiwango chako. Toa kuanzia {min} FCFA." },
    },
  },
  {
    topic: "creator", target: "RAPPEL_MONETISATION",
    texts: {
      fr: { title: "🚀 La méthode des créateurs qui gagnent", body: "Publie régulièrement, réponds à ta communauté et monte en niveau : plus ton niveau est haut, plus chaque vue rapporte." },
      en: { title: "🚀 How top creators earn", body: "Post regularly, engage with your community and level up: the higher your level, the more each view pays." },
      es: { title: "🚀 El método de los creadores que ganan", body: "Publica con regularidad, responde a tu comunidad y sube de nivel: cuanto más alto, más rinde cada vista." },
      de: { title: "🚀 So verdienen erfolgreiche Creator", body: "Poste regelmäßig, antworte deiner Community und steige im Level auf: je höher, desto mehr bringt jeder Aufruf." },
      ar: { title: "🚀 طريقة المبدعين الذين يربحون", body: "انشر بانتظام وتفاعل مع مجتمعك وارتقِ بمستواك: كلما ارتفع مستواك زاد ربح كل مشاهدة." },
      pt: { title: "🚀 O método dos criadores que ganham", body: "Publique com regularidade, responda à comunidade e suba de nível: quanto mais alto, mais cada visualização rende." },
      zh: { title: "🚀 赚钱创作者的做法", body: "定期发布、回应你的社群并提升等级：等级越高，每次浏览收益越多。" },
      sw: { title: "🚀 Njia ya waundaji wanaopata", body: "Chapisha mara kwa mara, jibu jumuiya yako na upande ngazi: kadri ngazi inavyopanda, kila mtazamo hulipa zaidi." },
    },
  },
  {
    topic: "referral", target: "RAPPEL_PARRAINAGE",
    texts: {
      fr: { title: "🤝 Parraine et gagne 75 %", body: "Reçois 75 % de commission sur chaque activation de tes filleuls. Plus tu invites tôt, plus tu gagnes." },
      en: { title: "🤝 Refer and earn 75%", body: "Get a 75% commission on each activation by your referrals. The sooner you invite, the more you earn." },
      es: { title: "🤝 Recomienda y gana el 75 %", body: "Recibe un 75 % de comisión por cada activación de tus referidos. Cuanto antes invites, más ganas." },
      de: { title: "🤝 Empfiehl weiter und erhalte 75 %", body: "Erhalte 75 % Provision auf jede Aktivierung deiner Geworbenen. Je früher du einlädst, desto mehr verdienst du." },
      ar: { title: "🤝 ادعُ أصدقاءك واربح 75%", body: "احصل على عمولة 75% عن كل تفعيل يقوم به من دعوتهم. كلما دعوت مبكرًا زادت أرباحك." },
      pt: { title: "🤝 Indique e ganhe 75 %", body: "Receba 75 % de comissão por cada ativação dos seus indicados. Quanto mais cedo convidar, mais ganha." },
      zh: { title: "🤝 推荐好友，赚取 75%", body: "你邀请的好友每次激活，你都可获得 75% 佣金。越早邀请，赚得越多。" },
      sw: { title: "🤝 Alika na upate 75%", body: "Pata kamisheni ya 75% kwa kila uwezeshaji wa walioalikwa na wewe. Kadri unavyoalika mapema, ndivyo unavyopata zaidi." },
    },
  },
  {
    topic: "live", target: "RAPPEL_LIVE",
    texts: {
      fr: { title: "🔴 Passe en live", body: "Retrouve ta communauté en direct, reçois des cadeaux et fais grandir ton audience." },
      en: { title: "🔴 Go live", body: "Meet your community in real time, receive gifts and grow your audience." },
      es: { title: "🔴 Haz un directo", body: "Encuentra a tu comunidad en vivo, recibe regalos y haz crecer tu audiencia." },
      de: { title: "🔴 Geh live", body: "Triff deine Community live, erhalte Geschenke und vergrößere dein Publikum." },
      ar: { title: "🔴 ابدأ بثًا مباشرًا", body: "التقِ بمجتمعك مباشرة، واستقبل الهدايا ونمِّ جمهورك." },
      pt: { title: "🔴 Faça uma live", body: "Encontre a sua comunidade em direto, receba presentes e faça crescer a sua audiência." },
      zh: { title: "🔴 开启直播", body: "与你的社群实时见面，收获礼物，扩大你的粉丝群。" },
      sw: { title: "🔴 Anza matangazo ya moja kwa moja", body: "Kutana na jumuiya yako moja kwa moja, pokea zawadi na ukuze hadhira yako." },
    },
  },
  {
    topic: "sellLive", target: "RAPPEL_LIVE",
    texts: {
      fr: { title: "🛍️ Vends en direct", body: "Présente tes produits en live : on voit, on pose ses questions et on achète. Lance ton premier live." },
      en: { title: "🛍️ Sell live", body: "Show your products live: people see them, ask questions and buy. Start your first live." },
      es: { title: "🛍️ Vende en directo", body: "Presenta tus productos en vivo: la gente los ve, pregunta y compra. Lanza tu primer directo." },
      de: { title: "🛍️ Verkaufe live", body: "Zeig deine Produkte live: Die Leute sehen sie, fragen nach und kaufen. Starte dein erstes Live." },
      ar: { title: "🛍️ بِع مباشرة", body: "اعرض منتجاتك في بث مباشر: يراها الناس ويسألون ثم يشترون. ابدأ أول بث لك." },
      pt: { title: "🛍️ Venda em direto", body: "Apresente os seus produtos numa live: as pessoas veem, perguntam e compram. Comece a sua primeira live." },
      zh: { title: "🛍️ 直播带货", body: "在直播中展示你的产品：大家看得到、能提问，也能下单。开启你的第一场直播。" },
      sw: { title: "🛍️ Uza moja kwa moja", body: "Onyesha bidhaa zako katika matangazo ya moja kwa moja: watu wanaona, wanauliza na wananunua. Anza la kwanza." },
    },
  },
  {
    topic: "channel", target: "RAPPEL_CANAL",
    texts: {
      fr: { title: "📺 Crée ton canal", body: "Rassemble ta communauté, publie ton contenu et fidélise tes abonnés." },
      en: { title: "📺 Create your channel", body: "Bring your community together, publish your content and keep your followers coming back." },
      es: { title: "📺 Crea tu canal", body: "Reúne a tu comunidad, publica tu contenido y fideliza a tus seguidores." },
      de: { title: "📺 Erstelle deinen Kanal", body: "Bring deine Community zusammen, veröffentliche Inhalte und binde deine Follower." },
      ar: { title: "📺 أنشئ قناتك", body: "اجمع مجتمعك وانشر محتواك وحافظ على ولاء متابعيك." },
      pt: { title: "📺 Crie o seu canal", body: "Reúna a sua comunidade, publique o seu conteúdo e fidelize os seus seguidores." },
      zh: { title: "📺 创建你的频道", body: "汇聚你的社群，发布内容，留住你的粉丝。" },
      sw: { title: "📺 Tengeneza kituo chako", body: "Kusanya jumuiya yako, chapisha maudhui yako na uwafanye wafuasi wako warudi." },
    },
  },
  {
    topic: "group", target: "RAPPEL_GROUPE",
    texts: {
      fr: { title: "👥 Crée ton groupe", body: "Discute avec ta communauté. Dans un groupe privé payant, 70 % des abonnements te reviennent." },
      en: { title: "👥 Create your group", body: "Chat with your community. In a paid private group, you keep 70% of subscriptions." },
      es: { title: "👥 Crea tu grupo", body: "Conversa con tu comunidad. En un grupo privado de pago, el 70 % de las suscripciones es para ti." },
      de: { title: "👥 Erstelle deine Gruppe", body: "Chatte mit deiner Community. In einer kostenpflichtigen privaten Gruppe bleiben 70 % der Abos bei dir." },
      ar: { title: "👥 أنشئ مجموعتك", body: "تحدّث مع مجتمعك. في المجموعة الخاصة المدفوعة يعود إليك 70% من الاشتراكات." },
      pt: { title: "👥 Crie o seu grupo", body: "Converse com a sua comunidade. Num grupo privado pago, 70 % das subscrições são suas." },
      zh: { title: "👥 创建你的群组", body: "与你的社群交流。付费私密群组的订阅收入，70% 归你。" },
      sw: { title: "👥 Tengeneza kikundi chako", body: "Zungumza na jumuiya yako. Katika kikundi binafsi cha malipo, 70% ya michango inakuwa yako." },
    },
  },
  {
    topic: "packs", target: "RAPPEL_MONETISATION",
    texts: {
      fr: { title: "🎨 Vends tes stickers", body: "70 % du prix de chaque pack vendu te revient, en pièces gagnées. Crée le tien." },
      en: { title: "🎨 Sell your stickers", body: "70% of the price of each pack sold comes to you, in earned coins. Create yours." },
      es: { title: "🎨 Vende tus stickers", body: "El 70 % del precio de cada pack vendido es para ti, en monedas ganadas. Crea el tuyo." },
      de: { title: "🎨 Verkaufe deine Sticker", body: "70 % des Preises jedes verkauften Packs gehen an dich, in verdienten Münzen. Erstelle deins." },
      ar: { title: "🎨 بِع ملصقاتك", body: "70% من سعر كل حزمة مباعة تعود إليك على شكل عملات مكتسبة. أنشئ حزمتك." },
      pt: { title: "🎨 Venda os seus stickers", body: "70 % do preço de cada pack vendido é seu, em moedas ganhas. Crie o seu." },
      zh: { title: "🎨 出售你的贴纸", body: "每售出一个贴纸包，价格的 70% 归你，以赚得的金币结算。来创建你的贴纸包。" },
      sw: { title: "🎨 Uza stika zako", body: "70% ya bei ya kila kifurushi kinachouzwa ni yako, kwa sarafu ulizopata. Tengeneza chako." },
    },
  },
  {
    topic: "weekly", target: "RAPPEL_CLASSEMENT",
    texts: {
      fr: { title: "🏆 Le top des commentateurs", body: "Les meilleurs commentateurs de la semaine gagnent jusqu’à 500 pièces. Commente et monte au classement." },
      en: { title: "🏆 Top commenters of the week", body: "The week’s best commenters win up to 500 coins. Comment and climb the ranking." },
      es: { title: "🏆 Los mejores comentaristas", body: "Los mejores comentaristas de la semana ganan hasta 500 monedas. Comenta y sube en el ranking." },
      de: { title: "🏆 Top-Kommentierer der Woche", body: "Die besten Kommentierer der Woche gewinnen bis zu 500 Münzen. Kommentiere und steige im Ranking auf." },
      ar: { title: "🏆 أفضل المعلّقين", body: "أفضل معلّقي الأسبوع يربحون حتى 500 عملة. علّق وارتقِ في الترتيب." },
      pt: { title: "🏆 Os melhores comentadores", body: "Os melhores comentadores da semana ganham até 500 moedas. Comente e suba no ranking." },
      zh: { title: "🏆 本周评论榜", body: "本周最佳评论者最高可获 500 金币。多评论，冲榜吧。" },
      sw: { title: "🏆 Wachangiaji bora wa wiki", body: "Wachangiaji bora wa wiki hushinda hadi sarafu 500. Toa maoni na upande kwenye orodha." },
    },
  },
  {
    topic: "shop", target: "RAPPEL_BOUTIQUE",
    texts: {
      fr: { title: "🛒 La vente directe arrive bientôt", body: "Bientôt, vends tes produits en ligne directement sur Afrolook. Prépare ta communauté dès maintenant." },
      en: { title: "🛒 Direct online selling is coming soon", body: "Soon you’ll be able to sell your products online right on Afrolook. Start building your community now." },
      es: { title: "🛒 La venta directa llega pronto", body: "Pronto podrás vender tus productos en línea directamente en Afrolook. Prepara a tu comunidad desde ya." },
      de: { title: "🛒 Direktverkauf kommt bald", body: "Bald kannst du deine Produkte direkt auf Afrolook online verkaufen. Baue jetzt deine Community auf." },
      ar: { title: "🛒 البيع المباشر قريبًا", body: "قريبًا ستتمكن من بيع منتجاتك عبر الإنترنت مباشرة على أفرولوك. جهّز مجتمعك من الآن." },
      pt: { title: "🛒 A venda direta chega em breve", body: "Em breve poderá vender os seus produtos online diretamente no Afrolook. Prepare já a sua comunidade." },
      zh: { title: "🛒 在线直销即将上线", body: "很快你就能直接在 Afrolook 上在线销售你的产品。现在就开始积累你的社群。" },
      sw: { title: "🛒 Uuzaji wa moja kwa moja unakuja hivi karibuni", body: "Hivi karibuni utaweza kuuza bidhaa zako mtandaoni moja kwa moja kwenye Afrolook. Anza kujenga jumuiya yako sasa." },
    },
  },
  {
    topic: "about", target: "RAPPEL_ABOUT",
    texts: {
      fr: { title: "🌍 Afrolook, c’est ta communauté", body: "Réseau social, lives, quiz, études et contes : tout au même endroit, avec des façons de gagner." },
      en: { title: "🌍 Afrolook is your community", body: "Social network, lives, quizzes, study and tales: all in one place, with ways to earn." },
      es: { title: "🌍 Afrolook es tu comunidad", body: "Red social, directos, quiz, estudio y cuentos: todo en un solo lugar, con formas de ganar." },
      de: { title: "🌍 Afrolook ist deine Community", body: "Soziales Netzwerk, Lives, Quiz, Lernen und Erzählungen: alles an einem Ort, mit Verdienstmöglichkeiten." },
      ar: { title: "🌍 أفرولوك هو مجتمعك", body: "شبكة اجتماعية وبث مباشر واختبارات ودراسة وحكايات: كل ذلك في مكان واحد مع طرق للربح." },
      pt: { title: "🌍 O Afrolook é a sua comunidade", body: "Rede social, lives, quizzes, estudo e contos: tudo num só lugar, com formas de ganhar." },
      zh: { title: "🌍 Afrolook 是你的社群", body: "社交网络、直播、问答、学习和故事：全在一处，还有赚钱的方式。" },
      sw: { title: "🌍 Afrolook ni jumuiya yako", body: "Mtandao wa kijamii, matangazo ya moja kwa moja, maswali, masomo na hadithi: vyote mahali pamoja, vyenye njia za kupata." },
    },
  },
  {
    topic: "comment", target: "RAPPEL_COMMENTER",
    texts: {
      fr: { title: "💬 Commenter, ça rapporte", body: "Chaque semaine, les meilleurs commentateurs gagnent des pièces. Commente les posts des créateurs et monte au classement." },
      en: { title: "💬 Commenting pays off", body: "Every week, the best commenters win coins. Comment on creators’ posts and climb the ranking." },
      es: { title: "💬 Comentar da recompensa", body: "Cada semana, los mejores comentaristas ganan monedas. Comenta las publicaciones de los creadores y sube en el ranking." },
      de: { title: "💬 Kommentieren lohnt sich", body: "Jede Woche gewinnen die besten Kommentierer Münzen. Kommentiere Beiträge von Creatorn und steige im Ranking auf." },
      ar: { title: "💬 التعليق يستحق", body: "كل أسبوع يربح أفضل المعلّقين عملات. علّق على منشورات المبدعين وارتقِ في الترتيب." },
      pt: { title: "💬 Comentar compensa", body: "Todas as semanas, os melhores comentadores ganham moedas. Comente as publicações dos criadores e suba no ranking." },
      zh: { title: "💬 评论有回报", body: "每周最佳评论者都能赢得金币。评论创作者的帖子，冲上排行榜。" },
      sw: { title: "💬 Kutoa maoni kunalipa", body: "Kila wiki wachangiaji bora hushinda sarafu. Toa maoni kwenye machapisho ya waundaji na upande kwenye orodha." },
    },
  },
  {
    topic: "flame", target: "RAPPEL_COMMENTER",
    texts: {
      fr: { title: "🔥 Allume ta flamme", body: "Commente chaque jour pour garder ta série de flammes et grimper au classement." },
      en: { title: "🔥 Keep your flame lit", body: "Comment every day to keep your flame streak going and climb the ranking." },
      es: { title: "🔥 Mantén tu llama encendida", body: "Comenta cada día para conservar tu racha de llamas y subir en el ranking." },
      de: { title: "🔥 Halte deine Flamme am Brennen", body: "Kommentiere jeden Tag, um deine Flammen-Serie zu halten und im Ranking aufzusteigen." },
      ar: { title: "🔥 أبقِ شعلتك مشتعلة", body: "علّق كل يوم لتحافظ على سلسلة الشعلات وترتقي في الترتيب." },
      pt: { title: "🔥 Mantenha a sua chama acesa", body: "Comente todos os dias para manter a sua série de chamas e subir no ranking." },
      zh: { title: "🔥 让你的火焰不熄灭", body: "每天评论，保持火焰连续天数，并冲上排行榜。" },
      sw: { title: "🔥 Weka mwali wako ukiwaka", body: "Toa maoni kila siku ili kudumisha mfululizo wa miali na kupanda kwenye orodha." },
    },
  },
  {
    topic: "musicUpload", target: "RAPPEL_MUSIQUE",
    texts: {
      fr: { title: "🎵 Mets ta musique en ligne", body: "Publie tes titres sur Afrolook : écoutes, ventes et utilisations dans les posts peuvent te rapporter des pièces." },
      en: { title: "🎵 Put your music online", body: "Publish your tracks on Afrolook: listens, sales and uses in posts can earn you coins." },
      es: { title: "🎵 Sube tu música", body: "Publica tus temas en Afrolook: escuchas, ventas y usos en publicaciones pueden darte monedas." },
      de: { title: "🎵 Stelle deine Musik online", body: "Veröffentliche deine Titel auf Afrolook: Hörer, Verkäufe und Nutzungen in Beiträgen können dir Münzen bringen." },
      ar: { title: "🎵 انشر موسيقاك", body: "انشر أغانيك على أفرولوك: الاستماع والمبيعات والاستخدام في المنشورات قد تدرّ عليك عملات." },
      pt: { title: "🎵 Coloque a sua música online", body: "Publique as suas faixas no Afrolook: audições, vendas e utilizações em publicações podem render moedas." },
      zh: { title: "🎵 上传你的音乐", body: "在 Afrolook 发布你的作品：收听、销售以及在帖子中被使用都可能为你带来金币。" },
      sw: { title: "🎵 Weka muziki wako mtandaoni", body: "Chapisha nyimbo zako kwenye Afrolook: usikilizaji, mauzo na matumizi kwenye machapisho yanaweza kukuletea sarafu." },
    },
  },
  {
    topic: "musicEarn", target: "RAPPEL_ARTISTE",
    texts: {
      fr: { title: "💿 Ce que gagnent les artistes", body: "Tu fixes tes prix et tu touches 60 % de chaque vente et de chaque utilisation, en pièces gagnées convertibles en argent." },
      en: { title: "💿 What artists earn", body: "You set your prices and keep 60% of every sale and every use, in earned coins you can convert to cash." },
      es: { title: "💿 Lo que ganan los artistas", body: "Tú fijas tus precios y recibes el 60 % de cada venta y de cada uso, en monedas ganadas convertibles en dinero." },
      de: { title: "💿 Das verdienen Künstler", body: "Du legst deine Preise fest und erhältst 60 % jedes Verkaufs und jeder Nutzung, in verdienten Münzen, die du in Geld umwandeln kannst." },
      ar: { title: "💿 ما يربحه الفنانون", body: "أنت تحدد أسعارك وتحصل على 60% من كل عملية بيع وكل استخدام، بعملات مكتسبة يمكن تحويلها إلى مال." },
      pt: { title: "💿 O que ganham os artistas", body: "Você define os preços e recebe 60 % de cada venda e de cada utilização, em moedas ganhas convertíveis em dinheiro." },
      zh: { title: "💿 艺术家能赚多少", body: "价格由你定，每次销售和每次使用你都能获得 60%，以赚得的金币结算，可兑换成现金。" },
      sw: { title: "💿 Kile wanachopata wasanii", body: "Unaweka bei zako na kupata 60% ya kila mauzo na kila matumizi, kwa sarafu ulizopata zinazobadilishwa kuwa pesa." },
    },
  },
  {
    // Invitation à suivre la CHAÎNE WhatsApp d'Afrolook : un clic ouvre la chaîne (https://whatsapp.com/channel/…), pas un contact
    topic: "whatsapp", target: "RAPPEL_WHATSAPP",
    texts: {
      fr: { title: "📲 Suis-nous sur WhatsApp", body: "Rejoins la chaîne officielle Afrolook : actus, astuces pour gagner et nouveautés en avant-première." },
      en: { title: "📲 Follow us on WhatsApp", body: "Join the official Afrolook channel: news, tips to earn and early updates." },
      es: { title: "📲 Síguenos en WhatsApp", body: "Únete al canal oficial de Afrolook: novedades, consejos para ganar y avances en primicia." },
      de: { title: "📲 Folge uns auf WhatsApp", body: "Tritt dem offiziellen Afrolook-Kanal bei: News, Verdienst-Tipps und Neuheiten vorab." },
      ar: { title: "📲 تابعنا على واتساب", body: "انضم إلى قناة أفرولوك الرسمية: الأخبار ونصائح الربح والمستجدات أولًا بأول." },
      pt: { title: "📲 Siga-nos no WhatsApp", body: "Entre no canal oficial do Afrolook: novidades, dicas para ganhar e novidades em primeira mão." },
      zh: { title: "📲 在 WhatsApp 上关注我们", body: "加入 Afrolook 官方频道：资讯、赚钱技巧和抢先体验。" },
      sw: { title: "📲 Tufuate kwenye WhatsApp", body: "Jiunge na kituo rasmi cha Afrolook: habari, vidokezo vya kupata na mambo mapya kabla ya wengine." },
    },
  },
  {
    topic: "facebook", target: "RAPPEL_FACEBOOK",
    texts: {
      fr: { title: "👍 Suis-nous sur Facebook", body: "Rejoins notre page : actus, annonces et conseils pour réussir sur Afrolook." },
      en: { title: "👍 Follow us on Facebook", body: "Join our page: news, announcements and tips to succeed on Afrolook." },
      es: { title: "👍 Síguenos en Facebook", body: "Únete a nuestra página: novedades, anuncios y consejos para triunfar en Afrolook." },
      de: { title: "👍 Folge uns auf Facebook", body: "Besuche unsere Seite: News, Ankündigungen und Tipps für deinen Erfolg auf Afrolook." },
      ar: { title: "👍 تابعنا على فيسبوك", body: "انضم إلى صفحتنا: الأخبار والإعلانات ونصائح للنجاح على أفرولوك." },
      pt: { title: "👍 Siga-nos no Facebook", body: "Junte-se à nossa página: novidades, anúncios e dicas para ter sucesso no Afrolook." },
      zh: { title: "👍 在 Facebook 关注我们", body: "加入我们的主页：资讯、公告和在 Afrolook 成功的小技巧。" },
      sw: { title: "👍 Tufuate kwenye Facebook", body: "Jiunge na ukurasa wetu: habari, matangazo na vidokezo vya kufanikiwa kwenye Afrolook." },
    },
  },
  {
    topic: "tiktok", target: "RAPPEL_TIKTOK",
    texts: {
      fr: { title: "🎬 Retrouve-nous sur TikTok", body: "Des vidéos, des astuces et les coulisses d’Afrolook t’attendent." },
      en: { title: "🎬 Find us on TikTok", body: "Videos, tips and behind-the-scenes of Afrolook are waiting for you." },
      es: { title: "🎬 Encuéntranos en TikTok", body: "Te esperan vídeos, consejos y los entresijos de Afrolook." },
      de: { title: "🎬 Finde uns auf TikTok", body: "Videos, Tipps und Einblicke hinter die Kulissen von Afrolook warten auf dich." },
      ar: { title: "🎬 تجدنا على تيك توك", body: "فيديوهات ونصائح وكواليس أفرولوك بانتظارك." },
      pt: { title: "🎬 Encontre-nos no TikTok", body: "Vídeos, dicas e bastidores do Afrolook esperam por si." },
      zh: { title: "🎬 在 TikTok 找到我们", body: "视频、技巧和 Afrolook 的幕后花絮等着你。" },
      sw: { title: "🎬 Tupate kwenye TikTok", body: "Video, vidokezo na nyuma ya pazia ya Afrolook vinakusubiri." },
    },
  },
  {
    topic: "newsMusic", target: "RAPPEL_NOUVEAUTE_MUSIQUE",
    texts: {
      fr: { title: "🆕 Nouveau : la musique sur Afrolook", body: "Écoute des artistes africains, utilise leurs sons dans tes posts et soutiens-les." },
      en: { title: "🆕 New: music on Afrolook", body: "Listen to African artists, use their sounds in your posts and support them." },
      es: { title: "🆕 Novedad: música en Afrolook", body: "Escucha artistas africanos, usa sus sonidos en tus publicaciones y apóyalos." },
      de: { title: "🆕 Neu: Musik auf Afrolook", body: "Höre afrikanische Künstler, nutze ihre Sounds in deinen Beiträgen und unterstütze sie." },
      ar: { title: "🆕 جديد: الموسيقى على أفرولوك", body: "استمع لفنانين أفارقة واستخدم أصواتهم في منشوراتك وادعمهم." },
      pt: { title: "🆕 Novo: música no Afrolook", body: "Ouça artistas africanos, use os sons deles nas suas publicações e apoie-os." },
      zh: { title: "🆕 新功能：Afrolook 音乐", body: "收听非洲艺术家的作品，在帖子中使用他们的声音并支持他们。" },
      sw: { title: "🆕 Mpya: muziki kwenye Afrolook", body: "Sikiliza wasanii wa Afrika, tumia sauti zao kwenye machapisho yako na uwaunge mkono." },
    },
  },
  {
    topic: "newsDefi", target: "RAPPEL_NOUVEAUTE_DEFI",
    texts: {
      fr: { title: "🆕 Les DÉFIS sont arrivés", body: "Relève un défi, vote et fais vibrer la communauté. Viens voir." },
      en: { title: "🆕 Challenges are here", body: "Take on a challenge, vote and get the community buzzing. Come and see." },
      es: { title: "🆕 Llegaron los RETOS", body: "Acepta un reto, vota y haz vibrar a la comunidad. Ven a verlo." },
      de: { title: "🆕 Die CHALLENGES sind da", body: "Nimm eine Challenge an, stimme ab und bring die Community in Schwung. Schau vorbei." },
      ar: { title: "🆕 وصلت التحديات", body: "خُض تحديًا وصوّت وأشعل حماس المجتمع. تعال وشاهد." },
      pt: { title: "🆕 Os DESAFIOS chegaram", body: "Aceite um desafio, vote e anime a comunidade. Venha ver." },
      zh: { title: "🆕 挑战来了", body: "接受挑战、投票，让社群热闹起来。快来看看。" },
      sw: { title: "🆕 Changamoto zimewasili", body: "Chukua changamoto, piga kura na uchangamshe jumuiya. Njoo uone." },
    },
  },
  {
    topic: "newsStudy", target: "RAPPEL_NOUVEAUTE_ETUDE",
    texts: {
      fr: { title: "🆕 Étudie sur Afrolook", body: "Cours, quiz et diplômes : progresse chapitre après chapitre, à ton rythme." },
      en: { title: "🆕 Study on Afrolook", body: "Lessons, quizzes and diplomas: progress chapter by chapter, at your own pace." },
      es: { title: "🆕 Estudia en Afrolook", body: "Lecciones, quizzes y diplomas: avanza capítulo a capítulo, a tu ritmo." },
      de: { title: "🆕 Lerne auf Afrolook", body: "Lektionen, Quiz und Abschlüsse: komm Kapitel für Kapitel voran, in deinem Tempo." },
      ar: { title: "🆕 ادرس على أفرولوك", body: "دروس واختبارات وشهادات: تقدّم فصلًا بعد فصل وبالوتيرة التي تناسبك." },
      pt: { title: "🆕 Estude no Afrolook", body: "Aulas, quizzes e diplomas: avance capítulo a capítulo, ao seu ritmo." },
      zh: { title: "🆕 在 Afrolook 学习", body: "课程、问答和文凭：按自己的节奏，一章一章地前进。" },
      sw: { title: "🆕 Soma kwenye Afrolook", body: "Masomo, maswali na vyeti: songa sura baada ya sura, kwa kasi yako." },
    },
  },
  {
    topic: "newsContes", target: "RAPPEL_NOUVEAUTE_CONTES",
    texts: {
      fr: { title: "🆕 Des contes africains à lire", body: "De nouvelles histoires t’attendent, avec un quiz pour gagner des pièces." },
      en: { title: "🆕 African tales to read", body: "New stories are waiting for you, with a quiz to win coins." },
      es: { title: "🆕 Cuentos africanos para leer", body: "Te esperan nuevas historias, con un quiz para ganar monedas." },
      de: { title: "🆕 Afrikanische Märchen zum Lesen", body: "Neue Geschichten warten auf dich, mit Quiz und Münzen." },
      ar: { title: "🆕 حكايات أفريقية للقراءة", body: "قصص جديدة بانتظارك مع اختبار لربح العملات." },
      pt: { title: "🆕 Contos africanos para ler", body: "Novas histórias esperam por si, com um quiz para ganhar moedas." },
      zh: { title: "🆕 值得一读的非洲故事", body: "新故事等着你，还有问答可赢金币。" },
      sw: { title: "🆕 Hadithi za Kiafrika za kusoma", body: "Hadithi mpya zinakusubiri, na maswali ya kushinda sarafu." },
    },
  },
];

/** Mention « Pub » d'une pub Afrolook envoyée par notification, dans la langue de la personne. */
export const AD_LABEL: Record<Lang, string> = { fr: "Pub", en: "Ad", es: "Anuncio", de: "Anzeige", ar: "إعلان", pt: "Anúncio", zh: "广告", sw: "Tangazo" };

/** Promotion d'un nouveau créateur : mention du titre et texte de repli (quand son post n'a pas de texte), dans la langue de la personne. */
export const NEW_CREATOR_LABEL: Record<Lang, string> = {
  fr: "Nouveau créateur", en: "New creator", es: "Nuevo creador", de: "Neuer Creator", ar: "مبدع جديد", pt: "Novo criador", zh: "新创作者", sw: "Mwundaji mpya",
};
export const NEW_CREATOR_BODY: Record<Lang, string> = {
  fr: "Découvre son dernier post et encourage-le en t'abonnant.",
  en: "Check out their latest post and cheer them on by following.",
  es: "Descubre su última publicación y anímale siguiéndole.",
  de: "Schau dir den neuesten Beitrag an und unterstütze mit einem Follow.",
  ar: "اكتشف آخر منشور له وشجّعه بمتابعته.",
  pt: "Descubra a última publicação e incentive seguindo.",
  zh: "看看他的最新帖子，关注来鼓励他吧。",
  sw: "Tazama chapisho lake la hivi karibuni na umtie moyo kwa kumfuata.",
};

/** Langue d'un profil (champ `appLang`) : une des 8 langues de l'application, sinon le français. */
export function langOf(v: unknown): Lang {
  const s = String(v ?? "").toLowerCase().slice(0, 2);
  return (LANGS as string[]).includes(s) ? (s as Lang) : "fr";
}

/** Sujet du jour pour une personne : tourne d'un jour à l'autre, décalé selon la personne pour que tout le monde ne reçoive pas le même. */
export function topicIndex(dayIndex: number, uidHash: number): number {
  return (((dayIndex + uidHash) % TIPS.length) + TIPS.length) % TIPS.length;
}

/** Hachage simple et stable d'un identifiant (répartition des sujets). */
export function hashId(id: string): number {
  let h = 2166136261;
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

/** Texte final d'un sujet dans une langue, variables remplacées. */
export function tipText(tip: Tip, lang: Lang, vars: TipVars): Text {
  const t = tip.texts[lang] ?? tip.texts.fr;
  const fill = (s: string) => s.replace("{views}", vars.views).replace("{amount}", vars.amount).replace("{min}", vars.min);
  return { title: fill(t.title), body: fill(t.body) };
}

/** Nombre formaté simplement (espace fine pour les milliers). */
export function fmt(n: number): string {
  return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
}

// ─── Rappels d'engagement : textes dans la langue choisie ─────────────────────────────────────────────────
// Français : plusieurs variantes (policy_logic.copyFor). Autres langues : un texte par rappel ; le nombre de nouveaux posts n'y est pas cité
// (pas de pluriel à gérer). Une langue inconnue retombe sur le français.
import { copyFor, ReminderKind } from "./policy_logic";

type SimpleKind = "quiz" | "etude" | "conte" | "feed" | "comeback";
const OTHER: Record<SimpleKind, Record<Exclude<Lang, "fr">, Text>> = {
  quiz: {
    en: { title: "🎯 Today’s quiz is waiting", body: "3 questions, coins to win. Ready to play?" },
    es: { title: "🎯 Tu quiz del día te espera", body: "3 preguntas y monedas por ganar. ¿Listo para jugar?" },
    de: { title: "🎯 Dein Tagesquiz wartet", body: "3 Fragen, Münzen zu gewinnen. Bereit?" },
    ar: { title: "🎯 اختبار اليوم بانتظارك", body: "3 أسئلة وعملات للفوز بها. هل أنت مستعد؟" },
    pt: { title: "🎯 O quiz do dia espera por si", body: "3 perguntas e moedas para ganhar. Pronto para jogar?" },
    zh: { title: "🎯 今日问答等你来", body: "3 道题，还有金币可赢。准备好了吗？" },
    sw: { title: "🎯 Maswali ya leo yanakusubiri", body: "Maswali 3, sarafu za kushinda. Uko tayari?" },
  },
  etude: {
    en: { title: "📚 5 minutes to move forward", body: "A short chapter will help you progress toward your diploma." },
    es: { title: "📚 5 minutos para avanzar", body: "Un capítulo corto te acerca a tu diploma." },
    de: { title: "📚 5 Minuten für den Fortschritt", body: "Ein kurzes Kapitel bringt dich deinem Abschluss näher." },
    ar: { title: "📚 5 دقائق للتقدم", body: "فصل قصير يقرّبك من شهادتك." },
    pt: { title: "📚 5 minutos para avançar", body: "Um capítulo curto aproxima-o do seu diploma." },
    zh: { title: "📚 5 分钟，向前一步", body: "一个短章节，让你离文凭更近。" },
    sw: { title: "📚 Dakika 5 za kusonga mbele", body: "Sura fupi itakusogeza karibu na cheti chako." },
  },
  conte: {
    en: { title: "🌙 An African tale for you", body: "A story to discover, with a quiz to win coins." },
    es: { title: "🌙 Un cuento africano para ti", body: "Una historia por descubrir, con un quiz para ganar monedas." },
    de: { title: "🌙 Ein afrikanisches Märchen für dich", body: "Eine Geschichte zum Entdecken, mit Quiz und Münzen." },
    ar: { title: "🌙 حكاية أفريقية لك", body: "قصة لتكتشفها مع اختبار لربح العملات." },
    pt: { title: "🌙 Um conto africano para si", body: "Uma história para descobrir, com um quiz para ganhar moedas." },
    zh: { title: "🌙 为你准备的非洲故事", body: "发现一个故事，再用问答赢取金币。" },
    sw: { title: "🌙 Hadithi ya Kiafrika kwa ajili yako", body: "Hadithi ya kugundua, na maswali ya kushinda sarafu." },
  },
  feed: {
    en: { title: "🔥 Your creators have posted", body: "New posts from creators you follow are waiting for you." },
    es: { title: "🔥 Tus creadores han publicado", body: "Te esperan nuevas publicaciones de los creadores que sigues." },
    de: { title: "🔥 Deine Creator haben gepostet", body: "Neue Beiträge der Creator, denen du folgst, warten auf dich." },
    ar: { title: "🔥 مبدعوك نشروا جديدًا", body: "منشورات جديدة من المبدعين الذين تتابعهم بانتظارك." },
    pt: { title: "🔥 Os seus criadores publicaram", body: "Há novas publicações dos criadores que segue à sua espera." },
    zh: { title: "🔥 你关注的创作者更新了", body: "你关注的创作者有新帖子等你查看。" },
    sw: { title: "🔥 Waundaji wako wamechapisha", body: "Machapisho mapya ya waundaji unaowafuata yanakusubiri." },
  },
  comeback: {
    en: { title: "👋 We’ve missed you", body: "News, quizzes and creators are waiting for you." },
    es: { title: "👋 Te echamos de menos", body: "Novedades, quizzes y creadores te esperan." },
    de: { title: "👋 Wir haben dich vermisst", body: "Neuigkeiten, Quiz und Creator warten auf dich." },
    ar: { title: "👋 اشتقنا إليك", body: "أخبار واختبارات ومبدعون بانتظارك." },
    pt: { title: "👋 Sentimos a sua falta", body: "Novidades, quizzes e criadores esperam por si." },
    zh: { title: "👋 我们想你了", body: "新鲜内容、问答和创作者正等着你。" },
    sw: { title: "👋 Tumekukosa", body: "Habari, maswali na waundaji wanakusubiri." },
  },
};

/** Texte d'un rappel d'engagement dans la langue de la personne. */
export function reminderText(kind: ReminderKind, lang: Lang, variantSeed: number, unseen = 0, streak = 0): Text {
  if (lang !== "fr" && kind in OTHER) return OTHER[kind as SimpleKind][lang];
  return copyFor(kind, variantSeed, streak, unseen);
}
