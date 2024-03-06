eps=1/128;
$fn = 100;                          // how polligonall you want the model 

module toroidal_propeller(
    blades = 3,                     // number of blades
    height = 6,                     // height
    blade_length = 68,              // blade length in mm
    blade_width = 42,               // blade width in mm
    blade_thickness = 4,            // blade thickness in mm
    blade_hole_offset = 1.4,        // blade hole offset
    blade_attack_angle = 35,        // blade attack angle
    blade_offset = -6,              // blade distance from propeller axis
    blade_safe_direction = "PREV",  // indicates if a blade must delete itself from getting into the previous (PREV) or the next blade (NEXT).
    hub_height = 6,                 // Hub height
    hub_d = 16,                     // hub diameter
    hub_screw_d = 5.5,              // hub screw diameter
    hub_notch_height = 0,           // height for the notch 
    hub_notch_d = 0                 // diameter for the notch
){
    l = height / tan(blade_attack_angle);
    p = 2 * PI * blade_length/2;

    difference(){
        union(){
            linear_extrude(height=height, twist=l/p  * 360, convexity=2){
                blades2D(
                    n = blades,
                    height = height,
                    length = blade_length,
                    width = blade_width,
                    thickness = blade_thickness,
                    hole_offset = blade_hole_offset,
                    blade_direction = blade_attack_angle > 0 ? 1 : -1,
                    offset = blade_offset,
                    blade_safe_direction = 
                        blade_safe_direction == "PREV"? 1 : 
                        blade_safe_direction == "NEXT"? -1: 
                        0 // default
                );
            }

            cylinder(d = hub_d, h = hub_height);
        }
        translate([0,0,-eps]){
            cylinder(d = hub_screw_d, h = hub_height + 2*eps);
            cylinder(d = hub_notch_d, h = hub_notch_height + eps);
        }
    }
}

module blades2D(n, height, length, width, thickness, hole_offset, blade_direction, offset, blade_safe_direction){
    for(a=[0:n-1]){
        difference(){
            rotate([0,0,a*(360/n)]){
                translate([offset,0,0]) blade2D(
                    height = height,        // height
                    length = length,        // blade length in mm
                    width = width,          // blade width in mm
                    thickness = thickness,  // blade thickness in mm
                    hole_offset = hole_offset    // blade hole offset
                );
            }

            cw_ccw_mult = blade_direction * blade_safe_direction;
            rotate([0,0, (a + cw_ccw_mult) * (360/n)])
                translate([length/2 + hole_offset + offset,0,0])
                    scale([1, (width-thickness)/(length-thickness)]) circle(d=length-thickness);

        }
    }
}


module blade2D (height, length, width, thickness, hole_offset){
    difference(){
        translate([length/2,0,0])
            scale([1, width/length]) circle(d=length);

        translate([length/2 + hole_offset,0,0])
            scale([1, (width-thickness)/(length-thickness)]) circle(d=length-thickness);
    }
}

toroidal_propeller();