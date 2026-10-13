(function () {
  'use strict';
  var L = (document.body && document.body.dataset.lang) || 'fr';
  var fr = L !== 'en';
  var IOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
  var AND = /Android/.test(navigator.userAgent);
  var STORE_IOS = 'https://apps.apple.com/app/afrolook/id6740918963';
  var STORE_AND = 'https://play.google.com/store/apps/details?id=com.afrolook.afrolook';

  var PHOTOS = [
    '/img/afl/intro1.jpg', '/img/afl/intro2.jpg', '/img/afl/intro3.jpg',
    '/img/afl/intro4.jpg', '/img/afl/intro5.jpg', '/img/afl/intro6.jpg', '/img/afl/intro7.jpg'
  ];

  var MFR = [
    'Tu postes des vidéos ? Afrolook te paie tes vues',
    'Des vues sur TikTok sans rémunération ? Essaie Afrolook',
    'Instagram ne te paie pas tes vues. Afrolook, oui.',
    'Chaque vue sur Afrolook = une pièce de plus',
    'Monétisation sans seuil, dès ta première vue. Gratuit.',
    'Chacune de tes vues a de la valeur sur Afrolook',
    'Afrolook transforme tes vues en revenus réels',
    'Tu postes sur Instagram. Tu gagnes sur Afrolook.',
    'Afrolook te paie dès tes premières vues',
    'Tu filmes déjà. Autant être payé pour ça.',
    'Toutes tes vues sur Afrolook = pièces dans ton portefeuille',
    'Poste comme sur TikTok. Gagne comme nulle part.',
    'Tes likes = de vraies pièces sur Afrolook',
    '100 likes sur Afrolook = 100 pièces dans ton compte',
    'Chaque like sur Afrolook = une pièce de plus',
    'Likes + vues = argent réel sur Afrolook',
    'Sur Afrolook, tes abonnés te font vraiment gagner',
    'Tes likes ne disparaissent pas. Ils deviennent tes gains.',
    'Afrolook : le réseau qui dit merci à tes likes',
    'Crée ta carte créateur sur Afrolook',
    'Ta carte Afrolook : ton identité de créateur, vendable',
    'Les créateurs pro ont une carte. La tienne est prête.',
    'Afrolook : crée et vends ta carte de créateur numérique',
    'Ta carte créateur Afrolook = ta marque personnelle',
    'Partage ta carte créateur. Développe ton audience.',
    'Afrolook : le réseau social qui paie ses créateurs',
    'Crée ton compte Afrolook. Commence à gagner.',
    'Rejoins des milliers de créateurs rémunérés',
    'Partage. Crée. Gagne. C’est Afrolook.',
    'Afrolook, c’est TikTok mais tes vues sont payées.',
    'Instagram, TikTok : tes vues ne t’enrichissent pas. Afrolook, si.',
    'Créateur de contenu ? Afrolook est fait pour toi.',
    'Afrolook : monétise ton contenu dès le premier jour',
    'Télécharge Afrolook. Poste. Encaisse.',
    'Rejoins Afrolook et transforme ta créativité en argent',
    'Sur Afrolook, chaque création vaut quelque chose',
    'Ton talent mérite d’être rémunéré. C’est Afrolook.',
    'Commence à monétiser sur Afrolook dès aujourd’hui',
    'Afrolook : le réseau africain des créateurs',
    'Exprime-toi. Monétise. Grandis. Sur Afrolook.',
    'Ta créativité a une valeur. Afrolook te la paie.',
    'Rejoins la communauté Afrolook et commence à gagner',
    'Afrolook : crée, partage et gagne de l’argent réel',
    'Sur Afrolook, vues, likes et cartes = revenus',
    'Afrolook récompense chaque créateur',
    'Poste tes vidéos sur Afrolook. Tes vues te paient.',
    'Sois payé pour ce que tu crées. Télécharge Afrolook.',
    'Afrolook : plus qu’un réseau, une source de revenus',
    'Créateur débutant ou pro ? Afrolook te rémunère.',
    'Sur Afrolook, tes followers valent de l’argent.',
    'Lance-toi sur Afrolook : zéro abonné requis',
    'Afrolook : la monétisation accessible à tous',
    'Tes vidéos ont de la valeur. Rejoins Afrolook.',
    'Afrolook : vues + likes + cartes = pièces dans ton compte',
    'Monétise sur Afrolook. Pas de minimum requis.',
    'Afrolook : le réseau social où créer, c’est gagner',
    'Afrolook : la plateforme africaine des créateurs',
    'Sois payé pour tes vues. Télécharge Afrolook.'
  ];

  var MEN = [
    'Post videos? Afrolook pays you for every view',
    'Views on TikTok with nothing? Try Afrolook',
    "Instagram doesn't pay your views. Afrolook does.",
    'Every view on Afrolook = one more coin',
    'Earn from day one, no threshold. Free to join.',
    'Every single view is worth something on Afrolook',
    'Afrolook turns your views into real income',
    'Post on Instagram. Earn on Afrolook.',
    'Afrolook pays you from your very first views',
    "You're already filming. Might as well get paid.",
    'All your views on Afrolook = coins in your wallet',
    'Post like TikTok. Earn like nowhere else.',
    'Your likes = real coins on Afrolook',
    '100 likes on Afrolook = 100 coins in your account',
    'Every like on Afrolook = one more coin',
    'Likes + views = real money on Afrolook',
    'On Afrolook, your followers actually make you money',
    "Your likes don't disappear. They become earnings.",
    'Afrolook: the network that rewards your likes',
    'Create your creator card on Afrolook',
    'Your Afrolook card: your creator identity, sellable',
    'Pro creators have a card. Yours is ready.',
    'Afrolook: create and sell your digital creator card',
    'Your Afrolook creator card = your personal brand',
    'Share your creator card. Grow your audience.',
    'Afrolook: the social network that pays its creators',
    'Create your Afrolook account. Start earning.',
    'Join thousands of paid creators',
    "Share. Create. Earn. That's Afrolook.",
    'Afrolook is like TikTok, but your views are paid.',
    "Instagram, TikTok: your views don't pay you. Afrolook does.",
    'Content creator? Afrolook is made for you.',
    'Afrolook: monetize your content from day one',
    'Download Afrolook. Post. Cash out.',
    'Join Afrolook and turn your creativity into money',
    'On Afrolook, every creation is worth something',
    "Your talent deserves to be paid. That's Afrolook.",
    'Start monetizing on Afrolook today',
    'Afrolook: the African network for creators',
    'Express yourself. Monetize. Grow. On Afrolook.',
    'Your creativity has value. Afrolook pays you for it.',
    'Join the Afrolook community and start earning',
    'Afrolook: create, share and earn real money',
    'On Afrolook, views, likes and cards = revenue',
    'Afrolook rewards every creator',
    'Post your videos on Afrolook. Your views pay you.',
    'Get paid for what you create. Download Afrolook.',
    'Afrolook: more than a network, a source of income',
    'Beginner or pro creator? Afrolook pays you.',
    'On Afrolook, your followers are worth money.',
    'Start on Afrolook: zero followers needed',
    'Afrolook: monetization accessible to all',
    'Your videos have value. Join Afrolook.',
    'Afrolook: views + likes + cards = coins in your account',
    'Monetize on Afrolook. No minimum required.',
    'Afrolook: the social network where creating means earning',
    'Afrolook: the African platform for creators',
    'Get paid for your views. Download Afrolook.'
  ];

  var _idx = Math.floor(Math.random() * MFR.length);
  function nextMsg(isFr) { _idx = (_idx + 1) % MFR.length; return (isFr ? MFR : MEN)[_idx]; }
  function pickPhoto() { return PHOTOS[Math.floor(Math.random() * PHOTOS.length)]; }
  function storeUrl() { return IOS ? STORE_IOS : STORE_AND; }
  function ctaTxt(isFr) { return isFr ? 'Télécharger Afrolook' : 'Download Afrolook'; }
  function track(fmt, type) { try { window.saTrack && window.saTrack('afl_' + type, { fmt: fmt }); } catch (e) {} }

  function buildRect(isFr) {
    var msg = nextMsg(isFr), photo = pickPhoto(), url = storeUrl();
    return '<a class="afl-banner afl-rect" href="' + url + '" target="_blank" rel="noopener sponsored" data-afl="rect">' +
      '<span class="afl-spon">' + (isFr ? 'Sponsorisé' : 'Sponsored') + '</span>' +
      '<div class="afl-r-img" style="background-image:url(' + photo + ')"></div>' +
      '<div class="afl-r-body">' +
        '<span class="afl-badge">Afrolook</span>' +
        '<p class="afl-msg">' + msg + '</p>' +
        '<span class="afl-cta">' + ctaTxt(isFr) + '</span>' +
      '</div>' +
    '</a>';
  }

  function buildLb(isFr) {
    var msg = nextMsg(isFr), photo = pickPhoto(), url = storeUrl();
    return '<a class="afl-banner afl-lb" href="' + url + '" target="_blank" rel="noopener sponsored" data-afl="lb">' +
      '<span class="afl-spon">' + (isFr ? 'Sponsorisé' : 'Sponsored') + '</span>' +
      '<div class="afl-lb-img" style="background-image:url(' + photo + ')"></div>' +
      '<div class="afl-lb-body">' +
        '<span class="afl-badge">Afrolook</span>' +
        '<p class="afl-msg">' + msg + '</p>' +
      '</div>' +
      '<span class="afl-cta afl-cta-lb">' + ctaTxt(isFr) + '</span>' +
    '</a>';
  }

  function buildLoad(isFr) {
    var msg = nextMsg(isFr), photo = pickPhoto(), url = storeUrl();
    return '<a class="afl-banner afl-load" href="' + url + '" target="_blank" rel="noopener sponsored" data-afl="load">' +
      '<div class="afl-l-img" style="background-image:url(' + photo + ')"></div>' +
      '<div class="afl-l-body">' +
        '<span class="afl-badge afl-badge-sm">' + (isFr ? 'Afrolook · Publicité' : 'Afrolook · Ad') + '</span>' +
        '<p class="afl-msg afl-msg-sm">' + msg + '</p>' +
        '<span class="afl-cta afl-cta-sm">' + ctaTxt(isFr) + ' →</span>' +
      '</div>' +
    '</a>';
  }

  function renderIn(el, buildFn) {
    el.innerHTML = buildFn(fr);
    el.hidden = false;
    var a = el.querySelector('[data-afl]');
    if (a) {
      var fmt = a.dataset.afl;
      track(fmt, 'imp');
      a.addEventListener('click', function () { track(fmt, 'click'); }, { once: true });
    }
  }

  window.saAfrolookAds = {
    fill: function (el) {
      var fmt = el.dataset.ad;
      renderIn(el, fmt === 'lb' ? buildLb : buildRect);
    }
  };

  // Bannière pendant la génération : surveille #s-gen.loading
  (function () {
    var genBtn = document.getElementById('s-gen');
    var slot = document.getElementById('afl-gen-ad');
    if (!genBtn || !slot) return;
    var shown = false;
    var observer = new MutationObserver(function () {
      var busy = genBtn.classList.contains('loading');
      if (busy && !shown) {
        renderIn(slot, buildLoad);
        shown = true;
      } else if (!busy && shown) {
        slot.hidden = true;
        slot.innerHTML = '';
        shown = false;
      }
    });
    observer.observe(genBtn, { attributes: true, attributeFilter: ['class'] });
  })();
})();
