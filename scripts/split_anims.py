"""
Split baked ALLanim into separate DAE clips.
Open the .blend file in Blender, then run this script from the Scripting tab.
"""
import bpy
import os

out_dir = os.path.expanduser("~/Projects/codebuddy/models/chubby")
os.makedirs(out_dir, exist_ok=True)

# Animation segments from keyframe analysis
segments = [
    ("idle1",     0,   127),
    ("jump",      128, 148),
    ("walk",      149, 177),
    ("run1",      178, 197),
    ("falls1",    198, 224),
    ("wakesup1",  225, 253),
    ("idle2",     254, 339),
    ("no",        340, 369),
    ("yes",       370, 400),
    ("waving",    401, 421),
    ("happy",     422, 441),
    ("attack1",   442, 460),
    ("falls2",    461, 484),
    ("wakesup2",  485, 495),
    ("falls3",    496, 519),
    ("wakesup3",  520, 530),
    ("run2",      531, 546),
    ("attack2",   547, 563),
    ("dmg1",      564, 578),
    ("dmg2",      579, 593),
]

for name, start, end in segments:
    print(f"Exporting {name} (frames {start}-{end})...")

    bpy.context.scene.frame_start = start
    bpy.context.scene.frame_end = end

    bpy.ops.object.select_all(action='SELECT')

    path = os.path.join(out_dir, f"{name}.dae")
    bpy.ops.wm.collada_export(
        filepath=path,
        apply_modifiers=True,
        selected=True,
        include_children=True,
    )
    print(f"  -> {path}")

print(f"\nDone! {len(segments)} clips exported to {out_dir}")
