
import SwiftUI

struct AccentColor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
    
    // Curated, desaturated palette tuned to a consistent lightness/chroma so any
    // choice reads as intentional and calm against the system material.
    // "System" defers to the user's macOS accent — the most native default.
    static let allColors: [AccentColor] = [
        AccentColor(name: "System", color: .accentColor),
        AccentColor(name: "Sage",   color: Color(red: 0.45, green: 0.60, blue: 0.50)),
        AccentColor(name: "Slate",  color: Color(red: 0.40, green: 0.53, blue: 0.66)),
        AccentColor(name: "Clay",   color: Color(red: 0.79, green: 0.55, blue: 0.45)),
        AccentColor(name: "Rose",   color: Color(red: 0.76, green: 0.52, blue: 0.57)),
        AccentColor(name: "Plum",   color: Color(red: 0.58, green: 0.50, blue: 0.67)),
        AccentColor(name: "Ochre",  color: Color(red: 0.78, green: 0.64, blue: 0.40))
    ]
}
