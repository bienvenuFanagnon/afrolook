// Page « Proposer ma commande » : pseudo, demande en 1 phrase, contrôle par l'IA, test obligatoire avec ses crédits, soumission pour validation.
(function () {
  'use strict';
  var root = document.getElementById('prop'); if (!root) return;
  var L = root.dataset.locale === 'en' ? 'en' : 'fr', TRY = root.dataset.try || '/generer/';
  var TX = {
    fr: {
      loginH: 'Connectez-vous pour proposer une commande', loginP: 'Gratuit, avec votre compte Google. Le test du rendu se fait avec vos propres crédits.', login: 'Continuer avec Google',
      steps: ['1 · Rédiger', '2 · Tester', '3 · Soumettre'],
      handleH: 'Choisissez votre pseudo', handleP: 'Il s’affiche sur vos commandes publiées. 3 à 20 caractères : lettres, chiffres ou _. Un changement possible par mois.', handleIn: 'votre_pseudo', handleSave: 'Enregistrer mon pseudo', handleOk: 'Disponible', handleNext: 'Prochain changement possible le ', yourHandle: 'Votre pseudo',
      briefH: 'Décrivez l’affiche que vous voulez', briefP: 'Dites à quoi sert l’affiche, ce qu’on y voit (le sujet de la photo) et l’ambiance. Quelques phrases suffisent.', briefIn: 'Ex. : affiche pour un salon de coiffure, la photo d’une cliente au centre, fond rose pastel, lumière douce, espace en bas pour les prix.', ex: ['Affiche pour un salon de coiffure, cliente au centre, fond rose pastel', 'Promotion d’un plat africain en gros plan, ambiance chaude, espace pour le prix', 'Annonce d’une villa à louer, photo lumineuse et chic'], exH: 'Idées pour démarrer',
      analyze: 'Analyser ma demande', analyzing: 'Analyse en cours…', min: 'Au moins 25 caractères.',
      reviewH: 'Votre commande', cat: 'Catégorie', fmt: 'Format', tests: 'tests faits',
      testH: 'Testez le rendu avec vos crédits', testP: 'Le test est obligatoire : ajoutez une photo de ce que la commande doit transformer, lancez la génération et vérifiez le résultat. Ce rendu deviendra l’aperçu de votre commande.', testPFree: 'Cette commande crée l’image sans photo : lancez la génération pour voir le résultat. Ce rendu deviendra l’aperçu de votre commande.',
      photo: 'Ajouter une photo', photoChange: 'Changer la photo', product: 'Nom du produit ou du sujet (facultatif)', runTest: 'Tester', credits: 'crédits', balance: 'Votre solde', again: 'Refaire un test', good: 'Ce rendu me convient : en faire l’aperçu', running: 'Création de l’image… (jusqu’à 40 secondes)', needPhoto: 'Ajoutez d’abord une photo.', buy: 'Recharger mes crédits', previewOk: 'Aperçu validé ✓', next: 'Continuer', editBrief: 'Modifier ma demande',
      submitH: 'Soumettre pour validation', modeH: 'Votre commande est…', free: 'Gratuite', freeP: 'Les utilisateurs la lancent au tarif normal (6 crédits). Idéal pour se faire connaître et monter dans le classement.', paid: 'Payante', paidP: 'Les utilisateurs paient 1 crédit de plus (7 au lieu de 6), qui vous revient. Le gain est protégé 7 jours, puis il est à vous.', consent: 'J’accepte que ce rendu serve d’aperçu public, que ma commande soit contrôlée par SlashAtlas et publiée sous mon pseudo.', submit: 'Soumettre ma commande', sending: 'Envoi…',
      doneH: 'Commande soumise ✓', doneP: 'Elle sera relue par l’équipe SlashAtlas. Vous pouvez suivre son état ci-dessous.', another: 'Proposer une autre commande',
      mineH: 'Mes commandes', usesN: function (n) { return n + ' utilisation' + (n > 1 ? 's' : ''); }, peopleN: function (n) { return n + ' personne' + (n > 1 ? 's' : ''); }, view: 'Voir la page', shareL: 'Partager', linkCopied: 'Lien copié ✓', myProfile: 'Mon profil public', sumCmds: 'commandes publiées', sumUses: 'utilisations', none: 'Aucune proposition pour le moment.', st: { draft: 'Brouillon', pending: 'En attente de validation', published: 'Publiée', rejected: 'Refusée', suspended: 'Retirée' }, modeL: { free: 'Gratuite', paid: 'Payante' }, resume: 'Continuer', del: 'Supprimer', reason: 'Motif', confirmDel: 'Supprimer cette proposition ?',
      walletH: 'Mon solde de gains', wAvail: 'disponibles', wPend: 'en attente', wSpent: 'déjà utilisés ou retirés', wRate: function (r) { return '1 crédit gagné = ' + r + ' F'; }, wHold: function (d) { return 'Un gain est protégé ' + d + ' jours avant de devenir disponible (annulé si le paiement de l’acheteur est contesté).'; }, wMin: function (l) { return 'Retrait dès ' + l.minMobileXof + ' F par mobile money (' + l.minMobileCredits + ' crédits) ou ' + l.minCardUsd + ' $ par carte bancaire (' + l.minCardCredits + ' crédits). Les crédits gagnés peuvent aussi être convertis en crédits pour créer des affiches.'; }, wConv: 'Convertir en crédits', wWd: 'Demander un retrait', wAmount: 'Nombre de crédits', wDo: 'Valider', wMethod: 'Moyen de retrait', wMobile: 'Mobile money', wCard: 'Carte bancaire', wAccount: 'Numéro mobile money et opérateur, ou coordonnées de la carte', wName: 'Nom du titulaire', wFrozen: 'Vos gains sont suspendus : contactez-nous.', wHist: 'Mes retraits', wDone: 'Fait ✓', earnedN: function (n) { return n + ' crédit' + (n > 1 ? 's' : '') + ' gagné' + (n > 1 ? 's' : ''); }, wst: { requested: 'En attente de paiement', paid: 'Payé', refused: 'Refusé' }, wAll: 'Tout',
      rules: 'Règles : pas de contenu adulte, violent ou illégal, pas de marque ni de personne réelle imitée, pas de promesse trompeuse. Chaque commande est relue avant publication.',
      e: { not_enough_gains: 'Vous n’avez pas assez de gains disponibles.', below_min: 'Montant inférieur au minimum de retrait.', bad_account: 'Renseignez un compte de retrait valide et le nom du titulaire.', withdrawal_pending: 'Un retrait est déjà en attente de paiement.', account_linked: 'Ce compte de retrait est déjà utilisé par un autre compte.', frozen: 'Vos gains sont suspendus.', bad_amount: 'Montant invalide.', bad_method: 'Choisissez un moyen de retrait.', bad_handle: 'Pseudo invalide : 3 à 20 caractères, lettres minuscules, chiffres ou _.', handle_forbidden: 'Ce pseudo n’est pas autorisé. Choisissez-en un autre.', handle_taken: 'Ce pseudo est déjà pris.', handle_cooldown: 'Vous avez déjà changé de pseudo ce mois-ci.', brief_short: 'Décrivez un peu plus l’affiche (25 caractères au moins).', daily_limit: 'Limite du jour atteinte. Réessayez demain.', blocked: 'Ce compte ne peut pas proposer de commande.', ai_format: 'L’analyse n’a pas abouti. Reformulez votre demande et réessayez.', ai_unavailable: 'L’analyse est indisponible pour le moment. Réessayez dans quelques minutes.', insufficient_credits: 'Crédits insuffisants pour lancer le test.', tests_limit: 'Nombre maximal de tests atteint pour cette commande.', bad_render: 'Ce rendu ne correspond pas à cette commande. Relancez un test.', test_required: 'Validez d’abord un rendu de test.', consent_required: 'Cochez la case pour continuer.', handle_required: 'Choisissez d’abord votre pseudo.', pending_limit: 'Trop de commandes en attente de validation.', no_photo: 'Ajoutez d’abord une photo.', bad_photo: 'Photo non reconnue (JPG, PNG ou WebP).', photo_too_big: 'Photo trop lourde.', refused: 'L’IA a refusé cette image. Essayez une autre photo.', busy: 'Le service est très sollicité. Réessayez dans un instant.', rate: 'Trop de demandes. Patientez un instant.', server: 'Une erreur est survenue. Réessayez.' },
    },
    en: {
      loginH: 'Sign in to submit a command', loginP: 'Free, with your Google account. Testing the result uses your own credits.', login: 'Continue with Google',
      steps: ['1 · Write', '2 · Test', '3 · Submit'],
      handleH: 'Choose your username', handleP: 'It appears on your published commands. 3 to 20 characters: letters, digits or _. One change per month.', handleIn: 'your_username', handleSave: 'Save my username', handleOk: 'Available', handleNext: 'Next change possible on ', yourHandle: 'Your username',
      briefH: 'Describe the poster you want', briefP: 'Say what the poster is for, what we see in it (the subject of the photo) and the mood. A few sentences are enough.', briefIn: 'E.g.: poster for a hair salon, a client’s photo in the center, pastel pink background, soft light, space at the bottom for prices.', ex: ['Poster for a hair salon, client in the center, pastel pink background', 'Close-up promotion of an African dish, warm mood, space for the price', 'Announcement of a villa for rent, bright and chic photo'], exH: 'Ideas to start',
      analyze: 'Analyze my request', analyzing: 'Analyzing…', min: 'At least 25 characters.',
      reviewH: 'Your command', cat: 'Category', fmt: 'Format', tests: 'tests done',
      testH: 'Test the result with your credits', testP: 'The test is mandatory: add a photo of what the command should transform, run the generation and check the result. This result becomes the preview of your command.', testPFree: 'This command creates the image without a photo: run the generation to see the result. This result becomes the preview of your command.',
      photo: 'Add a photo', photoChange: 'Change the photo', product: 'Product or subject name (optional)', runTest: 'Test', credits: 'credits', balance: 'Your balance', again: 'Test again', good: 'This result is good: use it as the preview', running: 'Creating the image… (up to 40 seconds)', needPhoto: 'Add a photo first.', buy: 'Top up my credits', previewOk: 'Preview validated ✓', next: 'Continue', editBrief: 'Edit my request',
      submitH: 'Submit for approval', modeH: 'Your command is…', free: 'Free', freeP: 'Users run it at the normal price (6 credits). Great to get known and climb the ranking.', paid: 'Paid', paidP: 'Users pay 1 extra credit (7 instead of 6), which comes to you. The earning is held for 7 days, then it is yours.', consent: 'I agree that this result is used as a public preview, that my command is reviewed by SlashAtlas and published under my username.', submit: 'Submit my command', sending: 'Sending…',
      doneH: 'Command submitted ✓', doneP: 'It will be reviewed by the SlashAtlas team. You can follow its status below.', another: 'Submit another command',
      mineH: 'My commands', usesN: function (n) { return n + ' use' + (n > 1 ? 's' : ''); }, peopleN: function (n) { return n + ' ' + (n > 1 ? 'people' : 'person'); }, view: 'View the page', shareL: 'Share', linkCopied: 'Link copied ✓', myProfile: 'My public profile', sumCmds: 'published commands', sumUses: 'uses', none: 'No submission yet.', st: { draft: 'Draft', pending: 'Awaiting approval', published: 'Published', rejected: 'Rejected', suspended: 'Removed' }, modeL: { free: 'Free', paid: 'Paid' }, resume: 'Continue', del: 'Delete', reason: 'Reason', confirmDel: 'Delete this submission?',
      walletH: 'My earnings', wAvail: 'available', wPend: 'pending', wSpent: 'already used or withdrawn', wRate: function (r) { return '1 earned credit = ' + r + ' F'; }, wHold: function (d) { return 'An earning is held for ' + d + ' days before it becomes available (cancelled if the buyer’s payment is disputed).'; }, wMin: function (l) { return 'Withdraw from ' + l.minMobileXof + ' F by mobile money (' + l.minMobileCredits + ' credits) or $' + l.minCardUsd + ' by bank card (' + l.minCardCredits + ' credits). Earned credits can also be converted into credits to create posters.'; }, wConv: 'Convert to credits', wWd: 'Request a withdrawal', wAmount: 'Number of credits', wDo: 'Confirm', wMethod: 'Withdrawal method', wMobile: 'Mobile money', wCard: 'Bank card', wAccount: 'Mobile money number and operator, or card details', wName: 'Account holder name', wFrozen: 'Your earnings are suspended: please contact us.', wHist: 'My withdrawals', wDone: 'Done ✓', earnedN: function (n) { return n + ' credit' + (n > 1 ? 's' : '') + ' earned'; }, wst: { requested: 'Awaiting payment', paid: 'Paid', refused: 'Refused' }, wAll: 'All',
      rules: 'Rules: no adult, violent or illegal content, no imitation of brands or real people, no misleading promises. Every command is reviewed before publication.',
      e: { not_enough_gains: 'You do not have enough available earnings.', below_min: 'Amount below the minimum withdrawal.', bad_account: 'Enter a valid payout account and the account holder name.', withdrawal_pending: 'A withdrawal is already awaiting payment.', account_linked: 'This payout account is already used by another account.', frozen: 'Your earnings are suspended.', bad_amount: 'Invalid amount.', bad_method: 'Choose a withdrawal method.', bad_handle: 'Invalid username: 3 to 20 characters, lowercase letters, digits or _.', handle_forbidden: 'This username is not allowed. Pick another one.', handle_taken: 'This username is already taken.', handle_cooldown: 'You already changed your username this month.', brief_short: 'Describe the poster a bit more (at least 25 characters).', daily_limit: 'Daily limit reached. Try again tomorrow.', blocked: 'This account cannot submit commands.', ai_format: 'The analysis failed. Rephrase your request and try again.', ai_unavailable: 'The analysis is unavailable right now. Try again in a few minutes.', insufficient_credits: 'Not enough credits to run the test.', tests_limit: 'Maximum number of tests reached for this command.', bad_render: 'This result does not match this command. Run a new test.', test_required: 'Validate a test result first.', consent_required: 'Tick the box to continue.', handle_required: 'Choose your username first.', pending_limit: 'Too many commands awaiting approval.', no_photo: 'Add a photo first.', bad_photo: 'Unrecognized photo (JPG, PNG or WebP).', photo_too_big: 'Photo too large.', refused: 'The AI refused this image. Try another photo.', busy: 'The service is very busy. Try again in a moment.', rate: 'Too many requests. Please wait a moment.', server: 'Something went wrong. Please try again.' },
    },
  }[L];
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var st = { checking: true, user: null, prof: null, items: [], draft: null, step: 1, brief: '', product: '', photo: null, genId: '', result: null, busy: '', msg: '', err: '', mode: 'free', consent: false, done: false, handleIn: '', handleOk: null };
  var errTxt = function (code) { return TX.e[code] || TX.e.server; };
  var title = function (x) { return L === 'en' ? x.titleEn : x.titleFr; };
  var desc = function (x) { return L === 'en' ? x.descEn : x.descFr; };
  var cmdUrl = function (id) { return (L === 'en' ? '/en/c/u-' : '/c/u-') + id + '/'; };
  var fmtDate = function (ms) { return new Date(ms).toLocaleDateString(L === 'en' ? 'en-GB' : 'fr-FR', { day: 'numeric', month: 'long' }); };

  function api(path, body) {
    return window.slashAuth.call('community/' + path, body || {}).then(function (r) { if (r.status === 200) return r.data; throw { code: (r.data && r.data.error) || 'server', status: r.status }; });
  }
  function fail(e) { st.busy = ''; st.err = errTxt(e && e.code); render(); }
  function loadAll() {
    return Promise.all([api('profile'), api('mine'), api('wallet').catch(function () { return null; })]).then(function (a) { st.prof = a[0]; st.items = a[1].items || []; st.wallet = a[2]; render(); }).catch(function (e) { st.err = errTxt(e && e.code); render(); });
  }

  function stepper() {
    return '<ol class="pstep">' + TX.steps.map(function (s, i) { return '<li class="' + (i + 1 === st.step ? 'on' : i + 1 < st.step ? 'ok' : '') + '">' + esc(s) + '</li>'; }).join('') + '</ol>';
  }
  function summary() {
    var d = st.draft; if (!d) return '';
    return '<div class="pcard"><b>' + esc(title(d)) + '</b><p>' + esc(desc(d)) + '</p><small>' + esc(TX.cat) + ' : ' + esc(d.catLabel) + ' · ' + esc(TX.fmt) + ' : ' + esc(d.ratio) + (d.tests ? ' · ' + d.tests + ' ' + esc(TX.tests) : '') + '</small></div>';
  }
  function msgs() { return (st.err ? '<p class="fmsg err" role="alert">' + esc(st.err) + '</p>' : '') + (st.msg ? '<p class="fmsg" role="status">' + esc(st.msg) + '</p>' : ''); }

  function viewHandle() {
    var ok = st.handleOk;
    return '<div class="sbox pbox"><h2 class="ph2">' + esc(TX.handleH) + '</h2><p class="hint">' + esc(TX.handleP) + '</p><div class="prow"><span class="pat">@</span><input id="p-handle" class="pin" type="text" maxlength="20" autocapitalize="off" autocomplete="off" spellcheck="false" placeholder="' + esc(TX.handleIn) + '" value="' + esc(st.handleIn) + '"></div>' +
      '<p class="fmsg' + (ok === false ? ' err' : '') + '" id="p-hmsg">' + (ok === true ? esc(TX.handleOk) + ' ✓' : ok === false ? esc(errTxt(st.handleWhy)) : '') + '</p><button class="btn pri" type="button" id="p-hsave"' + (ok === true && !st.busy ? '' : ' disabled') + '>' + esc(TX.handleSave) + '</button>' + msgs() + '</div>';
  }
  function viewStep1() {
    return '<div class="sbox pbox">' + stepper() + '<h2 class="ph2">' + esc(TX.briefH) + '</h2><p class="hint">' + esc(TX.briefP) + '</p><textarea id="p-brief" class="pin" rows="5" maxlength="600" placeholder="' + esc(TX.briefIn) + '">' + esc(st.brief) + '</textarea>' +
      '<div class="pex"><small>' + esc(TX.exH) + '</small>' + TX.ex.map(function (x, i) { return '<button class="chip" type="button" data-ex="' + i + '">' + esc(x) + '</button>'; }).join('') + '</div>' +
      '<button class="btn pri big" type="button" id="p-analyze"' + (st.busy ? ' disabled' : '') + '>' + esc(st.busy === 'analyze' ? TX.analyzing : TX.analyze) + '</button>' + msgs() + '<p class="hint">' + esc(TX.rules) + '</p></div>';
  }
  function viewStep2() {
    var d = st.draft, free = d.kind === 'free', cost = st.prof ? st.prof.genCost : 6, bal = st.prof ? st.prof.credits : 0;
    var photoBox = free ? '' : '<div class="pphoto">' + (st.photo ? '<img src="' + esc(st.photo.url) + '" alt="">' : '') + '<label class="btn gl sm">' + esc(st.photo ? TX.photoChange : TX.photo) + '<input id="p-photo" type="file" accept="image/*" hidden></label></div><input id="p-product" class="pin" type="text" maxlength="60" placeholder="' + esc(TX.product) + '" value="' + esc(st.product) + '">';
    var res = st.result ? '<div class="pres"><img src="data:' + esc(st.result.mime) + ';base64,' + st.result.image + '" alt=""><div class="acts big"><button class="btn pri" type="button" id="p-good"' + (st.busy ? ' disabled' : '') + '>' + esc(TX.good) + '</button><button class="btn gl" type="button" id="p-test"' + (st.busy ? ' disabled' : '') + '>' + esc(TX.again) + '</button></div></div>' : '';
    var lowBal = bal < cost;
    return '<div class="sbox pbox">' + stepper() + summary() + '<h2 class="ph2">' + esc(TX.testH) + '</h2><p class="hint">' + esc(free ? TX.testPFree : TX.testP) + '</p>' + photoBox +
      '<p class="pbal">' + esc(TX.balance) + ' : <b>' + bal + '</b> ' + esc(TX.credits) + (lowBal ? ' · <a href="' + esc(TRY) + '">' + esc(TX.buy) + '</a>' : '') + '</p>' +
      (st.result ? '' : '<button class="btn pri big" type="button" id="p-test"' + (st.busy ? ' disabled' : '') + '>' + esc(st.busy === 'test' ? TX.running : TX.runTest + ' · ' + cost + ' ' + TX.credits) + '</button>') + (st.busy === 'test' && st.result ? '<p class="fmsg">' + esc(TX.running) + '</p>' : '') + res +
      (d.hasPreview && !st.result ? '<p class="fmsg">' + esc(TX.previewOk) + '</p><button class="btn gl" type="button" id="p-next">' + esc(TX.next) + '</button>' : '') +
      msgs() + '<button class="btn gl sm" type="button" id="p-edit">' + esc(TX.editBrief) + '</button></div>';
  }
  function viewStep3() {
    return '<div class="sbox pbox">' + stepper() + summary() + '<p class="fmsg">' + esc(TX.previewOk) + '</p><h2 class="ph2">' + esc(TX.modeH) + '</h2><div class="pmode">' +
      ['free', 'paid'].map(function (m) { return '<label class="pm' + (st.mode === m ? ' on' : '') + '"><input type="radio" name="p-mode" value="' + m + '"' + (st.mode === m ? ' checked' : '') + '><b>' + esc(TX[m]) + '</b><small>' + esc(TX[m + 'P']) + '</small></label>'; }).join('') + '</div>' +
      '<label class="pchk"><input type="checkbox" id="p-consent"' + (st.consent ? ' checked' : '') + '><span>' + esc(TX.consent) + '</span></label>' +
      '<button class="btn pri big" type="button" id="p-submit"' + (st.busy ? ' disabled' : '') + '>' + esc(st.busy === 'submit' ? TX.sending : TX.submit) + '</button>' + msgs() + '</div>';
  }
  function viewDone() {
    return '<div class="sbox pbox"><h2 class="ph2">' + esc(TX.doneH) + '</h2><p class="hint">' + esc(TX.doneP) + '</p><button class="btn gl" type="button" id="p-another">' + esc(TX.another) + '</button></div>';
  }
  function viewWallet() {
    var w = st.wallet; if (!w || !(w.total || w.withdrawals.length || st.items.some(function (x) { return x.status === 'published'; }))) return '';
    var n = function (v) { return String(v).replace(/\B(?=(\d{3})+(?!\d))/g, ' '); };
    var f = st.wform || '';
    var form = f === 'conv' ? '<div class="pform"><label>' + esc(TX.wAmount) + '<input id="w-n" class="pin" type="number" min="1" max="' + w.available + '" value="' + Math.min(w.available, 50) + '"></label><button class="btn pri sm" type="button" id="w-conv-go"' + (st.busy ? ' disabled' : '') + '>' + esc(TX.wDo) + '</button></div>'
      : f === 'wd' ? '<div class="pform"><label>' + esc(TX.wMethod) + '<select id="w-m" class="pin"><option value="mobile"' + (st.wm !== 'card' ? ' selected' : '') + '>' + esc(TX.wMobile) + '</option><option value="card"' + (st.wm === 'card' ? ' selected' : '') + '>' + esc(TX.wCard) + '</option></select></label>' +
        '<label>' + esc(TX.wAmount) + '<input id="w-n" class="pin" type="number" min="1" max="' + w.available + '" value="' + (st.wn || (st.wm === 'card' ? w.limits.minCardCredits : w.limits.minMobileCredits)) + '"></label>' +
        '<label>' + esc(TX.wAccount) + '<input id="w-a" class="pin" type="text" maxlength="120" value="' + esc(st.wa || '') + '"></label><label>' + esc(TX.wName) + '<input id="w-nm" class="pin" type="text" maxlength="80" value="' + esc(st.wnm || '') + '"></label>' +
        '<button class="btn pri sm" type="button" id="w-wd-go"' + (st.busy ? ' disabled' : '') + '>' + esc(TX.wDo) + '</button></div>' : '';
    var hist = w.withdrawals.length ? '<h3 class="ph3">' + esc(TX.wHist) + '</h3><ul class="plist">' + w.withdrawals.map(function (x) { return '<li class="pit"><div class="pin2"><b>' + n(x.credits) + ' · ' + n(x.xof) + ' F</b><small>' + esc(x.method === 'card' ? TX.wCard : TX.wMobile) + ' · ' + new Date(x.at).toLocaleDateString(L === 'en' ? 'en-GB' : 'fr-FR') + '</small><span class="pbadge ' + (x.status === 'paid' ? 'published' : x.status === 'refused' ? 'rejected' : 'pending') + '">' + esc(TX.wst[x.status] || x.status) + '</span>' + (x.reason ? '<small class="preason">' + esc(x.reason) + '</small>' : '') + '</div></li>'; }).join('') + '</ul>' : '';
    return '<div class="sbox pbox"><h2 class="ph2">' + esc(TX.walletH) + '</h2><div class="refnums"><div><b>' + n(w.available) + '</b><small>' + esc(TX.wAvail) + ' · ≈ ' + n(w.cash.availableXof) + ' F</small></div><div><b>' + n(w.pending) + '</b><small>' + esc(TX.wPend) + ' · ≈ ' + n(w.cash.pendingXof) + ' F</small></div><div><b>' + n(w.spent) + '</b><small>' + esc(TX.wSpent) + '</small></div></div>' +
      '<p class="hint">' + esc(TX.wRate(w.cash.rate)) + '. ' + esc(TX.wHold(w.holdDays)) + ' ' + esc(TX.wMin(w.limits)) + '</p>' + (w.frozen ? '<p class="fmsg err">' + esc(TX.wFrozen) + '</p>' : '<div class="acts"><button class="btn gl sm" type="button" id="w-conv"' + (w.available ? '' : ' disabled') + '>' + esc(TX.wConv) + '</button><button class="btn pri sm" type="button" id="w-wd"' + (w.available ? '' : ' disabled') + '>' + esc(TX.wWd) + '</button></div>') + form + msgs() + hist + '</div>';
  }
  function viewList() {
    var rows = st.items.length ? st.items.map(function (x) {
      return '<li class="pit"><div class="pth">' + (x.thumb ? '<img src="' + esc(x.thumb) + '" alt="">' : '') + '</div><div class="pin2"><b>' + esc(title(x)) + '</b><small>' + esc(x.catLabel) + (x.mode ? ' · ' + (x.mode === 'paid' ? window.saIcon('lock') + ' ' : '') + esc(TX.modeL[x.mode]) : '') + '</small><span class="pbadge ' + esc(x.status) + '">' + esc(TX.st[x.status] || x.status) + '</span>' +
        (x.reason && (x.status === 'rejected' || x.status === 'suspended') ? '<small class="preason">' + esc(TX.reason) + ' : ' + esc(x.reason) + '</small>' : '') +
        (x.status === 'published' ? '<small>' + esc(TX.usesN(x.uses || 0)) + (x.people ? ' · ' + esc(TX.peopleN(x.people)) : '') + (x.mode === 'paid' ? ' · ' + esc(TX.earnedN(x.earned || 0)) : '') + '</small>' : '') + '<div class="pbtns">' + (x.status === 'published' ? '<a class="btn gl sm" href="' + cmdUrl(x.id) + '">' + esc(TX.view) + '</a><button class="btn gl sm" type="button" data-share="' + esc(x.id) + '">' + esc(TX.shareL) + '</button>' : '') + (x.status === 'draft' ? '<button class="btn gl sm" type="button" data-resume="' + esc(x.id) + '">' + esc(TX.resume) + '</button>' : '') + (x.status === 'draft' || x.status === 'rejected' ? '<button class="btn gl sm" type="button" data-del="' + esc(x.id) + '">' + esc(TX.del) + '</button>' : '') + '</div></div></li>';
    }).join('') : '<li class="none">' + esc(TX.none) + '</li>';
    var pubs = st.items.filter(function (x) { return x.status === 'published'; }), tot = pubs.reduce(function (n, x) { return n + (x.uses || 0); }, 0);
    var sum = pubs.length ? '<div class="refnums"><div><b>' + pubs.length + '</b><small>' + esc(TX.sumCmds) + '</small></div><div><b>' + tot + '</b><small>' + esc(TX.sumUses) + '</small></div></div>' + (st.prof && st.prof.handle ? '<p><a class="btn gl sm" href="' + (L === 'en' ? '/en/creator/' : '/createur/') + esc(st.prof.handle) + '/">' + esc(TX.myProfile) + '</a></p>' : '') : '';
    return '<h2 class="refh" id="mes-commandes">' + esc(TX.mineH) + '</h2>' + sum + '<ul class="plist">' + rows + '</ul>';
  }

  function render() {
    if (st.checking) { root.innerHTML = '<div class="sbox sload"><span class="spin" aria-label="…"></span></div>'; return; }
    if (!st.user) { root.innerHTML = '<div class="sbox"><h2 class="ph2">' + esc(TX.loginH) + '</h2><p class="hint">' + esc(TX.loginP) + '</p><button class="btn pri big" type="button" data-login>' + esc(TX.login) + '</button><p class="fmsg" id="auth-msg" role="status" aria-live="polite"></p></div>'; return; }
    if (!st.prof) { root.innerHTML = '<div class="sbox sload"><span class="spin" aria-label="…"></span></div>' + (st.err ? '<p class="fmsg err">' + esc(st.err) + '</p>' : ''); return; }
    var head = st.prof.handle ? '<p class="pwho">' + esc(TX.yourHandle) + ' : <b>@' + esc(st.prof.handle) + '</b>' + (st.prof.canChangeAt > Date.now() ? '' : '') + '</p>' : '';
    var main = !st.prof.handle ? viewHandle() : st.done ? viewDone() : st.step === 1 ? viewStep1() : st.step === 2 ? viewStep2() : viewStep3();
    var keepFocus = document.activeElement && document.activeElement.id;
    root.innerHTML = head + main + (st.prof.handle ? viewWallet() : '') + viewList();
    bind();
    if (keepFocus) { var el = document.getElementById(keepFocus); if (el && el.tagName !== 'BUTTON' && el.type !== 'file') { try { el.focus(); var v = el.value; if (v != null && el.setSelectionRange) el.setSelectionRange(v.length, v.length); } catch (e) {} } }
  }

  function readPhoto(file) {
    return new Promise(function (ok, ko) {
      if (!/^image\//.test(file.type)) return ko({ code: 'bad_photo' });
      var fr = new FileReader();
      fr.onerror = function () { ko({ code: 'bad_photo' }); };
      fr.onload = function () {
        var im = new Image();
        im.onerror = function () { ko({ code: 'bad_photo' }); };
        im.onload = function () {
          var k = Math.min(1, 1280 / Math.max(im.width, im.height)), w = Math.round(im.width * k), h = Math.round(im.height * k), cv = document.createElement('canvas');
          cv.width = w; cv.height = h; cv.getContext('2d').drawImage(im, 0, 0, w, h);
          var url = cv.toDataURL('image/jpeg', 0.88);
          ok({ mime: 'image/jpeg', data: url.split(',')[1], url: url });
        };
        im.src = fr.result;
      };
      fr.readAsDataURL(file);
    });
  }
  var hTimer = null;
  function bind() {
    var q = function (id) { return document.getElementById(id); };
    var on = function (id, fn) { var el = q(id); if (el) el.onclick = fn; };
    var h = q('p-handle');
    if (h) h.oninput = function () {
      st.handleIn = h.value.trim().toLowerCase().replace(/^@/, ''); st.handleOk = null; clearTimeout(hTimer);
      var s = q('p-hsave'); if (s) s.disabled = true; var m = q('p-hmsg'); if (m) { m.textContent = ''; m.className = 'fmsg'; }
      if (st.handleIn.length < 3) return;
      hTimer = setTimeout(function () {
        var want = st.handleIn;
        api('handle-check', { handle: want }).then(function (r) { if (want !== st.handleIn) return; st.handleOk = !!r.available; st.handleWhy = r.reason || 'handle_taken'; var m2 = q('p-hmsg'), s2 = q('p-hsave'); if (m2) { m2.textContent = r.available ? TX.handleOk + ' ✓' : errTxt(st.handleWhy); m2.className = 'fmsg' + (r.available ? '' : ' err'); } if (s2) s2.disabled = !r.available; }).catch(function () {});
      }, 350);
    };
    on('p-hsave', function () { st.busy = 'handle'; st.err = ''; api('handle', { handle: st.handleIn }).then(function (p) { st.prof = p; st.busy = ''; render(); }).catch(function (e) { st.handleOk = false; st.handleWhy = e && e.code; fail(e); }); });
    var b = q('p-brief'); if (b) b.oninput = function () { st.brief = b.value; };
    Array.prototype.forEach.call(root.querySelectorAll('[data-ex]'), function (c) { c.onclick = function () { st.brief = TX.ex[+c.dataset.ex]; render(); }; });
    on('p-analyze', function () {
      if ((st.brief || '').trim().length < 25) { st.err = TX.min; render(); return; }
      st.busy = 'analyze'; st.err = ''; st.msg = ''; render();
      api('analyze', { brief: st.brief, lang: L }).then(function (r) {
        st.busy = '';
        if (!r.allowed) { st.err = r.message || errTxt('ai_format'); render(); return; }
        st.draft = r.draft; st.step = 2; st.photo = null; st.result = null; st.err = ''; loadAll();
      }).catch(fail);
    });
    var ph = q('p-photo'); if (ph) ph.onchange = function () { var f = ph.files && ph.files[0]; if (!f) return; readPhoto(f).then(function (p) { st.photo = p; st.err = ''; render(); }).catch(fail); };
    var pr = q('p-product'); if (pr) pr.oninput = function () { st.product = pr.value; };
    var tb = q('p-test'); if (tb) tb.onclick = function () {
      if (st.draft.kind !== 'free' && !st.photo) { st.err = TX.needPhoto; render(); return; }
      st.busy = 'test'; st.err = ''; st.msg = ''; var keep = st.result; render();
      api('test', { id: st.draft.id, lang: L, product: st.product, photos: st.photo ? [{ mime: st.photo.mime, data: st.photo.data }] : [] }).then(function (r) {
        st.busy = ''; st.result = { image: r.image, mime: r.mime, genId: r.genId }; st.prof.credits = r.credits; st.draft.tests = r.tests; render();
      }).catch(function (e) { st.result = keep; fail(e); });
    };
    on('p-good', function () {
      st.busy = 'good'; render();
      api('approve-render', { id: st.draft.id, genId: st.result.genId }).then(function () { st.busy = ''; st.draft.hasPreview = true; st.step = 3; st.result = null; st.err = ''; loadAll(); }).catch(fail);
    });
    on('p-next', function () { st.step = 3; st.err = ''; render(); });
    on('p-edit', function () { st.brief = st.brief || ''; st.step = 1; st.err = ''; st.result = null; render(); });
    Array.prototype.forEach.call(root.querySelectorAll('input[name="p-mode"]'), function (r) { r.onchange = function () { st.mode = r.value; render(); }; });
    var cs = q('p-consent'); if (cs) cs.onchange = function () { st.consent = cs.checked; };
    on('p-submit', function () {
      if (!st.consent) { st.err = errTxt('consent_required'); render(); return; }
      st.busy = 'submit'; st.err = ''; render();
      api('submit', { id: st.draft.id, mode: st.mode, consent: true }).then(function () { st.busy = ''; st.done = true; st.draft = null; st.consent = false; st.brief = ''; loadAll(); }).catch(fail);
    });
    on('p-another', function () { st.done = false; st.step = 1; st.draft = null; st.photo = null; st.result = null; render(); });
    Array.prototype.forEach.call(root.querySelectorAll('[data-resume]'), function (btn) { btn.onclick = function () {
      var it = st.items.filter(function (x) { return x.id === btn.dataset.resume; })[0]; if (!it) return;
      st.draft = it; st.step = it.hasPreview ? 3 : 2; st.done = false; st.photo = null; st.result = null; st.err = ''; render(); window.scrollTo({ top: root.offsetTop - 80, behavior: 'smooth' });
    }; });
    on('w-conv', function () { st.wform = st.wform === 'conv' ? '' : 'conv'; st.err = ''; st.msg = ''; render(); });
    on('w-wd', function () { st.wform = st.wform === 'wd' ? '' : 'wd'; st.err = ''; st.msg = ''; render(); });
    var wm = q('w-m'); if (wm) wm.onchange = function () { st.wm = wm.value; st.wn = ''; st.wa = (q('w-a') || {}).value; st.wnm = (q('w-nm') || {}).value; render(); };
    on('w-conv-go', function () {
      st.busy = 'conv'; st.err = ''; render();
      api('convert', { credits: +q('w-n').value }).then(function () { st.busy = ''; st.wform = ''; st.msg = TX.wDone; loadAll(); }).catch(fail);
    });
    on('w-wd-go', function () {
      st.wn = q('w-n').value; st.wa = q('w-a').value; st.wnm = q('w-nm').value; st.wm = q('w-m').value;
      st.busy = 'wd'; st.err = ''; render();
      api('withdraw', { method: st.wm, credits: +st.wn, account: st.wa, name: st.wnm }).then(function () { st.busy = ''; st.wform = ''; st.msg = TX.wDone; loadAll(); }).catch(fail);
    });
    Array.prototype.forEach.call(root.querySelectorAll('[data-share]'), function (btn) { btn.onclick = function () {
      var url = 'https://slashatlas.com' + cmdUrl(btn.dataset.share), done = function () { btn.textContent = TX.linkCopied; setTimeout(function () { btn.textContent = TX.shareL; }, 1800); };
      if (navigator.share) navigator.share({ title: 'SlashAtlas', url: url }).catch(function () {}); else try { navigator.clipboard.writeText(url).then(done); } catch (e) {}
    }; });
    Array.prototype.forEach.call(root.querySelectorAll('[data-del]'), function (btn) { btn.onclick = function () {
      if (!window.confirm(TX.confirmDel)) return;
      api('remove', { id: btn.dataset.del }).then(function () { if (st.draft && st.draft.id === btn.dataset.del) { st.draft = null; st.step = 1; } loadAll(); }).catch(fail);
    }; });
  }

  // Partager l'opportunité : un seul lien, l'aperçu (image, titre, explication) fait le reste
  var refCode = '';
  var shareUrl = function () { return 'https://slashatlas.com' + location.pathname + (refCode ? '?ref=' + refCode : ''); };
  var shBtn = document.getElementById('earn-share'), waBtn = document.getElementById('earn-wa');
  var shMsg = function () { var b = shBtn && shBtn.parentNode; return (b && b.dataset.msg) || ''; };
  if (waBtn) waBtn.addEventListener('click', function () { waBtn.href = 'https://wa.me/?text=' + encodeURIComponent(shMsg() + '\n' + shareUrl()); });
  if (shBtn) shBtn.addEventListener('click', function () {
    var url = shareUrl(), msg = shMsg();
    if (navigator.share) { navigator.share({ title: document.title, text: msg, url: url }).catch(function () {}); return; }
    var done = function () { var l0 = shBtn.textContent; shBtn.textContent = L === 'en' ? 'Link copied ✓' : 'Lien copié ✓'; setTimeout(function () { shBtn.textContent = l0; }, 1800); };
    try { navigator.clipboard.writeText(msg + '\n' + url).then(done, function () { window.prompt('', url); }); } catch (e) { window.prompt('', url); }
  });

  import('/js/auth.js');
  document.addEventListener('sa:auth', function (e) {
    if (e.detail.user && window.slashAuth) window.slashAuth.call('referrals').then(function (r) { if (r.status === 200 && r.data && r.data.code) refCode = r.data.code; }).catch(function () {});
    st.user = e.detail.user; st.checking = false; st.prof = null; st.err = '';
    var hw = document.getElementById('howto'); if (hw) hw.open = !st.user; // connecté : les explications se replient, l'action reste en haut
    render();
    if (st.user) loadAll().then(function () { if (location.hash === '#mes-commandes') { var h = document.getElementById('mes-commandes'); if (h) h.scrollIntoView(); } });
  });
  render();
})();
