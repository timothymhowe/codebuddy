import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel!
    var statusItem: NSStatusItem!
    let buddyState = BuddyState()

    private var walkObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        setupMenuBar()
        buddyState.startWatching()

        // Watch for state changes to trigger walking
        walkObserver = buddyState.$currentState.sink { [weak self] state in
            guard let self = self else { return }
            if state == .coding {
                // Delay walk until jump animation finishes (0.8s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if self.buddyState.currentState == .coding {
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
        let avatarView = AvatarView(state: buddyState)

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
        let avatarView = AvatarView(state: buddyState)
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
}
