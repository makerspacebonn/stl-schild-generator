// ============================================================================
// Parametric name tag for 3D printing
// ----------------------------------------------------------------------------
//  - Rectangular, flat, `thickness` mm tall (default 2 mm)
//  - One short end rounded, with a keyring hole in that rounded end
//  - Name engraved ("inverse") into the top face, `text_depth` mm deep (default 1 mm)
//  - Length auto-fits the name via textmetrics()  ->  no name gets clipped
//
//  Render in the GUI: set `name` below, press F6, then Export as STL.
//
//  Command line (the --enable=textmetrics flag is REQUIRED for auto-fit):
//      openscad --enable=textmetrics -D 'name="Falk"' -o falk.stl nametag.scad
//
//  Batch:  ./generate.sh        (reads names.txt)
//          ./generate.sh "Anna" "Jörg"
// ============================================================================

/* [Text] */
// The name to engrave
name = "Sample";
// Font spec ("Family:style=...") — change to taste, e.g. "DejaVu Sans:style=Bold"
font = "Liberation Sans:style=Bold";
// Glyph size (mm)
text_size = 9;        // [4:0.5:20]
// How deep the text is engraved into the top face (mm)
text_depth = 1;       // [0.4:0.1:2]

/* [Tag body] */
// Tag thickness / Z height (mm)
thickness = 2;        // [1:0.5:6]
// Tag width — the short dimension / height of the tag (mm)
tag_width = 18;       // [10:1:40]
// Keyring hole diameter (mm)
hole_d = 5;           // [2:0.5:12]
// Distance of the hole center from the rounded tip (mm).
hole_inset = tag_width / 3;   // [3:0.5:25]
// Corner radius of the flat (square) end (mm). 0 = sharp corners.
corner_r = 3;         // [0:0.5:9]
// Gap between the keyring-hole zone and where the text starts (mm)
text_gap = 3;         // [0:0.5:10]
// Extra length past the text on the flat end (mm)
end_pad = 4;          // [0:0.5:15]

/* [Quality] */
// Curve smoothness (higher = smoother circles, slower)
$fn = 64;             // [16:8:128]

// ----------------------------------------------------------------------------
// Derived geometry
// ----------------------------------------------------------------------------
r        = tag_width / 2;                 // rounded-end radius = half the width
hole_x   = max(hole_inset, hole_d / 2 + 0.5);  // keep a tiny wall to the tip
tm       = textmetrics(name, size = text_size, font = font);
text_w   = tm.size[0];                    // rendered width of the name
text_x0  = hole_x + hole_d / 2 + text_gap; // text starts just past the hole
total_len = text_x0 + text_w + end_pad;   // full tag length

// Sanity (echoed to console on render):
//   wall around hole          = (tag_width - hole_d)/2   = 6.5 mm  (defaults)
//   hole distance from tip    =  r - hole_d/2            = 6.5 mm  (defaults)
echo(name = name, text_w = text_w, total_len = total_len,
     hole_wall_to_tip = hole_x - hole_d / 2);

// ----------------------------------------------------------------------------
// 2D outline: rounded on the left end; the right (flat) end corners are
// rounded by `corner_r` (set corner_r = 0 for sharp corners).
// ----------------------------------------------------------------------------
module outline() {
    cr = min(corner_r, r);   // clamp so it can never exceed the half-width
    hull() {
        translate([r, r]) circle(r);                          // rounded end
        if (cr > 0) {
            // two small circles at the flat-end corners -> rounded corners
            translate([total_len - cr, cr])             circle(cr);
            translate([total_len - cr, tag_width - cr]) circle(cr);
        } else {
            translate([total_len - 0.01, 0]) square([0.01, tag_width]); // sharp end
        }
    }
}

// ----------------------------------------------------------------------------
// Assemble: extruded body, minus keyring hole, minus engraved text
// ----------------------------------------------------------------------------
difference() {
    linear_extrude(thickness) outline();

    // Keyring hole, positioned `hole_x` from the tip, through the full thickness
    translate([hole_x, r, -0.01])
        cylinder(d = hole_d, h = thickness + 0.02);

    // Recessed text: occupies only the top `text_depth` mm of the body
    translate([text_x0 + text_w / 2, r, thickness - text_depth])
        linear_extrude(text_depth + 0.02)
            text(name, size = text_size, font = font,
                 halign = "center", valign = "center");
}
