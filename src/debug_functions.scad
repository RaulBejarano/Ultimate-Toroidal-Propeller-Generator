// pct (0..100) -> t (0..path_portion)
function pct_to_t(pct, path_portion=1.0) = (pct/100) * path_portion;

// pega ponto no path em um pct
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

// desenha todos os perfis nas posições correspondentes
// n_profiles = quantidade de itens que você tem em profiles/chords/etc
module draw_profiles_on_path(
    n_profiles,
    profiles, profile_pcts, chords, chord_pivot_pcts, attack_angles,
    hub_d, hub_height, blade_length, blade_offset,
    leadW_pct, trailW_pct, leadX_pct, trailX_pct,
    path_portion=1.0
){
    for (i=[0:n_profiles-1]) {
        p = path_point_at_pct(
            profile_pcts[i],
            hub_d, hub_height, blade_length, blade_offset,
            leadW_pct, trailW_pct, leadX_pct, trailX_pct,
            path_portion
        );

        // Coloca o perfil “chapado” no plano XY, centrado no ponto do path.
        // (A orientação ao longo da tangente a gente faz no próximo passo.)
        translate(p)
            draw_profile2D(
                profiles[i],
                chord = chords[i],
                chord_pivot_pct = chord_pivot_pcts[i],
                attack_angle = attack_angles[i]
            );
    }
}


// ============================================================
// desenhar caminho (tubo) a partir de uma lista de pontos 3D
// ============================================================
module path_polyline(points, steps, r=0.35){
    for (i = [0:steps-1]) {
        p0 = points[i];
        p1 = points[i+1];
        v  = p1 - p0;
        L  = norm(v);

        if (L > 1e-9) {
            translate(p0)
                rotate(
                    a = acos(v[2]/L),
                    v = [-v[1], v[0], 0]
                )
                    cylinder(h=L, r=r, $fn=24);
        }
    }
}

module path_points_debug(points, r=0.6){
    for (p = points) translate(p) sphere(r=r, $fn=24);
}


// ============================================================
// Desenha o perfil 2D com corda (chord)
// chord_pivot_pct: 0=LE, 50=meio, 100=TE
// ============================================================
module draw_profile2D(profile, chord=10, chord_pivot_pct=0, attack_angle=0, n=90){
    px = chord_pivot_pct/100;
    pts = profile_points(profile, n=n);

    // move pivot para x=0 e escala pela corda
    pts2 = [ for(p=pts) [ (p[0]-px)*chord, p[1]*chord ] ];

    rotate(attack_angle)
        polygon(points=pts2);
}

// ============================================================
// Polyline 2D -> desenha como "tubo" usando cilindros (sem len())
// steps2d = quantidade de segmentos (se pts tem N pontos, use N)
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

// fecha o contorno (liga último ao primeiro)
module polyline2d_tube_closed(pts2d, steps2d, r=0.12){
    polyline2d_tube(pts2d, steps2d, r=r);
    // fecha com o último segmento
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
// Desenha o perfil como "linha" (tubo) já com chord/pivot/attack
// profile_line_steps é o N usado para gerar os pontos do perfil.
// Para ellipse: N = n (ex: 120)
// Para naca:    N = 2*(n+1) + 2*(n+1) ??? (no nosso naca4_points: concat(upper,lower) => 2*(n+1))
// então: steps2d = 2*(n+1) no NACA e steps2d = n no ellipse
// ============================================================
module draw_profile2D_as_line(profile, chord=10, chord_pivot_pct=0, attack_angle=0, n=90, r=0.12){
    px  = chord_pivot_pct/100;
    pts = profile_points(profile, n=n);

    // aplica pivot + chord
    pts2 = [ for(p=pts) [ (p[0]-px)*chord, p[1]*chord ] ];

    // rotaciona o perfil no plano (attack)
    // (fazendo rotação manual em 2D pra evitar depender de rotate() em filhos)
    ca = cos(attack_angle);
    sa = sin(attack_angle);
    pts3 = [ for(p=pts2) [ p[0]*ca - p[1]*sa, p[0]*sa + p[1]*ca ] ];

    // número de pontos do contorno:
    steps2d = list_size(pts3);

    polyline2d_tube_closed(pts3, steps2d, r=r);
}
