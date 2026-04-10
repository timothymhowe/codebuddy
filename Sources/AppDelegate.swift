import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel!
    var statusItem: NSStatusItem!
    let buddyState = BuddyState()
    let settings = BuddySettings()

    private var walkObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        setupMenuBar()
        buddyState.startWatching()

        // Watch for state changes to trigger walking
        walkObserver = buddyState.$currentState.sink { [weak self] state in
            guard let self = self else { return }
            if state == .coding && self.settings.walkEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if self.buddyState.currentState == .coding && self.settings.walkEnabled {
                        self.panel.startWalking()
                    }
                }
            } else {
                self.panel.stopWalking()
            }
        }
    }

    // MARK: - Panel

    private func setupPanel() {
        let avatarView = AvatarView(state: buddyState, settings: settings)

        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 180),
            backing: .buffered,
            defer: false
        )

        panel.contentView = NSHostingView(rootView: avatarView)
        panel.backgroundColor = .clear
        panel.isOpaque = false

        // Slammed to absolute bottom of display
        if let screen = NSScreen.main {
            let x = screen.frame.maxX - 170
            panel.setFrameOrigin(NSPoint(x: x, y: 0))
        }

        // When walking dog hits screen edge, trigger jump-turn on 3d model
        panel.onEdgeHit = { [weak self] newDirection in
            guard let self = self else { return }
            // Post notification so LowPolyHead can pick it up
            NotificationCenter.default.post(
                name: NSNotification.Name("BuddyEdgeHit"),
                object: nil,
                userInfo: ["direction": newDirection]
            )
        }

        panel.orderFront(nil)
    }

    func refreshPanel() {
        let avatarView = AvatarView(state: buddyState, settings: settings)
        panel.contentView = NSHostingView(rootView: avatarView)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "sparkle",
                accessibilityDescription: "CodeBuddy"
            )
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Current persona header
        let current = buddyState.selectedPersona
        let nameItem = NSMenuItem(
            title: "\(current.name)  \(current.subtitle)",
            action: nil, keyEquivalent: ""
        )
        nameItem.isEnabled = false
        menu.addItem(nameItem)

        let stars = String(repeating: "★", count: current.rarity.stars)
        let rarityItem = NSMenuItem(
            title: "\(stars)  \(current.rarity.label)  ·  \(current.ability.label)",
            action: nil, keyEquivalent: ""
        )
        rarityItem.isEnabled = false
        menu.addItem(rarityItem)

        let loreItem = NSMenuItem(title: current.lore, action: nil, keyEquivalent: "")
        loreItem.isEnabled = false
        menu.addItem(loreItem)

        menu.addItem(NSMenuItem.separator())

        // Persona picker
        let personaMenu = NSMenu()
        let grouped = Dictionary(grouping: Persona.all) { $0.rarity }

        for rarity in Rarity.allCases {
            guard let personas = grouped[rarity] else { continue }

            let header = NSMenuItem(
                title: "── \(rarity.label) \(String(repeating: "★", count: rarity.stars)) ──",
                action: nil, keyEquivalent: ""
            )
            header.isEnabled = false
            personaMenu.addItem(header)

            for persona in personas {
                let check = persona.id == current.id ? "✓ " : "   "
                let item = NSMenuItem(
                    title: "\(check)\(persona.name)  \(persona.subtitle)  ·  \(persona.ability.label)",
                    action: #selector(selectPersona(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = persona.id
                personaMenu.addItem(item)
            }
        }

        let switchItem = NSMenuItem(title: "Switch Persona", action: nil, keyEquivalent: "")
        switchItem.submenu = personaMenu
        menu.addItem(switchItem)

        menu.addItem(NSMenuItem.separator())

        // Test state buttons
        let testMenu = NSMenu()
        for activity in ["idle", "thinking", "coding", "running", "error", "success"] {
            let item = NSMenuItem(
                title: activity,
                action: #selector(testState(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = activity
            testMenu.addItem(item)
        }
        let testItem = NSMenuItem(title: "Test States", action: nil, keyEquivalent: "")
        testItem.submenu = testMenu
        menu.addItem(testItem)

        // Test individual animation clips
        let clipMenu = NSMenu()
        for name in ["idle1","idle2","jump","walk","run","run2","falls1","falls2","falls3",
                      "wakesup1","wakesup2","wakesup3","no","yes","waving","happy",
                      "attack1","attack2","dmg1","dmg2"] {
            let item = NSMenuItem(title: name, action: #selector(testClip(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            clipMenu.addItem(item)
        }
        let clipItem = NSMenuItem(title: "Test Clips", action: nil, keyEquivalent: "")
        clipItem.submenu = clipMenu
        menu.addItem(clipItem)

        menu.addItem(NSMenuItem.separator())

        // Settings submenu
        let settingsMenu = NSMenu()
        let toggles: [(String, Bool, Selector)] = [
            ("Voice", settings.voiceEnabled, #selector(toggleVoice)),
            ("Speech Bubbles", settings.speechBubbleEnabled, #selector(toggleBubbles)),
            ("Draggable", settings.draggable, #selector(toggleDraggable)),
            ("Walk on Coding", settings.walkEnabled, #selector(toggleWalk)),
            ("Gravity", settings.gravityEnabled, #selector(toggleGravity)),
        ]
        for (title, enabled, action) in toggles {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.state = enabled ? .on : .off
            settingsMenu.addItem(item)
        }
        // Volume
        settingsMenu.addItem(NSMenuItem.separator())
        let volLabel = NSMenuItem(title: "Volume: \(Int(settings.volume * 100))%", action: nil, keyEquivalent: "")
        volLabel.isEnabled = false
        settingsMenu.addItem(volLabel)
        for (label, val) in [("Mute", Float(0)), ("25%", Float(0.25)), ("50%", Float(0.5)), ("75%", Float(0.75)), ("100%", Float(1.0))] {
            let item = NSMenuItem(title: label, action: #selector(setVolume(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = val
            item.state = abs(settings.volume - val) < 0.05 ? .on : .off
            settingsMenu.addItem(item)
        }

        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit CodeBuddy",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    @objc private func selectPersona(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        buddyState.selectPersona(Persona.find(id))
        statusItem.menu = buildMenu()
        refreshPanel()
    }

    @objc private func testState(_ sender: NSMenuItem) {
        guard let stateStr = sender.representedObject as? String,
              let activity = BuddyActivity(rawValue: stateStr) else { return }
        buddyState.currentState = activity
    }

    @objc private func testClip(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("BuddyTestClip"),
            object: nil,
            userInfo: ["clip": name]
        )
    }

    // MARK: - Settings toggles

    @objc private func toggleVoice() {
        settings.voiceEnabled.toggle()
        statusItem.menu = buildMenu()
    }
    @objc private func toggleBubbles() {
        settings.speechBubbleEnabled.toggle()
        statusItem.menu = buildMenu()
    }
    @objc private func toggleDraggable() {
        settings.draggable.toggle()
        panel.isMovableByWindowBackground = settings.draggable
        statusItem.menu = buildMenu()
    }
    @objc private func toggleWalk() {
        settings.walkEnabled.toggle()
        if !settings.walkEnabled { panel.stopWalking() }
        statusItem.menu = buildMenu()
    }
    @objc private func toggleGravity() {
        settings.gravityEnabled.toggle()
        panel.gravityEnabled = settings.gravityEnabled
        statusItem.menu = buildMenu()
    }
    @objc private func setVolume(_ sender: NSMenuItem) {
        guard let vol = sender.representedObject as? Float else { return }
        settings.volume = vol
        statusItem.menu = buildMenu()
    }
}
