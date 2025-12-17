use <src/toroidal_propeller.scad>
$fn = 100;  // global tessellation (higher = smoother preview/export)

toroidal_propeller(
    // -------------------------
    // Blade count + rotation
    // -------------------------
    blades = 2,                                                // number of blades (copied/rotated around Z)
    rotation = "CW",                                           // "CCW" (default) or "CW" (mirrored in YZ plane)

    // -------------------------
    // Hub geometry
    // -------------------------
    hub_height = 6,                                            // hub height
    hub_d = 16,                                                // hub outer diameter
    hub_screw_d = 5.5,                                         // center screw hole diameter
    hub_notch_height = 0,                                      // optional notch height (0 = disabled)
    hub_notch_d = 0,                                           // optional notch diameter (0 = disabled)

    // -------------------------
    // Path / blade geometry
    // -------------------------
    blade_length = 40,                                         // blade span/length used by the toroidal path
    blade_offset = 2,                                          // Z offset between leading/trailing halves
    leading_blade_width = 25,                             // leading half width (percent of blade_length)
    trailing_blade_width = 20,                            // trailing half width (percent of blade_length)
    leading_blade_xoffset = 50,                           // leading half X offset (percent of blade_length)
    trailing_blade_xoffset = 80,                          // trailing half X offset (percent of blade_length)

    // -------------------------
    // Airfoil profiles (keyframes along the path)
    // -------------------------
    profiles = ["2412","2412",["ellipse", 0.5],"2412","8412"], // NACA 4-digit or ["ellipse", scale]
    profile_pcts = [0,35,50,87,100],                           // keyframe positions along the path (0..100)
    chords = [8,3,2.5,3,4],                                    // chord length at each keyframe (same order as profiles)
    chord_pivot_pcts = [50,25,100,50,65],                      // pivot along chord: 0=LE, 50=mid, 100=TE
    attack_angles = [15,40,-90,0,10],                          // attack angle (deg) at each keyframe

    // -------------------------
    // Render only part of the path
    // -------------------------
    path_portion = 1.0                                         // 1.0 = full path, 0.5 = half path, etc.
);
