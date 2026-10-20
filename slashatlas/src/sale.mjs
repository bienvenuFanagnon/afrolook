// Commandes qui servent à VENDRE quelque chose (produit, tenue, plat, bien) : le rendu final peut porter À VENDRE, prix, réduction, marque, contact et petit QR code.
// Mêmes règles pour le site (exemples, cases du Studio, commande copiée) et les scripts d'images.
export const SALE_CATS = ['mode', 'produit', 'beaute', 'bijoux', 'tech', 'auto', 'maison', 'packaging', 'food', 'immobilier', 'sante'];
export const SALE_KINDS = ['product', 'dish', 'place', 'person'];
// une personne sur la photo ne compte que pour la mode et la beauté (tenues et soins vendus), pas pour les autres catégories
export function isSale(c) {
  if (!c || !SALE_CATS.includes(c.cat)) return false;
  const k = c.kind || 'product';
  if (!SALE_KINDS.includes(k)) return false;
  if (k === 'person' && !['mode', 'beaute'].includes(c.cat)) return false;
  if (k === 'place' && c.cat !== 'immobilier') return false;
  return true;
}
