"""Regenerate committed app icons. Optional tooling: pip install pillow numpy."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
size = 1024
y, x = np.mgrid[-1:1:complex(size), -1:1:complex(size)]
a = np.arctan2(y, x)
r = np.hypot(x, y)
radius = 0.66 + 0.025 * np.sin(a * 3 + 1) + 0.018 * np.sin(a * 5)
d = r - radius
inside = np.clip(-d * 700 + 0.5, 0, 1)
z = np.sqrt(np.clip(1 - (r / radius) ** 2, 0, 1))
blue = np.array([0.29, 0.46, 0.92])
pink = np.array([0.88, 0.48, 0.70])
mix = (0.5 + 0.5 * np.sin(a * 2 + 1.8))[..., None]
rim = blue * (1 - mix) + pink * mix
peach_mix = (np.clip(np.sin(a + 0.2), 0, 1) ** 5 * 0.7)[..., None]
rim = rim * (1 - peach_mix) + np.array([1, 0.75, 0.62]) * peach_mix
color = np.ones((size, size, 3)) * np.array([0.03, 0.035, 0.055])
color += ((1 - z) ** 2.6)[..., None] * rim * 0.76
for i in range(3):
    fold = 0.43 + i * 0.07 + 0.065 * np.sin(a * 2 + i * 1.7) + 0.03 * np.sin(a * 3 + i)
    line = np.exp(-((r - fold) / (0.025 + i * 0.008)) ** 2)
    shine = (0.5 + 0.5 * np.sin(a * 2 + i * 2)) ** 3
    color += (line * shine * (0.3 + i * 0.07))[..., None] * rim
color += (np.exp(-np.abs(d) * 180) * 0.7)[..., None] * rim
highlight = np.exp(-((x + 0.27) ** 2 + (y + 0.53) ** 2) / 0.001)
color += highlight[..., None] * np.array([0.4, 0.5, 0.7])
glow = np.exp(-np.abs(d) * 25) * 0.065
background = np.array([8, 9, 11]) / 255
color = color * inside[..., None] + (background + glow[..., None] * rim) * (1 - inside[..., None])
image = Image.fromarray(np.uint8(np.clip(color, 0, 1) * 255), 'RGB')
master = ROOT / 'assets' / 'icon.png'
image.save(master)
android = ROOT / 'android/app/src/main/res'
for density, pixels in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(android / f'mipmap-{density}/ic_launcher.png')
catalog = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for icon in json.loads((catalog / 'Contents.json').read_text())['images']:
    pixels = round(float(icon['size'].split('x')[0]) * float(icon['scale'].removesuffix('x')))
    image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(catalog / icon['filename'])
print('Generated Android and iOS icons from the liquid orb design.')
