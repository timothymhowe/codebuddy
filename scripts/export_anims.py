"""
Auto-detect animation segments by keyframe gaps and export each as separate DAE.
Run in Blender: open the .blend file, then run this script.
"""
import bpy
import os

# Output directory
out_dir = os.path.expanduser("~/Projects/codebuddy/models/chubby")
os.makedirs(out_dir, exist_ok=True)

# Collect all keyframe times from all actions
all_times = set()
for action in bpy.data.actions:
    for fcurve in action.fcurves:
        for kp in fcurve.keyframe_points:
            all_times.add(int(kp.co[0]))

sorted_times = sorted(all_times)
print(f"Found {len(sorted_times)} unique keyframe times")
print(f"Range: {sorted_times[0]} - {sorted_times[-1]}")

# Find segment boundaries — gaps of 2+ frames with no keyframes
# or just split at large gaps
segments = []
seg_start = sorted_times[0]
prev = sorted_times[0]

# Detect boundaries: look for frames where many bones have keyframes
# (animation transitions usually key everything on the same frame)
from collections import Counter
frame_density = Counter()
for action in bpy.data.actions:
    for fcurve in action.fcurves:
        for kp in fcurve.keyframe_points:
            frame_density[int(kp.co[0])] += 1

# Frames with high keyframe density are likely animation boundaries
avg_density = sum(frame_density.values()) / len(frame_density) if frame_density else 1
threshold = avg_density * 1.5

boundary_frames = sorted([f for f, count in frame_density.items() if count >= threshold])
print(f"\nHigh-density frames (likely boundaries): {boundary_frames[:30]}...")

# Build segments from boundary frames
segments = []
for i in range(len(boundary_frames) - 1):
    start = boundary_frames[i]
    end = boundary_frames[i + 1]
    if end - start > 5:  # skip tiny segments
        segments.append((start, end))

print(f"\nDetected {len(segments)} animation segments:")
for i, (start, end) in enumerate(segments):
    fps = bpy.context.scene.render.fps
    dur = (end - start) / fps
    print(f"  anim_{i:02d}: frames {start}-{end} ({dur:.2f}s)")

# Export each segment
for i, (start, end) in enumerate(segments):
    bpy.context.scene.frame_start = start
    bpy.context.scene.frame_end = end

    name = f"anim_{i:02d}"
    path = os.path.join(out_dir, f"{name}.dae")

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.collada_export(
        filepath=path,
        apply_modifiers=True,
        selected=True,
        include_children=True,
    )
    print(f"Exported: {name} (frames {start}-{end}) -> {path}")

print(f"\nDone! {len(segments)} clips exported to {out_dir}")
print("\nRename them to match their actual animation (idle.dae, bounce.dae, fall.dae, etc)")
