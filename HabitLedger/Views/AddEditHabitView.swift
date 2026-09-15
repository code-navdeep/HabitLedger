
import SwiftUI

struct AddEditHabitView: View {
    let habit: Habit?
    @EnvironmentObject var habitStore: HabitStore
    let onDismiss: () -> Void

    enum ScheduleKind: String, CaseIterable {
        case daily = "Daily"
        case specificDays = "Days"
        case perWeek = "Per Week"
    }

    @State private var name: String = ""
    @State private var selectedType: Habit.HabitType = .binary
    @State private var selectedGoal: Habit.HabitGoal = .adopt
    @State private var target: String = ""
    @State private var createdDate: Date = Date()
    @State private var scheduleKind: ScheduleKind = .daily
    @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var timesPerWeek: Int = 3
    @State private var showingError = false
    @State private var errorMessage = ""

    private var isEditing: Bool { habit != nil }

    /// A habit with logged history can't change type — old entries have the old
    /// value type and there is no sensible conversion.
    private var isTypeLocked: Bool {
        guard let habit else { return false }
        return !habit.entries.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(isEditing ? "Edit Habit" : "Add Habit")
                .textStyle(.title2)
                .foregroundColor(.theme.textPrimary)
                .padding()

            Divider()

            // Form Content
            VStack(alignment: .leading, spacing: Theme.spacing(3)) {
                VStack(alignment: .leading, spacing: Theme.spacing(1)) {
                    Text("Habit Name").foregroundColor(.theme.textSecondary)
                    TextField("", text: $name)
                        .textFieldStyle(ModernTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: Theme.spacing(1)) {
                    Text("Type").foregroundColor(.theme.textSecondary)
                    Picker("", selection: $selectedType) {
                        ForEach(Habit.HabitType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isTypeLocked)

                    if isTypeLocked {
                        Text("Type can't be changed once a habit has history.")
                            .font(.caption)
                            .foregroundColor(.theme.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacing(1)) {
                    Text("Goal").foregroundColor(.theme.textSecondary)
                    Picker("", selection: $selectedGoal) {
                        ForEach(Habit.HabitGoal.allCases, id: \.self) { goal in
                            Text(goal.displayName).tag(goal)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(successExplanation)
                        .font(.caption)
                        .foregroundColor(.theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: Theme.spacing(1)) {
                    Text("Schedule").foregroundColor(.theme.textSecondary)
                    Picker("", selection: $scheduleKind) {
                        ForEach(ScheduleKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if scheduleKind == .specificDays {
                        weekdayChips
                    } else if scheduleKind == .perWeek {
                        Stepper("\(timesPerWeek)× per week", value: $timesPerWeek, in: 1...7)
                            .font(.body)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacing(1)) {
                    Text("Start Date").foregroundColor(.theme.textSecondary)
                    DatePicker("", selection: $createdDate, displayedComponents: [.date])
                        .datePickerStyle(.field)
                        .labelsHidden()
                }

                if selectedType == .numerical {
                    VStack(alignment: .leading, spacing: Theme.spacing(1)) {
                        Text("Daily Target (Optional)").foregroundColor(.theme.textSecondary)
                        TextField("e.g., 30", text: $target)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    .transition(.opacity.combined(with: .slide))
                }
            }
            .padding(Theme.spacing(3))

            // Footer Buttons
            HStack {
                Button("Cancel", role: .cancel, action: onDismiss)
                    .buttonStyle(ModernButtonStyle(isDestructive: true))

                Spacer()

                Button(isEditing ? "Save" : "Add", action: saveHabit)
                    .buttonStyle(ModernButtonStyle())
            }
            .padding(Theme.spacing(3))
        }
        .background(Color.theme.surface)
        .onAppear(perform: setupInitialValues)
        .onChange(of: selectedType) { oldValue, newValue in
            // Clear target when switching from numerical to binary
            if oldValue == .numerical && newValue == .binary {
                target = ""
            }
        }
        .alert("Invalid Input", isPresented: $showingError, actions: {
            Button("OK") {}
        }, message: { Text(errorMessage) })
    }

    /// Seven toggle chips ordered by the user's calendar (Mon-first locales included).
    @ViewBuilder
    private var weekdayChips: some View {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        HStack(spacing: Theme.spacing(0.75)) {
            ForEach(0..<7, id: \.self) { offset in
                let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
                let isOn = selectedWeekdays.contains(weekday)
                Button {
                    if isOn {
                        selectedWeekdays.remove(weekday)
                    } else {
                        selectedWeekdays.insert(weekday)
                    }
                } label: {
                    Text(symbols[weekday - 1])
                        .font(.caption.bold())
                        .foregroundColor(isOn ? .white : .theme.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(isOn ? habitStore.accentColor : Color.theme.surface2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Plain-words explanation of what counts as a success for the chosen combination.
    private var successExplanation: String {
        switch (selectedType, selectedGoal) {
        case (.binary, .adopt):
            return "Success: tap Yes — or leave the day unlogged. Only an explicit No breaks a streak."
        case (.binary, .quit):
            return "Success: tap No — or leave the day unlogged. Only an explicit Yes breaks a streak."
        case (.numerical, .adopt):
            return "Success: log a value that reaches the target (or anything above 0 without one). Unlogged days count as failures."
        case (.numerical, .quit):
            return "Success: log a value at or below the target (or exactly 0 without one). Unlogged days count as failures."
        }
    }

    private func setupInitialValues() {
        if let habit = habit {
            name = habit.name
            selectedType = habit.type
            selectedGoal = habit.goal
            // Show the stored value faithfully: whole numbers without decimals,
            // fractional targets untruncated.
            target = habit.target.map { value in
                value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
            } ?? ""
            createdDate = habit.createdDate

            switch habit.schedule {
            case .daily:
                scheduleKind = .daily
            case .weekdays(let days):
                scheduleKind = .specificDays
                selectedWeekdays = days
            case .timesPerWeek(let count):
                scheduleKind = .perWeek
                timesPerWeek = count
            }
        }
    }

    private func saveHabit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validation
        guard !trimmedName.isEmpty else {
            showError("Please enter a habit name")
            return
        }

        let existingHabit = habitStore.habits.first { $0.name.lowercased() == trimmedName.lowercased() }
        if let existing = existingHabit, existing.id != habit?.id {
            showError("A habit with this name already exists")
            return
        }

        var targetValue: Double?
        if selectedType == .numerical && !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsedTarget = Double(target.trimmingCharacters(in: .whitespacesAndNewlines)), parsedTarget > 0 else {
                showError("Please enter a valid target value")
                return
            }
            targetValue = parsedTarget
        }

        let schedule: Schedule
        switch scheduleKind {
        case .daily:
            schedule = .daily
        case .specificDays:
            guard !selectedWeekdays.isEmpty else {
                showError("Please select at least one day")
                return
            }
            schedule = .weekdays(selectedWeekdays)
        case .perWeek:
            schedule = .timesPerWeek(timesPerWeek)
        }

        // Create or update habit
        if var existingHabit = habit {
            existingHabit.name = trimmedName
            existingHabit.type = selectedType
            existingHabit.target = targetValue
            existingHabit.goal = selectedGoal
            existingHabit.schedule = schedule
            existingHabit.createdDate = Calendar.current.startOfDay(for: createdDate)
            habitStore.updateHabit(existingHabit)
        } else {
            let newHabit = Habit(name: trimmedName, type: selectedType, target: targetValue, goal: selectedGoal, schedule: schedule, createdDate: createdDate)
            habitStore.addHabit(newHabit)
        }

        onDismiss()
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - Custom Styles

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Theme.spacing(1.5))
            .background(Color.primary.opacity(0.06))
            .cornerRadius(8)
            .foregroundColor(.theme.textPrimary)
    }
}

struct ModernButtonStyle: ButtonStyle {
    @EnvironmentObject var habitStore: HabitStore
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(isDestructive ? Color.red.opacity(0.8) : habitStore.accentColor)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

#Preview {
    AddEditHabitView(habit: HabitStore().habits.first, onDismiss: {})
        .environmentObject(HabitStore())
}
