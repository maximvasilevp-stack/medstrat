#!/usr/bin/env python3
"""Build the Medstrat pixel map from Natural Earth admin-0 countries (pure Python 3 stdlib).

Outputs (into assets/map/):
  province_ids.dat  - W*H bytes, province id per cell (0 = water)
  terrain.dat       - W*H bytes, terrain class per cell (see TERRAIN_* below)
  provinces.json    - metadata: grid size, bbox, provinces (name, color, capital, neighbours)
  preview.png       - RGB preview of the map for a quick visual check

Run:  python3 tools/build_map.py
"""
import json
import math
import os
import struct
import sys
import zlib
from collections import defaultdict, deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "data", "ne_50m_admin_0_countries.geojson")
OUT_DIR = os.path.join(ROOT, "assets", "map")

# ---------------------------------------------------------------- configuration
LON0, LAT0, LAT1 = -11.0, 27.0, 71.0      # west / south / north edges (deg)
W, H = 640, 768                            # grid size in cells
PHI0 = 49.0                                # latitude of true scale for the x-correction
XSCALE = math.cos(math.radians(PHI0))
S = (LAT1 - LAT0) / H                      # degrees of latitude per cell
LON1 = LON0 + W * S / XSCALE               # derived east edge (~44.9)

MIN_CELLS = 20                             # provinces smaller than this merge into a neighbour
FORCE_KEEP = {"Malta"}
SKIP = {"United States of America"}          # never rasterized (touch the bbox only through the antimeridian)
VOID = 255                                    # id for land that is out of play (clipped neighbours of the map)
VOID_COUNTRIES = {
    "Western Sahara", "Mauritania", "Iran", "Azerbaijan", "Faroe Islands", "Greenland", "Kazakhstan",
}
MERGE_INTO = {                              # explicit merges (gameplay simplification)
    "Northern Cyprus": "Cyprus",
    "Aland": "Finland",
    "Isle of Man": "United Kingdom",
    "Guernsey": "United Kingdom",
    "Jersey": "United Kingdom",
    "Vatican": "Italy",
    "San Marino": "Italy",
    "Monaco": "France",
    "Liechtenstein": "Switzerland",
    "Andorra": "Spain",
}
LAKE_MAX = 300                             # enclosed water components below this become land
SEA_REACH = 80                             # max water distance (cells) for sea adjacency
SHALLOW_DIST = 2                           # water cells within this distance of land are shallow

# straits that are narrower than a cell: carve a 1-cell water channel so seas stay connected
STRAITS = [
    ((-5.75, 35.85), (-5.45, 36.15)),      # Gibraltar
    ((28.95, 40.95), (29.15, 41.30)),      # Bosporus
    ((26.15, 39.95), (26.75, 40.45)),      # Dardanelles
    ((15.55, 38.10), (15.70, 38.30)),      # Messina
    ((12.55, 55.55), (12.85, 56.10)),      # Oresund
    ((36.45, 45.15), (36.70, 45.45)),      # Kerch
]

SAND_COUNTRIES = {
    "Egypt", "Libya", "Algeria", "Tunisia", "Morocco", "Saudi Arabia", "Jordan",
    "Iraq", "Syria", "Israel", "Palestine", "Lebanon",
}
SAND_MAX_LAT = 34.2                        # in sand countries, cells north of this stay green
SNOW_MIN_LAT = 66.0

# mountain ranges: list of (points [(lon,lat)...], radius_in_cells)
MOUNTAINS = [
    ([(5.5, 44.2), (7.5, 45.8), (10.5, 46.5), (13.5, 47.0), (15.5, 47.3)], 4),   # Alps
    ([(-1.5, 43.0), (2.5, 42.6)], 2),                                              # Pyrenees
    ([(9.5, 44.4), (13.0, 43.0), (15.5, 40.5), (16.5, 39.0)], 2),                  # Apennines
    ([(17.0, 49.5), (21.0, 49.3), (24.0, 48.0), (26.0, 46.5), (24.5, 45.5), (22.0, 45.5)], 3),  # Carpathians
    ([(14.5, 45.5), (18.0, 43.5), (20.0, 42.0), (21.5, 40.5)], 2),                 # Dinaric
    ([(22.5, 43.0), (27.0, 43.0)], 2),                                              # Balkan
    ([(6.0, 58.5), (8.0, 61.0), (12.0, 63.0), (15.0, 66.0), (20.0, 69.0)], 3),     # Scandinavian
    ([(40.0, 43.5), (44.5, 42.0)], 3),                                              # Caucasus
    ([(-8.0, 31.0), (-5.0, 32.5), (-2.0, 34.0), (2.0, 35.5), (7.0, 36.0)], 2),     # Atlas
    ([(30.0, 37.0), (34.0, 37.0), (38.0, 38.0), (42.0, 39.5)], 2),                 # Taurus
    ([(36.0, 41.0), (40.0, 40.8)], 2),                                              # Pontic
    ([(-7.0, 43.0), (-3.0, 43.2)], 2),                                              # Cantabrian
    ([(-4.0, 37.0), (-2.5, 37.2)], 1),                                              # Sierra Nevada
    ([(-5.0, 57.0), (-3.5, 58.0)], 2),                                              # Highlands
]

TERRAIN_DEEP, TERRAIN_SHALLOW, TERRAIN_GRASS, TERRAIN_SAND, TERRAIN_SNOW, TERRAIN_MOUNTAIN = range(6)
TERRAIN_RGB = {
    TERRAIN_DEEP: (24, 52, 96), TERRAIN_SHALLOW: (52, 96, 148), TERRAIN_GRASS: (96, 140, 72),
    TERRAIN_SAND: (196, 172, 112), TERRAIN_SNOW: (214, 220, 226), TERRAIN_MOUNTAIN: (120, 112, 100),
}

PLAYER_FACTIONS = {"player1": "Italy", "player2": "Tunisia"}
FIXED_COLORS = {"Italy": (210, 59, 59), "Tunisia": (142, 68, 173)}

# ---------------------------------------------------------------- projection

def to_cell(lon, lat):
    return (lon - LON0) * XSCALE / S, (LAT1 - lat) / S


def cell_center_lonlat(x, y):
    return LON0 + (x + 0.5) * S / XSCALE, LAT1 - (y + 0.5) * S


# ---------------------------------------------------------------- rasterisation

def rasterize_polygon(rings, grid, pid):
    """Even-odd scanline fill of one polygon (outer ring + holes) into grid (bytearray W*H)."""
    rows = defaultdict(list)
    for ring in rings:
        pts = [to_cell(lon, lat) for lon, lat in ring]
        n = len(pts)
        for i in range(n):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % n]
            if y0 == y1:
                continue
            if y0 > y1:
                x0, y0, x1, y1 = x1, y1, x0, y0
            ys = max(0, math.ceil(y0 - 0.5))
            ye = min(H - 1, math.ceil(y1 - 0.5) - 1)
            if ys > ye:
                continue
            dxdy = (x1 - x0) / (y1 - y0)
            for y in range(ys, ye + 1):
                rows[y].append(x0 + (y + 0.5 - y0) * dxdy)
    for y, xs in rows.items():
        xs.sort()
        base = y * W
        for i in range(0, len(xs) - 1, 2):
            xa, xb = xs[i], xs[i + 1]
            xs0 = max(0, math.ceil(xa - 0.5))
            xe = min(W - 1, math.ceil(xb - 0.5) - 1)
            if xs0 <= xe:
                grid[base + xs0: base + xe + 1] = bytes([pid]) * (xe - xs0 + 1)


def feature_bbox(coords):
    lons, lats = [], []
    stack = [coords]
    while stack:
        c = stack.pop()
        if isinstance(c[0], (int, float)):
            lons.append(c[0]); lats.append(c[1])
        else:
            stack.extend(c)
    return min(lons), max(lons), min(lats), max(lats)


def carve_line(grid, a, b):
    """Set a 4-connected line of water cells between two lon/lat points."""
    x0, y0 = to_cell(*a)
    x1, y1 = to_cell(*b)
    x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
    x, y = x0, y0
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx, sy = (1 if x1 > x0 else -1), (1 if y1 > y0 else -1)
    err = dx - dy
    while True:
        if 0 <= x < W and 0 <= y < H:
            grid[y * W + x] = 0
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy; x += sx
            if 0 <= x < W and 0 <= y < H:
                grid[y * W + x] = 0
        if e2 < dx:
            err += dx; y += sy


# ---------------------------------------------------------------- helpers

def neighbours4(i):
    x, y = i % W, i // W
    if x > 0: yield i - 1
    if x < W - 1: yield i + 1
    if y > 0: yield i - W
    if y < H - 1: yield i + W


def components(grid, predicate):
    """Connected components (4-neighbour) of cells satisfying predicate(cell_index)."""
    seen = bytearray(W * H)
    comps = []
    for start in range(W * H):
        if seen[start] or not predicate(start):
            continue
        comp = []
        dq = deque([start]); seen[start] = 1
        while dq:
            i = dq.popleft(); comp.append(i)
            for j in neighbours4(i):
                if not seen[j] and predicate(j):
                    seen[j] = 1; dq.append(j)
        comps.append(comp)
    return comps


def hsl_to_rgb(h, s, l):
    c = (1 - abs(2 * l - 1)) * s
    hp = (h % 360) / 60.0
    x = c * (1 - abs(hp % 2 - 1))
    r, g, b = [(c, x, 0), (x, c, 0), (0, c, x), (0, x, c), (x, 0, c), (c, 0, x)][int(hp) % 6]
    m = l - c / 2
    return tuple(int(round((v + m) * 255)) for v in (r, g, b))


def write_png(path, w, h, rgb):
    raw = b"".join(b"\x00" + rgb[y * w * 3:(y + 1) * w * 3] for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def hash_noise(x, y, seed=1337):
    n = (x * 374761393 + y * 668265263 + seed * 982451653) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


# ---------------------------------------------------------------- main pipeline

def main():
    print("loading", SRC)
    with open(SRC, encoding="utf-8") as f:
        data = json.load(f)

    # 1. pick features touching the bbox, assign temporary ids
    feats = []
    for f in data["features"]:
        p = f["properties"]
        admin = p.get("ADMIN")
        if admin in SKIP:
            continue
        lo0, lo1, la0, la1 = feature_bbox(f["geometry"]["coordinates"])
        if lo1 < LON0 or lo0 > LON1 or la1 < LAT0 or la0 > LAT1:
            continue
        feats.append(f)
    feats.sort(key=lambda f: f["properties"]["ADMIN"])
    void_feats = [f for f in feats if f["properties"]["ADMIN"] in VOID_COUNTRIES]
    feats = [f for f in feats if f["properties"]["ADMIN"] not in VOID_COUNTRIES]
    if len(feats) > 250:
        sys.exit("too many features for 8-bit ids")
    tmp_id = {f["properties"]["ADMIN"]: i + 1 for i, f in enumerate(feats)}
    props = {f["properties"]["ADMIN"]: f["properties"] for f in feats}

    # 2. rasterize
    grid = bytearray(W * H)
    for f in void_feats:                      # painted first so real countries win any overlap
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for rings in polys:
            rasterize_polygon(rings, grid, VOID)
    for f in feats:
        admin = f["properties"]["ADMIN"]
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for rings in polys:
            rasterize_polygon(rings, grid, tmp_id[admin])
    print("rasterized", len(feats), "features")

    # 3. carve straits
    for a, b in STRAITS:
        carve_line(grid, a, b)

    # 4. enclosed small water bodies -> land of the surrounding majority
    water_comps = components(grid, lambda i: grid[i] == 0)
    water_comps.sort(key=len, reverse=True)
    for comp in water_comps[1:]:
        if len(comp) >= LAKE_MAX:
            continue
        counts = defaultdict(int)
        for i in comp:
            for j in neighbours4(i):
                if grid[j]:
                    counts[grid[j]] += 1
        if counts:
            fill = max(counts, key=counts.get)
            for i in comp:
                grid[i] = fill
    print("water components kept:", sum(1 for c in water_comps if len(c) >= LAKE_MAX or c is water_comps[0]))

    # 5. merges: explicit, then by size
    def cells_of(pid):
        return [i for i in range(W * H) if grid[i] == pid]

    def border_lengths(pid):
        counts = defaultdict(int)
        for i in cells_of(pid):
            for j in neighbours4(i):
                if grid[j] and grid[j] != pid and grid[j] != VOID:
                    counts[grid[j]] += 1
        return counts

    def nearest_by_water(pid):
        seen = bytearray(W * H)
        dq = deque()
        for i in cells_of(pid):
            for j in neighbours4(i):
                if grid[j] == 0 and not seen[j]:
                    seen[j] = 1; dq.append(j)
        while dq:
            i = dq.popleft()
            for j in neighbours4(i):
                if grid[j] and grid[j] != pid and grid[j] != VOID:
                    return grid[j]
                if grid[j] == 0 and not seen[j]:
                    seen[j] = 1; dq.append(j)
        return 0

    def merge(src, dst):
        for i in range(W * H):
            if grid[i] == src:
                grid[i] = dst

    alive = dict(tmp_id)
    for name, target in MERGE_INTO.items():
        if name in alive and target in alive:
            merge(alive[name], alive[target]); del alive[name]
            print("merged", name, "->", target)
    changed = True
    while changed:
        changed = False
        sizes = defaultdict(int)
        for i in range(W * H):
            if grid[i]:
                sizes[grid[i]] += 1
        for name, pid in list(alive.items()):
            n = sizes.get(pid, 0)
            if n >= MIN_CELLS or name in FORCE_KEEP and n > 0:
                continue
            bl = border_lengths(pid)
            target = max(bl, key=bl.get) if bl else nearest_by_water(pid)
            tname = next((k for k, v in alive.items() if v == target), None)
            if target and tname:
                merge(pid, target); del alive[name]; changed = True
                print("merged (small, %d cells)" % n, name, "->", tname)
            elif n == 0:
                del alive[name]; changed = True
                print("dropped (no cells)", name)

    # 6. renumber ids 1..N in a stable order (by English name)
    order = sorted(alive.items(), key=lambda kv: kv[0])
    remap = {old: new + 1 for new, (name, old) in enumerate(order)}
    lut = bytes([VOID if v == VOID else remap.get(v, 0) for v in range(256)])
    grid = bytearray(grid.translate(lut))
    provinces = []
    for new, (name, _old) in enumerate(order):
        p = props[name]
        provinces.append({"id": new + 1, "name": p.get("NAME_RU") or name, "name_en": name,
                          "continent": p.get("CONTINENT")})
    id_by_name = {pr["name_en"]: pr["id"] for pr in provinces}
    N = len(provinces)
    print("provinces:", N)

    # 7. terrain
    terrain = bytearray(W * H)
    land_dist = [-1] * (W * H)       # distance from land for water cells
    dq = deque()
    for i in range(W * H):
        if grid[i]:
            land_dist[i] = 0; dq.append(i)
    while dq:
        i = dq.popleft()
        if land_dist[i] >= SHALLOW_DIST:
            continue
        for j in neighbours4(i):
            if land_dist[j] < 0:
                land_dist[j] = land_dist[i] + 1; dq.append(j)
    name_by_id = {pr["id"]: pr["name_en"] for pr in provinces}
    for i in range(W * H):
        pid = grid[i]
        x, y = i % W, i // W
        lon, lat = cell_center_lonlat(x, y)
        if pid == 0:
            terrain[i] = TERRAIN_SHALLOW if land_dist[i] > 0 else TERRAIN_DEEP
        elif lat >= SNOW_MIN_LAT:
            terrain[i] = TERRAIN_SNOW
        elif pid == VOID:
            terrain[i] = TERRAIN_SAND if lat < 36 else TERRAIN_GRASS
        elif name_by_id[pid] in SAND_COUNTRIES and lat < SAND_MAX_LAT:
            terrain[i] = TERRAIN_SAND
        else:
            terrain[i] = TERRAIN_GRASS
    for pts, radius in MOUNTAINS:
        cpts = [to_cell(lon, lat) for lon, lat in pts]
        for (ax, ay), (bx, by) in zip(cpts, cpts[1:]):
            length = math.hypot(bx - ax, by - ay)
            steps = max(1, int(length))
            for k in range(steps + 1):
                t = k / steps
                cx, cy = ax + (bx - ax) * t, ay + (by - ay) * t
                r = radius + 1
                for yy in range(int(cy - r), int(cy + r) + 1):
                    for xx in range(int(cx - r), int(cx + r) + 1):
                        if 0 <= xx < W and 0 <= yy < H:
                            d = math.hypot(xx + 0.5 - cx, yy + 0.5 - cy)
                            if d <= radius * (0.7 + 0.6 * hash_noise(xx, yy)):
                                i = yy * W + xx
                                if grid[i]:
                                    terrain[i] = TERRAIN_MOUNTAIN

    # 8. adjacency, coast, capitals
    land_adj = defaultdict(set)
    cells = defaultdict(list)
    coast = set()
    for i in range(W * H):
        pid = grid[i]
        if not pid or pid == VOID:
            continue
        cells[pid].append(i)
        x = i % W
        if x < W - 1:
            q = grid[i + 1]
            if q and q != pid and q != VOID:
                land_adj[pid].add(q); land_adj[q].add(pid)
        if i + W < W * H:
            q = grid[i + W]
            if q and q != pid and q != VOID:
                land_adj[pid].add(q); land_adj[q].add(pid)
        for j in neighbours4(i):
            if grid[j] == 0:
                coast.add(i); break

    sea_adj = defaultdict(set)
    for pid in range(1, N + 1):
        seen = bytearray(W * H)
        dq = deque()
        for i in cells[pid]:
            if i in coast:
                for j in neighbours4(i):
                    if grid[j] == 0 and not seen[j]:
                        seen[j] = 1; dq.append((j, 1))
        while dq:
            i, d = dq.popleft()
            for j in neighbours4(i):
                q = grid[j]
                if q == VOID:
                    continue
                if q and q != pid:
                    sea_adj[pid].add(q); sea_adj[q].add(pid)
                elif q == 0 and not seen[j] and d < SEA_REACH:
                    seen[j] = 1; dq.append((j, d + 1))

    for pr in provinces:
        pid = pr["id"]
        cs = cells[pid]
        pr["cells"] = len(cs)
        pr["coastal"] = any(i in coast for i in cs)
        p = props[pr["name_en"]]
        if p.get("LABEL_X") is not None and p.get("LABEL_Y") is not None:
            mx, my = to_cell(p["LABEL_X"], p["LABEL_Y"])   # Natural Earth's curated label point
            mx -= 0.5; my -= 0.5
        else:
            mx = sum(i % W for i in cs) / len(cs)
            my = sum(i // W for i in cs) / len(cs)
        best = min(cs, key=lambda i: (i % W - mx) ** 2 + (i // W - my) ** 2)
        pr["capital"] = {"x": best % W, "y": best // W}
        if pr["coastal"]:   # default port location: coast cell nearest to the capital
            cx, cy = best % W, best // W
            pc = min((i for i in cs if i in coast), key=lambda i: (i % W - cx) ** 2 + (i // W - cy) ** 2)
            pr["port_cell"] = {"x": pc % W, "y": pc // W}
        pr["land"] = sorted(land_adj[pid])
        pr["sea"] = sorted(sea_adj[pid] - land_adj[pid])
        if pr["name_en"] in FIXED_COLORS:
            rgb = FIXED_COLORS[pr["name_en"]]
        else:
            rgb = hsl_to_rgb(pid * 137.508 + 40, 0.5, 0.55)
        pr["color"] = "#%02x%02x%02x" % rgb

    # 9. self checks
    for pr in provinces:
        assert pr["cells"] >= 1, pr
        for q in pr["land"]:
            assert pr["id"] in provinces[q - 1]["land"], ("asymmetric land", pr["name_en"], q)
        for q in pr["sea"]:
            assert pr["id"] in provinces[q - 1]["sea"] or pr["id"] in provinces[q - 1]["land"], ("asymmetric sea", pr["name_en"], q)
    for name in PLAYER_FACTIONS.values():
        assert name in id_by_name, name + " missing"
        assert provinces[id_by_name[name] - 1]["coastal"], name + " must be coastal"
    it, tn = id_by_name["Italy"], id_by_name["Tunisia"]
    assert tn in provinces[it - 1]["sea"], "Italy and Tunisia must be sea neighbours"
    px, py = to_cell(13.36, 38.12)   # Palermo
    assert grid[int(py) * W + int(px)] == it, "Sicily must belong to Italy"
    assert all(grid[i] == 0 or grid[i] <= N or grid[i] == VOID for i in range(W * H))
    void_cells = sum(1 for i in range(W * H) if grid[i] == VOID)

    # 10. write outputs
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "province_ids.dat"), "wb") as f:
        f.write(bytes(grid))
    with open(os.path.join(OUT_DIR, "terrain.dat"), "wb") as f:
        f.write(bytes(terrain))
    meta = {
        "width": W, "height": H,
        "bbox": {"lon0": LON0, "lon1": round(LON1, 4), "lat0": LAT0, "lat1": LAT1, "xscale": XSCALE},
        "players": {k: id_by_name[v] for k, v in PLAYER_FACTIONS.items()},
        "void_id": VOID,
        "terrain_names": ["deep", "shallow", "grass", "sand", "snow", "mountain"],
        "provinces": provinces,
    }
    with open(os.path.join(OUT_DIR, "provinces.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, separators=(",", ":"))

    rgb = bytearray(W * H * 3)
    colors = {pr["id"]: tuple(int(pr["color"][k:k + 2], 16) for k in (1, 3, 5)) for pr in provinces}
    for i in range(W * H):
        pid = grid[i]
        r, g, b = TERRAIN_RGB[terrain[i]]
        if pid == VOID:
            r, g, b = (r * 2 + 90) // 3, (g * 2 + 90) // 3, (b * 2 + 90) // 3
        elif pid:
            border = any(grid[j] != pid for j in neighbours4(i))
            if border:
                r, g, b = 30, 24, 20
            else:
                cr, cg, cb = colors[pid]
                r, g, b = (r + cr) // 2, (g + cg) // 2, (b + cb) // 2
        rgb[i * 3:i * 3 + 3] = bytes((r, g, b))
    write_png(os.path.join(OUT_DIR, "preview.png"), W, H, bytes(rgb))

    print("%-24s %6s %5s %4s %4s" % ("province", "cells", "coast", "land", "sea"))
    for pr in provinces:
        print("%-24s %6d %5s %4d %4d" % (pr["name"], pr["cells"], "y" if pr["coastal"] else "-", len(pr["land"]), len(pr["sea"])))
    print("void cells (out of play):", void_cells)
    print("done ->", OUT_DIR)


if __name__ == "__main__":
    main()
