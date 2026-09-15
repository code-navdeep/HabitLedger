
import SwiftUI

/// Tri-state control for binary habits: Yes ("I did it"), No ("I didn't"),
/// or neither (unlogged). It states a fact — whether the day was a success
/// is decided by the habit's goal, not by this control.
/// Tapping the selected side clears the day back to unlogged.
struct YesNoControl: View {
    @EnvironmentObject var habitStore: HabitStore
    /// nil = unlogged, true = did it, false = didn't do it.
    let value: Bool?
    let onChange: (Bool?) -> Void

    var body: some View {
        HStack(spacing: 6) {
            segment(isYes: true)
            segment(isYes: false)
        }
    }

    private func segment(isYes: Bool) -> some View {
        let isSelected = value == isYes
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onChange(isSelected ? nil : isYes)
            }
        } label: {
            Image(systemName: isYes ? "checkmark" : "xmark")
                .font(.subheadline.bold())
                .foregroundColor(isSelected ? .white : .theme.textSecondary)
                .frame(width: 32, height: 26)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? (isYes ? habitStore.accentColor : Color.red.opacity(0.75))
                              : Color.theme.surface2)
                )
        }
        .buttonStyle(.plain)
        .help(isYes ? "I did it" : "I didn't do it")
    }
}

#Preview {
    VStack(spacing: 12) {
        YesNoControl(value: true, onChange: { _ in })
        YesNoControl(value: false, onChange: { _ in })
        YesNoControl(value: nil, onChange: { _ in })
    }
    .padding()
    .background(Color.theme.background)
    .environmentObject(HabitStore())
}
