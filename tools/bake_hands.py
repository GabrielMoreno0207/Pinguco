"""Esculpe as mãos do jogador (primeira pessoa) e grava assets/hands/hand_r.bin e hand_l.bin.

    python tools/bake_hands.py
    python tools/bake_hands.py --fast     # voxel maior (pré-visualização rápida)

Mesmo formato dos fregueses (PGC1). Cada braço é uma malha contínua com esqueleto:
  - "arm": antebraço com manga dobrada (relógio na esquerda);
  - "hand" (pulso), três falanges por dedo (f<i>a/b/c, i = 0 indicador … 3 mindinho)
    e o dedão (t_a/t_b).
Os dedos dobram em volta do eixo Y local de cada osso (Y+ fecha para o lado da palma
na mão direita, Y- na esquerda), então o jogo fecha a mão em volta do item com uma
conta 2D simples. Palma voltada para -X na mão direita, dedos para -Z, indicador em
cima (+Y). A esquerda é o espelho em X.
Precisa de numpy, scikit-image e fast-simplification.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bake_customers import FAST, Model, Palette, write  # noqa: E402
from sdf_sculpt import Frame, ell_dots, rot_y  # noqa: E402

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'hands')

# papéis de cor (o Hands resolve): pele, manga e dobra da manga
SKIN, SLEEVE, SLEEVE_FOLD = 0, 3, 5
NAIL_COL = (1.0, 0.84, 0.78)

WRIST = np.array([0.008, -0.01, 0.05])
FORE_DIR = np.array([0.22, -0.4, 1.0]) / np.linalg.norm([0.22, -0.4, 1.0])
FORE_LEN = 0.34
FINGER_Y = [0.03, 0.009, -0.012, -0.032]
FINGER_R = [0.0104, 0.0106, 0.0101, 0.009]
FINGER_LEN = [(0.03, 0.022, 0.017), (0.033, 0.025, 0.018), (0.031, 0.023, 0.017), (0.024, 0.018, 0.015)]
# curva da escultura (as poses do jogo partem daqui)
BIND_CURL = (0.12, 0.16, 0.12)
FINGER_Z = -0.042
THUMB_BASE = np.array([-0.013, 0.03, 0.016])
THUMB_DIR = np.array([-0.45, 0.22, -0.75]) / np.linalg.norm([-0.45, 0.22, -0.75])
THUMB_LEN = (0.032, 0.028)


class HandModel(Model):
    def __init__(self, pid):
        self.pid = pid
        self.pp = {}
        self.pal = Palette()
        self.nodes = []
        self.anchors = []
        self.parts = []
        self.vox = 2.0 if FAST else 1.0


def mirror(v, s):
    return np.array([v[0] * s, v[1], v[2]])


def axis_frame(d, up=(0, 1, 0)):
    """Rotação com -Z apontando para `d` e Y o mais perto possível de `up`."""
    z = -np.asarray(d, float)
    z /= np.linalg.norm(z)
    u = np.asarray(up, float)
    y = u - z * (u @ z)
    y /= np.linalg.norm(y)
    return np.column_stack([np.cross(y, z), y, z])


def along_frame(d):
    """Rotação com Y ao longo de `d` e Z virado para cima (lado de cima do antebraço)."""
    y = np.asarray(d, float) / np.linalg.norm(d)
    x = np.cross(y, (0, 1, 0))
    x /= np.linalg.norm(x)
    return np.column_stack([x, y, np.cross(x, y)])


def build(side):
    s = 1.0 if side == 'r' else -1.0
    m = HandModel('hand_' + side)
    pal = m.pal
    wrist = mirror(WRIST, s)
    m.node('arm', None, t=wrist, bone=True)
    m.node('hand', 'arm', bone=True)

    # uma malha só (antebraço + mão), para não ter emenda nem duas superfícies brigando no pulso
    hs = m.sculpt(0.001)
    hs.falloff = 0.007
    fs = hs

    # ---------------------------------------------------------------- antebraço (osso "arm")
    fa = Frame(along_frame(mirror(FORE_DIR, s)), wrist, bone='arm')
    L = FORE_LEN
    fs.cone(fa, (0, -0.012, 0), (0, L, 0), 0.033, 0.05, SKIN)
    fs.ell(fa, (0, L * 0.55, 0.006), (0.047, 0.1, 0.04), SKIN, k=0.03)
    # manga dobrada: tubo, dobra mais clara e botão em cima
    fs.cone(fa, (0, L * 0.7, 0), (0, L * 1.05, 0), 0.064, 0.068, SLEEVE, op='hard')
    fs.cone(fa, (0, L * 0.63, 0), (0, L * 0.73, 0), 0.071, 0.072, SLEEVE_FOLD, k=0.006)
    fs.torus(fa, (0, L * 0.635, 0), 0.068, 0.006, SLEEVE_FOLD, op='hard')
    top = np.array(fs.surf(fa, (0, L * 0.68, 0), (0, 0, 1)))
    fs.cyl(fa, top, 0.008, 0.003, 0.002, pal.fx('sleeve_btn', (0.95, 0.93, 0.85)), axis='z', op='hard')
    if side == 'l':
        band = pal.fx('watch_band', (0.22, 0.15, 0.11))
        gold = pal.fx('watch_case', (0.88, 0.72, 0.3), rough=0.3)
        face = pal.fx('watch_face', (0.97, 0.96, 0.9))
        ink = pal.fx('watch_ink', (0.1, 0.06, 0.05))
        fs.cone(fa, (0, L * 0.09, 0), (0, L * 0.17, 0), 0.0375, 0.0395, band, op='hard')
        top = np.array(fs.surf(fa, (0, L * 0.13, 0), (0, 0, 1)))
        fs.cyl(fa, top + (0, 0, 0.003), 0.021, 0.0055, 0.003, gold, axis='z', op='hard')
        fs.cyl(fa, top + (0, 0, 0.008), 0.0165, 0.0012, 0.0008, face, axis='z', op='hard')
        fs.box(fa, top + (0, 0.005, 0.0095), (0.0013, 0.0065, 0.0008), 0.0006, ink, op='hard')
        fs.box(fa, top + (0.0035, 0, 0.0095), (0.005, 0.0012, 0.0008), 0.0006, ink, op='hard')
        fs.cyl(fa, top + (0.0225, 0, 0.003), 0.003, 0.002, 0.001, gold, axis='x', op='hard')

    # ---------------------------------------------------------------- mão (com esqueleto)
    fh = Frame(bone='hand')
    nails = []
    # dedos: uma primitiva por falange, sem fusão entre dedos vizinhos
    for i in range(4):
        r = FINGER_R[i]
        base = np.array([s * 0.003, FINGER_Y[i], FINGER_Z])
        p, ang, parent = base, 0.0, 'hand'
        for j, seg in enumerate('abc'):
            name = 'f%d%s' % (i, seg)
            ang_j = BIND_CURL[j] + (0.04 * i if j == 0 else 0.0)
            ang += ang_j
            t = p - wrist if j == 0 else (0, 0, -FINGER_LEN[i][j - 1])
            m.node(name, parent, rot_y(s * ang_j), t, bone=True)
            fb = Frame(rot_y(s * ang), p, bone=name)
            ln = FINGER_LEN[i][j]
            ra, rb = r * (1.0 - 0.04 * j), r * (0.96 - 0.04 * j)
            hs.cone(fb, (0, 0, 0), (0, 0, -ln + (rb if j == 2 else 0)), ra, rb, SKIN)
            if j == 2:
                # unha nas costas da ponta (a palma fica do lado -X*s)
                nails.append(fb.to_world((s * rb * 0.6, 0, -ln + rb * 1.3)))
            p = fb.to_world((0, 0, -ln))
            parent = name
        # nó do dedo nas costas da mão
        hs.ell(fh, base + np.array([s * 0.009, 0, 0.006]), (0.008, r * 1.05, 0.011), SKIN, k=0.004)
    # pulso e palma (une suave na base dos dedos) + monte do dedão
    hs.cone(fh, wrist + (0, 0, 0.012), mirror((0.004, 0.0, -0.01), s), 0.032, 0.03, SKIN, k=0.012)
    hs.box(fh, mirror((0.004, 0.0, -0.01), s), (0.018, 0.041, 0.034), 0.016, SKIN, k=0.01)
    hs.ell(fh, mirror((-0.016, 0.02, 0.006), s), (0.016, 0.022, 0.03), SKIN, k=0.012)
    # dedão
    tb = mirror(THUMB_BASE, s)
    Rt = axis_frame(mirror(THUMB_DIR, s))
    m.node('t_a', 'hand', Rt, tb - wrist, bone=True)
    m.node('t_b', 't_a', rot_y(s * 0.25), (0, 0, -THUMB_LEN[0]), bone=True)
    ft_a = Frame(Rt, tb, bone='t_a')
    hs.cone(ft_a, (0, 0, 0.012), (0, 0, -THUMB_LEN[0]), 0.0148, 0.0136, SKIN, k=0.006)
    ft_b = Frame(Rt @ rot_y(s * 0.25), ft_a.to_world((0, 0, -THUMB_LEN[0])), bone='t_b')
    hs.cone(ft_b, (0, 0, 0), (0, 0, -THUMB_LEN[1] + 0.012), 0.0136, 0.012, SKIN)
    nails.append(ft_b.to_world((s * 0.0075, 0, -THUMB_LEN[1] + 0.014)))
    # unhas (pintadas, recortadas na malha)
    hs.paint({SKIN}, ell_dots(nails, (0.0072, 0.0072, 0.0072)), pal.fx('nail', NAIL_COL, rough=0.35))
    m.part('arm', None, hs, True, tris=18000)
    return m


def main():
    for side in ('r', 'l'):
        write(build(side), OUT_DIR)


if __name__ == '__main__':
    main()
