#!/usr/bin/env python3
"""Rootless Intel render-node OpenGL ES2/FBO draw-and-readback test.

No DRM/KMS master, no VT, no compositor, no Wayland socket, no modeset.
Only renders a tiny 64x64 offscreen texture on /dev/dri/renderD128.
"""
from __future__ import annotations
import ctypes as C
import os
import sys
import time

EGL_NONE=0x3038
EGL_PLATFORM_GBM_MESA=0x31D7
EGL_SURFACE_TYPE=0x3033
EGL_PBUFFER_BIT=0x0001
EGL_RENDERABLE_TYPE=0x3040
EGL_OPENGL_ES2_BIT=0x0004
EGL_RED_SIZE=0x3024
EGL_GREEN_SIZE=0x3023
EGL_BLUE_SIZE=0x3022
EGL_ALPHA_SIZE=0x3021
EGL_WIDTH=0x3057
EGL_HEIGHT=0x3056
EGL_CONTEXT_CLIENT_VERSION=0x3098
EGL_OPENGL_ES_API=0x30A0
EGL_EXTENSIONS=0x3055
GL_RENDERER=0x1F01
GL_VENDOR=0x1F00
GL_VERSION=0x1F02
GL_TEXTURE_2D=0x0DE1
GL_RGBA=0x1908
GL_UNSIGNED_BYTE=0x1401
GL_FRAMEBUFFER=0x8D40
GL_COLOR_ATTACHMENT0=0x8CE0
GL_FRAMEBUFFER_COMPLETE=0x8CD5
GL_COLOR_BUFFER_BIT=0x4000
DRM_RENDER="/dev/dri/renderD128"

def fn(lib,name,restype,argtypes):
    f=getattr(lib,name);f.restype=restype;f.argtypes=argtypes;return f
void=C.c_void_p
uint=C.c_uint
integer=C.c_int
libgbm=C.CDLL("/nix/store/wilz94hzz4q3fss6qvv625zvww4a6s4s-mesa-libgbm-25.0.1/lib/libgbm.so.1")
libegl=C.CDLL("/nix/store/7227amwg7k4sbl6mhglq17v5x5ki54ks-libglvnd-1.7.0/lib/libEGL.so.1")
libgles=C.CDLL("/nix/store/7227amwg7k4sbl6mhglq17v5x5ki54ks-libglvnd-1.7.0/lib/libGLESv2.so.2")
gbm_create=fn(libgbm,"gbm_create_device",void,[integer])
gbm_destroy=fn(libgbm,"gbm_device_destroy",None,[void])
getproc=fn(libegl,"eglGetProcAddress",void,[C.c_char_p])
eglinit=fn(libegl,"eglInitialize",uint,[void,C.POINTER(integer),C.POINTER(integer)])
eglerr=fn(libegl,"eglGetError",uint,[])
eglbindapi=fn(libegl,"eglBindAPI",uint,[uint])
eglchoose=fn(libegl,"eglChooseConfig",uint,[void,C.POINTER(integer),C.POINTER(void),integer,C.POINTER(integer)])
eglcontext=fn(libegl,"eglCreateContext",void,[void,void,void,C.POINTER(integer)])
eglpbuffer=fn(libegl,"eglCreatePbufferSurface",void,[void,void,C.POINTER(integer)])
eglmake=fn(libegl,"eglMakeCurrent",uint,[void,void,void,void])
egldestroycontext=fn(libegl,"eglDestroyContext",uint,[void,void])
egldestroysurface=fn(libegl,"eglDestroySurface",uint,[void,void])
eglterminate=fn(libegl,"eglTerminate",uint,[void])
eglquery=fn(libegl,"eglQueryString",C.c_char_p,[void,integer])
glstring=fn(libgles,"glGetString",C.c_char_p,[uint])
glgentextures=fn(libgles,"glGenTextures",None,[integer,C.POINTER(uint)])
glbindtexture=fn(libgles,"glBindTexture",None,[uint,uint])
glteximage=fn(libgles,"glTexImage2D",None,[uint,integer,integer,integer,integer,integer,uint,uint,void])
glgenframebuffers=fn(libgles,"glGenFramebuffers",None,[integer,C.POINTER(uint)])
glbindframebuffer=fn(libgles,"glBindFramebuffer",None,[uint,uint])
glframebuffertexture=fn(libgles,"glFramebufferTexture2D",None,[uint,uint,uint,uint,integer])
glcheckframebuffer=fn(libgles,"glCheckFramebufferStatus",uint,[uint])
glclearcolor=fn(libgles,"glClearColor",None,[C.c_float]*4)
glclear=fn(libgles,"glClear",None,[uint])
glreadpixels=fn(libgles,"glReadPixels",None,[integer,integer,integer,integer,uint,uint,void])
glfinish=fn(libgles,"glFinish",None,[])
glgeterror=fn(libgles,"glGetError",uint,[])
gldelframebuffers=fn(libgles,"glDeleteFramebuffers",None,[integer,C.POINTER(uint)])
gldeltextures=fn(libgles,"glDeleteTextures",None,[integer,C.POINTER(uint)])

def success(value,description):
    if not value:raise RuntimeError(f"{description} failed: EGL 0x{eglerr():04x}")

def main():
    print("test=ROOTLESS_DRM_RENDER_NODE_ES2_OFFSCREEN")
    print("target=/dev/dri/renderD128")
    print("dimensions=64x64")
    fd=os.open(DRM_RENDER,os.O_RDWR | os.O_CLOEXEC)
    gbm=None
    display=None
    surface=None
    context=None
    tex=uint(0)
    fbo=uint(0)
    try:
        gbm=gbm_create(fd)
        if not gbm:raise RuntimeError("GBM device could not open render node")
        ptr=getproc(b"eglGetPlatformDisplayEXT")
        if not ptr:raise RuntimeError("eglGetPlatformDisplayEXT is unavailable")
        getplatform=C.CFUNCTYPE(void,uint,void,C.POINTER(integer))(ptr)
        display=getplatform(EGL_PLATFORM_GBM_MESA,gbm,None)
        if not display:raise RuntimeError("No EGLDisplay for this GBM device")
        major=integer();minor=integer()
        success(eglinit(display,C.byref(major),C.byref(minor)),"eglInitialize")
        success(eglbindapi(EGL_OPENGL_ES_API),"eglBindAPI")
        # Mesa GBM may advertise EGL_WINDOW_BIT but no EGL_PBUFFER_BIT.
        # Render exclusively into a dedicated GLES framebuffer, so avoid
        # requiring a pbuffer-capable EGLConfig.
        attrs=(integer*11)(
            EGL_RENDERABLE_TYPE,EGL_OPENGL_ES2_BIT,
            EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,
            EGL_ALPHA_SIZE,8,EGL_NONE)
        config=void()
        count=integer()
        success(eglchoose(display,attrs,C.byref(config),1,C.byref(count)),"eglChooseConfig")
        if count.value!=1:raise RuntimeError("No GLES2 RGBA8 configuration")
        context_attrs=(integer*3)(EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE)
        context=eglcontext(display,config,None,context_attrs)
        success(context,"eglCreateContext")
        pbuffer_attrs=(integer*5)(EGL_WIDTH,64,EGL_HEIGHT,64,EGL_NONE)
        surface=eglpbuffer(display,config,pbuffer_attrs)
        if surface:
            success(eglmake(display,surface,surface,context),"eglMakeCurrent pbuffer")
            print("context_mode=pbuffer")
        else:
            extensions=(eglquery(display,EGL_EXTENSIONS) or b"").decode(errors="replace")
            if "EGL_KHR_surfaceless_context" not in extensions:
                raise RuntimeError("Neither pbuffer nor surfaceless EGL supported")
            success(eglmake(display,None,None,context),"eglMakeCurrent surfaceless")
            print("context_mode=surfaceless")
        vendor=(glstring(GL_VENDOR) or b"").decode(errors="replace")
        renderer=(glstring(GL_RENDERER) or b"").decode(errors="replace")
        version=(glstring(GL_VERSION) or b"").decode(errors="replace")
        print(f"EGL_VERSION={major.value}.{minor.value}")
        print(f"GL_VENDOR={vendor}")
        print(f"GL_RENDERER={renderer}")
        print(f"GL_VERSION={version}")
        if "Intel" not in renderer or "llvmpipe" in renderer.lower():
            raise RuntimeError("Hardware Intel rendering NOT confirmed")
        glgentextures(1,C.byref(tex))
        if not tex.value:raise RuntimeError("No GLES texture allocated")
        glbindtexture(GL_TEXTURE_2D,tex)
        glteximage(GL_TEXTURE_2D,0,GL_RGBA,64,64,0,GL_RGBA,GL_UNSIGNED_BYTE,None)
        glgenframebuffers(1,C.byref(fbo))
        if not fbo.value:raise RuntimeError("No GLES framebuffer allocated")
        glbindframebuffer(GL_FRAMEBUFFER,fbo)
        glframebuffertexture(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,tex,0)
        status=glcheckframebuffer(GL_FRAMEBUFFER)
        if status!=GL_FRAMEBUFFER_COMPLETE:
            raise RuntimeError(f"Offscreen framebuffer incomplete: 0x{status:04x}")
        start=time.perf_counter()
        colors=[(1.0,0.0,1.0,1.0),(0.0,1.0,0.0,1.0)]
        for i in range(8):
            color=colors[i%2]
            glclearcolor(*color)
            glclear(GL_COLOR_BUFFER_BIT)
            glfinish()
            pixel=(C.c_ubyte*4)()
            glreadpixels(4,4,1,1,GL_RGBA,GL_UNSIGNED_BYTE,C.byref(pixel))
            error=glgeterror()
            if error!=0:
                raise RuntimeError(f"GLES error after draw+readback 0x{error:04x}")
            expected=(255,0,255,255) if i%2==0 else (0,255,0,255)
            if any(abs(int(got)-wanted)>1 for got,wanted in zip(pixel,expected)):
                raise RuntimeError(f"Hardware rendered pixels disagree: {tuple(pixel)} vs {expected}")
        print("FRAMES_DRAWN_AND_READBACK=8")
        print("LAST_PIXEL_RGBA=0,255,0,255")
        print(f"ELAPSED_WALL_MS={(time.perf_counter()-start)*1000:.2f}")
        print("DIRECT_INTEL_GLES2_RENDER_NODE=PASS")
        print("FLICK_COMPOSITOR_OR_KMS_CHANGED=NO")
    finally:
        if context and display:
            if fbo.value:gldelframebuffers(1,C.byref(fbo))
            if tex.value:gldeltextures(1,C.byref(tex))
            eglmake(display,None,None,None)
            if surface:egldestroysurface(display,surface)
            egldestroycontext(display,context)
        if display:eglterminate(display)
        if gbm:gbm_destroy(gbm)
        os.close(fd)

if __name__=="__main__":
    try:main()
    except Exception as exc:
        print(f"OFFSCREEN_GPU_TEST_ERROR={type(exc).__name__}:{exc}",file=sys.stderr)
        raise SystemExit(1)
