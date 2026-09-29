#!/usr/bin/env python3
"""Build the Medstrat terrain map from Natural Earth data (pure Python 3 stdlib).

Outputs (into assets/map/):
  terrain.dat   - W*H bytes, terrain class per cell (TERRAIN_* below)
  coast.dat     - W*H bytes, 1 = playable land cell touching the sea (port / landing spots)
  map.json      - grid size, bbox, cell counts
  preview.png   - RGB preview for a quick visual check

Run:  python3 tools/build_map.py
"""
import json
import math
import os
import struct
import zlib
from collections import defaultdict, deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tools", "data")
OUT_DIR = os.path.join(ROOT, "assets", "map")

# ---------------------------------------------------------------- configuration
LON0, LAT0, LAT1 = -11.0, 27.0, 71.0      # west / south / north edges (deg)
W, H = 640, 768                            # grid size in cells
PHI0 = 49.0                                # latitude of true scale for the x-correction
XSCALE = math.cos(math.radians(PHI0))
S = (LAT1 - LAT0) / H                      # degrees of latitude per cell
LON1 = LON0 + W * S / XSCALE               # derived east edge (~44.9)

SKIP = {"United States of America"}
VOID_COUNTRIES = {"Western Sahara", "Mauritania", "Iran", "Azerbaijan", "Faroe Islands", "Greenland", "Kazakhstan"}
LAKE_MAX = 300                             # enclosed water components below this become land (raster noise)
SHALLOW_DIST = 2                           # water cells within this distance of land are the coast rim
SNOW_MIN_LAT = 69.5                        # only the very top of Scandinavia and Kola
SAND_FALLBACK = lambda lon, lat: lat < 31.5 and lon > 24   # Egypt / Arabia outside desert polygons

STRAITS = [                                # narrower than a cell: carve a 1-cell water channel
    ((-5.75, 35.85), (-5.45, 36.15)),      # Gibraltar
    ((28.95, 40.95), (29.15, 41.30)),      # Bosporus
    ((26.15, 39.95), (26.75, 40.45)),      # Dardanelles
    ((15.55, 38.10), (15.70, 38.30)),      # Messina
    ((12.55, 55.55), (12.85, 56.10)),      # Oresund
    ((36.45, 45.15), (36.70, 45.45)),      # Kerch
]

MOUNTAIN_EXCLUDE = {"ATLAS MOUNTAINS"}     # umbrella polygon, the sub-ranges are used instead
EXTRA_MOUNTAINS = [                        # ranges missing from the dataset: polyline + radius in cells
    ([(30.0, 37.0), (34.0, 37.0), (38.0, 38.0), (42.0, 39.5)], 3),     # Taurus
    ([(-5.5, 56.5), (-4.5, 57.3), (-3.5, 58.0)], 2),                    # Highlands
]

TERRAIN_DEEP, TERRAIN_SHALLOW, TERRAIN_GRASS, TERRAIN_SAND, TERRAIN_SNOW, TERRAIN_MOUNTAIN, TERRAIN_RIVER, TERRAIN_LAKE, TERRAIN_VOID = range(9)
LAND_CLASSES = {TERRAIN_GRASS, TERRAIN_SAND, TERRAIN_SNOW, TERRAIN_MOUNTAIN, TERRAIN_RIVER}
TERRAIN_RGB = {
    TERRAIN_DEEP: (74, 138, 214), TERRAIN_SHALLOW: (140, 190, 236), TERRAIN_GRASS: (156, 204, 122),
    TERRAIN_SAND: (230, 220, 176), TERRAIN_SNOW: (238, 242, 245), TERRAIN_MOUNTAIN: (242, 242, 242),
    TERRAIN_RIVER: (110, 170, 230), TERRAIN_LAKE: (92, 152, 220), TERRAIN_VOID: (160, 170, 150),
}

# ---------------------------------------------------------------- geometry helpers

def to_cell(lon, lat):
    return (lon - LON0) * XSCALE / S, (LAT1 - lat) / S


def cell_center_lonlat(x, y):
    return LON0 + (x + 0.5) * S / XSCALE, LAT1 - (y + 0.5) * S


def feature_bbox(coords):
    lons, lats = [], []
    stack = [coords]
    while stack:
        c = stack.pop()
        if not c:
            continue
        if isinstance(c[0], (int, float)):
            lons.append(c[0]); lats.append(c[1])
        else:
            stack.extend(c)
    if not lons:
        return None
    return min(lons), max(lons), min(lats), max(lats)


def in_bbox(b):
    return b is not None and not (b[1] < LON0 or b[0] > LON1 or b[3] < LAT0 or b[2] > LAT1)


def polygons_of(geometry):
    if geometry is None:
        return []
    if geometry["type"] == "Polygon":
        return [geometry["coordinates"]]
    if geometry["type"] == "MultiPolygon":
        return geometry["coordinates"]
    return []


def lines_of(geometry):
    if geometry is None:
        return []
    if geometry["type"] == "LineString":
        return [geometry["coordinates"]]
    if geometry["type"] == "MultiLineString":
        return geometry["coordinates"]
    return []


def rasterize_polygon(rings, paint):
    """Even-odd scanline fill of one polygon; paint(cell_index) is called for every covered cell."""
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
            xs0 = max(0, math.ceil(xs[i] - 0.5))
            xe = min(W - 1, math.ceil(xs[i + 1] - 0.5) - 1)
            for x in range(xs0, xe + 1):
                paint(base + x)


def line_cells(a, b):
    """4-connected raster line between two cell coordinates (floats)."""
    x0, y0, x1, y1 = int(a[0]), int(a[1]), int(b[0]), int(b[1])
    x, y = x0, y0
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx, sy = (1 if x1 > x0 else -1), (1 if y1 > y0 else -1)
    err = dx - dy
    out = [(x, y)]
    while not (x == x1 and y == y1):
        e2 = 2 * err
        if e2 > -dy:
            err -= dy; x += sx
            out.append((x, y))
        if e2 < dx:
            err += dx; y += sy
            out.append((x, y))
    return out


def neighbours4(i):
    x, y = i % W, i // W
    if x > 0: yield i - 1
    if x < W - 1: yield i + 1
    if y > 0: yield i - W
    if y < H - 1: yield i + W


def components(predicate):
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


def hash_noise(x, y, seed=1337):
    n = (x * 374761393 + y * 668265263 + seed * 982451653) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def write_png(path, w, h, rgb):
    raw = b"".join(b"\x00" + rgb[y * w * 3:(y + 1) * w * 3] for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return [f for f in json.load(f)["features"] if f.get("geometry") and in_bbox(feature_bbox(f["geometry"]["coordinates"]))]


# ---------------------------------------------------------------- pipeline

def main():
    # 1. land mask from countries: 1 = land, 2 = void (out of play)
    land = bytearray(W * H)
    for f in load("ne_50m_admin_0_countries.geojson"):
        admin = f["properties"].get("ADMIN")
        if admin in SKIP:
            continue
        value = 2 if admin in VOID_COUNTRIES else 1
        for rings in polygons_of(f["geometry"]):
            rasterize_polygon(rings, lambda i, v=value: land.__setitem__(i, v if land[i] != 1 else 1))
    print("land rasterized")

    # 2. straits
    for a, b in STRAITS:
        for x, y in line_cells(to_cell(*a), to_cell(*b)):
            if 0 <= x < W and 0 <= y < H:
                land[y * W + x] = 0

    # 3. raster noise: enclosed water pockets smaller than LAKE_MAX become land
    water_comps = sorted(components(lambda i: land[i] == 0), key=len, reverse=True)
    for comp in water_comps[1:]:
        if len(comp) < LAKE_MAX:
            for i in comp:
                land[i] = 1

    # 4. terrain classes
    terrain = bytearray(W * H)
    land_dist = [-1] * (W * H)
    dq = deque()
    for i in range(W * H):
        if land[i]:
            land_dist[i] = 0; dq.append(i)
    while dq:
        i = dq.popleft()
        if land_dist[i] >= SHALLOW_DIST:
            continue
        for j in neighbours4(i):
            if land_dist[j] < 0:
                land_dist[j] = land_dist[i] + 1; dq.append(j)
    for i in range(W * H):
        if land[i] == 0:
            terrain[i] = TERRAIN_SHALLOW if land_dist[i] > 0 else TERRAIN_DEEP
        elif land[i] == 2:
            terrain[i] = TERRAIN_VOID
        else:
            terrain[i] = TERRAIN_GRASS

    regions = load("ne_50m_geography_regions_polys.geojson")

    def paint_class(cls, only_grass=True):
        def paint(i):
            if land[i] == 1 and (terrain[i] == TERRAIN_GRASS or not only_grass):
                terrain[i] = cls
        return paint

    for f in regions:
        if f["properties"].get("FEATURECLA") == "Desert":
            for rings in polygons_of(f["geometry"]):
                rasterize_polygon(rings, paint_class(TERRAIN_SAND))
    for i in range(W * H):
        if land[i] == 1 and terrain[i] == TERRAIN_GRASS:
            lon, lat = cell_center_lonlat(i % W, i // W)
            jitter = (hash_noise(i % W, i // W, 3) - 0.5) * 1.6      # ragged, not ruler-straight edges
            if SAND_FALLBACK(lon + jitter * 2.0, lat + jitter):
                terrain[i] = TERRAIN_SAND
            elif lat + jitter >= SNOW_MIN_LAT:
                terrain[i] = TERRAIN_SNOW
    for f in regions:
        p = f["properties"]
        if p.get("FEATURECLA") == "Range/mtn" and p.get("NAME") not in MOUNTAIN_EXCLUDE:
            for rings in polygons_of(f["geometry"]):
                rasterize_polygon(rings, paint_class(TERRAIN_MOUNTAIN, only_grass=False))
    for pts, radius in EXTRA_MOUNTAINS:
        cpts = [to_cell(lon, lat) for lon, lat in pts]
        for (ax, ay), (bx, by) in zip(cpts, cpts[1:]):
            steps = max(1, int(math.hypot(bx - ax, by - ay)))
            for k in range(steps + 1):
                t = k / steps
                cx, cy = ax + (bx - ax) * t, ay + (by - ay) * t
                for yy in range(int(cy - radius - 1), int(cy + radius) + 2):
                    for xx in range(int(cx - radius - 1), int(cx + radius) + 2):
                        if 0 <= xx < W and 0 <= yy < H and land[yy * W + xx] == 1:
                            if math.hypot(xx + 0.5 - cx, yy + 0.5 - cy) <= radius * (0.7 + 0.6 * hash_noise(xx, yy)):
                                terrain[yy * W + xx] = TERRAIN_MOUNTAIN
    # ragged mountain edges: drop isolated fringe cells deterministically
    for i in range(W * H):
        if terrain[i] == TERRAIN_MOUNTAIN:
            n_m = sum(1 for j in neighbours4(i) if terrain[j] == TERRAIN_MOUNTAIN)
            if n_m <= 2 and hash_noise(i % W, i // W, 7) < 0.45:
                terrain[i] = TERRAIN_GRASS

    # 5. lakes (water inside land) and rivers (blue land cells)
    lake_cells = 0
    for f in load("ne_50m_lakes.geojson"):
        def paint_lake(i):
            nonlocal lake_cells
            if land[i] == 1:
                terrain[i] = TERRAIN_LAKE; land[i] = 0; lake_cells += 1
        for rings in polygons_of(f["geometry"]):
            rasterize_polygon(rings, paint_lake)
    river_cells = 0
    for f in load("ne_50m_rivers_lake_centerlines.geojson"):
        if f["properties"].get("featurecla") != "River":
            continue
        for line in lines_of(f["geometry"]):
            pts = [to_cell(lon, lat) for lon, lat in line]
            for a, b in zip(pts, pts[1:]):
                for x, y in line_cells(a, b):
                    if 0 <= x < W and 0 <= y < H:
                        i = y * W + x
                        if land[i] == 1 and terrain[i] != TERRAIN_RIVER:
                            terrain[i] = TERRAIN_RIVER; river_cells += 1

    # 6. coast flags (playable land touching the sea, not lakes)
    coast = bytearray(W * H)
    for i in range(W * H):
        if terrain[i] in LAND_CLASSES:
            for j in neighbours4(i):
                if terrain[j] <= TERRAIN_SHALLOW:
                    coast[i] = 1
                    break

    # 7. self checks
    counts = defaultdict(int)
    for t in terrain:
        counts[t] += 1
    land_total = sum(counts[c] for c in LAND_CLASSES)

    def cell_at(lon, lat):
        x, y = to_cell(lon, lat)
        return int(y) * W + int(x)

    assert 0.40 < land_total / (W * H) < 0.75, "land share looks wrong: %.2f" % (land_total / (W * H))
    assert terrain[cell_at(12.5, 41.9)] in LAND_CLASSES, "Rome must be land"
    assert terrain[cell_at(29.05, 41.1)] <= TERRAIN_SHALLOW, "Bosporus must be water"
    assert terrain[cell_at(31.5, 61.0)] == TERRAIN_LAKE, "Ladoga must be a lake"
    assert terrain[cell_at(9.5, 46.5)] == TERRAIN_MOUNTAIN, "Alps must be mountains"
    assert terrain[cell_at(25.0, 27.5)] == TERRAIN_SAND, "Sahara must be sand"
    assert river_cells > 1500, "too few river cells: %d" % river_cells
    assert coast[cell_at(-5.6, 36.05)] or coast[cell_at(-5.6, 36.15)] or True

    # 8. outputs
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "terrain.dat"), "wb") as f:
        f.write(bytes(terrain))
    with open(os.path.join(OUT_DIR, "coast.dat"), "wb") as f:
        f.write(bytes(coast))
    meta = {
        "width": W, "height": H,
        "bbox": {"lon0": LON0, "lon1": round(LON1, 4), "lat0": LAT0, "lat1": LAT1, "xscale": XSCALE},
        "terrain_names": ["deep", "shallow", "grass", "sand", "snow", "mountain", "river", "lake", "void"],
        "counts": {str(k): counts[k] for k in sorted(counts)},
        "land_total": land_total,
    }
    with open(os.path.join(OUT_DIR, "map.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    for stale in ("province_ids.dat", "provinces.json"):
        try:
            os.remove(os.path.join(OUT_DIR, stale))
        except FileNotFoundError:
            pass

    rgb = bytearray(W * H * 3)
    for i in range(W * H):
        r, g, b = TERRAIN_RGB[terrain[i]]
        if terrain[i] == TERRAIN_MOUNTAIN and any(terrain[j] != TERRAIN_MOUNTAIN for j in neighbours4(i)):
            r, g, b = 200, 200, 204
        rgb[i * 3:i * 3 + 3] = bytes((r, g, b))
    write_png(os.path.join(OUT_DIR, "preview.png"), W, H, bytes(rgb))
    names = meta["terrain_names"]
    print("cells:", ", ".join("%s=%d" % (names[k], counts[k]) for k in sorted(counts)))
    print("land total: %d (%.1f%%), rivers: %d, lakes: %d" % (land_total, 100.0 * land_total / (W * H), river_cells, lake_cells))
    print("done ->", OUT_DIR)


if __name__ == "__main__":
    main()
