// Google Analytics 4 (Firebase) avec le mode de consentement Google v2.
// Espace économique européen, Royaume-Uni, Suisse : refusé par défaut (aucun cookie d'analyse) tant que le message Google ne donne pas l'accord.
// Ailleurs : analyse accordée, publicité refusée par défaut. Aucune mesure si « Ne pas suivre », pour les robots et pour l'administrateur connecté sur cet appareil.
(function () {
  var el = document.currentScript, ID = el && el.dataset.id; if (!ID) return;
  try {
    if (/bot|crawl|spider|headless|lighthouse|preview/i.test(navigator.userAgent) || navigator.doNotTrack === '1' || navigator.globalPrivacyControl === true) return;
    if (localStorage.getItem('sa_admin') === '1') return;
  } catch (e) {}
  window.dataLayer = window.dataLayer || [];
  function gtag() { window.dataLayer.push(arguments); }
  window.gtag = gtag;
  var EEA = ['AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE', 'IS', 'LI', 'NO', 'GB', 'CH'];
  gtag('consent', 'default', { ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied', analytics_storage: 'denied', region: EEA, wait_for_update: 500 });
  gtag('consent', 'default', { ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied', analytics_storage: 'granted' });
  gtag('js', new Date());
  gtag('config', ID, { language: document.documentElement.lang });
  var s = document.createElement('script'); s.async = true; s.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(ID); document.head.appendChild(s);
})();
