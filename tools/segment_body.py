#!/usr/bin/env python3
"""Zerlegt das Meshy-Körpermodell (ein einziges Mesh) in Körperregionen.

Eingabe : tools/source/Meshy_Holographic_Human.usdz
Ausgabe : PainDiary/Resources/KoerperGlas.usdz  (ein Mesh pro Region, ASCII-Namen)

Die Prim-Namen sind ASCII; die App ordnet sie in `BodySceneBuilder.usdzRegionen` den Anzeigenamen
(z. B. `Ruecken_oben` → „Rücken oben") zu. Vorderseite/Rückseite werden über die Flächennormale (n_z) getrennt.
Konvention wie in der App: x < 0 = „links" (links im Bild bei Frontansicht).

Aufruf:  pip install usd-core numpy && python3 tools/segment_body.py [--preview preview.png]
"""
import argparse, os, sys, tempfile, zipfile
import numpy as np
from pxr import Usd, UsdGeom, UsdUtils, Vt, Gf, Sdf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUELLE = os.path.join(ROOT, "tools", "source", "Meshy_Holographic_Human.usdz")
ZIEL = os.path.join(ROOT, "PainDiary", "Resources", "KoerperGlas.usdz")

# Rand zwischen Rumpf und Arm (|x|) in Abhängigkeit von y — aus Schnittmessungen des Modells
RUMPF_RAND = [(0.70, 0.185), (0.62, 0.185), (0.40, 0.165), (0.35, 0.170), (0.30, 0.175), (0.25, 0.180),
              (0.20, 0.190), (0.15, 0.210), (0.10, 0.220), (0.05, 0.230), (0.00, 0.230),
              (-0.05, 0.240), (-0.20, 0.240)]

def rumpf_rand(y):
    ys = [p[0] for p in RUMPF_RAND][::-1]
    xs = [p[1] for p in RUMPF_RAND][::-1]
    return float(np.interp(y, ys, xs))

# Höhengrenzen (Modell: y von -0.95 bis +0.95)
Y_KOPF = 0.77        # darüber Kopf
Y_HALS = 0.62        # Hals bis hierher
Y_BRUST = 0.28
Y_BAUCH = -0.00 + 0.05  # 0.05
Y_HUEFTE = -0.10
Y_OBERARM = 0.40; Y_ELLBOGEN_O = 0.22; Y_ELLBOGEN_U = 0.14; Y_HAND = -0.03
Y_GESAESS_U = -0.20
Y_KNIE_O = -0.44; Y_KNIE_U = -0.56; Y_KNOECHEL_O = -0.80; Y_FUSS = -0.88

def region(c, n):
    """c = Flächenmitte (x, y, z), n = gemittelte Normale. Vorderseite = n_z >= 0."""
    x, y, z = c
    vorne = n[2] >= 0
    seite = "links" if x < 0 else "rechts"
    ax = abs(x)
    if y > Y_KOPF:
        return "Kopf"
    # Arme: außerhalb des Rumpfrands (unterhalb der Achsel) bzw. Schulterkappe
    if y <= 0.70 and y > Y_OBERARM and ax > rumpf_rand(y):
        return f"Schulter_{seite}"
    if y <= Y_OBERARM and y > -0.14 and ax > rumpf_rand(y) and ax > 0.16:
        if y > Y_ELLBOGEN_O: return f"{'Bizeps' if vorne else 'Trizeps'}_{seite}"
        if y > Y_ELLBOGEN_U: return f"Ellbogen_{seite}"
        if y > Y_HAND:       return f"Unterarm_{seite}"
        return f"Hand_{seite}"
    # Rumpf (vorne/hinten getrennt)
    if y > Y_HALS:   return "Hals" if vorne else "Nacken"
    if y > Y_BRUST:  return "Brust" if vorne else "Ruecken_oben"
    if y > Y_BAUCH:  return "Bauch" if vorne else "Ruecken_unten"
    if not vorne and y > Y_GESAESS_U: return "Gesaess"
    if vorne and y > Y_HUEFTE:        return "Huefte"
    # Beine
    if y > Y_KNIE_O:     return f"Oberschenkel_{'vorne' if vorne else 'hinten'}_{seite}"
    if y > Y_KNIE_U:     return f"{'Kniescheibe' if vorne else 'Kniekehle'}_{seite}"
    if y > Y_KNOECHEL_O: return f"{'Schienbein' if vorne else 'Wade'}_{seite}"
    if y > Y_FUSS:       return f"Knoechel_{seite}"
    # Fuß: Sohle (unten), Ferse (hinten), Spann (oben/vorne)
    if n[1] < -0.30: return f"Fussohle_{seite}"
    if n[2] < -0.30: return f"Ferse_{seite}"
    return f"Fussspann_{seite}"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="PNG mit eingefärbten Regionen (Front/Seite/Rücken)")
    args = ap.parse_args()

    quelle = Usd.Stage.Open(QUELLE)
    mesh = next(UsdGeom.Mesh(p) for p in quelle.Traverse() if p.IsA(UsdGeom.Mesh))
    pts = np.array(mesh.GetPointsAttr().Get(), dtype=np.float64)
    nrm = np.array(mesh.GetNormalsAttr().Get(), dtype=np.float64)
    idx = np.array(mesh.GetFaceVertexIndicesAttr().Get(), dtype=np.int64).reshape(-1, 3)
    # Modellkoordinaten sind in der Datei auf Fuß-Einheiten ausgelegt, die Zahlenwerte bleiben erhalten
    cent = pts[idx].mean(axis=1)
    fn = nrm[idx].mean(axis=1)
    namen = np.array([region(c, n) for c, n in zip(cent, fn)])

    os.makedirs(os.path.dirname(ZIEL), exist_ok=True)
    tmp = tempfile.mkdtemp()
    usda = os.path.join(tmp, "KoerperGlas.usdc")
    stage = Usd.Stage.CreateNew(usda)
    UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
    UsdGeom.SetStageMetersPerUnit(stage, 1.0)
    root = UsdGeom.Xform.Define(stage, "/Root")
    stage.SetDefaultPrim(root.GetPrim())

    ausgabe = {}
    for name in sorted(set(namen)):
        faces = idx[namen == name]
        benutzt, neu = np.unique(faces, return_inverse=True)
        m = UsdGeom.Mesh.Define(stage, f"/Root/{name}")
        m.CreatePointsAttr(Vt.Vec3fArray.FromNumpy(pts[benutzt].astype(np.float32)))
        m.CreateNormalsAttr(Vt.Vec3fArray.FromNumpy(nrm[benutzt].astype(np.float32)))
        m.SetNormalsInterpolation(UsdGeom.Tokens.vertex)
        m.CreateFaceVertexCountsAttr(Vt.IntArray([3] * len(faces)))
        m.CreateFaceVertexIndicesAttr(Vt.IntArray.FromNumpy(neu.astype(np.int32)))
        m.CreateSubdivisionSchemeAttr(UsdGeom.Tokens.none)
        lo, hi = pts[benutzt].min(axis=0), pts[benutzt].max(axis=0)
        m.CreateExtentAttr(Vt.Vec3fArray([Gf.Vec3f(*lo), Gf.Vec3f(*hi)]))
        ausgabe[name] = len(faces)
    stage.GetRootLayer().Save()

    if os.path.exists(ZIEL): os.remove(ZIEL)
    if not UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(usda), ZIEL):
        sys.exit("USDZ konnte nicht erstellt werden")
    print(f"{ZIEL}: {os.path.getsize(ZIEL)/1e6:.1f} MB, {len(ausgabe)} Regionen")
    for n, k in ausgabe.items(): print(f"  {n:22s} {k:7d} Flächen")

    if args.preview:
        import matplotlib; matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        farben = {n: plt.cm.tab20(i % 20) for i, n in enumerate(sorted(set(namen)))}
        fig, ax = plt.subplots(1, 3, figsize=(15, 9))
        for a, (h, v, t) in zip(ax, [(0, 1, "Vorderseite (x,y)"), (2, 1, "Seite (z,y)"), (0, 1, "Rückseite (x,y)")]):
            sel = fn[:, 2] >= 0 if t.startswith("Vorder") else (fn[:, 2] < 0 if t.startswith("Rück") else slice(None))
            a.scatter(cent[sel][:, h], cent[sel][:, v], s=0.3, c=[farben[n] for n in namen[sel]])
            a.set_aspect("equal"); a.set_title(t)
        plt.savefig(args.preview, dpi=70)

if __name__ == "__main__":
    main()
