#!/usr/bin/env python3
"""Simulador de una consola PlayStation con Gran Turismo 7.

Sirve para probar la aplicación sin la consola ni el juego:
  1. Escucha el latido (UDP 33739), igual que la consola.
  2. Al recibirlo, envía paquetes de telemetría cifrados (Salsa20) a la IP que lo mandó,
     al puerto 33740, a 60 paquetes por segundo.
  3. El "auto" recorre Spa-Francorchamps con una velocidad que depende de la curvatura:
     frena antes de las curvas, acelera a la salida y cambia de marcha.

Uso en el mismo PC:   python3 gt7_fake_console.py --track SpaData.js
  y en la aplicación escribe como IP de la consola:  127.0.0.1

Uso desde otro equipo: ejecútalo en una máquina de la red y escribe su IP en la aplicación.
Las coordenadas se giran y se desplazan a propósito, como pasaría con las del juego.
"""
import argparse, json, math, socket, struct, sys, time

# ---------------------------------------------------------------- Salsa20 ----
M = 0xFFFFFFFF


def _rotl(a, b):
    return ((a << b) & M) | (a >> (32 - b))


def _quarter(y0, y1, y2, y3):
    z1 = y1 ^ _rotl((y0 + y3) & M, 7)
    z2 = y2 ^ _rotl((z1 + y0) & M, 9)
    z3 = y3 ^ _rotl((z2 + z1) & M, 13)
    z0 = y0 ^ _rotl((z3 + z2) & M, 18)
    return z0, z1, z2, z3


def _block(inp):
    x = list(inp)
    for _ in range(10):
        x[0], x[4], x[8], x[12] = _quarter(x[0], x[4], x[8], x[12])
        x[5], x[9], x[13], x[1] = _quarter(x[5], x[9], x[13], x[1])
        x[10], x[14], x[2], x[6] = _quarter(x[10], x[14], x[2], x[6])
        x[15], x[3], x[7], x[11] = _quarter(x[15], x[3], x[7], x[11])
        x[0], x[1], x[2], x[3] = _quarter(x[0], x[1], x[2], x[3])
        x[5], x[6], x[7], x[4] = _quarter(x[5], x[6], x[7], x[4])
        x[10], x[11], x[8], x[9] = _quarter(x[10], x[11], x[8], x[9])
        x[15], x[12], x[13], x[14] = _quarter(x[15], x[12], x[13], x[14])
    return struct.pack("<16I", *[(x[i] + inp[i]) & M for i in range(16)])


def salsa20_xor(key, nonce, data):
    k = struct.unpack("<8I", key)
    v = struct.unpack("<2I", nonce)
    out, ctr = bytearray(), 0
    for off in range(0, len(data), 64):
        st = [0x61707865, k[0], k[1], k[2], k[3], 0x3320646E, v[0], v[1], ctr & M, ctr >> 32,
              0x79622D32, k[4], k[5], k[6], k[7], 0x6B206574]
        ks = _block(st)
        chunk = data[off:off + 64]
        out += bytes(a ^ b for a, b in zip(chunk, ks))
        ctr += 1
    return bytes(out)


KEY = b"Simulator Interface Packet GT7 ver 0.0"[:32]
TYPES = {b"A": (296, 0xDEADBEAF), b"B": (316, 0xDEADBEEF), b"~": (344, 0x55FABB4F)}


def build_packet(kind, f, packet_id, iv1):
    size, xor = TYPES[kind]
    p = bytearray(size)
    struct.pack_into("<I", p, 0x00, 0x47375330)
    struct.pack_into("<3f", p, 0x04, f["x"], f["y"], f["z"])
    struct.pack_into("<3f", p, 0x10, f["vx"], f["vy"], f["vz"])
    struct.pack_into("<f", p, 0x3C, f["rpm"])
    struct.pack_into("<f", p, 0x44, 55.0)               # combustible
    struct.pack_into("<f", p, 0x48, 100.0)
    struct.pack_into("<f", p, 0x4C, f["speed"])
    struct.pack_into("<i", p, 0x70, packet_id)
    struct.pack_into("<h", p, 0x74, f["lap"])
    struct.pack_into("<h", p, 0x76, 7)
    struct.pack_into("<i", p, 0x78, f["best"])
    struct.pack_into("<i", p, 0x7C, f["last"])
    struct.pack_into("<h", p, 0x88, 7600)
    struct.pack_into("<h", p, 0x8A, 8300)
    struct.pack_into("<h", p, 0x8E, 0x0009)             # en pista + en marcha
    p[0x90] = ((min(f["gear"] + 1, 14) & 0xF) << 4) | (f["gear"] & 0xF)
    p[0x91] = int(round(max(0.0, min(1.0, f["throttle"])) * 255))
    p[0x92] = int(round(max(0.0, min(1.0, f["brake"])) * 255))
    struct.pack_into("<i", p, 0x124, 3554)              # código de auto de ejemplo
    nonce = struct.pack("<II", iv1 ^ xor, iv1)
    c = bytearray(salsa20_xor(KEY, nonce, bytes(p)))
    c[0x40:0x44] = struct.pack("<I", iv1)               # el IV viaja en claro
    return bytes(c)


# ------------------------------------------------------------------ pista ----
def load_track(path):
    txt = open(path, encoding="utf-8").read()
    data = json.loads(txt.split("var SPA = ", 1)[1].rsplit(";", 1)[0])
    return data


def speed_profile(d, a_lat=13.0, v_top=88.0, a_brake=14.0, a_acc=8.5):
    x, y, ds, n = d["x"], d["y"], d["spacing"], len(d["x"])
    hd = [math.atan2(x[(i + 1) % n] - x[i - 1], y[(i + 1) % n] - y[i - 1]) for i in range(n)]
    kap = []
    for i in range(n):
        dh = (hd[(i + 1) % n] - hd[i - 1] + math.pi) % (2 * math.pi) - math.pi
        kap.append(abs(dh) / (2 * ds))
    kap = [sum(kap[(i + j) % n] for j in range(-2, 3)) / 5 for i in range(n)]
    v = [min(v_top, math.sqrt(a_lat / max(k, 1e-4))) for k in kap]
    for _ in range(3):
        for i in reversed(range(2 * n)):
            j, k = i % n, (i + 1) % n
            v[j] = min(v[j], math.sqrt(v[k] ** 2 + 2 * a_brake * ds))
        for i in range(2 * n):
            j, k = i % n, (i + 1) % n
            acc = a_acc * max(0.15, 1 - v[j] / (v_top + 12))
            v[k] = min(v[k], math.sqrt(v[j] ** 2 + 2 * acc * ds))
    return v


def elevation_at(d, s):
    e = d["elevation"]
    s %= d["lengthM"]
    for (s0, z0), (s1, z1) in zip(e, e[1:]):
        if s0 <= s <= s1:
            return z0 + (z1 - z0) * (s - s0) / max(1e-6, s1 - s0)
    return e[0][1]


GEAR_AT = [0, 62, 105, 148, 190, 232, 274]      # km/h a los que entra cada marcha


class Car:
    def __init__(self, d, rot_deg=37.0, off=(1200.0, -800.0)):
        self.d, self.n, self.ds = d, len(d["x"]), d["spacing"]
        self.L = self.n * self.ds
        self.v = speed_profile(d)
        self.s, self.speed, self.lap, self.lap_t = 0.0, self.v[0], 1, 0.0
        self.last, self.best = -1, -1
        self.a_smooth = 0.0
        th = math.radians(rot_deg)
        self.c, self.sn, self.off = math.cos(th), math.sin(th), off

    def step(self, dt):
        f = (self.s % self.L) / self.ds
        i = int(f) % self.n
        j = (i + 1) % self.n
        u = f - int(f)
        v_new = self.v[i] + (self.v[j] - self.v[i]) * u
        acc = (v_new - self.speed) / dt
        self.a_smooth += (acc - self.a_smooth) * 0.25
        self.speed = v_new
        self.s += self.speed * dt
        self.lap_t += dt
        if self.s >= self.L:
            self.s -= self.L
            self.last = int(self.lap_t * 1000)
            self.best = self.last if self.best < 0 else min(self.best, self.last)
            self.lap += 1
            self.lap_t = 0.0

    def frame(self):
        d, f = self.d, (self.s % self.L) / self.ds
        i, u = int(f) % self.n, f - int(f)
        j = (i + 1) % self.n
        X = d["x"][i] + (d["x"][j] - d["x"][i]) * u
        Y = d["y"][i] + (d["y"][j] - d["y"][i]) * u
        fx, fy = d["x"][j] - d["x"][i], d["y"][j] - d["y"][i]
        m = math.hypot(fx, fy) or 1.0
        fx, fy = fx / m, fy / m
        kmh = self.speed * 3.6
        gear = max(1, sum(1 for g in GEAR_AT if kmh >= g))
        lo = GEAR_AT[gear - 1]
        hi = GEAR_AT[gear] if gear < len(GEAR_AT) else lo + 45
        frac = max(0.0, min(1.0, (kmh - lo) / max(1.0, hi - lo)))
        a = self.a_smooth
        throttle = max(0.0, min(1.0, 0.45 + a / 8.0)) if a > -1.2 else 0.0
        brake = max(0.0, min(1.0, -a / 14.0)) if a < -1.2 else 0.0
        return dict(
            x=self.c * X - self.sn * Y + self.off[0], z=self.sn * X + self.c * Y + self.off[1],
            y=elevation_at(d, self.s), vx=(self.c * fx - self.sn * fy) * self.speed, vy=0.0,
            vz=(self.sn * fx + self.c * fy) * self.speed, speed=self.speed, gear=gear,
            rpm=3600 + 4300 * frac, throttle=throttle, brake=brake,
            lap=self.lap, last=self.last, best=self.best)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--track", default="SpaData.js", help="ruta de SpaData.js")
    ap.add_argument("--listen-port", type=int, default=33739, help="puerto del latido (como la consola)")
    ap.add_argument("--send-port", type=int, default=33740, help="puerto donde recibe la aplicación")
    ap.add_argument("--duration", type=float, default=0, help="segundos antes de salir (0 = sin límite)")
    ap.add_argument("--timeout", type=float, default=16.0, help="segundos sin latido antes de callar")
    args = ap.parse_args()

    car = Car(load_track(args.track))
    rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    rx.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    rx.bind(("0.0.0.0", args.listen_port))
    rx.setblocking(False)
    tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    print(f"Consola simulada lista: espero el latido en UDP {args.listen_port} "
          f"y enviaré a UDP {args.send_port}. Ctrl+C para salir.", flush=True)
    client, kind, last_hb, packet_id, sent = None, b"A", 0.0, 0, 0
    dt, t0 = 1 / 60, time.monotonic()
    nxt = t0
    try:
        while True:
            now = time.monotonic()
            if args.duration and now - t0 > args.duration:
                break
            try:
                while True:
                    data, addr = rx.recvfrom(64)
                    if data[:1] in TYPES:
                        if client != addr[0] or kind != data[:1]:
                            print(f"Latido '{data[:1].decode()}' de {addr[0]}:{addr[1]}: empiezo a enviar "
                                  f"paquetes de {TYPES[data[:1]][0]} bytes", flush=True)
                        client, kind, last_hb = addr[0], data[:1], now
                    else:
                        print(f"Latido desconocido {data!r} ignorado (este simulador soporta A, B y ~)", flush=True)
            except BlockingIOError:
                pass

            if now >= nxt:
                nxt += dt
                car.step(dt)
                if client and now - last_hb < args.timeout:
                    pk = build_packet(kind, car.frame(), packet_id, (0x9E3779B9 * (packet_id + 1)) & M)
                    tx.sendto(pk, (client, args.send_port))
                    packet_id += 1
                    sent += 1
                elif client:
                    print("Sin latidos: dejo de enviar (como la consola real).", flush=True)
                    client = None
            else:
                time.sleep(max(0.0, min(0.002, nxt - now)))
    except KeyboardInterrupt:
        pass
    print(f"Fin. Paquetes enviados: {sent}, vueltas completas: {car.lap - 1}", flush=True)


if __name__ == "__main__":
    sys.exit(main())
