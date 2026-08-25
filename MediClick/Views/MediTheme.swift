import SwiftUI

// MARK: - MediClick Medical Theme

extension Color {
    // Azul médico principal
    static let mediPrimary = Color(red: 0.16, green: 0.50, blue: 0.73)       // #2980B9
    static let mediPrimaryLight = Color(red: 0.22, green: 0.60, blue: 0.85)   // #3899D9
    static let mediPrimaryDark = Color(red: 0.10, green: 0.37, blue: 0.56)    // #1A5E8F
    
    // Celeste suave para fondos
    static let mediBackground = Color(red: 0.91, green: 0.96, blue: 0.99)     // #E8F5FE
    static let mediBackgroundCard = Color.white
    static let mediBackgroundSoft = Color(red: 0.85, green: 0.93, blue: 0.98) // #D9EDFB
    
    // Verde salud
    static let mediSuccess = Color(red: 0.15, green: 0.68, blue: 0.38)       // #27AE60
    static let mediSuccessLight = Color(red: 0.85, green: 0.95, blue: 0.88)   // #D9F2E0
    
    // Rojo urgencia
    static let mediDanger = Color(red: 0.91, green: 0.30, blue: 0.24)        // #E74C3C
    static let mediDangerLight = Color(red: 0.98, green: 0.89, blue: 0.88)    // #FAE3E0
    
    // Naranja atención
    static let mediWarning = Color(red: 0.95, green: 0.61, blue: 0.07)       // #F39C12
    static let mediWarningLight = Color(red: 1.0, green: 0.95, blue: 0.85)    // #FFF2D9
    
    // Textos
    static let mediTextPrimary = Color(red: 0.15, green: 0.22, blue: 0.30)   // #273849
    static let mediTextSecondary = Color(red: 0.40, green: 0.50, blue: 0.58)  // #668094
    static let mediTextMuted = Color(red: 0.60, green: 0.68, blue: 0.74)      // #99ADBC
}

// MARK: - Gradient backgrounds

struct MediGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color.mediPrimary, Color.mediPrimaryLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Medical Card Style

struct MediCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.mediBackgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.mediPrimary.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func mediCard() -> some View {
        modifier(MediCard())
    }
}

// MARK: - Medical Icon Views

struct MediIcon: View {
    let systemName: String
    var size: CGFloat = 20
    var color: Color = .mediPrimary
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size))
            .foregroundStyle(color)
    }
}

struct MediBadge: View {
    let text: String
    let color: Color
    let bgColor: Color
    
    init(_ text: String, color: Color = .mediSuccess, bgColor: Color = .mediSuccessLight) {
        self.text = text
        self.color = color
        self.bgColor = bgColor
    }
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bgColor)
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Medical Avatar

struct MediAvatar: View {
    let name: String
    var size: CGFloat = 44
    
    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }
    
    private var color: Color {
        let colors: [Color] = [.mediPrimary, .mediSuccess, .mediPrimaryLight, .mediPrimaryDark,
                                Color(red: 0.56, green: 0.27, blue: 0.68), // purple
                                Color(red: 0.20, green: 0.60, blue: 0.60)] // teal
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 1)
            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Medical Button Style

struct MediButtonStyle: ButtonStyle {
    var isSecondary: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isSecondary ? Color.mediBackgroundSoft : Color.mediPrimary)
            .foregroundStyle(isSecondary ? Color.mediPrimary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Medical Input Style

struct MediTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.mediPrimary)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding(14)
        .background(Color.mediBackgroundSoft.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.mediPrimary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Status helpers

struct MediStatus {
    static func color(for status: String) -> Color {
        switch status {
        case "confirmed": return .mediSuccess
        case "pending": return .mediWarning
        case "in_progress": return .mediPrimary
        case "completed": return .mediTextMuted
        case "cancelled": return .mediDanger
        case "active": return .mediSuccess
        case "expired": return .mediDanger
        default: return .mediTextMuted
        }
    }
    
    static func bgColor(for status: String) -> Color {
        switch status {
        case "confirmed": return .mediSuccessLight
        case "pending": return .mediWarningLight
        case "in_progress": return Color.mediPrimary.opacity(0.12)
        case "cancelled": return .mediDangerLight
        case "active": return .mediSuccessLight
        case "expired": return .mediDangerLight
        default: return Color.mediTextMuted.opacity(0.12)
        }
    }
    
    static func label(for status: String) -> String {
        switch status {
        case "confirmed": return "Confirmado"
        case "pending": return "Pendiente"
        case "in_progress": return "En curso"
        case "completed": return "Completado"
        case "cancelled": return "Cancelado"
        case "no_show": return "Ausente"
        case "active": return "Vigente"
        case "expired": return "Vencida"
        default: return status.capitalized
        }
    }
}
