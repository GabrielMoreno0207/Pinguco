"""Escultura por campo de distância (SDF) -> malha contínua.

Cada peça é a união suave de primitivas (elipsoides, cones arredondados, caixas
arredondadas, toros...). O resultado passa por marching cubes e vira uma malha
única, sem emendas, com:
  - regiões de material por triângulo (pele, camisa, calça...), com bordas de
    pintura recortadas na malha (listras, decote, bolinhas) para ficarem nítidas;
  - decimação por quádricas (malha leve) com os vértices reprojetados na superfície;
  - normais pelo gradiente do campo (sombreado liso);
  - pesos de esqueleto calculados pela distância às primitivas de cada osso.
"""
import math

import fast_simplification
import numpy as np
from skimage.measure import marching_cubes


# ------------------------------------------------------------------ matrizes

def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], float)


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], float)


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], float)


class Frame:
    """Referencial rígido (rotação + origem) dentro do espaço da peça."""

    def __init__(self, R=None, t=(0, 0, 0), bone=None):
        self.R = np.eye(3) if R is None else np.asarray(R, float)
        self.t = np.asarray(t, float)
        self.bone = bone

    def to_local(self, P):
        return (P - self.t) @ self.R

    def to_world(self, L):
        return np.asarray(L, float) @ self.R.T + self.t

    def child(self, R=None, t=(0, 0, 0), bone=None):
        R = np.eye(3) if R is None else np.asarray(R, float)
        return Frame(self.R @ R, self.to_world(t), bone or self.bone)


# ------------------------------------------------------------------ SDFs (coords locais)

def _len(v):
    return np.sqrt(np.einsum('ij,ij->i', v, v))


def f_sphere(c, r):
    c = np.asarray(c, float)
    return lambda Q: _len(Q - c) - r


def f_ell(c, r):
    c = np.asarray(c, float)
    r = np.asarray(r, float)
    rmin = r.min()

    def f(Q):
        q = (Q - c) / r
        k0 = _len(q)
        k1 = _len(q / r)
        d = k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
        return np.where(k0 < 0.5, (k0 - 1.0) * rmin, d)
    return f


def f_cone(a, b, ra, rb):
    """Cone arredondado de `a` (raio ra) até `b` (raio rb)."""
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    ba = b - a
    l2 = float(ba @ ba)
    rr = ra - rb
    a2 = l2 - rr * rr
    il2 = 1.0 / l2

    def f(Q):
        pa = Q - a
        y = pa @ ba
        z = y - l2
        xv = pa * l2 - y[:, None] * ba
        x2 = np.einsum('ij,ij->i', xv, xv)
        y2 = y * y * l2
        z2 = z * z * l2
        k = math.copysign(1.0, rr) * rr * rr * x2 if rr != 0 else np.zeros_like(x2)
        d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - ra
        c1 = np.sign(z) * a2 * z2 > k
        c2 = np.sign(y) * a2 * y2 < k
        return np.where(c1, np.sqrt(x2 + z2) * il2 - rb, np.where(c2, np.sqrt(x2 + y2) * il2 - ra, d3))
    return f


def f_capcone(c, h, r_bottom, r_top, rnd, zscale=1.0):
    """Tronco de cone vertical com tampas retas (meia-altura h) e bordas arredondadas.
    zscale achata a seção (elipse)."""
    c = np.asarray(c, float)
    h, r1, r2 = h - rnd, r_bottom - rnd, r_top - rnd
    k1 = np.array([r2, h])
    k2 = np.array([r2 - r1, 2.0 * h])
    k2d = k2 @ k2

    def f(Q):
        q = Q - c
        qx = np.sqrt(q[:, 0] ** 2 + (q[:, 2] / zscale) ** 2)
        qy = q[:, 1]
        cax = qx - np.minimum(qx, np.where(qy < 0.0, r1, r2))
        cay = np.abs(qy) - h
        t = np.clip(((k1[0] - qx) * k2[0] + (k1[1] - qy) * k2[1]) / k2d, 0.0, 1.0)
        cbx = qx - k1[0] + k2[0] * t
        cby = qy - k1[1] + k2[1] * t
        sgn = np.where((cbx < 0.0) & (cay < 0.0), -1.0, 1.0)
        return sgn * np.sqrt(np.minimum(cax * cax + cay * cay, cbx * cbx + cby * cby)) * min(1.0, zscale) - rnd
    return f


def f_box(c, half, rad):
    c = np.asarray(c, float)
    half = np.asarray(half, float)

    def f(Q):
        q = np.abs(Q - c) - half + rad
        return _len(np.maximum(q, 0.0)) + np.minimum(q.max(axis=1), 0.0) - rad
    return f


def _axis(Q, c, axis):
    q = Q - np.asarray(c, float)
    if axis == 'x':
        return q[:, [1, 0, 2]]
    if axis == 'z':
        return q[:, [0, 2, 1]]
    return q


def f_torus(c, R, r, axis='y'):
    def f(Q):
        q = _axis(Q, c, axis)
        qx = np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - R
        return np.sqrt(qx * qx + q[:, 1] ** 2) - r
    return f


def f_cyl(c, radius, half_h, rnd, axis='y'):
    """Cilindro com bordas arredondadas (raio de arredondamento `rnd`)."""
    def f(Q):
        q = _axis(Q, c, axis)
        dx = np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - radius + rnd
        dy = np.abs(q[:, 1]) - half_h + rnd
        return np.minimum(np.maximum(dx, dy), 0.0) + np.sqrt(np.maximum(dx, 0) ** 2 + np.maximum(dy, 0) ** 2) - rnd
    return f


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


# ------------------------------------------------------------------ escultura

class Prim:
    __slots__ = ('fn', 'lo', 'hi', 'region', 'k', 'op', 'bone')

    def __init__(self, fn, lo, hi, region, k, op, bone):
        self.fn, self.lo, self.hi = fn, lo, hi
        self.region, self.k, self.op, self.bone = region, k, op, bone


class Rule:
    __slots__ = ('targets', 'field', 'region', 'mask')

    def __init__(self, targets, field, region, mask):
        self.targets, self.field, self.region, self.mask = targets, field, region, mask


def _bounds(frame, lo, hi):
    lo = np.asarray(lo, float)
    hi = np.asarray(hi, float)
    corners = np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
    w = frame.to_world(corners)
    return w.min(axis=0), w.max(axis=0)


class Sculpt:
    """Uma peça esculpida. `op`: 'add' (união suave com raio k), 'hard' (união seca)
    ou 'sub' (entalhe suave)."""

    def __init__(self, voxel):
        self.voxel = voxel
        self.prims = []
        self.rules = []

    # --- primitivas
    def _add(self, frame, fn_local, lo, hi, region, k, op, bone):
        fn = (lambda Q, f=fn_local, fr=frame: f(fr.to_local(Q)))
        wlo, whi = _bounds(frame, lo, hi)
        self.prims.append(Prim(fn, wlo, whi, region, k, op, bone or frame.bone))

    def ell(self, fr, c, r, region, k=0.0, op='add', bone=None):
        c = np.asarray(c, float)
        r = np.asarray(r, float) if np.ndim(r) else np.array([r, r, r], float)
        fn = f_sphere(c, r[0]) if r[0] == r[1] == r[2] else f_ell(c, r)
        self._add(fr, fn, c - r, c + r, region, k, op, bone)

    def cone(self, fr, a, b, ra, rb, region, k=0.0, op='add', bone=None):
        a = np.asarray(a, float)
        b = np.asarray(b, float)
        m = max(ra, rb)
        self._add(fr, f_cone(a, b, ra, rb), np.minimum(a, b) - m, np.maximum(a, b) + m, region, k, op, bone)

    def tube(self, fr, pts, radii, region, k=0.0, op='add', bone=None, join=0.0):
        """Cones encadenados (cordões, correntes, sobrancelhas). `join` suaviza as juntas."""
        pts = [np.asarray(p, float) for p in pts]
        if np.ndim(radii) == 0:
            radii = [radii] * len(pts)
        fns = [f_cone(pts[i], pts[i + 1], radii[i], radii[i + 1]) for i in range(len(pts) - 1)]

        def fn(Q):
            d = fns[0](Q)
            for g in fns[1:]:
                d = smin(d, g(Q), join) if join > 0 else np.minimum(d, g(Q))
            return d
        m = max(radii)
        P = np.array(pts)
        self._add(fr, fn, P.min(axis=0) - m, P.max(axis=0) + m, region, k, op, bone)

    def box(self, fr, c, half, rad, region, k=0.0, op='add', bone=None):
        c = np.asarray(c, float)
        half = np.asarray(half, float)
        self._add(fr, f_box(c, half, rad), c - half, c + half, region, k, op, bone)

    def torus(self, fr, c, R, r, region, axis='y', k=0.0, op='add', bone=None):
        c = np.asarray(c, float)
        e = np.array([R + r, r, R + r])
        if axis == 'x':
            e = e[[1, 0, 2]]
        elif axis == 'z':
            e = e[[0, 2, 1]]
        self._add(fr, f_torus(c, R, r, axis), c - e, c + e, region, k, op, bone)

    def cyl(self, fr, c, radius, half_h, rnd, region, axis='y', k=0.0, op='add', bone=None):
        c = np.asarray(c, float)
        e = np.array([radius, half_h, radius])
        if axis == 'x':
            e = e[[1, 0, 2]]
        elif axis == 'z':
            e = e[[0, 2, 1]]
        self._add(fr, f_cyl(c, radius, half_h, rnd, axis), c - e, c + e, region, k, op, bone)

    def custom(self, fr, fn_local, lo, hi, region, k=0.0, op='add', bone=None):
        self._add(fr, fn_local, lo, hi, region, k, op, bone)

    # --- pintura (recortada na malha)
    def paint(self, targets, field, region, mask=None):
        """Triângulos de `targets` onde field(P) < 0 viram `region`. A borda field = 0
        é recortada na malha, então fica reta e nítida."""
        self.rules.append(Rule(set(targets), field, region, mask))

    # --- avaliação
    def eval(self, P, upto=None):
        P = np.asarray(P, float)
        d = np.full(len(P), 1.0)
        for p in (self.prims if upto is None else self.prims[:upto]):
            m = p.k + 0.01
            sel = np.all((P >= p.lo - m) & (P <= p.hi + m), axis=1)
            if not sel.any():
                continue
            di = p.fn(P[sel])
            ds = d[sel]
            if p.op == 'sub':
                d[sel] = smax(ds, -di, p.k) if p.k > 0 else np.maximum(ds, -di)
            elif p.op == 'add' and p.k > 0:
                d[sel] = smin(ds, di, p.k)
            else:
                d[sel] = np.minimum(ds, di)
        return d

    def grad(self, P):
        e = self.voxel * 0.35
        g = np.zeros_like(P)
        for i in range(3):
            o = np.zeros(3)
            o[i] = e
            g[:, i] = self.eval(P + o) - self.eval(P - o)
        n = _len(g)
        return g / np.maximum(n, 1e-12)[:, None]

    def ray(self, fr, origin, direction, maxd=0.5):
        """Ponto (local ao frame) onde o raio a partir de `origin` cruza a superfície."""
        o = np.asarray(origin, float)
        dv = np.asarray(direction, float)
        dv = dv / np.linalg.norm(dv)
        ts = np.arange(0.0, maxd, 0.0015)
        L = o + ts[:, None] * dv
        d = self.eval(fr.to_world(L))
        s = d > 0
        idx = np.nonzero(s[1:] != s[:-1])[0]
        if len(idx) == 0:
            return o
        i = idx[0]
        t = ts[i] + (ts[i + 1] - ts[i]) * d[i] / (d[i] - d[i + 1])
        return o + t * dv

    def surf(self, fr, origin, direction, out=0.0, maxd=0.5):
        dv = np.asarray(direction, float)
        dv = dv / np.linalg.norm(dv)
        return self.ray(fr, origin, dv, maxd) + dv * out

    # --- volume -> malha
    def _volume(self):
        vox = self.voxel
        adds = [p for p in self.prims if p.op != 'sub']
        lo = np.min([p.lo for p in adds], axis=0) - 3 * vox
        hi = np.max([p.hi for p in adds], axis=0) + 3 * vox
        n = np.ceil((hi - lo) / vox).astype(int) + 1
        vol = np.full(n, 1.0, np.float32)
        axes = [lo[i] + np.arange(n[i]) * vox for i in range(3)]
        for p in self.prims:
            m = p.k + 2 * vox
            i0 = np.clip(np.floor((p.lo - m - lo) / vox).astype(int), 0, n)
            i1 = np.clip(np.ceil((p.hi + m - lo) / vox).astype(int) + 1, 0, n)
            if np.any(i1 <= i0):
                continue
            sl = tuple(slice(i0[i], i1[i]) for i in range(3))
            X, Y, Z = np.meshgrid(axes[0][sl[0]], axes[1][sl[1]], axes[2][sl[2]], indexing='ij')
            Q = np.stack([X.ravel(), Y.ravel(), Z.ravel()], axis=1)
            sub = vol[sl]
            di = p.fn(Q).reshape(sub.shape)
            if p.op == 'sub':
                vol[sl] = smax(sub, -di, p.k) if p.k > 0 else np.maximum(sub, -di)
            elif p.op == 'add' and p.k > 0:
                vol[sl] = smin(sub, di, p.k)
            else:
                vol[sl] = np.minimum(sub, di)
        return vol, lo

    def _base_regions(self, C):
        best = np.full(len(C), np.inf)
        reg = np.zeros(len(C), int)
        for p in self.prims:
            if p.op == 'sub':
                continue
            m = p.k + 0.01
            sel = np.nonzero(np.all((C >= p.lo - m) & (C <= p.hi + m), axis=1))[0]
            if len(sel) == 0:
                continue
            d = np.abs(p.fn(C[sel]))
            better = d < best[sel]
            best[sel[better]] = d[better]
            reg[sel[better]] = p.region
        return reg

    def _relax(self, V, F, iters=4):
        """Suavização tangencial: deixa os triângulos mais regulares (sombreado sem
        estrelinhas) e devolve cada vértice para a superfície exata."""
        n = len(V)
        E = np.vstack([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
        E = np.vstack([E, E[:, ::-1]])
        deg = np.bincount(E[:, 0], minlength=n).astype(float)
        for _ in range(2):
            V = V - self.grad(V) * self.eval(V)[:, None]
        for it in range(iters):
            acc = np.zeros_like(V)
            np.add.at(acc, E[:, 0], V[E[:, 1]])
            avg = acc / np.maximum(deg, 1)[:, None]
            Nn = self.grad(V)
            dv = avg - V
            dv -= Nn * np.einsum('ij,ij->i', dv, Nn)[:, None]
            W = V + dv * 0.5
            for _ in range(2):
                W = W - self.grad(W) * self.eval(W)[:, None]
            # em peças finas (abas, bordas) o passo pode cruzar para o outro lado: desfaz
            ok = np.einsum('ij,ij->i', self.grad(W), Nn) > 0.6
            V = np.where(ok[:, None], W, V)
        return V

    def _region_score(self, P, region):
        """Menor |distância| às primitivas de uma região (quem "veste" o ponto)."""
        best = np.full(len(P), 1e3)
        for p in self.prims:
            if p.op == 'sub' or p.region != region:
                continue
            m = p.k + 0.01
            sel = np.nonzero(np.all((P >= p.lo - m) & (P <= p.hi + m), axis=1))[0]
            if len(sel):
                best[sel] = np.minimum(best[sel], np.abs(p.fn(P[sel])))
        return best

    def bake(self, bones=None, target=None):
        """Retorna lista de superfícies: dict(region, verts, normals, idx[, bones, weights]).
        `target`: número aproximado de triângulos depois da decimação."""
        vol, lo = self._volume()
        verts, faces, _, _ = marching_cubes(vol, 0.0, allow_degenerate=False)
        V = lo + verts * self.voxel
        F = faces.astype(np.int64)
        # decimação da malha inteira (ainda sem regiões) + volta para a superfície exata
        if target and len(F) > target:
            V, F = fast_simplification.simplify(V, F.astype(np.int32), target_count=int(target), agg=5.0)
            F = np.asarray(F, np.int64)
            V = self._relax(V, F)
        a, b, c = V[F[:, 0]], V[F[:, 1]], V[F[:, 2]]
        F = F[_len(np.cross(b - a, c - a)) > 1e-14]
        # regiões base (por triângulo) e bordas entre peças recortadas na isolinha
        reg = self._base_regions(V[F].mean(axis=1))
        vreg = self._base_regions(V)
        fl = vreg[F]
        mixed = (fl[:, 0] != fl[:, 1]) | (fl[:, 1] != fl[:, 2])
        pairs = set()
        for row in fl[mixed]:
            u = sorted(set(row.tolist()))
            if len(u) == 2:
                pairs.add(tuple(u))
        for ra, rb in sorted(pairs):
            # só os triângulos que têm vértices das duas regiões (a borda de verdade)
            fl = vreg[F]
            fm = (fl == ra).any(axis=1) & (fl == rb).any(axis=1)
            if not fm.any():
                continue
            fld = (lambda P, ra=ra, rb=rb: self._region_score(P, ra) - self._region_score(P, rb))
            n0 = len(V)
            V, F, reg = _apply_rule(V, F, reg, Rule({ra, rb}, fld, ra, None), fm, rb)
            if len(V) > n0:
                vreg = np.concatenate([vreg, self._base_regions(V[n0:])])
        # pinturas recortadas (subdivide onde o detalhe é menor que os triângulos)
        for rule in self.rules:
            for _ in range(3):
                V, F, reg, more = _refine(V, F, reg, rule, self.voxel)
                if not more:
                    break
            V, F, reg = _apply_rule(V, F, reg, rule)
        N = self.grad(V)
        # Godot: frente dos triângulos no sentido horário
        a, b, c = V[F[:, 0]], V[F[:, 1]], V[F[:, 2]]
        fn = np.cross(b - a, c - a)
        nn = N[F].sum(axis=1)
        flip = np.einsum('ij,ij->i', fn, nn) > 0
        F[flip] = F[flip][:, [0, 2, 1]]
        W = Bi = None
        if bones is not None:
            Bi, W = self._weights(V, bones)
        out = []
        for r in sorted(set(reg.tolist())):
            fs = F[reg == r]
            used, inv = np.unique(fs.ravel(), return_inverse=True)
            s = dict(region=int(r), verts=V[used].astype(np.float32), normals=N[used].astype(np.float32),
                     idx=inv.astype(np.int32))
            if bones is not None:
                s['bones'] = Bi[used].astype(np.int32)
                s['weights'] = W[used].astype(np.float32)
            out.append(s)
        return out

    def _weights(self, V, bones, falloff=0.022):
        """Pesos pela distância às primitivas de cada osso. O osso "dono" é o da
        primitiva mais próxima; só ossos vizinhos dele (pai/filho) entram na mistura,
        para o braço não grudar na barriga nem uma coxa na outra. Primitivas com
        `bone` chamável (saia) devolvem os próprios pesos."""
        nb = len(bones)
        adj = getattr(self, 'adjacent', None) or set()
        D = np.full((len(V), nb), np.inf)
        best = np.full(len(V), np.inf)
        owner = np.zeros(len(V), int)
        custom = {}
        for pi, p in enumerate(self.prims):
            if p.op == 'sub':
                continue
            m = 0.25
            sel = np.nonzero(np.all((V >= p.lo - m) & (V <= p.hi + m), axis=1))[0]
            if len(sel) == 0:
                continue
            d = p.fn(V[sel])
            ad = np.abs(d)
            closer = ad < best[sel]
            best[sel[closer]] = ad[closer]
            if callable(p.bone):
                custom[pi] = p.bone
                owner[sel[closer]] = -1 - pi
                continue
            j = bones.index(p.bone)
            owner[sel[closer]] = j
            D[sel, j] = np.minimum(D[sel, j], d)
        W = np.zeros((len(V), nb))
        for j in range(nb):
            rows = owner == j
            if not rows.any():
                continue
            ok = np.array([k == j or (bones[j], bones[k]) in adj or (bones[k], bones[j]) in adj for k in range(nb)])
            dd = D[rows] - D[rows, j][:, None]
            W[rows] = np.where(ok[None, :] & np.isfinite(dd), np.exp(-np.maximum(dd, 0.0) / falloff), 0.0)
        for pi, fn in custom.items():
            rows = owner == -1 - pi
            if rows.any():
                for name, w in fn(V[rows]).items():
                    W[rows, bones.index(name)] += w
        order = np.argsort(-W, axis=1)[:, :4]
        Wt = np.take_along_axis(W, order, axis=1)
        Wt[Wt < 0.02] = 0.0
        Wt /= np.maximum(Wt.sum(axis=1, keepdims=True), 1e-9)
        return order, Wt


def _refine(V, F, reg, rule, min_edge):
    """Divide em 4 os triângulos-alvo por onde a borda da pintura passa perto (bolinhas e
    linhas finas menores que o triângulo não somem nem viram serrilhado)."""
    C = V[F].mean(axis=1)
    target = np.isin(reg, list(rule.targets))
    if rule.mask is not None:
        target &= rule.mask(C)
    if not target.any():
        return V, F, reg, False
    a, b, c = V[F[:, 0]], V[F[:, 1]], V[F[:, 2]]
    edge = np.maximum(np.maximum(_len(b - a), _len(c - b)), _len(a - c))
    idx = np.nonzero(target & (edge > min_edge * 1.5))[0]
    near = np.zeros(len(F), bool)
    if len(idx):
        fa, fb, fc = a[idx], b[idx], c[idx]
        sv = np.stack([rule.field(fa), rule.field(fb), rule.field(fc)], 1) > 0
        agree = sv.all(1) | ~sv.any(1)
        probes = [(fa + fb) * 0.5, (fb + fc) * 0.5, (fc + fa) * 0.5, (fa + fb + fc) / 3.0]
        sp = np.stack([rule.field(q) for q in probes], 1) > 0
        missed = agree & np.any(sp != sv[:, :1], axis=1)
        near[idx[missed]] = True
    if not near.any():
        return V, F, reg, False
    cache = {}
    new_pts = []
    nv = len(V)

    def mid(i, j):
        key = (i, j) if i < j else (j, i)
        if key not in cache:
            new_pts.append((V[i] + V[j]) * 0.5)
            cache[key] = nv + len(new_pts) - 1
        return cache[key]
    tris = []
    treg = []
    for (i, j, k), r in zip(F[near], reg[near]):
        ij, jk, ki = mid(i, j), mid(j, k), mid(k, i)
        tris += [(i, ij, ki), (ij, j, jk), (ki, jk, k), (ij, jk, ki)]
        treg += [r] * 4
    V = np.vstack([V, np.array(new_pts)])
    F = np.vstack([F[~near], np.array(tris, np.int64)])
    reg = np.concatenate([reg[~near], np.array(treg, int)])
    return V, F, reg, True


def _apply_rule(V, F, reg, rule, face_mask=None, region_pos=None):
    """Recorta os triângulos-alvo na isolinha field = 0 e pinta o lado negativo com
    `rule.region` (e o positivo com `region_pos`, se dado). `face_mask` restringe ainda
    mais quais triângulos podem ser recortados/pintados."""
    C = V[F].mean(axis=1)
    target = np.isin(reg, list(rule.targets))
    if rule.mask is not None:
        target &= rule.mask(C)
    if face_mask is not None:
        target &= face_mask
    if not target.any():
        return V, F, reg
    f = rule.field(V)
    f = np.where(np.abs(f) < 1e-9, 1e-9, f)
    s = f > 0
    sf = s[F]
    straddle = target & sf.any(axis=1) & ~sf.all(axis=1)
    if straddle.any():
        # arestas cortadas: ponto exato do zero do campo por bisseção (o campo não é linear)
        fs_ = F[straddle]
        E = np.vstack([fs_[:, [0, 1]], fs_[:, [1, 2]], fs_[:, [2, 0]]])
        E = np.sort(E[s[E[:, 0]] != s[E[:, 1]]], axis=1)
        E = np.unique(E, axis=0)
        pa, pb = V[E[:, 0]], V[E[:, 1]]
        sa_ = s[E[:, 0]]
        lo_t = np.zeros(len(E))
        hi_t = np.ones(len(E))
        for _ in range(14):
            mt = (lo_t + hi_t) * 0.5
            sm = rule.field(pa + (pb - pa) * mt[:, None]) > 0
            same = sm == sa_
            lo_t = np.where(same, mt, lo_t)
            hi_t = np.where(same, hi_t, mt)
        t_ = (lo_t + hi_t) * 0.5
        new_pts = pa + (pb - pa) * t_[:, None]
        nv = len(V)
        cache = {(int(i), int(j)): nv + k for k, (i, j) in enumerate(E)}

        def ev(a, b):
            return cache[(a, b) if a < b else (b, a)]

        tris = []
        treg = []
        for (a, b, c), (sa, sb, sc), r in zip(F[straddle], sf[straddle], reg[straddle]):
            if sa == sb:
                lone, o1, o2 = c, a, b
            elif sa == sc:
                lone, o1, o2 = b, c, a
            else:
                lone, o1, o2 = a, b, c
            e1 = ev(lone, o1)
            e2 = ev(lone, o2)
            tris += [(lone, e1, e2), (e1, o1, o2), (e1, o2, e2)]
            treg += [r, r, r]
        V = np.vstack([V, new_pts])
        F = np.vstack([F[~straddle], np.array(tris, np.int64)])
        reg = np.concatenate([reg[~straddle], np.array(treg, int)])
        target = np.concatenate([target[~straddle], np.ones(len(tris), bool)])
        C = V[F].mean(axis=1)
    fc = rule.field(C)
    reg = reg.copy()
    reg[target & (fc < 0)] = rule.region
    if region_pos is not None:
        reg[target & (fc >= 0)] = region_pos
    return V, F, reg


# ------------------------------------------------------------------ campos de pintura

def dots(centers, r):
    C = np.asarray(centers, float)

    def f(P):
        best = np.full(len(P), np.inf)
        for c in C:
            best = np.minimum(best, _len(P - c))
        return best - r
    return f


def ell_dots(centers, radii):
    C = np.asarray(centers, float)
    R = np.asarray(radii, float)

    def f(P):
        best = np.full(len(P), np.inf)
        for c in C:
            q = (P - c) / R
            best = np.minimum(best, (_len(q) - 1.0) * R.min())
        return best
    return f
