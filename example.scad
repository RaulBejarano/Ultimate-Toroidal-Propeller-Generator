use <src/toroidal_propeller.scad>

//$fn = 100;
toroidal_propeller(
    blades = 3,                 // number of blades
    height = 5,                 // height
    blade_length = 50,          // blade length
    blade_width = 50,           // blade width
    blade_thickness = 4,        // blade thickness
    blade_hole_offset = 1.2,    // blade hole offset
    blade_twist = 30,           // blade twist angle
    hub_d = 15,                 // hub diameter
    hub_screw_d = 5             // hub screw diameter
);