# flutedVaseBox

Parametric OpenSCAD rebuild of `Behälter v2 100x100x50` — a rounded-square block
with a shallow vertical flute/rib texture wrapped around all four sides, originally
a static (non-parametric) mesh exported from FreeCAD. See the header comment in
`flutedvasebox.scad` for exactly what was measured off the reference mesh vs. what was
turned into a parameter, and the deviations taken on purpose.

**[Configure one in your browser →](https://alex499.github.io/flutedVaseBox/)** — no
install, no account. The page runs this same `flutedvasebox.scad` through OpenSCAD
compiled to WebAssembly, so the STL it hands you is the one the command line would
produce.

## Attribution & license

The reference mesh is "Stackable Box (vase mode)" by **Chris (Aero)Engineering
Design**, published on Printables
(model 595626, https://www.printables.com/model/595626-stackable-box-vase-mode),
licensed **CC BY-NC-SA 4.0** (Attribution–NonCommercial–ShareAlike). Remixing is
permitted under that license; commercial use is not. As required by the
share-alike term, this derivative (`flutedvasebox.scad` and everything in this
folder) is licensed under those same CC BY-NC-SA 4.0 terms — see `LICENSE`.
Any redistribution must credit the original author and may not be used
commercially.

It's a **solid** model, not a hollow container: the original is solid too, and this
shape is meant for slicer **vase mode** (spiralized, single-wall) printing — don't
slice it with normal walls/infill, there's nothing inside.

The original mesh was used locally to measure the numbers documented in
`flutedvasebox.scad`'s header, but isn't part of this repo and isn't redistributed
here — get it from the Printables page above if you want to compare against it
yourself.

## Parameters (Customizer)

- `width`, `depth`, `height` — outer size in mm (bounding box at the flute peaks)

Everything else (flute count/depth, corner rounding, the stacking foot) is
measured off the reference and kept out of the Customizer, so the only real
decision is the size above — see the `/* [Hidden] */` section of
`flutedvasebox.scad` for what each of those does, and override any of them
from the command line if you want to:

```sh
openscad -o out.stl -D 'width=120' -D 'depth=80' -D 'height=60' -D 'flute_count=90' flutedvasebox.scad
```

## Printing

Vase mode (spiralize outer contour), 1 wall, 0% infill, no top/bottom layers.

## The browser configurator

[`web/`](web/) is a static page that renders this file in the browser: OpenSCAD itself,
compiled to WebAssembly, driven by the same `-D` flags you would type. There is no server
and nothing is uploaded — the model is fetched as plain text and rendered locally.

The address bar always carries the whole configuration, so a link reproduces a box
exactly: copy it to send someone a size, or bookmark it and let the browser sync it to
the machine next to the printer. Every parameter is written out rather than only the
ones that differ from a default, so an old link cannot quietly change meaning when a
default does.

```sh
cd web
yarn install
yarn serve      # builds _site/ and serves it on http://localhost:8080
```

`node verify.js` checks the page against the CLI: it drives the real worker, compares
signed volume and bounding box for a spread of sizes, and sweeps the width × depth ×
height slider range for a clean render. The sweep alone (`node verify.js sweep`) needs
no OpenSCAD installed and is what CI runs before deploying.

Editing `flutedvasebox.scad` needs no change here — the page reads it at run time. A
*new* Customizer parameter needs a control adding to `web/index.html`.
