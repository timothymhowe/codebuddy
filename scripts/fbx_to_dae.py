"""Convert FBX to DAE with textures via Blender."""
import bpy
import sys
import os

argv = sys.argv
args = argv[argv.index('--') + 1:] if '--' in argv else []
if len(args) < 2:
    print("Usage: blender --background --python fbx_to_dae.py -- input.fbx output.dae")
    sys.exit(1)

fbx_path = args[0]
out_path = args[1]
tex_dir = os.path.dirname(fbx_path)

# Clear scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# Import FBX
print(f"Importing: {fbx_path}")
bpy.ops.import_scene.fbx(filepath=fbx_path)

# Fix texture paths — look for images in same folder as fbx
for img in bpy.data.images:
    if img.filepath:
        basename = os.path.basename(bpy.path.abspath(img.filepath))
        local = os.path.join(tex_dir, basename)
        if os.path.exists(local):
            img.filepath = local
            img.reload()
            print(f"  Texture: {basename} -> loaded")

# Select all
bpy.ops.object.select_all(action='SELECT')

# Export DAE
print(f"Exporting: {out_path}")
bpy.ops.wm.collada_export(
    filepath=out_path,
    apply_modifiers=True,
    selected=True,
    include_children=True,
)

print("Done!")
