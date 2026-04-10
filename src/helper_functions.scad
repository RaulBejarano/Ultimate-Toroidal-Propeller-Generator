// ============================================================
// helper_functions.scad  (general helpers + loft builder)
// ============================================================

// --------------------
// Generic math / vector helpers
// --------------------
function clamp(x,a,b) = (x<a) ? a : (x>b) ? b : x;

function vlen(v)  = norm(v);
function vunit(v) = let(L=vlen(v)) (L>1e-12 ? v/L : [0,0,0]);

function vadd3(a,b) = [a[0]+b[0], a[1]+b[1], a[2]+b[2]];

// Count list length without len()
function list_size(l, i=0) = is_undef(l[i]) ? i : list_size(l, i+1);

// Recursively concat list-of-lists
function concat_many(arr, i=0) =
    is_undef(arr[i]) ? [] : concat(arr[i], concat_many(arr, i+1));

// Interpolation helpers
function lerp(a,b,u)  = a + (b-a)*u;
function lerp2(a,b,u) = [lerp(a[0],b[0],u), lerp(a[1],b[1],u)];


// ============================================================
// LOFT (polyhedron) - follows the path by interpolating between keyframes
// Caps are always disabled (no end caps)
// ============================================================

// Force a fixed number of points for any profile type
// - NACA uses 2*(nseg+1) points => choose nseg = (N/2)-1, so N must be even
function profile_points_fixedN(profile, N=80) =
    let(
        N2 = (N<4)?4:N,
        Ne = (N2%2==1)? (N2+1) : N2,
        nseg = Ne/2 - 1
    )
    is_string(profile) ? naca4_points(profile, n=nseg)
  : (is_list(profile) && profile[0]=="ellipse") ? ellipse_points(profile[1], n=Ne)
  : naca4_points("0012", n=nseg);

// Build 2D profile points with chord/pivot/attack applied (no modules)
function profile_pts2d_fixedN(profile, chord=10, chord_pivot_pct=0, attack_angle=0, N=80) =
    let(
        px  = chord_pivot_pct/100,
        pts = profile_points_fixedN(profile, N=N),
        // pivot + scale
        pts2 = [ for(p=pts) [ (p[0]-px)*chord, p[1]*chord ] ],
        // rotate in 2D (attack)
        ca = cos(attack_angle),
        sa = sin(attack_angle)
    )
    [ for(p=pts2) [ p[0]*ca - p[1]*sa, p[0]*sa + p[1]*ca ] ];

// Applies half-blade orientation corrections to a 2D airfoil profile.
//
// The toroidal blade is composed of two halves (leading and trailing)
// that face opposite directions along the path. To keep the airfoil
// consistently oriented (upper/lower surfaces and chord direction),
// different fixes are applied depending on the current path position.
//
// - For the trailing half:
//   The profile is mirrored along the Y axis to swap upper/lower surfaces.
//
// - For the leading half:
//   The profile is rotated 180° in the XY plane to reverse its chord direction.
//
// These operations ensure geometric continuity and prevent the profile
// from appearing flipped or inverted when lofted along the toroidal path.
function profile_pts2d_apply_half_fixes(t, path_portion, pts2d) =
    let(
        leading = (t < 0.5*path_portion),
        // trailing swap (flip Y)
        ptsA = (!leading) ? [ for(p=pts2d) [ p[0], -p[1] ] ] : pts2d,
        // leading roll 180 (x,y)->(-x,-y)
        ptsB = (leading) ? [ for(p=ptsA) [ -p[0], -p[1] ] ] : ptsA
    )
    ptsB;

// Convert a 2D slice (already prepared) into 3D at parameter t
function slice3d_from_pts2d(
    t, pts2d,
    hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct
) =
    let(
        P = toroidal_path_spline_3d(
            t, hub_d, hub_height, blade_length, blade_offset,
            leadW_pct, trailW_pct, leadX_pct, trailX_pct
        ),
        T = path_tangent_at_t(
            t, hub_d, hub_height, blade_length, blade_offset,
            leadW_pct, trailW_pct, leadX_pct, trailX_pct,
            dt=1e-3
        ),
        axes = frame_axes_from_tangent(T),
        X = axes[0],
        Y = axes[1]
    )
    [ for(p=pts2d) P + X*p[0] + Y*p[1] ];

// Side faces between ring A and ring B (same point count N)
function loft_side_faces(N, ringA, ringB) =
    concat_many([
        for(j=[0:N-1])
            let(
                a = ringA + j,
                b = ringA + ((j+1)%N),
                c = ringB + ((j+1)%N),
                d = ringB + j
            )
            // two triangles per quad
            [ [a,b,c], [a,c,d] ]
    ]);

// Main loft module
module loft_profiles_on_path_poly_follow(
    profiles, profile_pcts, chords, chord_pivot_pcts, attack_angles,
    hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    path_portion=1.0,
    N=80,
    steps_per_span=12
){
    n_profiles = list_size(profiles);
    Np = (N%2==1) ? (N+1) : N;

    key_t = [ for(i=[0:n_profiles-1]) (profile_pcts[i]/100) * path_portion ];

    // Precompute 2D keyframes (already fixed by leading/trailing half rules)
    key_pts2d = [
        for(i=[0:n_profiles-1])
            let(ti = key_t[i])
            profile_pts2d_apply_half_fixes(
                ti, path_portion,
                profile_pts2d_fixedN(
                    profiles[i],
                    chord=chords[i],
                    chord_pivot_pct=chord_pivot_pcts[i],
                    attack_angle=attack_angles[i],
                    N=Np
                )
            )
    ];

    // Build interpolated slices between keyframes
    slices = concat_many([
        for(i=[0:n_profiles-2])
            concat_many([
                for(s=[0:steps_per_span-1])
                    let(
                        u = s/steps_per_span,
                        t = lerp(key_t[i], key_t[i+1], u),
                        pts2d_blend = [
                            for(k=[0:Np-1])
                                lerp2(key_pts2d[i][k], key_pts2d[i+1][k], u)
                        ]
                    )
                    [ slice3d_from_pts2d(
                        t, pts2d_blend,
                        hub_d, hub_height, blade_length, blade_offset,
                        leadW_pct, trailW_pct, leadX_pct, trailX_pct
                    ) ]
            ])
    ]);

    // Add last slice
    slices2 = concat(slices, [
        slice3d_from_pts2d(
            key_t[n_profiles-1], key_pts2d[n_profiles-1],
            hub_d, hub_height, blade_length, blade_offset,
            leadW_pct, trailW_pct, leadX_pct, trailX_pct
        )
    ]);

    pts = concat_many(slices2);
    n_slices = list_size(slices2);

    faces_side = concat_many([
        for(i=[0:n_slices-2])
            loft_side_faces(Np, i*Np, (i+1)*Np)
    ]);

    polyhedron(points=pts, faces=faces_side, convexity=10);
}
