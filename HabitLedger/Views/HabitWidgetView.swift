import SwiftUI

struct HabitWidgetView: View {
    @EnvironmentObject var habitStore: HabitStore
    let habit: Habit
    let onEdit: (Habit) -> Void
    let onShowProgress: (Habit) -> Void

    @State private var showingDeleteConfirmation = false

    private var isScheduledToday: Bool {
        habit.isScheduled(on: habitStore.currentDate)
    }

    var body: some View {
        HStack(spacing: Theme.spacing(1.5)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .textStyle(.headline)
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)

                streakView

                if !isScheduledToday {
                    Text("Not scheduled today")
                        .font(.caption2)
                        .foregroundColor(.theme.textTertiary)
                }
            }

            Spacer(minLength: Theme.spacing(1))

            actionControl

            menuButton
        }
        .opacity(isScheduledToday ? 1.0 : 0.6)
        .padding(.horizontal, Theme.spacing(2))
        .padding(.vertical, Theme.spacing(1.5))
        .contentShape(Rectangle())
        .confirmationDialog("Delete '\(habit.name)'?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                withAnimation {
                    habitStore.deleteHabit(habit)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all history for this habit.")
        }
    }

    @ViewBuilder
    private var streakView: some View {
        let streaks = habitStore.calculateStreaks(for: habit)
        let suffix = habit.schedule.isWeeklyQuota ? "w" : ""

        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.caption2)
                .foregroundColor(streaks.current > 0 ? .orange : .theme.textTertiary)
            Text("\(streaks.current)\(suffix)")
                .textStyle(.caption)
                .foregroundColor(.theme.textSecondary)
        }
    }

    @ViewBuilder
    private var actionControl: some View {
        switch habit.type {
        case .binary:
            YesNoControl(value: habit.getEntry(for: habitStore.currentDate)?.value.boolValue) { newValue in
                if let newValue {
                    habitStore.updateCompletion(for: habit.id, on: habitStore.currentDate, to: newValue)
                } else {
                    habitStore.clearEntry(for: habit.id, on: habitStore.currentDate)
                }
            }
        case .numerical:
            CustomStepper(value: Binding(
                get: { habit.getNumericalValue(for: habitStore.currentDate) },
                set: { habitStore.updateNumericalValue(for: habit.id, on: habitStore.currentDate, to: $0) }
            ), target: habit.target)
        }
    }

    private var menuButton: some View {
        Menu {
            Button { onEdit(habit) } label: { Label("Edit", systemImage: "pencil") }
            Button { onShowProgress(habit) } label: { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            Button {
                withAnimation { habitStore.setArchived(true, for: habit.id) }
            } label: { Label("Archive", systemImage: "archivebox") }
            Divider()
            Button(role: .destructive) { showingDeleteConfirmation = true } label: { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundColor(.theme.textSecondary)
                .frame(width: 20, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

#Preview {
    let habit = HabitStore().habits[0]
    HabitWidgetView(habit: habit, onEdit: { _ in }, onShowProgress: { _ in })
        .padding()
        .frame(width: 400)
        .background(Color.theme.background)
        .environmentObject(HabitStore())
}
