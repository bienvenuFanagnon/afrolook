# ---------- scènes (publicité « avant / avec SlashAtlas ») ----------
from PIL import ImageEnhance, ImageOps
import textwrap
SK_BEFORE = load('skincareglow', 'avant'); SK_AFTER = posters['skincareglow']
GREEN = (48, 209, 88); RED = (255, 85, 85); YEL = (255, 204, 0)
def bad_poster(variant, w, h):
    """Résultat « moyen » typique d'un prompt approximatif : recadrage maladroit, couleurs criardes, texte générique."""
    im = SK_BEFORE.copy()
    if variant == 0:
        im = ImageOps.fit(im, (w, h), centering=(0.2, 0.7)); im = ImageEnhance.Color(im).enhance(1.9); im = ImageEnhance.Contrast(im).enhance(1.25)
        d = ImageDraw.Draw(im); d.rectangle((0, int(h * 0.78), w, int(h * 0.93)), fill=(220, 30, 60)); d.text((w / 2, h * 0.855), 'BEST CREAM!!!', font=font(h * 0.07), fill=(255, 255, 255), anchor='mm')
    elif variant == 1:
        im = ImageOps.fit(im, (w, h), centering=(0.5, 0.2)); im = ImageEnhance.Color(im).enhance(0.55); tint = Image.new('RGB', im.size, (60, 140, 90)); im = Image.blend(im, tint, 0.35)
        d = ImageDraw.Draw(im); d.text((w * 0.08, h * 0.1), 'new product', font=font(h * 0.08), fill=(255, 235, 120)); d.text((w * 0.08, h * 0.19), 'buy now buy now', font=font(h * 0.045), fill=(255, 255, 255))
    else:
        im = ImageOps.fit(im, (w, h), centering=(0.9, 0.5)); im = ImageEnhance.Brightness(im).enhance(1.35); im = im.filter(ImageFilter.GaussianBlur(2))
        ov = Image.new('RGB', im.size, (255, 120, 190)); im = Image.blend(im, ov, 0.22)
        d = ImageDraw.Draw(im); d.text((w / 2, h * 0.5), 'SALE', font=font(h * 0.2), fill=(255, 255, 0), anchor='mm'); d.text((w / 2, h * 0.7), 'cream cream cream', font=font(h * 0.05), fill=(40, 40, 40), anchor='mm')
    return fit(im, w, h, 22)
_bad = {}
def bad(variant, w, h):
    k = (variant, w, h)
    if k not in _bad: _bad[k] = bad_poster(variant, w, h)
    return _bad[k]
def mmss(sec): sec = int(max(0, sec)); return f'{sec // 60}:{sec % 60:02d}'
def wrap_text(draw, s, f, maxw):
    lines, cur = [], ''
    for wd in s.split(' '):
        t = (cur + ' ' + wd).strip()
        if draw.textlength(t, font=f) <= maxw: cur = t
        else: lines.append(cur); cur = wd
    if cur: lines.append(cur)
    return lines
def geom():
    """Zones : boîte de prompt, carte résultat, chrono."""
    if SPL:
        return dict(px=W * 0.05, py=H * 0.20, pw=W * 0.52, ph=H * 0.50, rx=W * 0.78, ry=H * 0.50, rw=int(W * 0.23), tx=W * 0.31, ty=H * 0.09, sx=W * 0.08, sy=H * 0.86)
    rw = int(W * 0.56); return dict(px=W * 0.06, py=H * 0.17, pw=W * 0.88, ph=H * 0.23, rx=W / 2, ry=H * 0.64, rw=rw, tx=W / 2, ty=H * 0.075, sx=W * 0.22, sy=H * 0.885)
def prompt_box(img, g, text_s, typed_frac, label, col, show_photo=True, alpha=1.0):
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    x0, y0, x1, y1 = g['px'], g['py'], g['px'] + g['pw'], g['py'] + g['ph']
    d.rounded_rectangle((x0, y0, x1, y1), 28 * U, fill=(24, 26, 33, int(255 * alpha)), outline=(col + (int(255 * alpha),)), width=3)
    f = font((36 if not SPL else 32) * U, 'r'); tx = x0 + (150 if show_photo else 36) * U
    typed = text_s[:int(len(text_s) * clamp(typed_frac))]
    lines = wrap_text(d, typed, f, (x1 - tx) - 30 * U)[:7]
    ys = y0 + 34 * U
    for ln in lines: d.text((tx, ys), ln, font=f, fill=(235, 235, 240, int(255 * alpha)), anchor='la'); ys += f.size * 1.3
    if typed_frac < 1 and int(typed_frac * 40) % 2 == 0: d.text((tx + (d.textlength(lines[-1], font=f) if lines else 0) + 4 * U, ys - f.size * 1.3), '|', font=f, fill=col + (255,), anchor='la')
    d.text((x0 + 30 * U, y1 - 34 * U), label, font=font(28 * U, 'b'), fill=col + (int(255 * alpha),), anchor='lm')
    img = Image.alpha_composite(img, lay)
    if show_photo: img = paste(img, fit(SK_BEFORE, int(96 * U), int(96 * U), 16), x0 + 76 * U, y0 + 72 * U, shadowed=False, alpha=alpha)
    return img
def timer(img, g, sec, col, label):
    f = font(92 * U); s_ = mmss(sec)
    img = pill(img, s_, g['tx'], g['ty'], 80 if not SPL else 70, bgc=(20, 22, 28), fg=col, padx=46, pady=18)
    return text(img, label, g['tx'], g['ty'] + 92 * U, 34, col=MUT, kind='r', shadow_=False)
def strip(img, g, thumbs, alpha=1.0):
    for i, v in enumerate(thumbs):
        img = paste(img, bad(v, int(150 * U), int(186 * U)), g['sx'] + i * 170 * U, g['sy'], shadowed=False, alpha=0.9)
    return img
def s_hook(t):  # 0 – 2.6
    img = bg(t)
    for i, w_ in enumerate(T_('hook').split('\n')):
        a = ease_out((t - 0.2 - i * 0.35) / 0.4)
        img = text(img, w_, W / 2, H * (0.40 if not SPL else 0.42) + (i - 0.5) * 120 * U + (1 - a) * 36 * U, 78 if not SPL else 66, alpha=a, maxw=W * 0.92)
    return img
def s_struggle(t):  # 2.6 – 11.6
    tt = t - 2.6; img = bg(t); g = geom()
    img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (60, 0, 0, 40)))
    P = [T_('p1'), T_('p2'), T_('p3')]; turn_start = [0.2, 3.0, 5.7]; res_at = [2.0, 4.9, 7.6]
    k = 0 if tt < 3.0 else (1 if tt < 5.7 else 2)
    frac = (tt - turn_start[k]) / (1.1 if k == 0 else (1.5 if k == 1 else 1.7))
    img = prompt_box(img, g, P[k], frac, f"{T_('try')} {k + 1}", RED if k == 2 else ACC2)
    # résultat
    if tt >= res_at[k]:
        a = ease_back((tt - res_at[k]) / 0.5); rw = g['rw']; rh = int(rw * 1.24)
        img = paste(img, bad(k, rw, rh), g['rx'], g['ry'], angle=(-2 + k * 2), scale=clamp(a, 0.01, 1.05), shadowed=True)
        chip = T_('still') if k == 2 else T_('meh')
        if a > 0.8: img = pill(img, chip, g['rx'], g['ry'] + rh * 0.58, 34, bgc=(RED if k == 2 else (70, 72, 82)), fg=WHITE, padx=26, pady=12)
    elif tt >= turn_start[k] + 1.2:  # points de chargement
        n = int(tt * 4) % 4; img = text(img, '.' * (n + 1), g['rx'], g['ry'], 120, col=MUT)
    done = [v for v in range(3) if tt >= res_at[v] + 0.9 and v != k]
    img = strip(img, g, [v for v in range(3) if tt >= res_at[v] + 0.9 and v < k] if k > 0 else [])
    img = timer(img, g, 892 * ease_io(tt / 9.0), RED, 'time spent' if LANG == 'en' else 'temps passé')
    return badge(img, t, 3.0)
def s_faster(t):  # 11.6 – 13.8
    tt = t - 11.6; img = bg(t)
    a = ease_out(tt / 0.4); img = text(img, T_('faster'), W / 2, H * 0.5, 96 if not SPL else 86, col=WHITE, alpha=a, maxw=W * 0.9)
    return img
def s_site(t):  # 13.8 – 21.2
    tt = t - 13.8; img = bg(t); g = geom()
    # carte « site » avec les boutons Générer ici / Copier
    cw = int(W * 0.84) if not SPL else int(W * 0.46); ch = int(H * 0.17) if not SPL else int(H * 0.26)
    cx = W / 2 if not SPL else W * 0.30; cy = H * 0.255 if not SPL else H * 0.47
    a = ease_back(tt / 0.5)
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    x0, y0 = cx - cw / 2, cy - ch / 2; sc = clamp(a, 0.01, 1.0)
    d.rounded_rectangle((cx - cw * sc / 2, cy - ch * sc / 2, cx + cw * sc / 2, cy + ch * sc / 2), 30 * U, fill=(20, 22, 28, 255), outline=(60, 64, 74, 255), width=3)
    if sc > 0.95:
        d.text((x0 + 36 * U, y0 + 44 * U), '/skincareglow', font=font(48 * U, 'm'), fill=ACC2 + (255,), anchor='lm')
        d.text((x0 + 36 * U, y0 + 96 * U), T_('ready'), font=font(30 * U, 'r'), fill=MUT + (255,), anchor='lm')
        press = 1.0 if 1.6 < tt < 1.9 else 0.0
        by = y1 = y0 + ch - 54 * U
        d.rounded_rectangle((x0 + 36 * U, by - 34 * U, x0 + 36 * U + 270 * U, by + 34 * U), 34 * U, fill=ACC + (255,)); d.text((x0 + (36 + 135) * U, by), T_('gen'), font=font(30 * U), fill=(255, 255, 255, 255), anchor='mm')
        bx0 = x0 + 330 * U; bgc = (OK + (255,)) if tt > 1.9 else (30, 32, 40, 255)
        d.rounded_rectangle((bx0, by - 34 * U, bx0 + 200 * U, by + 34 * U), 34 * U, fill=bgc, outline=(80, 84, 96, 255) if tt <= 1.9 else None, width=2)
        d.text((bx0 + 100 * U, by), T_('copied') if tt > 1.9 else T_('copy'), font=font(30 * U), fill=(255, 255, 255, 255), anchor='mm')
    img = Image.alpha_composite(img, lay)
    if 1.3 < tt < 2.1:  # tap
        px = x0 + 330 * U + 100 * U; py = y0 + ch - 54 * U
        r = (1 - clamp((tt - 1.6) / 0.4)) * 30 * U + 26 * U
        ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ImageDraw.Draw(ov).ellipse((px - r, py - r, px + r, py + r), outline=(255, 255, 255, 200), width=5); img = Image.alpha_composite(img, ov)
    # collage dans la boîte de prompt (coller)
    if tt > 2.4:
        g2 = dict(g); 
        if not SPL: g2.update(py=H * 0.375, ph=H * 0.115)
        typed = ((tt - 2.4) / 0.25)
        img = prompt_box(img, g2, '/skincareglow ' + ('my face cream' if LANG == 'en' else 'ma crème visage'), clamp(typed), '', OK)
    # résultat
    if tt >= 4.6:
        a = ease_back((tt - 4.6) / 0.55); rw = g['rw']; rh = int(rw * 1.24)
        img = paste(img, fit(SK_AFTER, rw, rh), g['rx'], g['ry'] + (0 if SPL else 0.04 * H), angle=0, scale=clamp(a, 0.01, 1.06))
        for (sx, sy, off, r) in SPK:
            aa = math.sin(clamp((tt - 4.9 - off) / 0.8) * math.pi)
            if aa > 0: img = sparkle(img, g['rx'] + (sx - 0.5) * rw * 1.2, g['ry'] + (sy - 0.5) * rh * 1.1, r * U * aa, aa)
        if a > 0.8: img = pill(img, T_('done'), g['rx'], g['ry'] + (0 if SPL else 0.04 * H) + rh * 0.58, 38, bgc=OK, fg=(0, 30, 10), padx=30, pady=14)
    img = timer(img, g, 20 * ease_io((tt - 2.6) / 2.0) if tt > 2.6 else 0, GREEN, T_('secs') if tt > 4.6 else ('time spent' if LANG == 'en' else 'temps passé'))
    return badge(img, t, 14.5)
def s_everywhere(t):  # 21.2 – 27.0
    tt = t - 21.2; img = bg(t)
    names = ['skincareglow', 'menuhero', 'fashionposter']
    cw = int(W * 0.17) if SPL else int(W * 0.27); ch = int(cw * 1.24)
    for i, nme in enumerate(names):
        a = ease_back((tt - 0.1 - i * 0.15) / 0.5)
        if a <= 0: continue
        px = W * (0.10 + 0.16 * i) if SPL else W * (0.20 + 0.30 * i); py = H * 0.5 if SPL else H * 0.30
        img = paste(img, fit(posters[nme], cw, ch), px, py, angle=(-5 + 5 * i), scale=clamp(a, 0.01, 1.08))
    tx = W * 0.72 if SPL else W / 2; ty = H * 0.22 if SPL else H * 0.47
    a = ease_out((tt - 0.4) / 0.4); img = text(img, T_('testit'), tx, ty, 50 if not SPL else 42, col=WHITE, alpha=a, maxw=W * (0.5 if SPL else 0.9))
    chips = [T_('gen'), 'ChatGPT', 'Gemini', 'Midjourney']
    for i, c in enumerate(chips):
        a = ease_back((tt - 0.9 - i * 0.25) / 0.4)
        if a <= 0: continue
        cy = ty + (110 + i * 112) * U if SPL else H * (0.545 + 0.075 * i)
        img = pill(img, c, tx, cy, 46 if not SPL else 40, bgc=(ACC if i == 0 else (30, 32, 40)), fg=WHITE, alpha=clamp(a, 0, 1), scale=clamp(a, 0.01, 1.05), padx=44, pady=18)
    a = ease_out((tt - 2.6) / 0.4)
    img = text(img, f"225 {T_('free')}", W * (0.72 if SPL else 0.5), H * (0.88 if not SPL else 0.90), 54 if not SPL else 44, col=ACC2, alpha=a, maxw=W * 0.9)
    return badge(img, t, 22.0)
def s_cta(t):  # 27.0 – fin
    tt = t - 27.0; img = bg(t)
    pw = W * 0.18 if LAND else (H * 0.20 if SQ else W * 0.31); cw, ch = int(pw), int(pw * 1.24)
    for i, nme in enumerate(['fashionposter', 'skincareglow', 'menuhero']):
        a = ease_back((tt - 0.1 - i * 0.12) / 0.5)
        if a <= 0: continue
        if SPL: px = W * (0.10 + 0.145 * i); py = H * 0.5 + (i % 2) * 36 * U - 18 * U
        else: px = W * (0.22 + 0.28 * i); py = H * 0.70 + (i % 2) * 24 * U
        img = paste(img, fit(posters[nme], cw, ch), px, py, angle=(-6 + 6 * i), scale=clamp(a, 0.01, 1.1))
    tx = W * 0.70 if LAND else (W * 0.72 if SQ else W / 2); ty0 = 0.27 if SPL else 0.15
    a = ease_out((tt - 0.3) / 0.4); img = text(img, '/SlashAtlas', tx, H * ty0, 96 if not SPL else 80, col=ACC2, alpha=a, maxw=W * (0.9 if not SPL else 0.50))
    a = ease_out((tt - 0.8) / 0.4); img = text(img, T_('tryfree'), tx, H * (ty0 + (0.12 if not SPL else 0.15)), 86 if not SPL else 70, alpha=a, maxw=W * (0.9 if not SPL else 0.50))
    a = ease_back((tt - 1.3) / 0.5)
    if a > 0:
        pulse = 1 + 0.035 * math.sin(tt * 6)
        img = pill(img, 'slashatlas.com', tx, H * (ty0 + (0.25 if not SPL else 0.31)), 80 if not SPL else 56, alpha=clamp(a, 0, 1), scale=clamp(a, 0.01, 1.1) * pulse, padx=50, pady=26)
    a = ease_out((tt - 1.9) / 0.4); img = text(img, T_('nosign'), tx, H * (ty0 + (0.34 if not SPL else 0.44)), 46 if not SPL else 38, col=MUT, kind='r', alpha=a)
    return badge(img, t, 27.8)
SC = [(0, 2.6, s_hook), (2.6, 11.6, s_struggle), (11.6, 13.8, s_faster), (13.8, 21.2, s_site), (21.2, 27.0, s_everywhere), (27.0, 99, s_cta)]
def frame(t):
    for a_, b_, fn in SC:
        if a_ <= t < b_: img = fn(t); break
    for tb in (2.6, 11.6, 13.8, 21.2, 27.0):
        if tb <= t < tb + 0.18: img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (0, 0, 0, int(200 * (1 - (t - tb) / 0.18)))))
    if t > LIMIT - 0.5: img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (0, 0, 0, int(255 * clamp((t - (LIMIT - 0.5)) / 0.5)))))
    return img.convert('RGB')
if __name__ == '__main__':
    MIX = sys.argv[6] if len(sys.argv) > 6 else 'mix.wav'
    if len(sys.argv) > 7 and sys.argv[7] == 'test':
        import os; os.makedirs('test', exist_ok=True)
        for tt in [float(x) for x in sys.argv[8].split(',')]: frame(tt).save(f'test/v2_{LANG}_{W}x{H}_{tt}.png')
        sys.exit(0)
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-i', MIX, '-t', str(LIMIT),
           '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '192k', '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11', OUT]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    for i in range(int(LIMIT * FPS)): p.stdin.write(frame(i / FPS).tobytes())
    p.stdin.close(); p.wait(); print('fini', OUT)
