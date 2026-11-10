// Barre « Administration » commune aux deux pages réservées à l'équipe : le tableau de bord (/admin/) et la régie publicitaire (/ads/admin/).
// Même barre, mêmes libellés, même place : on passe de l'une à l'autre sans chercher. La page active est marquée (aria-current).
export const adminNav = (active) => {
  const L = [['dash', '/admin/', 'Tableau de bord'], ['regie', '/ads/admin/', 'Régie publicitaire']];
  return `<nav class="admnav" aria-label="Administration"><div class="wrap">${L.map(([k, h, l]) => `<a href="${h}"${k === active ? ' aria-current="page"' : ''}>${l}</a>`).join('')}<span class="sp"></span><a class="out" href="/">Retour au site</a></div></nav>`;
};
