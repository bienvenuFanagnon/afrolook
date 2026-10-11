// Page « À propos et contact » : identifie l'éditeur et explique le site (utile aux visiteurs et à la validation AdSense).
export function aboutBody(l, g, n) {
  const mail = g.email ? `<a href="mailto:${g.email}">${g.email}</a>` : '';
  const id = [g.name, g.form, g.registration && (l === 'fr' ? 'Immatriculation ' : 'Registration ') + g.registration, g.address].filter(Boolean).join(' · ');
  if (l === 'fr') return {
    title: 'À propos et contact | SlashAtlas',
    desc: 'SlashAtlas aide les commerçants et créateurs à faire de belles affiches avec des commandes IA gratuites. Qui nous sommes, comment nous travaillons, comment nous écrire.',
    h: 'À propos de SlashAtlas',
    sections: [
      ['Notre but', [`SlashAtlas est une bibliothèque de ${n} commandes prêtes à copier pour créer des affiches et des visuels publicitaires avec une IA : produit, plat, boutique, événement, immobilier, mode, beauté, sport, musique et réseaux sociaux. Chaque commande existe en français et en anglais.`, 'Nous écrivons et testons chaque commande nous-mêmes sur de vraies photos. Les exemples « avant / après » du site sont générés avec la même commande que celle que vous copiez.']],
      ['Comment le site vit', ['Les commandes à copier sont gratuites. Le Studio permet de générer l’image directement sur le site avec des crédits payants (mobile money). Le site peut afficher de la publicité, qui contribue à son financement. Les pages de contenu ne mettent jamais une publicité près d’un bouton.']],
      ['Ce que nous ne faisons pas', ['Nous ne vendons pas vos photos, nous ne les conservons pas, et nous ne promettons pas de résultats identiques d’une génération à l’autre : c’est une IA. Voir les pages Confidentialité et Conditions.']],
      ['Nous contacter', [mail ? `Écrivez-nous à ${mail}. Nous répondons en général sous 48 heures ouvrées.` : 'Utilisez le formulaire d’inscription du site (liste d’attente) en laissant une note : nous répondons en général sous 48 heures ouvrées.', id ? `Éditeur : ${id}` : '']],
    ],
  };
  return {
    title: 'About and contact | SlashAtlas',
    desc: 'SlashAtlas helps shop owners and creators make great posters with free AI commands. Who we are, how we work and how to reach us.',
    h: 'About SlashAtlas',
    sections: [
      ['Our goal', [`SlashAtlas is a library of ${n} ready-to-copy commands to create posters and advertising visuals with AI: product, dish, shop, event, real estate, fashion, beauty, sport, music and social media. Every command exists in French and in English.`, 'We write and test every command ourselves on real photos. The “before / after” examples on the site are generated with the very command you copy.']],
      ['How the site is funded', ['Copy-ready commands are free. The Studio lets you generate the image right on the site with paid credits (mobile money). The site may show advertising, which helps fund it. Content pages never put an ad next to a button.']],
      ['What we do not do', ['We do not sell your photos, we do not keep them, and we do not promise identical results from one generation to the next: it is an AI. See the Privacy and Terms pages.']],
      ['Contact us', [mail ? `Write to us at ${mail}. We usually reply within 48 working hours.` : 'Use the site’s sign-up form (waiting list) and leave a note: we usually reply within 48 working hours.', id ? `Publisher: ${id}` : '']],
    ],
  };
}
