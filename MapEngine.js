.pragma library

// Motor del mapa de circuito. JavaScript puro, sin dependencias de QML, para poder
// probarlo con Node. Coordenadas del mundo: metros, x = este, y = norte.
// Distancia "s": metros recorridos desde el inicio del trazado, cíclica.

var CHUNK = 16;                      // puntos por bloque para recortar lo que no se ve

function mod(a, m) { var r = a % m; return r < 0 ? r + m : r; }
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function hyp(a, b) { return Math.sqrt(a * a + b * b); }
function lado(c) { return c.side === "izquierda" ? "izquierdo" : "derecho"; }
function round5(v) { return Math.max(5, Math.round(v / 5) * 5); }

// ---------------------------------------------------------------------------
// Construcción de la pista
// ---------------------------------------------------------------------------
function buildTrack(D) {
    var n = D.x.length, ds = D.spacing, L = n * ds;
    var T = { D: D, n: n, ds: ds, L: L, hw: D.halfWidth, x: D.x, y: D.y, off: D.offset,
              hd: [], rx: [], ry: [], ez: [], gr: [], corners: [], pit: D.pit.path,
              kerbs: D.kerbs, runoffs: D.runoffs, barriers: D.barriers };
    var i, a, b;
    for (i = 0; i < n; i++) {
        a = (i + 1) % n; b = (i - 1 + n) % n;
        var h = Math.atan2(D.x[a] - D.x[b], D.y[a] - D.y[b]);
        T.hd.push(h); T.rx.push(Math.cos(h)); T.ry.push(-Math.sin(h));
    }
    // elevación aproximada por interpolación lineal de los puntos de control
    var E = D.elevation;
    for (i = 0; i < n; i++) {
        var s = i * ds, k = 0;
        while (k < E.length - 2 && E[k + 1][0] < s) k++;
        var u = (s - E[k][0]) / Math.max(1e-6, E[k + 1][0] - E[k][0]);
        T.ez.push(E[k][1] + (E[k + 1][1] - E[k][1]) * clamp(u, 0, 1));
    }
    var span = 6;
    for (i = 0; i < n; i++)
        T.gr.push(100 * (T.ez[(i + span) % n] - T.ez[(i - span + n) % n]) / (2 * span * ds));
    // curvas
    for (i = 0; i < D.corners.length; i++) T.corners.push(D.corners[i]);
    // límites y bloques
    var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
    for (i = 0; i < n; i++) {
        minX = Math.min(minX, D.x[i]); maxX = Math.max(maxX, D.x[i]);
        minY = Math.min(minY, D.y[i]); maxY = Math.max(maxY, D.y[i]);
    }
    T.bounds = { minX: minX, maxX: maxX, minY: minY, maxY: maxY };
    T.chunk = { cx: [], cy: [], r: [] };
    for (i = 0; i < n; i += CHUNK) {
        var sx = 0, sy = 0, cnt = 0, j;
        for (j = 0; j <= CHUNK; j++) { sx += D.x[(i + j) % n]; sy += D.y[(i + j) % n]; cnt++; }
        var mx = sx / cnt, my = sy / cnt, rr = 0;
        for (j = 0; j <= CHUNK; j++)
            rr = Math.max(rr, hyp(D.x[(i + j) % n] - mx, D.y[(i + j) % n] - my));
        T.chunk.cx.push(mx); T.chunk.cy.push(my); T.chunk.r.push(rr + T.hw + 40);
    }
    return T;
}

function posAt(T, s, o) {
    o = o || 0;
    var f = mod(s, T.L) / T.ds, i = Math.floor(f), u = f - i, j = (i + 1) % T.n;
    i = i % T.n;
    var x = T.x[i] + (T.x[j] - T.x[i]) * u, y = T.y[i] + (T.y[j] - T.y[i]) * u;
    var fx = Math.sin(T.hd[i]), fy = Math.cos(T.hd[i]);
    var gx = Math.sin(T.hd[j]), gy = Math.cos(T.hd[j]);
    var vx = fx + (gx - fx) * u, vy = fy + (gy - fy) * u;
    var m = Math.sqrt(vx * vx + vy * vy) || 1; vx /= m; vy /= m;
    return { x: x + vy * o, y: y - vx * o, h: Math.atan2(vx, vy), cx: x, cy: y };
}

function lineOffsetAt(T, s) {
    var f = mod(s, T.L) / T.ds, i = Math.floor(f), u = f - i;
    return T.off[i % T.n] + (T.off[(i + 1) % T.n] - T.off[i % T.n]) * u;
}

function elevAt(T, s) {
    var f = mod(s, T.L) / T.ds, i = Math.floor(f), u = f - i;
    return T.ez[i % T.n] + (T.ez[(i + 1) % T.n] - T.ez[i % T.n]) * u;
}

function gradeAt(T, s) { return T.gr[Math.floor(mod(s, T.L) / T.ds) % T.n]; }

// distancia con signo en la vuelta: positivo = adelante
function sgn(T, d) { return mod(d + T.L / 2, T.L) - T.L / 2; }

// ---------------------------------------------------------------------------
// Curva en foco, fase y alertas
// ---------------------------------------------------------------------------
function zoneStart(c) { return (c.sBrake !== null ? c.sBrake : c.sIn - 30) - 20; }

function focus(T, s) {
    var chosen = null, chosenKey = 1e18, best = null, bestD = 1e18, k, c;
    for (k = 0; k < T.corners.length; k++) {
        c = T.corners[k];
        var start = zoneStart(c);
        var rel = mod(s - start, T.L), span = mod(c.sOut + 10 - start, T.L);
        if (rel <= span) {
            var key = mod(c.sOut - s, T.L);          // la que termina antes
            if (key < chosenKey) { chosenKey = key; chosen = c; }
        } else {
            var d = mod(start - s, T.L);
            if (d < bestD) { bestD = d; best = c; }
        }
    }
    c = chosen || best;
    var dIn = sgn(T, c.sIn - s);
    var dBrake = c.sBrake !== null ? sgn(T, c.sBrake - s) : null;
    var dOut = sgn(T, c.sOut - s);
    var nextApex = null, apexesLeft = 0, j;
    for (j = 0; j < c.apexes.length; j++) {
        var da = sgn(T, c.apexes[j] - s);
        if (da > 0) { apexesLeft++; if (nextApex === null) nextApex = da; }
    }
    var phase;
    if (dBrake !== null && dBrake > 0) phase = "approach";
    else if (dBrake !== null && dIn > 0) phase = "brake";
    else if (dBrake === null && dIn > 0) phase = "approach";
    else if (apexesLeft > 0) phase = "turn";
    else if (dOut > 0) phase = "exit";
    else phase = "done";
    var between = c.apexes.length > 1 && dIn <= 0 && apexesLeft > 0 && apexesLeft < c.apexes.length;
    return { idx: c.idx, corner: c, phase: phase, inside: !!chosen, dIn: dIn, dBrake: dBrake,
             dApex: nextApex, dOut: dOut, between: between };
}

function alerts(T, s, speedKmh, F) {
    var c = F.corner, name = c.name, nm = round5;
    if (F.phase === "brake")
        return { level: 3, title: "Frena ahora", sub: name + ", curva en " + nm(F.dIn) + " m" };
    if (F.phase === "approach") {
        if (c.sBrake !== null) {
            if (F.dBrake <= 70)
                return { level: 2, title: "Frenada próxima", sub: "Frena en " + nm(F.dBrake) + " m, " + name };
            if (F.dBrake <= 250)
                return { level: 1, title: "Mantén el lado " + lado(c), sub: name + ", frenada en " + nm(F.dBrake) + " m" };
        } else if (F.dIn <= 250) {
            if (c.blind)
                return { level: 2, title: "Curva ciega, sin frenar", sub: name + ", en " + nm(F.dIn) + " m. Mantén el lado " + lado(c) };
            return { level: 1, title: "Sin frenar, lado " + lado(c), sub: name + ", en " + nm(F.dIn) + " m" };
        }
        return { level: 0, title: "Recta", sub: "Siguiente: " + name + ", en " + nm(F.dIn) + " m" };
    }
    if (F.phase === "turn") {
        if (F.between)
            return { level: 1, title: "Prepara el cambio de dirección", sub: name };
        return { level: 1, title: "Vértice", sub: "Mantén la trazada en " + name };
    }
    if (F.phase === "exit") {
        var t = c.exit_alert || "";
        if (t) {
            var p = t.indexOf(":");
            var title = p > 0 ? t.substring(0, p) : t.replace(/\.$/, "");
            var sub = p > 0 ? t.substring(p + 1).trim() : name;
            return { level: /cuidado/i.test(title) ? 2 : 1, title: title, sub: sub };
        }
        return { level: 1, title: "Salida limpia", sub: name };
    }
    return { level: 0, title: "Recta", sub: "Siguiente: " + name };
}

// 3, 2 y 1 barras a 150, 100 y 50 m del punto de frenada
function brakeBoards(c) {
    if (c.sBrake === null) return [];
    return [ { s: c.sBrake - 150, n: 3 }, { s: c.sBrake - 100, n: 2 }, { s: c.sBrake - 50, n: 1 } ];
}

// ---------------------------------------------------------------------------
// Teselas satelitales (Web Mercator). El mapa es independiente del proveedor.
// ---------------------------------------------------------------------------
function tileList(T, z, template) {
    var O = T.D.origin, b = T.bounds, pad = 120;
    function lon(x) { return O.lon + x / O.kx; }
    function lat(y) { return O.lat + y / O.ky; }
    var n2 = Math.pow(2, z);
    function tx(lo) { return Math.floor((lo + 180) / 360 * n2); }
    function ty(la) {
        var r = la * Math.PI / 180;
        return Math.floor((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * n2);
    }
    function tlon(i) { return i / n2 * 360 - 180; }
    function tlat(j) { var m = Math.PI * (1 - 2 * j / n2); return Math.atan(0.5 * (Math.exp(m) - Math.exp(-m))) * 180 / Math.PI; }
    var x0 = tx(lon(b.minX - pad)), x1 = tx(lon(b.maxX + pad));
    var y0 = ty(lat(b.maxY + pad)), y1 = ty(lat(b.minY - pad));
    var out = [], i, j;
    for (j = y0; j <= y1; j++) {
        for (i = x0; i <= x1; i++) {
            var wLon = tlon(i), eLon = tlon(i + 1), nLat = tlat(j), sLat = tlat(j + 1);
            out.push({
                url: template.replace("{z}", z).replace("{x}", i).replace("{y}", j),
                x: (wLon - O.lon) * O.kx, y: -(nLat - O.lat) * O.ky,      // esquina NO, y hacia abajo
                w: (eLon - wLon) * O.kx, h: (nLat - sLat) * O.ky
            });
        }
    }
    return out;
}

// ---------------------------------------------------------------------------
// Cámaras
// ---------------------------------------------------------------------------
function overviewCam(T, W, H, st) {
    var b = T.bounds, bw = b.maxX - b.minX, bh = b.maxY - b.minY;
    var usableH = H - 78;                           // la franja de elevación ocupa el borde inferior
    var fit = Math.min((W - 56) / bw, (usableH - 20) / bh);
    var sc = fit * (st.zoom || 1);
    var cx = st.cx !== undefined && st.cx !== null ? st.cx : (b.minX + b.maxX) / 2;
    var cy = st.cy !== undefined && st.cy !== null ? st.cy : (b.minY + b.maxY) / 2;
    return { nav: false, sc: sc, fit: fit, cx: cx, cy: cy, px: W / 2, py: usableH / 2 + 6, W: W, H: H,
             ch: 1, sh: 0, viewR: 1e9, ox: 0, oy: 0 };
}

function navCam(T, W, H, st) {
    var p = posAt(T, st.lapS, 0), sc = st.navScale || 1.3;
    return { nav: true, sc: sc, cx: p.x, cy: p.y, h: p.h, px: W / 2, py: H * 0.72, W: W, H: H,
             ch: Math.cos(p.h), sh: Math.sin(p.h), viewR: hyp(W, H) / sc * 0.75, ox: 0, oy: 0 };
}

function pj(cam, x, y) {
    var dx = x - cam.cx, dy = y - cam.cy;
    if (cam.nav) {
        cam.ox = cam.px + (dx * cam.ch - dy * cam.sh) * cam.sc;
        cam.oy = cam.py - (dx * cam.sh + dy * cam.ch) * cam.sc;
    } else {
        cam.ox = cam.px + dx * cam.sc;
        cam.oy = cam.py - dy * cam.sc;
    }
}

function visibleChunk(cam, T, k) {
    return hyp(T.chunk.cx[k] - cam.cx, T.chunk.cy[k] - cam.cy) < cam.viewR + T.chunk.r[k];
}

// ---------------------------------------------------------------------------
// Primitivas de trazado
// ---------------------------------------------------------------------------
// Camino por la línea central (o desplazada) entre s0 y s1, sin cerrar.
function tracePath(ctx, cam, T, s0, s1, o) {
    var i0 = Math.floor(s0 / T.ds), i1 = Math.ceil(s1 / T.ds), first = true, i, ii, off, x, y;
    for (i = i0; i <= i1; i++) {
        ii = mod(i, T.n);
        off = o === "line" ? T.off[ii] : o;
        x = T.x[ii] + T.rx[ii] * off; y = T.y[ii] + T.ry[ii] * off;
        pj(cam, x, y);
        if (first) { ctx.moveTo(cam.ox, cam.oy); first = false; } else ctx.lineTo(cam.ox, cam.oy);
    }
}

// Toda la vuelta, omitiendo los bloques que quedan fuera de la vista.
function lapPath(ctx, cam, T, o) {
    var nChunks = T.chunk.cx.length, k, down = false, i, ii, off, x, y, last = null;
    for (k = 0; k < nChunks; k++) {
        if (!visibleChunk(cam, T, k)) { down = false; continue; }
        for (i = k * CHUNK; i <= k * CHUNK + CHUNK; i++) {
            ii = i % T.n;
            off = o === "line" ? T.off[ii] : o;
            x = T.x[ii] + T.rx[ii] * off; y = T.y[ii] + T.ry[ii] * off;
            pj(cam, x, y);
            if (!down) { ctx.moveTo(cam.ox, cam.oy); down = true; } else ctx.lineTo(cam.ox, cam.oy);
        }
    }
}

function styleStroke(ctx, color, width, alpha, cap, join) {
    ctx.strokeStyle = color; ctx.lineWidth = width; ctx.globalAlpha = alpha === undefined ? 1 : alpha;
    ctx.lineCap = cap || "butt"; ctx.lineJoin = join || "round";
}

function rangeVisible(cam, T, s0, s1) {
    if (!cam.nav) return true;
    var p = posAt(T, (s0 + s1) / 2, 0), half = Math.abs(s1 - s0) / 2 + 40;
    return hyp(p.cx - cam.cx, p.cy - cam.cy) < cam.viewR + half;
}

function drawLabel(ctx, text, x, y, color, size, bold, align) {
    ctx.font = (bold ? "bold " : "") + size + "px sans-serif";
    ctx.textAlign = align || "left"; ctx.textBaseline = "middle";
    ctx.lineWidth = 3; ctx.strokeStyle = "rgba(8,12,16,0.85)"; ctx.globalAlpha = 1;
    ctx.strokeText(text, x, y);
    ctx.fillStyle = color; ctx.fillText(text, x, y);
}

function dot(ctx, x, y, r, fill, stroke, sw) {
    ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.globalAlpha = 1; ctx.fillStyle = fill; ctx.fill();
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = sw || 2; ctx.stroke(); }
}

function difficultyColor(c, th) { return c.difficulty >= 4 ? th.danger : (c.difficulty === 3 ? th.warn : th.good); }

// ---------------------------------------------------------------------------
// Modo navegación (vista tipo conducción, rumbo hacia arriba)
// ---------------------------------------------------------------------------
function drawNav(ctx, W, H, T, st) {
    var th = st.theme, cam = navCam(T, W, H, st), sc = cam.sc, hw = T.hw, k, i, r;
    var F = st.focus, c = F.corner;
    ctx.globalAlpha = 1;
    ctx.fillStyle = th.terrain; ctx.fillRect(0, 0, W, H);

    // escapatorias
    var rcol = { asphalt: "#4a535e", gravel: "#85734a", grass: "#1d3b2a" };
    for (k = 0; k < T.runoffs.length; k++) {
        r = T.runoffs[k];
        if (!rangeVisible(cam, T, r.s0, r.s1)) continue;
        ctx.beginPath(); tracePath(ctx, cam, T, r.s0, r.s1, r.side * (hw + r.width / 2));
        styleStroke(ctx, rcol[r.type], r.width * sc, 1, "butt", "round"); ctx.stroke();
    }
    // barreras
    for (k = 0; k < T.barriers.length; k++) {
        r = T.barriers[k];
        if (!rangeVisible(cam, T, r.s0, r.s1)) continue;
        ctx.beginPath(); tracePath(ctx, cam, T, r.s0, r.s1, r.side * r.off);
        styleStroke(ctx, "#aab4be", Math.max(2, 0.7 * sc), 0.85, "butt", "round"); ctx.stroke();
    }
    // asfalto y bordes
    ctx.beginPath(); lapPath(ctx, cam, T, 0);
    styleStroke(ctx, th.asphalt, 2 * hw * sc, 1, "round", "round"); ctx.stroke();
    ctx.beginPath(); lapPath(ctx, cam, T, -(hw - 0.4));
    styleStroke(ctx, "#e8edf2", Math.max(1.2, 0.4 * sc), 0.9, "butt", "round"); ctx.stroke();
    ctx.beginPath(); lapPath(ctx, cam, T, hw - 0.4);
    styleStroke(ctx, "#e8edf2", Math.max(1.2, 0.4 * sc), 0.9, "butt", "round"); ctx.stroke();

    // boxes
    if (T.pit && T.pit.length > 1) {
        ctx.beginPath();
        for (i = 0; i < T.pit.length; i++) {
            pj(cam, T.pit[i][0], T.pit[i][1]);
            if (i === 0) ctx.moveTo(cam.ox, cam.oy); else ctx.lineTo(cam.ox, cam.oy);
        }
        styleStroke(ctx, "#3a3f46", 6 * sc, 1, "round", "round"); ctx.stroke();
        styleStroke(ctx, th.warn, Math.max(1.5, 0.5 * sc), 0.9, "round", "round"); ctx.stroke();
        pj(cam, T.pit[0][0], T.pit[0][1]);
        if (hyp(cam.ox - W / 2, cam.oy - H / 2) < Math.max(W, H))
            drawLabel(ctx, "Entrada a boxes", cam.ox + 10, cam.oy, th.warn, 11, true);
        pj(cam, T.pit[T.pit.length - 1][0], T.pit[T.pit.length - 1][1]);
        if (hyp(cam.ox - W / 2, cam.oy - H / 2) < Math.max(W, H))
            drawLabel(ctx, "Salida de boxes", cam.ox + 10, cam.oy, th.warn, 11, true);
    }

    // pianos (rayas alternas rojo y blanco)
    for (k = 0; k < T.kerbs.length; k++) {
        r = T.kerbs[k];
        if (!rangeVisible(cam, T, r.s0, r.s1)) continue;
        var o = r.side * (hw - 0.9), s, flip = 0;
        for (s = r.s0; s < r.s1; s += 3) {
            var a = posAt(T, s, o), b = posAt(T, Math.min(s + 3, r.s1), o);
            pj(cam, a.x, a.y); var ax = cam.ox, ay = cam.oy;
            pj(cam, b.x, b.y);
            ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(cam.ox, cam.oy);
            styleStroke(ctx, flip % 2 === 0 ? "#e5484d" : "#f4f6f8", Math.max(2, 1.7 * sc), 1, "butt", "round");
            ctx.stroke(); flip++;
        }
    }

    // flechas de pendiente (naranja = sube, azul = baja)
    if (st.layers.grade) {
        var s0 = st.lapS - 100, s1 = st.lapS + 900, sa;
        for (sa = Math.floor(s0 / 40) * 40; sa < s1; sa += 40) {
            var g = gradeAt(T, sa);
            if (Math.abs(g) < 1.8) continue;
            var pp = posAt(T, sa, 0); pj(cam, pp.cx, pp.cy);
            var ang = pp.h - cam.h, size = 7, col = g > 0 ? "#ff9f43" : "#4ea8ff";
            var fx = Math.sin(ang), fy = -Math.cos(ang), rxn = -fy, ryn = fx;
            ctx.beginPath();
            ctx.moveTo(cam.ox + fx * size, cam.oy + fy * size);
            ctx.lineTo(cam.ox - fx * size * 0.4 + rxn * size, cam.oy - fy * size * 0.4 + ryn * size);
            ctx.lineTo(cam.ox - fx * size * 0.4 - rxn * size, cam.oy - fy * size * 0.4 - ryn * size);
            ctx.closePath(); ctx.globalAlpha = 0.85; ctx.fillStyle = col; ctx.fill();
        }
    }

    // trazada de referencia, tenue
    if (st.layers.line) {
        ctx.beginPath(); tracePath(ctx, cam, T, st.lapS - 150, st.lapS + 1200, "line");
        styleStroke(ctx, th.accent, 2, 0.45, "round", "round"); ctx.stroke();
    }

    // tramo de la próxima curva resaltado; el resto del circuito sigue visible
    var hs0 = (c.sBrake !== null ? c.sBrake : c.sIn - 40) - 15, hs1 = c.sOut + 25;
    var hl = mod(hs1 - hs0, T.L), hstart = hs0;
    if (F.inside || F.phase === "approach") {
        ctx.beginPath(); tracePath(ctx, cam, T, hstart, hstart + hl, 0);
        styleStroke(ctx, th.accent, (2 * hw + 8) * sc, 0.2, "round", "round"); ctx.stroke();
        ctx.beginPath(); tracePath(ctx, cam, T, hstart, hstart + hl, "line");
        styleStroke(ctx, th.accent, Math.max(3, 0.9 * sc), 0.95, "round", "round"); ctx.stroke();
    }

    // marcadores de frenada (3, 2 y 1 barras) y línea de frenada
    for (k = 0; k < T.corners.length; k++) {
        var cc = T.corners[k];
        if (cc.sBrake === null || !rangeVisible(cam, T, cc.sBrake - 160, cc.sBrake + 10)) continue;
        var boards = brakeBoards(cc), bi, bar;
        for (bi = 0; bi < boards.length; bi++) {
            for (bar = 0; bar < boards[bi].n; bar++) {
                var sb = boards[bi].s + bar * 4;
                var l = posAt(T, sb, -(hw + 1.5)), rr = posAt(T, sb, -(hw + 6));
                pj(cam, l.x, l.y); var lx = cam.ox, ly = cam.oy; pj(cam, rr.x, rr.y);
                ctx.beginPath(); ctx.moveTo(lx, ly); ctx.lineTo(cam.ox, cam.oy);
                styleStroke(ctx, "#f4f6f8", Math.max(2, 1.2 * sc), 1, "butt"); ctx.stroke();
                var l2 = posAt(T, sb, hw + 1.5), r2 = posAt(T, sb, hw + 6);
                pj(cam, l2.x, l2.y); lx = cam.ox; ly = cam.oy; pj(cam, r2.x, r2.y);
                ctx.beginPath(); ctx.moveTo(lx, ly); ctx.lineTo(cam.ox, cam.oy); ctx.stroke();
            }
        }
        var e1 = posAt(T, cc.sBrake, -hw), e2 = posAt(T, cc.sBrake, hw);
        pj(cam, e1.x, e1.y); var bx = cam.ox, by = cam.oy; pj(cam, e2.x, e2.y);
        ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(cam.ox, cam.oy);
        styleStroke(ctx, th.danger, Math.max(3, 1.4 * sc), 1, "butt"); ctx.stroke();
    }

    // meta
    var m1 = posAt(T, 0, -hw), m2 = posAt(T, 0, hw);
    pj(cam, m1.x, m1.y); var mx1 = cam.ox, my1 = cam.oy; pj(cam, m2.x, m2.y);
    ctx.beginPath(); ctx.moveTo(mx1, my1); ctx.lineTo(cam.ox, cam.oy);
    styleStroke(ctx, "#ffffff", Math.max(3, 1.2 * sc), 1, "butt"); ctx.stroke();

    // nombres de las curvas cercanas
    for (k = 0; k < T.corners.length; k++) {
        var cn = T.corners[k], pm = posAt(T, cn.sMark, -cn.dirs[0] * (hw + 14));
        pj(cam, pm.x, pm.y);
        if (cam.ox < -40 || cam.ox > W + 40 || cam.oy < -20 || cam.oy > H + 20) continue;
        var isFocus = cn.idx === c.idx;
        drawLabel(ctx, cn.name, cam.ox, cam.oy, isFocus ? th.accent : th.text, isFocus ? 13 : 11, isFocus, "center");
    }

    // el auto: una flecha
    ctx.save(); ctx.translate(cam.px, cam.py);
    ctx.beginPath(); ctx.moveTo(0, -15); ctx.lineTo(10, 11); ctx.lineTo(0, 5); ctx.lineTo(-10, 11); ctx.closePath();
    ctx.globalAlpha = 1; ctx.fillStyle = th.accent; ctx.fill();
    ctx.strokeStyle = "#08131a"; ctx.lineWidth = 2; ctx.stroke();
    ctx.restore();
    ctx.globalAlpha = 1;

    drawElevation(ctx, 12, H - 62, W - 24, 50, T, st, st.lapS - 200, st.lapS + 1000, true);
}

// ---------------------------------------------------------------------------
// Modo satélite / análisis (norte arriba)
// ---------------------------------------------------------------------------
function drawOverview(ctx, W, H, T, st) {
    var th = st.theme, cam = overviewCam(T, W, H, st), hw = T.hw, k, i, c;
    ctx.globalAlpha = 1;
    ctx.clearRect(0, 0, W, H);
    if (!st.hasTiles) {
        ctx.fillStyle = th.terrain; ctx.fillRect(0, 0, W, H);
        ctx.strokeStyle = "rgba(255,255,255,0.05)"; ctx.lineWidth = 1; ctx.beginPath();
        for (i = 0.5; i < W; i += 32) { ctx.moveTo(i, 0); ctx.lineTo(i, H); }
        for (i = 0.5; i < H; i += 32) { ctx.moveTo(0, i); ctx.lineTo(W, i); }
        ctx.stroke();
    }
    var w = 2.6 + 1.2 * Math.min(3, st.zoom || 1);
    ctx.beginPath(); lapPath(ctx, cam, T, 0);
    styleStroke(ctx, "#05090d", w + 4, 0.7, "round", "round"); ctx.stroke();
    ctx.beginPath(); lapPath(ctx, cam, T, 0);
    styleStroke(ctx, "#f1f5f9", w, 0.95, "round", "round"); ctx.stroke();

    // boxes
    if (st.layers.boxes && T.pit.length > 1) {
        ctx.beginPath();
        for (i = 0; i < T.pit.length; i++) {
            pj(cam, T.pit[i][0], T.pit[i][1]);
            if (i === 0) ctx.moveTo(cam.ox, cam.oy); else ctx.lineTo(cam.ox, cam.oy);
        }
        styleStroke(ctx, th.warn, w, 0.95, "round", "round"); ctx.stroke();
        pj(cam, T.pit[0][0], T.pit[0][1]);
        dot(ctx, cam.ox, cam.oy, 8, th.warn, "#08131a", 2);
        drawLabel(ctx, "Entrada a boxes", cam.ox + 14, cam.oy - 8, th.warn, 11, true);
        pj(cam, T.pit[T.pit.length - 1][0], T.pit[T.pit.length - 1][1]);
        dot(ctx, cam.ox, cam.oy, 8, th.warn, "#08131a", 2);
        drawLabel(ctx, "Salida de boxes", cam.ox - 14, cam.oy + 18, th.warn, 11, true, "right");
    }

    // trazada de referencia completa
    if (st.layers.line) {
        ctx.beginPath(); lapPath(ctx, cam, T, "line");
        styleStroke(ctx, th.accent, 1.6, 0.8, "round", "round"); ctx.stroke();
    }
    // zonas de frenada
    if (st.layers.brake) {
        for (k = 0; k < T.corners.length; k++) {
            c = T.corners[k];
            if (c.sBrake === null) continue;
            ctx.beginPath(); tracePath(ctx, cam, T, c.sBrake, c.sIn, "line");
            styleStroke(ctx, th.danger, w + 1, 0.95, "butt", "round"); ctx.stroke();
        }
    }

    // análisis de la curva elegida: frenada, entrada, vértices y salida
    var sel = T.corners[st.selected] || T.corners[0];
    if (st.layers.apex) {
        ctx.beginPath(); tracePath(ctx, cam, T, (sel.sBrake !== null ? sel.sBrake : sel.sIn) - 10, sel.sOut + 25, "line");
        styleStroke(ctx, th.accent, w + 2.5, 1, "round", "round"); ctx.stroke();
        var pts = [];
        if (sel.sBrake !== null) pts.push({ s: sel.sBrake, t: "Frenada", col: th.danger, sq: true });
        pts.push({ s: sel.sIn, t: "Entrada", col: th.warn });
        for (i = 0; i < sel.apexes.length; i++)
            pts.push({ s: sel.apexes[i], t: sel.apexes.length > 1 ? "Vértice " + (i + 1) : "Vértice", col: th.accent });
        pts.push({ s: sel.sOut, t: "Salida", col: th.good });
        for (i = 0; i < pts.length; i++) {
            var q = posAt(T, pts[i].s, lineOffsetAt(T, pts[i].s));
            pj(cam, q.x, q.y);
            if (pts[i].sq) { ctx.globalAlpha = 1; ctx.fillStyle = pts[i].col; ctx.fillRect(cam.ox - 6, cam.oy - 6, 12, 12); ctx.strokeStyle = "#08131a"; ctx.lineWidth = 2; ctx.strokeRect(cam.ox - 6, cam.oy - 6, 12, 12); }
            else dot(ctx, cam.ox, cam.oy, 6, pts[i].col, "#08131a", 2);
            drawLabel(ctx, pts[i].t, cam.ox + 10, cam.oy + (i % 2 === 0 ? -10 : 12), pts[i].col, 11, true);
        }
    }

    // meta
    pj(cam, T.x[0], T.y[0]);
    ctx.globalAlpha = 1; ctx.fillStyle = "#ffffff"; ctx.fillRect(cam.ox - 5, cam.oy - 5, 10, 10);
    ctx.fillStyle = "#08131a"; ctx.fillRect(cam.ox - 5, cam.oy - 5, 5, 5); ctx.fillRect(cam.ox, cam.oy, 5, 5);
    drawLabel(ctx, "Meta", cam.ox + 10, cam.oy + 14, "#ffffff", 11, true);

    // insignias de las curvas: el anillo indica la dificultad
    for (k = 0; k < T.corners.length; k++) {
        c = T.corners[k];
        var pm = posAt(T, c.sMark, 0); pj(cam, pm.x, pm.y);
        var isSel = c.idx === sel.idx, rad = isSel ? 13 : 10;
        dot(ctx, cam.ox, cam.oy, rad, isSel ? th.accent : "#0b1118", difficultyColor(c, th), isSel ? 3 : 2.5);
        drawLabel(ctx, String(c.idx + 1), cam.ox, cam.oy, isSel ? "#08131a" : "#f1f5f9", isSel ? 13 : 11, true, "center");
        if (st.layers.names || isSel)
            drawLabel(ctx, c.name, cam.ox + rad + 4, cam.oy - rad + 2, isSel ? th.accent : th.text, isSel ? 13 : 11, isSel);
    }
    drawElevation(ctx, 12, H - 62, W - 24, 50, T, st, 0, T.L, false);
}

function focusView(T, W, H, c) {
    var cam = overviewCam(T, W, H, { zoom: 1 });
    var span = Math.max(120, (c.sOut - c.sIn) * 1.7);
    var zoom = clamp((Math.min(W, H) * 0.55) / (span * cam.fit), 1, 12);
    var p = posAt(T, c.sMark, 0);
    return { zoom: zoom, cx: p.x, cy: p.y };
}

function hitCorner(T, W, H, st, mx, my) {
    var cam = overviewCam(T, W, H, st), best = -1, bestD = 18, k;
    for (k = 0; k < T.corners.length; k++) {
        var p = posAt(T, T.corners[k].sMark, 0); pj(cam, p.x, p.y);
        var d = hyp(cam.ox - mx, cam.oy - my);
        if (d < bestD) { bestD = d; best = k; }
    }
    return best;
}

// ---------------------------------------------------------------------------
// Franja de elevación (aproximada) con las curvas marcadas
// ---------------------------------------------------------------------------
function drawElevation(ctx, x, y, w, h, T, st, sa, sb, isNav) {
    var th = st.theme, steps = Math.max(2, Math.floor(w / 3)), i, zmin = 1e9, zmax = -1e9, s, z;
    ctx.globalAlpha = 1; ctx.fillStyle = "rgba(8,12,16,0.72)"; ctx.fillRect(x, y, w, h);
    for (i = 0; i <= steps; i++) {
        z = elevAt(T, sa + (sb - sa) * i / steps); zmin = Math.min(zmin, z); zmax = Math.max(zmax, z);
    }
    var pad = Math.max(6, (zmax - zmin) * 0.15); zmin -= pad; zmax += pad;
    ctx.beginPath(); ctx.moveTo(x, y + h);
    for (i = 0; i <= steps; i++) {
        z = elevAt(T, sa + (sb - sa) * i / steps);
        ctx.lineTo(x + w * i / steps, y + h - (z - zmin) / (zmax - zmin) * (h - 14));
    }
    ctx.lineTo(x + w, y + h); ctx.closePath();
    ctx.fillStyle = th.accent; ctx.globalAlpha = 0.16; ctx.fill();
    ctx.beginPath();
    for (i = 0; i <= steps; i++) {
        z = elevAt(T, sa + (sb - sa) * i / steps);
        var yy = y + h - (z - zmin) / (zmax - zmin) * (h - 14);
        if (i === 0) ctx.moveTo(x, yy); else ctx.lineTo(x + w * i / steps, yy);
    }
    styleStroke(ctx, th.accent, 1.6, 0.95, "round", "round"); ctx.stroke();
    // curvas en la franja
    var k, c;
    for (k = 0; k < T.corners.length; k++) {
        c = T.corners[k];
        var rel = sgn(T, c.sMark - (sa + sb) / 2) + (sa + sb) / 2;
        if (!isNav) rel = c.sMark;
        if (rel < sa || rel > sb) continue;
        var cx = x + w * (rel - sa) / (sb - sa);
        var isSel = (!isNav && c.idx === st.selected) || (isNav && st.focus && c.idx === st.focus.idx);
        ctx.beginPath(); ctx.moveTo(cx, y + 2); ctx.lineTo(cx, y + h);
        styleStroke(ctx, isSel ? th.accent : th.muted, isSel ? 2 : 1, isSel ? 1 : 0.55, "butt");
        ctx.stroke();
        drawLabel(ctx, String(c.idx + 1), cx, y + 8, isSel ? th.accent : th.muted, 10, isSel, "center");
    }
    if (isNav) {
        var cxn = x + w * (st.lapS - sa) / (sb - sa);
        ctx.beginPath(); ctx.moveTo(cxn, y); ctx.lineTo(cxn, y + h);
        styleStroke(ctx, "#ffffff", 2, 1, "butt"); ctx.stroke();
        var g = gradeAt(T, st.lapS);
        drawLabel(ctx, (g >= 0 ? "+" : "") + g.toFixed(0) + " %", cxn + 6, y + h - 9,
                  g > 1.8 ? "#ff9f43" : (g < -1.8 ? "#4ea8ff" : th.text), 11, true);
    }
    drawLabel(ctx, "Elevación aprox.", x + w - 6, y + h - 8, th.muted, 10, false, "right");
    ctx.globalAlpha = 1;
}

function draw(ctx, W, H, T, st) {
    if (st.mode === "nav") drawNav(ctx, W, H, T, st); else drawOverview(ctx, W, H, T, st);
}
