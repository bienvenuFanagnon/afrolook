#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère les 6 packs régionaux officiels (kind 'world') : 8 stickers WebP animés par région.

Réutilise gen_pack.py (sprites emoji Noto, mouvements, pastilles, encodage <= 600 Ko).
Sortie : <out>/{id}.webp + _thumb.webp, puis tools/stickers/regions_index.json.
Usage : python3 tools/stickers/gen_regions.py [--out DOSSIER] [--jobs N]
"""
import argparse
import json
import os
import sys
from multiprocessing import Pool
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gen_pack as g  # noqa: E402

INDEX = HERE / "regions_index.json"

# région -> (noms 8 langues, [(emoji, mouvement, couleur, fr, en, es, de, ar, pt, zh, sw)])
REGIONS = {
    "africa": ({
        "fr": "Afrique", "en": "Africa", "es": "África", "de": "Afrika", "ar": "أفريقيا",
        "pt": "África", "zh": "非洲", "sw": "Afrika"}, [
        ("🥁", "bounce", "violet", "Tam-tam", "Drum", "Tambor", "Trommel", "طبل", "Tambor", "鼓", "Ngoma"),
        ("🦁", "pulse", "coral", "Lion", "Lion", "León", "Löwe", "أسد", "Leão", "狮子", "Simba"),
        ("🌍", "turn", "teal", "Afrique", "Africa", "África", "Afrika", "أفريقيا", "África", "非洲", "Afrika"),
        ("🐘", "sway", "blue", "Éléphant", "Elephant", "Elefante", "Elefant", "فيل", "Elefante", "大象", "Tembo"),
        ("🥭", "jelly", "magenta", "Mangue", "Mango", "Mango", "Mango", "مانجو", "Manga", "芒果", "Embe"),
        ("🌴", "sway", "teal", "Palmier", "Palm tree", "Palmera", "Palme", "نخلة", "Palmeira", "棕榈树", "Mnazi"),
        ("💃", "dance", "pink", "Danse", "Dance", "Baile", "Tanz", "رقص", "Dança", "舞蹈", "Ngoma ya densi"),
        ("🍲", "float", "indigo", "Bon plat", "Tasty dish", "Buen plato", "Leckeres Gericht", "طبق لذيذ", "Prato saboroso", "美食", "Chakula kitamu"),
    ]),
    "caribbean": ({
        "fr": "Caraïbes", "en": "Caribbean", "es": "Caribe", "de": "Karibik", "ar": "الكاريبي",
        "pt": "Caribe", "zh": "加勒比", "sw": "Karibi"}, [
        ("🏝️", "float", "teal", "Île", "Island", "Isla", "Insel", "جزيرة", "Ilha", "海岛", "Kisiwa"),
        ("🥥", "bounce", "blue", "Noix de coco", "Coconut", "Coco", "Kokosnuss", "جوز الهند", "Coco", "椰子", "Nazi"),
        ("🍹", "sway", "coral", "Cocktail", "Cocktail", "Cóctel", "Cocktail", "كوكتيل", "Coquetel", "鸡尾酒", "Kokteli"),
        ("🐚", "pulse", "pink", "Coquillage", "Seashell", "Concha", "Muschel", "صدفة", "Concha", "贝壳", "Kombe"),
        ("🌺", "jelly", "magenta", "Hibiscus", "Hibiscus", "Hibisco", "Hibiskus", "كركديه", "Hibisco", "木槿花", "Hibiskasi"),
        ("🐬", "jump_spin", "blue", "Dauphin", "Dolphin", "Delfín", "Delfin", "دلفين", "Golfinho", "海豚", "Pomboo"),
        ("🎶", "dance", "violet", "Musique", "Music", "Música", "Musik", "موسيقى", "Música", "音乐", "Muziki"),
        ("⛵", "sway", "indigo", "Voilier", "Sailboat", "Velero", "Segelboot", "قارب شراعي", "Veleiro", "帆船", "Mashua"),
    ]),
    "europe": ({
        "fr": "Europe", "en": "Europe", "es": "Europa", "de": "Europa", "ar": "أوروبا",
        "pt": "Europa", "zh": "欧洲", "sw": "Ulaya"}, [
        ("🗼", "pulse", "indigo", "Tour Eiffel", "Eiffel Tower", "Torre Eiffel", "Eiffelturm", "برج إيفل", "Torre Eiffel", "埃菲尔铁塔", "Mnara wa Eiffel"),
        ("🥐", "bounce", "coral", "Croissant", "Croissant", "Cruasán", "Croissant", "كرواسون", "Croissant", "牛角包", "Kroissanti"),
        ("🍕", "pop_spin", "magenta", "Pizza", "Pizza", "Pizza", "Pizza", "بيتزا", "Pizza", "披萨", "Piza"),
        ("🎻", "sway", "violet", "Violon", "Violin", "Violín", "Geige", "كمان", "Violino", "小提琴", "Fidla"),
        ("🏰", "float", "blue", "Château", "Castle", "Castillo", "Schloss", "قلعة", "Castelo", "城堡", "Ngome"),
        ("🚲", "slide", "teal", "Vélo", "Bicycle", "Bicicleta", "Fahrrad", "دراجة", "Bicicleta", "自行车", "Baiskeli"),
        ("🧀", "jelly", "pink", "Fromage", "Cheese", "Queso", "Käse", "جبن", "Queijo", "奶酪", "Jibini"),
        ("☕", "float", "indigo", "Café", "Coffee", "Café", "Kaffee", "قهوة", "Café", "咖啡", "Kahawa"),
    ]),
    "asia": ({
        "fr": "Asie", "en": "Asia", "es": "Asia", "de": "Asien", "ar": "آسيا",
        "pt": "Ásia", "zh": "亚洲", "sw": "Asia"}, [
        ("🏮", "sway", "coral", "Lanterne", "Lantern", "Farolillo", "Laterne", "فانوس", "Lanterna", "灯笼", "Taa"),
        ("🍜", "float", "magenta", "Nouilles", "Noodles", "Fideos", "Nudeln", "معكرونة", "Macarrão", "面条", "Tambi"),
        ("🐼", "giggle", "teal", "Panda", "Panda", "Panda", "Panda", "باندا", "Panda", "熊猫", "Panda"),
        ("🌸", "jelly", "pink", "Cerisier en fleurs", "Cherry blossom", "Cerezo en flor", "Kirschblüte", "زهرة الكرز", "Flor de cerejeira", "樱花", "Ua la cheri"),
        ("🎋", "sway", "teal", "Bambou", "Bamboo", "Bambú", "Bambus", "خيزران", "Bambu", "竹子", "Mianzi"),
        ("🍣", "bounce", "violet", "Sushi", "Sushi", "Sushi", "Sushi", "سوشي", "Sushi", "寿司", "Sushi"),
        ("🐉", "pulse", "indigo", "Dragon", "Dragon", "Dragón", "Drache", "تنين", "Dragão", "龙", "Joka"),
        ("🍵", "float", "blue", "Thé", "Tea", "Té", "Tee", "شاي", "Chá", "茶", "Chai"),
    ]),
    "latam": ({
        "fr": "Amérique latine", "en": "Latin America", "es": "Latinoamérica", "de": "Lateinamerika", "ar": "أمريكا اللاتينية",
        "pt": "América Latina", "zh": "拉丁美洲", "sw": "Amerika ya Kusini"}, [
        ("🌮", "bounce", "coral", "Taco", "Taco", "Taco", "Taco", "تاكو", "Taco", "塔可", "Tako"),
        ("🎺", "cheer", "magenta", "Trompette", "Trumpet", "Trompeta", "Trompete", "بوق", "Trompete", "小号", "Tarumbeta"),
        ("🦜", "sway", "teal", "Perroquet", "Parrot", "Loro", "Papagei", "ببغاء", "Papagaio", "鹦鹉", "Kasuku"),
        ("🌶️", "fire_flicker", "coral", "Piment", "Chili pepper", "Chile", "Chili", "فلفل حار", "Pimenta", "辣椒", "Pilipili"),
        ("⚽", "jump_spin", "blue", "Football", "Football", "Fútbol", "Fußball", "كرة القدم", "Futebol", "足球", "Mpira wa miguu"),
        ("🎸", "dance", "violet", "Guitare", "Guitar", "Guitarra", "Gitarre", "غيتار", "Violão", "吉他", "Gitaa"),
        ("🌵", "pulse", "teal", "Cactus", "Cactus", "Cactus", "Kaktus", "صبار", "Cacto", "仙人掌", "Kaktasi"),
        ("🥑", "jelly", "indigo", "Avocat", "Avocado", "Aguacate", "Avocado", "أفوكادو", "Abacate", "牛油果", "Parachichi"),
    ]),
    "mena": ({
        "fr": "Moyen-Orient", "en": "Middle East", "es": "Oriente Medio", "de": "Naher Osten", "ar": "الشرق الأوسط",
        "pt": "Oriente Médio", "zh": "中东", "sw": "Mashariki ya Kati"}, [
        ("🕌", "pulse", "teal", "Mosquée", "Mosque", "Mezquita", "Moschee", "مسجد", "Mesquita", "清真寺", "Msikiti"),
        ("🐪", "walk", "coral", "Chameau", "Camel", "Camello", "Kamel", "جمل", "Camelo", "骆驼", "Ngamia"),
        ("☕", "float", "indigo", "Café", "Coffee", "Café", "Kaffee", "قهوة", "Café", "咖啡", "Kahawa"),
        ("🌙", "sway", "violet", "Lune", "Moon", "Luna", "Mond", "قمر", "Lua", "月亮", "Mwezi"),
        ("🏜️", "float", "magenta", "Désert", "Desert", "Desierto", "Wüste", "صحراء", "Deserto", "沙漠", "Jangwa"),
        ("🥙", "bounce", "pink", "Sandwich oriental", "Wrap", "Shawarma", "Dürüm", "شاورما", "Shawarma", "卷饼", "Shawarma"),
        ("🍯", "jelly", "coral", "Miel", "Honey", "Miel", "Honig", "عسل", "Mel", "蜂蜜", "Asali"),
        ("🧿", "shine", "blue", "Porte-bonheur", "Lucky charm", "Amuleto", "Glücksbringer", "عين الحسد", "Amuleto", "护身符", "Hirizi"),
    ]),
}
LANGS = ["fr", "en", "es", "de", "ar", "pt", "zh", "sw"]
ORDER = {"africa": 10, "caribbean": 11, "europe": 12, "asia": 13, "latam": 14, "mena": 15}


def build():
    out = []
    for region, (names, items) in REGIONS.items():
        for i, it in enumerate(items):
            emoji, motion, color = it[:3]
            caps = dict(zip(LANGS, it[3:]))
            sid = "%s_%s" % (region, g.slugify(caps["en"]))
            kws = []
            for l in ("fr", "en", "es", "de", "pt", "sw"):
                for w in g.strip_accents(caps[l]).lower().replace("'", " ").replace("-", " ").split():
                    if len(w) >= 2 and w not in g.STOP and w not in kws:
                        kws.append(w)
            for l in ("ar", "zh"):
                if caps[l] not in kws:
                    kws.append(caps[l])
            kws.append(region)
            out.append({"id": sid, "region": region, "category": "humeur", "order": i + 1, "emoji": emoji,
                        "motion": motion, "color": color, "captions": caps, "keywords": kws,
                        "file": sid + ".webp", "thumbFile": sid + "_thumb.webp"})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(HERE / "regions_out"))
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    stickers = build()
    with Pool(max(1, a.jobs)) as pool:
        res = {r[0]: r for r in pool.map(g.process, [(s, str(out)) for s in stickers])}
    packs = []
    for region, (names, _) in REGIONS.items():
        st = []
        for s in stickers:
            if s["region"] != region:
                continue
            _, size, dur, tsize, q, step = res[s["id"]]
            st.append({k: s[k] for k in ("id", "category", "order", "emoji", "motion", "captions", "keywords", "file", "thumbFile")}
                      | {"sizeBytes": size, "durationMs": dur, "giftPriceCoins": 0})
        packs.append({"packId": "world_" + region, "region": region, "order": ORDER[region], "names": names, "stickers": st})
    json.dump(packs, open(INDEX, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    sizes = [r[1] for r in res.values()]
    print("OK %d stickers, max %.0f Ko" % (len(sizes), max(sizes) / 1024))


if __name__ == "__main__":
    main()
