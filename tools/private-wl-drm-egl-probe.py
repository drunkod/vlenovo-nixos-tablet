#!/usr/bin/env python3
"""Start a disposable Wayland EGL/wl_drm test socket WITHOUT a display output.

No KMS, no seat, no VT, no system services, no privileged operations.
Uses the render node and Mesa EGL_WL_bind_wayland_display extension directly.
Useful for testing client EGL renderer selection independently of Flick.
"""
from __future__ import annotations
import argparse
import ctypes as C
import os
from pathlib import Path
import signal
import time

cvoid = C.c_void_p
cint = C.c_int
cuint = C.c_uint

def function(lib, name, restype, argtypes):
    f = getattr(lib,name)
    f.restype=restype
    f.argtypes=argtypes
    return f

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--egl-lib",required=True)
    p.add_argument("--gbm-lib",required=True)
    p.add_argument("--wayland-lib",required=True)
    p.add_argument("--runtime",required=True)
    p.add_argument("--socket",default="private-egl-probe")
    p.add_argument("--seconds",type=int,default=30)
    p.add_argument("--bind",action="store_true")
    args=p.parse_args()
    if args.seconds>90 or args.seconds<3:
        p.error("--seconds must be 3..90")
    root=Path(args.runtime).resolve()
    home=Path("/run/user")/str(os.getuid())
    if not root.is_relative_to(home) or root==home:
        p.error("runtime must be a private subdirectory of /run/user/<current-uid>")
    if root.exists():
        p.error("refusing to reuse an existing runtime directory")
    root.mkdir(mode=0o700)
    os.environ["XDG_RUNTIME_DIR"]=str(root)
    os.environ.setdefault("EGL_PLATFORM","gbm")
    server=None
    gbmdev=None
    egl_display=None
    render_fd=None
    try:
        w=C.CDLL(args.wayland_lib)
        gbm=C.CDLL(args.gbm_lib)
        egl=C.CDLL(args.egl_lib)
        wl_display_create=function(w,"wl_display_create",cvoid,[])
        wl_display_add_socket=function(w,"wl_display_add_socket",cint,[cvoid,C.c_char_p])
        wl_display_get_event_loop=function(w,"wl_display_get_event_loop",cvoid,[cvoid])
        wl_event_loop_dispatch=function(w,"wl_event_loop_dispatch",cint,[cvoid,cint])
        wl_display_flush_clients=function(w,"wl_display_flush_clients",None,[cvoid])
        wl_display_destroy=function(w,"wl_display_destroy",None,[cvoid])
        gbm_create_device=function(gbm,"gbm_create_device",cvoid,[cint])
        gbm_device_destroy=function(gbm,"gbm_device_destroy",None,[cvoid])
        get_proc=function(egl,"eglGetProcAddress",cvoid,[C.c_char_p])
        egl_initialize=function(egl,"eglInitialize",cuint,[cvoid,C.POINTER(cint),C.POINTER(cint)])
        egl_terminate=function(egl,"eglTerminate",cuint,[cvoid])
        render_fd=os.open("/dev/dri/renderD128",os.O_RDWR|os.O_CLOEXEC)
        gbmdev=gbm_create_device(render_fd)
        if not gbmdev:
            raise RuntimeError("gbm_create_device returned NULL")
        address=get_proc(b"eglGetPlatformDisplayEXT")
        if not address:
            raise RuntimeError("eglGetPlatformDisplayEXT unavailable")
        egl_get_platform=C.CFUNCTYPE(cvoid,cuint,cvoid,cvoid)(address)
        egl_display=egl_get_platform(0x31D7,gbmdev,None) # EGL_PLATFORM_GBM_KHR
        if not egl_display:
            raise RuntimeError("eglGetPlatformDisplayEXT returned NULL")
        major,minor=cint(),cint()
        if egl_initialize(egl_display,C.byref(major),C.byref(minor))!=1:
            raise RuntimeError("eglInitialize returned false")
        server=wl_display_create()
        if not server:
            raise RuntimeError("wl_display_create returned NULL")
        if args.bind:
            address=get_proc(b"eglBindWaylandDisplayWL")
            if not address:
                raise RuntimeError("eglBindWaylandDisplayWL unavailable")
            bind=C.CFUNCTYPE(cuint,cvoid,cvoid)(address)
            if bind(egl_display,server)!=1:
                raise RuntimeError("eglBindWaylandDisplayWL returned false")
        if wl_display_add_socket(server,args.socket.encode())!=0:
            raise RuntimeError("wl_display_add_socket failed")
        print(f"EGL_VERSION={major.value}.{minor.value}",flush=True)
        print(f"BOUND_WL_DRM={args.bind}",flush=True)
        print(f"PRIVATE_SOCKET={root/args.socket}",flush=True)
        loop=wl_display_get_event_loop(server)
        if not loop:
            raise RuntimeError("no Wayland event loop")
        live=True
        def stop(_signum,_frame):
            nonlocal live
            live=False
        signal.signal(signal.SIGTERM,stop)
        signal.signal(signal.SIGINT,stop)
        end=time.monotonic()+args.seconds
        while time.monotonic()<end and live:
            if wl_event_loop_dispatch(loop,100)<0:
                raise RuntimeError("Wayland event loop dispatch failed")
            wl_display_flush_clients(server)
        print("PRIVATE_SERVER_EXIT=OK",flush=True)
    finally:
        # The private compositor has no clients or outputs after probe.
        if server:
            wl_display_destroy(server)
        if egl_display:
            egl_terminate(egl_display)
        if gbmdev:
            gbm_device_destroy(gbmdev)
        if render_fd is not None:
            os.close(render_fd)
        socket=root/args.socket
        if socket.exists() or socket.is_symlink():
            socket.unlink()
        lock=root/(args.socket+".lock")
        if lock.exists():
            lock.unlink()
        try:root.rmdir()
        except OSError:pass

if __name__=="__main__":
    main()
