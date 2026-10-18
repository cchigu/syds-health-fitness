"""Run from the project folder: python tool/make_icon.py

Pixel-art app icon: Syd flexing with Willy the Himalayan cat, in a cozy
farm-game style (sky, hills, fence, flowers, wooden frame).

Drawn on a 64x64 grid, auto-outlined, then scaled up with nearest-neighbour
so every pixel stays crisp.
"""
from PIL import Image

N = 64
SCALE = 16  # 64 * 16 = 1024

# ---------------------------------------------------------------- palette
C = {
    # scene
    'sky1': (120, 196, 236), 'sky2': (146, 210, 242), 'sky3': (178, 224, 246),
    'cloud': (255, 255, 255), 'cloud_s': (222, 236, 246),
    'hill': (110, 176, 90), 'hill_d': (88, 150, 74),
    'grass': (122, 196, 74), 'grass_d': (92, 162, 56), 'grass_l': (156, 214, 96),
    'fence': (196, 140, 80), 'fence_d': (150, 100, 56),
    'flower_p': (240, 120, 160), 'flower_y': (250, 214, 90), 'flower_w': (255, 250, 240),
    'sun': (255, 228, 120), 'sun_l': (255, 244, 180),
    'frame_o': (74, 46, 26), 'frame': (176, 112, 54), 'frame_l': (224, 168, 92),
    # characters
    'out': (52, 32, 26),
    'hair': (170, 122, 78), 'hair_l': (222, 184, 128), 'hair_d': (128, 88, 54),
    'skin': (248, 214, 192), 'skin_s': (232, 182, 156), 'cheek': (240, 150, 150),
    'eye': (60, 42, 34), 'eye_w': (255, 255, 255), 'mouth': (200, 100, 96),
    'top': (232, 93, 142), 'top_d': (184, 59, 107), 'top_l': (250, 150, 186),
    'shorts': (78, 112, 168), 'shorts_d': (58, 84, 132),
    'shoe': (90, 58, 42), 'shoe_l': (130, 90, 66),
    'spark': (255, 236, 120),
    'heart': (240, 80, 120), 'heart_l': (255, 160, 190),
    # Willy (Himalayan: cream body, seal-brown points, blue eyes)
    'cat': (240, 228, 210), 'cat_s': (214, 196, 170), 'cat_w': (255, 250, 242),
    'cat_pt': (78, 54, 40), 'cat_pt_l': (110, 80, 60),
    'cat_eye': (120, 190, 235), 'cat_nose': (40, 26, 22),
}

# -------------------------------------------------------------- helpers
scene = [[None] * N for _ in range(N)]   # background
chars = [[None] * N for _ in range(N)]   # characters (get outlined)
fx = [[None] * N for _ in range(N)]      # on top, no outline (sparkles)


def put(layer, x, y, c):
    if 0 <= x < N and 0 <= y < N:
        layer[y][x] = C[c] if isinstance(c, str) else c


def rect(layer, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(layer, x, y, c)


def ellipse(layer, cx, cy, rx, ry, c):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                put(layer, x, y, c)


def sprite(layer, x0, y0, rows, key):
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != '.':
                put(layer, x0 + dx, y0 + dy, key[ch])


# ---------------------------------------------------------------- scene
for y in range(N):
    band = 'sky1' if y < 14 else ('sky2' if y < 26 else 'sky3')
    for x in range(N):
        put(scene, x, y, band)

# sun (top right)
ellipse(scene, 52, 11, 4.2, 4.2, 'sun')
ellipse(scene, 51, 10, 2.2, 2.2, 'sun_l')

# clouds
for cx, cy in [(13, 9), (32, 6)]:
    ellipse(scene, cx, cy, 4.5, 1.8, 'cloud')
    ellipse(scene, cx - 2, cy - 1, 2.5, 1.6, 'cloud')
    ellipse(scene, cx + 2, cy - 1.2, 2.2, 1.6, 'cloud')
    rect(scene, cx - 4, cy + 1, cx + 4, cy + 1, 'cloud_s')

# far hills
for x in range(N):
    h1 = 36 - int(3.2 * __import__('math').sin(x / 9.0 + 0.5))
    for y in range(h1, N):
        put(scene, x, y, 'hill')
    put(scene, x, h1, 'hill_d') if x % 7 == 0 else None

# fence (behind characters)
for y in (41, 44):
    rect(scene, 0, y, N - 1, y, 'fence')
    rect(scene, 0, y + 1, N - 1, y + 1, 'fence_d')
for x in range(2, N, 8):
    rect(scene, x, 38, x + 1, 47, 'fence')
    rect(scene, x + 1, 38, x + 1, 47, 'fence_d')
    put(scene, x, 37, 'fence')

# grass
for y in range(47, N):
    for x in range(N):
        put(scene, x, y, 'grass')
for x in range(N):
    put(scene, x, 47, 'grass_l')
import random
random.seed(7)
for _ in range(70):
    x, y = random.randrange(N), random.randrange(49, N)
    put(scene, x, y, 'grass_d')
    put(scene, x, y - 1, 'grass_d') if random.random() < 0.5 else None
# flowers
for x, y, col in [(6, 52, 'flower_p'), (10, 57, 'flower_y'), (15, 53, 'flower_w'),
                  (36, 60, 'flower_p'), (58, 58, 'flower_y'), (60, 51, 'flower_p'),
                  (4, 60, 'flower_w')]:
    put(scene, x, y, col)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        put(scene, x + dx, y + dy, col)
    put(scene, x, y, 'flower_y' if col != 'flower_y' else 'flower_w')

# ------------------------------------------------------------- Syd
# Long wavy hair behind head and shoulders.
ellipse(chars, 26, 18, 8.6, 8.8, 'hair')
rect(chars, 17, 18, 35, 31, 'hair')
for x, y in [(17, 32), (18, 33), (21, 32), (31, 32), (34, 33), (35, 32)]:
    put(chars, x, y, 'hair')
# hair shading / highlights (waves)
for y in range(19, 31):
    put(chars, 18, y, 'hair_d' if y % 4 == 0 else 'hair')
    put(chars, 34, y, 'hair_d' if y % 4 == 2 else 'hair')
    put(chars, 19, y, 'hair_l' if y % 4 in (1, 2) else 'hair')
    put(chars, 33, y, 'hair_l' if y % 4 in (3, 0) else 'hair')

# Face
ellipse(chars, 26, 19.5, 6.2, 7.0, 'skin')
rect(chars, 21, 24, 31, 25, 'skin')
# curtain bangs: parted in the middle, sweeping to the sides
sprite(chars, 19, 11, [
    "..HHHHHHHHHHHH..",
    ".HHLLHHHHHLLHHH.",
    "HHHLHHHH.HHHLHHH",
    "HHHHHH.....HHHHH",
    "HHHH.........HHH",
    "HHH...........HH",
], {'H': 'hair', 'L': 'hair_l'})
# side strands framing the face
for y in range(17, 27):
    put(chars, 20, y, 'hair')
    put(chars, 32, y, 'hair')
put(chars, 21, 17, 'hair'); put(chars, 31, 17, 'hair')

# eyes (soft, smiling), brows hint, cheeks, mouth
for ex in (23, 29):
    put(chars, ex, 19, 'eye'); put(chars, ex + 1, 19, 'eye')
    put(chars, ex, 20, 'eye'); put(chars, ex + 1, 20, 'eye_w')
put(chars, 23, 18, 'hair_d'); put(chars, 24, 18, 'hair_d')
put(chars, 29, 18, 'hair_d'); put(chars, 30, 18, 'hair_d')
for x in (22, 23):
    put(chars, x, 22, 'cheek')
for x in (30, 31):
    put(chars, x, 22, 'cheek')
put(chars, 26, 22, 'skin_s')                       # nose
put(chars, 24, 24, 'mouth'); put(chars, 28, 24, 'mouth')
for x in (25, 26, 27):
    put(chars, x, 25, 'mouth')

# neck
rect(chars, 25, 26, 27, 27, 'skin')
put(chars, 25, 27, 'skin_s'); put(chars, 27, 27, 'skin_s')

# tank top
rect(chars, 21, 28, 31, 40, 'top')
rect(chars, 20, 29, 32, 39, 'top')
rect(chars, 23, 28, 29, 28, 'skin')                 # neckline
put(chars, 24, 29, 'skin'); put(chars, 25, 29, 'skin'); put(chars, 26, 29, 'skin')
put(chars, 27, 29, 'skin'); put(chars, 28, 29, 'skin')
for y in range(30, 40):
    put(chars, 31, y, 'top_d'); put(chars, 32, y, 'top_d')
for y in range(31, 38):
    put(chars, 21, y, 'top_l')
# little heart on the top
for x, y in [(25, 33), (27, 33), (25, 34), (26, 34), (27, 34), (26, 35)]:
    put(chars, x, y, 'top_l')

# long hair falling in front of both shoulders
for x0, wave in ((20, (0, 0, 1, 1, 0, 0, -1, 0, 0)), (31, (0, 0, -1, -1, 0, 0, 1, 0, 0))):
    for i, y in enumerate(range(27, 36)):
        put(chars, x0 + wave[i], y, 'hair')
        put(chars, x0 + 1 + wave[i], y, 'hair_l' if i in (1, 6) else 'hair')
put(chars, 21, 36, 'hair'); put(chars, 31, 36, 'hair')

# shorts
rect(chars, 21, 41, 31, 45, 'shorts')
rect(chars, 26, 43, 26, 45, 'shorts_d')
rect(chars, 21, 41, 31, 41, 'shorts_d')

# legs + shoes
rect(chars, 22, 46, 24, 54, 'skin')
rect(chars, 28, 46, 30, 54, 'skin')
put(chars, 24, 47, 'skin_s'); put(chars, 30, 47, 'skin_s')
rect(chars, 21, 55, 25, 57, 'shoe')
rect(chars, 27, 55, 31, 57, 'shoe')
rect(chars, 22, 55, 24, 55, 'shoe_l')
rect(chars, 28, 55, 30, 55, 'shoe_l')

# Flexing arm (her right = viewer's left): upper arm out, bicep peak,
# forearm straight up, fist on top.
rect(chars, 12, 29, 20, 32, 'skin')                 # upper arm
rect(chars, 12, 28, 17, 28, 'skin')                 # bicep...
rect(chars, 13, 27, 16, 27, 'skin')
rect(chars, 14, 26, 15, 26, 'skin')                 # ...peak!
put(chars, 16, 27, 'skin_s'); put(chars, 17, 28, 'skin_s')
for x in range(12, 20):
    put(chars, x, 32, 'skin_s')                     # underside shadow
rect(chars, 9, 28, 12, 32, 'skin')                  # elbow
put(chars, 9, 32, 'skin_s'); put(chars, 10, 32, 'skin_s')
rect(chars, 9, 21, 12, 27, 'skin')                  # forearm
for y in range(21, 31):
    put(chars, 9, y, 'skin_s')
rect(chars, 9, 20, 11, 20, 'skin')                  # wrist
# fist (rounded), fingers curled toward her
rect(chars, 9, 15, 12, 15, 'skin')
rect(chars, 8, 16, 13, 19, 'skin')
for y in (16, 17, 18):
    put(chars, 13, y, 'skin_s')                     # finger tips
put(chars, 10, 17, 'skin_s'); put(chars, 11, 17, 'skin_s')  # thumb line
put(chars, 8, 19, 'skin_s')

# Other arm, relaxed at her side
rect(chars, 33, 29, 35, 39, 'skin')
for y in range(30, 39):
    put(chars, 35, y, 'skin_s')
rect(chars, 33, 40, 35, 41, 'skin')

# ------------------------------------------------------------- Willy
# Fluffy cream body, sitting
ellipse(chars, 47.5, 51, 7.5, 6.5, 'cat')
ellipse(chars, 47.5, 54, 8.2, 4.0, 'cat')
ellipse(chars, 47.5, 49, 4.2, 4.5, 'cat_w')        # white chest ruff
for x, y in [(41, 50), (42, 53), (53, 51), (54, 54), (52, 56), (43, 56)]:
    put(chars, x, y, 'cat_s')
# fluff tufts on the edges
for x, y in [(39, 52), (39, 55), (56, 52), (56, 55), (40, 48), (55, 48)]:
    put(chars, x, y, 'cat')

# Tail (seal point), curling up on the right
for x, y in [(56, 57), (57, 57), (58, 56), (59, 55), (59, 54), (59, 53),
             (58, 52), (57, 53), (58, 53), (58, 54), (58, 55), (57, 56)]:
    put(chars, x, y, 'cat_pt')
put(chars, 58, 52, 'cat_pt_l')

# Front paws
rect(chars, 43, 57, 45, 58, 'cat_pt')
rect(chars, 50, 57, 52, 58, 'cat_pt')
put(chars, 44, 57, 'cat_pt_l'); put(chars, 51, 57, 'cat_pt_l')

# Big round fluffy head
ellipse(chars, 47.5, 41.5, 7.2, 5.9, 'cat')
ellipse(chars, 47.5, 44.0, 6.2, 3.6, 'cat')            # fluffy cheeks
for x, y in [(41, 41), (54, 41), (42, 45), (53, 45), (47, 47), (48, 47)]:
    put(chars, x, y, 'cat')
# ears (dark, small, set wide like a Himalayan)
for x, y in [(42, 36), (42, 37), (43, 37), (43, 36), (42, 35)]:
    put(chars, x, y, 'cat_pt')
for x, y in [(53, 36), (53, 37), (52, 37), (52, 36), (53, 35)]:
    put(chars, x, y, 'cat_pt')
# seal-brown face mask
ellipse(chars, 47.5, 42.8, 4.6, 3.4, 'cat_pt')
ellipse(chars, 47.5, 44.2, 2.2, 1.6, 'cat_pt_l')
put(chars, 47, 39, 'cat_pt'); put(chars, 48, 39, 'cat_pt')   # mask up the forehead
# blue eyes, a little sleepy/grumpy like the photo
for ex in (45, 49):
    put(chars, ex, 42, 'cat_eye'); put(chars, ex + 1, 42, 'cat_eye')
    put(chars, ex, 41, 'cat_pt'); put(chars, ex + 1, 41, 'cat_pt')
put(chars, 47, 44, 'cat_nose'); put(chars, 48, 44, 'cat_nose')
put(chars, 47, 45, 'cat_pt'); put(chars, 48, 45, 'cat_pt')
# whiskers peeking out
for x, y in [(40, 43), (39, 44), (55, 43), (56, 44)]:
    put(fx, x, y, 'cat_w')

# ------------------------------------------------------------ effects
# sparkles by the bicep
for cx, cy in [(5, 24), (6, 12), (17, 23)]:
    put(fx, cx, cy, 'spark')
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        put(fx, cx + dx, cy + dy, 'spark')
# floating heart between Syd and Willy
heart = [
    ".HH.HH.",
    "HLHHHHH",
    "HHHHHHH",
    ".HHHHH.",
    "..HHH..",
    "...H...",
]
sprite(fx, 39, 25, heart, {'H': 'heart', 'L': 'heart_l'})
for x, y in [(38, 25), (38, 26), (46, 25), (46, 26), (39, 24), (40, 24),
             (42, 24), (43, 24), (44, 24), (45, 24)]:
    pass  # (outline added below)


def outline_layer(layer):
    """Dark outline around everything in a layer (classic farm-game look)."""
    out = [row[:] for row in layer]
    for y in range(N):
        for x in range(N):
            if layer[y][x] is None:
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < N and 0 <= ny < N and layer[ny][nx] is not None:
                        out[y][x] = C['out']
                        break
    return out


# heart gets its own outline
heart_layer = [[None] * N for _ in range(N)]
sprite(heart_layer, 39, 25, heart, {'H': 'heart', 'L': 'heart_l'})
heart_layer = outline_layer(heart_layer)
chars_o = outline_layer(chars)


def compose(with_frame=True):
    img = Image.new('RGB', (N, N))
    px = img.load()
    for y in range(N):
        for x in range(N):
            c = scene[y][x]
            if chars_o[y][x] is not None:
                c = chars_o[y][x]
            if heart_layer[y][x] is not None:
                c = heart_layer[y][x]
            if fx[y][x] is not None and heart_layer[y][x] is None:
                c = fx[y][x]
            px[x, y] = c
    if with_frame:
        for i, col in enumerate(['frame_o', 'frame', 'frame', 'frame_l']):
            for k in range(N):
                for (x, y) in ((k, i), (k, N - 1 - i), (i, k), (N - 1 - i, k)):
                    if i <= min(x, y, N - 1 - x, N - 1 - y) <= i:
                        px[x, y] = C[col]
        # wood grain notches
        for k in range(6, N - 6, 9):
            for (x, y) in ((k, 1), (k, N - 2), (1, k), (N - 2, k)):
                px[x, y] = C['frame_o']
    return img


icon = compose(with_frame=True).resize((N * SCALE, N * SCALE), Image.NEAREST)
icon.save('assets/icon/app_icon.png')

# Android adaptive icon: art without the frame, scaled into the safe zone on a
# transparent canvas; the sky colour fills the background layer.
# 704 = 64 * 11 keeps pixels even and fully covers the round mask.
art = compose(with_frame=False).resize((704, 704), Image.NEAREST)
fg = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
fg.paste(art, (160, 160))
fg.save('assets/icon/app_icon_foreground.png')
print('saved', icon.size, fg.size)
