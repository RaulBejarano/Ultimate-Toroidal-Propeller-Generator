use <src/toroidal_propeller.scad>
$fn = 100;                      // how polligonall you want the model

toroidal_propeller(
    blades = 3,                     // number of blades | Default(3)
    height = 6,                     // height | Default(6)
    blade_length = 68,              // blade length | Default(68)
    blade_width = 42,               // blade width | Default(42)
    blade_thickness = 4,            // blade thickness | Default(4)
    blade_hole_offset = 1.4,        // blade hole offset | Default(1.4)
    blade_attack_angle = 35,        // blade attack angle | Default(35)
    blade_offset = -6,              // blade distance from propeller axis | Default(-6)
    blade_safe_direction = "PREV",  // indicates if a blade must delete itself from getting into the previous (PREV) or the next blade (NEXT) | Default("PREV")
    hub_height = 6,                 // Hub height | Default(6)
    hub_d = 16,                     // hub diameter | Default(16)
    hub_screw_d = 5.5,              // hub screw diameter | Default(5.5)
    hub_notch_height = 0,           // height for the notch | Default(0 = [No support])
    hub_notch_d = 0                 // diameter for the notch | Default(0 = [No support])
);
