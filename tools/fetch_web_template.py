#!/usr/bin/env python3
"""Fetch only Godot 4.7.2 single-thread Web export templates via HTTP Range requests."""

import os
import struct
import sys
import urllib.request
import zipfile
import zlib

TPZ_URL = (
    "https://github.com/godotengine/godot/releases/download/"
    "4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
)
TARGET_DIR = os.path.expanduser(
    "~/Library/Application Support/Godot/export_templates/4.7.2.stable"
)
WANTED = {
    "templates/web_nothreads_release.zip": "web_nothreads_release.zip",
    "templates/web_nothreads_debug.zip": "web_nothreads_debug.zip",
}


def http_range(url: str, start: int, end: int) -> tuple[bytes, int]:
    req = urllib.request.Request(
        url,
        headers={
            "Range": f"bytes={start}-{end}",
            "User-Agent": "Mozilla/5.0 (compatible; GodotTemplateFetcher/1.0)",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = resp.read()
        cr = resp.headers.get("Content-Range", "")
        total = int(cr.split("/")[-1]) if "/" in cr else len(data)
        return data, total


def get_remote_size(url: str) -> tuple[str, int]:
    req = urllib.request.Request(
        url,
        headers={
            "Range": "bytes=0-0",
            "User-Agent": "Mozilla/5.0 (compatible; GodotTemplateFetcher/1.0)",
        },
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        final_url = resp.geturl()
        cr = resp.headers.get("Content-Range", "")
        if "/" in cr:
            return final_url, int(cr.split("/")[-1])
        cl = resp.headers.get("Content-Length")
        if cl:
            return final_url, int(cl)
        raise RuntimeError("Server did not return Content-Range or Content-Length")


def parse_central_directory(final_url: str, total_size: int) -> dict[str, dict]:
    tail_size = min(65536 + 22, total_size)
    tail_start = total_size - tail_size
    tail, _ = http_range(final_url, tail_start, total_size - 1)

    eocd_idx = tail.rfind(b"PK\x05\x06")
    if eocd_idx == -1:
        raise RuntimeError("ZIP End-of-Central-Directory not found")

    disk, cd_disk, entries_disk, total_entries, cd_size, cd_offset, comment_len = (
        struct.unpack("<HHHHIIH", tail[eocd_idx + 4 : eocd_idx + 22])
    )

    # ZIP64 fallback if any 32-bit field is maxed out
    if cd_offset == 0xFFFFFFFF or cd_size == 0xFFFFFFFF or total_entries == 0xFFFF:
        loc_idx = tail.rfind(b"PK\x06\x07", 0, eocd_idx)
        if loc_idx == -1:
            raise RuntimeError("ZIP64 EOCD locator needed but not found")
        _, z64_offset, _ = struct.unpack("<IQI", tail[loc_idx + 4 : loc_idx + 20])
        z64_hdr, _ = http_range(final_url, z64_offset, z64_offset + 55)
        if z64_hdr[:4] != b"PK\x06\x06":
            raise RuntimeError("Invalid ZIP64 EOCD signature")
        cd_size, cd_offset = struct.unpack("<QQ", z64_hdr[40:56])

    cd_bytes, _ = http_range(final_url, cd_offset, cd_offset + cd_size - 1)
    entries: dict[str, dict] = {}
    pos = 0
    while pos + 46 <= len(cd_bytes):
        if cd_bytes[pos : pos + 4] != b"PK\x01\x02":
            break
        (
            _ver_made,
            _ver_need,
            _flags,
            method,
            _mtime,
            _mdate,
            crc32,
            comp_size,
            uncomp_size,
            fname_len,
            extra_len,
            comment_l,
            _disk_start,
            _int_attr,
            _ext_attr,
            local_off,
        ) = struct.unpack("<HHHHHHIIIHHHHHII", cd_bytes[pos + 4 : pos + 46])
        name_start = pos + 46
        fname = cd_bytes[name_start : name_start + fname_len].decode("utf-8", "replace")
        extra = cd_bytes[name_start + fname_len : name_start + fname_len + extra_len]

        # Parse ZIP64 extra field if needed
        ep = 0
        while ep + 4 <= len(extra):
            eid, esize = struct.unpack("<HH", extra[ep : ep + 4])
            edata = extra[ep + 4 : ep + 4 + esize]
            if eid == 0x0001:
                idx = 0
                if uncomp_size == 0xFFFFFFFF and idx + 8 <= len(edata):
                    uncomp_size = struct.unpack("<Q", edata[idx : idx + 8])[0]
                    idx += 8
                if comp_size == 0xFFFFFFFF and idx + 8 <= len(edata):
                    comp_size = struct.unpack("<Q", edata[idx : idx + 8])[0]
                    idx += 8
                if local_off == 0xFFFFFFFF and idx + 8 <= len(edata):
                    local_off = struct.unpack("<Q", edata[idx : idx + 8])[0]
                    idx += 8
            ep += 4 + esize

        entries[fname] = {
            "method": method,
            "crc32": crc32,
            "comp_size": comp_size,
            "uncomp_size": uncomp_size,
            "local_off": local_off,
        }
        pos = name_start + fname_len + extra_len + comment_l

    return entries


def extract_entry(final_url: str, info: dict, out_path: str) -> None:
    local_off = info["local_off"]
    comp_size = info["comp_size"]
    # Fetch local header + compressed payload (+ margin for filename/extra)
    buf, _ = http_range(final_url, local_off, local_off + 30 + 1024 + comp_size)
    if buf[:4] != b"PK\x03\x04":
        raise RuntimeError(f"Invalid local file header at offset {local_off}")
    fn_len, ex_len = struct.unpack("<HH", buf[26:30])
    data_start = 30 + fn_len + ex_len
    if len(buf) < data_start + comp_size:
        missing_start = local_off + len(buf)
        missing_end = local_off + data_start + comp_size - 1
        more, _ = http_range(final_url, missing_start, missing_end)
        buf += more
    payload = buf[data_start : data_start + comp_size]

    method = info["method"]
    if method == 0:
        raw = payload
    elif method == 8:
        raw = zlib.decompress(payload, -zlib.MAX_WBITS)
    else:
        raise RuntimeError(f"Unsupported ZIP compression method: {method}")

    if (zlib.crc32(raw) & 0xFFFFFFFF) != info["crc32"]:
        raise RuntimeError(f"CRC32 mismatch for {out_path}")

    tmp_path = out_path + ".tmp"
    with open(tmp_path, "wb") as f:
        f.write(raw)
    os.replace(tmp_path, out_path)


def main() -> int:
    os.makedirs(TARGET_DIR, exist_ok=True)
    missing = {
        k: v
        for k, v in WANTED.items()
        if not os.path.exists(os.path.join(TARGET_DIR, v))
    }
    if not missing:
        print("All single-thread Web export templates already present.")
        return 0

    print(f"Resolving {TPZ_URL} ...")
    final_url, total_size = get_remote_size(TPZ_URL)
    print(f"Archive size: {total_size / (1024 * 1024):.1f} MiB. Reading ZIP directory...")
    entries = parse_central_directory(final_url, total_size)

    for zip_key, out_name in missing.items():
        if zip_key not in entries:
            web_keys = sorted(k for k in entries if "web" in k.lower())
            print(f"ERROR: '{zip_key}' not found in archive. Web entries: {web_keys}", file=sys.stderr)
            return 1
        info = entries[zip_key]
        out_path = os.path.join(TARGET_DIR, out_name)
        print(
            f"Downloading {zip_key} ({info['comp_size'] / (1024 * 1024):.1f} MiB compressed) -> {out_path}"
        )
        extract_entry(final_url, info, out_path)
        with zipfile.ZipFile(out_path, "r") as zf:
            bad = zf.testzip()
            if bad is not None:
                raise RuntimeError(f"Corrupt ZIP entry {bad} in {out_path}")
        print(f"Verified OK: {out_path} ({os.path.getsize(out_path) / (1024 * 1024):.1f} MiB)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
