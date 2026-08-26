import SwiftUI

// MARK: - MediClick Premium Medical Theme

extension Color {
    // Paleta celeste médica premium
    static let mediCyan       = Color(red: 0.25, green: 0.78, blue: 0.93)   // #40C7ED
    static let mediSky        = Color(red: 0.31, green: 0.65, blue: 0.94)   // #4FA6F0
    static let mediPrimary    = Color(red: 0.16, green: 0.50, blue: 0.83)   // #2980D4
    static let mediDeep       = Color(red: 0.10, green: 0.35, blue: 0.62)   // #1A599E
    static let mediMidnight   = Color(red: 0.06, green: 0.22, blue: 0.42)   // #0F386B
    
    // Fondos
    static let mediBg         = Color(red: 0.94, green: 0.98, blue: 1.0)    // #F0FAFF
    static let mediBgSoft     = Color(red: 0.88, green: 0.95, blue: 0.99)   // #E0F2FD
    static let mediSurface    = Color.white
    
    // Estados
    static let mediSuccess    = Color(red: 0.13, green: 0.75, blue: 0.55)   // #21BF8C
    static let mediDanger     = Color(red: 0.95, green: 0.36, blue: 0.40)   // #F25C66
    static let mediWarning    = Color(red: 1.0, green: 0.70, blue: 0.20)    // #FFB333
    
    // Textos
    static let mediText       = Color(red: 0.11, green: 0.20, blue: 0.31)   // #1C334F
    static let mediTextSoft   = Color(red: 0.38, green: 0.50, blue: 0.62)   // #61809E
    static let mediTextMuted  = Color(red: 0.60, green: 0.70, blue: 0.79)   // #99B3C9
}

// MARK: - Premium Gradients

extension LinearGradient {
    static let mediHero = LinearGradient(
        colors: [.mediCyan, .mediSky, .mediPrimary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let mediDeepHero = LinearGradient(
        colors: [.mediSky, .mediPrimary, .mediDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let mediGlass = LinearGradient(
        colors: [.white.opacity(0.9), .white.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let mediBorder = LinearGradient(
        colors: [.mediCyan.opacity(0.6), .mediSky.opacity(0.2), .mediPrimary.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let mediShine = LinearGradient(
        colors: [.white.opacity(0.4), .clear, .white.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let mediBackground = LinearGradient(
        colors: [Color.mediBg, Color.mediBgSoft, Color.mediBg],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static func medi(_ colors: [Color]) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Premium Card with glass effect + gradient border

struct MediGlassCard: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 18
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(LinearGradient.mediGlass)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(LinearGradient.mediBorder, lineWidth: 1)
            )
            .shadow(color: .mediPrimary.opacity(0.12), radius: 16, x: 0, y: 6)
            .shadow(color: .mediCyan.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Elevated Card (solid white, deep shadow)

struct MediElevatedCard: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 18
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.mediSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(LinearGradient.mediBorder, lineWidth: 1)
            )
            .shadow(color: .mediPrimary.opacity(0.10), radius: 20, x: 0, y: 8)
            .shadow(color: .mediDeep.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Gradient Card (colored, for stats)

struct MediGradientCard: ViewModifier {
    let colors: [Color]
    var padding: CGFloat = 16
    var radius: CGFloat = 18
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    LinearGradient.medi(colors)
                    LinearGradient.mediShine
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: colors.first?.opacity(0.35) ?? .clear, radius: 16, x: 0, y: 8)
    }
}

extension View {
    func mediGlass(padding: CGFloat = 16, radius: CGFloat = 18) -> some View {
        modifier(MediGlassCard(padding: padding, radius: radius))
    }
    func mediElevated(padding: CGFloat = 16, radius: CGFloat = 18) -> some View {
        modifier(MediElevatedCard(padding: padding, radius: radius))
    }
    func mediGradientCard(_ colors: [Color], padding: CGFloat = 16, radius: CGFloat = 18) -> some View {
        modifier(MediGradientCard(colors: colors, padding: padding, radius: radius))
    }
    func mediCard() -> some View {
        modifier(MediElevatedCard())
    }
}

// MARK: - Premium Background

struct MediBackground: View {
    var body: some View {
        ZStack {
            LinearGradient.mediBackground.ignoresSafeArea()
            
            // Decorative blurred circles
            GeometryReader { geo in
                Circle()
                    .fill(LinearGradient.medi([.mediCyan.opacity(0.15), .mediSky.opacity(0.05)]))
                    .frame(width: geo.size.width * 0.9)
                    .blur(radius: 60)
                    .offset(x: -geo.size.width * 0.3, y: -geo.size.height * 0.15)
                
                Circle()
                    .fill(LinearGradient.medi([.mediSky.opacity(0.12), .mediPrimary.opacity(0.04)]))
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 50)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Premium Avatar with gradient ring

struct MediAvatar: View {
    let name: String
    var size: CGFloat = 44
    
    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }
    
    private var gradientColors: [Color] {
        let palettes: [[Color]] = [
            [.mediCyan, .mediSky],
            [.mediSky, .mediPrimary],
            [.mediSuccess, .mediCyan],
            [.mediPrimary, .mediDeep],
            [Color(red: 0.55, green: 0.45, blue: 0.92), .mediSky],
            [Color(red: 0.20, green: 0.75, blue: 0.75), .mediCyan],
        ]
        return palettes[abs(name.hashValue) % palettes.count]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient.medi(gradientColors))
            Circle()
                .fill(LinearGradient.mediShine)
            Circle()
                .stroke(.white.opacity(0.4), lineWidth: 1.5)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: gradientColors.first?.opacity(0.4) ?? .clear, radius: 8, y: 3)
    }
}

// MARK: - Premium Badge

struct MediBadge: View {
    let text: String
    let color: Color
    let bgColor: Color
    
    init(_ text: String, color: Color = .mediSuccess, bgColor: Color? = nil) {
        self.text = text
        self.color = color
        self.bgColor = bgColor ?? color.opacity(0.12)
    }
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(bgColor)
                    .overlay(
                        Capsule().stroke(color.opacity(0.25), lineWidth: 0.5)
                    )
            )
            .foregroundStyle(color)
    }
}

// MARK: - Premium Button

struct MediButtonStyle: ButtonStyle {
    var colors: [Color] = [.mediCyan, .mediPrimary]
    var isSecondary: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                ZStack {
                    if isSecondary {
                        Color.mediBgSoft
                    } else {
                        LinearGradient.medi(colors)
                        LinearGradient.mediShine
                    }
                }
            )
            .foregroundStyle(isSecondary ? Color.mediPrimary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSecondary ? Color.mediPrimary.opacity(0.2) : .white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isSecondary ? .clear : (colors.first?.opacity(0.4) ?? .clear),
                    radius: configuration.isPressed ? 6 : 14,
                    y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Premium TextField

struct MediTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    isFocused ? LinearGradient.medi([.mediCyan, .mediPrimary])
                              : LinearGradient.medi([.mediTextMuted, .mediTextMuted])
                )
                .frame(width: 22)
            
            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.mediTextMuted))
                    .focused($isFocused)
                    .foregroundStyle(Color.mediText)
                    .font(.system(size: 16, design: .rounded))
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.mediTextMuted))
                    .focused($isFocused)
                    .foregroundStyle(Color.mediText)
                    .font(.system(size: 16, design: .rounded))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isFocused ? LinearGradient.medi([.mediCyan, .mediPrimary])
                              : LinearGradient.medi([.mediPrimary.opacity(0.15), .mediSky.opacity(0.1)]),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .shadow(color: isFocused ? .mediCyan.opacity(0.2) : .clear, radius: 8, y: 2)
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Section Header

struct MediSectionHeader: View {
    let title: String
    let icon: String
    var color: Color = .mediPrimary
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient.medi([color.opacity(0.2), color.opacity(0.08)]))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Color.mediTextSoft)
            Spacer()
        }
    }
}

// MARK: - Status helpers

struct MediStatus {
    static func color(for status: String) -> Color {
        switch status {
        case "confirmed", "active": return .mediSuccess
        case "pending": return .mediWarning
        case "in_progress": return .mediPrimary
        case "completed": return .mediTextMuted
        case "cancelled", "expired": return .mediDanger
        default: return .mediTextMuted
        }
    }
    
    static func gradient(for status: String) -> [Color] {
        switch status {
        case "confirmed", "active": return [.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)]
        case "pending": return [.mediWarning, Color(red: 0.95, green: 0.60, blue: 0.10)]
        case "in_progress": return [.mediCyan, .mediPrimary]
        case "cancelled", "expired": return [.mediDanger, Color(red: 0.85, green: 0.25, blue: 0.30)]
        default: return [.mediTextMuted, .mediTextSoft]
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


// MARK: - Typography

extension Font {
    static func mediTitle(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func mediHeadline(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func mediBody(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func mediCaption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func mediNumber(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: - Animated Logo (heartbeat + ECG wave)

struct MediAnimatedLogo: View {
    var size: CGFloat = 96
    @State private var pulse = false
    @State private var wavePhase: CGFloat = 0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Outer glow that breathes
            Circle()
                .fill(LinearGradient.medi([.mediCyan.opacity(0.35), .mediSky.opacity(0.1)]))
                .frame(width: size * 1.45, height: size * 1.45)
                .blur(radius: size * 0.22)
                .opacity(glowOpacity)
                .scaleEffect(pulse ? 1.08 : 0.96)
            
            // Pulse rings
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .stroke(Color.mediCyan.opacity(0.4), lineWidth: 1.5)
                    .frame(width: size, height: size)
                    .scaleEffect(pulse ? 1.35 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 1.8)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.9),
                        value: pulse
                    )
            }
            
            // Main circle
            Circle()
                .fill(LinearGradient.mediHero)
                .frame(width: size, height: size)
            Circle()
                .fill(LinearGradient.mediShine)
                .frame(width: size, height: size)
            Circle()
                .stroke(.white.opacity(0.45), lineWidth: 1.5)
                .frame(width: size, height: size)
            
            // ECG wave
            ECGWave(phase: wavePhase)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white, .white.opacity(0.3)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size * 0.72, height: size * 0.34)
                .offset(y: size * 0.16)
            
            // Heart that beats
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.3, weight: .medium))
                .foregroundStyle(.white)
                .offset(y: -size * 0.13)
                .scaleEffect(pulse ? 1.12 : 1.0)
                .shadow(color: .white.opacity(0.5), radius: pulse ? 8 : 3)
        }
        .frame(width: size * 1.45, height: size * 1.45)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.7
            }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                wavePhase = 1
            }
        }
    }
}

/// ECG line that scrolls
struct ECGWave: Shape {
    var phase: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let mid = h / 2
        
        // Normalized ECG pattern points (x 0-1, y -1 to 1)
        let pattern: [(CGFloat, CGFloat)] = [
            (0.00, 0), (0.14, 0),
            (0.20, -0.18),           // P wave
            (0.26, 0),
            (0.32, 0.28),            // Q
            (0.38, -1.0),            // R spike
            (0.44, 0.45),            // S
            (0.50, 0),
            (0.62, -0.32),           // T wave
            (0.72, 0), (1.00, 0)
        ]
        
        // Draw two cycles offset by phase for continuous scroll
        for cycle in 0..<2 {
            let offset = (CGFloat(cycle) - phase) * w
            for (i, pt) in pattern.enumerated() {
                let x = offset + pt.0 * w
                let y = mid + pt.1 * mid * 0.85
                if i == 0 && cycle == 0 {
                    p.move(to: CGPoint(x: x, y: y))
                } else if i == 0 {
                    p.addLine(to: CGPoint(x: x, y: y))
                } else {
                    p.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        return p
    }
}

// MARK: - Small animated pulse icon (for headers)

struct MediPulseIcon: View {
    var size: CGFloat = 54
    @State private var beat = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: size, height: size)
            Circle()
                .stroke(.white.opacity(0.35), lineWidth: 1.5)
                .frame(width: size, height: size)
                .scaleEffect(beat ? 1.12 : 1.0)
                .opacity(beat ? 0.3 : 1)
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(.white)
                .scaleEffect(beat ? 1.06 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                beat = true
            }
        }
    }
}
