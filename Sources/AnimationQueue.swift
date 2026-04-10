import SceneKit

/// Sequential animation queue — plays clips one after another, supports interruption
class AnimationQueue {
    private var queue: [(clip: String, action: (() -> Void)?)] = []
    private var isPlaying = false
    private weak var targetNode: SCNNode?
    private var clips: [String: SCNAnimation] = [:]
    private var currentTimer: Timer?
    private var currentAnimKey: String?

    init(target: SCNNode?, clips: [String: SCNAnimation]) {
        self.targetNode = target
        self.clips = clips
    }

    /// Clear the queue and stop current animation
    func clear() {
        queue.removeAll()
        isPlaying = false
        currentTimer?.invalidate()
        currentTimer = nil
        if let key = currentAnimKey {
            targetNode?.removeAnimation(forKey: key, blendOutDuration: 0.15)
            currentAnimKey = nil
        }
    }

    /// Add a clip to the queue with an optional side-effect to run when it starts
    func enqueue(_ clipName: String, action: (() -> Void)? = nil) {
        queue.append((clip: clipName, action: action))
        if !isPlaying { playNext() }
    }

    /// Add a looping clip — plays until interrupted
    func loop(_ clipName: String, action: (() -> Void)? = nil) {
        guard let node = targetNode, let anim = clips[clipName] else { return }
        clear()
        isPlaying = true
        action?()

        let animCopy = anim.copy() as! SCNAnimation
        animCopy.blendInDuration = 0.15
        let key = "clip_\(clipName)"
        let player = SCNAnimationPlayer(animation: animCopy)
        node.addAnimationPlayer(player, forKey: key)
        player.play()
        currentAnimKey = key
    }

    /// Interrupt current queue with a new sequence, then resume idle
    func interrupt(with sequence: [(clip: String, action: (() -> Void)?)], thenIdle: String = "idle2") {
        clear()
        for item in sequence {
            enqueue(item.clip, action: item.action)
        }
        enqueue(thenIdle)
    }

    private func playNext() {
        guard let node = targetNode, !queue.isEmpty else {
            isPlaying = false
            return
        }

        isPlaying = true
        let item = queue.removeFirst()

        guard let anim = clips[item.clip] else {
            // Skip unknown clips
            playNext()
            return
        }

        // Run side-effect
        item.action?()

        // Crossfade: add new animation FIRST with blend-in, then fade out old
        let blendDur: CGFloat = 0.15
        let info = LowPolyHead.clipMap[item.clip]
        let loops = info?.loops ?? false

        // Clone anim so we can set blend without affecting the cached copy
        let animCopy = anim.copy() as! SCNAnimation
        animCopy.blendInDuration = blendDur

        // Start new animation on a fresh key
        let newKey = "clip_\(item.clip)"
        let player = SCNAnimationPlayer(animation: animCopy)
        node.addAnimationPlayer(player, forKey: newKey)
        player.play()

        // Fade out previous animation
        if let prevKey = currentAnimKey {
            node.removeAnimation(forKey: prevKey, blendOutDuration: blendDur)
        }
        currentAnimKey = newKey

        if loops {
            // Loop runs until clear() is called
        } else {
            currentTimer = Timer.scheduledTimer(withTimeInterval: anim.duration, repeats: false) { [weak self] _ in
                self?.playNext()
            }
        }
    }
}
