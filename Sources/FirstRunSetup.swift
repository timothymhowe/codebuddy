import Foundation

/// On every launch:
/// - refreshes ~/.codebuddy/hooks/ from the bundle so upgrades pick up new hook logic
/// - installs ~/.claude/commands/codebuddy.md slash command
/// - merges hooks into ~/.claude/settings.json if none of ours are there yet
enum FirstRunSetup {
    static func run() {
        syncHooks()
        installSkill()
        mergeClaudeHooks()
    }

    // MARK: hooks dir

    private static func syncHooks() {
        let fm = FileManager.default
        let hooksDir = NSHomeDirectory() + "/.codebuddy/hooks"
        try? fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)

        guard let res = Bundle.main.resourcePath else { return }
        for script in ["buddy-hook.sh", "set-state.sh"] {
            let src = res + "/hooks/" + script
            let dst = hooksDir + "/" + script
            guard fm.fileExists(atPath: src) else { continue }
            if fm.fileExists(atPath: dst) { try? fm.removeItem(atPath: dst) }
            try? fm.copyItem(atPath: src, toPath: dst)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst)
        }

        let stateFile = NSHomeDirectory() + "/.codebuddy/state.json"
        if !fm.fileExists(atPath: stateFile) {
            let seed = #"{"state":"idle","context":null,"mentioned":false}"#
            try? seed.write(toFile: stateFile, atomically: true, encoding: .utf8)
        }
    }

    // MARK: slash command

    private static func installSkill() {
        let fm = FileManager.default
        let dir = NSHomeDirectory() + "/.claude/commands"
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        guard let src = Bundle.main.resourcePath.map({ $0 + "/claude-commands/codebuddy.md" }),
              fm.fileExists(atPath: src) else { return }
        let dst = dir + "/codebuddy.md"
        if fm.fileExists(atPath: dst) { try? fm.removeItem(atPath: dst) }
        try? fm.copyItem(atPath: src, toPath: dst)
    }

    // MARK: Claude Code hooks

    /// Registers buddy-hook.sh in ~/.claude/settings.json on first run only. If
    /// the user later removes our hooks, we stay out of their way — they can
    /// delete ~/.codebuddy/.hooks-registered to force re-registration.
    private static func mergeClaudeHooks() {
        let fm = FileManager.default
        let marker = NSHomeDirectory() + "/.codebuddy/.hooks-registered"
        if fm.fileExists(atPath: marker) { return }

        let claudeDir = NSHomeDirectory() + "/.claude"
        let path = claudeDir + "/settings.json"
        try? fm.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)

        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = obj
            if let raw = String(data: data, encoding: .utf8), raw.contains("buddy-hook") {
                // Already wired up some other way — don't double-register.
                try? "".write(toFile: marker, atomically: true, encoding: .utf8)
                return
            }
        }

        // permissions.allow  (so Claude Code auto-approves the hook)
        var permissions = settings["permissions"] as? [String: Any] ?? [:]
        var allow = permissions["allow"] as? [String] ?? []
        let rule = "Bash(bash ~/.codebuddy/hooks/buddy-hook.sh*)"
        if !allow.contains(rule) { allow.append(rule) }
        permissions["allow"] = allow
        settings["permissions"] = permissions

        // hooks — append our entries next to whatever is already there
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let buddy: [String: [[String: Any]]] = [
            "PreToolUse": [
                ["matcher": "Edit|Write|MultiEdit|NotebookEdit",
                 "hooks": [["type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh coding"]]],
                ["matcher": "Bash",
                 "hooks": [["type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh running"]]],
                ["matcher": "Grep|Glob|Read|Agent|WebSearch|WebFetch",
                 "hooks": [["type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh thinking"]]],
            ],
            "PostToolUse":   [["hooks": [["type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh thinking"]]]],
            "Notification":  [["hooks": [["type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh success"]]]],
            "Stop":          [["hooks": [["type": "command", "command": "bash ~/.codebuddy/hooks/buddy-hook.sh idle"]]]],
        ]
        for (event, entries) in buddy {
            var existing = hooks[event] as? [[String: Any]] ?? []
            existing.append(contentsOf: entries)
            hooks[event] = existing
        }
        settings["hooks"] = hooks

        guard let out = try? JSONSerialization.data(withJSONObject: settings,
                                                    options: [.prettyPrinted]) else { return }
        try? out.write(to: URL(fileURLWithPath: path))
        try? "".write(toFile: marker, atomically: true, encoding: .utf8)
    }
}
