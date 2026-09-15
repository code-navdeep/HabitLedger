import Foundation

struct HabitEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    let date: Date
    let value: HabitValue

    enum HabitValue: Codable, Hashable {
        case binary(Bool)
        case numerical(Double)

        var boolValue: Bool? {
            if case .binary(let value) = self {
                return value
            }
            return nil
        }

        var numericalValue: Double? {
            if case .numerical(let value) = self {
                return value
            }
            return nil
        }
    }
}
