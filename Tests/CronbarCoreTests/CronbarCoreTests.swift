import CronbarCore
import Foundation
import Testing

private let fixtures = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
private let plists = fixtures.appending(path: "plists")

private func plist(_ name: String) throws -> [String: Any] {
    let data = try Data(contentsOf: plists.appending(path: "\(name).plist"))
    return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
}

private func launchctlPrint(_ name: String) throws -> String {
    try String(contentsOf: fixtures.appending(path: "launchctl/\(name).txt"), encoding: .utf8)
}

@Suite struct ScheduleTests {
    @Test(arguments: [
        ("daily", "daily 09:00"),
        ("hourly", "hourly at :05"),
        ("weekly", "weekly Mon 08:30"),
        ("monthly", "monthly day 1 06:00"),
        ("yearly", "yearly Dec 25 07:00"),
        ("every-minute", "every minute"),
        ("calendar-array", "daily 09:15 … 17:15 (3×)"),
        ("calendar-mixed", "2 schedules, first: daily 09:00"),
        ("interval-30m", "every 30 min"),
        ("interval-2h", "every 2 h"),
        ("interval-90s", "every 90 s"),
        ("run-at-load", "at login"),
        ("keep-alive", "always running"),
        ("watch", "on file change"),
        ("on-demand", "on demand"),
    ])
    func words(fixture: String, expected: String) throws {
        #expect(Schedule.words(for: try plist(fixture)) == expected)
    }

    @Test func intervalWordsCoverDaysAndSingleUnits() {
        #expect(Schedule.intervalWords(seconds: 86400) == "every day")
        #expect(Schedule.intervalWords(seconds: 172_800) == "every 2 days")
        #expect(Schedule.intervalWords(seconds: 3600) == "every hour")
    }

    @Test func hourWithoutMinuteRunsEachMinuteOfThatHour() {
        #expect(Schedule.words(for: ["StartCalendarInterval": ["Hour": 3]]) == "daily each min of 03:xx")
    }

    @Test func sundayIsZeroOrSeven() {
        #expect(Schedule.words(for: ["StartCalendarInterval": ["Weekday": 7, "Hour": 1, "Minute": 0]]) == "weekly Sun 01:00")
    }

    @Test func emptyCalendarArrayIsOnDemand() {
        #expect(Schedule.words(for: ["StartCalendarInterval": [[String: Any]]()]) == "on demand")
    }

    @Test func keepAliveFalseFallsThrough() {
        #expect(Schedule.words(for: ["KeepAlive": false, "RunAtLoad": true]) == "at login")
    }

    @Test func keepAliveConditionsMeanAlwaysRunning() {
        #expect(Schedule.words(for: ["KeepAlive": ["SuccessfulExit": false]]) == "always running")
    }
}

@Suite struct JobStateTests {
    @Test(arguments: [
        ("loaded-exit0", JobState(isLoaded: true, lastExit: .code(0))),
        ("loaded-never", JobState(isLoaded: true, lastExit: .neverRan)),
        ("loaded-exit78", JobState(isLoaded: true, lastExit: .code(78))),
        ("loaded-signal", JobState(isLoaded: true, lastExit: .signal)),
        ("not-found", JobState(isLoaded: false, lastExit: .unknown)),
    ])
    func parse(fixture: String, expected: JobState) throws {
        #expect(JobState.parse(launchctlPrint: try launchctlPrint(fixture)) == expected)
    }

    @Test func emptyOutputIsNotLoaded() {
        #expect(JobState.parse(launchctlPrint: "") == JobState(isLoaded: false, lastExit: .unknown))
    }

    @Test func nestedBlocksDoNotCountAsLoadedLines() {
        let output = "gui/501/x = {\n\tevent triggers = {\n\t\tfoo = {\n\t\t}\n\t}\n\tlast exit code = 1\n}\n"
        #expect(JobState.parse(launchctlPrint: output) == JobState(isLoaded: true, lastExit: .code(1)))
    }

    @Test func unreadableExitCodeIsUnknown() {
        let output = "gui/501/x = {\n\tlast exit code = weird\n}\n"
        #expect(JobState.parse(launchctlPrint: output).lastExit == .unknown)
    }

    @Test func onlyRealNonZeroExitsOfLoadedJobsAreFailures() {
        #expect(JobState(isLoaded: true, lastExit: .code(1)).isFailure)
        #expect(JobState(isLoaded: true, lastExit: .signal).isFailure)
        #expect(!JobState(isLoaded: true, lastExit: .code(0)).isFailure)
        #expect(!JobState(isLoaded: true, lastExit: .neverRan).isFailure)
        #expect(!JobState(isLoaded: true, lastExit: .unknown).isFailure)
        #expect(!JobState(isLoaded: false, lastExit: .code(1)).isFailure)
    }
}

@Suite struct JobLoaderTests {
    private static func fakePrint(_ label: String) -> String {
        let name = switch label {
        case "com.example.daily": "loaded-exit78"
        case "com.example.interval-30m": "loaded-exit0"
        default: "not-found"
        }
        return (try? launchctlPrint(name)) ?? ""
    }

    private let jobs = JobLoader(agentsDirectory: plists, printJob: fakePrint).load()

    private func job(_ label: String) throws -> Job {
        try #require(jobs.first { $0.label == label })
    }

    @Test func hidesVendorAgents() {
        #expect(!jobs.contains { $0.label == "com.apple.something" })
        #expect(jobs.count == 15)
        #expect(JobLoader.isHidden("homebrew.mxcl.postgresql"))
        #expect(!JobLoader.isHidden("com.example.daily"))
    }

    @Test func summariesShowStateScheduleAndExit() throws {
        #expect(try job("com.example.daily").summary == "com.example.daily  ·  on · daily 09:00 · exit 78")
        #expect(try job("com.example.interval-30m").summary == "com.example.interval-30m  ·  on · every 30 min · exit 0")
        #expect(try job("com.example.hourly").summary == "com.example.hourly  ·  off · hourly at :05 · not loaded")
    }

    @Test func iconsFollowState() throws {
        #expect(try job("com.example.daily").systemImage == "xmark.octagon.fill")
        #expect(try job("com.example.interval-30m").systemImage == "checkmark.circle")
        #expect(try job("com.example.hourly").systemImage == "pause.circle")
    }

    @Test func readsLogPaths() throws {
        let daily = try job("com.example.daily")
        #expect(daily.outLog == "/tmp/example out.log")
        #expect(daily.errorLog == "/tmp/example-err.log")
        #expect(try job("com.example.hourly").outLog == nil)
    }

    @Test func emptyFolderHasNoJobs() throws {
        let empty = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        #expect(JobLoader(agentsDirectory: empty, printJob: { _ in "" }).load().isEmpty)
    }

    @Test func exitWordsForEachLastExit() {
        func summary(_ exit: LastExit) -> String {
            Job(label: "x", plistURL: URL(fileURLWithPath: "/x.plist"), schedule: "s",
                state: JobState(isLoaded: true, lastExit: exit)).summary
        }
        #expect(summary(.neverRan).hasSuffix("not run yet"))
        #expect(summary(.signal).hasSuffix("killed by signal"))
        #expect(summary(.unknown).hasSuffix("exit unknown"))
    }

    @Test func actionsBuildLaunchctlArguments() throws {
        let daily = try job("com.example.daily")
        let path = daily.plistURL.path
        #expect(JobAction.runNow.launchctlArguments(for: daily, domain: "gui/501") == ["kickstart", "gui/501/com.example.daily"])
        #expect(JobAction.turnOn.launchctlArguments(for: daily, domain: "gui/501") == ["bootstrap", "gui/501", path])
        #expect(JobAction.turnOff.launchctlArguments(for: daily, domain: "gui/501") == ["bootout", "gui/501", path])
    }
}
