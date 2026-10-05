/**
 * Région du joueur d'après son pays (code ISO à 2 lettres) : elle décide du jeu de niveaux qu'il reçoit
 * (af Afrique, eu Europe, as Asie et Océanie, am Amériques). Pays inconnu : « mx », un mélange de toutes les régions.
 */
export type QuizRegion = "af" | "eu" | "as" | "am" | "mx";

const LISTS: Record<Exclude<QuizRegion, "mx">, string> = {
  af: "DZ AO BJ BW BF BI CV CM CF TD KM CG CD CI DJ EG GQ ER SZ ET GA GM GH GN GW KE LS LR LY MG MW ML MR MU MA MZ NA NE NG RW ST SN SC SL SO ZA SS SD TZ TG TN UG ZM ZW EH RE YT",
  eu: "AL AD AT BY BE BA BG HR CY CZ DK EE FI FR DE GR HU IS IE IT XK LV LI LT LU MT MD MC ME NL MK NO PL PT RO RU SM RS SK SI ES SE CH UA GB VA GI GG JE IM FO AX",
  as: "AF AM AZ BH BD BT BN KH CN GE HK IN ID IR IQ IL JP JO KZ KW KG LA LB MO MY MV MN MM NP KP OM PK PS PH QA SA SG KR LK SY TW TJ TH TL TR TM AE UZ VN YE AU NZ FJ PG SB VU WS TO KI FM MH PW NR TV PF NC GU CK NU",
  am: "AG AR BS BB BZ BO BR CA CL CO CR CU DM DO EC SV GD GT GY HT HN JM MX NI PA PY PE KN LC VC SR TT US UY VE PR GL GP MQ GF BL MF AW CW SX BM KY VG VI TC AI MS",
};

const MAP: Record<string, QuizRegion> = {};
(Object.keys(LISTS) as Exclude<QuizRegion, "mx">[]).forEach((r) => LISTS[r].split(" ").forEach((c) => { MAP[c] = r; }));

export function regionOf(country: string | undefined | null): QuizRegion {
  return MAP[String(country ?? "").trim().toUpperCase()] ?? "mx";
}
