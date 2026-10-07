#!/usr/bin/env python3
"""Zerschneidet `body.obj` (ein Körpernetz) in die geforderten anatomischen Teile.

Ausgabe (nach tools/export/ und PainDiary/Resources/):
  - body_segmented.fbx           Hierarchie wie in der Vorgabe, Blender-Objekte exakt benannt
  - KoerperGlas.usdz             Y-up, Meter, gleiche Namen/Hierarchie (für SceneKit/RealityKit)

Schritte pro Teil (alles mit Blender/bmesh, `pip install bpy numpy usd-core`):
  1. echte Schnitte mit Ebenen (bisect) – saubere Kanten, keine Treppen
  2. Schnittflächen schließen (Deckel), dann Schnittkanten leicht abrunden (Bevel)
  3. Teil um ~1 % um seine Mitte verkleinern → sichtbarer Mikro-Spalt (Naht) zwischen Nachbarn
Konvention: `_l` = links im Bild bei Frontansicht (x < 0), wie überall in der App.
            Mit --anatomisch werden _l/_r vertauscht (anatomische linke Körperseite).

Aufruf: python3 tools/segment_body_obj.py [--obj PFAD] [--preview vorschau.png] [--anatomisch]
"""
import argparse, math, os, sys
import numpy as np
import bpy, bmesh
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OBJ = os.path.join(ROOT, "tools", "source", "body.obj")
OUT_FBX = os.path.join(ROOT, "tools", "export", "body_segmented.fbx")
OUT_USDZ = os.path.join(ROOT, "PainDiary", "Resources", "KoerperGlas.usdz")

XC, ZC = -1.95, -115.0     # Körpermitte im OBJ (cm)
SHRINK = 0.99              # Mikro-Spalt: Teile auf 99 % skalieren
BEVEL = 0.12               # cm, sehr leichte Abrundung der Schnittkanten
Z_TORSO = -0.6
Z_ARM = -6.5            # Oberarm liegt hinter der Rumpfmitte

# ---- Landmarken (cm, Koordinaten relativ zur Körpermitte, y nach oben, z nach vorne) ----
Y_HEAD, Y_NECK = 133.5, 123.5
Y_CHEST, Y_BACKU = 97.0, 92.0
Y_ABD, Y_CROTCH = 66.0, 46.0
Y_GLUTE = Y_CROTCH        # Gesäß/Oberschenkel-hinten und Leiste/Oberschenkel-vorne teilen dieselbe Ebene
TORSO_X = 19.5             # Rumpfrand zu Armen (Rumpf max. 18.3 cm Halbbreite)
# linker Arm (x < 0), Achsenpunkte
S = np.array([-25.0, 110.0]); E = np.array([-34.0, 88.0]); W = np.array([-48.0, 72.0])
# Beine
Y_KNEE_T, Y_KNEE_B, Y_ANKLE = 20.0, 6.0, -14.0
Y_SOLE, Z_HEEL = -22.5, -5.5

def unit(v): v = np.asarray(v, float); return v / np.linalg.norm(v)

# Halbräume: (Punkt, Normale) → behalten, wo dot(p - Punkt, Normale) >= 0
def above(y):  return ((0, y, 0), (0, 1, 0))
def below(y):  return ((0, y, 0), (0, -1, 0))
def front(z=Z_TORSO): return ((0, 0, z), (0, 0, 1))
def back(z=Z_TORSO):  return ((0, 0, z), (0, 0, -1))
def xge(x): return ((x, 0, 0), (1, 0, 0))
def xle(x): return ((x, 0, 0), (-1, 0, 0))
def tilted_z(p0, p1, positive):
    """Ebene durch zwei (y, z)-Punkte der Beinachse; positive = vorne."""
    (y0, z0), (y1, z1) = p0, p1
    d = np.array([y1 - y0, z1 - z0]); n = np.array([-d[1], d[0]]); n = unit(n)
    if n[1] < 0: n = -n                      # Normale zeigt nach +z (vorne)
    if not positive: n = -n
    return ((0, y0, z0), (0, n[0], n[1]))
def plane2d(pt, nrm):    # Ebene senkrecht zur xy-Ebene durch pt (x,y) mit Normale (nx, ny)
    return ((pt[0], pt[1], 0), (nrm[0], nrm[1], 0))

def arm_planes(sign):
    """Ebenen für Schulter/Oberarm/Ellbogen/Unterarm/Hand der Seite sign (-1 = x<0)."""
    s, e, w = (np.array([sign * abs(a[0]), a[1]]) for a in (S, E, W))
    du, df = unit(e - s), unit(w - e)
    dm = unit(du + df)
    p_sh = s + du * 6.0                      # Ende der Schulter
    p_e1, p_e2 = e - dm * 4.0, e + dm * 4.0  # Ellbogenzone
    ein = lambda p, d, pos: plane2d(p, d if pos else -d)
    return dict(
        out=(xle(-TORSO_X) if sign < 0 else xge(TORSO_X)),
        shoulder=[ein(p_sh, du, False)],
        upper=[ein(p_sh, du, True), ein(p_e1, dm, False)],
        elbow=[ein(p_e1, dm, True), ein(p_e2, dm, False)],
        lower=[ein(p_e2, dm, True), ein(w, df, False)],
        hand=[ein(w, df, True)],
        palm_n=unit(np.array([-df[1], df[0]]) * (1 if (-df[1]) * (-sign) > 0 else -1)),
        hand_axis=(w, df))

def hand_split(sign, palm):
    a = arm_planes(sign)
    w, df = a["hand_axis"]
    n = np.array([-df[1], df[0]])            # ⟂ Handachse (in xy)
    toward_body = np.array([-sign, 0.0])     # zeigt zur Körpermitte
    if np.dot(n, toward_body) < 0: n = -n
    if not palm: n = -n
    return plane2d(w, n)

def regions(links_x_neg=True):
    """name -> Liste von Halbräumen (Seite l = x<0)."""
    R = {}
    R["head_front"] = [above(Y_HEAD), front(-0.5)]
    R["head_back"] = [above(Y_HEAD), back(-0.5)]
    R["neck_front"] = [below(Y_HEAD), above(Y_NECK), front(1.0)]
    R["neck_back"] = [below(Y_HEAD), above(Y_NECK), back(1.0)]
    lim = [xge(-TORSO_X), xle(TORSO_X)]
    R["chest"] = [below(Y_NECK), above(Y_CHEST), front(), *lim]
    R["abdomen"] = [below(Y_CHEST), above(Y_ABD), front(), *lim]
    R["hips_front"] = [below(Y_ABD), above(Y_CROTCH), front(), *lim]
    R["back_upper"] = [below(Y_NECK), above(Y_BACKU), back(), *lim]
    R["back_lower"] = [below(Y_BACKU), above(Y_ABD), back(), *lim]
    R["glutes"] = [below(Y_ABD), above(Y_GLUTE), back(), *lim]
    for side, sign in (("l", -1), ("r", 1)):
        a = arm_planes(sign)
        arm_y = above(50.0)                  # Arme enden über dem Becken (schließt Überlappung mit Füßen aus)
        R[f"shoulder_{side}"] = [arm_y, a["out"], *a["shoulder"], below(Y_NECK + 6)]
        R[f"arm_upper_front_{side}"] = [arm_y, a["out"], *a["upper"], front(Z_ARM)]
        R[f"arm_upper_back_{side}"] = [arm_y, a["out"], *a["upper"], back(Z_ARM)]
        R[f"elbow_{side}"] = [arm_y, a["out"], *a["elbow"]]
        R[f"arm_lower_{side}"] = [arm_y, a["out"], *a["lower"]]
        R[f"hand_palm_{side}"] = [arm_y, a["out"], *a["hand"], hand_split(sign, True)]
        R[f"hand_back_{side}"] = [arm_y, a["out"], *a["hand"], hand_split(sign, False)]
        side_h = xle(0.0) if sign < 0 else xge(0.0)
        thigh_front = tilted_z((Y_CROTCH, Z_TORSO), (Y_KNEE_T, -6.2), True)
        thigh_back = tilted_z((Y_CROTCH, Z_TORSO), (Y_KNEE_T, -6.2), False)
        R[f"thigh_front_{side}"] = [side_h, below(Y_CROTCH), above(Y_KNEE_T), thigh_front]
        R[f"thigh_back_{side}"] = [side_h, below(Y_GLUTE), above(Y_KNEE_T), thigh_back]
        R[f"knee_{side}"] = [side_h, below(Y_KNEE_T), above(Y_KNEE_B), front(-7.5)]
        R[f"knee_hollow_{side}"] = [side_h, below(Y_KNEE_T), above(Y_KNEE_B), back(-7.5)]
        R[f"shin_{side}"] = [side_h, below(Y_KNEE_B), above(Y_ANKLE), front(-7.0)]
        R[f"calf_{side}"] = [side_h, below(Y_KNEE_B), above(Y_ANKLE), back(-7.0)]
        R[f"foot_top_{side}"] = [side_h, below(Y_ANKLE), above(Y_SOLE), front(Z_HEEL)]
        R[f"foot_sole_{side}"] = [side_h, below(Y_SOLE), front(Z_HEEL)]
        R[f"heel_{side}"] = [side_h, below(Y_ANKLE), back(Z_HEEL)]
    return R

# JSON-Hierarchie (Elternteil je Teil)
PARENT = {
    "head_front": "root", "head_back": "root", "neck_front": "head_front", "neck_back": "head_back",
    "chest": "root", "abdomen": "chest", "hips_front": "abdomen",
    "back_upper": "root", "back_lower": "back_upper", "glutes": "back_lower",
}
for s in ("l", "r"):
    PARENT.update({
        f"shoulder_{s}": "chest", f"arm_upper_front_{s}": f"shoulder_{s}", f"arm_upper_back_{s}": f"shoulder_{s}",
        f"elbow_{s}": f"arm_upper_back_{s}", f"arm_lower_{s}": f"elbow_{s}",
        f"hand_palm_{s}": f"arm_lower_{s}", f"hand_back_{s}": f"arm_lower_{s}",
        f"thigh_front_{s}": "hips_front", f"thigh_back_{s}": "glutes",
        f"knee_{s}": f"thigh_front_{s}", f"knee_hollow_{s}": f"thigh_back_{s}",
        f"shin_{s}": f"knee_{s}", f"calf_{s}": f"knee_hollow_{s}",
        f"foot_top_{s}": f"shin_{s}", f"heel_{s}": f"calf_{s}", f"foot_sole_{s}": f"heel_{s}",
    })

def lade_obj(pfad):
    V, cur, faces = [], None, {}
    for line in open(pfad):
        if line.startswith("v "): V.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("g "): cur = line.split()[1]; faces.setdefault(cur, [])
        elif line.startswith("f "): faces[cur].append([int(t.split("/")[0]) - 1 for t in line.split()[1:]])
    V = np.array(V)
    benutzt = sorted({i for f in faces["body"] for i in f})
    neu = {a: b for b, a in enumerate(benutzt)}
    P = V[benutzt].copy(); P[:, 0] -= XC; P[:, 2] -= ZC
    F = [[neu[i] for i in f] for f in faces["body"]]
    return P, F

def basis_bmesh(P, F):
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in P]
    bm.verts.ensure_lookup_table()
    for f in F:
        try: bm.faces.new([vs[i] for i in f])
        except ValueError: pass
    return bm

def clip(bm, plane, tol=1e-4):
    (co, no) = plane
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, dist=tol, plane_co=Vector(co), plane_no=Vector(no),
                           clear_inner=True, clear_outer=False)
    lose = [v for v in bm.verts if not v.link_faces]
    if lose: bmesh.ops.delete(bm, geom=lose, context="VERTS")

def baue_teil(basis, ebenen):
    bm = basis.copy()
    for pl in ebenen:
        if not bm.faces: break
        clip(bm, pl)
    if not bm.faces: return None, 0.0
    flaeche_vor_deckel = sum(f.calc_area() for f in bm.faces)
    # Deckel auf die Schnittränder
    rand = [e for e in bm.edges if e.is_boundary]
    deckel = set()
    if rand:
        try:
            res = bmesh.ops.holes_fill(bm, edges=rand, sides=100000)
            deckel = set(res.get("faces", []))
            if deckel:
                tri = bmesh.ops.triangulate(bm, faces=list(deckel), quad_method="BEAUTY", ngon_method="BEAUTY")
                deckel = set(tri.get("faces", [])) | deckel
        except Exception as ex:
            print("  Deckel fehlgeschlagen:", ex)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    # Schnittkanten leicht abrunden
    if deckel:
        kanten = [e for e in bm.edges if len(e.link_faces) == 2 and
                  ((e.link_faces[0] in deckel) != (e.link_faces[1] in deckel))]
        if kanten:
            try:
                bmesh.ops.bevel(bm, geom=kanten, offset=BEVEL, offset_type="OFFSET", profile=0.5,
                                segments=2, affect="EDGES", clamp_overlap=True)
            except Exception as ex:
                print("  Bevel übersprungen:", ex)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm, flaeche_vor_deckel

def mikro_spalt(bm, faktor=SHRINK):
    if not bm.verts: return
    xs = [v.co for v in bm.verts]
    lo = Vector((min(c.x for c in xs), min(c.y for c in xs), min(c.z for c in xs)))
    hi = Vector((max(c.x for c in xs), max(c.y for c in xs), max(c.z for c in xs)))
    mitte = (lo + hi) / 2
    for v in bm.verts: v.co = mitte + (v.co - mitte) * faktor

def weich_mit_harten_kanten(bm, winkel=35.0):
    for f in bm.faces: f.smooth = True
    grenz = math.radians(winkel)
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > grenz: e.smooth = False

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--obj", default=OBJ)
    ap.add_argument("--preview")
    ap.add_argument("--anatomisch", action="store_true", help="_l/_r anatomisch statt Bildseite")
    args = ap.parse_args()
    if not os.path.exists(args.obj):
        sys.exit(f"{args.obj} fehlt (body.obj nach tools/source/ legen)")

    P, F = lade_obj(args.obj)
    basis = basis_bmesh(P, F)
    y_min = float(P[:, 1].min())
    teile = regions()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    szene = bpy.context.scene
    szene.unit_settings.system = "METRIC"

    # Blender-Rahmen: (x, y_hoch, z_vorne) [cm] → (x, -z, y - y_min) [m]
    def zu_blender(co): return Vector((co.x * 0.01, -co.z * 0.01, (co.y - y_min) * 0.01))
    mat = bpy.data.materials.new("frosted_glass"); mat.use_nodes = True  # noqa (Blender 5: deprecated, funktioniert)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.9, 0.93, 1.0, 1)
        bsdf.inputs["Roughness"].default_value = 0.35
        bsdf.inputs["Metallic"].default_value = 0.1
        bsdf.inputs["Alpha"].default_value = 0.85
    root = bpy.data.objects.new("body_root", None); szene.collection.objects.link(root)

    objekte, vorschau = {}, []
    flaeche_summe = 0.0
    flaeche_orig = sum(f.calc_area() for f in basis.faces)
    swap = {"l": "r", "r": "l"} if args.anatomisch else {}
    for name, ebenen in teile.items():
        bm, fl = baue_teil(basis, ebenen)
        flaeche_summe += fl
        if bm is None:
            print(f"WARNUNG: {name} ist leer"); continue
        flaechen = len(bm.faces)
        mikro_spalt(bm)
        weich_mit_harten_kanten(bm)
        if args.preview:
            for f in bm.faces:
                vorschau.append((name, [tuple(v.co) for v in f.verts], tuple(f.normal)))
        for v in bm.verts: v.co = zu_blender(v.co)
        bm.normal_update()
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh); bm.free()
        ziel = name
        if args.anatomisch and name.endswith(("_l", "_r")):
            ziel = name[:-1] + swap[name[-1]]
        mesh.materials.append(mat)
        ob = bpy.data.objects.new(ziel, mesh)
        szene.collection.objects.link(ob)
        objekte[name] = ob
        print(f"  {ziel:22s} {flaechen:6d} Flächen")
    for name, ob in objekte.items():
        eltern = PARENT.get(name, "root")
        ob.parent = root if eltern == "root" else objekte.get(eltern, root)

    print(f"Abdeckung: Teile {flaeche_summe:.0f} cm² von {flaeche_orig:.0f} cm² Original ({100*flaeche_summe/flaeche_orig:.2f} %)")
    exportiere_fbx(objekte, root)
    exportiere_usd(objekte, root)

    if args.preview:
        rendere_vorschau(vorschau, args.preview)

def rendere_vorschau(polys, ziel):
    """Painter-Algorithmus: Vorderansicht, Seite, Rückansicht – jede Region eine Farbe, Schattierung nach Normale."""
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.collections import PolyCollection
    namen = sorted({n for n, _, _ in polys})
    farb = {n: plt.cm.tab20(i % 20) for i, n in enumerate(namen)}
    ansichten = [("Vorne", lambda c: (c[0], c[1]), lambda c: c[2], lambda n: n[2]),
                 ("Seite", lambda c: (c[2], c[1]), lambda c: c[0], lambda n: n[0]),
                 ("Hinten", lambda c: (-c[0], c[1]), lambda c: -c[2], lambda n: -n[2])]
    fig, ax = plt.subplots(1, 3, figsize=(16, 10))
    for a, (titel, proj, tiefe, nrm) in zip(ax, ansichten):
        items = sorted(polys, key=lambda p: tiefe([sum(v[i] for v in p[1]) / len(p[1]) for i in range(3)]))
        flaechen, farben = [], []
        for n, vs, nn in items:
            if nrm(nn) < -0.2: continue                      # abgewandte Flächen weglassen
            hell = 0.55 + 0.45 * max(0.0, nrm(nn))
            c = farb[n]; farben.append((c[0] * hell, c[1] * hell, c[2] * hell, 1))
            flaechen.append([proj(v) for v in vs])
        a.add_collection(PolyCollection(flaechen, facecolors=farben, edgecolors="k", linewidths=0.05))
        a.autoscale(); a.set_aspect("equal"); a.set_title(titel)
    plt.tight_layout(); plt.savefig(ziel, dpi=80)

def exportiere_fbx(objekte, root):
    os.makedirs(os.path.dirname(OUT_FBX), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=OUT_FBX, use_selection=True, object_types={"EMPTY", "MESH"},
                             path_mode="COPY", embed_textures=False, mesh_smooth_type="EDGE",
                             add_leaf_bones=False, bake_anim=False)
    print("FBX:", OUT_FBX, f"{os.path.getsize(OUT_FBX)/1e6:.1f} MB")

def exportiere_usd(objekte, root):
    """USD selbst schreiben: Y-up, Meter, Hierarchie wie in Blender, Normale pro Ecke (harte Kanten bleiben hart)."""
    from pxr import Usd, UsdGeom, UsdUtils, Vt, Gf, Sdf
    import tempfile
    tmp = tempfile.mkdtemp()
    pfad = os.path.join(tmp, "KoerperGlas.usdc")
    st = Usd.Stage.CreateNew(pfad)
    UsdGeom.SetStageUpAxis(st, UsdGeom.Tokens.y)
    UsdGeom.SetStageMetersPerUnit(st, 1.0)
    wurzel = UsdGeom.Xform.Define(st, "/body_root")
    st.SetDefaultPrim(wurzel.GetPrim())

    def prim_pfad(ob):
        teile = []
        while ob is not None and ob.name != "body_root":
            teile.append(ob.name); ob = ob.parent
        return "/body_root/" + "/".join(reversed(teile))
    def yup(v): return (v[0], v[2], -v[1])      # Blender (x,y,z-up) → USD Y-up

    for ob in sorted(objekte.values(), key=lambda o: len(prim_pfad(o))):
        pfad_prim = prim_pfad(ob)
        # fehlende Zwischenebenen sind durch Elternobjekte abgedeckt (Eltern zuerst definiert)
        parent_path = pfad_prim.rsplit("/", 1)[0]
        if not st.GetPrimAtPath(parent_path):
            UsdGeom.Xform.Define(st, parent_path)
        m = UsdGeom.Mesh.Define(st, pfad_prim)
        me = ob.data
        pts = np.array([yup(v.co) for v in me.vertices], dtype=np.float32)
        m.CreatePointsAttr(Vt.Vec3fArray.FromNumpy(pts))
        counts = [len(p.vertices) for p in me.polygons]
        idx = [i for p in me.polygons for i in p.vertices]
        m.CreateFaceVertexCountsAttr(Vt.IntArray(counts))
        m.CreateFaceVertexIndicesAttr(Vt.IntArray(idx))
        n = np.array([yup(c.vector) for c in me.corner_normals], dtype=np.float32)
        m.CreateNormalsAttr(Vt.Vec3fArray.FromNumpy(n))
        m.SetNormalsInterpolation(UsdGeom.Tokens.faceVarying)
        m.CreateSubdivisionSchemeAttr(UsdGeom.Tokens.none)
        lo, hi = pts.min(axis=0), pts.max(axis=0)
        m.CreateExtentAttr(Vt.Vec3fArray([Gf.Vec3f(*map(float, lo)), Gf.Vec3f(*map(float, hi))]))
    st.GetRootLayer().Save()
    os.makedirs(os.path.dirname(OUT_USDZ), exist_ok=True)
    if os.path.exists(OUT_USDZ): os.remove(OUT_USDZ)
    if not UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(pfad), OUT_USDZ):
        sys.exit("USDZ konnte nicht erstellt werden")
    print("USDZ:", OUT_USDZ, f"{os.path.getsize(OUT_USDZ)/1e6:.1f} MB")

if __name__ == "__main__":
    main()
