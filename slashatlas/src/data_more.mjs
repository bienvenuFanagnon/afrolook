// Commandes supplémentaires (étape 1 : 25 par catégorie). Chaque ligne décrit une idée de visuel ; la commande complète est composée ici
// à partir d'une trame par type de sujet (produit, plat, personne, lieu) : la partie créative (« scène ») est écrite à la main.
import mode from './cmds/mode.mjs';
import produit from './cmds/produit.mjs';
import food from './cmds/food.mjs';
import immobilier from './cmds/immobilier.mjs';
import sport from './cmds/sport.mjs';
import musique from './cmds/musique.mjs';
import reseaux from './cmds/reseaux.mjs';
import evenement from './cmds/evenement.mjs';
import beaute from './cmds/beaute.mjs';
import effets from './cmds/effets.mjs';
import video from './cmds/video.mjs';
import tech from './cmds/tech.mjs';
import auto from './cmds/auto.mjs';
import bijoux from './cmds/bijoux.mjs';
import maison from './cmds/maison.mjs';
import education from './cmds/education.mjs';
import sante from './cmds/sante.mjs';
import voyage from './cmds/voyage.mjs';
import business from './cmds/business.mjs';
import packaging from './cmds/packaging.mjs';
import typo from './cmds/typo.mjs';
import logomat from './cmds/logomat.mjs';
import planches from './cmds/planches.mjs';
import infographie from './cmds/infographie.mjs';
import diorama from './cmds/diorama.mjs';
import anime from './cmds/anime.mjs';
import marque from './cmds/marque.mjs';
import editorial from './cmds/editorial.mjs';
import jalons from './cmds/jalons.mjs';
import magazine from './cmds/magazine.mjs';
import ecom from './cmds/ecom.mjs';
import mascotte from './cmds/mascotte.mjs';
import motion from './cmds/motion.mjs';
import kit from './cmds/kit.mjs';
import mise_en_scene from './cmds/mise_en_scene.mjs';
import femmes from './cmds/femmes.mjs';

const FILES0 = { mode, produit, food, immobilier, sport, musique, reseaux, evenement, beaute, effets, video, tech, auto, bijoux, maison, education, sante, voyage, business, packaging, typo, logomat, planches, infographie, diorama, anime, marque, editorial, jalons, magazine, ecom, mascotte, motion, kit, affiches: mise_en_scene };
// commandes « produits que les femmes vendent le plus » placées en tête de leur catégorie
const FILES = Object.fromEntries(Object.entries(FILES0).map(([cat, rows]) => [cat, [...(femmes[cat] || []), ...rows]]));
const FMT = {
  fr: { '4:5': 'vertical 4:5', '1:1': 'carré 1:1', '3:2': 'paysage 3:2', '9:16': 'vertical 9:16', '16:9': 'paysage 16:9', '3:4': 'vertical 3:4', 'texte': 'texte' },
  en: { '4:5': 'vertical 4:5', '1:1': 'square 1:1', '3:2': 'landscape 3:2', '9:16': 'vertical 9:16', '16:9': 'landscape 16:9', '3:4': 'vertical 3:4', 'texte': 'text' },
};
const FRAME = {
  fr: {
    product: (s, f) => `Avec le ou les produits de la photo jointe, crée ${s} Format ${f}. Chaque produit reste parfaitement identique (forme, couleurs, logo, étiquette). Aucun texte ajouté.`,
    dish: (s, f) => `Avec le ou les plats de la photo jointe, crée ${s} Format ${f}. Les plats restent fidèles à la photo, sans ingrédient ni texte ajouté.`,
    person: (s, f) => `À partir de la photo jointe, crée ${s} Format ${f}. La ou les personnes restent identiques (visage, tenue, proportions). Aucun texte ni logo ajouté.`,
    place: (s, f) => `À partir de la photo jointe du bien ou du lieu, crée ${s} Format ${f}. L’architecture et les dimensions restent identiques. Aucun texte ajouté.`,
    poster: (s, f) => `À partir de la photo jointe, crée ${s} Format ${f}. Le sujet de la photo reste identique (forme, couleurs, visage, tenue). Les textes entre guillemets sont écrits exactement tels quels, bien lisibles et sans faute : remplacez-les par les vôtres.`,
    logo: (s, f) => `Avec le logo joint, crée ${s} Format ${f}. Le logo garde exactement sa forme, ses proportions et ses couleurs d’origine. Aucun autre texte ajouté.`,
    free: (s, f) => `Crée ${s} Format ${f}. Remplacez les mots entre crochets par votre sujet.`,
    video: (s, f) => `Avec la photo jointe du produit comme image de départ, crée une vidéo publicitaire : ${s} Format ${f}. Le produit reste parfaitement identique (forme, couleurs, logo, étiquette). Aucun texte ajouté.`,
    motion: (s, f) => `Crée une vidéo de motion design de 6 à 8 secondes : ${s} Format ${f}. Si une image est jointe (logo, photo), elle garde exactement sa forme et ses couleurs. Les textes entre guillemets sont écrits exactement tels quels, bien lisibles et sans faute : remplacez-les par les vôtres. Mouvements fluides, sans coupure brusque.`,
    text: (s) => s,
  },
  en: {
    product: (s, f) => `With the product(s) in the attached photo, create ${s} ${f} format. Each product stays perfectly identical (shape, colors, logo, label). No added text.`,
    dish: (s, f) => `With the dish(es) in the attached photo, create ${s} ${f} format. The dishes stay faithful to the photo, no added ingredient or text.`,
    person: (s, f) => `From the attached photo, create ${s} ${f} format. The person or people stay identical (face, outfit, proportions). No added text or logo.`,
    place: (s, f) => `From the attached photo of the property or place, create ${s} ${f} format. The architecture and dimensions stay identical. No added text.`,
    poster: (s, f) => `From the attached photo, create ${s} ${f} format. The subject of the photo stays identical (shape, colors, face, outfit). Texts in quotation marks are written exactly as given, clearly legible and without errors: replace them with your own.`,
    logo: (s, f) => `Using the attached logo, create ${s} ${f} format. The logo keeps exactly its original shape, proportions and colors. No other text added.`,
    free: (s, f) => `Create ${s} ${f} format. Replace the words in square brackets with your own subject.`,
    video: (s, f) => `Using the attached product photo as the starting frame, create an advertising video: ${s} ${f} format. The product stays perfectly identical (shape, colors, logo, label). No added text.`,
    motion: (s, f) => `Create a 6 to 8 second motion design video: ${s} ${f} format. If an image is attached (logo, photo), it keeps exactly its shape and colors. Texts in quotation marks are written exactly as given, clearly legible and without errors: replace them with your own. Smooth movements, no abrupt cuts.`,
    text: (s) => s,
  },
};
const hash = (s) => [...s].reduce((h, c) => (h * 31 + c.charCodeAt(0)) >>> 0, 7);

export const MORE = Object.entries(FILES).flatMap(([cat, rows]) => rows.map(([slug, kind, ratio, ft, fp, fd, fs, et, ep, ed, es, steps]) => {
  const h = hash(slug);
  return {
    slug, code: '/' + slug, cat, ratio, kind, noImage: true, scene: { fr: fs, en: es },
    steps: steps ? steps.map(([f, e]) => ({ fr: f, en: e })) : undefined,
    x: `${25 + (h % 50)}%`, y: `${25 + ((h >> 3) % 50)}%`, r: ['50%', '8%', '30%'][h % 3],
    fr: { title: ft, poster: fp, desc: fd, prompt: FRAME.fr[kind](fs, FMT.fr[ratio]) },
    en: { title: et, poster: ep, desc: ed, prompt: FRAME.en[kind](es, FMT.en[ratio]) },
  };
}));
