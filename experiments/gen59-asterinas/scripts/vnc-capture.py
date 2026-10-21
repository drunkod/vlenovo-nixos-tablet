#!/usr/bin/env python3
"""Capture ONLY the localhost QEMU VNC framebuffer. No desktop screenshots."""
import argparse
import binascii
import socket
import struct
import time
import zlib
from pathlib import Path


def recv_exact(s, count):
    data = bytearray()
    while len(data) < count:
        chunk = s.recv(count - len(data))
        if not chunk:
            raise EOFError("VNC server disconnected")
        data.extend(chunk)
    return bytes(data)


def chunk(typ, data):
    return struct.pack(">I", len(data)) + typ + data + struct.pack(
        ">I", binascii.crc32(typ + data) & 0xFFFFFFFF
    )


def png(rgb, width, height):
    stride = width * 3
    raw = b"".join(b"\x00" + rgb[y * stride:(y + 1) * stride] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 6))
            + chunk(b"IEND", b""))


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--port", type=int, default=5927)
    a.add_argument("--output", default="/tmp/asterinas-gen59-vnc.png")
    a.add_argument("--key", choices=["Enter", "Escape", "t", "Down", "Up"])
    a.add_argument("--type", help="Send ASCII characters to the QEMU guest before capture")
    a.add_argument("--wait", type=float, default=2, help="Seconds between keys and capture")
    args = a.parse_args()
    with socket.create_connection(("127.0.0.1", args.port), timeout=10) as s:
        s.settimeout(30)
        v = recv_exact(s, 12)
        if not v.startswith(b"RFB 003."):
            raise ValueError(f"Unexpected RFB version {v!r}")
        s.sendall(b"RFB 003.008\n")
        n = recv_exact(s, 1)[0]
        if n == 0:
            raise RuntimeError(recv_exact(s, 4))
        choices = recv_exact(s, n)
        if 1 not in choices:
            raise RuntimeError(f"Unauthenticated VNC unavailable: {choices!r}")
        s.sendall(b"\x01")
        if struct.unpack(">I", recv_exact(s, 4))[0] != 0:
            raise RuntimeError("VNC security handshake rejected")
        s.sendall(b"\x01")
        init = recv_exact(s, 24)
        width, height = struct.unpack(">HH", init[:4])
        name_len = struct.unpack(">I", init[20:24])[0]
        if name_len > 4096:
            raise RuntimeError("Unexpected long VNC server name")
        name = recv_exact(s, name_len).decode("utf-8", "replace")
        fmt = struct.pack(">BBBBHHHBBBxxx", 32, 24, 0, 1, 255, 255, 255, 16, 8, 0)
        s.sendall(b"\x00\x00\x00\x00" + fmt)
        s.sendall(b"\x02\x00\x00\x01\x00\x00\x00\x00")
        if args.key:
            code = {"Enter":0xFF0D,"Escape":0xFF1B,"t":ord("t"),
                    "Down":0xFF54,"Up":0xFF52}[args.key]
            s.sendall(struct.pack(">BBHI", 4, 1, 0, code))
            s.sendall(struct.pack(">BBHI", 4, 0, 0, code))
            time.sleep(1)
        if args.type:
            for char in args.type:
                code = 0xFF0D if ord(char) == 10 else ord(char)
                # QEMU VNC's keymap needs an explicit Shift event for ':'
                # (otherwise the UEFI shell receives ';').
                shifted = char == ":" or char.isupper()
                if shifted:
                    s.sendall(struct.pack(">BBHI", 4, 1, 0, 0xFFE1))
                s.sendall(struct.pack(">BBHI", 4, 1, 0, code))
                s.sendall(struct.pack(">BBHI", 4, 0, 0, code))
                if shifted:
                    s.sendall(struct.pack(">BBHI", 4, 0, 0, 0xFFE1))
                time.sleep(0.025)
            time.sleep(args.wait)
        s.sendall(struct.pack(">BBHHHH", 3, 0, 0, 0, width, height))
        typ = recv_exact(s, 1)[0]
        if typ != 0:
            raise RuntimeError(f"Expected framebuffer-update type 0, got {typ}")
        nrect = struct.unpack(">H", recv_exact(s, 3)[1:])[0]
        framebuffer = bytearray(width * height * 4)
        for _ in range(nrect):
            x,y,w,h,encoding = struct.unpack(">HHHHi", recv_exact(s, 12))
            if encoding != 0:
                raise RuntimeError(f"Unexpected non-RAW encoding {encoding}")
            data = recv_exact(s, w*h*4)
            for row in range(h):
                dst = ((y+row)*width+x)*4
                framebuffer[dst:dst+w*4] = data[row*w*4:(row+1)*w*4]
        rgb = bytearray(width*height*3)
        for j in range(width*height):
            b,g,r,_ = framebuffer[j*4:j*4+4]
            rgb[j*3:j*3+3] = bytes((r,g,b))
        Path(args.output).write_bytes(png(rgb, width, height))
        print(f"QEMU_VNC_CAPTURE_OK width={width} height={height} "
              f"name={name!r} output={args.output}")


if __name__ == "__main__":
    main()
