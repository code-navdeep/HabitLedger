
import SwiftUI

struct CustomStepper: View {
    @Binding var value: Double
    let target: Double?

    /// Minimum allowed value (default 0, cannot be negative)
    var minValue: Double = 0

    var body: some View {
        HStack(spacing: Theme.spacing(1)) {
            Button(action: {
                if value > minValue {
                    value -= 1
                }
            }) {
                Image(systemName: "minus")
            }
            .buttonStyle(StepperButtonStyle(isDisabled: value <= minValue))
            .disabled(value <= minValue)

            Text(String(format: "%.0f", value))
                .textStyle(.title2)
                .foregroundColor(.theme.textPrimary)
                .frame(minWidth: 50)

            Button(action: { value += 1 }) {
                Image(systemName: "plus")
            }
            .buttonStyle(StepperButtonStyle(isDisabled: false))
        }
    }
}

private struct StepperButtonStyle: ButtonStyle {
    @EnvironmentObject var habitStore: HabitStore
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.headline)
            .foregroundColor(isDisabled ? .gray : habitStore.accentColor)
            .padding(Theme.spacing(1))
            .background(Color.theme.surface2.opacity(isDisabled ? 0.4 : 0.8))
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed && !isDisabled ? 0.9 : 1.0)
    }
}

#Preview {
    CustomStepper(value: .constant(10), target: 20)
        .padding()
        .background(Color.theme.background)
        .environmentObject(HabitStore())
}
