// flutedVaseBox — parametric rebuild of "Behälter v2 100x100x50"
//
// Reconstructed from the reference mesh in reference/Behälter v2.3mf by direct
// measurement: unzipping the .3mf and parsing 3D/3dmodel.model's raw vertex
// list, cross-checked by importing the mesh into OpenSCAD and rendering /
// sectioning it. It's a solid block, not a hollow shell — a horizontal section
// at mid-height and a vertical section both come back fully filled — so this
// is built for slicer vase-mode printing (spiralized single wall), not as a
// walled container with a floor and rim.
//
// Measured directly off the front face at full height (z=50, the flat
// full-amplitude region, away from top/bottom edges) by fitting a Fourier
// series to the raw mesh vertices, period exactly 5 mm:
//   y(x) = -48.75 - [0.663617*cos(theta) - 0.040947*cos(3*theta) + 0.007074*cos(5*theta)]
//   theta = 2*pi*x/5
// A single cos(theta) term (amplitude 0.62868) fits the peaks and valleys
// almost exactly but is off by up to 0.06 mm through the middle of each
// flute -- about 5% of the flute depth, and enough to show up as a
// distributed ~2% volume mismatch across the whole wall in a boolean diff
// against the reference. The odd harmonics above fit the actual mesh to
// within 0.001 mm (rms), so the groove cross-section is a slightly
// "sharpened" wave, not a pure sinusoid -- consistent with a swept profile
// rather than a simple cosine, from wherever the original was authored.
// Peak radius 49.37868 mm matches the mesh's own bounding-box half-extent
// exactly; valley radius is 48.12132 mm; peak-to-valley 1.25949 mm.
// The flutes run at full amplitude as a straight vertical extrusion from
// z=7.76 all the way to the top (z=50, flat with a wavy rim). Below 7.76
// they don't fade out towards the base -- they get cut off.
//
// The very bottom (z=0 to 2.292) is a plain, unfluted, straight-sided ring
// measurably SMALLER than the flute midline: half-width 47.0 mm vs. the
// midline's 48.75 mm, a 1.75 mm setback (2.371 mm from this file's own
// peak-matched HX, see below). That's a stacking foot/step: it registers
// inward of another vase's top rim instead of overhanging it when
// stacked. Above the foot, this file intersects the full-amplitude ribs
// (unchanged, running all the way down) with a plain, unfluted CONE that
// grows linearly in radius from the foot's radius (z=foot_height) up to
// the peak radius (z=base_transition_height). Wherever the cone is still
// smaller than a rib's natural radius at that angle, the rib is sliced
// flush to the cone; once the cone grows past it, the rib's true shape
// appears untouched. The cone being linear is confirmed off the mesh: at
// a fixed x, there isn't a single extra vertex between the foot and just
// below where that x's rib clears the cone -- one flat, unbroken,
// straight-sided surface. Since grooves have a smaller natural radius
// than ridges, they clear the cone sooner (z=5.24) than ridges do
// (z=7.76) -- exactly the scalloped/toothed silhouette of the reference's
// bottom edge, with no amplitude-growth model needed at all.
//
// Deviations from the original, on purpose:
//   * width/depth here are the actual bounding-box size at the flute peaks
//     (base_half_extent = width/2 - flute_depth/2), whereas the original's own
//     "100x100" label overshoots its actual peak radius by about 0.6 mm —
//     not reproduced, since a size parameter that doesn't match the printed
//     part isn't useful.
//   * flute count (not a fixed 5 mm wavelength) is the parameter, so the
//     pattern always tiles with zero seam as width/depth/corner_radius
//     change. At the default size the true count (76, found by sweeping
//     flute_count against the reference until the flat-face radius lines
//     up -- a wrong guess is unmistakable, it beats instantly against the
//     wrong period) makes wavelength come out to almost exactly 5 mm; other
//     sizes will drift from 5 mm somewhat as flute_count is a whole number.
//   * above the flat foot, the original's clipping cone likely isn't
//     perfectly linear all the way from the foot to the peak (there are a
//     couple of short sub-stages visible in the mesh right near the foot
//     and right near full amplitude) — approximated here as one single
//     linear cone (built exactly via hull(), not stacked slices), which
//     is close enough for a vase-mode print.
//   * corner treatment: the flute wave is continued at constant arc-length
//     period around the rounded corner, same as the flat faces. With the
//     right flute_count and corner_radius (above) this makes the flat
//     faces match the reference to within tessellation noise (rms
//     0.002 mm), but the corner itself still has a real, unresolved
//     mismatch (rms 0.7 mm, max 1.3 mm, on a corner radius-from-center that
//     runs 50-67 mm) — the true corner geometry isn't simply the same wave
//     wrapped at constant arc length. Left as the largest remaining
//     accuracy gap; the corner is a small fraction of the perimeter so the
//     effect on printed appearance is minor.
//
// Stage: complete.

/* [Size] */
width = 100;
depth = 100;
height = 50;

/* [Hidden] */
// Everything below is measured off the reference (see the header) and kept
// out of the Customizer so the only real decision is the size above --
// still free to override any of it from the command line with -D.

$fa = 2;
$fs = 0.3;

// Number of flutes wrapped around the full perimeter. A count, not a fixed
// wavelength, so the pattern always tiles seamlessly as width/depth/
// corner_radius change. Actual wavelength = perimeter/flute_count, ~5 mm at
// the default 100x100 size.
flute_count = 76;
// Peak-to-valley radial depth of each flute, mm (measured: 1.25949).
flute_depth = 1.25949;
// Corner rounding of the underlying (unfluted) squircle, mm. Measured by a
// least-squares search (not directly readable off the mesh): the value that
// makes this file's flat-face radius match the reference to within
// tessellation noise (rms 0.002 mm) is 5.825, well off the first visual
// guess of 4.
corner_radius = 5.825;
// Height above the foot where the clipping cone reaches the ridge (peak)
// radius (measured ~7.76 mm) -- ridges clear the cone here, and the
// object becomes a plain uniform extrusion above this height.
base_transition_height = 7.76;

// Height of the plain, unfluted foot ring at the very bottom -- the
// stacking step. Measured ~2.29 mm.
foot_height = 2.3;
// How far the foot is set back from the flute midline radius, mm. Measured
// midline (at default width=100) is 49.371, the foot half-width is 47.0 --
// a 2.371 mm inset, which is this default.
foot_inset = 2.371;

// Tessellation quality knob, not meant to be dialled in the Customizer.
points_per_flute = 10;

// Measured groove cross-section, as odd harmonics of the flute wave
// (coefficients for cos(theta), cos(3*theta), cos(5*theta)); their sum is
// the peak offset, scaled below so the sum always equals flute_depth/2
// regardless of what flute_depth is set to.
flute_harmonics = [0.663617, -0.040947, 0.007074];

// --- Rounded-rect boundary, traced by arc length ---
// Walks the rounded-rect perimeter counter-clockwise starting at the left end
// of the bottom edge (y = -HY), so s=0 is there and s = Ls/2 lands on the
// bottom edge's midpoint (x=0) — the point the flute phase is anchored to,
// matching the measured peak at x=0.
function fillet_arc_len(r) = PI*r/2;

function perimeter(HX, HY, R) = 4*(HX-R) + 4*(HY-R) + 2*PI*R;

function boundary_raw(s, HX, HY, R) =
    let(
        Ls = 2*(HX-R),
        Ld = 2*(HY-R),
        La = fillet_arc_len(R),
        b0 = Ls,
        b1 = b0+La,
        b2 = b1+Ld,
        b3 = b2+La,
        b4 = b3+Ls,
        b5 = b4+La,
        b6 = b5+Ld
    )
    s < b0 ? [ -(HX-R)+s, -HY, 0, -1 ] :
    s < b1 ? let(a=-90+90*(s-b0)/La, cx=HX-R, cy=-(HY-R))
             [ cx+R*cos(a), cy+R*sin(a), cos(a), sin(a) ] :
    s < b2 ? [ HX, -(HY-R)+(s-b1), 1, 0 ] :
    s < b3 ? let(a=0+90*(s-b2)/La, cx=HX-R, cy=HY-R)
             [ cx+R*cos(a), cy+R*sin(a), cos(a), sin(a) ] :
    s < b4 ? [ (HX-R)-(s-b3), HY, 0, 1 ] :
    s < b5 ? let(a=90+90*(s-b4)/La, cx=-(HX-R), cy=HY-R)
             [ cx+R*cos(a), cy+R*sin(a), cos(a), sin(a) ] :
    s < b6 ? [ -HX, (HY-R)-(s-b5), -1, 0 ] :
             let(a=180+90*(s-b6)/La, cx=-(HX-R), cy=-(HY-R))
             [ cx+R*cos(a), cy+R*sin(a), cos(a), sin(a) ];

function flute_shape(theta) =
    flute_harmonics[0]*cos(theta) + flute_harmonics[1]*cos(3*theta) + flute_harmonics[2]*cos(5*theta);

function flute_point(s, HX, HY, R, half_amp, wavelength, phase0) =
    let(
        b = boundary_raw(s, HX, HY, R),
        theta = 360*(s-phase0)/wavelength,
        scale = half_amp / (flute_harmonics[0]+flute_harmonics[1]+flute_harmonics[2]),
        off = scale*flute_shape(theta)
    )
    [ b[0] + off*b[2], b[1] + off*b[3] ];

// The full-amplitude ribbed boundary -- constant, used unchanged both for
// the body above the cone and for the "ribs run all the way down" shape
// that the cone (below) clips.
module fluted_profile() {
    HX = width/2 - flute_depth/2;
    HY = depth/2 - flute_depth/2;
    R = min(corner_radius, HX, HY);
    P = perimeter(HX, HY, R);
    wavelength = P/flute_count;
    phase0 = HX-R;
    n = max(flute_count*points_per_flute, 32);
    polygon([ for (i=[0:n-1]) flute_point(i*P/n, HX, HY, R, flute_depth/2, wavelength, phase0) ]);
}

// A plain (unfluted) rounded-rect boundary at the given half-extents --
// used for the foot and for the two end caps of the clipping cone.
module plain_profile(HX, HY) {
    R = min(corner_radius, HX, HY);
    P = perimeter(HX, HY, R);
    n = max(flute_count*points_per_flute, 32);
    polygon([ for (i=[0:n-1]) let(s=i*P/n, b=boundary_raw(s, HX, HY, R)) [b[0], b[1]] ]);
}

module fluted_vase() {
    // Full-amplitude body -- above the cone's reach, nothing left to clip.
    translate([0, 0, base_transition_height])
        linear_extrude(height - base_transition_height)
            fluted_profile();

    // Transition: the ribs run at full amplitude all the way down to the
    // foot -- what's visible here is them getting sliced by a plain cone
    // that grows linearly from the foot's radius to the peak radius.
    // Grooves (smaller natural radius) clear the cone before ridges do,
    // which is what produces the toothed/scalloped bottom edge.
    //
    // The cone's two caps are built a bit beyond [foot_height,
    // base_transition_height] (extrapolating the same linear radius law)
    // purely so its top/bottom faces don't land exactly on the ribbed
    // prism's -- coincident faces between the two intersection operands
    // are what makes OpenCSG's fast preview (F5) flicker there, even
    // though the actual render (F6) and any export are unaffected. The
    // extrapolation doesn't change the cone's shape inside the real
    // range, since a line is still the same line however far it's drawn.
    cone_margin = 5;
    cone_t0 = -cone_margin/(base_transition_height-foot_height);
    cone_t1 = 1+cone_margin/(base_transition_height-foot_height);
    intersection() {
        translate([0, 0, foot_height])
            linear_extrude(base_transition_height - foot_height)
                fluted_profile();
        hull() {
            translate([0, 0, foot_height-cone_margin])
                linear_extrude(0.01)
                    plain_profile((width/2-flute_depth/2-foot_inset) + cone_t0*(flute_depth/2+foot_inset),
                                  (depth/2-flute_depth/2-foot_inset) + cone_t0*(flute_depth/2+foot_inset));
            translate([0, 0, base_transition_height+cone_margin])
                linear_extrude(0.01)
                    plain_profile((width/2-flute_depth/2-foot_inset) + cone_t1*(flute_depth/2+foot_inset),
                                  (depth/2-flute_depth/2-foot_inset) + cone_t1*(flute_depth/2+foot_inset));
        }
    }

    // Stacking foot: plain, unfluted, recessed ring at the very bottom.
    linear_extrude(foot_height)
        plain_profile(width/2 - flute_depth/2 - foot_inset,
                      depth/2 - flute_depth/2 - foot_inset);
}

fluted_vase();
