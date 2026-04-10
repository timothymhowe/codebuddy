"""
Export each action as a separate DAE with keyframes shifted to start at frame 0.
Open the .blend file, then run this from the Scripting tab.
"""
import bpy
import os

out_dir = os.path.expanduser("~/Projects/codebuddy/models/chubby/anims")
os.makedirs(out_dir, exist_ok=True)

# Get the armature
armature = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        armature = obj
        break

if not armature:
    print("ERROR: No armature found")
    raise SystemExit

print(f"Armature: {armature.name}")
print(f"Actions found: {len(bpy.data.actions)}")

# Skip the mega-animation and blink
skip = {"allanimations", "blink_allanims"}

for action in bpy.data.actions:
    name = action.name.lower().replace(" ", "_").replace(".", "_")
    if name in skip:
        print(f"  SKIP: {action.name}")
        continue

    start = int(action.frame_range[0])
    end = int(action.frame_range[1])
    frame_count = end - start

    print(f"  {action.name} -> {name}.dae (frames {start}-{end}, shifting to 0-{frame_count})")

    # Duplicate the action so we can shift keyframes without messing up the original
    temp_action = action.copy()
    temp_action.name = f"_temp_{name}"

    # Shift all keyframes to start at 0
    offset = -start
    for fcurve in temp_action.fcurves:
        for kp in fcurve.keyframe_points:
            kp.co[0] += offset
            kp.handle_left[0] += offset
            kp.handle_right[0] += offset

    # Set as active action
    armature.animation_data.action = temp_action
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = frame_count

    # Select all
    bpy.ops.object.select_all(action='SELECT')

    # Export
    path = os.path.join(out_dir, f"{name}.dae")
    bpy.ops.wm.collada_export(
        filepath=path,
        apply_modifiers=True,
        selected=True,
        include_children=True,
    )

    # Clean up temp action
    bpy.data.actions.remove(temp_action)

# Restore first action
if bpy.data.actions:
    armature.animation_data.action = bpy.data.actions[0]

print(f"\nDone! Exported to {out_dir}")
print("All keyframes shifted to start at frame 0")
