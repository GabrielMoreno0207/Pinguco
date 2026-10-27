"""Esculpe os fregueses do Pinguço e grava assets/customers/<id>.bin.

    python tools/bake_customers.py            # todos
    python tools/bake_customers.py tiozao     # só um
    python tools/bake_customers.py --fast     # voxel maior (pré-visualização rápida)

Cada freguês vira uma malha contínua (corpo com pesos de esqueleto) + peças rígidas
(cabeça, mãos, sobrancelhas, lábios, chapéu, acessório de mão). O CustomerRig lê o
arquivo, monta o esqueleto e pinta as regiões com as cores do freguês.
Precisa de numpy e scikit-image.
"""
import gzip
import math
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_sculpt import Frame, Sculpt, dots, ell_dots, f_capcone, rot_x, rot_y, rot_z  # noqa: E402

HIP_Y = 0.85
THIGH = 0.42
HEAD_R = 0.25
HEAD_SCALE = 0.8
EYE_R = 0.078
# pose A da escultura: braços e pernas afastados para nada se fundir com o tronco
ARM_SPREAD = 0.42
LEG_SPREAD = 0.1
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'customers')
FAST = '--fast' in sys.argv

# papéis de cor (o rig resolve com a pele/roupa/cabelo sorteados do freguês)
SKIN, SKIN_DARK, NOSE, SHIRT, SHIRT_DARK, SHIRT_LIGHT, PANTS, PANTS_DARK, HAIR, HAIR_DARK, HAIR_SKIN, LIP, HAIR_DEEP = range(13)
FIXED_BASE = 32

PROFILES = {
    'tiozao': dict(bw=0.88, bd=1.0, h=1.0, waist=1.08, chest=1.04, hip=1.0, sh=1.0, thick=1.1, sleeve=0,
                   hs=(0.92, 1.2, 0.95), neck=1.0),
    'valentao': dict(bw=0.88 * 1.3, bd=1.0, h=1.05, waist=0.84, chest=1.12, hip=1.0, sh=1.12, thick=1.35, sleeve=0,
                     hs=(1.05, 1.1, 1.0), neck=1.3),
    'falante': dict(bw=0.88 * 0.85, bd=0.85, h=1.08, waist=0.92, chest=1.0, hip=1.0, sh=1.0, thick=0.9, sleeve=1,
                    hs=(0.86, 1.28, 0.92), neck=1.0),
    'fofoqueira': dict(bw=0.88 * 0.95, bd=1.0, h=0.95, waist=0.8, chest=1.04, hip=1.1, sh=1.0, thick=1.0, sleeve=2,
                       hs=(0.92, 1.2, 0.95), neck=1.0),
    'universitario': dict(bw=0.88 * 0.85, bd=0.9, h=1.06, waist=1.0, chest=1.0, hip=1.0, sh=1.0, thick=0.9, sleeve=2,
                          hs=(0.88, 1.24, 0.95), neck=1.0),
    'malandro': dict(bw=0.88 * 0.95, bd=1.0, h=1.02, waist=0.92, chest=1.0, hip=1.0, sh=1.0, thick=1.0, sleeve=1,
                     hs=(0.9, 1.2, 0.95), neck=1.0),
}

GOLD = (1.0, 0.8, 0.2)
WHITE = (0.95, 0.95, 0.92)
DARK = (0.1, 0.1, 0.11)
LEATHER = (0.25, 0.15, 0.08)


def euler(x, y, z):
    """Mesma ordem do Godot (YXZ)."""
    return rot_y(y) @ rot_x(x) @ rot_z(z)


class Palette:
    def __init__(self):
        self.entries = []
        self.index = {}

    def fx(self, name, colors, group=None, emission=0.0, rough=-1.0):
        if name in self.index:
            return self.index[name]
        if not isinstance(colors[0], (tuple, list)):
            colors = [colors]
        self.entries.append(dict(group=group or name, colors=colors, emission=emission, rough=rough))
        self.index[name] = FIXED_BASE + len(self.entries) - 1
        return self.index[name]


class Model:
    def __init__(self, pid):
        self.pid = pid
        self.pp = PROFILES[pid]
        self.pal = Palette()
        self.nodes = []      # (name, parent, R(3x3 com escala), t, is_bone)
        self.anchors = []    # (name, node, pos, normal)
        self.parts = []      # (name, node or None, Sculpt, skinned)
        self.vox = 2.0 if FAST else 1.0

    def node(self, name, parent, R=None, t=(0, 0, 0), bone=False, bind=None):
        """`R`/`t`: pose neutra do nó (a que o rig usa). `bind`: rotação da pose em que a
        malha foi esculpida (pose A), quando diferente."""
        R = np.eye(3) if R is None else np.asarray(R, float)
        self.nodes.append((name, parent, R, np.asarray(t, float), bone, R if bind is None else np.asarray(bind, float)))

    def has(self, name):
        return any(n[0] == name for n in self.nodes)

    def sculpt(self, voxel):
        return Sculpt(voxel * self.vox)

    def part(self, name, node, s, skinned=False, tris=None):
        if tris is None:
            tris = {'body': 16000, 'head': 10000}.get(name, 1800 if name.startswith('hand') else 400)
        self.parts.append((name, node, s, skinned, tris))

    def anchor(self, name, node, pos, normal=(0, 0, -1)):
        self.anchors.append((name, node, np.asarray(pos, float), np.asarray(normal, float)))


# ================================================================== esqueleto

def build_skeleton(m):
    pp = m.pp
    bw, h = pp['bw'], pp['h']
    m.node('torso', None, t=(0, HIP_Y, 0), bone=True)
    m.node('head', 'torso', np.eye(3) * HEAD_SCALE, (0, 0.64 * h, 0))
    for sd, s in (('l', -1), ('r', 1)):
        m.node('arm_' + sd, 'torso', t=(s * 0.26 * bw, 0.52 * h, 0), bone=True, bind=rot_z(s * ARM_SPREAD))
        m.node('fore_' + sd, 'arm_' + sd, rot_x(0.3), (0, -0.26, 0), bone=True)
        m.node('hand_' + sd, 'fore_' + sd, rot_y(s * 0.8), (0, -0.235, 0))
    for sd, s in (('l', -1), ('r', 1)):
        m.node('leg_' + sd, None, t=(s * 0.11 * bw, HIP_Y, 0), bone=True, bind=rot_z(s * LEG_SPREAD))
        m.node('knee_' + sd, 'leg_' + sd, t=(0, -THIGH, 0), bone=True)
    ft = Frame(t=(0, HIP_Y, 0), bone='torso')
    fr = {'torso': ft}
    for sd, s in (('l', -1), ('r', 1)):
        fa = ft.child(rot_z(s * ARM_SPREAD), (s * 0.26 * bw, 0.52 * h, 0), bone='arm_' + sd)
        fr['arm_' + sd] = fa
        fr['fore_' + sd] = fa.child(rot_x(0.3), (0, -0.26, 0), bone='fore_' + sd)
        fl = Frame(rot_z(s * LEG_SPREAD), (s * 0.11 * bw, HIP_Y, 0), bone='leg_' + sd)
        fr['leg_' + sd] = fl
        fr['knee_' + sd] = fl.child(t=(0, -THIGH, 0), bone='knee_' + sd)
    return fr


# ================================================================== corpo

def torso_base(m, s, F, belt=True, hem=True):
    pp = m.pp
    bw, h, dep = pp['bw'], pp['h'], 0.85 * pp['bd']
    wk, ck, hk, sk = pp['waist'], pp['chest'], pp['hip'], pp['sh']
    ft = F['torso']
    s.ell(ft, (0, 0.0, 0), (0.2 * hk * bw, 0.14, 0.19 * hk * dep), PANTS)
    s.ell(ft, (0, 0.17 * h, 0), (0.185 * wk * bw, 0.16, 0.18 * wk * dep), SHIRT, k=0.08)
    s.ell(ft, (0, 0.34 * h, 0), (0.2 * ck * bw, 0.16 * h, 0.19 * ck * dep), SHIRT, k=0.08)
    s.ell(ft, (0, 0.46 * h, 0.01), (0.2 * sk * bw, 0.08, 0.15 * dep), SHIRT, k=0.07)
    nr = 0.058 * pp['neck']
    s.cone(ft, (0, 0.5 * h, 0.01), (0, 0.72 * h, 0.01), nr * 1.08, nr, SKIN, k=0.04)
    yb = 0.06
    torso_x = 0.3 * bw

    def tmask(lo, hi):
        return lambda P: (np.abs(ft.to_local(P)[:, 0]) < torso_x) & (ft.to_local(P)[:, 1] > lo) & (ft.to_local(P)[:, 1] < hi)
    # camisa por cima, calça por baixo: linha da cintura reta
    s.paint({SHIRT}, lambda P: ft.to_local(P)[:, 1] - yb, PANTS, tmask(-0.3, 0.4))
    s.paint({PANTS}, lambda P: yb - ft.to_local(P)[:, 1], SHIRT, tmask(-0.02, 0.4))
    if belt:
        band(m, s, ft, 0.035, 0.016, 0.006, m.pal.fx('belt', LEATHER))
        zf = s.surf(ft, (0, 0.035, 0), (0, 0, -1))[2]
        s.box(ft, (0, 0.035, zf - 0.004), (0.03, 0.022, 0.007), 0.005, m.pal.fx('gold', GOLD, rough=0.3), op='hard')
        s.box(ft, (0, 0.035, zf - 0.008), (0.016, 0.01, 0.01), 0.003, 0, k=0.002, op='sub')
    if hem:
        band(m, s, ft, yb + 0.012, 0.012, 0.004, SHIRT_DARK)
    # bolsos de trás
    for sd in (-1, 1):
        x = sd * 0.09 * bw
        zb = s.surf(ft, (x, -0.02, 0), (0, 0, 1))[2]
        fp = ft.child(rot_y(sd * 0.35), (x, -0.02, zb))
        s.box(fp, (0, 0, 0), (0.042, 0.04, 0.006), 0.004, PANTS_DARK, k=0.004)
    return yb


def band(m, s, ft, y, hw, out, region, rnd=0.004):
    """Faixa em volta do tronco na altura y (cinto, barra, cós)."""
    rx = s.surf(ft, (0, y, 0), (1, 0, 0))[0] + out
    zf = -s.surf(ft, (0, y, 0), (0, 0, -1))[2] + out
    zb = s.surf(ft, (0, y, 0), (0, 0, 1))[2] + out
    az = (zf + zb) * 0.5
    zc = (zb - zf) * 0.5
    mm = min(rx, az)

    def fn(Q):
        dx = (np.sqrt((Q[:, 0] / rx) ** 2 + ((Q[:, 2] - zc) / az) ** 2) - 1.0) * mm + rnd
        dy = np.abs(Q[:, 1] - y) - hw + rnd
        return np.minimum(np.maximum(dx, dy), 0.0) + np.sqrt(np.maximum(dx, 0) ** 2 + np.maximum(dy, 0) ** 2) - rnd
    s.custom(ft, fn, (-rx, y - hw, zc - az), (rx, y + hw, zc + az), region, op='hard')


def chain(m, s, ft, y0, w, drop, r, region, n=15, beads=False):
    """Cordão em "U" deitado no peito. Fino demais para o voxel do corpo, então vira
    uma peça própria presa no tronco (coordenadas locais do tronco). Devolve a peça e
    o referencial dela, para os pingentes."""
    pts = []
    for i in range(n):
        a = -1.25 + 2.5 * i / (n - 1)
        x = math.sin(a) * w
        # pontas no pescoço, meio caído no peito
        y = y0 - (math.cos(a) - math.cos(1.25)) / (1 - math.cos(1.25)) * drop
        pts.append(s.surf(ft, (x * 0.5, y, 0.0), (x * 0.5, 0, -0.2), out=r * 0.7))
    cs = m.sculpt(0.0012)
    F = Frame()
    if beads:
        for p in pts:
            cs.ell(F, p, r, region, op='hard')
    else:
        cs.tube(F, pts, r, region, join=r * 0.8)
    m.part('chain', 'torso', cs, tris=1400)
    return cs, F, pts


def arms(m, s, F, sleeve):
    t = m.pp['thick']
    bw, h = m.pp['bw'], m.pp['h']
    ft = F['torso']
    for sd, side in (('l', -1), ('r', 1)):
        fa, ff = F['arm_' + sd], F['fore_' + sd]
        up = SHIRT if sleeve == 2 else SKIN
        # ombro de verdade: trapézio descendo do pescoço até a junta (no tronco) e
        # deltoide por cima da junta (no braço), para o braço não sair de uma bolinha
        sh = (side * 0.26 * bw, 0.52 * h, 0)
        s.cone(ft, (side * 0.07, 0.56 * h, 0.01), (sh[0] * 0.92, sh[1] - 0.005, 0.0), 0.05 * t, 0.058 * t, SHIRT, k=0.06)
        s.ell(fa, (side * 0.006, -0.025, 0), (0.064 * t, 0.075 * t, 0.06 * t), SKIN if sleeve == 0 else SHIRT, k=0.05)
        s.cone(fa, (0, -0.03, 0), (0, -0.25, 0), 0.054 * t, 0.045 * t, up, k=0.035)
        s.cone(ff, (0, 0.0, 0), (0, -0.228, 0), 0.046 * t, 0.033 * t, up, k=0.035)
        if sleeve == 1:
            s.cone(fa, (0, 0.0, 0), (0, -0.14, 0), 0.066 * t, 0.06 * t, SHIRT, op='hard')
            s.torus(fa, (0, -0.133, 0), 0.058 * t, 0.007, SHIRT_DARK, op='hard')
        elif sleeve == 2:
            s.cone(ff, (0, -0.17, 0), (0, -0.212, 0), 0.04 * t, 0.038 * t, SHIRT_DARK, op='hard')


def pants_legs(m, s, F, cuff=True):
    for sd in ('l', 'r'):
        fl, fk = F['leg_' + sd], F['knee_' + sd]
        s.cone(fl, (0, 0.02, 0), (0, -THIGH, 0), 0.082, 0.07, PANTS, k=0.05)
        s.cone(fk, (0, 0, 0), (0, -0.35, 0), 0.069, 0.064, PANTS, k=0.03)
        if cuff:
            s.cone(fk, (0, -0.333, 0), (0, -0.362, 0), 0.068, 0.069, PANTS_DARK, op='hard')


def shoe(m, s, fk, kind, color, sole=(0.12, 0.1, 0.1)):
    pal = m.pal
    c = pal.fx('shoe', color, rough=0.35 if kind == 'dress' else -1.0)
    so = pal.fx('sole', sole)
    s.ell(fk, (0, -0.372, 0.0), (0.058, 0.056, 0.07), c, k=0.03)
    s.ell(fk, (0, -0.392, -0.075), (0.061, 0.044, 0.118), c, k=0.04)
    s.box(fk, (0, -0.4185, -0.052), (0.064, 0.0115, 0.138), 0.009, so, op='hard')
    floc = (lambda P, f=fk: f.to_local(P))
    if kind == 'dress' and m.pid == 'malandro':
        black = pal.fx('shoe_black', (0.08, 0.06, 0.06))
        s.paint({c}, lambda P: floc(P)[:, 2] + 0.12, black)
        s.paint({c}, lambda P: 0.03 - floc(P)[:, 2], black)
    elif kind == 'sneaker':
        lace = pal.fx('lace', (0.2, 0.2, 0.25))
        red = pal.fx('stripe_red', (0.85, 0.2, 0.2))
        for i in range(3):
            z0 = -0.05 - i * 0.03
            s.paint({c}, (lambda z0_: lambda P: np.abs(floc(P)[:, 2] - z0_) - 0.005)(z0), lace,
                    lambda P: (np.abs(floc(P)[:, 0]) < 0.028) & (floc(P)[:, 1] > -0.37))
        s.paint({c}, lambda P: np.abs((floc(P)[:, 1] + 0.39) + (floc(P)[:, 2] + 0.03) * 0.45) - 0.009, red,
                lambda P: np.abs(floc(P)[:, 0]) > 0.045)


def boot(m, s, fk, color):
    c = m.pal.fx('boot', color)
    s.cone(fk, (0, -0.22, 0), (0, -0.37, 0), 0.071, 0.068, c, op='hard')
    s.torus(fk, (0, -0.225, 0), 0.07, 0.008, c, op='hard')
    shoe(m, s, fk, 'boot', color, sole=(0.08, 0.06, 0.05))
    lace = m.pal.fx('boot_lace', (0.6, 0.5, 0.35))
    floc = (lambda P, f=fk: f.to_local(P))
    for i in range(5):
        y0 = -0.24 - i * 0.028
        s.paint({c}, (lambda y_: lambda P: np.abs(floc(P)[:, 1] - y_) - 0.004)(y0), lace,
                lambda P: (np.abs(floc(P)[:, 0]) < 0.025) & (floc(P)[:, 2] < -0.04))


# ================================================================== cabeça

def head_base(m, s):
    pp = m.pp
    r = HEAD_R
    hs = pp['hs']
    fy = r
    fz = -r * hs[2] * 0.86
    F = Frame()
    s.ell(F, (0, r, 0), (r * hs[0], r * hs[1], r * hs[2]), SKIN)
    s.ell(F, (0, r * 0.55, -0.03), (r * 0.72 * hs[0], r * 0.72 * 0.8, r * 0.72 * hs[2]), SKIN, k=0.07)
    for sd in (-1, 1):
        s.ell(F, (sd * 0.1 * hs[0], fy - 0.075, fz + 0.045), (0.075, 0.06, 0.06), SKIN, k=0.05)
    s.cone(F, (0, 0.06, 0.02), (0, -0.1, 0.02), 0.068, 0.07, SKIN, k=0.04)
    for sd in (-1, 1):
        ex = sd * r * hs[0] * 0.97
        s.ell(F, (ex, fy - 0.01, 0.0), (0.024, 0.05, 0.036), SKIN, k=0.012)
        s.ell(F, (ex + sd * 0.017, fy - 0.006, -0.004), (0.011, 0.03, 0.02), 0, k=0.006, op='sub')
    nr, ns = 0.03, (0.95, 0.9, 1.0)
    if m.pid == 'falante':
        ns = (0.8, 1.0, 1.6)
    elif m.pid == 'tiozao':
        nr = 0.042
    elif m.pid == 'fofoqueira':
        nr = 0.024
    elif m.pid == 'valentao':
        ns = (1.25, 0.85, 0.9)
    s.ell(F, (0, fy - 0.045, fz - 0.035), tuple(nr * v for v in ns), NOSE, k=0.022)
    # cantinhos da boca
    for sd in (-1, 1):
        s.ell(F, (sd * 0.05, fy - 0.135, fz + 0.005), (0.012, 0.016, 0.012), 0, k=0.01, op='sub')
    return F, r, hs, fy, fz


def face_nodes(m, head_s, F, r, hs, fy, fz):
    """Sobrancelhas e lábios: peças rígidas próprias (animadas pelo rig)."""
    eye_x = 0.075 * hs[0]
    eye_y = fy + 0.05
    brow_y = eye_y + EYE_R * 1.12 + 0.012
    mouth_y = fy - 0.13
    for sd, side in (('l', -1), ('r', 1)):
        m.anchor('eye_' + sd, 'head', (side * eye_x, eye_y, fz))
    # sobrancelhas
    t, arch, col = 0.022, 0.014, HAIR_DARK
    if m.pid in ('valentao', 'tiozao'):
        t, arch = 0.027, 0.008
    elif m.pid == 'fofoqueira':
        t, arch, col = 0.012, 0.024, HAIR_DEEP
    for sd, side in (('l', -1), ('r', 1)):
        z = head_s.surf(F, (side * eye_x, brow_y, 0), (0, 0, -1))[2]
        m.node('brow_' + sd, 'head', t=(side * eye_x, brow_y, z + 0.006))
        s = m.sculpt(0.0012)
        bf = Frame()
        pts = [(-side * 0.055, -0.01, 0.006), (-side * 0.02, arch * 0.8, -0.002), (side * 0.015, arch, -0.003),
               (side * 0.062, -0.014, 0.018)]
        s.tube(bf, pts, [t * 0.55, t, t * 0.9, t * 0.45], col, join=0.012)
        m.part('brow_' + sd, 'brow_' + sd, s)
    # boca e lábios
    zm = head_s.surf(F, (0, mouth_y, 0), (0, 0, -1))[2]
    m.node('mouth', 'head', t=(0, mouth_y, zm + 0.02))
    lip = m.pal.fx('lipstick', (0.85, 0.1, 0.25)) if m.pid == 'fofoqueira' else LIP
    lt = 0.0085 if m.pid == 'fofoqueira' else 0.0045
    lr = 0.011 if m.pid == 'fofoqueira' else 0.0058
    for sd, side in (('l', -1), ('r', 1)):
        m.node('lip_up_' + sd, 'mouth', t=(side * 0.007, 0.016, -0.022))
        s = m.sculpt(0.0009)
        s.tube(Frame(), [(side * 0.0, 0.0, 0.0), (side * 0.024, -0.001, 0.002), (side * 0.046, -0.008, 0.011)],
               [lt, lt * 0.95, lt * 0.45], lip, join=0.006)
        m.part('lip_up_' + sd, 'lip_up_' + sd, s, tris=320)
    m.node('lip_low', 'mouth', t=(0, -0.018, -0.018))
    for sd, side in (('l', -1), ('r', 1)):
        m.node('lip_low_' + sd, 'lip_low')
        s = m.sculpt(0.0009)
        s.tube(Frame(), [(-side * 0.002, 0.0, 0.0), (side * 0.02, -0.001, 0.002), (side * 0.038, 0.002, 0.008)],
               [lr, lr * 0.95, lr * 0.45], lip, join=0.006)
        m.part('lip_low_' + sd, 'lip_low_' + sd, s, tris=320)
    for sd, side in (('l', -1), ('r', 1)):
        p = head_s.surf(F, (side * 0.13 * hs[0], fy - 0.07, 0), (0, 0, -1))
        m.anchor('cheek_' + sd, 'head', p)


# ================================================================== mãos

def hand_part(m, side, extras=None):
    """Mão de boneco de vinil: palma cheia, quatro dedos juntinhos e meio dobrados
    (separados por um sulco) e dedão bem destacado na frente. Palma para -X*side,
    dedos descendo (-Y) e empilhados em Z (indicador na frente, -Z)."""
    t = m.pp['thick']
    sc = 0.92 + (t - 1.0) * 0.6
    s = m.sculpt(0.0013)
    F = Frame()
    lens = [(0.03, 0.021, 0.017), (0.033, 0.023, 0.018), (0.031, 0.022, 0.017), (0.025, 0.018, 0.015)]
    curls = [(0.16, 0.3, 0.2), (0.2, 0.34, 0.24), (0.26, 0.38, 0.28), (0.34, 0.42, 0.3)]
    tips = []
    knuckles = []
    # dedos primeiro, sem fusão entre eles (o sulco entre um e outro fica marcado)
    for i in range(4):
        rr = (0.0104 if i < 3 else 0.0094) * sc
        p = np.array([-side * 0.001 * sc, -0.06 * sc, (-0.0318 + i * 0.0212) * sc])
        pts = [p]
        ang = 0.0
        for j in range(3):
            ang += curls[i][j]
            d = np.array([-side * math.sin(ang), -math.cos(ang), (i - 1.5) * 0.04])
            p = p + d / np.linalg.norm(d) * lens[i][j] * sc
            pts.append(p)
        s.tube(F, pts, [rr, rr * 0.98, rr * 0.95, rr * 0.92], SKIN, join=0.003)
        tips.append(pts[-1])
        knuckles.append(pts[0])
    # pulso, palma (une suave nos dedos) e nós dos dedos nas costas da mão
    s.cone(F, (0, 0.045, 0), (0, -0.008, 0), 0.029 * t, 0.025 * sc, SKIN, k=0.01)
    s.box(F, (side * 0.001 * sc, -0.034 * sc, 0), (0.0165 * sc, 0.029 * sc, 0.04 * sc), 0.015 * sc, SKIN, k=0.012)
    for kn in knuckles:
        s.ell(F, kn + np.array([side * 0.007, 0.004, 0]) * sc, (0.0075 * sc, 0.009 * sc, 0.0095 * sc), SKIN, k=0.005)
    # monte e dedão (na frente, dobrando para o lado da palma)
    s.ell(F, (-side * 0.008 * sc, -0.028 * sc, -0.028 * sc), (0.016 * sc, 0.028 * sc, 0.019 * sc), SKIN, k=0.012)
    t0 = np.array([-side * 0.01, -0.03, -0.038]) * sc
    t1 = t0 + np.array([-side * 0.3, -0.85, -0.3]) / np.linalg.norm([0.3, 0.85, 0.3]) * 0.024 * sc
    t2 = t1 + np.array([-side * 0.42, -0.86, -0.08]) / np.linalg.norm([0.42, 0.86, 0.08]) * 0.02 * sc
    t3 = t2 + np.array([-side * 0.55, -0.82, 0.05]) / np.linalg.norm([0.55, 0.82, 0.05]) * 0.015 * sc
    s.tube(F, [t0, t1, t2, t3], [0.0145 * sc, 0.013 * sc, 0.0118 * sc, 0.0108 * sc], SKIN, k=0.008, join=0.004)
    tips.append(t3)
    if extras:
        extras(s, F, tips, sc)
    return s


# ================================================================== perfis

def model_tiozao(m, F):
    pp = m.pp
    h, bw = pp['h'], pp['bw']
    pal = m.pal
    s = m.sculpt(0.0045)
    ft = F['torso']
    torso_base(m, s, F)
    m.node('belly', 'torso', np.diag([1.0, 0.9, 0.95]), (0, 0.2, -0.1), bone=True)
    s.ell(ft, (0, 0.2, -0.1), (0.25, 0.225, 0.2375), SHIRT, k=0.07, bone='belly')
    arms(m, s, F, 0)
    # regata: decote e cavas de pele
    tl = (lambda P: ft.to_local(P))

    def tank(P):
        L = tl(P)
        x, y = np.abs(L[:, 0]), L[:, 1]
        neck = np.maximum((0.4 * h + 3.0 * x * x) - y, x - 0.085 * bw)
        armh = np.maximum(0.37 * h - y, 0.125 * bw - x)
        return np.minimum(neck, armh)
    s.paint({SHIRT}, tank, SKIN, lambda P: tl(P)[:, 1] > 0.3 * h)
    # pelinho no peito, mancha de molho na barriga
    chest = [s.surf(ft, (math.cos(a) * 0.035, 0.47 * h + math.sin(a) * 0.02, 0), (0, 0, -1)) for a in np.arange(7) * 2.4]
    s.paint({SKIN}, dots([ft.to_world(p) for p in chest], 0.007), HAIR, lambda P: tl(P)[:, 1] > 0.4 * h)
    stain = [s.surf(ft, (0.09, 0.27, -0.1), (0, 0, -1)), s.surf(ft, (0.13, 0.24, -0.1), (0, 0, -1))]
    s.paint({SHIRT}, ell_dots([ft.to_world(p) for p in stain[:1]], (0.04, 0.03, 0.03)), pal.fx('stain', (0.75, 0.45, 0.2)))
    s.paint({SHIRT}, dots([ft.to_world(stain[1])], 0.016), pal.fx('stain', (0.75, 0.45, 0.2)))
    # cordão com medalha
    gold = pal.fx('gold', GOLD, rough=0.3)
    cs, cf, pts = chain(m, s, ft, 0.55 * h, 0.08, 0.11, 0.0028, gold)
    mp = pts[len(pts) // 2] + np.array([0, -0.022, -0.004])
    cs.cyl(cf, mp, 0.019, 0.003, 0.002, gold, axis='z', op='hard')
    cs.cyl(cf, mp + np.array([0, 0, -0.003]), 0.012, 0.0015, 0.001, gold, axis='z', k=0.002, op='sub')
    cs.torus(cf, mp + np.array([0, 0.02, 0]), 0.004, 0.0015, gold, axis='z', op='hard')
    # carteira no bolso de trás
    zb = s.surf(ft, (0.09 * bw, -0.01, 0), (0, 0, 1))[2]
    s.box(ft, (0.09 * bw, -0.01, zb + 0.008), (0.045, 0.03, 0.012), 0.006, pal.fx('wallet', (0.35, 0.2, 0.1)), op='hard')
    # relógio de couro
    ff = F['fore_l']
    s.torus(ff, (0, -0.19, 0), 0.034, 0.009, pal.fx('watch_band', (0.35, 0.2, 0.1)), op='hard')
    s.cyl(ff, (0, -0.19, -0.04), 0.018, 0.005, 0.002, pal.fx('white', WHITE), axis='z', op='hard')
    # bermuda larga + canela de fora + chinelo
    for sd, side in (('l', -1), ('r', 1)):
        fl, fk = F['leg_' + sd], F['knee_' + sd]
        s.cone(fl, (0, 0.02, 0), (0, -0.37, 0), 0.1, 0.098, PANTS, k=0.05)
        s.torus(fl, (0, -0.368, 0), 0.094, 0.01, PANTS_DARK, op='hard')
        s.box(fl, (side * 0.098, -0.22, 0), (0.008, 0.05, 0.045), 0.006, PANTS_DARK, k=0.004)
        s.cone(fl, (0, -0.3, 0), (0, -THIGH, 0), 0.056, 0.054, SKIN, k=0.02)
        s.cone(fk, (0, 0, 0), (0, -0.37, 0), 0.052, 0.042, SKIN, k=0.03)
        flipflop(m, s, fk)
        hair = [fk.to_world((side * 0.02 - 0.015 + i * 0.011, -0.1 - i * 0.055, -0.05)) for i in range(5)]
        s.paint({SKIN}, dots(hair, 0.0045), HAIR_DARK, (lambda f: lambda P: f.to_local(P)[:, 2] < -0.02)(fk))
    m.part('body', None, s, True)

    hs_ = m.sculpt(0.003)
    Fh, r, hs, fy, fz = head_base(m, hs_)
    # coroinha de cabelo em tufos, bigodão, papada, rugas e caneta atrás da orelha
    for i in range(13):
        a = -0.25 + (math.pi + 0.5) * i / 12
        pos = (math.cos(a) * r * hs[0] * 0.97, r + 0.04 + math.sin(i * 1.7) * 0.012, math.sin(a) * r * hs[2] * 0.97)
        hs_.ell(Fh, pos, (0.042, 0.05, 0.042), HAIR, k=0.025)
    for i in range(7):
        tt = -1.0 + 2.0 * i / 6
        pos = (tt * 0.1, fy - 0.092 - abs(tt) * 0.025, fz - 0.045 + abs(tt) * 0.03)
        hs_.ell(Fh, pos, (0.036 - abs(tt) * 0.008, 0.03, 0.028), HAIR, k=0.02)
    hs_.ell(Fh, (0, fy - 0.19, fz + 0.075), (0.125, 0.045, 0.08), SKIN, k=0.04)
    for i in range(3):
        y = fy + 0.2 + i * 0.026
        hs_.tube(Fh, [hs_.surf(Fh, (x, y, 0), (0, 0, -1)) for x in np.linspace(-0.07, 0.07, 5)], 0.0035, 0, k=0.004, op='sub')
    for sd in (-1, 1):
        hs_.tube(Fh, [hs_.surf(Fh, (sd * 0.075, fy - 0.07, 0), (0, 0, -1)), hs_.surf(Fh, (sd * 0.088, fy - 0.15, 0), (0, 0, -1))],
                 0.0035, 0, k=0.004, op='sub')
    pen = (r * hs[0] * 0.92, fy + 0.07, 0.02)
    d = np.array([-math.cos(1.2), -math.sin(1.2), 0]) * 0.06
    hs_.cone(Fh, np.array(pen) - d, np.array(pen) + d, 0.008, 0.008, pal.fx('pen', (0.15, 0.3, 0.8)), op='hard')
    hs_.cone(Fh, np.array(pen) - d * 1.05, np.array(pen) - d * 0.75, 0.0088, 0.0088, pal.fx('white', WHITE), op='hard')
    face_nodes(m, hs_, Fh, r, hs, fy, fz)
    m.part('head', 'head', hs_)


def flipflop(m, s, fk):
    pal = m.pal
    green = pal.fx('flipflop', (0.2, 0.55, 0.3))
    s.box(fk, (0, -0.415, -0.05), (0.055, 0.009, 0.125), 0.008, green, op='hard')
    s.box(fk, (0, -0.426, -0.05), (0.056, 0.004, 0.126), 0.004, pal.fx('white', WHITE), op='hard')
    s.ell(fk, (0, -0.385, -0.06), (0.045, 0.028, 0.11), SKIN, k=0.03)
    for i in range(5):
        s.ell(fk, (-0.034 + i * 0.017, -0.395, -0.165 + abs(i - 1.0) * 0.007), 0.0125 - abs(i - 1.5) * 0.0012, SKIN, k=0.008)
    for sd in (-1, 1):
        s.tube(fk, [(0, -0.392, -0.13), (sd * 0.025, -0.37, -0.09), (sd * 0.046, -0.402, -0.04)], 0.006,
               pal.fx('white', WHITE), op='hard')


def model_valentao(m, F):
    pp = m.pp
    h, bw, t = pp['h'], pp['bw'], pp['thick']
    pal = m.pal
    s = m.sculpt(0.0045)
    ft = F['torso']
    torso_base(m, s, F)
    tl = (lambda P: ft.to_local(P))
    # peitoral, trapézio e ombros de academia
    for sd in (-1, 1):
        s.ell(ft, (sd * 0.085 * bw, 0.38 * h, -0.07), (0.1, 0.075, 0.08), SHIRT, k=0.04)
        s.ell(ft, (sd * 0.09, 0.56 * h, 0.02), (0.1, 0.05, 0.07), SKIN, k=0.05)
    arms(m, s, F, 0)
    for sd in ('l', 'r'):
        fa = F['arm_' + sd]
        s.ell(fa, (0, 0.0, 0), (0.085 * t, 0.075 * t, 0.08 * t), SKIN, k=0.04)
        s.ell(fa, (0, -0.13, -0.02), (0.05 * t, 0.07 * t, 0.05 * t), SKIN, k=0.03)

    def tank(P):
        L = tl(P)
        x, y = np.abs(L[:, 0]), L[:, 1]
        neck = np.maximum((0.42 * h + 2.5 * x * x) - y, x - 0.09 * bw)
        armh = np.maximum(0.36 * h - y, 0.115 * bw - x)
        return np.minimum(neck, armh)
    s.paint({SHIRT}, tank, SKIN, lambda P: tl(P)[:, 1] > 0.3 * h)
    # tanquinho marcado na regata
    for i in range(3):
        y = (0.15 + i * 0.065) * h
        s.tube(ft, [s.surf(ft, (x, y, 0), (0, 0, -1)) for x in np.linspace(-0.05 * bw, 0.05 * bw, 4)], 0.004, 0,
               k=0.006, op='sub')
    s.tube(ft, [s.surf(ft, (0, y * h, 0), (0, 0, -1)) for y in np.linspace(0.13, 0.31, 4)], 0.004, 0, k=0.006, op='sub')
    gold = pal.fx('gold', GOLD, rough=0.3)
    cs, cf, pts = chain(m, s, ft, 0.56 * h, 0.11, 0.13, 0.0042, gold, n=19)
    p = pts[len(pts) // 2] + np.array([0, -0.032, -0.005])
    cs.box(cf, p, (0.02, 0.026, 0.005), 0.004, gold, op='hard')
    cs.box(cf, p + np.array([0, 0, -0.005]), (0.012, 0.018, 0.002), 0.002, gold, k=0.002, op='sub')
    cs.torus(cf, p + np.array([0, 0.03, 0]), 0.006, 0.0022, gold, axis='z', op='hard')
    # munhequeira vermelha, bracelete de ouro, tribal no braço esquerdo
    s.cone(F['fore_r'], (0, -0.155, 0), (0, -0.205, 0), 0.047, 0.045, pal.fx('wristband', (0.85, 0.15, 0.15)), op='hard')
    s.torus(F['fore_l'], (0, -0.19, 0), 0.042, 0.008, gold, op='hard')
    fa = F['arm_l']
    tribal = pal.fx('tribal', (0.12, 0.12, 0.16))
    for i in range(4):
        y0 = -0.07 - i * 0.035

        def fld(P, y0=y0):
            L = fa.to_local(P)
            return np.abs(L[:, 1] - y0 - 0.008 * np.sin(np.arctan2(L[:, 2], L[:, 0]) * 6)) - 0.005
        s.paint({SKIN}, fld, tribal, lambda P: (fa.to_local(P)[:, 1] < -0.04) & (fa.to_local(P)[:, 1] > -0.22))
    m.anchor('tattoo', 'arm_r', s.surf(F['arm_r'], (0, -0.13, 0), (0, 0, -1), out=0.002))
    # calça cargo + coturno
    pants_legs(m, s, F)
    for sd, side in (('l', -1), ('r', 1)):
        fl = F['leg_' + sd]
        s.box(fl, (side * 0.082, -0.25, 0), (0.012, 0.055, 0.045), 0.008, PANTS_DARK, k=0.005)
        s.box(fl, (side * 0.086, -0.2, 0), (0.012, 0.014, 0.047), 0.005, PANTS_DARK, op='hard')
        boot(m, s, F['knee_' + sd], (0.13, 0.1, 0.08))
    m.part('body', None, s, True)

    hs_ = m.sculpt(0.003)
    Fh, r, hs, fy, fz = head_base(m, hs_)
    sc = np.array([0, r, 0])
    # cabelo raspado (pintado) + boné aba reta virado pra trás
    hs_.paint({SKIN}, lambda P: (fy + 0.12) - P[:, 1] + P[:, 2] * 0.3, HAIR_SKIN)
    cap_col = pal.fx('cap', [(0.85, 0.15, 0.15), (0.15, 0.4, 0.85)], group='cap')
    cap_dark = pal.fx('cap_dark', [(0.6, 0.1, 0.1), (0.1, 0.27, 0.6)], group='cap')
    fc = Frame(rot_x(0.25), sc)
    rr = (r * hs[0] * 1.045, r * hs[1] * 1.045, r * hs[2] * 1.045)
    e = r * hs[1] * 1.045 * math.sin(math.radians(24))

    def capf(Q):
        q = Q / np.array(rr)
        d = (np.sqrt(np.einsum('ij,ij->i', q, q)) - 1.0) * min(rr)
        return np.maximum(d, (e - 0.0) - Q[:, 1])
    hs_.custom(fc, capf, (-rr[0], e, -rr[2]), (rr[0], rr[1], rr[2]), cap_col, k=0.004)
    hs_.cyl(fc, (0, e + 0.008, 0), r * hs[0] * 1.06 * math.cos(math.radians(24)), 0.012, 0.006, cap_dark, op='hard')
    hs_.box(fc, (0, e + 0.01, r * hs[2] + 0.065), (0.12, 0.008, 0.075), 0.007, cap_col, op='hard')
    hs_.cyl(fc, (0, rr[1] + 0.002, 0), 0.016, 0.006, 0.004, cap_dark, op='hard')
    hs_.box(fc, (0, e + 0.05, -r * hs[2] * 0.98), (0.05, 0.007, 0.01), 0.004, pal.fx('dark', DARK), op='hard')
    # barba por fazer, cicatriz, brinco de argola
    hs_.paint({SKIN}, lambda P: np.maximum(P[:, 1] - (fy - 0.15) - np.abs(P[:, 0]) * 0.5, P[:, 2] - (fz + 0.12)), SKIN_DARK)
    scar = pal.fx('scar', (0.85, 0.45, 0.45))
    a = hs_.surf(Fh, (0.16, fy - 0.03, 0), (0, 0, -1))
    b = hs_.surf(Fh, (0.19, fy - 0.1, 0), (0, 0, -1))
    seg = lambda P: _seg_dist(P, a, b) - 0.004
    hs_.paint({SKIN, SKIN_DARK}, seg, scar)
    for k in range(3):
        c = a + (b - a) * (0.25 + k * 0.25)
        hs_.paint({SKIN, SKIN_DARK}, (lambda c_: lambda P: _seg_dist(P, c_ - np.array([0.012, -0.005, 0]), c_ + np.array([0.012, -0.005, 0])) - 0.0028)(c), scar)
    hs_.torus(Fh, (-r * hs[0] * 1.0, fy - 0.075, -0.005), 0.016, 0.004, pal.fx('gold', GOLD, rough=0.3), axis='x', op='hard')
    face_nodes(m, hs_, Fh, r, hs, fy, fz)
    m.part('head', 'head', hs_)


def _seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def open_collar(m, s, ft, h, bw, color, v_y):
    """Gola de camisa aberta em V com o peito de fora."""
    tl = (lambda P: ft.to_local(P))
    s.paint({SHIRT}, lambda P: (v_y + 2.2 * np.abs(tl(P)[:, 0])) - tl(P)[:, 1], SKIN,
            lambda P: (tl(P)[:, 2] < 0) & (tl(P)[:, 1] > 0.3 * h))
    for sd in (-1, 1):
        p = s.surf(ft, (sd * 0.06 * bw, 0.53 * h, 0), (0, 0, -1), out=0.004)
        fc = ft.child(euler(0.55, sd * 0.45, sd * -0.6), p)
        s.box(fc, (0, 0, 0), (0.05, 0.007, 0.038), 0.006, color, op='hard')


def model_falante(m, F):
    pp = m.pp
    h, bw = pp['h'], pp['bw']
    pal = m.pal
    s = m.sculpt(0.0045)
    ft = F['torso']
    torso_base(m, s, F)
    arms(m, s, F, 1)
    tl = (lambda P: ft.to_local(P))
    open_collar(m, s, ft, h, bw, SHIRT_LIGHT, 0.48 * h)
    # carcela, botões, bolso com caneta
    s.paint({SHIRT}, lambda P: np.abs(tl(P)[:, 0]) - 0.016, SHIRT_DARK,
            lambda P: (tl(P)[:, 2] < 0) & (tl(P)[:, 1] > 0.08) & (tl(P)[:, 1] < 0.47 * h))
    white = pal.fx('white', WHITE)
    for i in range(4):
        p = s.surf(ft, (0, (0.42 - i * 0.085) * h, 0), (0, 0, -1), out=0.002)
        s.ell(ft, p, (0.009, 0.009, 0.005), white, op='hard')
    pk = s.surf(ft, (-0.09 * bw, 0.38 * h, 0), (0, 0, -1))
    s.box(ft, pk, (0.036, 0.042, 0.006), 0.004, SHIRT_DARK, k=0.003)
    s.cone(ft, pk + np.array([0.018, 0.02, -0.008]), pk + np.array([0.018, 0.07, -0.008]), 0.006, 0.006,
           pal.fx('pen', (0.15, 0.3, 0.8)), op='hard')
    # estampa havaiana: flores e folhas
    petal = pal.fx('petal', (1.0, 0.92, 0.35))
    core = pal.fx('flower_core', (0.95, 0.5, 0.1))
    leaf = pal.fx('leaf', (0.12, 0.45, 0.2))
    petals, cores, leaves = [], [], []
    for i in range(10):
        a = i * 2.1
        x = math.cos(a) * 0.14 * bw
        if abs(x) < 0.035:
            x += 0.07
        y = (0.12 + (i % 4) * 0.1) * h
        back = i >= 6
        c = s.surf(ft, (x, y, 0), (0, 0, 1 if back else -1))
        cores.append(ft.to_world(c))
        for k in range(5):
            b = a + k * math.tau / 5
            petals.append(ft.to_world(c + np.array([math.cos(b) * 0.017, math.sin(b) * 0.017, 0])))
        leaves.append(ft.to_world(c + np.array([math.cos(a) * 0.035, math.sin(a) * 0.035, 0])))
    s.paint({SHIRT}, dots(leaves, 0.014), leaf, lambda P: tl(P)[:, 1] > 0.08)
    s.paint({SHIRT, leaf}, dots(petals, 0.012), petal, lambda P: tl(P)[:, 1] > 0.08)
    s.paint({SHIRT, petal}, dots(cores, 0.008), core)
    # relógio digital
    ff = F['fore_l']
    s.torus(ff, (0, -0.19, 0), 0.032, 0.009, pal.fx('dark', DARK), op='hard')
    s.box(ff, (0, -0.19, -0.038), (0.014, 0.014, 0.006), 0.003, pal.fx('lcd', (0.55, 0.85, 0.55), emission=0.4), op='hard')
    pants_legs(m, s, F)
    for sd in ('l', 'r'):
        shoe(m, s, F['knee_' + sd], 'dress', (0.35, 0.2, 0.1))
    m.part('body', None, s, True)

    hs_ = m.sculpt(0.003)
    Fh, r, hs, fy, fz = head_base(m, hs_)
    # cabelo com topete alto em mechas + costeletas
    rr = (r * hs[0] * 1.03, r * hs[1] * 1.03, r * hs[2] * 1.03)
    fc = Frame(rot_x(0.35), (0, r, 0))
    e = r * hs[1] * 1.03 * math.sin(math.radians(30))

    def hairf(Q):
        q = Q / np.array(rr)
        d = (np.sqrt(np.einsum('ij,ij->i', q, q)) - 1.0) * min(rr)
        return np.maximum(d, e - Q[:, 1])
    hs_.custom(fc, hairf, (-rr[0], e, -rr[2]), rr, HAIR, k=0.012)
    for i in range(5):
        tt = i / 4
        pos = (-0.08 + 0.18 * tt, r + r * hs[1] * (0.72 + math.sin(tt * math.pi) * 0.17), -r * 0.35 + r * 0.55 * tt)
        hs_.ell(Fh, pos, (r * (0.42 - tt * 0.12) * 1.25, r * (0.42 - tt * 0.12) * 0.7, r * (0.42 - tt * 0.12) * 1.05), HAIR, k=0.04)
    hs_.ell(Fh, (-0.1, r + r * hs[1] * 0.83, -r * 0.5), (0.075, 0.058, 0.07), HAIR, k=0.03)
    for sd in (-1, 1):
        hs_.ell(Fh, (sd * r * hs[0] * 0.95, fy + 0.03, -0.05), (0.016, 0.06, 0.04), HAIR, k=0.012)
    # óculos de aro grosso
    eye_x = 0.075 * hs[0]
    dark = pal.fx('dark', DARK)
    for sd in (-1, 1):
        lc = np.array([sd * eye_x, fy + 0.05, fz - EYE_R * 0.8 - 0.008])
        hs_.torus(Fh, lc, eye_x * 0.93, eye_x * 0.075, dark, axis='z', op='hard')
        ear = np.array([sd * r * hs[0] * 0.98, fy + 0.03, 0.0])
        hs_.tube(Fh, [lc + np.array([sd * eye_x, 0, 0]), lc + np.array([sd * (eye_x + 0.025), 0.0, 0.03]), ear], 0.0055,
                 dark, op='hard')
    face_nodes(m, hs_, Fh, r, hs, fy, fz)
    m.part('head', 'head', hs_)


def model_fofoqueira(m, F):
    pp = m.pp
    h, bw = pp['h'], pp['bw']
    pal = m.pal
    s = m.sculpt(0.0045)
    ft = F['torso']
    torso_base(m, s, F, belt=False, hem=False)
    arms(m, s, F, 2)
    for sd in ('l', 'r'):
        s.ell(F['arm_' + sd], (0, -0.05, 0), (0.078, 0.07, 0.078), SHIRT_LIGHT, k=0.02)
    tl = (lambda P: ft.to_local(P))
    # decote redondo com babado e colar de pérolas
    s.paint({SHIRT}, lambda P: (0.47 * h + 2.4 * tl(P)[:, 0] ** 2) - tl(P)[:, 1], SKIN,
            lambda P: (tl(P)[:, 2] < 0.02) & (tl(P)[:, 1] > 0.3 * h))
    for i in range(11):
        a = -1.15 + 2.3 * i / 10
        x = math.sin(a) * 0.15
        y = 0.47 * h + 2.4 * x * x - 0.006
        p = s.surf(ft, (x * 0.6, y, 0), (x * 0.4, 0, -0.25), out=-0.004)
        s.ell(ft, p, (0.026, 0.02, 0.016), SHIRT_LIGHT, k=0.012)
    chain(m, s, ft, 0.55 * h, 0.075, 0.07, 0.0085, pal.fx('pearl', (1.0, 0.98, 0.92), rough=0.25), n=15, beads=True)
    # saia rodada (cós + bolinhas), meia-calça e scarpin
    skirt = PANTS
    rx = 0.2 * pp['hip'] * bw * 1.06
    rb = 0.3 * bw * 1.05
    zs = 0.85
    def skirt_w(P):
        # cintura presa no tronco; a frente da barra acompanha as coxas (metade de cada
        # lado) e a parte de trás fica pendurada com o tronco
        L = ft.to_local(P)
        t = np.clip((0.02 - L[:, 1]) / 0.3, 0.0, 1.0)
        t = t * t * (3 - 2 * t) * np.clip(0.6 - L[:, 2] / 0.12, 0.15, 1.0)
        sl = np.clip(0.5 - L[:, 0] / 0.12, 0.0, 1.0)
        return {'torso': 1.0 - t, 'leg_l': t * sl, 'leg_r': t * (1.0 - sl)}
    s.custom(ft, f_capcone((0, -0.125, 0), 0.235, rb, rx, 0.012, zs), (-rb, -0.36, -rb), (rb, 0.11, rb), skirt,
             op='hard', bone=skirt_w)
    s.paint({skirt}, lambda P: (ft.to_local(P)[:, 1] + 0.33), PANTS_DARK)
    s.cone(ft, (0, 0.085, 0), (0, 0.13, 0), rx + 0.006, rx + 0.004, PANTS_DARK, op='hard')
    polka = []
    for i in range(16):
        a = i * 1.3
        y = -0.03 - (i % 4) * 0.075
        rad = rx + (rb - rx) * (0.11 - y) / 0.47
        polka.append(ft.to_world((math.sin(a) * rad, y, -math.cos(a) * rad * zs)))
    s.paint({skirt}, dots(polka, 0.014), pal.fx('polka', (1.0, 0.96, 0.9)))
    for sd in ('l', 'r'):
        fl, fk = F['leg_' + sd], F['knee_' + sd]
        s.cone(fl, (0, -0.15, 0), (0, -THIGH, 0), 0.06, 0.052, SKIN_DARK, k=0.02)
        s.cone(fk, (0, 0, 0), (0, -0.37, 0), 0.05, 0.04, SKIN_DARK, k=0.03)
        red = pal.fx('heel', (0.8, 0.12, 0.15), rough=0.3)
        fh = fk.child(rot_x(-0.18), (0, -0.385, -0.05))
        s.ell(fh, (0, 0, 0), (0.042, 0.035, 0.1), red, k=0.02)
        s.ell(fk, (0, -0.37, -0.03), (0.04, 0.02, 0.055), SKIN_DARK, k=0.02)
        s.cone(fk, (0, -0.39, 0.035), (0, -0.428, 0.04), 0.012, 0.008, pal.fx('heel_tip', (0.45, 0.07, 0.09)), op='hard')
    # pulseiras e bolsa no ombro
    ff = F['fore_l']
    for i, col in enumerate([GOLD, (0.9, 0.3, 0.5), (0.3, 0.7, 0.9)]):
        s.torus(ff, (0, -0.172 - i * 0.017, 0), 0.04, 0.0065, pal.fx('bracelet%d' % i, col, rough=0.3), op='hard')
    bag = pal.fx('bag', (0.85, 0.65, 0.2))
    fb = ft.child(rot_z(0.1), (0.27 * bw, 0.12, 0.05))
    s.box(fb, (0, 0, 0), (0.085, 0.062, 0.032), 0.02, bag, op='hard')
    s.box(fb, (0, 0.04, -0.001), (0.087, 0.026, 0.034), 0.015, pal.fx('bag_flap', (0.68, 0.5, 0.14)), op='hard')
    s.ell(fb, (0, 0.022, -0.036), 0.009, pal.fx('gold', GOLD, rough=0.3), op='hard')
    s.tube(ft, [(0.24 * bw, 0.18, 0.05), (0.2 * bw, 0.4 * h, 0.1), (0.15 * bw, 0.53 * h, 0.06)], 0.008,
           pal.fx('bag_strap', (0.55, 0.38, 0.1)), op='hard')
    m.part('body', None, s, True)

    hs_ = m.sculpt(0.003)
    Fh, r, hs, fy, fz = head_base(m, hs_)
    # cabelão armado em cachos com coque, franja, bobes, argolas e pinta
    for i in range(18):
        a = i * math.tau / 18
        if math.sin(a) < -0.55:
            continue
        y = r * 1.0 + math.sin(a * 2.0) * 0.06 + 0.12
        hs_.ell(Fh, (math.cos(a) * r * 1.0, y, math.sin(a) * r * 0.95 + 0.04), 0.11, HAIR, k=0.03)
    for i in range(10):
        a = i * math.tau / 10 + 0.3
        if math.sin(a) < -0.3:
            continue
        hs_.ell(Fh, (math.cos(a) * r * 1.08, r * 0.82 + (i % 2) * 0.04, math.sin(a) * r * 0.95 + 0.06), 0.06, HAIR, k=0.025)
    hs_.ell(Fh, (0, r + r * hs[1] * 0.43, 0.03), r * 0.9, HAIR, k=0.04)
    for i in range(4):
        hs_.ell(Fh, (-0.1 + i * 0.065, r + r * hs[1] * 0.71, fz + 0.075 + abs(i - 1.5) * 0.02), (0.066, 0.048, 0.048), HAIR, k=0.03)
    cols = [(1.0, 0.55, 0.7), (0.45, 0.75, 1.0), (1.0, 0.85, 0.3)]
    for i in range(5):
        pos = (-0.16 + i * 0.08, r + r * hs[1] * 0.9 - abs(i - 2) * 0.03, 0.04 + abs(i - 2) * 0.03)
        hs_.cyl(Fh, pos, 0.035, 0.055, 0.012, pal.fx('roller%d' % (i % 3), cols[i % 3]), axis='x', op='hard')
    for sd in (-1, 1):
        hs_.torus(Fh, (sd * r * hs[0] * 1.0, fy - 0.1, -0.005), 0.034, 0.006, pal.fx('gold', GOLD, rough=0.3), axis='x', op='hard')
    hs_.ell(Fh, hs_.surf(Fh, (0.085, fy - 0.1, 0), (0, 0, -1)), 0.008, pal.fx('mole', (0.15, 0.08, 0.05)), op='hard')
    face_nodes(m, hs_, Fh, r, hs, fy, fz)
    m.part('head', 'head', hs_)

    def nails(s2, F2, tips, sc):
        s2.paint({SKIN}, dots(tips, 0.009 * sc), pal.fx('nail', (0.85, 0.1, 0.25), rough=0.25))
    m.hand_extras = nails


def model_universitario(m, F):
    pp = m.pp
    h, bw = pp['h'], pp['bw']
    pal = m.pal
    s = m.sculpt(0.0045)
    ft = F['torso']
    torso_base(m, s, F, belt=False, hem=False)
    tl = (lambda P: ft.to_local(P))
    # moletom cobre o cós: barra canelada
    s.paint({PANTS}, lambda P: -(tl(P)[:, 1] + 0.035), SHIRT,
            lambda P: (np.abs(tl(P)[:, 0]) < 0.3 * pp['bw']) & (tl(P)[:, 1] > -0.1))
    band(m, s, ft, -0.02, 0.028, 0.006, SHIRT_DARK, rnd=0.008)
    arms(m, s, F, 2)
    # capuz embolado nas costas, cordinhas, bolso canguru
    s.torus(ft.child(rot_x(-0.45), (0, 0.565 * h, 0.06)), (0, 0, 0), 0.09, 0.045, SHIRT_DARK, k=0.02)
    s.ell(ft, (0, 0.53 * h, 0.15), (0.13, 0.09, 0.06), SHIRT_DARK, k=0.03)
    white = pal.fx('white', WHITE)
    for sd in (-1, 1):
        top = s.surf(ft, (sd * 0.035, 0.53 * h, 0), (0, 0, -1), out=0.006)
        bot = s.surf(ft, (sd * 0.042, 0.4 * h, 0), (0, 0, -1), out=0.007)
        s.tube(ft, [top, bot], 0.0055, white, op='hard')
        s.ell(ft, bot + np.array([0, -0.008, 0]), 0.009, white, op='hard')
    pk = s.surf(ft, (0, 0.16 * h, 0), (0, 0, -1))
    s.box(ft, pk, (0.12 * bw, 0.055, 0.008), 0.008, SHIRT_DARK, k=0.004)
    m.anchor('ufpz', 'torso', s.surf(ft, (0, 0.37 * h, 0), (0, 0, -1), out=0.003))
    # mochila: corpo, bolso com zíper, alças por cima dos ombros
    pack = pal.fx('pack', [(0.2, 0.3, 0.55), (0.15, 0.15, 0.17), (0.7, 0.25, 0.2)], group='pack')
    pack_l = pal.fx('pack_light', [(0.26, 0.37, 0.62), (0.21, 0.21, 0.23), (0.77, 0.32, 0.27)], group='pack')
    pack_d = pal.fx('pack_dark', [(0.13, 0.2, 0.38), (0.09, 0.09, 0.1), (0.48, 0.16, 0.13)], group='pack')
    zb = s.surf(ft, (0, 0.33 * h, 0), (0, 0, 1))[2]
    s.box(ft, (0, 0.33 * h, zb + 0.075), (0.15 * bw, 0.18, 0.075), 0.035, pack, op='hard')
    s.box(ft, (0, 0.24 * h, zb + 0.16), (0.11 * bw, 0.07, 0.028), 0.02, pack_l, op='hard')
    s.paint({pack_l}, (lambda P: np.abs(tl(P)[:, 1] - 0.29 * h) - 0.004), pal.fx('zip', (0.75, 0.75, 0.78)),
            lambda P: tl(P)[:, 2] > zb + 0.17)
    for sd in (-1, 1):
        x = sd * 0.1 * bw
        a = s.surf(ft, (x, 0.2 * h, 0), (0, 0, -1), out=0.006)
        b = s.surf(ft, (x, 0.47 * h, 0), (0, 0, -1), out=0.008)
        top = s.surf(ft, (x, 0.5 * h, 0), (0, 1, 0), out=0.008)
        c = np.array([x, 0.5 * h, zb + 0.02])
        s.tube(ft, [a, b, top, c], 0.016, pack_d, op='hard', join=0.01)
    # fones no pescoço
    dark = pal.fx('dark', DARK)
    s.torus(ft, (0, 0.62 * h, 0.0), 0.085, 0.01, dark, op='hard')
    for sd in (-1, 1):
        s.cyl(ft, (sd * 0.088, 0.6 * h, -0.035), 0.04, 0.016, 0.008, dark, axis='x', op='hard')
        s.cyl(ft, (sd * 0.07, 0.6 * h, -0.035), 0.028, 0.004, 0.003, pal.fx('stripe_red', (0.85, 0.2, 0.2)), axis='x', op='hard')
    pants_legs(m, s, F)
    for sd in ('l', 'r'):
        shoe(m, s, F['knee_' + sd], 'sneaker', (0.95, 0.95, 0.95), sole=(0.96, 0.96, 0.96))
    m.part('body', None, s, True)

    hs_ = m.sculpt(0.003)
    Fh, r, hs, fy, fz = head_base(m, hs_)
    # touca canelada com pompom, costeletas, cavanhaque, bigodinho e olheiras
    beanie = pal.fx('beanie', [(0.85, 0.2, 0.2), (0.95, 0.75, 0.15), (0.2, 0.55, 0.35)], group='beanie')
    beanie_d = pal.fx('beanie_dark', [(0.66, 0.14, 0.14), (0.75, 0.57, 0.1), (0.14, 0.42, 0.26)], group='beanie')
    fc = Frame(rot_x(0.3), (0, r, 0))
    rr = (r * hs[0] * 1.06, r * hs[1] * 1.06 * 1.15, r * hs[2] * 1.06)
    e = rr[1] * math.sin(math.radians(20)) * 0.9

    def bean(Q):
        q = Q / np.array(rr)
        d = (np.sqrt(np.einsum('ij,ij->i', q, q)) - 1.0) * min(rr)
        return np.maximum(d, e - Q[:, 1])
    hs_.custom(fc, bean, (-rr[0], e, -rr[2]), rr, beanie, k=0.004)
    cr = r * max(hs[0], hs[2]) * 1.06 * math.cos(math.radians(20)) + 0.013
    hs_.cyl(fc, (0, e + 0.032, 0), cr, 0.036, 0.016, beanie_d, op='hard')
    yc = e + 0.032

    def ribs(Q):
        rho = np.sqrt(Q[:, 0] ** 2 + Q[:, 2] ** 2)
        arc = np.abs(np.sin(np.arctan2(Q[:, 2], Q[:, 0]) * 24)) * cr / 24
        return np.maximum(np.maximum(np.abs(rho - cr) - 0.006, np.abs(Q[:, 1] - yc) - 0.03), arc - 0.0025)
    hs_.custom(fc, ribs, (-cr - 0.01, yc - 0.04, -cr - 0.01), (cr + 0.01, yc + 0.04, cr + 0.01), 0, k=0.002, op='sub')
    hs_.ell(fc, (0, rr[1] + 0.035, 0), 0.05, pal.fx('white', WHITE), k=0.01)
    for sd in (-1, 1):
        hs_.ell(Fh, (sd * r * hs[0] * 0.95, fy + 0.05, -0.03), (0.016, 0.06, 0.04), HAIR, k=0.012)
        eye_x = 0.075 * hs[0]
        c = hs_.surf(Fh, (sd * eye_x, fy + 0.05 - EYE_R * 1.05, 0), (0, 0, -1))
        hs_.paint({SKIN}, ell_dots([c], (0.04, 0.014, 0.03)), SKIN_DARK)
    hs_.ell(Fh, hs_.surf(Fh, (0, fy - 0.2, 0), (0, 0, -1)), (0.026, 0.034, 0.02), HAIR, k=0.012)
    for sd in (-1, 1):
        hs_.ell(Fh, hs_.surf(Fh, (sd * 0.032, fy - 0.1, 0), (0, 0, -1)), (0.02, 0.007, 0.008), HAIR, k=0.004)
    face_nodes(m, hs_, Fh, r, hs, fy, fz)
    m.part('head', 'head', hs_)
    # celular na mão esquerda
    m.node('prop', 'hand_l', rot_y(-math.pi / 2), (0.04, -0.08, -0.01))
    ps = m.sculpt(0.0018)
    Fp = Frame()
    ps.box(Fp, (0, 0, 0), (0.035, 0.065, 0.006), 0.005, dark)
    ps.box(Fp, (0, 0, -0.0045), (0.03, 0.057, 0.0025), 0.002, pal.fx('screen', (0.45, 0.75, 1.0), emission=1.5), op='hard')
    for i in range(3):
        ps.box(Fp, (0, 0.035 - i * 0.025, -0.0068), (0.022, 0.006, 0.001), 0.0008, pal.fx('screen_row', (1, 1, 1), emission=1.0), op='hard')
    m.part('phone', 'prop', ps, tris=500)


def model_malandro(m, F):
    pp = m.pp
    h, bw = pp['h'], pp['bw']
    pal = m.pal
    s = m.sculpt(0.0045)
    ft = F['torso']
    torso_base(m, s, F)
    arms(m, s, F, 1)
    tl = (lambda P: ft.to_local(P))
    white = pal.fx('white', (0.97, 0.97, 0.95))
    open_collar(m, s, ft, h, bw, white, 0.47 * h)
    # camisa listrada (tronco e mangas)
    s.paint({SHIRT}, lambda P: np.sin((P[:, 1] - HIP_Y - 0.1) * math.tau / 0.075), white,
            lambda P: P[:, 1] > HIP_Y + 0.085)
    gold = pal.fx('gold', GOLD, rough=0.3)
    chain(m, s, ft, 0.53 * h, 0.065, 0.1, 0.0024, gold, n=17)
    pk = s.surf(ft, (-0.1 * bw, 0.4 * h, 0), (0, 0, -1))
    s.box(ft, pk, (0.035, 0.035, 0.006), 0.004, SHIRT_DARK, k=0.003)
    for k in range(3):
        a = pk + np.array([-0.018 + k * 0.018, 0.035 + (k % 2) * 0.008, -0.006])
        fk_ = ft.child(rot_z((k - 1) * 0.4), a)
        s.box(fk_, (0, 0, 0), (0.009, 0.017, 0.003), 0.0025, pal.fx('hanky', (0.95, 0.85, 0.2)), op='hard')
    ff = F['fore_l']
    s.torus(ff, (0, -0.19, 0), 0.034, 0.009, gold, op='hard')
    s.cyl(ff, (0, -0.19, -0.04), 0.018, 0.005, 0.002, pal.fx('watch_face', WHITE), axis='z', op='hard')
    pants_legs(m, s, F)
    for sd in ('l', 'r'):
        shoe(m, s, F['knee_' + sd], 'dress', (0.98, 0.98, 0.96))
    m.part('body', None, s, True)

    hs_ = m.sculpt(0.003)
    Fh, r, hs, fy, fz = head_base(m, hs_)
    # cabelo na régua (casquete), costeletas e bigodinho fino
    rr = (r * hs[0] * 1.015, r * hs[1] * 1.015, r * hs[2] * 1.015)
    fc = Frame(rot_x(0.3), (0, r, 0))
    e = rr[1] * math.sin(math.radians(33))

    def slick(Q):
        q = Q / np.array(rr)
        d = (np.sqrt(np.einsum('ij,ij->i', q, q)) - 1.0) * min(rr)
        return np.maximum(d, e - Q[:, 1])
    hs_.custom(fc, slick, (-rr[0], e, -rr[2]), rr, HAIR, k=0.006)
    for sd in (-1, 1):
        hs_.ell(Fh, (sd * r * hs[0] * 0.93, fy + 0.04, -0.045), (0.01, 0.035, 0.02), HAIR, k=0.015)
    a = hs_.surf(Fh, (-0.05, fy - 0.098, 0), (0, 0, -1), out=0.002)
    b = hs_.surf(Fh, (0.05, fy - 0.098, 0), (0, 0, -1), out=0.002)
    c = hs_.surf(Fh, (0, fy - 0.093, 0), (0, 0, -1), out=0.002)
    hs_.tube(Fh, [a, c, b], [0.004, 0.0075, 0.004], HAIR, k=0.004, join=0.006)
    face_nodes(m, hs_, Fh, r, hs, fy, fz)
    m.part('head', 'head', hs_)
    # chapéu panamá com fita
    m.node('hat', 'head', rot_z(0.12), (0, r + r * hs[1] * 0.55, 0))
    hs2 = m.sculpt(0.002)
    Fp = Frame()
    straw = pal.fx('straw', (0.97, 0.94, 0.85))
    # aba levemente virada para cima nas laterais, copa baixa com vinco em cima
    def brim(Q):
        rr_ = np.sqrt(Q[:, 0] ** 2 + Q[:, 2] ** 2)
        y = Q[:, 1] - 0.006 - np.maximum(rr_ - r * 0.95, 0.0) ** 2 * 0.5 * (Q[:, 0] ** 2 / np.maximum(rr_ ** 2, 1e-9))
        dx = rr_ - r * 1.42 + 0.009
        dy = np.abs(y) - 0.01 + 0.009
        return np.minimum(np.maximum(dx, dy), 0.0) + np.sqrt(np.maximum(dx, 0) ** 2 + np.maximum(dy, 0) ** 2) - 0.009
    hs2.custom(Fp, brim, (-r * 1.45, -0.01, -r * 1.45), (r * 1.45, 0.06, r * 1.45), straw)
    hs2.custom(Fp, f_capcone((0, 0.08, 0), 0.075, r * 0.86, r * 0.74, 0.03), (-r * 0.87, 0.0, -r * 0.87),
               (r * 0.87, 0.16, r * 0.87), straw, k=0.025)
    hs2.ell(Fp, (0, 0.166, 0), (0.035, 0.018, 0.11), 0, k=0.025, op='sub')
    hs2.paint({straw}, lambda P: np.abs(P[:, 1] - 0.03) - 0.015, pal.fx('hat_band', (0.1, 0.08, 0.08)),
              lambda P: np.sqrt(P[:, 0] ** 2 + P[:, 2] ** 2) < r * 0.93)
    m.part('panama', 'hat', hs2, tris=6000)
    m.ring = True


MODELS = {
    'tiozao': model_tiozao, 'valentao': model_valentao, 'falante': model_falante,
    'fofoqueira': model_fofoqueira, 'universitario': model_universitario, 'malandro': model_malandro,
}


def build(pid):
    m = Model(pid)
    m.hand_extras = None
    m.ring = False
    F = build_skeleton(m)
    MODELS[pid](m, F)
    for sd, side in (('l', -1), ('r', 1)):
        extras = m.hand_extras
        if m.ring and sd == 'r':
            def extras(s2, F2, tips, sc, pal=m.pal):
                s2.torus(F2, (0.0, -0.088 * sc, -0.033 * sc), 0.0135 * sc, 0.0035, pal.fx('gold', GOLD, rough=0.3), op='hard')
        m.part('hand_' + sd, 'hand_' + sd, hand_part(m, side, extras))
    return m


# ================================================================== arquivo

def _str(b, s):
    e = s.encode('utf-8')
    b += struct.pack('<B', len(e)) + e


def write(m, out_dir=OUT_DIR):
    bones = [n[0] for n in m.nodes if n[4]]
    names = [n[0] for n in m.nodes]
    b = bytearray(b'PGC1')
    b += struct.pack('<H', len(m.nodes))
    for name, parent, R, t, is_bone, Rb in m.nodes:
        _str(b, name)
        b += struct.pack('<hB', names.index(parent) if parent else -1, 1 if is_bone else 0)
        b += struct.pack('<12f', *R[:, 0], *R[:, 1], *R[:, 2], *t)
        b += struct.pack('<12f', *Rb[:, 0], *Rb[:, 1], *Rb[:, 2], *t)
    b += struct.pack('<H', len(m.anchors))
    for name, node, pos, nrm in m.anchors:
        _str(b, name)
        b += struct.pack('<h6f', names.index(node), *pos, *nrm)
    b += struct.pack('<H', len(m.pal.entries))
    for e in m.pal.entries:
        _str(b, e['group'])
        b += struct.pack('<ffB', e['emission'], e['rough'], len(e['colors']))
        for c in e['colors']:
            b += struct.pack('<3f', *c)
    b += struct.pack('<H', len(m.parts))
    tris = 0
    adj = {(n[1], n[0]) for n in m.nodes if n[4] and n[1]} | {('torso', 'leg_l'), ('torso', 'leg_r')}
    for name, node, s, skinned, target in m.parts:
        s.adjacent = adj
        surfs = s.bake(bones if skinned else None, target)
        _str(b, name)
        b += struct.pack('<hBB', names.index(node) if node else -1, 1 if skinned else 0, len(surfs))
        for sf in surfs:
            nv, ni = len(sf['verts']), len(sf['idx'])
            tris += ni // 3
            b += struct.pack('<BII', sf['region'], nv, ni)
            b += sf['verts'].astype('<f4').tobytes() + sf['normals'].astype('<f4').tobytes()
            if skinned:
                b += sf['bones'].astype('<i4').tobytes() + sf['weights'].astype('<f4').tobytes()
            b += sf['idx'].astype('<i4').tobytes()
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, m.pid + '.bin')
    with open(path, 'wb') as f:
        f.write(gzip.compress(bytes(b), 9, mtime=0))
    print('%-14s %7d triângulos  %6.0f KB' % (m.pid, tris, os.path.getsize(path) / 1024))


def main():
    ids = [a for a in sys.argv[1:] if not a.startswith('--')] or list(PROFILES)
    for pid in ids:
        write(build(pid))


if __name__ == '__main__':
    main()
