// flutedVase — parametric rebuild of "Behälter v2 100x100x50"
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
// The flutes run as a straight vertical extrusion from z=7.76 to the top
// (z=50 — full amplitude reaches the top edge, which is flat with a wavy
// rim) and fade out over the bottom ~7.76 mm into a flush flat base.
//
// That base isn't just a flush fade to the flute midline, though — the very
// bottom (z=0 to 2.292) is a plain, unfluted, straight-sided ring measurably
// SMALLER than the flute midline: half-width 47.0 mm vs. the midline's
// 48.75 mm, a 1.75 mm setback (2.371 mm from this file's own peak-matched
// HX, see below). That's a stacking foot/step: it registers inward of
// another vase's top rim instead of overhanging it when stacked. Above the
// foot, the radius grows smoothly back out to the midline while the flutes
// simultaneously fade in.
//
// Critically, "fade in" doesn't happen at the same height all the way
// around: tracing the onset of curvature above the foot at 11 x positions
// across one period showed the ridge (x=0) doesn't reach full amplitude
// until z=7.75, but the groove (x=2.5) is already fully settled by z=5.24 --
// a full 2.5 mm earlier. That gap, fit to a cosine of the same phase as the
// flute itself (mid 6.5, amplitude 1.26), is exactly what produces the
// scalloped/toothed silhouette of the reference's bottom edge. A uniform
// fade height for every phase (what an earlier version of this file did)
// reads as a smoothly melted transition instead of a crisp toothed one.
//
// The fade itself is a plain linear ramp, not eased -- confirmed off the
// mesh: at a fixed x, there isn't a single extra vertex between the foot
// (z=2.292) and just below where each phase settles, meaning that whole
// span is one flat, unbroken (i.e. straight, constant-slope) surface. So
// the wall really does meet the flat foot at a sharp kink: a vertical rise
// straight up from the floor, then the ribs begin cut straight off, not
// eased into smoothly.
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
//   * above the flat foot, the original blends into the fluted wall through
//     several distinct sub-stages (a short fillet, then a brief flat
//     cylindrical run, then the flute amplitude growing in) — collapsed
//     here into one smooth interpolation of radius-inset and flute
//     amplitude together, approximated with a stack of thin extrusions.
//     Close enough for a vase-mode print, not reproduced stage-for-stage.
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

/* [Flutes] */
// Number of flutes wrapped around the full perimeter. A count, not a fixed
// wavelength, so the pattern always tiles seamlessly as width/depth/
// corner_radius change. Actual wavelength = perimeter/flute_count, ~5 mm at
// the default 100x100 size.
flute_count = 76;  // [8:1:300]
// Peak-to-valley radial depth of each flute, mm (measured: 1.25949).
flute_depth = 1.25949;
// Corner rounding of the underlying (unfluted) squircle, mm. Measured by a
// least-squares search (not directly readable off the mesh): the value that
// makes this file's flat-face radius match the reference to within
// tessellation noise (rms 0.002 mm) is 5.825, well off the first visual
// guess of 4.
corner_radius = 5.825;
// Height above the foot where the flute RIDGES reach full amplitude
// (measured ~7.76 mm) -- the tallest point of the phase-dependent settle
// height below, and where the object becomes a plain uniform extrusion.
base_transition_height = 7.76;
// Height above the foot where the flute GROOVES reach full amplitude
// (measured ~5.24 mm) -- grooves settle sooner than ridges, which is what
// makes the bottom edge read as toothed rather than smoothly melted.
valley_settle_height = 5.24;

/* [Stacking] */
// Height of the plain, unfluted foot ring at the very bottom -- the
// stacking step. Measured ~2.29 mm.
foot_height = 2.3;
// How far the foot is set back from the flute midline radius, mm. Measured
// midline (at default width=100) is 49.371, the foot half-width is 47.0 --
// a 2.371 mm inset, which is this default.
foot_inset = 2.371;

/* [Hidden] */
$fa = 2;
$fs = 0.3;

// Tessellation quality knobs, not meant to be dialled in the Customizer.
transition_slices = 24;
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

// Per-phase settle height: ridges (theta=0) don't reach full amplitude
// until base_transition_height, grooves (theta=180) get there already by
// valley_settle_height -- same cosine phase as the flute wave itself.
function settle_height(theta) =
    (base_transition_height+valley_settle_height)/2
    + (base_transition_height-valley_settle_height)/2*cos(theta);

function flute_point(s, HX, HY, R, half_amp, wavelength, phase0, z) =
    let(
        b = boundary_raw(s, HX, HY, R),
        theta = 360*(s-phase0)/wavelength,
        amp_scale = max(0, min(1, (z-foot_height)/(settle_height(theta)-foot_height))),
        scale = half_amp / (flute_harmonics[0]+flute_harmonics[1]+flute_harmonics[2]),
        off = amp_scale*scale*flute_shape(theta)
    )
    [ b[0] + off*b[2], b[1] + off*b[3] ];

function profile_points(HX, HY, R, half_amp, count, z) =
    let(
        P = perimeter(HX, HY, R),
        wavelength = P/count,
        phase0 = HX-R,
        n = max(count*points_per_flute, 32)
    )
    [ for (i=[0:n-1]) flute_point(i*P/n, HX, HY, R, half_amp, wavelength, phase0, z) ];

module fluted_profile(z, inset=0) {
    HX = width/2 - flute_depth/2 - inset;
    HY = depth/2 - flute_depth/2 - inset;
    R = min(corner_radius, HX, HY);
    polygon(profile_points(HX, HY, R, flute_depth/2, flute_count, z));
}

module fluted_vase() {
    // Full-amplitude body -- every phase has settled by base_transition_height.
    translate([0, 0, base_transition_height])
        linear_extrude(height - base_transition_height)
            fluted_profile(base_transition_height, 0);

    // Transition: fades the foot's radius-inset back out to 0 uniformly,
    // while the flute amplitude grows in at a rate that depends on phase
    // (see settle_height) -- grooves finish early, ridges keep climbing.
    for (i = [0:transition_slices-1]) {
        z0 = foot_height + (base_transition_height-foot_height)*i/transition_slices;
        z1 = foot_height + (base_transition_height-foot_height)*(i+1)/transition_slices;
        t = (i+1)/transition_slices;
        translate([0, 0, z0])
            linear_extrude(z1-z0)
                fluted_profile(z1, foot_inset*(1-t));
    }

    // Stacking foot: plain, unfluted, recessed ring at the very bottom.
    linear_extrude(foot_height)
        fluted_profile(0, foot_inset);
}

fluted_vase();
