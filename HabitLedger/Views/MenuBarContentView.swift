
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject var habitStore: HabitStore
    @EnvironmentObject var router: PanelRouter

    enum ViewState {
        case browsing
        case adding
        case editing(Habit)
        case showingProgress(Habit)
        case settings
    }

    @State private var currentState: ViewState = .browsing
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 0) {
            switch currentState {
            case .browsing:
                VStack(spacing: 0) {
                    headerView
                    dateNavigationView
                    Divider()
                    DailyLogView(onAdd: {
                        withAnimation {
                            self.currentState = .adding
                        }
                    }, onEdit: { habit in
                        withAnimation {
                            self.currentState = .editing(habit)
                        }
                    }, onShowProgress: { habit in
                        withAnimation {
                            self.currentState = .showingProgress(habit)
                        }
                    })
                }
                .frame(width: 320)
            case .adding:
                AddEditHabitView(habit: nil, onDismiss: {
                    withAnimation {
                        currentState = .browsing
                    }
                })
                .frame(width: 360)
            case .editing(let habit):
                AddEditHabitView(habit: habit, onDismiss: {
                    withAnimation {
                        currentState = .browsing
                    }
                })
                .frame(width: 360)
            case .showingProgress(let habit):
                HabitProgressView(habit: habit, onDismiss: {
                    withAnimation {
                        currentState = .browsing
                    }
                })
                .frame(width: 420)
            case .settings:
                SettingsView(onDismiss: {
                    withAnimation {
                        currentState = .browsing
                    }
                })
                .frame(width: 360)
            }
        }
        .tint(habitStore.accentColor)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .alert("Error", isPresented: $showingError, presenting: habitStore.error) { error in
            Button("OK") {
                habitStore.error = nil
            }
        } message: { error in
            VStack(alignment: .leading, spacing: 8) {
                Text(error.localizedDescription)
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.caption)
                }
            }
        }
        .onChange(of: habitStore.error) { _, error in
            showingError = error != nil
        }
        .onReceive(router.$requestedState) { request in
            guard let request else { return }
            withAnimation {
                switch request {
                case .adding: currentState = .adding
                case .settings: currentState = .settings
                }
            }
            router.requestedState = nil
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("HabitLedger")
                .textStyle(.title2)
                .foregroundColor(.theme.textPrimary)

            Spacer()
        }
        .padding()
        .background(Color.theme.surface2.opacity(0.5))
    }

    private var hasActiveHabits: Bool {
        habitStore.habits.contains { !$0.isArchived }
    }

    /// The user can go back only while the current day is after the earliest habit's start date.
    private var canGoBack: Bool {
        guard let earliest = habitStore.earliestStartDate else { return false }
        return Calendar.current.startOfDay(for: habitStore.currentDate) > Calendar.current.startOfDay(for: earliest)
    }

    @ViewBuilder
    private var dateNavigationView: some View {
        HStack(spacing: 16) {
            Button(action: { habitStore.previousDay() }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(!canGoBack)
            .opacity(!hasActiveHabits ? 0 : (canGoBack ? 1.0 : 0.3))

            Spacer()

            VStack(spacing: 2) {
                Text(dateDisplay)
                    .textStyle(.headline)
                    .foregroundColor(.theme.textPrimary)

                if !habitStore.isToday {
                    Button("Today") {
                        withAnimation {
                            habitStore.goToToday()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(habitStore.accentColor)
                }
            }

            Spacer()

            Button(action: { habitStore.nextDay() }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(habitStore.isToday)
            .opacity(!hasActiveHabits ? 0 : (habitStore.isToday ? 0.3 : 1.0))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var dateDisplay: String {
        if habitStore.isToday {
            return "Today"
        } else if Calendar.current.isDateInYesterday(habitStore.currentDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: habitStore.currentDate)
        }
    }
}
