# -*- coding: utf-8 -*-
# Met à jour les textes de l'accueil du site (en-tête réseau social). À lancer depuis le dossier site/.
import re
BS = chr(92)
p = 'src/i18n.mjs'
s = open(p, encoding='utf-8', newline='').read(); crlf = '\r\n' in s; s = s.replace('\r\n', '\n')
idx = [m.start() for m in re.finditer('\n    home: [{]\n', s)]
assert len(idx) == 2, idx
FR = {'title': "Afrolook : le réseau social qui paie ses créateurs",
 'desc': "Publie, passe en live, reçois des cadeaux, vends en direct, crée des cartes et mets ta musique. Afrolook rémunère ses créateurs partout dans le monde. Gratuit sur Android et iPhone.",
 'eyebrow': "Réseau social · Cadeaux · Lives · Vente en direct", 'h1a': "Ton réseau social.", 'h1b': "Qui paie ses créateurs, partout dans le monde.",
 'lead': "Publie, passe en live, reçois des cadeaux de ta communauté, vends tes produits en direct, partage des cartes et mets ta musique. Plus ta communauté grandit, plus Afrolook te rémunère, dans ta monnaie.",
 'fine': "Écrans, noms et montants d'exemple. Les gains dépendent de ton audience."}
EN = {'title': "Afrolook: the social network that pays its creators",
 'desc': "Post, go live, receive gifts, sell live, create cards and add your music. Afrolook pays its creators all over the world. Free on Android and iPhone.",
 'eyebrow': "Social network · Gifts · Lives · Live selling", 'h1a': "Your social network.", 'h1b': "That pays its creators, all over the world.",
 'lead': "Post, go live, receive gifts from your community, sell your products live, share cards and add your music. The more your community grows, the more Afrolook pays you, in your currency.",
 'fine': "Example screens, names and amounts. Earnings depend on your audience."}

def q(v):
    return "'" + v.replace(BS, BS + BS).replace("'", BS + "'") + "'"

def strend(t, i):
    j = i + 1
    while t[j] != "'":
        j += 2 if t[j] == BS else 1
    return j + 1

def setkey(blk, key, val, start=0):
    i = blk.index(' ' + key + ": '", start) + len(key) + 3
    return blk[:i] + q(val) + blk[strend(blk, i):]

def patch(blk, vals, pil1, scr):
    for k, v in vals.items():
        blk = setkey(blk, k, v)
    i = blk.index('pil1: [') + 6
    j = blk.index(']', i) + 1
    blk = blk[:i] + '[' + q(pil1[0]) + ', ' + q(pil1[1]) + ']' + blk[j:]
    i = blk.index('screens: { k: ')
    for key, v in zip(('k', 'h', 'p'), scr):
        blk = setkey(blk, key, v, i)
    return blk

def endof(st):
    return st + s[st:].index('\n    faq:')

a, b = idx
fa, fb, ea, eb = a, endof(a), b, endof(b)
fr = patch(s[fa:fb], FR, ("Cadeaux et gains", "Sur tes posts et en live, retrait en argent réel"), ("L'application", "Le fil, les vidéos, la musique, les lives et les cadeaux", "Tout ce que tu fais dans Afrolook se retrouve dans une seule application : fil et chroniques, vidéos verticales, audio avec image, cartes, cadeaux sur les posts et en live, et vente en direct."))
en = patch(s[ea:eb], EN, ("Gifts and earnings", "On your posts and in lives, cash out in real money"), ("The app", "The feed, videos, music, lives and gifts", "Everything you do in Afrolook lives in one app: feed and chronicles, vertical videos, audio with a cover, cards, gifts on posts and in lives, and live selling."))
s = s[:fa] + fr + s[fb:ea] + en + s[eb:]
open(p, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if crlf else s)
print('ok')
