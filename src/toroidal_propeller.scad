// ============================================================
// toroidal_propeller.scad
// ============================================================

eps = 1/128;
$fn = 100;

include <helper_functions.scad>;
include <path_functions.scad>;
include <profile_functions.scad>;
include <debug_functions.scad>;

module toroidal_propeller(
    blades=2,

    // Hub
    hub_height=6,
    hub_d=16,
    hub_screw_d=5.5,
    hub_notch_height=0,
    hub_notch_d=0,

    // Blade / Path
    blade_offset=2,
    blade_length=68,

    leading_blade_width=18,
    trailing_blade_width=18,
    leading_blade_xoffset=50,
    trailing_blade_xoffset=60,

    // Profiles (keyframes)
    profiles=["8412",["ellipse",0.5],"2412"],
    profile_pcts=[0,50,100],
    chords=[8,2,6],
    chord_pivot_pcts=[0,0,0],
    attack_angles=[15,0,-10],

    path_portion=1.0,
    rotation="CCW",          // "CCW" | "CW"

    // Loft resolution
    loft_profile_points=80,  // N (even) points per section
    loft_steps_per_span=16   // slices between keyframes
){
    // ---------------------------
    // For debug only
    // ---------------------------
    // pts = toroidal_path_points(
    //     120,
    //     hub_d, hub_height,
    //     blade_length, blade_offset,
    //     leading_blade_width,
    //     trailing_blade_width,
    //     leading_blade_xoffset,
    //     trailing_blade_xoffset
    // );

    // // create line-path
    // path_polyline(pts, 120, r=0.4);
    // // create point-path
    // // path_points_debug(pts, r=0.8);

    // // draw the profiles
    // draw_profiles_on_path_perp(
    //     profiles,
    //     profile_pcts,
    //     chords,
    //     chord_pivot_pcts,
    //     attack_angles,

    //     hub_d,
    //     hub_height,
    //     blade_length,
    //     blade_offset,

    //     leading_blade_width,
    //     trailing_blade_width,
    //     leading_blade_xoffset,
    //     trailing_blade_xoffset,

    //     path_portion = 1.0,
    //     n = 90,      // resolution of profile
    //     r = 0.15     // line thickness
    // );

    // ---------------------------
    // Blades
    // ---------------------------
    module one_blade(){
        loft_profiles_on_path_poly_follow(
            profiles, profile_pcts, chords, chord_pivot_pcts, attack_angles,
            hub_d, hub_height, blade_length, blade_offset,
            leading_blade_width, trailing_blade_width,
            leading_blade_xoffset, trailing_blade_xoffset,
            path_portion=path_portion,
            N=loft_profile_points,
            steps_per_span=loft_steps_per_span
        );
    }

    module all_blades(){
        for (b=[0:blades-1])
            rotate([0,0,360*b/blades])
                one_blade();
    }

    // CW = mirror in YZ plane => invert X
    if (rotation == "CW")
        mirror([1,0,0]) all_blades();
    else
        all_blades();

    // ---------------------------
    // Hub (cylindrical)
    // ---------------------------
    difference() {
        cylinder(d=hub_d, h=hub_height, $fn=120);

        translate([0,0,-eps])
            cylinder(d=hub_screw_d, h=hub_height+2*eps, $fn=80);

        if (hub_notch_height>0 && hub_notch_d>0)
            translate([0,0,-eps])
                cylinder(d=hub_notch_d, h=hub_notch_height+eps, $fn=80);
    }
}

// quick test
toroidal_propeller();
