"""
Convert PMX model to USDZ for SceneKit via Blender.
Usage: blender --background --python convert_pmx.py -- input.pmx output.usdz
"""
import bpy
import sys
import os

def convert(pmx_path, out_path):
    # Clear scene
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Enable mmd_tools
    try:
        bpy.ops.preferences.addon_enable(module='mmd_tools')
    except Exception:
        pass  # might already be enabled or extension-based

    # Import PMX
    print(f"Importing: {pmx_path}")
    bpy.ops.mmd_tools.import_model(
        filepath=pmx_path,
        scale=0.08,
        types={'MESH', 'ARMATURE', 'MORPHS'},
        clean_model=True,
    )

    # Select all imported objects
    bpy.ops.object.select_all(action='SELECT')

    # Export based on format
    ext = os.path.splitext(out_path)[1].lower()
    if ext == '.usdz':
        print(f"Exporting USDZ: {out_path}")
        bpy.ops.wm.usd_export(
            filepath=out_path.replace('.usdz', '.usdc'),
            selected_objects_only=False,
            export_animation=True,
            export_hair=False,
            export_uvmaps=True,
            export_normals=True,
            export_materials=True,
        )
        # Package as USDZ
        usdc = out_path.replace('.usdz', '.usdc')
        if os.path.exists(usdc):
            os.rename(usdc, out_path)
    elif ext == '.dae':
        print(f"Exporting DAE: {out_path}")
        bpy.ops.wm.collada_export(filepath=out_path)
    elif ext in ('.glb', '.gltf'):
        print(f"Exporting GLTF: {out_path}")
        bpy.ops.export_scene.gltf(
            filepath=out_path,
            export_format='GLB' if ext == '.glb' else 'GLTF_SEPARATE',
            export_animations=True,
            export_skins=True,
        )
    elif ext == '.fbx':
        print(f"Exporting FBX: {out_path}")
        bpy.ops.export_scene.fbx(
            filepath=out_path,
            use_selection=False,
            add_leaf_bones=False,
            bake_anim=True,
        )
    else:
        # Fallback: OBJ (no rig but guaranteed to work)
        print(f"Exporting OBJ: {out_path}")
        bpy.ops.wm.obj_export(filepath=out_path)

    print(f"Done: {out_path}")


if __name__ == '__main__':
    argv = sys.argv
    # Everything after '--' is our args
    if '--' in argv:
        args = argv[argv.index('--') + 1:]
    else:
        args = []

    if len(args) < 2:
        print("Usage: blender --background --python convert_pmx.py -- input.pmx output.usdz")
        sys.exit(1)

    convert(args[0], args[1])
