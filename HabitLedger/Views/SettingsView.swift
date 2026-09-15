
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var habitStore: HabitStore
    let onDismiss: () -> Void

    @StateObject private var launchManager = LaunchAtLoginManager()
    @StateObject private var reminderManager = ReminderManager()
    @State private var pendingImportData: Data?
    @State private var dataErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("Settings")
                    .textStyle(.title2)
                    .foregroundColor(.theme.textPrimary)

                Spacer()

                // Balances the back button so the title stays centered.
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .opacity(0)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: Theme.spacing(3)) {
                // General
                section("General") {
                    Toggle(isOn: Binding(
                        get: { launchManager.isEnabled },
                        set: { launchManager.setEnabled($0) }
                    )) {
                        Text("Launch at Login").textStyle(.body)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                // Appearance
                section("Accent Color") {
                    HStack(spacing: Theme.spacing(1.5)) {
                        ForEach(AccentColor.allColors) { accent in
                            let isSelected = accent.color == habitStore.accentColor
                            Button {
                                habitStore.setAccentColor(accent.color)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(accent.color)
                                        .frame(width: 22, height: 22)
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .help(accent.name)
                        }
                    }
                }

                // Reminder
                section("Daily Reminder") {
                    HStack(spacing: Theme.spacing(2)) {
                        Toggle(isOn: Binding(
                            get: { reminderManager.isEnabled },
                            set: { reminderManager.setEnabled($0) }
                        )) {
                            Text("Remind me at").textStyle(.body)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        DatePicker("", selection: Binding(
                            get: { reminderManager.time },
                            set: { reminderManager.setTime($0) }
                        ), displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.field)
                        .labelsHidden()
                        .disabled(!reminderManager.isEnabled)
                    }
                }

                // Data
                section("Data") {
                    HStack(spacing: Theme.spacing(1)) {
                        Button("Export JSON") { exportJSON() }
                        Button("Export CSV") { exportCSV() }
                        Button("Import JSON…") { pickImportFile() }
                    }
                    .controlSize(.small)
                }
            }
            .padding(Theme.spacing(3))
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Text("HabitLedger \(appVersion)")
                .textStyle(.caption)
                .foregroundColor(.theme.textTertiary)
                .padding(Theme.spacing(1.5))
        }
        .alert("Replace all current habits?", isPresented: Binding(
            get: { pendingImportData != nil },
            set: { if !$0 { pendingImportData = nil } }
        )) {
            Button("Replace", role: .destructive) { applyImport() }
            Button("Cancel", role: .cancel) { pendingImportData = nil }
        } message: {
            Text("Importing replaces every habit and its history with the file's contents.")
        }
        .alert("Data Error", isPresented: Binding(
            get: { dataErrorMessage != nil },
            set: { if !$0 { dataErrorMessage = nil } }
        )) {
            Button("OK") { dataErrorMessage = nil }
        } message: {
            Text(dataErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing(1)) {
            Text(title)
                .textStyle(.caption)
                .foregroundColor(.theme.textSecondary)
            content()
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    // MARK: - Export / Import

    private func exportJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "HabitLedger-export.json"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try habitStore.exportJSON().write(to: url)
        } catch {
            dataErrorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "HabitLedger-export.csv"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try habitStore.exportCSV().write(to: url, atomically: true, encoding: .utf8)
        } catch {
            dataErrorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func pickImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            pendingImportData = try Data(contentsOf: url)
        } catch {
            dataErrorMessage = "Couldn't read the file: \(error.localizedDescription)"
        }
    }

    private func applyImport() {
        guard let data = pendingImportData else { return }
        pendingImportData = nil
        do {
            try habitStore.importHabits(from: data)
        } catch {
            dataErrorMessage = "Import failed: the file isn't a valid HabitLedger export."
        }
    }
}

#Preview {
    SettingsView(onDismiss: {})
        .environmentObject(HabitStore())
        .frame(width: 360)
}
