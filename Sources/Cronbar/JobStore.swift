import CronbarCore
import Foundation
import Observation

@MainActor
@Observable
final class JobStore {
    static let agentsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/LaunchAgents")

    private(set) var jobs: [Job] = []
    private(set) var actionError: String?

    var failureCount: Int { jobs.filter(\.state.isFailure).count }

    private let loader = JobLoader(agentsDirectory: JobStore.agentsDirectory) { label in
        Launchctl.run(["print", "\(JobLoader.userDomain)/\(label)"]).output
    }

    init() {
        Task { [weak self] in
            while let self {
                await self.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func refresh() async {
        let loader = loader
        jobs = await Task.detached { loader.load() }.value
    }

    func perform(_ action: JobAction, on job: Job) async {
        let arguments = action.launchctlArguments(for: job, domain: JobLoader.userDomain)
        let result = await Task.detached { Launchctl.run(arguments) }.value
        actionError = result.status == 0
            ? nil
            : "\(job.label): launchctl \(arguments[0]) failed (\(result.status))"
        await refresh()
    }
}
