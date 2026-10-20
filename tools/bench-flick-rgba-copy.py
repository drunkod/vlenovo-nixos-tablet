#!/usr/bin/env python3
"""Bounded full-frame RGBA allocation/copy microbenchmark.

Copies and allocates in user space only; does not call Slint, DRM, GPU, KMS,
Wayland or systemd. Run on physical tablet AFTER idle CPU sampling is complete.
This measures a COPY component of the removed Slint path, not total render time.
"""
import argparse
import statistics
import time

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--width",type=int,default=1920)
    parser.add_argument("--height",type=int,default=1200)
    parser.add_argument("--frames",type=int,default=120)
    parser.add_argument("--repeats",type=int,default=3)
    args=parser.parse_args()
    if not (1 <= args.width <= 3840 and 1 <= args.height <= 2160 and
            1 <= args.frames <= 500 and 1 <= args.repeats <= 8):
        parser.error("unsafe benchmark size; maximum frame is 3840x2160, 500 frames x8")
    size=args.width*args.height*4
    source=bytes([127])*size
    observed=[]
    print(f"mode=allocate_clone_and_copy width={args.width} height={args.height} "
          f"bytes_per_frame={size} repeats={args.repeats} frames_each={args.frames}")
    print("repeat,frames,elapsed_wall_s,elapsed_cpu_s,cpu_ms_per_frame,"
          "minimum_user_copy_mib_per_s")
    check=0
    # Separate warmup included only in the thermal load, not timings.
    for _ in range(3):
        clone=bytearray(source)
        render=bytearray(size)
        render[:]=clone
        check^=render[0]
    for rep in range(args.repeats):
        wall_start=time.perf_counter()
        cpu_start=time.process_time()
        for i in range(args.frames):
            # Original Flick cloned an RGBA Slint image and then wrote into
            # MemoryRenderBuffer. This is a portable proxy for that COPY work.
            clone=bytearray(source)
            render=bytearray(size)
            render[:]=clone
            check^=render[i % size]
        cpu_elapsed=time.process_time()-cpu_start
        wall_elapsed=time.perf_counter()-wall_start
        mib=(2*size*args.frames)/(1024*1024)
        rate=mib/wall_elapsed
        observed.append(cpu_elapsed/args.frames*1000)
        print(f"{rep+1},{args.frames},{wall_elapsed:.4f},{cpu_elapsed:.4f},"
              f"{cpu_elapsed/args.frames*1000:.4f},{rate:.1f}",flush=True)
    print(f"median_cpu_ms_per_frame={statistics.median(observed):.4f}")
    print(f"checksum_parity={check}")
    print("NOTE: only Python allocation/memory copy; NOT Slint or GPU benchmark")

if __name__=="__main__":
    main()
