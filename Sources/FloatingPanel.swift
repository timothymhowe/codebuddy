import AppKit
import AVFoundation

class FloatingPanel: NSPanel {
    private var velY: CGFloat = 0
    private var fallTimer: Timer?
    private var landPlayer: AVAudioPlayer?
    private var hasPlayedLandSound = false
    private var dragStart: NSPoint?

    // Walking
    private var walkTimer: Timer?
    private(set) var walkDirection: CGFloat = -1
    private(set) var isWalking = false
    var onEdgeHit: ((_ newDirection: CGFloat) -> Void)?
    var gravityEnabled: Bool = true

    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: backing,
            defer: flag
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hasShadow = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        fallTimer?.invalidate()
        fallTimer = nil
        dragStart = NSEvent.mouseLocation
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if let start = dragStart {
            if hypot(NSEvent.mouseLocation.x - start.x, NSEvent.mouseLocation.y - start.y) > 5 {
                isMovableByWindowBackground = true
            }
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        isMovableByWindowBackground = true
        dragStart = nil
        super.mouseUp(with: event)
        if gravityEnabled { startFalling() }
    }

    // MARK: - Gravity (straight down)

    private func startFalling() {
        if frame.origin.y <= 1 {
            setFrameOrigin(NSPoint(x: frame.origin.x, y: 0))
            return
        }

        velY = 0
        hasPlayedLandSound = false
        NotificationCenter.default.post(name: NSNotification.Name("BuddyDropped"), object: nil)
        fallTimer?.invalidate()
        fallTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.fallTick()
        }
    }

    private func fallTick() {
        let gravity: CGFloat = -3000
        let dt: CGFloat = 1.0 / 60.0

        velY += gravity * dt
        var y = frame.origin.y + velY * dt

        if y <= 0 {
            y = 0
            velY = 0
            fallTimer?.invalidate()
            fallTimer = nil

            if !hasPlayedLandSound {
                hasPlayedLandSound = true
                playLandSound()
                NotificationCenter.default.post(name: NSNotification.Name("BuddyLanded"), object: nil)
                DispatchQueue.global().async {
                    let task = Process()
                    task.launchPath = "/bin/bash"
                    task.arguments = [NSHomeDirectory() + "/.codebuddy/hooks/buddy-hook.sh", "dropped"]
                    try? task.run()
                    task.waitUntilExit()
                }
            }
        }

        setFrameOrigin(NSPoint(x: frame.origin.x, y: y))
    }

    private func playLandSound() {
        let cwd = FileManager.default.currentDirectoryPath
        let bundle = Bundle.main.resourcePath ?? ""
        for dir in [bundle + "/sounds/frenchie", bundle + "/sounds",
                    cwd + "/sounds/frenchie", cwd + "/sounds"] {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir),
               let f = files.first(where: { $0.lowercased().contains("error") }),
               let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: dir + "/" + f)) {
                p.volume = 0.15
                p.play()
                landPlayer = p
                return
            }
        }
    }

    // MARK: - Walking

    func startWalking() {
        guard !isWalking else { return }
        isWalking = true
        walkTimer?.invalidate()
        walkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.walkTick()
        }
    }

    func stopWalking() {
        isWalking = false
        walkTimer?.invalidate()
        walkTimer = nil
    }

    private func walkTick() {
        guard let screen = NSScreen.main else { return }
        let speed: CGFloat = 1.2
        var x = frame.origin.x + speed * walkDirection
        let minX = screen.frame.minX
        let maxX = screen.frame.maxX - frame.width
        if x <= minX {
            x = minX
            let old = walkDirection; walkDirection = 1
            if old != walkDirection { pauseForTurn(newDirection: walkDirection) }
        } else if x >= maxX {
            x = maxX
            let old = walkDirection; walkDirection = -1
            if old != walkDirection { pauseForTurn(newDirection: walkDirection) }
        }
        setFrameOrigin(NSPoint(x: x, y: frame.origin.y))
    }

    private func pauseForTurn(newDirection: CGFloat) {
        walkTimer?.invalidate()
        walkTimer = nil
        onEdgeHit?(newDirection)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self, self.isWalking else { return }
            self.walkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.walkTick()
            }
        }
    }

    deinit {
        fallTimer?.invalidate()
        walkTimer?.invalidate()
    }
}
