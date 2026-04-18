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
        var savedAnimTargetEuler: SCNVector3 = .init()

        func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
            guard hasCustomModel else { return }
            // Clamp character root — all axes (Y only changes during walk)
            if let ch = charNode {
                ch.eulerAngles.x = savedEuler.x
                ch.eulerAngles.z = savedEuler.z
                // Only clamp Y when not walking
                if !isWalking {
                    ch.eulerAngles.y = savedEuler.y
                }
            }
            // Clamp armature rotation
            if let at = animTargetNode {
                at.eulerAngles = savedAnimTargetEuler
            }
        }

        var isWalking = false

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
        var edgeObserver: Any?
        var baseScale: CGFloat = 1.0
        var savedEuler: SCNVector3 = .init()
        /// Loaded animation clips keyed by name
        var animClips: [String: SCNAnimation] = [:]
        /// The bone node that animations should be played on
        var animTargetNode: SCNNode?
        var animQueue: AnimationQueue?
    }

    // MARK: - Animation clips

    struct AnimClipInfo {
        let filename: String
        let loops: Bool
    }

    static let clipMap: [String: AnimClipInfo] = [
        "idle1":    AnimClipInfo(filename: "idle1.dae", loops: true),
        "idle2":    AnimClipInfo(filename: "idle2.dae", loops: true),
        "jump":     AnimClipInfo(filename: "jump.dae", loops: false),
        "walk":     AnimClipInfo(filename: "walk.dae", loops: true),
        "run":      AnimClipInfo(filename: "run.dae", loops: true),
        "run2":     AnimClipInfo(filename: "run2.dae", loops: true),
        "falls1":   AnimClipInfo(filename: "falls1.dae", loops: false),
        "falls2":   AnimClipInfo(filename: "falls2.dae", loops: false),
        "falls3":   AnimClipInfo(filename: "falls3.dae", loops: false),
        "wakesup1": AnimClipInfo(filename: "wakesup1.dae", loops: false),
        "wakesup2": AnimClipInfo(filename: "wakesup2.dae", loops: false),
        "wakesup3": AnimClipInfo(filename: "wakesup3.dae", loops: false),
        "no":       AnimClipInfo(filename: "no.dae", loops: false),
        "yes":      AnimClipInfo(filename: "yes.dae", loops: false),
        "waving":   AnimClipInfo(filename: "waving.dae", loops: false),
        "happy":    AnimClipInfo(filename: "happy.dae", loops: false),
        "attack1":  AnimClipInfo(filename: "attack1.dae", loops: false),
        "attack2":  AnimClipInfo(filename: "attack2.dae", loops: false),
        "dmg1":     AnimClipInfo(filename: "dmg1.dae", loops: false),
        "dmg2":     AnimClipInfo(filename: "dmg2.dae", loops: false),
    ]

    /// Map buddy activity to clip name
    static func animName(for activity: BuddyActivity) -> String {
        switch activity {
        case .idle:     return "idle2"
        case .thinking: return "idle1"
        case .coding:   return "walk"
        case .running:  return "run"
        case .error:    return "no"
        case .success:  return "happy"
        }
    }

    // MARK: - Model path

    private var customModelPath: String? {
        let dirs = [
            (Bundle.main.resourcePath ?? "") + "/models",
            FileManager.default.currentDirectoryPath + "/models",
            NSHomeDirectory() + "/.codebuddy/models",
        ]
        // Check for anims folder first — if it exists, use idle1.dae as the base model
        // (dae clips have matching skeleton hierarchy for animation swapping)
        for dir in dirs {
            let animDir = dir + "/chubby/anims"
            let idlePath = animDir + "/idle1.dae"
            if FileManager.default.fileExists(atPath: idlePath) { return idlePath }
        }
        // Fallback to single model file
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
        light(.directional, i: 1000, e: SCNVector3(-0.5, 0.35, 0), scene)
        light(.directional, i: 150, e: SCNVector3(-0.15, -0.5, 0), scene)
        light(.ambient, i: 100, e: .init(), scene)

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

            guard let charNode = c.charNode, let q = c.animQueue else { return }
            let clips = c.animClips

            if activity == .coding {
                c.isWalking = true
                let jumpDur = clips["jump"]?.duration ?? 0.8
                q.interrupt(with: [
                    (clip: "jump", action: {
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = jumpDur
                        charNode.eulerAngles.y = -CGFloat.pi / 2
                        SCNTransaction.commit()
                    }),
                ], thenIdle: "walk")
            } else if prevActivity == .coding {
                c.isWalking = false
                let jumpDur = clips["jump"]?.duration ?? 0.8
                let name = LowPolyHead.animName(for: activity)
                q.interrupt(with: [
                    (clip: "jump", action: {
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = jumpDur
                        charNode.eulerAngles.y = 0
                        SCNTransaction.commit()
                    }),
                    (clip: name, action: nil),
                ], thenIdle: "idle2")
            } else {
                // Normal state change: play anim then idle
                let name = LowPolyHead.animName(for: activity)
                q.interrupt(with: [
                    (clip: name, action: nil),
                ], thenIdle: "idle2")
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

        // ── Tap → play happy animation then return to idle ──
        if jiggleTrigger != c.lastJiggle && c.hasCustomModel {
            c.lastJiggle = jiggleTrigger
            if let q = c.animQueue {
                q.interrupt(with: [(clip: "happy", action: nil)], thenIdle: "idle2")
            }
        } else if jiggleTrigger != c.lastJiggle {
            // Procedural chibi fallback — scale jiggle
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
                ch.runAction(squish, forKey: "jiggle")
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

        // Apply texture — load dog.png from same folder and apply to all materials
        let modelDir = (path as NSString).deletingLastPathComponent
        func applyDogTexture(_ n: SCNNode) {
            if let geo = n.geometry {
                let texPath = modelDir + "/dog.png"
                if let img = NSImage(contentsOfFile: texPath) {
                    for mat in geo.materials {
                        mat.diffuse.contents = img
                        mat.lightingModel = .phong
                    }
                }
            }
            for c in n.childNodes { applyDogTexture(c) }
        }
        applyDogTexture(character)

        // Blender DAE is Z-up → rotate to Y-up
        if path.hasSuffix(".dae") {
            character.eulerAngles.x = -CGFloat.pi / 2
        }

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

        // Eyes use the same dog.png texture — no override needed for dae models

        // Store base scale and initial rotation for clamping
        context.coordinator.baseScale = fitScale
        context.coordinator.savedEuler = character.eulerAngles
        context.coordinator.hasCustomModel = true

        // Load separate animation clips from same folder as the model
        let animDir = (path as NSString).deletingLastPathComponent
        context.coordinator.animClips = LowPolyHead.loadClips(from: animDir)

        // Find the bone node that animations target (chest node)
        func findNode(named target: String, in node: SCNNode) -> SCNNode? {
            if node.name == target { return node }
            for c in node.childNodes {
                if let found = findNode(named: target, in: c) { return found }
            }
            return nil
        }
        // Play on petArmat (armature root) so all bones get animated including feet
        context.coordinator.animTargetNode =
            findNode(named: "petArmat", in: character)
            ?? findNode(named: "hips", in: character)
            ?? findNode(named: "chest", in: character)

        // Strip all baked animations
        func stripAllAnims(_ n: SCNNode) {
            for key in n.animationKeys { n.removeAnimation(forKey: key) }
            for c in n.childNodes { stripAllAnims(c) }
        }
        stripAllAnims(character)

        // Save anim target rotation for clamping
        if let at = context.coordinator.animTargetNode {
            context.coordinator.savedAnimTargetEuler = at.eulerAngles
        }

        // Create animation queue
        context.coordinator.animQueue = AnimationQueue(
            target: context.coordinator.animTargetNode,
            clips: context.coordinator.animClips
        )

        // Play initial idle
        context.coordinator.animQueue?.loop("idle2")

        // Listen for edge hits: dmg → jump-turn → walk
        let clips = context.coordinator.animClips
        let queue = context.coordinator.animQueue
        context.coordinator.edgeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BuddyEdgeHit"),
            object: nil, queue: .main
        ) { [weak character, weak queue] notif in
            guard let charNode = character, let q = queue,
                  let dir = notif.userInfo?["direction"] as? CGFloat else { return }
            let jumpDur = clips["jump"]?.duration ?? 0.8
            let targetY: CGFloat = dir > 0 ? CGFloat.pi / 2 : -CGFloat.pi / 2
            q.interrupt(with: [
                (clip: "dmg1", action: nil),
                (clip: "jump", action: {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = jumpDur
                    charNode.eulerAngles.y = targetY
                    SCNTransaction.commit()
                }),
            ], thenIdle: "walk")
        }

        // On land: falls1 → wakesup1 → idle2
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BuddyLanded"),
            object: nil, queue: .main
        ) { [weak queue] _ in
            queue?.interrupt(with: [
                (clip: "falls1", action: nil),
                (clip: "wakesup1", action: nil),
            ], thenIdle: "idle2")
        }

        // Test clip player — menu bar → Test Clips
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BuddyTestClip"),
            object: nil, queue: .main
        ) { [weak queue] notif in
            guard let q = queue,
                  let clipName = notif.userInfo?["clip"] as? String else { return }
            q.interrupt(with: [(clip: clipName, action: nil)], thenIdle: "idle2")
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

    // MARK: - Animation Clip Player

    /// Load all animation clips from the anims/ folder
    static func loadClips(from dir: String) -> [String: SCNAnimation] {
        var clips: [String: SCNAnimation] = [:]
        for (name, info) in clipMap {
            let path = dir + "/" + info.filename
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let src = SCNSceneSource(data: data, options: nil) else { continue }
            // Find the petArmat animation container (has the full body anim)
            let animIDs = src.identifiersOfEntries(withClass: CAAnimation.self)
            let targetID = animIDs.first(where: { $0.contains("petArmat") && $0.starts(with: "action_container") })
                ?? animIDs.first(where: { $0.contains("petArmat") })
                ?? animIDs.first(where: { !$0.contains("eyes") })
            if let id = targetID,
               let caAnim = src.entryWithIdentifier(id, withClass: CAAnimation.self),
               caAnim.duration > 0 {
                let anim = SCNAnimation(caAnimation: caAnim)
                anim.repeatCount = info.loops ? .infinity : 1
                clips[name] = anim
            }
        }
        return clips
    }

    /// Play a named clip on a node
    static func playClip(_ name: String, on node: SCNNode, clips: [String: SCNAnimation],
                         completion: (() -> Void)? = nil) {
        guard let anim = clips[name] else { return }
        // Remove current animation
        node.removeAnimation(forKey: "currentClip")
        // Add new
        let player = SCNAnimationPlayer(animation: anim)
        node.addAnimationPlayer(player, forKey: "currentClip")
        player.play()

        // If one-shot, fire completion after duration
        if let info = clipMap[name], !info.loops, let cb = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + anim.duration) {
                cb()
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
