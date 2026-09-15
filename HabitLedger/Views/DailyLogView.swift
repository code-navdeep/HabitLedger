import SwiftUI
import UniformTypeIdentifiers

struct DailyLogView: View {
    @EnvironmentObject var habitStore: HabitStore
    let onAdd: () -> Void
    let onEdit: (Habit) -> Void
    let onShowProgress: (Habit) -> Void

    @State private var listContentHeight: CGFloat = 0
    @State private var draggingHabit: Habit?
    @State private var archivedExpanded = false
    @State private var habitToDelete: Habit?
    private let maxListHeight: CGFloat = 440

    var body: some View {
        VStack(spacing: 0) {
            if habitStore.habits.isEmpty {
                EmptyStateView(onAdd: onAdd)
            } else {
                let activeHabits = habitStore.activeHabits(on: habitStore.currentDate)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if activeHabits.isEmpty {
                            Text("No habits for this day")
                                .textStyle(.body)
                                .foregroundColor(.theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(Theme.spacing(3))
                        }

                        ForEach(Array(activeHabits.enumerated()), id: \.element.id) { index, habit in
                            if index > 0 {
                                Divider()
                            }
                            HabitWidgetView(habit: habit, onEdit: onEdit, onShowProgress: onShowProgress)
                                .onDrag {
                                    draggingHabit = habit
                                    return NSItemProvider(object: habit.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: HabitDropDelegate(item: habit, dragging: $draggingHabit, store: habitStore))
                        }

                        if !habitStore.archivedHabits.isEmpty {
                            archivedSection
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                        }
                    )
                    .animation(.easeInOut(duration: 0.2), value: habitStore.habits.count)
                }
                .frame(height: min(listContentHeight, maxListHeight))
                .onPreferenceChange(ContentHeightKey.self) { listContentHeight = $0 }
            }
        }
        .confirmationDialog(
            "Delete '\(habitToDelete?.name ?? "")'?",
            isPresented: Binding(get: { habitToDelete != nil }, set: { if !$0 { habitToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let habit = habitToDelete {
                    withAnimation { habitStore.deleteHabit(habit) }
                }
                habitToDelete = nil
            }
            Button("Cancel", role: .cancel) { habitToDelete = nil }
        } message: {
            Text("This will permanently delete all history for this habit.")
        }
    }

    @ViewBuilder
    private var archivedSection: some View {
        Divider()
        DisclosureGroup(isExpanded: $archivedExpanded) {
            ForEach(habitStore.archivedHabits) { habit in
                HStack(spacing: Theme.spacing(1)) {
                    Text(habit.name)
                        .textStyle(.body)
                        .foregroundColor(.theme.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        withAnimation { habitStore.setArchived(false, for: habit.id) }
                    } label: {
                        Image(systemName: "tray.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Unarchive")

                    Button(role: .destructive) {
                        habitToDelete = habit
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete")
                }
                .padding(.vertical, Theme.spacing(0.5))
            }
        } label: {
            Text("Archived (\(habitStore.archivedHabits.count))")
                .textStyle(.caption)
                .foregroundColor(.theme.textSecondary)
        }
        .padding(.horizontal, Theme.spacing(2))
        .padding(.vertical, Theme.spacing(1))
    }
}

/// Reorders the habits array live while a row is dragged over its siblings.
struct HabitDropDelegate: DropDelegate {
    let item: Habit
    @Binding var dragging: Habit?
    let store: HabitStore

    func dropEntered(info: DropInfo) {
        guard let dragging,
              dragging.id != item.id,
              let fromIndex = store.habits.firstIndex(where: { $0.id == dragging.id }),
              let toIndex = store.habits.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation {
            store.moveHabit(fromIndex: fromIndex, toIndex: toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var habitStore: HabitStore
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacing(3)) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(habitStore.accentColor)

            VStack(spacing: Theme.spacing(0.5)) {
                Text("Start Building Better Habits")
                    .textStyle(.title2)
                    .foregroundColor(.theme.textPrimary)

                Text("Track your daily progress and build lasting streaks")
                    .textStyle(.body)
                    .foregroundColor(.theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAdd) {
                Label("Add Habit", systemImage: "plus")
                    .textStyle(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(habitStore.accentColor)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(Theme.spacing(4))
    }
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    MenuBarContentView()
        .environmentObject(HabitStore())
        .environmentObject(PanelRouter())
}
