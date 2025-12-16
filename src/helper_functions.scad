// ============================================================
// helper_functions.scad
// ============================================================

// --------------------
// Constantes / helpers
// --------------------
function clamp(x, a, b) = (x < a) ? a : (x > b) ? b : x;

function vdot(a,b) = a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
function vlen(v)   = norm(v);
function vunit(v)  = let(L=vlen(v)) (L>1e-12 ? v/L : [0,0,0]);

// Conta quantos elementos existem numa lista (sem len())
function list_size(l, i=0) =
    is_undef(l[i]) ? i : list_size(l, i+1);

// --------------------
// Catmull–Rom 3D
// --------------------
function catmull_rom3d(u, P0, P1, P2, P3) =
    let(u2=u*u, u3=u2*u)
    [0.5*(2*P1[0] + (-P0[0]+P2[0])*u + (2*P0[0]-5*P1[0]+4*P2[0]-P3[0])*u2 + (-P0[0]+3*P1[0]-3*P2[0]+P3[0])*u3),
     0.5*(2*P1[1] + (-P0[1]+P2[1])*u + (2*P0[1]-5*P1[1]+4*P2[1]-P3[1])*u2 + (-P0[1]+3*P1[1]-3*P2[1]+P3[1])*u3),
     0.5*(2*P1[2] + (-P0[2]+P2[2])*u + (2*P0[2]-5*P1[2]+4*P2[2]-P3[2])*u2 + (-P0[2]+3*P1[2]-3*P2[2]+P3[2])*u3)];


// --------------------
// Path spline (seu toroide)
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
        r = hub_d*cos(30)/2,

        A = [ r*cos(60),   r*sin(60),   hub_height/2 + blade_offset/2 ],
        B = [ leadX,       +leadW,      hub_height/2 ],
        M = [ blade_length, 0,          hub_height/2 ],
        C = [ trailX,      -trailW,     hub_height/2 ],
        D = [ r*cos(60),   r*sin(-60),  hub_height/2 - blade_offset/2 ],

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
        toroidal_path_spline_3d(tt, hub_d, hub_height, blade_length, blade_offset,
                               leadW_pct, trailW_pct, leadX_pct, trailX_pct)
];

// tangente numérica do path
function path_tangent_at_t(
    t, hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    dt=1e-3
) =
    let(t0 = (t-dt < 0) ? 0 : t-dt,
        t1 = (t+dt > 1) ? 1 : t+dt,
        p0 = toroidal_path_spline_3d(t0, hub_d, hub_height, blade_length, blade_offset,
                                     leadW_pct, trailW_pct, leadX_pct, trailX_pct),
        p1 = toroidal_path_spline_3d(t1, hub_d, hub_height, blade_length, blade_offset,
                                     leadW_pct, trailW_pct, leadX_pct, trailX_pct))
    vunit(p1 - p0);


// --------------------
// Orientação do perfil:
// - plano do perfil ⟂ caminho (Z local = tangente)
// - corda (X local) || plano XY
// - e fix de sinal no X pra não “pular” 180° aleatoriamente
// --------------------
module orient_profile_perp_with_chord_xy(T){
    Z = vunit(T);

    // escolhe um "up" que NÃO seja paralelo à tangente
    up = (abs(Z[2]) < 0.9) ? [0,0,1] : [0,1,0];

    // X = eixo da corda (sempre perpendicular a Z)
    X = vunit(cross(up, Z));

    // Y completa o frame de mão direita
    Y = cross(Z, X);

    multmatrix([
        [X[0], Y[0], Z[0], 0],
        [X[1], Y[1], Z[1], 0],
        [X[2], Y[2], Z[2], 0],
        [0,    0,    0,    1]
    ]) children();
}



// --------------------
// Roll 180° só na 1ª metade do caminho (leading blade)
// (Se quiser na outra metade, troque < por >)
// --------------------
function is_leading_half(t, path_portion) = (t < 0.5*path_portion);

module trailing_upper_lower_fix(t, path_portion){
    // trailing = metade oposta
    if (!is_leading_half(t, path_portion))
        scale([1,-1,1]) children();   // troca cima/baixo
    else
        children();
}
module leading_roll_180(t, path_portion){
    if (is_leading_half(t, path_portion))
        rotate([0,0,180]) children();
    else
        children();
}


// ============================================================
// PERFIS 2D
// ============================================================

// Helpers de string (NACA "2412")
function _digit(s,i) = ord(s[i]) - ord("0");

// m = 1o dígito /100, p = 2o dígito /10, t = últimos 2 dígitos /100
function naca4_params(code) =
    let(m = _digit(code,0)/100,
        p = _digit(code,1)/10,
        t = (_digit(code,2)*10 + _digit(code,3))/100)
    [m,p,t];

// distribuição por cosseno
function _cosspace(i,n) = 0.5*(1 - cos(180*i/n));

// espessura (NACA clássica)
function naca4_yt(x,t) =
    5*t*(0.2969*sqrt(x) - 0.1260*x - 0.3516*x*x + 0.2843*x*x*x - 0.1015*x*x*x*x);

// cambra
function naca4_yc(x,m,p) =
    (m==0 || p==0) ? 0 :
    (x<p) ? (m/(p*p))*(2*p*x - x*x)
          : (m/((1-p)*(1-p)))*((1-2*p) + 2*p*x - x*x);

// derivada da cambra
function naca4_dyc(x,m,p) =
    (m==0 || p==0) ? 0 :
    (x<p) ? (2*m/(p*p))*(p - x)
          : (2*m/((1-p)*(1-p)))*(p - x);

// Pontos do perfil NACA 4 dígitos (contorno fechado), x∈[0,1]
//
// >>> CORREÇÃO PRINCIPAL: inverti o sinal do Y na saída
// para bater com a sua convenção de "upper/lower" no modelo.
function naca4_points(code, n=80) =
    let(mp = naca4_params(code),
        m=mp[0], p=mp[1], t=mp[2],

        upper = [
            for(i=[0:n])
                let(x  = _cosspace(i,n),
                    yc = naca4_yc(x,m,p),
                    dy = naca4_dyc(x,m,p),
                    th = atan(dy),
                    yt = naca4_yt(x,t))
                [ x - yt*sin(th), yc + yt*cos(th) ]
        ],

        lower = [
            for(i=[n:-1:0])
                let(x  = _cosspace(i,n),
                    yc = naca4_yc(x,m,p),
                    dy = naca4_dyc(x,m,p),
                    th = atan(dy),
                    yt = naca4_yt(x,t))
                [ x + yt*sin(th), yc - yt*cos(th) ]
        ],

        pts = concat(upper, lower)
    )
    [ for(pnt = pts) [pnt[0], -pnt[1]] ];   // <<< flip global do NACA

// Perfil elipse: ["ellipse", scale]
function ellipse_points(scale=0.5, n=120) =
    [ for(i=[0:n-1])
        let(a = 360*i/n,
            x = (cos(a)+1)/2,
            y = sin(a)*scale/2)
        [x,y]
    ];

// Seleciona pontos do perfil
function profile_points(profile, n=90) =
    is_string(profile) ? naca4_points(profile, n=n)
  : (is_list(profile) && profile[0]=="ellipse") ? ellipse_points(profile[1], n=n)
  : naca4_points("0012", n=n);

// Desenha perfil 2D com chord e pivot
module draw_profile2D(profile, chord=10, chord_pivot_pct=0, attack_angle=0, n=90){
    px  = chord_pivot_pct/100;
    pts = profile_points(profile, n=n);

    pts2 = [ for(p=pts) [ (p[0]-px)*chord, p[1]*chord ] ];

    rotate(attack_angle)
        polygon(points=pts2);
}


// ============================================================
// DEBUG: desenhar caminho (tubo) a partir de uma lista de pontos
// ============================================================
module path_polyline(points, steps, r=0.15){
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

// ---- Função para calcular o eixo de um frame (X, Y, Z) ----
function frame_axes_from_tangent(T) =
    let(
        Z = vunit(T),
        up = (abs(Z[2]) < 0.9) ? [0,0,1] : [0,1,0],
        X = vunit(cross(up, Z)),
        Y = cross(Z, X)
    )
    [X, Y, Z];

// ---- Função para gerar slice 3D a partir dos pontos 2D (perfil) ----
function slice3d_at_t_from_pts2d(
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


// ============================================================
// LOFT leve sem BOSL2: polyhedron conectando slices
// ============================================================

// retorna N pontos para QUALQUER perfil, garantindo mesmo tamanho
// - para NACA: naca4_points(code, nseg) gera 2*(nseg+1) pontos
//   então escolhemos nseg = (N/2)-1  => N precisa ser par e >= 4
function profile_points_N(profile, N=100) =
    let(N2 = (N<4)?4:N,
        Ne = (N2%2==1)? (N2+1) : N2,            // força par
        nseg = Ne/2 - 1)
    is_string(profile) ? naca4_points(profile, n=nseg)
  : (is_list(profile) && profile[0]=="ellipse") ? ellipse_points(profile[1], n=Ne)
  : naca4_points("0012", n=nseg);

// 2D com chord/pivot/attack (sem módulos)
function profile_pts2d_N(profile, chord=10, chord_pivot_pct=0, attack_angle=0, N=100) =
    let(
        px  = chord_pivot_pct/100,
        pts = profile_points_N(profile, N=N),
        pts2 = [ for(p=pts) [ (p[0]-px)*chord, p[1]*chord ] ],
        ca = cos(attack_angle),
        sa = sin(attack_angle)
    )
    [ for(p=pts2) [ p[0]*ca - p[1]*sa, p[0]*sa + p[1]*ca ] ];

// aplica seus fixes (trailing flip + leading roll 180) em 2D
function profile_pts2d_fixed(t, path_portion, pts2d) =
    let(
        leading = (t < 0.5*path_portion),
        // trailing_upper_lower_fix
        ptsA = (!leading) ? [ for(p=pts2d) [ p[0], -p[1] ] ] : pts2d,
        // leading_roll_180
        ptsB = (leading) ? [ for(p=ptsA) [ -p[0], -p[1] ] ] : ptsA
    )
    ptsB;

// frame (X,Y,Z) igual ao seu orient_profile_perp_with_chord_xy, só que como função
function frame_axes_from_tangent(T) =
    let(
        Z = vunit(T),
        up = (abs(Z[2]) < 0.9) ? [0,0,1] : [0,1,0],
        X = vunit(cross(up, Z)),
        Y = cross(Z, X)
    )
    [X, Y, Z];

// slice 3D no t
function slice3d_at_t(
    t, profile, chord, chord_pivot_pct, attack_angle,
    hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    path_portion=1.0,
    N=100
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
        Y = axes[1],
        pts2d0 = profile_pts2d_N(profile, chord, chord_pivot_pct, attack_angle, N=N),
        pts2d  = profile_pts2d_fixed(t, path_portion, pts2d0)
    )
    [ for(p=pts2d) P + X*p[0] + Y*p[1] ];

// concat “manual” (sem depender de len())
function concat_many(arr, i=0) =
    is_undef(arr[i]) ? []
  : concat(arr[i], concat_many(arr, i+1));

// lista de faces entre dois anéis (ring a -> ring b), com N pontos por anel
function loft_side_faces(N, ringA, ringB) =
    concat_many([
        for(j=[0:N-1])
            let(
                a = ringA + j,
                b = ringA + ((j+1)%N),
                c = ringB + ((j+1)%N),
                d = ringB + j
            )
            // dois triângulos por quad
            [ [a,b,c], [a,c,d] ]
    ]);

// tampas (fan) — adiciona 1 ponto centro por tampa e cria triângulos
function cap_faces(N, center_idx, ring_start, flip=false) =
    [ for(j=[0:N-1])
        let(a = ring_start + j,
            b = ring_start + ((j+1)%N))
        flip ? [center_idx, b, a] : [center_idx, a, b]
    ];

// módulo principal: loft das seções definidas em profiles/profile_pcts
module loft_profiles_on_path_poly(
    profiles, profile_pcts, chords, chord_pivot_pcts, attack_angles,
    hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    path_portion=1.0,
    N=100,          // qualidade do contorno por seção (par)
    caps=true
){
    n_profiles = list_size(profiles);
    Np = (N%2==1) ? (N+1) : N;

    // slices 3D
    slices = [
        for(i=[0:n_profiles-1])
            let(t = (profile_pcts[i]/100) * path_portion)
            slice3d_at_t(
                t,
                profiles[i], chords[i], chord_pivot_pcts[i], attack_angles[i],
                hub_d, hub_height, blade_length, blade_offset,
                leadW_pct, trailW_pct, leadX_pct, trailX_pct,
                path_portion=path_portion,
                N=Np
            )
    ];

    // flatten pontos
    pts = concat_many(slices);

    // faces laterais
    faces_side = concat_many([
        for(i=[0:n_profiles-2])
            loft_side_faces(Np, i*Np, (i+1)*Np)
    ]);

    total_pts = n_profiles * Np;

    if (caps) {
        c0 = ring_center_pts(pts, 0, Np);
        c1 = ring_center_pts(pts, (n_profiles-1)*Np, Np);

        pts2 = concat(pts, [c0], [c1]);
        c0i  = total_pts;
        c1i  = total_pts + 1;

        faces_cap0 = cap_faces(Np, c0i, 0, flip=true);
        faces_cap1 = cap_faces(Np, c1i, (n_profiles-1)*Np, flip=false);

        polyhedron(
            points=pts2,
            faces=concat(faces_side, faces_cap0, faces_cap1),
            convexity=10
        );
    } else {
        polyhedron(points=pts, faces=faces_side, convexity=10);
    }

}

// soma vetorial 3D
function vadd3(a,b) = [a[0]+b[0], a[1]+b[1], a[2]+b[2]];

// ---- Função para calcular o centro de um anel de pontos 3D (média dos pontos) ----
function ring_center_pts(pts, ring_start, N, k=0, acc=[0,0,0]) =
    (k >= N) ? [acc[0]/N, acc[1]/N, acc[2]/N]
             : ring_center_pts(pts, ring_start, N, k+1, vadd3(acc, pts[ring_start+k]));

function lerp(a,b,u) = a + (b-a)*u;
function lerp2(a,b,u) = [lerp(a[0],b[0],u), lerp(a[1],b[1],u)];

module loft_profiles_on_path_poly_follow(
    profiles, profile_pcts, chords, chord_pivot_pcts, attack_angles,
    hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    path_portion=1.0,
    N=80,                 // pontos por seção (par)
    steps_per_span=12,    // número de slices entre cada par de seções (ajustável)
    caps=false
){
    n_profiles = list_size(profiles);
    Np = (N%2==1) ? (N+1) : N;

    // Pré-calcula os pts2d de cada perfil “keyframe”
    key_pts2d = [
        for(i=[0:n_profiles-1])
            let(ti = (profile_pcts[i]/100) * path_portion)
            profile_pts2d_fixed(
                ti, path_portion,
                profile_pts2d_N(profiles[i], chords[i], chord_pivot_pcts[i], attack_angles[i], N=Np)
            )
    ];

    key_t = [ for(i=[0:n_profiles-1]) (profile_pcts[i]/100) * path_portion ];

    // Gera slices interpolados entre i e i+1
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
                    [ slice3d_at_t_from_pts2d(
                        t, pts2d_blend,
                        hub_d, hub_height, blade_length, blade_offset,
                        leadW_pct, trailW_pct, leadX_pct, trailX_pct
                    ) ]
            ])
    ]);

    // Adiciona a última slice (t final) para fechar o loft
    slices2 = concat(slices, [
        slice3d_at_t_from_pts2d(
            key_t[n_profiles-1], key_pts2d[n_profiles-1],
            hub_d, hub_height, blade_length, blade_offset,
            leadW_pct, trailW_pct, leadX_pct, trailX_pct
        )
    ]);

    // Flatten pontos
    pts = concat_many(slices2);

    n_slices = list_size(slices2);

    // Faces laterais
    faces_side = concat_many([
        for(i=[0:n_slices-2])
            loft_side_faces(Np, i*Np, (i+1)*Np)
    ]);

    // Caps (opcional)
    if (caps) {
        total_pts = n_slices * Np;
        c0 = ring_center_pts(pts, 0, Np);
        c1 = ring_center_pts(pts, (n_slices-1)*Np, Np);

        pts2 = concat(pts, [c0], [c1]);
        c0i  = total_pts;
        c1i  = total_pts + 1;

        faces_cap0 = cap_faces(Np, c0i, 0, flip=true);
        faces_cap1 = cap_faces(Np, c1i, (n_slices-1)*Np, flip=false);

        polyhedron(
            points=pts2,
            faces=concat(faces_side, faces_cap0, faces_cap1),
            convexity=10
        );
    } else {
        polyhedron(points=pts, faces=faces_side, convexity=10);
    }
}
