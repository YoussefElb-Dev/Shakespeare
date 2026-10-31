"""Freeze bundled quote fonts at readable regular weights. Requires fonttools."""
from pathlib import Path
import os
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

root = Path(__file__).resolve().parents[1] / 'assets/fonts'
for name, axes in [('NotoSansHebrew.ttf', {'wght': 400, 'wdth': 100}),
                   ('CormorantGaramond.ttf', {'wght': 400})]:
    path = root / name
    font = TTFont(path)
    if 'fvar' not in font:
        font.close()
        continue
    result = instantiateVariableFont(font, axes, inplace=False)
    temp = path.with_suffix('.regular.ttf')
    result.save(temp)
    result.close()
    font.close()
    os.replace(temp, path)
    print(f'Normalized {name} to regular weight.')
