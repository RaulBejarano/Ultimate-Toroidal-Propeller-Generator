module toroidal_propeller(
    blades = 3,                     // number of blades
    height = 6,                     // height
    blade_length = 68,              // blade length in mm
    blade_width = 42,               // blade width in mm
    blade_thickness = 4,            // blade thickness in mm
    blade_hole_offset = 1.4,        // blade hole offset
    blade_twist = 15,               // blade twist angle
    blade_offset = -6,               // blade distance from propeller axis
    safe_blades_direction = "PREV", // indicates if a blade must delete itself from getting into the previous (PREV) or the next blade (NEXT).
    hub_d = 16,                     // hub diameter
    hub_screw_d = 5.5               // hub screw diameter
){
    difference(){
        union(){
            // Hub
            cylinder(h=height,d=hub_d);
            // Propellers
            for(a=[0:blades-1]){
                rotate([0,0,a*(360/blades)]){
                    difference(){
                        translate([blade_offset,0,0])
                            blade(
                                height = height,
                                length = blade_length,
                                width = blade_width,
                                thickness = blade_thickness,
                                offset = blade_hole_offset,
                                twist = blade_twist
                            );
                        
                        // Substract what is inside other blades
                        cw_ccw_mult = (blade_twist > 0 ? -1 : 1) * (safe_blades_direction == "PREV" ? 1 : -1);
                        rotate([0,0, cw_ccw_mult * 360/blades])
                            translate([blade_offset,0,0])
                                linear_extrude(height=height, twist=blade_twist)
                                    translate([blade_length/2,0,0])
                                        scale([1, blade_width/blade_length]) circle(d=blade_length);
                    }
                }
            }
        }
        
        // Hub hole
        cylinder(h=height,d=hub_screw_d);
    }
}


module blade(height, length, width, thickness, offset, twist){
    linear_extrude(height=height, twist=twist, convexity=2)
        difference(){
            translate([length/2,0,0])
                scale([1, width/length]) circle(d=length);
    
            translate([length/2 + offset,0,0])
                scale([1, (width-thickness)/(length-thickness)]) circle(d=length-thickness);
    }
}