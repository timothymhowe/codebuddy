import Foundation
import Combine

// MARK: - Activity

enum BuddyActivity: String, Codable, Equatable {
    case idle, thinking, coding, running, error, success
}

// MARK: - Wire types

struct BuddyEvent: Codable {
    let state: BuddyActivity
    let context: String?
    let mentioned: Bool?
    let message: String?
}

struct BuddyConfig: Codable {
    var selectedPersonaId: String
}

// MARK: - State

class BuddyState: ObservableObject {
    @Published var currentState: BuddyActivity = .idle
    @Published var lastContext: String?
    @Published var lastMessage: String?
    @Published var selectedPersona: Persona

    private var fileMonitor: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private let stateFilePath: String
    private let configFilePath: String
    private var lastModified: Date?

    init() {
        let dir = NSHomeDirectory() + "/.codebuddy"
        stateFilePath = dir + "/state.json"
        configFilePath = dir + "/config.json"

        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        // Load saved persona or default to Mochi
        if let data = try? Data(contentsOf: URL(fileURLWithPath: configFilePath)),
           let config = try? JSONDecoder().decode(BuddyConfig.self, from: data) {
            selectedPersona = Persona.find(config.selectedPersonaId)
        } else {
            selectedPersona = Persona.all[0]
        }

        // Ensure state file exists
        if !FileManager.default.fileExists(atPath: stateFilePath) {
            if let data = try? JSONEncoder().encode(BuddyEvent(state: .idle, context: nil, mentioned: nil, message: nil)) {
                try? data.write(to: URL(fileURLWithPath: stateFilePath))
            }
        }
    }

    // MARK: - Persona selection

    func selectPersona(_ persona: Persona) {
        selectedPersona = persona
        if let data = try? JSONEncoder().encode(BuddyConfig(selectedPersonaId: persona.id)) {
            try? data.write(to: URL(fileURLWithPath: configFilePath))
        }
    }

    // MARK: - File watching

    func startWatching() {
        let fd = open(stateFilePath, O_EVTONLY)
        if fd >= 0 {
            fileMonitor = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .attrib],
                queue: .main
            )
            fileMonitor?.setEventHandler { [weak self] in self?.readState() }
            fileMonitor?.setCancelHandler { close(fd) }
            fileMonitor?.resume()
        }

        // Fallback poll
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.readStateIfChanged()
        }

        readState()
    }

    private func readStateIfChanged() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: stateFilePath),
              let modified = attrs[.modificationDate] as? Date else { return }
        if lastModified == nil || modified > lastModified! {
            readState()
        }
    }

    private func readState() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: stateFilePath)),
              let event = try? JSONDecoder().decode(BuddyEvent.self, from: data) else { return }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: stateFilePath) {
            lastModified = attrs[.modificationDate] as? Date
        }

        guard event.state != currentState else { return }

        DispatchQueue.main.async { [weak self] in
            self?.currentState = event.state
            self?.lastContext = event.context
            self?.lastMessage = (event.message?.isEmpty == false) ? event.message : nil

            // Auto-reset transient states
            if event.state == .success || event.state == .error {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if self?.currentState == event.state {
                        self?.currentState = .idle
                    }
                }
            }
        }
    }

    deinit {
        fileMonitor?.cancel()
        pollTimer?.invalidate()
    }
}
