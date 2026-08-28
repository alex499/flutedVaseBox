# flutedVase

Parametric OpenSCAD rebuild of `Behälter v2 100x100x50` — a rounded-square block
with a shallow vertical flute/rib texture wrapped around all four sides, originally
a static (non-parametric) mesh exported from FreeCAD. See the header comment in
`flutedvase.scad` for exactly what was measured off the reference mesh vs. what was
turned into a parameter, and the deviations taken on purpose.

It's a **solid** model, not a hollow container: the original is solid too, and this
shape is meant for slicer **vase mode** (spiralized, single-wall) printing — don't
slice it with normal walls/infill, there's nothing inside.

## Files

| File | What it is |
|---|---|
| `flutedvase.scad` | parametric source |
| `reference/Behälter v2.3mf` | original reference mesh, used only for measurement (gitignored, not redistributed) |

## Parameters (Customizer)

- `width`, `depth`, `height` — outer size in mm (bounding box at the flute peaks)
- `flute_count` — how many flutes wrap the full perimeter (period scales with size,
  ~5 mm at the 100×100 default)
- `flute_depth` — peak-to-valley depth of each flute, mm
- `corner_radius` — rounding of the underlying squircle
- `base_transition_height` — how tall the bottom fillet is before flutes reach full
  depth
- `foot_height`, `foot_inset` — the stacking foot: a plain, unfluted ring at the
  very bottom, set back from the flute midline so it registers inward of another
  vase's top rim instead of overhanging it when stacked

Rebuild after changing parameters from the command line:

```sh
openscad -o out.stl -D 'width=120' -D 'depth=80' -D 'height=60' flutedvase.scad
```

## Printing

Vase mode (spiralize outer contour), 1 wall, 0% infill, no top/bottom layers.
