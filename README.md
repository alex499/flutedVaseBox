# flutedVase

Parametric OpenSCAD rebuild of `Behälter v2 100x100x50` — a rounded-square block
with a shallow vertical flute/rib texture wrapped around all four sides, originally
a static (non-parametric) mesh exported from FreeCAD. See the header comment in
`flutedvase.scad` for exactly what was measured off the reference mesh vs. what was
turned into a parameter, and the deviations taken on purpose.

## Attribution & license

The reference mesh is "Stackable Box (vase mode)" by **Chris (Aero)Engineering
Design**, published on Printables
(model 595626, https://www.printables.com/model/595626-stackable-box-vase-mode),
licensed **CC BY-NC-SA 4.0** (Attribution–NonCommercial–ShareAlike). Remixing is
permitted under that license; commercial use is not. As required by the
share-alike term, this derivative (`flutedvase.scad` and everything in this
folder) is licensed under those same CC BY-NC-SA 4.0 terms — see `LICENSE`.
Any redistribution must credit the original author and may not be used
commercially.

It's a **solid** model, not a hollow container: the original is solid too, and this
shape is meant for slicer **vase mode** (spiralized, single-wall) printing — don't
slice it with normal walls/infill, there's nothing inside.

The original mesh was used locally to measure the numbers documented in
`flutedvase.scad`'s header, but isn't part of this repo and isn't redistributed
here — get it from the Printables page above if you want to compare against it
yourself.

## Parameters (Customizer)

- `width`, `depth`, `height` — outer size in mm (bounding box at the flute peaks)
- `flute_count` — how many flutes wrap the full perimeter (period scales with size,
  ~5 mm at the 100×100 default)
- `flute_depth` — peak-to-valley depth of each flute, mm
- `corner_radius` — rounding of the underlying squircle
- `base_transition_height` — height at which the clipping cone (below) reaches
  the flute peak radius, i.e. where the ribs are no longer being cut off
- `foot_height`, `foot_inset` — the stacking foot: a plain, unfluted ring at the
  very bottom, set back from the flute midline so it registers inward of another
  vase's top rim instead of overhanging it when stacked. Above the foot, the
  full-amplitude ribs (which run all the way down) get intersected with a plain
  cone growing from the foot's radius to the peak radius, so they appear to
  emerge from the foot rather than fading in — grooves clear the cone before
  ridges do, giving the toothed/scalloped bottom edge

Rebuild after changing parameters from the command line:

```sh
openscad -o out.stl -D 'width=120' -D 'depth=80' -D 'height=60' flutedvase.scad
```

## Printing

Vase mode (spiralize outer contour), 1 wall, 0% infill, no top/bottom layers.
