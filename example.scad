use <src/toroidal_propeller.scad>

$fn = 100;
toroidal_propeller(
    blades = 3,                 // number of blades
    height = 5,                 // height
    blade_length = 63,          // blade length
    blade_width = 39,           // blade width
    blade_thickness = 4,        // blade thickness
    blade_hole_offset = 1.4,    // blade hole offset
    blade_twist = 25,           // blade twist angle
    blade_offset = 0,           // blade distance from propeller axis
    hub_d = 16,                 // hub diameter
    hub_screw_d = 5.2           // hub screw diameter
);
