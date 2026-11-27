import Foundation

public enum LastExit: Equatable, Sendable {
    case code(Int)
    case neverRan
    case signal
    case unknown
}

/// Load state and last exit of a job, read from `launchctl print gui/<uid>/<label>`.
public struct JobState: Equatable, Sendable {
    public var isLoaded: Bool
    public var lastExit: LastExit

    public init(isLoaded: Bool, lastExit: LastExit) {
        self.isLoaded = isLoaded
        self.lastExit = lastExit
    }

    public var isFailure: Bool {
        guard isLoaded else { return false }
        switch lastExit {
        case .code(let code): return code != 0
        case .signal: return true
        case .neverRan, .unknown: return false
        }
    }

    /// The `launchctl print` format is undocumented, so only the first match of each field counts.
    public static func parse(launchctlPrint output: String) -> JobState {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        // The service block opens on an unindented "gui/501/label = {" line.
        let isLoaded = lines.contains { line in
            guard let first = line.first, !first.isWhitespace else { return false }
            return line.contains(" = {")
        }
        let fields = lines.map { $0.trimmingCharacters(in: .whitespaces) }

        if let exitLine = fields.first(where: { $0.hasPrefix("last exit code = ") }) {
            let value = exitLine.dropFirst("last exit code = ".count)
            if value.contains("never exited") {
                return JobState(isLoaded: isLoaded, lastExit: .neverRan)
            }
            let number = value.prefix { $0 == "-" || $0.isNumber }
            return JobState(isLoaded: isLoaded, lastExit: Int(number).map(LastExit.code) ?? .unknown)
        }
        guard isLoaded else { return JobState(isLoaded: false, lastExit: .unknown) }
        if fields.contains(where: { $0.hasPrefix("last terminating signal = ") }) {
            return JobState(isLoaded: true, lastExit: .signal)
        }
        return JobState(isLoaded: true, lastExit: .neverRan)
    }
}
