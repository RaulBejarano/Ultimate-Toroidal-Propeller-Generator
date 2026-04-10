// ============================================================
// debug_functions.scad  (visual debugging helpers)
// ============================================================

// pct (0..100) -> t (0..path_portion)
function pct_to_t(pct, path_portion=1.0) = (pct/100) * path_portion;

function path_point_at_pct(
    pct, hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    path_portion=1.0
) =
    toroidal_path_spline_3d(
        pct_to_t(pct, path_portion),
        hub_d, hub_height, blade_length, blade_offset,
        leadW_pct, trailW_pct, leadX_pct, trailX_pct
    );

// ============================================================
// Debug: draw a 3D polyline (tube segments)
// ============================================================
module path_polyline(points, steps, r=0.35){
    for (i = [0:steps-1]) {
        p0 = points[i];
        p1 = points[i+1];
        v  = p1 - p0;
        L  = norm(v);

        if (L > 1e-9) {
            translate(p0)
                rotate(a = acos(clamp(v[2]/L, -1, 1)), v = [-v[1], v[0], 0])
                    cylinder(h=L, r=r, $fn=24);
        }
    }
}

module path_points_debug(points, r=0.6){
    for (p = points) translate(p) sphere(r=r, $fn=24);
}


// ============================================================
// 2D polyline -> tube (cylinders)
// ============================================================
module polyline2d_tube(pts2d, steps2d, r=0.12){
    for(i=[0:steps2d-2]){
        p0 = pts2d[i];
        p1 = pts2d[i+1];
        v  = [p1[0]-p0[0], p1[1]-p0[1], 0];
        L  = norm(v);

        if (L > 1e-9){
            translate([p0[0], p0[1], 0])
                rotate(a = acos(clamp(v[0]/L, -1, 1)), v=[0,0,1])
                    cylinder(h=L, r=r, $fn=16);
        }
    }
}

module polyline2d_tube_closed(pts2d, steps2d, r=0.12){
    polyline2d_tube(pts2d, steps2d, r=r);

    p0 = pts2d[steps2d-1];
    p1 = pts2d[0];
    v  = [p1[0]-p0[0], p1[1]-p0[1], 0];
    L  = norm(v);

    if (L > 1e-9){
        translate([p0[0], p0[1], 0])
            rotate(a = acos(clamp(v[0]/L, -1, 1)), v=[0,0,1])
                cylinder(h=L, r=r, $fn=16);
    }
}


// ============================================================
// Draw a profile outline as a "line" (tube) with chord/pivot/attack
// ============================================================
module draw_profile2D_as_line(profile, chord=10, chord_pivot_pct=0, attack_angle=0, n=90, r=0.12){
    px  = chord_pivot_pct/100;
    pts = profile_points(profile, n=n);

    // pivot + chord scale
    pts2 = [ for(p=pts) [ (p[0]-px)*chord, p[1]*chord ] ];

    // rotate in 2D (attack)
    ca = cos(attack_angle);
    sa = sin(attack_angle);
    pts3 = [ for(p=pts2) [ p[0]*ca - p[1]*sa, p[0]*sa + p[1]*ca ] ];

    steps2d = list_size(pts3);
    polyline2d_tube_closed(pts3, steps2d, r=r);
}


// ============================================================
// Debug: draw profiles along the path (perpendicular to the path)
// ============================================================
module draw_profiles_on_path_perp(
    profiles, profile_pcts, chords, chord_pivot_pcts, attack_angles,
    hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    path_portion=1.0,
    n=90, r=0.12
){
    n_profiles = list_size(profiles);

    for (i=[0:n_profiles-1]) {
        t = (profile_pcts[i]/100) * path_portion;

        P = toroidal_path_spline_3d(
            t, hub_d, hub_height, blade_length, blade_offset,
            leadW_pct, trailW_pct, leadX_pct, trailX_pct
        );

        T = path_tangent_at_t(
            t, hub_d, hub_height, blade_length, blade_offset,
            leadW_pct, trailW_pct, leadX_pct, trailX_pct,
            dt=1e-3
        );

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
                            n = n,
                            r = r
                        );
    }
}
