"""Gera o ícone do jogo: uma garrafa de pinga com um copo de dose do lado.

Desenhado em vetor com o Pillow e reduzido com reamostragem. É uma silhueta preta
sobre fundo amarelo: duas cores só, o que mantém a leitura lá embaixo, no tamanho da
barra de tarefas. Os detalhes (rótulo, brilho do vidro, dose no copo) são vazados em
amarelo claro por cima do preto, em vez de desenhados por cima.

    python tools/make_icon.py            # assets/icon.png (256) + assets/icon.ico
    python tools/make_icon.py --preview  # salva também um PNG grande para conferir
"""

import argparse
import os

from PIL import Image, ImageDraw, ImageFont

# Reduzimos deste tamanho para o final: desenhar grande e encolher dá a borda suave.
SIZE = 256
SS = 4  # fator de supersampling

# --- paleta: duas cores, mais um creme para os vazados --------------------------
BG_TOP = (250, 206, 60)  # amarelo do boteco, puxado para o saturado
BG_BOT = (235, 168, 28)
INK = (24, 20, 16)  # o preto da garrafa e do copo (mesmo tom do contorno toon)
CUT = (253, 232, 155)  # creme dos vazados: rótulo, brilho e a dose


def bezier(p0, p1, p2, steps=18):
    """Curva quadrática, para o ombro da garrafa não ficar quebrado."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        pts.append((
            u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
        ))
    return pts


def bottle_outline():
    """Silhueta da garrafa em coordenadas de 256, de baixo para cima."""
    return (
        [(70, 228), (70, 124)]
        + bezier((70, 124), (74, 92), (92, 78))  # ombro esquerdo
        + [(92, 44), (112, 44)]
        + bezier((112, 78), (130, 92), (134, 124))  # ombro direito
        + [(134, 228)]
    )


def glass_outline():
    """Copo de dose: tronco de cone de boca mais larga."""
    return [(152, 166), (208, 166), (201, 228), (159, 228)]


def load_font(px):
    for name in ("arialbd.ttf", "ariblk.ttf", "DejaVuSans-Bold.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, px)
        except OSError:
            continue
    return None


def draw_icon():
    s = SIZE * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def sc(pts):
        return [(x * SS, y * SS) for x, y in pts]

    def box(x0, y0, x1, y1):
        return [x0 * SS, y0 * SS, x1 * SS, y1 * SS]

    # --- fundo: quadrado arredondado com leve degradê vertical ------------------
    grad = Image.new("RGBA", (1, s))
    gd = ImageDraw.Draw(grad)
    for y in range(s):
        t = y / (s - 1)
        gd.point((0, y), tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOT)) + (255,))
    grad = grad.resize((s, s))
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=56 * SS, fill=255)
    img.paste(grad, (0, 0), mask)

    # --- copo, em preto chapado -------------------------------------------------
    d.polygon(sc(glass_outline()), fill=INK)
    d.ellipse(box(152, 158, 208, 174), fill=INK)
    # vazados: a boca do copo e a dose servida
    d.ellipse(box(159, 162, 201, 171), fill=CUT)
    d.polygon(sc([(162, 196), (198, 196), (195, 221), (165, 221)]), fill=CUT)

    # --- garrafa, em preto chapado ----------------------------------------------
    d.polygon(sc(bottle_outline()), fill=INK)
    d.rounded_rectangle(box(86, 30, 118, 52), radius=6 * SS, fill=INK)
    # vazados: o rótulo com o "P" da pinga e o brilho do vidro
    d.rectangle(box(76, 158, 128, 200), fill=CUT)
    font = load_font(30 * SS)
    if font is not None:
        d.text((102 * SS, 180 * SS), "P", font=font, fill=INK, anchor="mm")
    # o brilho é no vidro, então aparece acima e abaixo do rótulo, nunca por cima dele
    d.line(sc([(82, 120), (82, 152)]), fill=CUT, width=5 * SS)
    d.line(sc([(82, 206), (82, 220)]), fill=CUT, width=5 * SS)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true", help="salva também um PNG 1024 para conferir")
    args = ap.parse_args()

    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(here, "assets")
    icon = draw_icon()
    png = os.path.join(out, "icon.png")
    icon.save(png)
    print("escrito", png)

    # .ico com vários tamanhos, para o executável exportado no Windows
    ico = os.path.join(out, "icon.ico")
    icon.save(ico, sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("escrito", ico)

    if args.preview:
        big = os.path.join(out, "icon_preview.png")
        icon.resize((1024, 1024), Image.NEAREST).save(big)
        print("escrito", big)


if __name__ == "__main__":
    main()
