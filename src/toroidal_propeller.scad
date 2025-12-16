// ============================================================
// toroidal_propeller.scad
// ============================================================

eps=1/128;
$fn=100;

include <helper_functions.scad>;
include <debug_functions.scad>;

// ============================================================
// Perfis no caminho, perpendiculares ao caminho,
// com corda paralela ao plano XY e roll 180 só na leading half.
// ============================================================
module draw_profiles_on_path_perp(
    profiles, profile_pcts, chords, chord_pivot_pcts, attack_angles,
    hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    path_portion=1.0
){
    n_profiles = list_size(profiles);

    for (i=[0:n_profiles-1]) {

        // t do caminho (0..path_portion)
        t = (profile_pcts[i]/100) * path_portion;

        // posição e tangente
        P = toroidal_path_spline_3d(
            t, hub_d, hub_height, blade_length, blade_offset,
            leadW_pct, trailW_pct, leadX_pct, trailX_pct
        );

        T = path_tangent_at_t(
            t, hub_d, hub_height, blade_length, blade_offset,
            leadW_pct, trailW_pct, leadX_pct, trailX_pct,
            dt=1e-3
        );

        // protege contra listas desalinhadas (evita “sumir” perfil)
        if (
            !is_undef(profile_pcts[i]) &&
            !is_undef(chords[i]) &&
            !is_undef(chord_pivot_pcts[i]) &&
            !is_undef(attack_angles[i])
        )
        translate(P)
            orient_profile_perp_with_chord_xy(T)
                trailing_upper_lower_fix(t, path_portion)
                    leading_roll_180(t, path_portion)
                        draw_profile2D_as_line(
                            profiles[i],
                            chord = chords[i],
                            chord_pivot_pct = chord_pivot_pcts[i],
                            attack_angle = attack_angles[i],
                            n = 90,     // ajuste: 60..120 é comum
                            r = 0.12    // espessura da linha
                        );
    }
}


// ============================================================
// Módulo principal
// ============================================================
module toroidal_propeller(
    blades=1,

    hub_height=6,
    hub_d=16,
    hub_screw_d=5.5,
    hub_notch_height=0,
    hub_notch_d=0,

    blade_offset=2,
    blade_length=68,

    leading_edge_blade_width=18,
    trailing_edge_blade_width=18,
    leading_edge_blade_xoffset=50,
    trailing_edge_blade_xoffset=60,

    profiles=["8412",["ellipse",0.5],"2412"],
    profile_pcts=[0,50,100],
    chords=[8,2,6],
    chord_pivot_pcts=[0,0,0],
    attack_angles=[15,0,-10],

    path_portion=1.0
){
    // Debug: caminho
    steps = 120;
    pts = toroidal_path_points(
        steps,
        hub_d, hub_height, blade_length, blade_offset,
        leading_edge_blade_width, trailing_edge_blade_width,
        leading_edge_blade_xoffset, trailing_edge_blade_xoffset,
        0, path_portion
    );
    path_polyline(pts, steps, r=0.35);

    // Perfis ao longo do caminho
    draw_profiles_on_path_perp(
        profiles, profile_pcts, chords, chord_pivot_pcts, attack_angles,
        hub_d, hub_height, blade_length, blade_offset,
        leading_edge_blade_width, trailing_edge_blade_width,
        leading_edge_blade_xoffset, trailing_edge_blade_xoffset,
        path_portion
    );

    // Hub hex (se quiser reativar)
    // difference() {
    //     union() {
    //         rotate([0,0,30]) cylinder(d=hub_d, h=hub_height, $fn=6);
    //     }
    //     translate([0,0,-eps]) cylinder(d=hub_screw_d, h=hub_height+2*eps);
    //     if (hub_notch_height>0 && hub_notch_d>0)
    //         translate([0,0,-eps]) cylinder(d=hub_notch_d, h=hub_notch_height+eps);
    // }
}

// teste rápido
toroidal_propeller();
