use <src/toroidal_propeller.scad>

$fn = 100;
toroidal_propeller(
    blades = 3,                     // number of blades
    height = 6,                     // height
    blade_length = 68,              // blade length
    blade_width = 42,               // blade width
    blade_thickness = 4,            // blade thickne,    // blade hole offset
    blade_hole_offset = 1.4,        // blade hole offset
    blade_twist = 15,               // blade twist angle
    blade_offset = -6,              // blade distance from propeller axis
    safe_blades_direction = "PREV", // indicates if a blade must delete itself from getting into the previous (PREV) or the next blade (NEXT).
    hub_d = 16,                     // hub diameter
    hub_screw_d = 5.5,              // hub screw diameter
    shaft_face = 2,                 // optional setup for "slip-over" propeller - recess face thickness
    shaft_dia = 12                  // optional setup for "slip-over" propeller - recess diameter
);
