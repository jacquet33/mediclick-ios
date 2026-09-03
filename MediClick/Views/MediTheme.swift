import SwiftUI

// ═══════════════════════════════════════════════════════════
// MediClick Design System v2 — Modern, neutral, clean
// Inspired by Apple Health, Airbnb, Linear
// ═══════════════════════════════════════════════════════════

// MARK: - Colors

extension Color {
    // Neutrals
    static let mediBg       = Color(hex: "FAFAF9")
    static let mediBgSoft   = Color(hex: "F5F5F4")
    static let mediSurface  = Color.white
    static let mediBorder   = Color(hex: "E8E5E1")
    
    // Text
    static let mediText     = Color(hex: "1A1A1A")
    static let mediTextSoft = Color(hex: "666666")
    static let mediTextMuted = Color(hex: "999999")
    
    // Accent — medical teal (used sparingly)
    static let mediTeal     = Color(hex: "0D9488")
    static let mediTealSoft = Color(hex: "F0FDFA")
    
    // Semantic
    static let mediDanger   = Color(hex: "EF4444")
    static let mediDangerSoft = Color(hex: "FEF2F2")
    static let mediWarning  = Color(hex: "F59E0B")
    static let mediWarningSoft = Color(hex: "FEF3C7")
    static let mediSuccess  = Color(hex: "10B981")
    static let mediSuccessSoft = Color(hex: "ECFDF5")
    
    // Legacy aliases (backward compat — point to new values)
    static let mediPrimary  = Color(hex: "1A1A1A")
    static let mediDeep     = Color(hex: "1A1A1A")
    static let mediCyan     = Color(hex: "0D9488")
    static let mediSky      = Color(hex: "0D9488")
    
    // Hex initializer
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: UInt64
        switch h.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }
}

// MARK: - Typography

extension Font {
    static func mediTitle(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    static func mediHeadline(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    static func mediBody(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func mediCaption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    static func mediNumber(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    static func mediMono(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

// MARK: - Background

struct MediBackground: View {
    var body: some View {
        Color.mediBg.ignoresSafeArea()
    }
}

// MARK: - Card Modifier

struct MediCard: ViewModifier {
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.mediSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.mediBorder, lineWidth: 0.5)
            )
    }
}

// Legacy alias
struct MediElevatedCard: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.mediSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.mediBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func mediCard(padding: CGFloat = 16) -> some View {
        modifier(MediCard(padding: padding))
    }
    func mediElevated(padding: CGFloat = 16) -> some View {
        modifier(MediElevatedCard(padding: padding))
    }
}

// MARK: - Button Style

struct MediButtonStyle: ButtonStyle {
    var colors: [Color] = [.mediPrimary]
    var isSecondary: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isSecondary ? Color.mediBgSoft : Color.mediPrimary)
            .foregroundStyle(isSecondary ? Color.mediText : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSecondary ? Color.mediBorder : .clear, lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Teal button for medical actions
struct MediTealButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.mediTeal)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Avatar

struct MediAvatar: View {
    let name: String
    var size: CGFloat = 36
    var color: Color = .mediTeal
    
    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Badge

struct MediBadge: View {
    let text: String
    var color: Color = .mediTeal
    
    private var bgColor: Color {
        if color == .mediTeal || color == .mediCyan || color == .mediSky { return .mediTealSoft }
        if color == .mediDanger { return .mediDangerSoft }
        if color == .mediWarning { return .mediWarningSoft }
        if color == .mediSuccess { return .mediSuccessSoft }
        return Color.mediBgSoft
    }
    
    init(_ text: String, color: Color = .mediTeal) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bgColor)
            .foregroundStyle(color == .mediPrimary || color == .mediDeep ? .mediTextSoft : color)
            .clipShape(Capsule())
    }
}

// MARK: - Section Header

struct MediSectionHeader: View {
    let title: String
    var icon: String = ""
    
    var body: some View {
        HStack(spacing: 8) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.mediTextMuted)
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.mediTextMuted)
                .tracking(0.5)
            Spacer()
        }
    }
}

// MARK: - Info Row

struct MediInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.mediTextMuted)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.mediTextSoft)
            }
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.mediText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Text Field

struct MediTextField: View {
    var label: String = ""
    var icon: String = ""
    var placeholder: String = ""
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextMuted)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            
            HStack(spacing: 10) {
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(isFocused ? Color.mediTeal : Color.mediTextMuted)
                        .frame(width: 20)
                }
                
                if isSecure {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.mediTextMuted))
                        .focused($isFocused)
                        .foregroundStyle(Color.mediText)
                } else {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.mediTextMuted))
                        .focused($isFocused)
                        .foregroundStyle(Color.mediText)
                }
            }
            .font(.system(size: 15))
            .padding(14)
            .background(Color.mediBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused ? Color.mediTeal : Color.mediBorder, lineWidth: isFocused ? 1 : 0.5)
            )
            .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}

// MARK: - Status Helpers

struct MediStatus {
    static func color(for status: String) -> Color {
        switch status {
        case "confirmed": return .mediTeal
        case "pending": return .mediWarning
        case "checked_in": return .mediSuccess
        case "completed": return .mediTextMuted
        case "in_progress": return .mediTeal
        case "cancelled": return .mediDanger
        case "no_show": return .mediDanger
        case "active", "vigente": return .mediSuccess
        case "expired": return .mediTextMuted
        default: return .mediTextMuted
        }
    }
    
    static func label(for status: String) -> String {
        switch status {
        case "confirmed": return "Confirmado"
        case "pending": return "Pendiente"
        case "checked_in": return "En sala"
        case "completed": return "Atendido"
        case "in_progress": return "En curso"
        case "cancelled": return "Cancelado"
        case "no_show": return "Ausente"
        case "active", "vigente": return "Vigente"
        case "expired": return "Vencida"
        default: return status.capitalized
        }
    }
    
    static func gradient(for status: String) -> [Color] {
        [color(for: status)]
    }
}

// MARK: - Legacy Gradient Compat

extension LinearGradient {
    static func medi(_ colors: [Color] = [.mediTeal]) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var mediHero: LinearGradient { medi([.mediTeal]) }
    static var mediBorder: LinearGradient { medi([Color.mediBorder]) }
    static var mediShine: LinearGradient {
        LinearGradient(colors: [.white.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - AnyShapeStyle compat (removed - use concrete types instead)
