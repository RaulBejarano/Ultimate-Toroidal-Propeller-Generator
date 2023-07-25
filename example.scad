use <src/toroidal_propeller.scad>

toroidal_propeller(
    $fn = 100,                      // how polligonall you want the model
    blades = 3,                     // number of blades | Default(3)
    height = 6,                     // height | Default(6)
    blade_length = 68,              // blade length | Default(68)
    blade_width = 42,               // blade width | Default(42)
    blade_thickness = 4,            // blade thickness | Default(4)
    blade_hole_offset = 1.4,        // blade hole offset | Default(1.4)
    blade_twist = 15,               // blade twist angle | Default(15)
    blade_offset = -6,              // blade distance from propeller axis | Default(-6)
    safe_blades_direction = "PREV", // indicates if a blade must delete itself from getting into the previous (PREV) or the next blade (NEXT) | Default("PREV")
    hub_d = 16,                     // hub diameter | Default(16)
    hub_screw_d = 5.5,              // hub screw diameter | Default(5.5)
    eh_l = 0,                       // length of the emptying of the hub | Default(0 = [No support])
    eh_d = 0                        // diameter of the hollowing of the hub | Default(0 = [No support])
);
