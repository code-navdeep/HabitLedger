import SwiftUI

enum Theme {
    // MARK: - Color Palette
    // Semantic system colors so the app adapts to light/dark automatically
    // and lets the window's vibrancy material show through.
    enum Colors {
        static let background = Color(nsColor: .windowBackgroundColor)
        static let surface = Color.clear              // no opaque fill — let the material show
        static let surface2 = Color.primary.opacity(0.08) // subtle adaptive fill for controls/strips
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color(nsColor: .tertiaryLabelColor)
        static let success = Color.green
        static let destructive = Color.red
    }
    
    // MARK: - Spacing
    static func spacing(_ multiplier: CGFloat) -> CGFloat {
        return 8 * multiplier
    }
    
    // MARK: - Typography
    enum TextStyle {
        case display, title1, title2, headline, body, caption
        
        var font: Font {
            switch self {
            case .display: return .system(size: 28, weight: .bold)
            case .title1: return .system(size: 22, weight: .bold)
            case .title2: return .system(size: 15, weight: .semibold)
            case .headline: return .system(size: 13, weight: .semibold)
            case .body: return .system(size: 11, weight: .regular)
            case .caption: return .system(size: 11, weight: .medium)
            }
        }
    }
}

// MARK: - View Extensions

extension Color {
    static let theme = Theme.Colors.self
}

struct TextStyleModifier: ViewModifier {
    let style: Theme.TextStyle
    
    func body(content: Content) -> some View {
        content.font(style.font)
    }
}

extension View {
    func textStyle(_ style: Theme.TextStyle) -> some View {
        self.modifier(TextStyleModifier(style: style))
    }
}