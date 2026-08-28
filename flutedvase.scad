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
// full-amplitude region, away from top/bottom edges):
//   y(x) = -48.75 - 0.62868*cos(2*pi*x/5)
// i.e. a radial flute of period exactly 5 mm and amplitude +/-0.62868 mm
// (1.25736 mm peak-to-valley) wrapped around a rounded-square cross-section.
// Peak radius 49.37868 mm matches the mesh's own bounding-box half-extent
// exactly; valley radius is 48.12132 mm.
// The flutes run as a straight vertical extrusion from z=7.76 to the top
// (z=50 — full amplitude reaches the top edge, which is flat with a wavy
// rim) and fade out over the bottom ~7.76 mm into a flush flat base.
//
// Deviations from the original, on purpose:
//   * width/depth here are the actual bounding-box size at the flute peaks
//     (base_half_extent = width/2 - flute_depth/2), whereas the original's own
//     "100x100" label overshoots its actual peak radius by about 0.6 mm —
//     not reproduced, since a size parameter that doesn't match the printed
//     part isn't useful.
//   * flute count (not a fixed 5 mm wavelength) is the parameter, so the
//     pattern always tiles with zero seam as width/depth/corner_radius
//     change — actual wavelength = perimeter/flute_count, ~5 mm at defaults.
//   * the bottom fillet is a straight amplitude fade with height (flat at
//     z=0, full amplitude at base_transition_height), approximated with a
//     stack of thin extrusions. The original's bottom edge is a fillet
//     along the actual wavy wall/floor intersection, which reads as a
//     slightly toothed/scalloped hem rather than a smooth fade — close
//     enough for a vase-mode print, not reproduced exactly (no CAD fillet
//     operation along an arbitrary 3D edge is available in plain OpenSCAD).
//   * corner treatment (how the flutes wrap the rounded corners) couldn't be
//     pinned down exactly from the raw mesh — approximated here by
//     continuing the same flute wave at constant arc-length period around a
//     simple rounded-rect corner.
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
flute_count = 78;  // [8:1:300]
// Peak-to-valley radial depth of each flute, mm (measured: 1.25736).
flute_depth = 1.25736;
// Corner rounding of the underlying (unfluted) squircle, mm.
corner_radius = 4;
// Height of the bottom fillet blending the flutes down into a flush flat
// base (measured ~7.76 mm).
base_transition_height = 7.76;

/* [Hidden] */
$fa = 2;
$fs = 0.3;

// Tessellation quality knobs, not meant to be dialled in the Customizer.
transition_slices = 24;
points_per_flute = 6;

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

function flute_point(s, HX, HY, R, half_amp, wavelength, phase0, amp_scale) =
    let(
        b = boundary_raw(s, HX, HY, R),
        off = amp_scale*half_amp*cos(360*(s-phase0)/wavelength)
    )
    [ b[0] + off*b[2], b[1] + off*b[3] ];

function profile_points(HX, HY, R, half_amp, count, amp_scale) =
    let(
        P = perimeter(HX, HY, R),
        wavelength = P/count,
        phase0 = HX-R,
        n = max(count*points_per_flute, 32)
    )
    [ for (i=[0:n-1]) flute_point(i*P/n, HX, HY, R, half_amp, wavelength, phase0, amp_scale) ];

module fluted_profile(amp_scale) {
    HX = width/2 - flute_depth/2;
    HY = depth/2 - flute_depth/2;
    polygon(profile_points(HX, HY, corner_radius, flute_depth/2, flute_count, amp_scale));
}

module fluted_vase() {
    // Full-amplitude body.
    translate([0, 0, base_transition_height])
        linear_extrude(height - base_transition_height)
            fluted_profile(1);

    // Bottom fillet: stepped loft fading amplitude from 0 (flush base) to 1
    // (matches the body above) over base_transition_height.
    for (i = [0:transition_slices-1]) {
        z0 = base_transition_height*i/transition_slices;
        z1 = base_transition_height*(i+1)/transition_slices;
        amp = (i+1)/transition_slices;
        translate([0, 0, z0])
            linear_extrude(z1-z0)
                fluted_profile(amp);
    }
}

fluted_vase();
