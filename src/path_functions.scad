// ============================================================
// path_functions.scad  (path + frames/orientation)
// ============================================================

// --------------------
// Catmull–Rom 3D spline
// --------------------
function catmull_rom3d(u, P0, P1, P2, P3) =
    let(u2=u*u, u3=u2*u)
    [0.5*(2*P1[0] + (-P0[0]+P2[0])*u + (2*P0[0]-5*P1[0]+4*P2[0]-P3[0])*u2 + (-P0[0]+3*P1[0]-3*P2[0]+P3[0])*u3),
     0.5*(2*P1[1] + (-P0[1]+P2[1])*u + (2*P0[1]-5*P1[1]+4*P2[1]-P3[1])*u2 + (-P0[1]+3*P1[1]-3*P2[1]+P3[1])*u3),
     0.5*(2*P1[2] + (-P0[2]+P2[2])*u + (2*P0[2]-5*P1[2]+4*P2[2]-P3[2])*u2 + (-P0[2]+3*P1[2]-3*P2[2]+P3[2])*u3)];


// --------------------
// Toroidal propeller path spline
// --------------------
function toroidal_path_spline_3d(
    t, hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    angle_A=60, angle_D=-240
) =
    let(
        leadW  = blade_length*(leadW_pct/100),
        trailW = blade_length*(trailW_pct/100),
        leadX  = blade_length*(leadX_pct/100),
        trailX = blade_length*(trailX_pct/100),

        // Effective radius based on hub diameter (kept from your original logic)
        r = hub_d*cos(30)/2,

        A = [ r*cos(60),    r*sin(60),   hub_height/2 + blade_offset/2 ],
        B = [ leadX,        +leadW,      hub_height/2 ],
        M = [ blade_length, 0,           hub_height/2 ],
        C = [ trailX,       -trailW,     hub_height/2 ],
        D = [ r*cos(60),    r*sin(-60),  hub_height/2 - blade_offset/2 ],

        scale_A = norm(B-A),
        scale_D = norm(D-C),

        Ta = [ scale_A*cos(angle_A), scale_A*sin(angle_A), 0 ],
        Td = [ scale_D*cos(angle_D), scale_D*sin(angle_D), 0 ],

        A0 = B - 2*Ta,
        D3 = C + 2*Td,

        segw=1/4,
        seg = (t<segw)?0 : (t<2*segw)?1 : (t<3*segw)?2 : 3,
        u   = (seg==0)?t/segw : (seg==1)?(t-segw)/segw : (seg==2)?(t-2*segw)/segw : (t-3*segw)/segw,

        P0=(seg==0)?A0 : (seg==1)?A : (seg==2)?B : M,
        P1=(seg==0)?A  : (seg==1)?B : (seg==2)?M : C,
        P2=(seg==0)?B  : (seg==1)?M : (seg==2)?C : D,
        P3=(seg==0)?M  : (seg==1)?C : (seg==2)?D : D3
    )
    catmull_rom3d(u,P0,P1,P2,P3);

function toroidal_path_points(
    steps, hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    t_start=0, t_end=1
) =
[
    for(i=[0:steps])
        let(u=i/steps, tt=t_start + (t_end-t_start)*u)
        toroidal_path_spline_3d(
            tt, hub_d, hub_height, blade_length, blade_offset,
            leadW_pct, trailW_pct, leadX_pct, trailX_pct
        )
];

// Numerical tangent of the path
function path_tangent_at_t(
    t, hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    dt=1e-3
) =
    let(
        t0 = (t-dt < 0) ? 0 : t-dt,
        t1 = (t+dt > 1) ? 1 : t+dt,
        p0 = toroidal_path_spline_3d(t0, hub_d, hub_height, blade_length, blade_offset, leadW_pct, trailW_pct, leadX_pct, trailX_pct),
        p1 = toroidal_path_spline_3d(t1, hub_d, hub_height, blade_length, blade_offset, leadW_pct, trailW_pct, leadX_pct, trailX_pct)
    )
    vunit(p1 - p0);


// --------------------
// Frames / orientation helpers
// --------------------
// Returns [X,Y,Z] axes where:
// - Z is the tangent direction
// - X is a chord axis (perpendicular to Z)
// - Y completes a right-handed frame
function frame_axes_from_tangent(T) =
    let(
        Z = vunit(T),
        up = (abs(Z[2]) < 0.9) ? [0,0,1] : [0,1,0],
        X = vunit(cross(up, Z)),
        Y = cross(Z, X)
    )
    [X, Y, Z];

// Orients children so that local Z follows the path tangent,
// while local X/Y lie in the plane perpendicular to the tangent.
module orient_profile_perp_with_chord_xy(T){
    axes = frame_axes_from_tangent(T);
    X = axes[0]; Y = axes[1]; Z = axes[2];

    multmatrix([
        [X[0], Y[0], Z[0], 0],
        [X[1], Y[1], Z[1], 0],
        [X[2], Y[2], Z[2], 0],
        [0,    0,    0,    1]
    ]) children();
}

// Half definitions and fixes used by the older debug visualization
function is_leading_half(t, path_portion) = (t < 0.5*path_portion);

module trailing_upper_lower_fix(t, path_portion){
    if (!is_leading_half(t, path_portion)) scale([1,-1,1]) children();
    else children();
}

module leading_roll_180(t, path_portion){
    if (is_leading_half(t, path_portion)) rotate([0,0,180]) children();
    else children();
}
