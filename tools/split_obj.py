#!/usr/bin/env python3
"""Separa um .obj com vários grupos (g NOME) num .obj por grupo: converte a escala, centra em
X/Z, assenta em Y=0 e escreve um .mtl comum com a textura.

Uso: python3 -I tools/split_obj.py <entrada.obj> <pasta_saida> <textura.png|jpg> [escala] [nome.mtl]
(escala por omissão 0.01: centímetros -> metros)"""
import os, sys

src, out, tex = sys.argv[1], sys.argv[2], sys.argv[3]
scale = float(sys.argv[4]) if len(sys.argv) > 4 else 0.01
V, VT, VN = [], [], []
groups, cur = {}, None
for line in open(src, encoding="utf-8", errors="replace"):
    p = line.split()
    if not p:
        continue
    if p[0] == "v":
        V.append([float(x) * scale for x in p[1:4]])
    elif p[0] == "vt":
        VT.append(p[1:3])
    elif p[0] == "vn":
        VN.append(p[1:4])
    elif p[0] == "g":
        # Alguns exportadores escrevem "g Grupo SM_Nome": preferir o nome que começa por SM_.
        names = [n for n in p[1:] if n.startswith("SM_")] or p[1:2]
        cur = None if names[0] == "default" else names[0]
        if cur:
            groups.setdefault(cur, [])
    elif p[0] == "f" and cur:
        groups[cur].append(p[1:])

os.makedirs(out, exist_ok=True)
tex_name = os.path.basename(tex)
mtl = sys.argv[5] if len(sys.argv) > 5 else "terrain.mtl"
with open(os.path.join(out, mtl), "w") as m:
    m.write("newmtl Terrain\nKd 1.000000 1.000000 1.000000\nmap_Kd %s\n" % tex_name)

for name, faces in groups.items():
    vi = sorted({int(t.split("/")[0]) for f in faces for t in f})
    pts = [V[i - 1] for i in vi]
    cx = (min(p[0] for p in pts) + max(p[0] for p in pts)) / 2
    cz = (min(p[2] for p in pts) + max(p[2] for p in pts)) / 2
    my = min(p[1] for p in pts)
    vmap, tmap, nmap = {}, {}, {}
    lines_v, lines_t, lines_n, lines_f = [], [], [], []
    for f in faces:
        idx = []
        for t in f:
            a = (t.split("/") + ["", ""])[:3]
            v, vt, vn = int(a[0]), a[1], a[2]
            if v not in vmap:
                x, y, z = V[v - 1]
                lines_v.append("v %.5f %.5f %.5f" % (x - cx, y - my, z - cz))
                vmap[v] = len(vmap) + 1
            s = str(vmap[v])
            if vt:
                k = int(vt)
                if k not in tmap:
                    lines_t.append("vt %s %s" % tuple(VT[k - 1]))
                    tmap[k] = len(tmap) + 1
                s += "/" + str(tmap[k])
            if vn:
                k = int(vn)
                if k not in nmap:
                    lines_n.append("vn %s %s %s" % tuple(VN[k - 1]))
                    nmap[k] = len(nmap) + 1
                s += ("" if vt else "/") + "/" + str(nmap[k])
            idx.append(s)
        lines_f.append("f " + " ".join(idx))
    with open(os.path.join(out, name + ".obj"), "w") as o:
        o.write("mtllib %s\no %s\n" % (mtl, name))
        o.write("\n".join(lines_v + lines_t + lines_n) + "\nusemtl Terrain\n" + "\n".join(lines_f) + "\n")
print(len(groups), "peças em", out)
