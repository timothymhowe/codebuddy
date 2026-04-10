import SwiftUI
import SceneKit

struct LowPolyHead: NSViewRepresentable {
    let personaId: String
    let bodyColor: Color
    let highlightColor: Color
    let hairColor: Color
    let eyeColor: Color
    let subtitle: String
    let activity: BuddyActivity
    let isBlinking: Bool
    let bounceSpeed: Double
    let jiggleTrigger: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
            // Clamp X and Z rotation to prevent backward tilt drift
            guard let ch = charNode, hasCustomModel else { return }
            ch.eulerAngles.x = savedEuler.x
            ch.eulerAngles.z = savedEuler.z
            // Y is allowed to change (walk direction)
        }

        var charNode: SCNNode?
        var headNode: SCNNode?
        var leftEyeNode: SCNNode?
        var rightEyeNode: SCNNode?
        var leftBrowNode: SCNNode?
        var rightBrowNode: SCNNode?
        var mouthNode: SCNNode?
        var leftBlush: SCNNode?
        var rightBlush: SCNNode?
        var lastJiggle = 0
        var lastActivity: BuddyActivity?
        var hasCustomModel = false
        var animTotalDuration: Double = 24.233
        var totalFrames: Double = 593
        var edgeObserver: Any?
        var baseScale: CGFloat = 1.0
        var savedEuler: SCNVector3 = .init()
    }

    // MARK: - Animation segments (frames at 25fps, 593 total)

    struct AnimSegment {
        let startFrame: Double
        let endFrame: Double
        let loops: Bool

        // USDZ total duration is 24.233s across 593 blender frames
        // Timing scale factor to align with actual playback
        static let scale: Double = 24.233 / 593.0

        var startTime: Double { startFrame * AnimSegment.scale }
        var endTime: Double { endFrame * AnimSegment.scale }
        var duration: Double { endTime - startTime }
    }

    static let animSegments: [String: AnimSegment] = [
        "idle1":    AnimSegment(startFrame: 0,   endFrame: 127, loops: true),
        "jump":     AnimSegment(startFrame: 128, endFrame: 148, loops: false),
        "walk":     AnimSegment(startFrame: 149, endFrame: 177, loops: true),
        "run1":     AnimSegment(startFrame: 178, endFrame: 197, loops: true),
        "falls1":   AnimSegment(startFrame: 198, endFrame: 224, loops: false),
        "wakesup1": AnimSegment(startFrame: 225, endFrame: 253, loops: false),
        "idle2":    AnimSegment(startFrame: 254, endFrame: 339, loops: true),
        "no":       AnimSegment(startFrame: 340, endFrame: 369, loops: false),
        "yes":      AnimSegment(startFrame: 370, endFrame: 400, loops: false),
        "waving":   AnimSegment(startFrame: 401, endFrame: 421, loops: false),
        "happy":    AnimSegment(startFrame: 422, endFrame: 441, loops: false),
        "attack1":  AnimSegment(startFrame: 442, endFrame: 460, loops: false),
        "falls2":   AnimSegment(startFrame: 461, endFrame: 484, loops: false),
        "wakesup2": AnimSegment(startFrame: 485, endFrame: 495, loops: false),
        "falls3":   AnimSegment(startFrame: 496, endFrame: 519, loops: false),
        "wakesup3": AnimSegment(startFrame: 520, endFrame: 530, loops: false),
        "run2":     AnimSegment(startFrame: 531, endFrame: 546, loops: true),
        "attack2":  AnimSegment(startFrame: 547, endFrame: 563, loops: false),
        "dmg1":     AnimSegment(startFrame: 564, endFrame: 578, loops: false),
        "dmg2":     AnimSegment(startFrame: 579, endFrame: 593, loops: false),
    ]

    /// Map buddy activity to animation name
    static func animName(for activity: BuddyActivity) -> String {
        switch activity {
        case .idle:     return "idle2"
        case .thinking: return "idle1"
        case .coding:   return "walk"
        case .running:  return "run1"
        case .error:    return "no"
        case .success:  return "happy"
        }
    }

    // MARK: - Model path

    private var customModelPath: String? {
        let dirs = [
            Bundle.main.resourcePath ?? "",
            FileManager.default.currentDirectoryPath + "/models",
            NSHomeDirectory() + "/.codebuddy/models",
        ]
        // Prioritize usdz (embedded textures) over dae
        for dir in dirs {
            for ext in ["usdz", "dae", "scn", "obj"] {
                let path = dir + "/" + personaId + "." + ext
                if FileManager.default.fileExists(atPath: path) { return path }
            }
        }
        return nil
    }

    // MARK: - Create

    func makeNSView(context: Context) -> SCNView {
        let v = SCNView()
        v.backgroundColor = .clear
        v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X
        v.preferredFramesPerSecond = 60

        let scene = SCNScene()
        scene.background.contents = NSColor.clear

        // ── Camera ──
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 28
        cam.position = SCNVector3(0, 0.35, 6.0)
        scene.rootNode.addChildNode(cam)

        // ── Lights ──
        light(.directional, i: 850, e: SCNVector3(-0.5, 0.35, 0), scene)
        light(.directional, i: 280, e: SCNVector3(-0.15, -0.5, 0), scene)
        light(.ambient, i: 550, e: .init(), scene)

        // ── Try loading custom 3D model ──
        if let modelPath = customModelPath {
            return buildFromModel(modelPath, scene: scene, view: v, context: context)
        }

        let skin = NSColor(bodyColor)
        let spec = NSColor(highlightColor)

        // ── Character root ──
        let character = SCNNode()
        character.name = "character"
        scene.rootNode.addChildNode(character)
        context.coordinator.charNode = character

        // ── Head — rounded box (Animal Crossing shape) ──
        let headGeo = SCNBox(width: 1.9, height: 1.55, length: 1.45, chamferRadius: 0.55)
        headGeo.chamferSegmentCount = 3
        let skinMat = phongMat(skin, spec: spec, shine: 0.06)
        headGeo.materials = [skinMat]

        let head = SCNNode(geometry: headGeo)
        head.name = "head"
        character.addChildNode(head)
        context.coordinator.headNode = head

        // ── Tiny chibi body ──
        let torsoGeo = SCNBox(width: 0.9, height: 0.6, length: 0.65, chamferRadius: 0.22)
        torsoGeo.chamferSegmentCount = 2
        torsoGeo.materials = [skinMat]
        let torso = SCNNode(geometry: torsoGeo)
        torso.position = SCNVector3(0, -1.05, 0)
        character.addChildNode(torso)

        // ── Eyes — simple dots with one glint ──
        let pupilMat = cMat(.black)
        let glintMat = cMat(.white)

        func makeEye(x: CGFloat) -> SCNNode {
            let dot = SCNNode(geometry: sph(0.14, 8, pupilMat))
            dot.position = SCNVector3(x, 0.05, 0.72)

            let glint = SCNNode(geometry: sph(0.04, 6, glintMat))
            glint.position = SCNVector3(-0.04, 0.04, 0.1)
            dot.addChildNode(glint)

            head.addChildNode(dot)
            return dot
        }

        context.coordinator.leftEyeNode = makeEye(x: -0.35)
        context.coordinator.rightEyeNode = makeEye(x: 0.35)

        // ── Blush cheeks ──
        let blushMat = SCNMaterial()
        blushMat.diffuse.contents = NSColor(red: 1, green: 0.45, blue: 0.5, alpha: 0.2)
        blushMat.lightingModel = .constant
        blushMat.isDoubleSided = true

        func makeBlush(x: CGFloat) -> SCNNode {
            let geo = SCNCylinder(radius: 0.13, height: 0.004)
            geo.radialSegmentCount = 8
            geo.materials = [blushMat]
            let n = SCNNode(geometry: geo)
            n.position = SCNVector3(x, -0.12, 0.7)
            n.eulerAngles.x = CGFloat.pi / 2
            head.addChildNode(n)
            return n
        }

        context.coordinator.leftBlush = makeBlush(x: -0.5)
        context.coordinator.rightBlush = makeBlush(x: 0.5)

        // ── Small brows — just little lines ──
        let browMat = cMat(NSColor(red: 0.2, green: 0.15, blue: 0.12, alpha: 0.6))
        func makeBrow(x: CGFloat) -> SCNNode {
            let geo = SCNCapsule(capRadius: 0.012, height: 0.13)
            geo.materials = [browMat]
            let n = SCNNode(geometry: geo)
            n.position = SCNVector3(x, 0.24, 0.72)
            n.eulerAngles.z = CGFloat.pi / 2
            head.addChildNode(n)
            return n
        }

        context.coordinator.leftBrowNode = makeBrow(x: -0.35)
        context.coordinator.rightBrowNode = makeBrow(x: 0.35)

        // ── Frenchie-specific geometry ──
        if personaId == "frenchie" {
            // Bat ears
            let earMat = phongMat(skin, spec: spec, shine: 0.04)
            let innerMat = cMat(NSColor(red: 0.75, green: 0.55, blue: 0.5, alpha: 0.7))

            for x: CGFloat in [-0.52, 0.52] {
                let earGeo = SCNBox(width: 0.32, height: 0.42, length: 0.18, chamferRadius: 0.1)
                earGeo.materials = [earMat]
                let ear = SCNNode(geometry: earGeo)
                ear.position = SCNVector3(x, 0.82, 0.08)
                let tilt: CGFloat = x < 0 ? -0.18 : 0.18
                ear.eulerAngles = SCNVector3(0.1, 0, tilt)
                head.addChildNode(ear)

                // Inner ear (pink)
                let innerGeo = SCNBox(width: 0.18, height: 0.28, length: 0.04, chamferRadius: 0.06)
                innerGeo.materials = [innerMat]
                let inner = SCNNode(geometry: innerGeo)
                inner.position = SCNVector3(0, 0.02, 0.08)
                ear.addChildNode(inner)
            }

            // Smushed snout
            let snoutGeo = SCNBox(width: 0.35, height: 0.18, length: 0.12, chamferRadius: 0.06)
            snoutGeo.materials = [earMat]
            let snout = SCNNode(geometry: snoutGeo)
            snout.position = SCNVector3(0, -0.15, 0.74)
            head.addChildNode(snout)

            // Nostrils
            for nx: CGFloat in [-0.07, 0.07] {
                let nGeo = SCNSphere(radius: 0.025)
                nGeo.segmentCount = 6
                nGeo.materials = [cMat(.black)]
                let n = SCNNode(geometry: nGeo)
                n.position = SCNVector3(nx, -0.01, 0.07)
                snout.addChildNode(n)
            }
        }

        // ── Labubu Mouth ──
        let mouth = SCNNode()
        mouth.name = "mouth"
        mouth.position = SCNVector3(0, -0.28, 0.7)
        head.addChildNode(mouth)
        context.coordinator.mouthNode = mouth

        // Dark mouth opening
        let mouthBG = SCNBox(width: 0.55, height: 0.14, length: 0.02, chamferRadius: 0.03)
        mouthBG.materials = [cMat(NSColor(red: 0.12, green: 0.04, blue: 0.06, alpha: 1))]
        let bgNode = SCNNode(geometry: mouthBG)
        mouth.addChildNode(bgNode)

        // Top teeth — jagged, slightly irregular
        let toothMat = cMat(NSColor(red: 0.97, green: 0.95, blue: 0.9, alpha: 1))
        let topTeethH: [CGFloat] = [0.04, 0.055, 0.04, 0.06, 0.045, 0.055, 0.04]
        for i in 0..<topTeethH.count {
            let h = topTeethH[i]
            let tooth = SCNCone(topRadius: 0, bottomRadius: 0.02, height: h)
            tooth.radialSegmentCount = 4
            tooth.materials = [toothMat]
            let tn = SCNNode(geometry: tooth)
            let x = CGFloat(i) * 0.072 - 0.216
            tn.position = SCNVector3(x, 0.06 + h * 0.1, 0.01)
            tn.eulerAngles.x = CGFloat.pi
            mouth.addChildNode(tn)
        }

        // Bottom teeth — smaller, fewer, offset
        let botTeethH: [CGFloat] = [0.03, 0.04, 0.035, 0.045, 0.03]
        for i in 0..<botTeethH.count {
            let h = botTeethH[i]
            let tooth = SCNCone(topRadius: 0, bottomRadius: 0.016, height: h)
            tooth.radialSegmentCount = 4
            tooth.materials = [toothMat]
            let tn = SCNNode(geometry: tooth)
            let x = CGFloat(i) * 0.09 - 0.18
            tn.position = SCNVector3(x, -0.055 - h * 0.1, 0.01)
            mouth.addChildNode(tn)
        }

        // ── Katakana on chest ──
        let textGeo = SCNText(string: subtitle, extrusionDepth: 0.005)
        textGeo.font = NSFont(name: "HiraginoSans-W7", size: 0.16)
            ?? NSFont.boldSystemFont(ofSize: 0.16)
        textGeo.flatness = 0.05
        let textMat = SCNMaterial()
        textMat.diffuse.contents = NSColor.white.withAlphaComponent(0.85)
        textMat.lightingModel = .constant
        textGeo.materials = [textMat]

        let textNode = SCNNode(geometry: textGeo)
        let (tmin, tmax) = textNode.boundingBox
        textNode.pivot = SCNMatrix4MakeTranslation(
            (tmax.x - tmin.x) / 2, (tmax.y - tmin.y) / 2, 0
        )
        textNode.position = SCNVector3(0, 0.0, 0.38)
        textNode.scale = SCNVector3(1.0, 1.0, 0.12)
        torso.addChildNode(textNode)

        // ── Animations ──
        let sway = SCNAction.repeatForever(.sequence([
            .rotateBy(x: 0.04, y: 0.15, z: 0.01, duration: 2.2 / bounceSpeed),
            .rotateBy(x: -0.04, y: -0.15, z: -0.01, duration: 2.2 / bounceSpeed),
        ]))
        character.runAction(sway, forKey: "sway")

        let breathe = SCNAction.repeatForever(.sequence([
            .scale(to: 1.012, duration: 1.7),
            .scale(to: 0.988, duration: 1.7),
        ]))
        character.runAction(breathe, forKey: "breathe")

        v.scene = scene
        return v
    }

    // MARK: - Update

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator

        // ── Switch animation on activity change (custom models only) ──
        if c.hasCustomModel && activity != c.lastActivity {
            let prevActivity = c.lastActivity
            c.lastActivity = activity

            guard let charNode = c.charNode else { return }

            if activity == .coding {
                // Jump-turn-walk sequence: jump + rotate 90° to face travel direction
                if let jumpSeg = LowPolyHead.animSegments["jump"],
                   let walkSeg = LowPolyHead.animSegments["walk"] {
                    LowPolyHead.applySegment(jumpSeg, to: charNode)
                    // Absolute rotation to 90° (sideways)
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = jumpSeg.duration
                    charNode.eulerAngles.y = -CGFloat.pi / 2
                    SCNTransaction.commit()
                    // After jump: switch to walk loop
                    DispatchQueue.main.asyncAfter(deadline: .now() + jumpSeg.duration) {
                        LowPolyHead.applySegment(walkSeg, to: charNode)
                    }
                }
            } else if prevActivity == .coding {
                // Leaving walk: jump-turn back to face camera
                if let jumpSeg = LowPolyHead.animSegments["jump"] {
                    LowPolyHead.applySegment(jumpSeg, to: charNode)
                    // Absolute rotation back to 0° (facing camera)
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = jumpSeg.duration
                    charNode.eulerAngles.y = 0
                    SCNTransaction.commit()
                    DispatchQueue.main.asyncAfter(deadline: .now() + jumpSeg.duration) {
                        let animName = LowPolyHead.animName(for: activity)
                        if let seg = LowPolyHead.animSegments[animName] {
                            LowPolyHead.applySegment(seg, to: charNode)
                            if !seg.loops {
                                DispatchQueue.main.asyncAfter(deadline: .now() + seg.duration) {
                                    if let idle = LowPolyHead.animSegments["idle2"] {
                                        LowPolyHead.applySegment(idle, to: charNode)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // Normal state change
                let animName = LowPolyHead.animName(for: activity)
                if let seg = LowPolyHead.animSegments[animName] {
                    LowPolyHead.applySegment(seg, to: charNode)
                    if !seg.loops {
                        DispatchQueue.main.asyncAfter(deadline: .now() + seg.duration) {
                            if let idle = LowPolyHead.animSegments["idle2"] {
                                LowPolyHead.applySegment(idle, to: charNode)
                            }
                        }
                    }
                }
            }
        }

        // ── Skin color (procedural models only) ──
        if !c.hasCustomModel {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.4
            c.headNode?.geometry?.materials.first?.diffuse.contents = NSColor(bodyColor)
            c.headNode?.geometry?.materials.first?.specular.contents = NSColor(highlightColor)
            SCNTransaction.commit()
        }

        // ── Blink ──
        let ey: CGFloat = isBlinking ? 0.06 : 1.0
        SCNTransaction.begin()
        SCNTransaction.animationDuration = isBlinking ? 0.05 : 0.1
        c.leftEyeNode?.scale = SCNVector3(1, ey, 1)
        c.rightEyeNode?.scale = SCNVector3(1, ey, 1)
        SCNTransaction.commit()

        // ── Iris direction ──
        let ip: SCNVector3
        switch activity {
        case .thinking: ip = SCNVector3(-0.02, 0.04, 0.16)
        case .coding:   ip = SCNVector3(0.01, -0.025, 0.16)
        case .running:  ip = SCNVector3(0.04, 0, 0.16)
        default:        ip = SCNVector3(0, 0, 0.16)
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.25
        c.leftEyeNode?.childNode(withName: "iris", recursively: false)?.position = ip
        c.rightEyeNode?.childNode(withName: "iris", recursively: false)?.position = ip
        SCNTransaction.commit()

        // ── Eyebrows ──
        let by: CGFloat
        let bt: CGFloat
        switch activity {
        case .thinking: by = 0.37; bt = 0.08
        case .error:    by = 0.28; bt = -0.15
        case .success:  by = 0.36; bt = 0.06
        default:        by = 0.32; bt = 0.0
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.2
        c.leftBrowNode?.position.y = by
        c.rightBrowNode?.position.y = by
        c.leftBrowNode?.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2 + bt)
        c.rightBrowNode?.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2 - bt)
        SCNTransaction.commit()

        // ── Labubu mouth (scale the whole teeth group) ──
        let ms: SCNVector3
        switch activity {
        case .idle:     ms = SCNVector3(1.0, 1.0, 1.0)
        case .thinking: ms = SCNVector3(0.7, 0.85, 1.0)
        case .coding:   ms = SCNVector3(1.2, 1.0, 1.0)
        case .running:  ms = SCNVector3(0.85, 0.9, 1.0)
        case .error:    ms = SCNVector3(1.3, 1.25, 1.0)
        case .success:  ms = SCNVector3(1.4, 1.15, 1.0)
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.25
        c.mouthNode?.scale = ms
        SCNTransaction.commit()

        // ── Blush intensity ──
        let blushA: CGFloat = activity == .success ? 0.45 : (activity == .error ? 0.1 : 0.25)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        c.leftBlush?.geometry?.materials.first?.diffuse.contents =
            NSColor(red: 1, green: 0.45, blue: 0.5, alpha: blushA)
        c.rightBlush?.geometry?.materials.first?.diffuse.contents =
            NSColor(red: 1, green: 0.45, blue: 0.5, alpha: blushA)
        SCNTransaction.commit()

        // ── Nudge on activity ──
        if let ch = c.charNode {
            let nudge: SCNAction
            switch activity {
            case .running:
                nudge = .sequence([
                    .rotateBy(x: 0, y: 0.2, z: 0, duration: 0.1),
                    .rotateBy(x: 0, y: -0.2, z: 0, duration: 0.1),
                ])
            case .error:
                nudge = .sequence([
                    .rotateBy(x: 0, y: 0, z: 0.1, duration: 0.07),
                    .rotateBy(x: 0, y: 0, z: -0.2, duration: 0.07),
                    .rotateBy(x: 0, y: 0, z: 0.1, duration: 0.07),
                ])
            case .success:
                nudge = .sequence([
                    .rotateBy(x: -0.1, y: 0, z: 0, duration: 0.12),
                    .rotateBy(x: 0.1, y: 0, z: 0, duration: 0.12),
                ])
            default:
                nudge = .wait(duration: 0)
            }
            ch.runAction(nudge, forKey: "nudge")
        }

        // ── Jiggle ──
        if jiggleTrigger != c.lastJiggle {
            c.lastJiggle = jiggleTrigger
            if let ch = c.charNode {
                let s = c.baseScale
                let squish = SCNAction.sequence([
                    .scale(to: s * 1.15, duration: 0.05),
                    .scale(to: s * 0.88, duration: 0.05),
                    .scale(to: s * 1.08, duration: 0.05),
                    .scale(to: s * 0.95, duration: 0.04),
                    .scale(to: s * 1.02, duration: 0.04),
                    .scale(to: s, duration: 0.03),
                ])
                // Wobble that returns to exactly zero
                let savedAngles = ch.eulerAngles
                let wobble = SCNAction.sequence([
                    .rotateBy(x: 0, y: 0, z: 0.18, duration: 0.04),
                    .rotateBy(x: 0, y: 0, z: -0.36, duration: 0.04),
                    .rotateBy(x: 0, y: 0, z: 0.25, duration: 0.04),
                    .rotateBy(x: 0, y: 0, z: -0.07, duration: 0.03),
                    .run { node in node.eulerAngles = savedAngles },
                ])
                ch.runAction(.group([squish, wobble]), forKey: "jiggle")
            }
        }
    }

    // MARK: - Custom Model Loader

    private func buildFromModel(_ path: String, scene: SCNScene, view: SCNView,
                                context: Context) -> SCNView {
        // Try URL-based loading first (needed for USDZ), fallback to data-based
        let url = URL(fileURLWithPath: path)
        let modelScene: SCNScene
        if let sc = try? SCNScene(url: url, options: nil) {
            modelScene = sc
        } else if let data = try? Data(contentsOf: url),
                  let source = SCNSceneSource(data: data, options: nil),
                  let sc = source.scene(options: nil) {
            modelScene = sc
        } else {
            view.scene = scene
            return view
        }

        // Wrap all imported nodes in a character root
        let character = SCNNode()
        character.name = "character"
        for child in modelScene.rootNode.childNodes {
            character.addChildNode(child.clone())
        }

        // Apply loose textures if no embedded ones (dae models)
        let isUSDZ = path.hasSuffix(".usdz")
        if !isUSDZ {
            let texDir = (path as NSString).deletingLastPathComponent + "/textures/"
            applyTextures(to: character, from: texDir)
        }

        // Fix orientation based on format
        if path.hasSuffix(".dae") {
            // MMD/PMX exports: Z-up → Y-up
            character.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        }
        // USDZ is already Y-up, no rotation needed

        // Auto-fit
        character.flattenedClone() // force bbox recalc
        let (bmin, bmax) = character.boundingBox
        let height = CGFloat(bmax.y - bmin.y)
        let width = CGFloat(bmax.x - bmin.x)
        let depth = CGFloat(bmax.z - bmin.z)
        let maxDim = max(height, width, depth, 0.001)
        let fitScale: CGFloat = 1.8 / maxDim
        character.scale = SCNVector3(fitScale, fitScale, fitScale)

        // Center and ground
        character.position = SCNVector3(0, -1.0, 0)

        scene.rootNode.addChildNode(character)
        context.coordinator.charNode = character

        // Find the first mesh node for color updates
        context.coordinator.headNode = character.childNodes(passingTest: { node, _ in
            node.geometry != nil
        }).first

        // Animation segment timing (120fps, 2908 total frames, 24.23s)
        // Idle: frames 0-633 = 0.00s - 5.27s
        let animFPS: Double = 120.0
        let idleStart: Double = 0.0 / animFPS
        let idleEnd: Double = 633.0 / animFPS

        // Strip ALL root bone turntable spins (B0_01 appears in both Meshes and SkinnedMeshes)
        func stripRoot(_ n: SCNNode) {
            let name = (n.name ?? "").lowercased()
            if name.starts(with: "b0") && n.animationKeys.contains("transform") {
                n.removeAnimation(forKey: "transform")
            }
            for c in n.childNodes { stripRoot(c) }
        }
        stripRoot(character)

        // Fix eyes — solid black button eyes
        func fixEyes(_ n: SCNNode) {
            let name = (n.name ?? "").lowercased()
            if name.contains("eye") {
                if let geo = n.geometry {
                    for mat in geo.materials {
                        mat.diffuse.contents = NSColor.black
                        mat.lightingModel = .constant
                    }
                }
            }
            for c in n.childNodes { fixEyes(c) }
        }
        fixEyes(character)

        // Store base scale and initial rotation for clamping
        context.coordinator.baseScale = fitScale
        context.coordinator.savedEuler = character.eulerAngles
        context.coordinator.hasCustomModel = true
        if let seg = LowPolyHead.animSegments["idle2"] {
            LowPolyHead.applySegment(seg, to: character)
        }

        // Listen for edge hits to play jump-turn
        context.coordinator.edgeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BuddyEdgeHit"),
            object: nil, queue: .main
        ) { [weak character] notif in
            guard let charNode = character,
                  let dir = notif.userInfo?["direction"] as? CGFloat,
                  let jumpSeg = LowPolyHead.animSegments["jump"],
                  let walkSeg = LowPolyHead.animSegments["walk"] else { return }

            // Play jump animation
            LowPolyHead.applySegment(jumpSeg, to: charNode)

            // Flip to face new direction
            let targetY: CGFloat = dir > 0 ? -CGFloat.pi / 2 : CGFloat.pi / 2
            SCNTransaction.begin()
            SCNTransaction.animationDuration = jumpSeg.duration
            charNode.eulerAngles.y = targetY
            SCNTransaction.commit()

            // Resume walk after jump
            DispatchQueue.main.asyncAfter(deadline: .now() + jumpSeg.duration) {
                LowPolyHead.applySegment(walkSeg, to: charNode)
            }
        }

        // On drop: play falls1 immediately
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BuddyDropped"),
            object: nil, queue: .main
        ) { [weak character] _ in
            guard let charNode = character,
                  let fallSeg = LowPolyHead.animSegments["falls1"] else { return }
            LowPolyHead.applySegment(fallSeg, to: charNode)
        }

        // On land: play wakesup1 → idle2
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BuddyLanded"),
            object: nil, queue: .main
        ) { [weak character] _ in
            guard let charNode = character,
                  let wakeSeg = LowPolyHead.animSegments["wakesup1"],
                  let idleSeg = LowPolyHead.animSegments["idle2"] else { return }
            LowPolyHead.applySegment(wakeSeg, to: charNode)
            DispatchQueue.main.asyncAfter(deadline: .now() + wakeSeg.duration) {
                LowPolyHead.applySegment(idleSeg, to: charNode)
            }
        }

        // No extra sway
        let skipSway = true
        if !skipSway {
            character.runAction(.repeatForever(.sequence([
                .rotateBy(x: 0.03, y: 0.12, z: 0, duration: 2.2 / bounceSpeed),
                .rotateBy(x: -0.03, y: -0.12, z: 0, duration: 2.2 / bounceSpeed),
            ])), forKey: "sway")
            character.runAction(.repeatForever(.sequence([
                .scale(to: fitScale * 1.01, duration: 1.7),
                .scale(to: fitScale * 0.99, duration: 1.7),
            ])), forKey: "breathe")
        }

        view.scene = scene
        view.delegate = context.coordinator
        return view
    }

    // MARK: - Animation Segment Player

    private static var loopTimer: Timer?

    static func applySegment(_ seg: AnimSegment, to node: SCNNode) {
        // Kill any existing loop timer
        loopTimer?.invalidate()
        loopTimer = nil

        func apply(_ n: SCNNode) {
            let name = (n.name ?? "").lowercased()
            if name.starts(with: "b0") && !name.contains("skin") {
                for c in n.childNodes { apply(c) }
                return
            }
            for key in n.animationKeys {
                if let player = n.animationPlayer(forKey: key) {
                    let anim = player.animation
                    n.removeAnimation(forKey: key)
                    anim.timeOffset = seg.startTime
                    anim.repeatCount = 0
                    let newPlayer = SCNAnimationPlayer(animation: anim)
                    n.addAnimationPlayer(newPlayer, forKey: key)
                    newPlayer.play()
                }
            }
            for c in n.childNodes { apply(c) }
        }
        apply(node)

        // Single timer for looping — restarts all anims together
        if seg.loops {
            // Preserve rotation so animations can't drift any axis
            let savedAngles = node.eulerAngles
            loopTimer = Timer.scheduledTimer(withTimeInterval: seg.duration, repeats: true) { _ in
                apply(node)
                node.eulerAngles = savedAngles
            }
        }
    }

    // MARK: - Texture Loader

    private func applyTextures(to root: SCNNode, from dir: String) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
        let imageFiles = files.filter { $0.hasSuffix(".png") || $0.hasSuffix(".jpg") || $0.hasSuffix(".tga") }

        // Strip suffixes like ".001", ".003" from material names for matching
        func baseName(_ name: String) -> String {
            var n = name.lowercased()
            // Remove blender numeric suffixes (.001, .003, etc)
            if let range = n.range(of: #"\.\d+$"#, options: .regularExpression) {
                n.removeSubrange(range)
            }
            return n
        }

        func walk(_ node: SCNNode) {
            if let geo = node.geometry {
                for mat in geo.materials {
                    let matBase = baseName(mat.name ?? "")

                    // Score each texture file — higher = better match
                    var best: (score: Int, file: String) = (0, "")
                    for file in imageFiles {
                        let fileBase = (file as NSString).deletingPathExtension.lowercased()
                        var score = 0

                        if matBase == fileBase { score = 100 }  // exact
                        else if matBase.contains(fileBase) { score = 50 }
                        else if fileBase.contains(matBase) { score = 50 }
                        else {
                            // Word overlap — count shared words
                            let matWords = Set(matBase.split(separator: "_").map(String.init))
                            let fileWords = Set(fileBase.split(separator: "_").map(String.init))
                            let overlap = matWords.intersection(fileWords).count
                            if overlap > 0 { score = overlap * 10 }
                        }

                        if score > best.score { best = (score, file) }
                    }

                    if !best.file.isEmpty, let img = NSImage(contentsOfFile: dir + best.file) {
                        mat.diffuse.contents = img
                    }
                }
            }
            node.childNodes.forEach { walk($0) }
        }
        walk(root)
    }

    // MARK: - Helpers

    private func light(_ t: SCNLight.LightType, i: CGFloat, e: SCNVector3, _ s: SCNScene) {
        let n = SCNNode()
        n.light = SCNLight()
        n.light!.type = t
        n.light!.intensity = i
        n.eulerAngles = e
        s.rootNode.addChildNode(n)
    }

    private func sph(_ r: CGFloat, _ seg: Int, _ m: SCNMaterial) -> SCNSphere {
        let g = SCNSphere(radius: r); g.segmentCount = seg; g.materials = [m]; return g
    }

    private func cMat(_ c: NSColor) -> SCNMaterial {
        let m = SCNMaterial(); m.diffuse.contents = c; m.lightingModel = .constant; return m
    }

    private func phongMat(_ c: NSColor, spec: NSColor, shine: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = c
        m.specular.contents = spec
        m.shininess = shine
        m.lightingModel = .phong
        return m
    }
}
