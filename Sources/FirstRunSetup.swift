import Foundation

/// Ensures ~/.codebuddy/ exists and has an up-to-date buddy-hook.sh.
/// The app bundle carries hooks/buddy-hook.sh in Resources/; on launch we copy
/// it into ~/.codebuddy/hooks/ so Claude Code can call it. We overwrite every
/// launch so upgrades pick up new hook logic automatically.
enum FirstRunSetup {
    static func run() {
        let home = NSHomeDirectory()
        let codebuddyDir = home + "/.codebuddy"
        let hooksDir = codebuddyDir + "/hooks"
        let fm = FileManager.default

        try? fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)

        // Copy bundled hook script → ~/.codebuddy/hooks/buddy-hook.sh
        if let src = Bundle.main.resourcePath.map({ $0 + "/hooks/buddy-hook.sh" }),
           fm.fileExists(atPath: src) {
            let dst = hooksDir + "/buddy-hook.sh"
            if fm.fileExists(atPath: dst) { try? fm.removeItem(atPath: dst) }
            try? fm.copyItem(atPath: src, toPath: dst)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst)
        }

        // Seed default state file if missing
        let stateFile = codebuddyDir + "/state.json"
        if !fm.fileExists(atPath: stateFile) {
            let seed = #"{"state":"idle","context":null,"mentioned":false}"#
            try? seed.write(toFile: stateFile, atomically: true, encoding: .utf8)
        }
    }
}
