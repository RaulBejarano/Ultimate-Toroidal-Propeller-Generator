// ============================================================
// profile_functions.scad  (NACA + ellipse profiles)
// ============================================================

// --------------------
// NACA 4-digit helpers
// --------------------
function _digit(s,i) = ord(s[i]) - ord("0");

function naca4_params(code) =
    let(
        m = _digit(code,0)/100,
        p = _digit(code,1)/10,
        t = (_digit(code,2)*10 + _digit(code,3))/100
    ) [m,p,t];

// Cosine spacing in [0..1]
function _cosspace(i,n) = 0.5*(1 - cos(180*i/n));

// Thickness distribution (classic NACA)
function naca4_yt(x,t) =
    5*t*(0.2969*sqrt(x) - 0.1260*x - 0.3516*x*x + 0.2843*x*x*x - 0.1015*x*x*x*x);

// Camber line
function naca4_yc(x,m,p) =
    (m==0 || p==0) ? 0 :
    (x<p) ? (m/(p*p))*(2*p*x - x*x)
          : (m/((1-p)*(1-p)))*((1-2*p) + 2*p*x - x*x);

// Derivative of camber line
function naca4_dyc(x,m,p) =
    (m==0 || p==0) ? 0 :
    (x<p) ? (2*m/(p*p))*(p - x)
          : (2*m/((1-p)*(1-p)))*(p - x);

// NACA 4-digit closed outline points (x in [0..1])
// Note: global Y flip is kept to match your upper/lower convention.
function naca4_points(code, n=80) =
    let(
        mp = naca4_params(code),
        m=mp[0], p=mp[1], t=mp[2],

        upper = [
            for(i=[0:n])
                let(
                    x  = _cosspace(i,n),
                    yc = naca4_yc(x,m,p),
                    dy = naca4_dyc(x,m,p),
                    th = atan(dy),
                    yt = naca4_yt(x,t)
                )
                [ x - yt*sin(th), yc + yt*cos(th) ]
        ],

        // Same as iterating [n:-1:0], but without deprecated reversed ranges
        lower = [
            for(ii=[0:n])
                let(
                    i = n - ii,
                    x  = _cosspace(i,n),
                    yc = naca4_yc(x,m,p),
                    dy = naca4_dyc(x,m,p),
                    th = atan(dy),
                    yt = naca4_yt(x,t)
                )
                [ x + yt*sin(th), yc - yt*cos(th) ]
        ],

        pts = concat(upper, lower)
    )
    [ for(pnt = pts) [pnt[0], -pnt[1]] ];

// --------------------
// Ellipse profile: ["ellipse", scale]
// --------------------
function ellipse_points(scale=0.5, n=120) =
    [ for(i=[0:n-1])
        let(
            a = 360*i/n,
            x = (cos(a)+1)/2,
            y = sin(a)*scale/2
        )
        [x,y]
    ];

// Profile selector
function profile_points(profile, n=90) =
    is_string(profile) ? naca4_points(profile, n=n)
  : (is_list(profile) && profile[0]=="ellipse") ? ellipse_points(profile[1], n=n)
  : naca4_points("0012", n=n);
