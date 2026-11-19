#!/usr/bin/env python3
"""HTTPS launcher + scannable terminal QR code for มหาแดน gogo M on iPhone 13 mini & Desktop."""

from __future__ import annotations

import argparse
import functools
import http.server
import pathlib
import re
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time


def detect_lan_ip() -> str:
    try:
        res = subprocess.run(["ipconfig", "getifaddr", "en0"], capture_output=True, text=True, timeout=2)
        ip = res.stdout.strip()
        if ip:
            return ip
    except Exception:
        pass
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.connect(("8.8.8.8", 80))
        ip = sock.getsockname()[0]
        sock.close()
        if ip:
            return ip
    except Exception:
        pass
    return "127.0.0.1"


# --- Pure-Python ISO/IEC 18004 QR Encoder (Byte mode, ECC Level L, Versions 2, 3, 4) ---
_GF_EXP = [1] * 512
_GF_LOG = [0] * 256
_x = 1
for _i in range(1, 255):
    _x <<= 1
    if _x & 0x100:
        _x ^= 0x11D
    _GF_EXP[_i] = _x
    _GF_LOG[_x] = _i
for _i in range(255, 512):
    _GF_EXP[_i] = _GF_EXP[_i - 255]


def _gf_mul(a: int, b: int) -> int:
    return 0 if a == 0 or b == 0 else _GF_EXP[_GF_LOG[a] + _GF_LOG[b]]


def _rs_gen_poly(deg: int) -> list[int]:
    poly = [1]
    for i in range(deg):
        nxt = [0] * (len(poly) + 1)
        root = _GF_EXP[i]
        for j, coef in enumerate(poly):
            nxt[j] ^= coef
            nxt[j + 1] ^= _gf_mul(coef, root)
        poly = nxt
    return poly


def _rs_encode(data: list[int], ecc_len: int) -> list[int]:
    gen = _rs_gen_poly(ecc_len)
    buf = data + [0] * ecc_len
    for i in range(len(data)):
        factor = buf[i]
        if factor != 0:
            for j in range(1, len(gen)):
                buf[i + j] ^= _gf_mul(gen[j], factor)
    return buf[len(data):]


def encode_qr_matrix(text: str) -> list[list[bool]]:
    raw = text.encode("utf-8")
    # Version 2-L (<=32B), Version 3-L (<=53B), Version 4-L (<=78B); all single-block L with 7 remainder bits
    if len(raw) <= 32:
        ver, size, data_cap, ecc_len, align = 2, 25, 34, 10, [18]
    elif len(raw) <= 53:
        ver, size, data_cap, ecc_len, align = 3, 29, 55, 15, [22]
    elif len(raw) <= 78:
        ver, size, data_cap, ecc_len, align = 4, 33, 80, 20, [26]
    else:
        raise ValueError(f"URL too long ({len(raw)} bytes) for QR v4-L (max 78 bytes)")

    bits: list[int] = []

    def push_bits(val: int, count: int) -> None:
        for shift in range(count - 1, -1, -1):
            bits.append((val >> shift) & 1)

    push_bits(0b0100, 4)  # Byte mode
    push_bits(len(raw), 8)
    for b in raw:
        push_bits(b, 8)
    push_bits(0, min(4, data_cap * 8 - len(bits)))
    while len(bits) % 8 != 0:
        bits.append(0)
    codewords = [sum(bits[i + k] << (7 - k) for k in range(8)) for i in range(0, len(bits), 8)]
    pad_bytes = (0xEC, 0x11)
    idx = 0
    while len(codewords) < data_cap:
        codewords.append(pad_bytes[idx % 2])
        idx += 1

    stream = codewords + _rs_encode(codewords, ecc_len)
    stream_bits: list[int] = []
    for cw in stream:
        for shift in range(7, -1, -1):
            stream_bits.append((cw >> shift) & 1)
    stream_bits.extend([0] * 7)

    mat: list[list[bool | None]] = [[None] * size for _ in range(size)]
    func: list[list[bool]] = [[False] * size for _ in range(size)]

    def set_func(r: int, c: int, val: bool) -> None:
        mat[r][c] = val
        func[r][c] = True

    def place_finder(r0: int, c0: int) -> None:
        for dr in range(-1, 8):
            for dc in range(-1, 8):
                r, c = r0 + dr, c0 + dc
                if 0 <= r < size and 0 <= c < size:
                    in_outer = 0 <= dr <= 6 and 0 <= dc <= 6
                    on_border = dr in (0, 6) or dc in (0, 6)
                    in_core = 2 <= dr <= 4 and 2 <= dc <= 4
                    set_func(r, c, in_outer and (on_border or in_core))

    place_finder(0, 0)
    place_finder(0, size - 7)
    place_finder(size - 7, 0)

    for ac in align:
        for dr in range(-2, 3):
            for dc in range(-2, 3):
                val = max(abs(dr), abs(dc)) != 1
                set_func(ac + dr, ac + dc, val)

    for i in range(8, size - 8):
        val = (i % 2) == 0
        set_func(6, i, val)
        set_func(i, 6, val)

    set_func(4 * ver + 9, 8, True)  # Dark module

    for i in range(9):
        if not func[8][i]:
            set_func(8, i, False)
        if not func[i][8]:
            set_func(i, 8, False)
    for i in range(8):
        set_func(8, size - 1 - i, False)
        set_func(size - 1 - i, 8, False)

    bi = 0
    col = size - 1
    upward = True
    while col > 0:
        if col == 6:
            col -= 1
        rows = range(size - 1, -1, -1) if upward else range(size)
        for r in rows:
            for dc in (0, -1):
                c = col + dc
                if not func[r][c]:
                    mat[r][c] = bool(stream_bits[bi]) if bi < len(stream_bits) else False
                    bi += 1
        upward = not upward
        col -= 2

    def mask_fn(mask_id: int, r: int, c: int) -> bool:
        if mask_id == 0:
            return (r + c) % 2 == 0
        if mask_id == 1:
            return r % 2 == 0
        if mask_id == 2:
            return c % 3 == 0
        if mask_id == 3:
            return (r + c) % 3 == 0
        if mask_id == 4:
            return (r // 2 + c // 3) % 2 == 0
        if mask_id == 5:
            return (r * c) % 2 + (r * c) % 3 == 0
        if mask_id == 6:
            return ((r * c) % 2 + (r * c) % 3) % 2 == 0
        return ((r + c) % 2 + (r * c) % 3) % 2 == 0

    def apply_format(grid: list[list[bool]], mask_id: int) -> None:
        fmt_data = (0b01 << 3) | mask_id
        rem = fmt_data << 10
        for shift in range(4, -1, -1):
            if rem & (1 << (shift + 10)):
                rem ^= 0x537 << shift
        fmt = ((fmt_data << 10) | rem) ^ 0x5412
        for i in range(6):
            grid[8][i] = bool((fmt >> i) & 1)
            grid[size - 1 - i][8] = bool((fmt >> i) & 1)
        grid[8][7] = bool((fmt >> 6) & 1)
        grid[size - 7][8] = bool((fmt >> 6) & 1)
        grid[8][8] = bool((fmt >> 7) & 1)
        grid[8][size - 8] = bool((fmt >> 7) & 1)
        grid[7][8] = bool((fmt >> 8) & 1)
        grid[8][size - 7] = bool((fmt >> 8) & 1)
        for i in range(9, 15):
            bit = bool((fmt >> i) & 1)
            grid[14 - i][8] = bit
            grid[8][size - 15 + i] = bit

    def penalty(grid: list[list[bool]]) -> int:
        score = 0
        for r in range(size):
            run = 1
            for c in range(1, size):
                if grid[r][c] == grid[r][c - 1]:
                    run += 1
                    score += 3 if run == 5 else (1 if run > 5 else 0)
                else:
                    run = 1
        for c in range(size):
            run = 1
            for r in range(1, size):
                if grid[r][c] == grid[r - 1][c]:
                    run += 1
                    score += 3 if run == 5 else (1 if run > 5 else 0)
                else:
                    run = 1
        return score

    best_grid: list[list[bool]] | None = None
    best_score = 10**9
    for mid in range(8):
        cand = [
            [bool(mat[r][c]) ^ (mask_fn(mid, r, c) if not func[r][c] else False) for c in range(size)]
            for r in range(size)
        ]
        apply_format(cand, mid)
        sc = penalty(cand)
        if sc < best_score:
            best_score = sc
            best_grid = cand
    assert best_grid is not None
    return best_grid


def render_qr_terminal(matrix: list[list[bool]], quiet: int = 2) -> str:
    size = len(matrix)
    padded: list[list[bool]] = []
    empty_row = [False] * (size + quiet * 2)
    for _ in range(quiet):
        padded.append(empty_row)
    for row in matrix:
        padded.append([False] * quiet + row + [False] * quiet)
    for _ in range(quiet):
        padded.append(empty_row)

    lines: list[str] = []
    for r in range(0, len(padded), 2):
        top = padded[r]
        bot = padded[r + 1] if r + 1 < len(padded) else empty_row
        chars = []
        for t_dark, b_dark in zip(top, bot):
            t_light = not t_dark
            b_light = not b_dark
            if t_light and b_light:
                chars.append("█")
            elif t_light:
                chars.append("▀")
            elif b_light:
                chars.append("▄")
            else:
                chars.append(" ")
        lines.append("".join(chars))
    return "\n".join(lines)


class _QuietHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def _ensure_self_signed_cert(lan_ip: str) -> tuple[pathlib.Path, pathlib.Path]:
    cert_path = pathlib.Path(tempfile.gettempdir()) / "maha_dan_gogo_m_cert.pem"
    key_path = pathlib.Path(tempfile.gettempdir()) / "maha_dan_gogo_m_key.pem"
    subprocess.run(
        [
            "/usr/bin/openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-days",
            "30",
            "-keyout",
            str(key_path),
            "-out",
            str(cert_path),
            "-subj",
            f"/CN={lan_ip}",
            "-addext",
            f"subjectAltName=IP:{lan_ip},DNS:localhost,IP:127.0.0.1",
        ],
        check=True,
        capture_output=True,
    )
    return cert_path, key_path


def _print_banner(primary_url: str, extra_lines: list[str], web_dir: pathlib.Path) -> None:
    print("=" * 60, flush=True)
    print("📱 มหาแดน gogo M — Secure Context HTTPS Server", flush=True)
    print(f"🔗 iPhone / Browser HTTPS URL : {primary_url}", flush=True)
    for line in extra_lines:
        print(line, flush=True)
    print(f"📂 Serving                    : {web_dir}", flush=True)
    print("=" * 60, flush=True)
    print(render_qr_terminal(encode_qr_matrix(primary_url)), flush=True)
    print("\nวิธีเปิดเล่นบน iPhone 13 mini:", flush=True)
    print(f"1) สแกน QR ด้านบน หรือเปิด {primary_url} ใน Safari", flush=True)
    print("2) กด แชร์ -> เพิ่มไปยังหน้าจอโฮม (Add to Home Screen)", flush=True)


def _run_cloudflared_tunnel(port: int, web_dir: pathlib.Path) -> int:
    cloudflared = shutil.which("cloudflared")
    if not cloudflared:
        return -1

    handler = functools.partial(_QuietHandler, directory=str(web_dir))
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    srv_thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    srv_thread.start()

    proc = subprocess.Popen(
        [cloudflared, "tunnel", "--no-autoupdate", "--url", f"http://127.0.0.1:{port}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    tunnel_url_box: list[str] = []
    ready_evt = threading.Event()
    url_re = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")

    def _drain_logs() -> None:
        assert proc.stdout is not None
        for line in proc.stdout:
            m = url_re.search(line)
            if m and not tunnel_url_box:
                tunnel_url_box.append(m.group(0))
                ready_evt.set()

    drain_thread = threading.Thread(target=_drain_logs, daemon=True)
    drain_thread.start()

    try:
        if not ready_evt.wait(timeout=15.0) or not tunnel_url_box:
            proc.terminate()
            httpd.shutdown()
            httpd.server_close()
            return -1

        public_url = tunnel_url_box[0]
        _print_banner(
            public_url,
            [
                f"💻 Local Mac Chrome URL       : http://localhost:{port}",
                "🔒 SSL Certificate            : Trusted Cloudflare HTTPS (Zero Browser Warnings)",
            ],
            web_dir,
        )
        print(f"\n🟢 Tunnel active -> {public_url} (Ctrl+C to stop)", flush=True)

        stop_evt = threading.Event()

        def _handle_sig(_signum, _frame) -> None:
            stop_evt.set()

        signal.signal(signal.SIGINT, _handle_sig)
        signal.signal(signal.SIGTERM, _handle_sig)
        while not stop_evt.is_set():
            if proc.poll() is not None:
                print("⚠️ Cloudflare tunnel exited unexpectedly.", file=sys.stderr, flush=True)
                return 1
            time.sleep(0.5)
        return 0
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        httpd.shutdown()
        httpd.server_close()


def _run_self_signed_https(port: int, lan_ip: str, web_dir: pathlib.Path) -> int:
    cert_path, key_path = _ensure_self_signed_cert(lan_ip)
    handler = functools.partial(_QuietHandler, directory=str(web_dir))
    httpd = http.server.ThreadingHTTPServer(("0.0.0.0", port), handler)
    ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ssl_ctx.load_cert_chain(certfile=str(cert_path), keyfile=str(key_path))
    httpd.socket = ssl_ctx.wrap_socket(httpd.socket, server_side=True)

    lan_url = f"https://{lan_ip}:{port}"
    _print_banner(
        lan_url,
        [
            f"💻 Local Mac URL              : https://localhost:{port}",
            "⚠️ Self-Signed Cert (ออฟไลน์): เปิดครั้งแรกกด แสดงรายละเอียด -> เยี่ยมชมเว็บไซต์นี้",
        ],
        web_dir,
    )
    print(f"\n🟢 Offline LAN HTTPS listening on https://0.0.0.0:{port} (Ctrl+C to stop)", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped.", flush=True)
    finally:
        httpd.shutdown()
        httpd.server_close()
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve มหาแดน gogo M over Secure Context HTTPS + QR.")
    parser.add_argument("--port", type=int, default=8088)
    parser.add_argument("--mode", choices=("tunnel", "https"), default="tunnel")
    parser.add_argument("--print-only", action="store_true", help="Print sample QR code and exit.")
    args = parser.parse_args()

    root_dir = pathlib.Path(__file__).resolve().parent.parent
    web_dir = root_dir / "build" / "web"
    lan_ip = detect_lan_ip()

    if args.print_only:
        sample_url = "https://maha-dan-gogo-m-preview-check.trycloudflare.com" if args.mode == "tunnel" else f"https://{lan_ip}:{args.port}"
        _print_banner(sample_url, [f"💻 Local Mac URL              : http://localhost:{args.port}"], web_dir)
        return

    if not (web_dir / "index.html").exists():
        raise SystemExit(f"❌ Missing {web_dir / 'index.html'} — run ./tools/export_web.sh first.")

    if args.mode == "tunnel":
        rc = _run_cloudflared_tunnel(args.port, web_dir)
        if rc == 0:
            return
        print("⚠️ Falling back to offline self-signed LAN HTTPS (--mode https)...", flush=True)

    raise SystemExit(_run_self_signed_https(args.port, lan_ip, web_dir))


if __name__ == "__main__":
    main()
