import AppKit
import AVFoundation

class FloatingPanel: NSPanel {
    private var velocity: CGFloat = 0
    private var fallTimer: Timer?
    private var groundY: CGFloat = 0
    private var landPlayer: AVAudioPlayer?
    private var hasPlayedLandSound = false

    // Walking
    private var walkTimer: Timer?
    private(set) var walkDirection: CGFloat = -1 // -1 = left, 1 = right
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

    private var dragStart: NSPoint?

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        // Only allow move after 5px drag threshold
        if let start = dragStart {
            let now = NSEvent.mouseLocation
            let dist = hypot(now.x - start.x, now.y - start.y)
            if dist > 5 {
                isMovableByWindowBackground = true
            }
        }
        super.mouseDragged(with: event)
    }

    // MARK: - Gravity

    override func mouseUp(with event: NSEvent) {
        isMovableByWindowBackground = true // reset for next drag
        dragStart = nil
        super.mouseUp(with: event)
        if gravityEnabled { startFalling() }
    }

    private func startFalling() {
        guard let _ = NSScreen.main else { return }
        groundY = 0 // absolute bottom — bezel is the floor

        // Already on the ground
        if frame.origin.y <= groundY + 1 {
            setFrameOrigin(NSPoint(x: frame.origin.x, y: groundY))
            return
        }

        velocity = 0
        hasPlayedLandSound = false
        NotificationCenter.default.post(name: NSNotification.Name("BuddyDropped"), object: nil)
        fallTimer?.invalidate()
        fallTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let gravity: CGFloat = -2200   // px/s² — snappy fall
        let dt: CGFloat = 1.0 / 60.0
        let bounceDamp: CGFloat = 0.35  // energy kept per bounce

        velocity += gravity * dt
        var y = frame.origin.y + velocity * dt

        if y <= groundY {
            y = groundY
            velocity = -velocity * bounceDamp

            // First impact: sound + fall animation
            if !hasPlayedLandSound {
                hasPlayedLandSound = true
                playLandSound()
                NotificationCenter.default.post(name: NSNotification.Name("BuddyLanded"), object: nil)
            }

            // Stop when bounce is tiny
            if abs(velocity) < 15 {
                velocity = 0
                fallTimer?.invalidate()
                fallTimer = nil
            }
        }

        setFrameOrigin(NSPoint(x: frame.origin.x, y: y))
    }

    private func playLandSound() {
        // Look for error/land sound in current persona's sound folder
        let cwd = FileManager.default.currentDirectoryPath
        let dirs = [
            cwd + "/sounds/frenchie",  // TODO: get current persona dynamically
            cwd + "/sounds",
        ]
        for dir in dirs {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                if let errorFile = files.first(where: { $0.lowercased().contains("error") }) {
                    let url = URL(fileURLWithPath: dir + "/" + errorFile)
                    if let p = try? AVAudioPlayer(contentsOf: url) {
                        p.volume = 0.5
                        p.play()
                        landPlayer = p
                        return
                    }
                }
            }
        }
        // Fallback: system sound
        NSSound.beep()
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
            let oldDir = walkDirection
            walkDirection = 1
            if oldDir != walkDirection { pauseForTurn(newDirection: walkDirection) }
        } else if x >= maxX {
            x = maxX
            let oldDir = walkDirection
            walkDirection = -1
            if oldDir != walkDirection { pauseForTurn(newDirection: walkDirection) }
        }

        setFrameOrigin(NSPoint(x: x, y: frame.origin.y))
    }

    private func pauseForTurn(newDirection: CGFloat) {
        // Pause walking during jump-turn
        walkTimer?.invalidate()
        walkTimer = nil
        onEdgeHit?(newDirection)

        // Resume walking after jump animation (0.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
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
