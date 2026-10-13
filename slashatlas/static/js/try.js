// Studio SlashAtlas : connexion Google, crédits, achat par mobile money, génération avec Gemini.
(function () {
  'use strict';
  var root = document.getElementById('studio');
  if (!root) return;
  var CONTACT = (document.getElementById('studio') || {dataset: {}}).dataset.contact || '';
  var L = document.body.dataset.lang === 'en' ? 'en' : 'fr';
  var T = {
    fr: {
      login: 'Continuer avec Google', loginNote: 'Connexion rapide avec votre compte Google. Si vous avez déjà un compte, vous êtes simplement reconnecté.',
      tabImage: 'Image', tabVideo: 'Vidéo', tabNew: 'Nouveau', vLoginTitle: 'Créez une vidéo publicitaire pour votre produit', vLoginText: 'Animations, musique et voix off facultative, à partir de vos photos. Connectez-vous pour commencer.',
      tabImage: 'Image', tabVideo: 'Vidéo', tabNew: 'Nouveau', vLoginTitle: 'Créez une vidéo publicitaire pour votre produit', vLoginText: 'Animations, musique et voix off facultative, à partir de vos photos. Connectez-vous pour commencer.',
      hello: 'Bonjour', back: 'Content de vous revoir', welcome: 'Compte créé', credits: 'crédits', credit: 'crédit', buy: 'Acheter des crédits', logout: 'Se déconnecter',
      cmd: 'Commande', change: 'Changer', photos: 'Vos photos', photosHint: 'Jusqu’à 3 photos (un ou plusieurs produits). JPG, PNG ou WebP.', add: 'Ajouter une photo', remove: 'Retirer',
      prodLabel: { product: 'Votre produit', dish: 'Votre plat', person: 'Sur la photo', place: 'Votre bien' }, prodPh: 'ex. crème visage, 3 bouteilles de jus', single: 'Un seul', several: 'Plusieurs',
      scene: 'Mise en scène', sceneHint: 'Décrivez le fond, l'ambiance ou comment composer la scène. Facultatif.', scenePh: 'ex. fond de marché africain, la personne porte le vêtement, ambiance coucher de soleil', sceneChips: ['Porter le vêtement', 'Fond marché africain', 'Studio blanc épuré', 'Ambiance coucher de soleil', 'Avant / Après'],
      brandSave: 'Mémoriser ma marque', brandSaved: 'Profil mémorisé',
      gen: 'Générer', genCost: 'Générer · 1 crédit', needPhoto: 'Ajoutez une photo pour générer', working: 'Création en cours… environ 20 secondes', done: 'Voici votre visuel', download: 'Télécharger', again: 'Refaire · 1 crédit', editTitle: 'Un défaut ? Corrigez ou modifiez', editPh: 'ex. enlève le reflet à gauche, fond plus clair, logo plus net', editBtn: 'Appliquer · 1 crédit', editing: 'Modification en cours… environ 20 secondes', version: 'Version', editHint: 'Décrivez ce qu’il faut changer. Le reste de l’image est conservé. Chaque modification coûte 1 crédit.', ai: 'Généré par IA · Gemini', aiNote: 'le fichier téléchargé est sans mention sur l’image',
      qrTitle: 'Ajouter un QR code à mon affiche (site, boutique, WhatsApp)', qrWhyT: 'À quoi sert le QR code ?', qrW1: 'Vous collez votre lien ou votre numéro WhatsApp.', qrW2: 'Un petit QR code apparaît sur l’affiche, à l’endroit le plus calme.', qrW3: 'Vos clients le scannent avec leur téléphone et arrivent directement chez vous : pour commander, réserver ou vous écrire, sans rien recopier.', qrWhyEnd: 'Facultatif. Vous pouvez le déplacer, le réduire ou le retirer, gratuitement, même après la génération.', qrLabel: 'Votre lien ou numéro WhatsApp', qrPh: 'ex. maboutique.com ou +225 07 00 00 00 00', qrOpens: 'Le QR code ouvrira :', qrBad: 'Lien non reconnu. Écrivez par exemple maboutique.com', qrLong: 'lien long, le code sera plus dense : préférez un lien court', qrCtaL: 'Texte au-dessus du QR code', qrCta_order: 'Scannez pour commander', qrCta_book: 'Scannez pour réserver', qrCta_contact: 'Scannez pour nous écrire', qrCta_shop: 'Scannez pour voir la boutique', qrPos: 'Emplacement', qrAuto: 'Automatique (conseillé)', qrBL: 'Bas gauche', qrBR: 'Bas droite', qrTL: 'Haut gauche', qrTR: 'Haut droite', qrNone: 'Aucun QR code', qrSize: 'Taille', qrS: 'Petit', qrM: 'Moyen', qrL: 'Grand', qrWarn: 'Ce coin n’avait pas été gardé libre à la génération : vérifiez que le QR code ne cache rien.', qrNote: 'Sous le QR code, « Créé avec slashatlas.com » est une simple information, pas un lien : le QR code ouvre uniquement votre lien.',
      share: 'Partager', shareTitle: 'Partager mon visuel', shareText: 'Mon visuel créé avec SlashAtlas', shareCopyLink: 'Copier le lien', shareImg: 'Partager l’image', shareCopyImg: 'Copier l’image', shareDone: 'Copié', shareHint: 'Les réseaux n’acceptent pas l’image par lien : téléchargez-la ou copiez-la, puis ajoutez-la à votre publication. Le lien SlashAtlas est ajouté au message.', shareFail: 'Copie impossible : téléchargez l’image puis partagez-la.',
      waStudio: 'Des surprises pour les créateurs arrivent sur notre canal WhatsApp.', waJoin: 'Rejoindre le canal',
      pitchT: 'Jusqu’à 24 crédits offerts par ami', pitch1: 'Créez votre compte (gratuit).', pitch2: 'Partagez votre lien à vos amis, autant que vous voulez.', pitch3: 'Chaque achat d’un ami vous rapporte jusqu’à 24 crédits : 24 affiches gratuites.', refShort: 'Gagner des crédits', refNone: 'Plus de crédit ? Parrainez un ami : jusqu’à 24 crédits offerts.', refGo: 'Mon lien', noCredit: 'Il vous faut des crédits pour générer.', balance: 'Solde',
      help: 'Un souci de paiement ? Écrivez-nous :', buyTitle: 'Acheter des crédits', buySub: '1 crédit = 1 génération. Les crédits n’expirent pas.', popular: 'Populaire', perCredit: 'par crédit', pay: 'Payer', country: 'Pays', operator: 'Opérateur', phone: 'Numéro mobile money', otp: 'Code OTP', otpHint: 'Orange Burkina : composez #144*4*6*montant# puis saisissez le code reçu.',
      feeLineCard: 'Pack {p} + frais de paiement {f}', usdNote: 'Prix en dollars. Par mobile money, le montant est converti en FCFA.',
      termsTag: 'À cocher pour payer', passUnit: 'jours', passTag: 'Sans pub', passOne: 'Pass sans pub', passWhat: 'sur tout le site', passTitle: 'Pass sans pub · 30 jours', passSub: 'Aucune publicité pendant 30 jours. Sans renouvellement automatique.', noAdsUntil: 'Sans pub jusqu’au {d}', paidPass: 'Paiement reçu : pass sans pub activé', passLogin: 'Connectez-vous pour activer votre pass sans pub (30 jours).', passBuy: 'Activer le pass sans pub',
      soon: 'bientôt', cardSoon: 'Le paiement par carte arrive bientôt. Merci, nous avons noté votre demande : en attendant, payez par mobile money.', card: 'Carte bancaire : bientôt', mm: 'Mobile money', cardTab: 'Carte bancaire', feeLine: 'Pack {p} FCFA + frais de paiement {f} FCFA', feeNote: 'Des frais d’opérateur peuvent s’appliquer.', validate: 'Validez {a} sur votre téléphone (frais d’opérateur inclus).', firstName: 'Prénom', lastName: 'Nom', city: 'Ville', zip: 'Code postal', countryCard: 'Pays', phoneCard: 'Téléphone (avec indicatif)', cardGo: 'Payer par carte', cardInfo: 'Vous serez redirigé vers la page de paiement sécurisée de FeexPay (3D Secure).', pending: 'Paiement en cours de vérification…', approx: '≈ {e} €', paying: 'Validez le paiement sur votre téléphone…', waitPay: 'En attente de la confirmation de l’opérateur', paid: 'Paiement reçu, crédits ajoutés', payFailed: 'Paiement refusé ou annulé. Réessayez.', openPay: 'Ouvrir la page de paiement', close: 'Fermer',
      termsAccept: 'J’ai lu et j’accepte les ', termsLink: 'conditions générales', termsNote: ' Je demande l’exécution immédiate du service et je reconnais perdre mon droit de rétractation pour les crédits utilisés.', cardPackOnly: 'Par carte : packs de 20 et 55 crédits.', 
      e: { terms_required: 'Cochez l’acceptation des conditions générales.', card_pack_limited: 'Ce pack n’est pas disponible par carte. Choisissez un pack plus petit.', card_limit: 'Limite d’achats par carte atteinte. Réessayez plus tard ou payez par mobile money.', no_instruction: 'Décrivez la modification à faire.', no_image: 'Image introuvable : refaites une génération.', insufficient_credits: 'Pas assez de crédits.', daily_limit: 'Limite quotidienne atteinte. Revenez demain.', refused: 'L’image n’a pas pu être créée avec cette photo. Essayez-en une autre. Votre crédit est rendu.', busy: 'Service très sollicité. Réessayez dans un instant. Votre crédit est rendu.', gemini_error: 'La création a échoué. Votre crédit est rendu.', photo_too_big: 'Photo trop lourde.', bad_photo: 'Format de photo non pris en charge.', auth: 'Reconnectez-vous.', payment_refused: 'Le paiement n’a pas pu démarrer. Vérifiez le numéro et l’opérateur.', bad_phone: 'Numéro invalide.', bad_card_info: 'Complétez tous les champs.', card_unavailable: 'Le paiement par carte n’est pas encore disponible.', otp_required: 'Code OTP requis.', rate: 'Trop de demandes, patientez un instant.', server: 'Erreur du service, réessayez.' },
    },
    en: {
      login: 'Continue with Google', loginNote: 'Quick sign-in with your Google account. If you already have an account, you are simply signed back in.',
      tabImage: 'Image', tabVideo: 'Video', tabNew: 'New', vLoginTitle: 'Create a video ad for your product', vLoginText: 'Animations, music and optional voice-over, from your photos. Sign in to get started.',
      hello: 'Hello', back: 'Welcome back', welcome: 'Account created', credits: 'credits', credit: 'credit', buy: 'Buy credits', logout: 'Sign out',
      cmd: 'Command', change: 'Change', photos: 'Your photos', photosHint: 'Up to 3 photos (one or several products). JPG, PNG or WebP.', add: 'Add a photo', remove: 'Remove',
      prodLabel: { product: 'Your product', dish: 'Your dish', person: 'In the photo', place: 'Your property' }, prodPh: 'e.g. face cream, 3 juice bottles', single: 'Single', several: 'Several',
      scene: 'Scene setup', sceneHint: 'Describe the background, mood or how the scene should be composed. Optional.', scenePh: 'e.g. African market backdrop, person wears the outfit, sunset mood', sceneChips: ['Wear the outfit', 'African market backdrop', 'Clean white studio', 'Sunset mood', 'Before / After'],
      brandSave: 'Save my brand', brandSaved: 'Profile saved',
      gen: 'Generate', genCost: 'Generate · 1 credit', needPhoto: 'Add a photo to generate', working: 'Creating… about 20 seconds', done: 'Here is your visual', download: 'Download', again: 'Redo · 1 credit', editTitle: 'Spotted a flaw? Fix or change it', editPh: 'e.g. remove the glare on the left, lighter background, sharper logo', editBtn: 'Apply · 1 credit', editing: 'Editing… about 20 seconds', version: 'Version', editHint: 'Describe what to change. The rest of the image is kept. Each edit costs 1 credit.', ai: 'AI-generated · Gemini', aiNote: 'the downloaded file has no mark on the image',
      qrTitle: 'Add a QR code to my poster (website, shop, WhatsApp)', qrWhyT: 'What is the QR code for?', qrW1: 'You paste your link or your WhatsApp number.', qrW2: 'A small QR code appears on the poster, in the calmest spot.', qrW3: 'Your customers scan it with their phone and land straight on your page: to order, book or message you, without typing anything.', qrWhyEnd: 'Optional. You can move it, shrink it or remove it, for free, even after generation.', qrLabel: 'Your link or WhatsApp number', qrPh: 'e.g. myshop.com or +225 07 00 00 00 00', qrOpens: 'The QR code will open:', qrBad: 'Link not recognized. Write for example myshop.com', qrLong: 'long link, the code will be denser: prefer a short link', qrCtaL: 'Text above the QR code', qrCta_order: 'Scan to order', qrCta_book: 'Scan to book', qrCta_contact: 'Scan to message us', qrCta_shop: 'Scan to see the shop', qrPos: 'Position', qrAuto: 'Automatic (recommended)', qrBL: 'Bottom left', qrBR: 'Bottom right', qrTL: 'Top left', qrTR: 'Top right', qrNone: 'No QR code', qrSize: 'Size', qrS: 'Small', qrM: 'Medium', qrL: 'Large', qrWarn: 'This corner was not kept free during generation: check that the QR code hides nothing.', qrNote: 'Under the QR code, “Made with slashatlas.com” is just information, not a link: the QR code only opens your link.',
      share: 'Share', shareTitle: 'Share my visual', shareText: 'My visual made with SlashAtlas', shareCopyLink: 'Copy link', shareImg: 'Share the image', shareCopyImg: 'Copy image', shareDone: 'Copied', shareHint: 'Social networks cannot take the image from a link: download or copy it, then add it to your post. The SlashAtlas link is added to the message.', shareFail: 'Copy not possible: download the image, then share it.',
      waStudio: 'Surprises for creators are coming on our WhatsApp channel.', waJoin: 'Join the channel',
      pitchT: 'Up to 24 free credits per friend', pitch1: 'Create your account (free).', pitch2: 'Share your link with as many friends as you like.', pitch3: 'Each friend’s purchase earns you up to 24 credits: 24 free posters.', refShort: 'Earn credits', refNone: 'Out of credits? Refer a friend: up to 24 free credits.', refGo: 'My link', noCredit: 'You need credits to generate.', balance: 'Balance',
      help: 'Payment problem? Write to us:', buyTitle: 'Buy credits', buySub: '1 credit = 1 generation. Credits do not expire.', popular: 'Popular', perCredit: 'per credit', pay: 'Pay', country: 'Country', operator: 'Operator', phone: 'Mobile money number', otp: 'OTP code', otpHint: 'Orange Burkina: dial #144*4*6*amount# then enter the code you receive.',
      feeLineCard: 'Pack {p} + payment fees {f}', usdNote: 'Prices in US dollars. With mobile money, the amount is converted to FCFA.',
      termsTag: 'Tick to pay', passUnit: 'days', passTag: 'No ads', passOne: 'No-ads pass', passWhat: 'on the whole site', passTitle: 'No-ads pass · 30 days', passSub: 'No advertising for 30 days. No automatic renewal.', noAdsUntil: 'Ad-free until {d}', paidPass: 'Payment received: no-ads pass activated', passLogin: 'Sign in to activate your no-ads pass (30 days).', passBuy: 'Activate the no-ads pass',
      soon: 'soon', cardSoon: 'Card payment is coming soon. Thanks, we noted your request: for now, please pay by mobile money.', card: 'Card payment: coming soon', mm: 'Mobile money', cardTab: 'Bank card', feeLine: 'Pack {p} FCFA + payment fees {f} FCFA', feeNote: 'Operator fees may apply.', validate: 'Confirm {a} on your phone (operator fees included).', firstName: 'First name', lastName: 'Last name', city: 'City', zip: 'Postal code', countryCard: 'Country', phoneCard: 'Phone (with country code)', cardGo: 'Pay by card', cardInfo: 'You will be redirected to FeexPay’s secure payment page (3D Secure).', pending: 'Checking your payment…', approx: '≈ €{e}', paying: 'Confirm the payment on your phone…', waitPay: 'Waiting for the operator’s confirmation', paid: 'Payment received, credits added', payFailed: 'Payment declined or cancelled. Please try again.', openPay: 'Open the payment page', close: 'Close',
      termsAccept: 'I have read and accept the ', termsLink: 'terms and conditions', termsNote: ' I request immediate performance of the service and acknowledge that I lose my right of withdrawal for credits already used.', cardPackOnly: 'By card: 20 and 55 credit packs.', 
      e: { terms_required: 'Please tick the box to accept the terms.', card_pack_limited: 'This pack is not available by card. Choose a smaller pack.', card_limit: 'Card purchase limit reached. Try again later or pay by mobile money.', no_instruction: 'Describe the change you want.', no_image: 'Image not found: please generate again.', insufficient_credits: 'Not enough credits.', daily_limit: 'Daily limit reached. Come back tomorrow.', refused: 'The image could not be created from this photo. Try another one. Your credit is refunded.', busy: 'The service is busy. Try again in a moment. Your credit is refunded.', gemini_error: 'Creation failed. Your credit is refunded.', photo_too_big: 'Photo too large.', bad_photo: 'Unsupported photo format.', auth: 'Please sign in again.', payment_refused: 'The payment could not start. Check the number and operator.', bad_phone: 'Invalid number.', bad_card_info: 'Please fill in every field.', card_unavailable: 'Card payment is not available yet.', otp_required: 'OTP code required.', rate: 'Too many requests, please wait a moment.', server: 'Service error, please try again.' },
    },
  }[L];
  var data = {}; try { data = JSON.parse(root.dataset.map); } catch (e) {}
  var params = new URLSearchParams(location.search);
  var slug = data.commands[params.get('c')] ? params.get('c') : Object.keys(data.commands)[0];
  var wantPass = params.get('pass') === '1';
  var state = { mode: params.get('mode') === 'video' && root.dataset.vurl ? 'video' : 'image', user: null, credits: 0, photos: [], multi: false, product: '', busy: false, cfg: null, result: null, versions: [], cur: 0, instruction: '', stagingInstruction: '', brand: { brand: '', contact: '', other: '' }, qr: { raw: '', pos: 'auto', size: 's', cta: 'order' }, sale: { on: true, tag: true, tagv: 'sale', price: true, priceV: '', cur: '', old: false, oldV: '', disc: false, discV: '', brand: true, contact: true, qr: true, model: 'auto' }, adFreeUntil: 0, checking: true, brandProfileLoaded: false };

  var $ = function (s, r) { return (r || root).querySelector(s); };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var usd = function (n) { var t = (Math.round(n * 100) / 100).toFixed(2); return L === 'fr' ? t.replace('.', ',') + ' $' : '$' + t; };
  var fmt = function (n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ' '); };
  function setAdFree(ms) {
    state.adFreeUntil = ms > Date.now() ? ms : 0;
    try { if (state.adFreeUntil) localStorage.setItem('sa_nopub', String(state.adFreeUntil)); else localStorage.removeItem('sa_nopub'); } catch (e) {}
  }
  function busy(btn, on) { if (!btn) return; btn.disabled = !!on; btn.classList.toggle('loading', !!on); }
  function flagTerms(modal) { var t = modal.querySelector('.terms'); if (!t) return; t.classList.remove('err'); void t.offsetWidth; t.classList.add('err'); try { t.scrollIntoView({ behavior: 'smooth', block: 'center' }); } catch (e) {} }
  var errText = function (code) { return T.e[code] || T.e.server; };

  function cmdBlock() {
    var c = data.commands[slug];
    return '<div class="scmd"><img src="/img/c/' + (c.img ? slug : 'none') + '-t.webp' + (document.body.dataset.imgv ? '?v=' + document.body.dataset.imgv : '') + '" alt="" ' + (c.img ? '' : 'hidden') + '><div><small>' + T.cmd + '</small><b>' + esc(c.code) + '</b><span>' + esc(c.title) + '</span></div>' +
      '<select id="s-cmd" aria-label="' + T.change + '">' + Object.keys(data.commands).map(function (k) { return '<option value="' + k + '"' + (k === slug ? ' selected' : '') + '>' + esc(data.commands[k].code + ' · ' + data.commands[k].title) + '</option>'; }).join('') + '</select></div>';
  }

  // ── mémoire partagée avec la page de la commande (« sa_sale_v1 ») : ce qui y est renseigné se retrouve ici, et inversement ──
  var SALE_KEY = 'sa_sale_v1';
  function saleLoad() {
    try {
      var d = JSON.parse(localStorage.getItem(SALE_KEY) || '{}'), a = state.sale;
      ['tag', 'price', 'old', 'disc', 'brand', 'contact', 'qr'].forEach(function (k) { if (typeof d[k] === 'boolean') a[k] = d[k]; });
      if (d.tagv) a.tagv = d.tagv; if (d.cur) a.cur = d.cur; if (d.priceV != null) a.priceV = d.priceV; if (d.oldV != null) a.oldV = d.oldV; if (d.discV != null) a.discV = d.discV;
      if (d.brandV) state.brand.brand = d.brandV; if (d.contactV) state.brand.contact = d.contactV; if (d.qrV) state.qr.raw = d.qrV;
    } catch (e) {}
  }
  function saleSave() {
    try {
      var a = state.sale, d = JSON.parse(localStorage.getItem(SALE_KEY) || '{}');
      ['tag', 'price', 'old', 'disc', 'brand', 'contact', 'qr'].forEach(function (k) { d[k] = a[k]; });
      d.tagv = a.tagv; d.cur = a.cur; d.priceV = a.priceV; d.oldV = a.oldV; d.discV = a.discV; d.brandV = state.brand.brand; d.contactV = state.brand.contact; d.qrV = state.qr.raw;
      localStorage.setItem(SALE_KEY, JSON.stringify(d));
    } catch (e) {}
  }
  // ── Affiche de vente : À VENDRE, prix et devise, réduction, marque, contact, petit QR code (cases à cocher) ──
  function saleBox() {
    if (!saleEligible()) return '';
    var S = data.sale, a = state.sale, cur = a.cur || S.defCur;
    var chk = function (k, label, inner) { return '<label class="chk"><input type="checkbox" data-sc="' + k + '"' + (a[k] ? ' checked' : '') + '><span>' + label + '</span>' + inner + '</label>'; };
    var txt = function (k, ph, max) { return '<input type="text" data-sv="' + k + '" maxlength="' + max + '" placeholder="' + esc(ph) + '" value="' + esc(k === 'brand' || k === 'contact' ? state.brand[k] : k === 'qr' ? state.qr.raw : a[k + 'V']) + '" autocomplete="off"' + (a[k === 'qr' ? 'qr' : k] ? '' : ' disabled') + '>'; };
    var curSel = '<select data-sv="cur"' + (a.price ? '' : ' disabled') + '>' + S.currencies.map(function (x) { return '<option' + (x === cur ? ' selected' : '') + '>' + esc(x) + '</option>'; }).join('') + (S.currencies.indexOf(cur) < 0 ? '<option selected>' + esc(cur) + '</option>' : '') + '<option value="__other">' + esc(S.curOther) + '</option></select>';
    var tagSel = '<select data-sv="tagv"' + (a.tag ? '' : ' disabled') + '>' + Object.keys(S.tags).map(function (k) { return '<option value="' + k + '"' + (a.tagv === k ? ' selected' : '') + '>' + esc(S.tags[k]) + '</option>'; }).join('') + '</select>';
    return '<details class="brandbox sf salebox"' + (a.on ? ' open' : '') + '><summary>' + S.title + '</summary>' +
      '<label class="sale-hd"><input type="checkbox" data-sc="on"' + (a.on ? ' checked' : '') + '>' + S.master + '</label><p class="hint">' + S.hint + '</p>' +
      '<div class="sgrid"' + (a.on ? '' : ' hidden') + '>' +
      chk('tag', S.tag, tagSel) + chk('price', S.price, txt('price', S.pricePh, 20) + curSel) + chk('old', S.old, txt('old', S.oldPh, 20)) + chk('disc', S.disc, txt('disc', S.discPh, 12)) +
      chk('brand', S.brand, txt('brand', S.brandPh, 40)) + chk('contact', S.contact, txt('contact', S.contactPh, 40)) + chk('qr', S.qr, txt('qr', S.qrPh, 200)) + '</div>' +
      '<div class="sgrid"' + (a.on ? '' : ' hidden') + '><b class="hint">' + S.model + '</b><div class="smodels" role="group">' + Object.keys(S.models).map(function (k) { return '<button type="button" data-sm="' + k + '" aria-pressed="' + (a.model === k) + '">' + esc(S.models[k]) + '</button>'; }).join('') + '</div>' +
      '<p class="hint" id="s-qrmsg2"></p><p class="hint">' + S.note + '</p></div></details>';
  }
  function saleOpts() {
    var a = state.sale, S = data.sale;
    return { model: a.model === 'auto' ? undefined : a.model, lang: L, tag: a.tag ? a.tagv : '', price: a.price ? a.priceV : '', cur: a.cur || S.defCur, old: a.old ? a.oldV : '', disc: a.disc ? a.discV : '', brand: a.brand ? state.brand.brand : '', contact: a.contact ? state.brand.contact : '', qr: a.qr ? normUrl(state.qr.raw) : '', qrSize: state.qr.size === 's' ? 's' : 'm' };
  }
  function saleKey() { return saleOn() ? 'S|' + JSON.stringify(saleOpts()) : ''; }
  var saleLib = null;
  function loadSaleLib() {
    if (window.saSale) return Promise.resolve();
    return saleLib || (saleLib = new Promise(function (res, rej) { var sc = document.createElement('script'); sc.src = '/js/sale.js?v=' + (root.dataset.sv || ''); sc.onload = res; sc.onerror = function () { saleLib = null; rej(new Error('salelib')); }; document.head.appendChild(sc); }));
  }
  function composeSale(raw) {
    var fontsReady = document.fonts && document.fonts.load ? Promise.all([document.fonts.load('800 40px Manrope'), document.fonts.load('700 30px Manrope')]).catch(function () {}) : Promise.resolve();
    return Promise.all([loadImg(URL.createObjectURL(raw)), loadQrLib(), loadSaleLib(), fontsReady]).then(function (a) {
      var img = a[0], deps = { create: function (w, h) { var c = document.createElement('canvas'); c.width = w; c.height = h; return c; }, qrcode: window.qrcode };
      var cv = window.saSale.compose(deps, img, saleOpts()); URL.revokeObjectURL(img.src);
      var type = raw.type === 'image/jpeg' ? 'image/jpeg' : 'image/png';
      return new Promise(function (res, rej) { cv.toBlob(function (b) { b ? res(b) : rej(new Error('sale')); }, type, 0.93); });
    });
  }
  // Marque et contacts à inscrire sur le visuel (3 champs au plus) ; le serveur compose la mise en page.
  function saleEligible() { return !!(data.sale && data.commands[slug] && data.commands[slug].sale); }
  function saleOn() { return saleEligible() && state.sale.on; }
  function brandBox() {
    var B = data.brand; if (!B) return '';
    var fields = B.fields.filter(function (f) { return !(saleOn() && f[0] !== 'other'); });
    var filled = fields.some(function (f) { return state.brand[f[0]]; });
    return '<details class="brandbox sf"' + (filled ? ' open' : '') + '><summary>' + B.title + '</summary><p class="hint">' + B.hint + '</p><div class="bgrid">' + fields.map(function (f) {
      return '<label>' + f[1] + '<input type="text" data-brole="' + f[0] + '" maxlength="' + f[3] + '" placeholder="' + esc(f[2]) + '" value="' + esc(state.brand[f[0]]) + '" autocomplete="off"></label>';
    }).join('') + '</div><button class="btn gl sm" type="button" id="s-brand-save">' + (state.brandProfileLoaded ? '✓ ' + T.brandSaved : T.brandSave) + '</button></details>';
  }
  function brandTexts() {
    // avec l'affiche de vente, marque et contact sont dessinés par le site (textes exacts) : l'IA n'en reçoit pas
    var o = {}; Object.keys(state.brand).forEach(function (k) { if (saleOn() && k !== 'other') return; var v = window.saBrandClean(state.brand[k], k === 'other' ? 80 : 60); if (v) o[k] = v; }); return o;
  }
  // ── Partage du visuel : feuille de partage du téléphone avec l'image ; sinon liens vers les réseaux + copie de l'image ──
  var SITE = location.origin + (L === 'en' ? '/en/' : '/');
  function shareLink() { return SITE + '?utm_source=share&utm_medium=studio'; }
  function sharePanel() {
    var u = encodeURIComponent(shareLink()), t = encodeURIComponent(T.shareText);
    var nets = [['WhatsApp', 'https://wa.me/?text=' + t + '%20' + u], ['Facebook', 'https://www.facebook.com/sharer/sharer.php?u=' + u], ['X', 'https://twitter.com/intent/tweet?text=' + t + '&url=' + u], ['LinkedIn', 'https://www.linkedin.com/sharing/share-offsite/?url=' + u], ['Telegram', 'https://t.me/share/url?url=' + u + '&text=' + t]];
    var canNative = !!(navigator.share && navigator.canShare);
    return '<div class="sshare" id="s-sharebox" hidden><b>' + T.shareTitle + '</b>' +
      (canNative ? '<button class="btn pri big" type="button" id="s-native">' + T.shareImg + '</button>' : '') +
      '<p class="hint">' + T.shareHint + '</p><div class="snets">' +
      nets.map(function (n) { return '<a class="btn gl sm" href="' + n[1] + '" target="_blank" rel="noopener" data-net="' + n[0] + '">' + n[0] + '</a>'; }).join('') +
      '</div><div class="snets"><button class="btn gl sm" type="button" id="s-copyimg">' + T.shareCopyImg + '</button><button class="btn gl sm" type="button" id="s-copylink">' + T.shareCopyLink + '</button></div></div>';
  }
  // ── QR code de l'utilisateur (son site, sa boutique, son WhatsApp) ajouté sur l'affiche après la génération ──
  // Le QR ouvre uniquement le lien de l'utilisateur ; « Créé avec slashatlas.com » en dessous est une simple mention, pas un lien.
  function normUrl(v) {
    v = String(v || '').trim().replace(/\s+/g, ' ');
    if (!v || v.length > 200) return '';
    if (/^\+?[\d ().-]{8,}$/.test(v)) return 'https://wa.me/' + v.replace(/\D/g, '');
    v = v.replace(/ /g, '');
    if (/^https?:\/\/[^\/\s]+\.[^\/\s]+/i.test(v)) return v;
    if (/^[a-z0-9][a-z0-9-]*(\.[a-z0-9-]+)+(\/\S*)?$/i.test(v)) return 'https://' + v;
    return '';
  }
  var qrLib = null;
  function loadQrLib() {
    if (window.qrcode) return Promise.resolve();
    return qrLib || (qrLib = new Promise(function (res, rej) { var sc = document.createElement('script'); sc.src = '/js/qrcode-1.4.4.js'; sc.onload = res; sc.onerror = function () { qrLib = null; rej(new Error('qrlib')); }; document.head.appendChild(sc); }));
  }
  function loadImg(src) { return new Promise(function (res, rej) { var i = new Image(); i.onload = function () { res(i); }; i.onerror = rej; i.src = src; }); }
  function qrKey() { var u = normUrl(state.qr.raw); return u && state.qr.pos !== 'none' ? [u, state.qr.pos, state.qr.size, state.qr.cta, L].join('|') : ''; }
  function composeQr(raw, url, pos, size, cta) {
    return Promise.all([loadImg(URL.createObjectURL(raw)), loadQrLib()]).then(function (a) {
      var img = a[0], w = img.naturalWidth, h = img.naturalHeight, mn = Math.min(w, h);
      var q = window.qrcode(0, 'M'); q.addData(url); q.make(); var n = q.getModuleCount();
      // petit par défaut ; jamais moins de 3 px par module (sinon le code ne se lit plus), jamais plus de 30 % de l'image
      var base = mn * ({ s: 0.085, m: 0.115, l: 0.16 }[size] || 0.085), side = Math.min(Math.max(base, 3 * (n + 6)), mn * 0.22);
      var cell = Math.max(2, Math.floor(side / (n + 6))), tw = cell * (n + 6), top = Math.round(tw * 0.17), bot = Math.round(tw * 0.27), th = top + tw + bot, m = Math.round(mn * 0.03);
      var c = document.createElement('canvas'); c.width = w; c.height = h; var g = c.getContext('2d'); g.drawImage(img, 0, 0);
      var spots = { bl: [m, h - th - m], br: [w - tw - m, h - th - m], tl: [m, m], tr: [w - tw - m, m] };
      if (!spots[pos]) { // « Auto » : le coin le plus calme de l'affiche (écart-type de luminance le plus faible) ; le bas est préféré, comme demandé à l'IA
        var best = null, bias = { br: 1, bl: 1.1, tr: 1.3, tl: 1.3 };
        Object.keys(spots).forEach(function (k) {
          var d = g.getImageData(spots[k][0], spots[k][1], tw, th).data, cnt = 0, sum = 0, sq = 0;
          for (var i = 0; i < d.length; i += 16) { var l = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]; sum += l; sq += l * l; cnt++; }
          var sd = Math.sqrt(Math.max(0, sq / cnt - (sum / cnt) * (sum / cnt))) * bias[k];
          if (!best || sd < best.sd) best = { sd: sd, k: k };
        });
        pos = best.k;
      }
      var x = spots[pos][0], y = spots[pos][1];
      g.save(); g.shadowColor = 'rgba(0,0,0,.35)'; g.shadowBlur = tw * 0.06; g.fillStyle = '#fff'; g.beginPath();
      if (g.roundRect) g.roundRect(x, y, tw, th, tw * 0.07); else g.rect(x, y, tw, th); g.fill(); g.restore();
      g.fillStyle = '#000'; for (var r = 0; r < n; r++) for (var k2 = 0; k2 < n; k2++) if (q.isDark(r, k2)) g.fillRect(x + (k2 + 3) * cell, y + top + (r + 3) * cell, cell, cell);
      g.textAlign = 'center'; g.textBaseline = 'alphabetic';
      var f = 'Manrope, system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif', line = T['qrCta_' + cta] || T.qrCta_order;
      var fs = Math.round(tw * 0.082); g.font = '800 ' + fs + 'px ' + f; while (g.measureText(line).width > tw * 0.94 && fs > 6) { fs--; g.font = '800 ' + fs + 'px ' + f; }
      g.fillStyle = '#111'; g.fillText(line, x + tw / 2, y + top * 0.72);
      g.fillStyle = '#444'; g.font = '500 ' + Math.round(tw * 0.07) + 'px ' + f; g.fillText(L === 'en' ? 'Made with' : 'Créé avec', x + tw / 2, y + top + tw + bot * 0.36);
      g.fillStyle = '#111'; g.font = '800 ' + Math.round(tw * 0.105) + 'px ' + f; g.fillText('slashatlas.com', x + tw / 2, y + top + tw + bot * 0.80);
      URL.revokeObjectURL(img.src);
      var type = raw.type === 'image/jpeg' ? 'image/jpeg' : 'image/png';
      return new Promise(function (res, rej) { c.toBlob(function (b) { b ? res(b) : rej(new Error('qr')); }, type, 0.93); });
    });
  }
  /** Met la version à jour avec le QR actuel (ou sans QR) ; gratuit, calculé dans le navigateur à partir de l'image d'origine. */
  function ensureQr(v) {
    var key = saleOn() ? saleKey() : qrKey();
    if (v.qrKey === key) return Promise.resolve(v);
    var done = function (blob) { if (v.url) URL.revokeObjectURL(v.url); v.blob = blob; v.url = URL.createObjectURL(blob); v.qrKey = key; return v; };
    if (!key) return Promise.resolve(done(v.raw));
    var p = saleOn() ? composeSale(v.raw) : composeQr(v.raw, normUrl(state.qr.raw), state.qr.pos, state.qr.size, state.qr.cta);
    return p.then(done, function () { v.qrKey = key; return v; });
  }
  function newVersion(id, mime, b64) {
    var bin = atob(b64), arr = new Uint8Array(bin.length); for (var i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
    var raw = new Blob([arr], { type: mime });
    return ensureQr({ id: id, raw: raw, blob: raw, url: '', qrKey: null, ext: mime.indexOf('jpeg') >= 0 ? 'jpg' : 'png' });
  }
  function applyQr() {
    var v = state.result; if (!v) return;
    ensureQr(v).then(function () {
      var im = $('.sres > img'), dl = $('.sres a[download]'); if (im) im.src = v.url; if (dl) dl.href = v.url;
      qrWarn();
      try { if (qrKey()) window.saTrack && window.saTrack('qr', { n: state.qr.pos }); } catch (e) {}
    });
  }
  // Si l'utilisateur déplace le QR dans un coin que l'IA n'avait pas gardé libre, on le lui signale.
  function qrWarn() {
    var el = $('#s-qrwarn'); if (!el) return;
    var v = state.result, p = state.qr.pos, g = v && v.genPos;
    el.textContent = v && g && p !== 'none' && p !== 'auto' && p !== g && g !== 'auto' ? T.qrWarn : '';
  }
  function qrStatus() {
    var el = $('#s-qrmsg'); if (!el) return;
    var raw = (state.qr.raw || '').trim(), u = normUrl(raw);
    el.className = 'hint' + (raw && !u ? ' bad' : '');
    el.textContent = !raw ? '' : (u ? T.qrOpens + ' ' + u + (u.length > 70 ? ' · ' + T.qrLong : '') : T.qrBad);
  }
  function qrBox() {
    var seg = function (attr, cur, items) { return '<div class="qrseg" role="group">' + items.map(function (p) { return '<button type="button" data-' + attr + '="' + p[0] + '" aria-pressed="' + (cur === p[0]) + '">' + p[1] + '</button>'; }).join('') + '</div>'; };
    return '<details class="brandbox sf qrbox"' + (state.qr.raw ? ' open' : '') + '><summary>' + T.qrTitle + '</summary>' +
      '<div class="qrwhy"><b>' + T.qrWhyT + '</b><ol><li>' + T.qrW1 + '</li><li>' + T.qrW2 + '</li><li>' + T.qrW3 + '</li></ol><p>' + T.qrWhyEnd + '</p></div>' +
      '<label>' + T.qrLabel + '<input id="s-qrurl" type="text" inputmode="url" maxlength="200" placeholder="' + esc(T.qrPh) + '" value="' + esc(state.qr.raw) + '" autocomplete="off" autocapitalize="off"></label><p class="hint" id="s-qrmsg"></p>' +
      '<div class="qrpos"><small>' + T.qrCtaL + '</small><select id="s-qrcta">' + ['order', 'book', 'contact', 'shop'].map(function (k) { return '<option value="' + k + '"' + (state.qr.cta === k ? ' selected' : '') + '>' + T['qrCta_' + k] + '</option>'; }).join('') + '</select></div>' +
      '<div class="qrpos"><small>' + T.qrPos + '</small>' + seg('qp', state.qr.pos, [['auto', T.qrAuto], ['br', T.qrBR], ['bl', T.qrBL], ['tr', T.qrTR], ['tl', T.qrTL], ['none', T.qrNone]]) + '<p class="hint" id="s-qrwarn"></p></div>' +
      '<div class="qrpos"><small>' + T.qrSize + '</small>' + seg('qs', state.qr.size, [['s', T.qrS], ['m', T.qrM], ['l', T.qrL]]) + '</div>' +
      '<p class="hint">' + T.qrNote + '</p></details>';
  }
  function flash(btn, txt) { var o = btn.textContent; btn.textContent = txt; setTimeout(function () { btn.textContent = o; }, 1800); }
  function toPng(blob) {
    return new Promise(function (resolve, reject) {
      if (blob.type === 'image/png') return resolve(blob);
      var url = URL.createObjectURL(blob), img = new Image();
      img.onload = function () { var c = document.createElement('canvas'); c.width = img.naturalWidth; c.height = img.naturalHeight; c.getContext('2d').drawImage(img, 0, 0); URL.revokeObjectURL(url); c.toBlob(function (b) { b ? resolve(b) : reject(new Error('png')); }, 'image/png'); };
      img.onerror = function () { URL.revokeObjectURL(url); reject(new Error('png')); }; img.src = url;
    });
  }
  var nativeData = null;
  function doShare() {
    var b = $('#s-sharebox'); if (!b || !state.result) return;
    b.hidden = !b.hidden;
    if (b.hidden) return;
    try { window.saTrack && window.saTrack('share', { n: 'open' }); } catch (e) {}
    b.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }
  function nativeShare(btn) {
    Promise.resolve(state.result.blob).then(function (blob) {
      var file; try { file = new File([blob], 'slashatlas-' + slug + '.' + (blob.type === 'image/jpeg' ? 'jpg' : 'png'), { type: blob.type }); } catch (e) { return; }
      var data = { files: [file], title: 'SlashAtlas', text: T.shareText + ' ' + shareLink() };
      if (!navigator.canShare(data)) { flash(btn, T.shareFail); return; }
      navigator.share(data).then(function () { try { window.saTrack && window.saTrack('share', { n: 'native' }); } catch (e) {} }, function (e) { if (e && e.name !== 'AbortError') flash(btn, T.shareFail); });
    });
  }
  function bar() {
    return '<div class="sbar" id="account"><div><small>' + T.hello + ', ' + esc((state.user.displayName || '').split(' ')[0] || state.user.email) + '</small><b id="s-bal">' + state.credits + ' ' + (state.credits === 1 ? T.credit : T.credits) + '</b>' + (state.adFreeUntil ? '<small class="okline">' + T.noAdsUntil.replace('{d}', new Date(state.adFreeUntil).toLocaleDateString(L === 'en' ? 'en-GB' : 'fr-FR', { day: 'numeric', month: 'long' })) + '</small>' : '') + '</div><div class="acts"><button class="btn pri sm" type="button" id="s-buy">' + T.buy + '</button><a class="btn gl sm" href="' + refUrl() + '">🎁 ' + T.refShort + '</a>' + (state.user.email === 'jorbienvenu@gmail.com' ? '<a class="btn gl sm" href="/admin/">Hub</a>' : '') + '<button class="btn gl sm" type="button" data-logout>' + T.logout + '</button></div></div>';
  }
  function studioNav() {
    var isVideo = state.mode === 'video';
    var hasVurl = !!root.dataset.vurl;
    var genPath = L === 'en' ? '/en/generate/' : '/generer/';
    var filmPath = L === 'en' ? '/en/film-studio/' : '/studio-film/';
    var imgItem = hasVurl
      ? '<button class="stool' + (!isVideo ? ' on' : '') + '" type="button" data-mode="image"><span class="stool-ic">🖼</span><b>Image</b><small>' + (L === 'en' ? 'Posters' : 'Affiches') + '</small></button>'
      : '<a class="stool on" href="' + genPath + '"><span class="stool-ic">🖼</span><b>Image</b><small>' + (L === 'en' ? 'Posters' : 'Affiches') + '</small></a>';
    var vidItem = hasVurl
      ? '<button class="stool' + (isVideo ? ' on' : '') + '" type="button" data-mode="video"><span class="stool-ic">🎬</span><b>' + (L === 'en' ? 'Video' : 'Vidéo') + '</b><small>Motion design</small></button>'
      : '<a class="stool" href="' + genPath + '?mode=video"><span class="stool-ic">🎬</span><b>' + (L === 'en' ? 'Video' : 'Vidéo') + '</b><small>Motion design</small></a>';
    var filmItem = '<a class="stool" href="' + filmPath + '"><span class="stool-ic">🎭</span><b>Film</b><small>' + (L === 'en' ? 'Scenario' : 'Scénario') + '</small></a>';
    var histCount = hist.items.length ? hist.items.length + (L === 'en' ? ' items' : '') : (L === 'en' ? 'My images' : 'Mes images');
    if (hist.items.length && L !== 'en') histCount = hist.items.length + ' créations';
    var histItem = '<button class="stool" type="button" id="s-hist-btn"><span class="stool-ic">🕐</span><b>' + (L === 'en' ? 'History' : 'Historique') + '</b><small>' + histCount + '</small></button>';
    return '<nav class="stools">' + imgItem + vidItem + filmItem + histItem + '</nav>';
  }
  function tabs() {
    if (!root.dataset.vurl) return '';
    return '<div class="stabs" role="tablist"><button type="button" role="tab" data-mode="image" aria-selected="' + (state.mode !== 'video') + '">' + T.tabImage + '</button><button type="button" role="tab" data-mode="video" aria-selected="' + (state.mode === 'video') + '">' + T.tabVideo + ' <i>' + T.tabNew + '</i></button></div>';
  }
  function render() {
    if (state.checking) { root.innerHTML = '<div class="sbox sload"><span class="spin" aria-label="…"></span></div>'; return; }
    if (!state.user) {
      root.innerHTML = tabs() + '<div class="sbox">' + (wantPass ? '<p class="lead">' + T.passLogin + '</p>' : state.mode === 'video' ? '<h2 class="vh">' + T.vLoginTitle + '</h2><p class="hint">' + T.vLoginText + '</p>' : cmdBlock()) + '<div class="refpitch"><b>🎁 ' + T.pitchT + '</b><ol><li>' + T.pitch1 + '</li><li>' + T.pitch2 + '</li><li>' + T.pitch3 + '</li></ol></div><button class="btn pri big" type="button" data-login>' + T.login + '</button><p class="hint">' + T.loginNote + '</p><p class="fmsg" id="auth-msg" role="status" aria-live="polite"></p></div>';
      bind(); return;
    }
    var kind = data.commands[slug].kind, lab = T.prodLabel[kind] || T.prodLabel.product;
    var thumbs = state.photos.map(function (p, i) { return '<figure class="ph"><img src="' + p.url + '" alt=""><button type="button" data-rm="' + i + '" aria-label="' + T.remove + '">×</button></figure>'; }).join('');
    var addBtn = state.photos.length < 3 ? '<label class="addph"><input id="s-file" type="file" accept="image/jpeg,image/png,image/webp,image/*" multiple hidden><span>+</span><small>' + T.add + '</small></label>' : '';
    var canGen = state.photos.length && !state.busy;
    var genLabel = state.credits < 1 ? T.buy : T.genCost;
    if (state.mode === 'video') { root.innerHTML = bar() + studioNav() + tabs() + '<div id="v-root"></div>'; bind(); mountVideo(); return; }
    root.innerHTML = bar() + studioNav() + (state.credits < 1 ? '<a class="refstrip" href="' + refUrl() + '"><span aria-hidden="true">🎁</span><b>' + T.refNone + '</b><i>' + T.refGo + ' ›</i></a>' : '') + tabs() +
      '<div class="sbox">' + cmdBlock() +
      '<div class="sf"><b>' + T.photos + '</b><div class="phs">' + thumbs + addBtn + '</div><small class="hint">' + T.photosHint + '</small></div>' +
      '<div class="adapt sf"><label>' + lab + '<input id="s-prod" type="text" maxlength="60" placeholder="' + esc(T.prodPh) + '" value="' + esc(state.product) + '" autocomplete="off"></label><div class="seg2" role="group"><button type="button" data-n="1" aria-pressed="' + (!state.multi) + '">' + T.single + '</button><button type="button" data-n="n" aria-pressed="' + state.multi + '">' + T.several + '</button></div></div>' +
      '<details class="brandbox sf scenebox"' + (state.stagingInstruction ? ' open' : '') + '><summary>' + T.scene + '</summary><div class="scene-chips">' + T.sceneChips.map(function (s) { return '<button type="button" class="chip" data-ss="' + esc(s) + '">' + esc(s) + '</button>'; }).join('') + '</div><textarea id="s-scene" rows="2" maxlength="200" placeholder="' + esc(T.scenePh) + '" autocomplete="off">' + esc(state.stagingInstruction) + '</textarea><small class="hint">' + T.sceneHint + '</small></details>' +
      saleBox() + brandBox() + (saleOn() ? '' : qrBox()) +
      '<button class="btn pri big' + (state.busy ? ' loading' : '') + '" type="button" id="s-gen"' + (state.credits >= 1 && !canGen ? ' disabled' : '') + '>' + (state.busy ? T.working : (state.credits >= 1 && !state.photos.length ? T.needPhoto : genLabel)) + '</button>' +
      '<p class="fmsg" id="s-msg" role="status" aria-live="polite"></p></div>' +
      (state.result ? '<div class="sres"><img src="' + state.result.url + '" alt="">' +
        (state.versions.length > 1 ? '<div class="vers">' + state.versions.map(function (v, i) { return '<button type="button" data-v="' + i + '" aria-pressed="' + (i === state.cur) + '">' + T.version + ' ' + (i + 1) + '</button>'; }).join('') + '</div>' : '') +
        '<div class="acts big"><a class="btn pri big" href="' + state.result.url + '" download="slashatlas-' + slug + '-v' + (state.cur + 1) + '.' + state.result.ext + '">' + T.download + '</a><button class="btn gl big" type="button" id="s-share">' + T.share + '</button><button class="btn gl big" type="button" id="s-again">' + T.again + '</button></div>' + sharePanel() +
        '<div class="sedit"><b>' + T.editTitle + '</b><textarea id="s-edit" rows="2" maxlength="300" placeholder="' + esc(T.editPh) + '">' + esc(state.instruction) + '</textarea><small class="hint">' + T.editHint + '</small><button class="btn pri big' + (state.busy ? ' loading' : '') + '" type="button" id="s-editgo"' + (state.busy ? ' disabled' : '') + '>' + (state.busy ? T.editing : T.editBtn) + '</button></div>' +
        (root.dataset.wa ? '<p class="wastudio"><span>' + T.waStudio + '</span> <a href="' + esc(root.dataset.wa) + '" target="_blank" rel="noopener" data-wa="studio">' + T.waJoin + '</a></p>' : '') + '<small class="aic">' + T.ai + ' · ' + T.aiNote + '</small></div>' : '') +
      histSection();
    bind();
    if (state.user && location.hash === '#account') {
      var acc = document.getElementById('account');
      if (acc) { acc.scrollIntoView({ behavior: 'smooth', block: 'start' }); try { history.replaceState(null, '', location.pathname + location.search); } catch (e) {} }
    }
    var hw = root.querySelector('.shist-wrap');
    if (hw) {
      hw.addEventListener('toggle', function () {
        hist.open = hw.open;
        if (hw.open && !hist.items.length && !hist.busy) loadHistory(); else renderHist();
      });
    }
  }
  function msg(t, ok) { var m = $('#s-msg') || $('#auth-msg'); if (m) { m.textContent = t || ''; m.className = 'fmsg' + (ok ? ' ok' : ''); } }

  function bind() {
    Array.prototype.forEach.call(root.querySelectorAll('[data-mode]'), function (b) { b.addEventListener('click', function () { if (state.mode === b.dataset.mode) return; state.mode = b.dataset.mode; try { history.replaceState(null, '', state.mode === 'video' ? '?mode=video' : location.pathname); } catch (e) {} render(); }); });
    var sel = $('#s-cmd'); if (sel) sel.addEventListener('change', function () { slug = sel.value; history.replaceState(null, '', '?c=' + slug); state.result = null; render(); });
    var f = $('#s-file'); if (f) f.addEventListener('change', function () { addFiles(f.files); });
    Array.prototype.forEach.call(root.querySelectorAll('[data-rm]'), function (b) { b.addEventListener('click', function () { var p = state.photos.splice(+b.dataset.rm, 1)[0]; if (p) URL.revokeObjectURL(p.url); render(); }); });
    Array.prototype.forEach.call(root.querySelectorAll('[data-brole]'), function (i) { i.addEventListener('input', function () { state.brand[i.dataset.brole] = i.value; }); });
    var pr = $('#s-prod'); if (pr) pr.addEventListener('input', function () { state.product = pr.value; });
    Array.prototype.forEach.call(root.querySelectorAll('.seg2 button'), function (b) { b.addEventListener('click', function () { state.multi = b.dataset.n === 'n'; Array.prototype.forEach.call(root.querySelectorAll('.seg2 button'), function (x) { x.setAttribute('aria-pressed', x === b ? 'true' : 'false'); }); }); });
    var sc = $('#s-scene'); if (sc) sc.addEventListener('input', function () { state.stagingInstruction = sc.value; });
    Array.prototype.forEach.call(root.querySelectorAll('[data-ss]'), function (b) { b.addEventListener('click', function () { var s = $('#s-scene'); state.stagingInstruction = b.dataset.ss; if (s) { s.value = b.dataset.ss; s.closest('details').open = true; s.focus(); } }); });
    var bsv = $('#s-brand-save'); if (bsv) bsv.addEventListener('click', function () { saveBrandProfileToServer(); flash(bsv, T.brandSaved); });
    var g = $('#s-gen'); if (g) g.addEventListener('click', function () { if (state.credits < 1) openBuy('generer'); else generate(); });
    // affiche de vente : cases, textes, devise, modèle ; recomposition immédiate du résultat (gratuit, dans le navigateur)
    var st2 = null, applySaleSoon = function () { saleSave(); clearTimeout(st2); st2 = setTimeout(applyQr, 450); };
    Array.prototype.forEach.call(root.querySelectorAll('[data-sc]'), function (c) { c.addEventListener('change', function () { var k = c.dataset.sc; state.sale[k] = c.checked; saleSave(); if (k === 'on') { render(); applyQr(); return; } var row = c.closest('.chk'); if (row) Array.prototype.forEach.call(row.querySelectorAll('input[type=text],select'), function (x) { x.disabled = !c.checked; }); applySaleSoon(); }); });
    Array.prototype.forEach.call(root.querySelectorAll('[data-sv]'), function (i) {
      var k = i.dataset.sv, ev = i.tagName === 'SELECT' ? 'change' : 'input';
      i.addEventListener(ev, function () {
        if (k === 'brand' || k === 'contact') state.brand[k] = i.value; else if (k === 'qr') { state.qr.raw = i.value; var m = $('#s-qrmsg2'); if (m) { var u = normUrl(i.value); m.textContent = i.value.trim() ? (u ? T.qrOpens + ' ' + u : T.qrBad) : ''; } }
        else if (k === 'cur') { if (i.value === '__other') { var v = window.prompt(data.sale.curOther, state.sale.cur || data.sale.defCur); if (v && v.trim()) state.sale.cur = v.trim().slice(0, 8); render(); return; } state.sale.cur = i.value; }
        else if (k === 'tagv') state.sale.tagv = i.value; else state.sale[k + 'V'] = i.value;
        applySaleSoon();
      });
    });
    Array.prototype.forEach.call(root.querySelectorAll('[data-sm]'), function (b) { b.addEventListener('click', function () { state.sale.model = b.dataset.sm; Array.prototype.forEach.call(root.querySelectorAll('[data-sm]'), function (x) { x.setAttribute('aria-pressed', x === b ? 'true' : 'false'); }); applyQr(); }); });
    var qu = $('#s-qrurl'); if (qu) { var qt = null; qrStatus(); qu.addEventListener('input', function () { state.qr.raw = qu.value; qrStatus(); clearTimeout(qt); qt = setTimeout(applyQr, 700); }); }
    var segBind = function (attr, key) { Array.prototype.forEach.call(root.querySelectorAll('[data-' + attr + ']'), function (b) { b.addEventListener('click', function () { state.qr[key] = b.dataset[attr]; Array.prototype.forEach.call(root.querySelectorAll('[data-' + attr + ']'), function (x) { x.setAttribute('aria-pressed', x === b ? 'true' : 'false'); }); qrWarn(); applyQr(); }); }); };
    segBind('qp', 'pos'); segBind('qs', 'size');
    var qcta = $('#s-qrcta'); if (qcta) qcta.addEventListener('change', function () { state.qr.cta = qcta.value; applyQr(); });
    qrWarn();
    var sh = $('#s-share'); if (sh) sh.addEventListener('click', doShare);
    var nb = $('#s-native'); if (nb) nb.addEventListener('click', function () { nativeShare(nb); });
    var ci = $('#s-copyimg'); if (ci) ci.addEventListener('click', function () {
      if (!(navigator.clipboard && window.ClipboardItem) || !state.result) { flash(ci, T.shareFail); return; }
      toPng(state.result.blob).then(function (b) { return navigator.clipboard.write([new ClipboardItem({ 'image/png': b })]); }).then(function () { flash(ci, T.shareDone); try { window.saTrack && window.saTrack('share', { n: 'copyimg' }); } catch (e) {} }, function () { flash(ci, T.shareFail); });
    });
    var cl = $('#s-copylink'); if (cl) cl.addEventListener('click', function () {
      var done = function () { flash(cl, T.shareDone); try { window.saTrack && window.saTrack('share', { n: 'copylink' }); } catch (e) {} };
      try { navigator.clipboard.writeText(shareLink()).then(done, function () { flash(cl, T.shareFail); }); } catch (e) { flash(cl, T.shareFail); }
    });
    Array.prototype.forEach.call(root.querySelectorAll('[data-net]'), function (a) { a.addEventListener('click', function () { try { window.saTrack && window.saTrack('share', { n: a.dataset.net }); } catch (e) {} }); });
    var ag = $('#s-again'); if (ag) ag.addEventListener('click', function () { if (state.credits < 1) openBuy('refaire'); else generate(); });
    var by = $('#s-buy'); if (by) by.addEventListener('click', openBuy);
    var ed = $('#s-edit'); if (ed) ed.addEventListener('input', function () { state.instruction = ed.value; });
    var eg = $('#s-editgo'); if (eg) eg.addEventListener('click', function () { if (state.credits < 1) openBuy('corriger'); else editImage(); });
    Array.prototype.forEach.call(root.querySelectorAll('[data-v]'), function (b) { b.addEventListener('click', function () { state.cur = +b.dataset.v; state.result = state.versions[state.cur]; ensureQr(state.result).then(render); }); });
    var hb = $('#s-hist-btn');
    if (hb) hb.addEventListener('click', function () {
      var hw = root.querySelector('.shist-wrap');
      if (!hw) return;
      if (!hw.open) hw.open = true;
      hist.open = true;
      if (!hist.items.length && !hist.busy) loadHistory(); else renderHist();
      setTimeout(function () { hw.scrollIntoView({ behavior: 'smooth', block: 'start' }); }, 80);
    });
  }

  // ── onglet vidéo : module chargé à la demande ──
  var vapi = {
    get cfg() { return state.cfg; }, get credits() { return state.credits; }, T: T, errText: errText, shrink: function (f) { return shrink(f); },
    call: function (p, b) { return window.slashAuth.call(p, b); }, post: function (u, b, t) { return window.slashAuth.post(u, b, t); }, blob: function (p, b) { return window.slashAuth.blob(p, b); },
    setCredits: function (n) { state.credits = n; var e = $('#s-bal'); if (e) e.textContent = n + ' ' + (n === 1 ? T.credit : T.credits); syncBal(n); },
    refreshMe: function () { window.slashAuth.call('me').then(function (r) { if (r.status === 200) vapi.setCredits(r.data.credits); }); },
    openBuy: function (f) { openBuy(f); }, renderUrl: root.dataset.vurl || '',
  };
  function mountVideo() {
    var node = $('#v-root'); if (!node) return;
    var go = function () { window.saVideo.mount(node, vapi); };
    if (window.saVideo) return go();
    var sc = document.createElement('script'); sc.src = '/js/videomode.js?v=' + (root.dataset.vv || ''); sc.onload = go; document.head.appendChild(sc);
  }

  // ── photos : réduites dans le navigateur (1600 px, JPEG) avant l'envoi ──
  function shrink(file) {
    return new Promise(function (resolve, reject) {
      var url = URL.createObjectURL(file), img = new Image();
      img.onload = function () {
        var max = 1600, w = img.naturalWidth, h = img.naturalHeight, k = Math.min(1, max / Math.max(w, h));
        var c = document.createElement('canvas'); c.width = Math.round(w * k); c.height = Math.round(h * k);
        c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
        c.toBlob(function (b) {
          if (!b) { URL.revokeObjectURL(url); return reject(new Error('bad_photo')); }
          var r = new FileReader(); r.onload = function () { resolve({ url: URL.createObjectURL(b), mime: 'image/jpeg', data: String(r.result).split(',')[1] }); URL.revokeObjectURL(url); }; r.readAsDataURL(b);
        }, 'image/jpeg', 0.86);
      };
      img.onerror = function () { URL.revokeObjectURL(url); reject(new Error('bad_photo')); };
      img.src = url;
    });
  }
  function addFiles(list) {
    var files = Array.prototype.slice.call(list).slice(0, 3 - state.photos.length);
    Promise.all(files.map(function (f) { return shrink(f).catch(function () { return null; }); })).then(function (r) {
      r.forEach(function (p) { if (p) state.photos.push(p); });
      render(); if (r.some(function (p) { return !p; })) msg(T.e.bad_photo);
    });
  }

  // ── génération ──
  function generate() {
    if (state.busy || !state.photos.length) return;
    state.busy = true; state.result = null; state.versions = []; render(); msg('');
    var genPos = normUrl(state.qr.raw) && state.qr.pos !== 'none' ? state.qr.pos : '';
    var body = { slug: slug, lang: L, product: state.product, multi: state.multi, texts: brandTexts(), qrpos: saleOn() ? '' : genPos, sale: saleOn() || undefined, saleOpts: saleOn() ? saleOpts() : undefined, stagingInstruction: state.stagingInstruction || undefined, photos: state.photos.map(function (p) { return { mime: p.mime, data: p.data }; }) };
    window.slashAuth.call('generate', body).then(function (r) {
      state.busy = false;
      if (r.status === 200) {
        newVersion(r.data.id, r.data.mime, r.data.image).then(function (v) {
          v.genPos = genPos; state.result = v; state.versions = [v]; state.cur = 0; state.instruction = '';
          state.credits = r.data.credits; render(); window.scrollTo({ top: $('.sres').offsetTop - 70, behavior: 'smooth' });
          // Sauvegarde locale de l'image et refresh de l'historique
          if (v.blob) idb.save(r.data.id, v.blob).catch(function () {});
          setTimeout(loadHistory, 800);
        });
      } else {
        if (r.data && r.data.error === 'insufficient_credits') { render(); openBuy('serveur'); return; }
        render(); msg(errText(r.data && r.data.error));
      }
    }).catch(function () { state.busy = false; render(); msg(T.e.server); });
  }

  function editImage() {
    var cur = state.versions[state.cur];
    if (state.busy || !cur) return;
    var text = (state.instruction || '').trim();
    if (text.length < 3) return msg(T.e.no_instruction);
    state.busy = true; render();
    window.slashAuth.call('edit', { id: cur.id, lang: L, instruction: text }).then(function (r) {
      state.busy = false;
      if (r.status === 200) {
        newVersion(r.data.id, r.data.mime, r.data.image).then(function (v) {
          v.genPos = cur.genPos; state.versions.push(v); state.cur = state.versions.length - 1; state.result = v; state.instruction = ''; state.credits = r.data.credits; render();
        });
      } else if (r.data && r.data.error === 'insufficient_credits') { render(); openBuy('serveur'); }
      else { render(); msg(errText(r.data && r.data.error)); }
    }).catch(function () { state.busy = false; render(); msg(T.e.server); });
  }

  // ── achat de crédits (mobile money) ──
  function quoteUsd(price, payin, payout) { var r2 = function (n) { return Math.round(n * 100) / 100; }, send = r2(price * (1 + payout / 100)), total = r2(send * (1 + payin / 100)); return { send: send, total: total, fee: r2(total - price) }; }
  function quote(price, payin, payout) { var send = Math.ceil(price * (1 + payout / 100)), total = Math.ceil(send * (1 + payin / 100)); return { send: send, total: total, fee: total - price }; }
  function openBuy(from) {
    var cfg = state.cfg; if (!cfg) return;
    try { window.saTrack && window.saTrack('buyopen', { n: typeof from === 'string' ? from : 'button' }); } catch (e) {}
    var countries = []; cfg.operators.forEach(function (o) { if (countries.indexOf(o.country) < 0) countries.push(o.country); });
    var sel = { pack: (typeof from === 'string' && from === 'pass') ? 'nopub' : (cfg.packs.filter(function (p) { return p.tag; })[0] || cfg.packs[0]).id, country: countries[0], op: null, method: 'mm', terms: false };
    var TL = L === 'en' ? '/en/terms/' : '/conditions/';
    function cardOk(id) { return !cfg.card.packs || cfg.card.packs.indexOf(id) >= 0; }
    var modal = document.createElement('div'); modal.className = 'smodal'; modal.setAttribute('role', 'dialog'); modal.setAttribute('aria-modal', 'true');
    document.body.appendChild(modal); document.body.style.overflow = 'hidden';
    var timer = null, ISO = ['FR', 'BE', 'CH', 'LU', 'DE', 'ES', 'PT', 'IT', 'NL', 'GB', 'IE', 'US', 'CA', 'BR', 'MX', 'CO', 'BJ', 'TG', 'CI', 'SN', 'BF', 'ML', 'CM', 'CG', 'GA', 'GN', 'NE', 'TD', 'CD', 'MA', 'DZ', 'TN', 'GH', 'NG'];
    function close() { clearInterval(timer); modal.remove(); document.body.style.overflow = ''; }
    function ops() { return cfg.operators.filter(function (o) { return o.country === sel.country; }); }
    function countryName(c) { try { return new Intl.DisplayNames([L], { type: 'region' }).of(c) || c; } catch (e) { return c; } }
    function draw() {
      if (!sel.op || sel.op.country !== sel.country) sel.op = ops()[0];
      var pk = cfg.packs.filter(function (p) { return p.id === sel.pack; })[0];
      var isCard = sel.method === 'card';
      if (isCard && !cardOk(sel.pack)) sel.pack = (cfg.packs.filter(function (p) { return cardOk(p.id) && p.tag; })[0] || cfg.packs.filter(function (p) { return cardOk(p.id); })[0]).id;
      pk = cfg.packs.filter(function (p) { return p.id === sel.pack; })[0];
      var tabs = '<div class="mtabs" role="tablist"><button type="button" data-m="mm" aria-pressed="' + !isCard + '">' + T.mm + '</button>' + (cfg.card && cfg.card.enabled ? '<button type="button" data-m="card" aria-pressed="' + isCard + '">' + T.cardTab + '</button>' : '<button type="button" data-soon="1">' + T.cardTab + ' <em class="soon">' + T.soon + '</em></button>') + '</div>';
      var form;
      if (!isCard) {
        form = '<label>' + T.country + '<select id="b-country">' + countries.map(function (c) { return '<option' + (c === sel.country ? ' selected' : '') + '>' + esc(c) + '</option>'; }).join('') + '</select></label>' +
          '<label>' + T.operator + '<select id="b-op">' + ops().map(function (o) { return '<option value="' + o.code + '"' + (o.code === sel.op.code ? ' selected' : '') + '>' + esc(o.label) + '</option>'; }).join('') + '</select></label>' +
          '<label>' + T.phone + '<span class="pfx"><i>+' + sel.op.dial + '</i><input id="b-phone" type="tel" inputmode="tel" autocomplete="tel-national" placeholder="XXXXXXXX"></span></label>' +
          (sel.op.otp ? '<label>' + T.otp + '<input id="b-otp" type="text" inputmode="numeric" autocomplete="one-time-code"></label><p class="hint">' + T.otpHint + '</p>' : '');
      } else {
        var nm = (state.user.displayName || '').split(' ');
        form = '<div class="two"><label>' + T.firstName + '<input id="c-first" autocomplete="given-name" value="' + esc(nm[0] || '') + '"></label><label>' + T.lastName + '<input id="c-last" autocomplete="family-name" value="' + esc(nm.slice(1).join(' ')) + '"></label></div>' +
          '<label>' + T.phoneCard + '<input id="c-phone" type="tel" inputmode="tel" autocomplete="tel" placeholder="+33…"></label>' +
          '<div class="two"><label>' + T.city + '<input id="c-city" autocomplete="address-level2"></label><label>' + T.zip + '<input id="c-zip" autocomplete="postal-code"></label></div>' +
          '<label>' + T.countryCard + '<select id="c-country">' + ISO.map(function (c) { return '<option value="' + c + '">' + esc(countryName(c)) + '</option>'; }).join('') + '</select></label><p class="hint">' + T.cardInfo + '</p>';
      }
      modal.innerHTML = '<div class="sheet"><button class="x" type="button" aria-label="' + T.close + '">×</button><h2>' + (pk.days ? T.passTitle : T.buyTitle) + '</h2><p class="hint">' + (pk.days ? T.passSub : T.buySub) + '</p>' + (pk.days ? '' : '<a class="refstrip" href="' + refUrl() + '"><span aria-hidden="true">🎁</span><b>' + T.refShort + '</b><i>' + T.refGo + ' ›</i></a>') +
        '<div class="packs">' + cfg.packs.slice().sort(function (x, y) { return (x.days ? 1 : 0) - (y.days ? 1 : 0); }).map(function (p) { return '<button type="button" class="pack' + (p.days ? ' passtile' : '') + (p.id === sel.pack ? ' on' : '') + '" data-p="' + p.id + '"' + (isCard && !cardOk(p.id) ? ' disabled' : '') + '>' + (p.tag ? '<i>' + T.popular + '</i>' : '') + (p.days ? '<b>' + p.days + ' ' + T.passUnit + '</b><span>' + T.passTag + '</span><em>' + usd(p.usd) + '</em><small>≈ ' + fmt(p.xof) + ' FCFA</small>' : '<b>' + p.credits + '</b><span>' + T.credits + '</span><em>' + usd(p.usd) + '</em><small>≈ ' + fmt(p.xof) + ' FCFA</small>') + '</button>'; }).join('') + '</div>' + tabs + form +
        '<p class="hint soft">' + T.feeNote + '</p><label class="terms"><input type="checkbox" id="b-terms"' + (sel.terms ? ' checked' : '') + '><span><b class="ttag">' + T.termsTag + '</b>' + T.termsAccept + '<a href="' + TL + '" target="_blank" rel="noopener">' + T.termsLink + '</a>.' + T.termsNote + '</span></label>' + (isCard ? '<p class="hint">' + T.cardPackOnly + '</p>' : '') +
        '<button class="btn pri big" type="button" id="b-pay">' + (isCard ? T.cardGo + ' ' + usd(pk.usd) : T.pay + ' ' + fmt(pk.xof) + ' FCFA') + '</button><p class="fmsg" id="b-msg" role="status" aria-live="polite"></p>' + (CONTACT ? '<p class="hint soft">' + T.help + ' <a href="mailto:' + CONTACT + '">' + CONTACT + '</a></p>' : '') + '</div>';
      $('.x', modal).onclick = close;
      Array.prototype.forEach.call(modal.querySelectorAll('.pack'), function (b) { b.onclick = function () { sel.pack = b.dataset.p; draw(); }; });
      Array.prototype.forEach.call(modal.querySelectorAll('[data-m]'), function (b) { b.onclick = function () { sel.method = b.dataset.m; draw(); }; });
      var co = $('#b-country', modal); if (co) co.onchange = function (e) { sel.country = e.target.value; sel.op = null; draw(); };
      var op = $('#b-op', modal); if (op) op.onchange = function (e) { sel.op = ops().filter(function (o) { return o.code === e.target.value; })[0]; draw(); };
      var sn = $('[data-soon]', modal); if (sn) sn.onclick = function () { try { window.saTrack && window.saTrack('cardwish', { n: sel.pack }); } catch (e) {} bmsg(T.cardSoon, true); };
      $('#b-terms', modal).onchange = function (e) { sel.terms = e.target.checked; var t = $('.terms', modal); if (t) t.classList.remove('err'); };
      $('#b-pay', modal).onclick = isCard ? payCard : pay;
    }
    function bmsg(t, ok) { var m = $('#b-msg', modal); if (m) { m.textContent = t || ''; m.className = 'fmsg' + (ok ? ' ok' : ' err'); } }
    function track(orderId, btn, total) {
      var tries = 0; bmsg(total ? T.validate.replace('{a}', fmt(total) + ' FCFA') : T.waitPay, true);
      timer = setInterval(function () {
        tries++;
        window.slashAuth.call('pay/status', { orderId: orderId }).then(function (s) {
          if (s.status !== 200) return;
          if (s.data.status === 'paid') { clearInterval(timer); try { var pp = cfg.packs.filter(function (x) { return x.id === sel.pack; })[0]; if (window.gtag && pp) window.gtag('event', 'purchase', { transaction_id: orderId, value: pp.usd, currency: 'USD', items: [{ item_id: pp.id, item_name: pp.days ? 'no-ads-pass' : 'credits-' + pp.credits, price: pp.usd, quantity: 1 }] }); } catch (e) {} try { localStorage.removeItem('sa_pending'); } catch (e) {} state.credits = s.data.balance; if (s.data.adFreeUntil) setAdFree(s.data.adFreeUntil); bmsg(s.data.adFreeUntil && !s.data.credits ? T.paidPass : T.paid, true); setTimeout(function () { close(); render(); }, 1200); }
          else if (s.data.status === 'failed') { clearInterval(timer); busy(btn, false); bmsg(T.payFailed); }
        });
        if (tries > 60) { clearInterval(timer); busy(btn, false); bmsg(T.payFailed); }
      }, 4000);
    }
    function pay() {
      var btn = $('#b-pay', modal), phone = $('#b-phone', modal).value.replace(/\D/g, ''), otp = sel.op.otp ? ($('#b-otp', modal).value || '').trim() : '';
      var okForm = phone.length >= 8 && !(sel.op.otp && !otp) && sel.terms;
      try { window.saTrack && window.saTrack('paytry', { m: 'mm', n: sel.pack, o: sel.op.code, v: okForm ? 1 : 0 }); } catch (e) {}
      if (phone.length < 8) return bmsg(T.e.bad_phone);
      if (sel.op.otp && !otp) return bmsg(T.e.otp_required);
      if (!sel.terms) { flagTerms(modal); return bmsg(T.e.terms_required); }
      busy(btn, true); bmsg(T.paying, true);
      window.slashAuth.call('pay/start', { packId: sel.pack, operator: sel.op.code, phone: phone, otp: otp, terms: cfg.termsVersion }).then(function (r) {
        if (r.status !== 200) { busy(btn, false); return bmsg(errText(r.data && r.data.error)); }
        if (r.data.paymentUrl) { var a = document.createElement('a'); a.href = r.data.paymentUrl; a.target = '_blank'; a.rel = 'noopener'; a.textContent = T.openPay; a.className = 'btn gl'; $('#b-msg', modal).after(a); }
        track(r.data.orderId, btn, r.data.total);
      }).catch(function () { busy(btn, false); bmsg(T.e.server); });
    }
    function payCard() {
      var btn = $('#b-pay', modal), v = function (id) { return ($('#' + id, modal).value || '').trim(); };
      var body = { packId: sel.pack, firstName: v('c-first'), lastName: v('c-last'), phone: v('c-phone'), city: v('c-city'), zip: v('c-zip'), country: $('#c-country', modal).value, terms: cfg.termsVersion };
      if (!sel.terms) { flagTerms(modal); return bmsg(T.e.terms_required); }
      if (!body.firstName || !body.lastName || !body.city || !body.zip || body.phone.replace(/\D/g, '').length < 8) return bmsg(T.e.bad_card_info);
      busy(btn, true); bmsg(T.paying, true);
      window.slashAuth.call('pay/card', body).then(function (r) {
        if (r.status !== 200) { busy(btn, false); return bmsg(errText(r.data && r.data.error)); }
        try { localStorage.setItem('sa_pending', r.data.orderId); } catch (e) {}
        location.href = r.data.paymentUrl;
      }).catch(function () { busy(btn, false); bmsg(T.e.server); });
    }
    draw();
  }
  // retour de la page de paiement par carte : on vérifie la commande en attente
  function resumePending() {
    var id = null; try { id = localStorage.getItem('sa_pending'); } catch (e) {}
    if (!id || !state.user) return;
    msg(T.pending, true);
    var tries = 0, t = setInterval(function () {
      tries++;
      window.slashAuth.call('pay/status', { orderId: id }).then(function (s) {
        if (s.status === 200 && s.data.status === 'paid') { clearInterval(t); try { localStorage.removeItem('sa_pending'); } catch (e) {} state.credits = s.data.balance; if (s.data.adFreeUntil) setAdFree(s.data.adFreeUntil); render(); msg(s.data.adFreeUntil && !s.data.credits ? T.paidPass : T.paid, true); }
        else if (s.status === 200 && s.data.status === 'failed') { clearInterval(t); try { localStorage.removeItem('sa_pending'); } catch (e) {} msg(T.payFailed); }
        else if (s.status === 404) { clearInterval(t); try { localStorage.removeItem('sa_pending'); } catch (e) {} msg(''); }
      });
      if (tries > 30) clearInterval(t);
    }, 4000);
  }

  function maybePass() { if (wantPass && state.user && state.cfg && !state.adFreeUntil && state.meLoaded) { wantPass = false; openBuy('pass'); } }

  // ── parrainage ──
  function savedRef() { try { var o = JSON.parse(localStorage.getItem('sa_ref') || 'null'); return o && Date.now() - o.t < 60 * 864e5 ? o.c : ''; } catch (e) { return ''; } }
  function refUrl() { return L === 'en' ? '/en/referral/' : '/parrainage/'; }

  // ── IndexedDB : cache local des images générées ──
  var idb = (function () {
    var DB = 'sa_studio', ST = 'imgs', _db = null;
    function open() {
      if (_db) return Promise.resolve(_db);
      return new Promise(function (res, rej) {
        var r = indexedDB.open(DB, 1);
        r.onupgradeneeded = function (e) { e.target.result.createObjectStore(ST); };
        r.onsuccess = function (e) { _db = e.target.result; res(_db); };
        r.onerror = function () { rej(r.error); };
      });
    }
    return {
      save: function (id, blob) { return open().then(function (db) { return new Promise(function (res) { var tx = db.transaction(ST, 'readwrite'); tx.objectStore(ST).put(blob, id); tx.oncomplete = res; tx.onerror = res; }); }).catch(function () {}); },
      get: function (id) { return open().then(function (db) { return new Promise(function (res) { var r = db.transaction(ST).objectStore(ST).get(id); r.onsuccess = function () { res(r.result || null); }; r.onerror = function () { res(null); }; }); }).catch(function () { return null; }); },
    };
  })();

  // ── historique des créations ──
  var hist = { items: [], busy: false, open: false };
  function relDate(ms) {
    if (!ms) return '';
    var d = new Date(ms), now = new Date(), diff = Math.floor((now - d) / 864e5);
    if (diff === 0) return L === 'en' ? 'Today' : 'Aujourd\'hui';
    if (diff === 1) return L === 'en' ? 'Yesterday' : 'Hier';
    if (diff < 7) return diff + (L === 'en' ? ' days ago' : ' j');
    try { return d.toLocaleDateString(L === 'en' ? 'en' : 'fr', { day: 'numeric', month: 'short' }); } catch (e) { return d.toLocaleDateString(); }
  }
  function loadHistory() {
    if (hist.busy || !state.user) return;
    hist.busy = true;
    window.slashAuth.call('history', {}).then(function (r) {
      hist.busy = false;
      if (r.status === 200 && Array.isArray(r.data)) { hist.items = r.data; if (hist.items.length && !hist.open) { hist.open = true; render(); } renderHist(); }
    }).catch(function () { hist.busy = false; });
  }
  function renderHist() {
    var el = document.getElementById('s-hist');
    if (!el) return;
    var TH = L === 'en' ? { title: 'My creations', empty: 'No image generated yet.', get: 'Recover', loading: 'Loading…', dl: 'Download' }
      : { title: 'Mes créations', empty: 'Aucune image générée pour le moment.', get: 'Récupérer', loading: 'Chargement…', dl: 'Télécharger' };
    if (!hist.items.length) { el.innerHTML = '<p class="hint" style="margin:0">' + TH.empty + '</p>'; return; }
    var cmds = data.commands;
    el.innerHTML = hist.items.map(function (item) {
      var cmd = cmds[item.slug] || {}; var label = (cmd.code || item.slug) + (cmd.title ? ' · ' + cmd.title : '');
      return '<div class="shistrow" data-hid="' + item.id + '"><div class="shinfo"><b>' + esc(label) + '</b><small>' + relDate(item.ts) + (item.product ? ' · ' + esc(item.product.slice(0, 30)) : '') + '</small></div><button class="btn gl sm shget" type="button" data-hid="' + item.id + '" data-hmime="image/jpeg">' + TH.get + '</button></div>';
    }).join('');
    Array.prototype.forEach.call(el.querySelectorAll('.shget'), function (btn) {
      btn.addEventListener('click', function () {
        var id = btn.dataset.hid;
        btn.disabled = true; btn.textContent = TH.loading;
        idb.get(id).then(function (blob) {
          if (blob) return blob;
          return window.slashAuth.call('regen', { id: id }).then(function (r) {
            if (r.status !== 200) throw new Error('not_found');
            var b64 = r.data.image, mime = r.data.mime || 'image/jpeg';
            var bytes = atob(b64), arr = new Uint8Array(bytes.length);
            for (var i = 0; i < bytes.length; i++) arr[i] = bytes.charCodeAt(i);
            var bl = new Blob([arr], { type: mime });
            idb.save(id, bl).catch(function () {});
            return bl;
          });
        }).then(function (blob) {
          var url = URL.createObjectURL(blob);
          var ext = blob.type.includes('png') ? 'png' : 'jpg';
          var item = hist.items.filter(function (x) { return x.id === id; })[0] || {};
          var row = el.querySelector('.shistrow[data-hid="' + id + '"]');
          if (row) {
            row.innerHTML = '<img src="' + url + '" class="shthumb" alt=""><div class="shinfo"><b>' + esc((data.commands[item.slug] || {}).code || item.slug) + '</b><small>' + relDate(item.ts) + '</small></div><a class="btn pri sm" href="' + url + '" download="slashatlas-' + (item.slug || 'image') + '.' + ext + '">' + TH.dl + '</a>';
          }
        }).catch(function () { btn.disabled = false; btn.textContent = TH.get; });
      });
    });
  }
  function histSection() {
    if (!state.user || !state.meLoaded) return '';
    var TH = L === 'en' ? { title: 'My creations' } : { title: 'Mes créations' };
    return '<details class="shist-wrap"' + (hist.open ? ' open' : '') + '><summary>' + TH.title + (hist.items.length ? ' (' + hist.items.length + ')' : '') + '</summary><div id="s-hist" class="shist">' + (hist.busy ? '<span class="spin" aria-label="…"></span>' : '') + '</div></details>';
  }

  function syncBal(n) {
    try { localStorage.setItem('sa_bal', String(n)); } catch (e) {}
    try { window.dispatchEvent(new CustomEvent('sa:credits', { detail: n })); } catch (e) {}
  }

  function loadBrandProfile() {
    if (state.brandProfileLoaded) return;
    window.slashAuth.call('brand-profile', {}).then(function (r) {
      if (r.status === 200 && r.data) {
        var d = r.data;
        if (d.brand && !state.brand.brand) state.brand.brand = d.brand;
        if (d.contact && !state.brand.contact) state.brand.contact = d.contact;
        if (d.other && !state.brand.other) state.brand.other = d.other;
        if (d.brand || d.contact || d.other) { state.brandProfileLoaded = true; saleSave(); render(); }
      }
    }).catch(function () {});
  }
  function saveBrandProfileToServer() {
    if (!state.user) return;
    window.slashAuth.call('brand-profile', { brand: state.brand.brand, contact: state.brand.contact, other: state.brand.other }).then(function (r) {
      if (r.status === 200) { state.brandProfileLoaded = true; saleSave(); }
    }).catch(function () {});
  }
  window.slashStudio = { openBuy: function (f) { openBuy(f); } };

  // ── démarrage ──
  saleLoad();
  import('/js/auth.js');
  fetch('/api/config').then(function (r) { return r.json(); }).then(function (c) { state.cfg = c; maybePass(); }).catch(function () {});
  document.addEventListener('sa:auth', function (e) {
    var u = e.detail.user; state.user = u;
    if (!u) { state.checking = false; state.credits = 0; state.result = null; render(); return; }
    window.slashAuth.call('me', { ref: savedRef() }).then(function (r) {
      state.checking = false;
      if (r.status === 200) { state.meLoaded = true; state.credits = r.data.credits; syncBal(r.data.credits); setAdFree(r.data.adFreeUntil || 0); render(); msg(r.data.created ? T.welcome : T.back, true); setTimeout(function () { msg(''); }, 2500); resumePending(); maybePass(); loadHistory(); loadBrandProfile(); }
      else { render(); msg(errText(r.data && r.data.error)); }
    });
  });
  render();
})();
