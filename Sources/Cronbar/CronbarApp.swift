import AppKit
import CronbarCore
import ServiceManagement
import SwiftUI

@main
struct CronbarApp: App {
    @State private var store = JobStore()

    var body: some Scene {
        MenuBarExtra {
            JobMenu(store: store)
        } label: {
            if store.failureCount > 0 {
                Label("\(store.failureCount)", systemImage: "clock.badge.exclamationmark")
                    .labelStyle(.titleAndIcon)
            } else {
                Image(systemName: "clock.badge.checkmark")
            }
        }
    }
}

struct JobMenu: View {
    let store: JobStore
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        if let error = store.actionError {
            Text(error)
            Divider()
        }
        if store.jobs.isEmpty {
            Text("No jobs in \(JobStore.agentsDirectory.path)")
        }
        ForEach(store.jobs) { job in
            Menu {
                JobActions(store: store, job: job)
            } label: {
                Label(job.summary, systemImage: job.systemImage)
            }
        }
        Divider()
        Button("Open LaunchAgents Folder") {
            NSWorkspace.shared.open(JobStore.agentsDirectory)
        }
        Button("Refresh") { Task { await store.refresh() } }
            .keyboardShortcut("r")
        Toggle("Open at Login", isOn: $opensAtLogin)
            .onChange(of: opensAtLogin) { _, enabled in
                try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                opensAtLogin = SMAppService.mainApp.status == .enabled
            }
        Divider()
        Button("Quit Cronbar") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

struct JobActions: View {
    let store: JobStore
    let job: Job

    var body: some View {
        Button("Run Now", systemImage: "play.fill") { run(.runNow) }
        if job.state.isLoaded {
            Button("Turn Off", systemImage: "stop.fill") { run(.turnOff) }
        } else {
            Button("Turn On", systemImage: "power") { run(.turnOn) }
        }
        if let out = job.outLog {
            Button("Open Log", systemImage: "doc.text") { open(out) }
        }
        if let err = job.errorLog, err != job.outLog {
            Button("Open Error Log", systemImage: "doc.text.fill") { open(err) }
        }
        Button("Reveal Plist in Finder", systemImage: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([job.plistURL])
        }
    }

    private func run(_ action: JobAction) {
        Task { await store.perform(action, on: job) }
    }

    private func open(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}
