import Foundation

public struct Job: Identifiable, Equatable, Sendable {
    public var label: String
    public var plistURL: URL
    public var schedule: String
    public var outLog: String?
    public var errorLog: String?
    public var state: JobState

    public var id: String { label }

    public init(
        label: String, plistURL: URL, schedule: String,
        outLog: String? = nil, errorLog: String? = nil, state: JobState
    ) {
        self.label = label
        self.plistURL = plistURL
        self.schedule = schedule
        self.outLog = outLog
        self.errorLog = errorLog
        self.state = state
    }

    /// Menu row, e.g. `com.me.backup  ·  on · daily 09:00 · exit 0`.
    public var summary: String {
        "\(label)  ·  \(state.isLoaded ? "on" : "off") · \(schedule) · \(exitWords)"
    }

    var exitWords: String {
        guard state.isLoaded else { return "not loaded" }
        return switch state.lastExit {
        case .code(let code): "exit \(code)"
        case .neverRan: "not run yet"
        case .signal: "killed by signal"
        case .unknown: "exit unknown"
        }
    }

    public var systemImage: String {
        if !state.isLoaded { return "pause.circle" }
        return state.isFailure ? "xmark.octagon.fill" : "checkmark.circle"
    }
}

public enum JobAction: Sendable {
    case runNow, turnOn, turnOff

    /// Turning on or off loads or unloads for this login session only; the plist stays as is.
    public func launchctlArguments(for job: Job, domain: String) -> [String] {
        switch self {
        case .runNow: ["kickstart", "\(domain)/\(job.label)"]
        case .turnOn: ["bootstrap", domain, job.plistURL.path]
        case .turnOff: ["bootout", domain, job.plistURL.path]
        }
    }
}

/// Reads every plist in a LaunchAgents folder and asks launchctl for each job's state.
public struct JobLoader: Sendable {
    /// Vendor agents the user didn't write.
    public static let hiddenPrefixes = [
        "com.apple.", "com.google.", "com.microsoft.", "com.github.facebook.", "com.adobe.",
        "com.dropbox.", "com.spotify.", "com.docker.", "com.jetbrains.", "homebrew.",
        "org.mozilla.", "us.zoom.",
    ]

    public static let userDomain = "gui/\(getuid())"

    public var agentsDirectory: URL
    /// Returns `launchctl print` output for a label.
    public var printJob: @Sendable (String) -> String

    public init(agentsDirectory: URL, printJob: @escaping @Sendable (String) -> String) {
        self.agentsDirectory = agentsDirectory
        self.printJob = printJob
    }

    public static func isHidden(_ label: String) -> Bool {
        hiddenPrefixes.contains { label.hasPrefix($0) }
    }

    public func load() -> [Job] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: agentsDirectory, includingPropertiesForKeys: nil
        )) ?? []
        return urls
            .filter { $0.pathExtension == "plist" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap(job)
    }

    private func job(at url: URL) -> Job? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let label = plist["Label"] as? String,
              !Self.isHidden(label)
        else { return nil }
        return Job(
            label: label,
            plistURL: url,
            schedule: Schedule.words(for: plist),
            outLog: plist["StandardOutPath"] as? String,
            errorLog: plist["StandardErrorPath"] as? String,
            state: JobState.parse(launchctlPrint: printJob(label))
        )
    }
}
