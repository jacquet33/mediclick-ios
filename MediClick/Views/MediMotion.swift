import SwiftUI

// MARK: - Movimiento y respuesta táctil de la app
// Los mismos efectos de la demo "Cómo funciona" del sitio: check que se dibuja,
// aparición escalonada, tarjetas que responden al scroll y al toque, punto "en vivo".

// MARK: Confirmación global

extension Notification.Name {
    static let mediExito = Notification.Name("mediExito")
}

enum MediFeedback {
    /// Muestra la confirmación animada sobre toda la app. Se demora apenas
    /// para que se vea después de cerrar la hoja desde la que se llamó.
    static func exito(_ titulo: String, _ detalle: String? = nil) {
        var info: [String: String] = ["t": titulo]
        if let detalle, !detalle.isEmpty { info["d"] = detalle }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NotificationCenter.default.post(name: .mediExito, object: nil, userInfo: info)
        }
    }
}

struct MediCheckShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY + r.height * 0.04))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.36, y: r.maxY - r.height * 0.12))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.14))
        return p
    }
}

/// Círculo y tilde que se dibujan, con un halo que se expande.
struct MediCheckmark: View {
    var size: CGFloat = 84
    var color: Color = .mediSuccess
    @State private var circulo: CGFloat = 0
    @State private var tilde: CGFloat = 0
    @State private var halo = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .scaleEffect(halo ? 1.35 : 0.6)
                .opacity(halo ? 0 : 1)
            Circle()
                .fill(color.opacity(0.08))
            Circle()
                .trim(from: 0, to: circulo)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                .rotationEffect(.degrees(-90))
            MediCheckShape()
                .trim(from: 0, to: tilde)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round, lineJoin: .round))
                .padding(size * 0.28)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { circulo = 1 }
            withAnimation(.easeOut(duration: 0.32).delay(0.45)) { tilde = 1 }
            withAnimation(.easeOut(duration: 0.9).delay(0.5)) { halo = true }
        }
    }
}

private struct MediExito: Identifiable {
    let id = UUID()
    let titulo: String
    let detalle: String?
}

private struct MediExitoCard: View {
    let exito: MediExito
    @State private var dentro = false

    var body: some View {
        VStack(spacing: 14) {
            MediCheckmark()
            Text(exito.titulo)
                .font(.mediHeadline(18))
                .foregroundStyle(Color.mediText)
                .multilineTextAlignment(.center)
            if let d = exito.detalle {
                Text(d)
                    .font(.mediCaption(14))
                    .foregroundStyle(Color.mediTextSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(maxWidth: 290)
        .background(Color.mediSurface)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.mediBorder, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 30, y: 14)
        .scaleEffect(dentro ? 1 : 0.86)
        .opacity(dentro ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) { dentro = true }
        }
    }
}

/// Se aplica una vez en la raíz (MainTabView).
struct MediExitoHost: ViewModifier {
    @State private var actual: MediExito?
    @State private var pulsos = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if let e = actual {
                    ZStack {
                        Color.black.opacity(0.16)
                            .ignoresSafeArea()
                            .onTapGesture { cerrar() }
                        MediExitoCard(exito: e)
                    }
                    .id(e.id)
                    .transition(.opacity)
                }
            }
            .sensoryFeedback(.success, trigger: pulsos)
            .onReceive(NotificationCenter.default.publisher(for: .mediExito)) { n in
                let t = (n.userInfo?["t"] as? String) ?? "Listo"
                let d = n.userInfo?["d"] as? String
                let nuevo = MediExito(titulo: t, detalle: d)
                withAnimation(.easeOut(duration: 0.2)) { actual = nuevo }
                pulsos += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                    if actual?.id == nuevo.id { cerrar() }
                }
            }
    }

    private func cerrar() {
        withAnimation(.easeOut(duration: 0.25)) { actual = nil }
    }
}

// MARK: Aparición escalonada

struct MediAparecer: ViewModifier {
    let indice: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
            .onAppear {
                guard !visible else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(Double(min(indice, 8)) * 0.055)) {
                    visible = true
                }
            }
    }
}

// MARK: Toque

/// Tarjetas y filas tocables: se hunden con resorte y dan un toque háptico suave.
struct MediPressStyle: ButtonStyle {
    var escala: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? escala : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: configuration.isPressed) { _, apretado in apretado }
    }
}

// MARK: Punto en vivo

struct MediLiveDot: View {
    var color: Color = .mediSuccess
    @State private var latido = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .background(
                Circle()
                    .stroke(color.opacity(0.55), lineWidth: 2)
                    .scaleEffect(latido ? 2.6 : 1)
                    .opacity(latido ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { latido = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: Aura del encabezado

/// Luces suaves que flotan detrás del encabezado de Inicio.
struct MediAura: View {
    @State private var mover = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 170, height: 170)
                .blur(radius: 36)
                .offset(x: mover ? 90 : 40, y: mover ? -40 : -10)
            Circle()
                .fill(Color.mediTeal.opacity(0.35))
                .frame(width: 140, height: 140)
                .blur(radius: 40)
                .offset(x: mover ? -70 : -110, y: mover ? 40 : 60)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { mover = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: Número que cuenta

/// Muestra un número que sube desde 0 la primera vez y rueda al cambiar.
struct MediContador: View {
    let valor: Int
    var font: Font = .system(size: 24, weight: .medium)
    @State private var mostrado = 0

    var body: some View {
        Text("\(mostrado)")
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(mostrado)))
            .onAppear {
                withAnimation(.snappy(duration: 0.8).delay(0.15)) { mostrado = valor }
            }
            .onChange(of: valor) { _, nuevo in
                withAnimation(.snappy) { mostrado = nuevo }
            }
    }
}

// MARK: - Atajos

extension View {
    /// Entra con fundido y un leve desplazamiento; `indice` escalona la lista.
    func mediAparecer(_ indice: Int = 0) -> some View {
        modifier(MediAparecer(indice: indice))
    }

    /// La tarjeta se acomoda al entrar y salir del área visible mientras se hace scroll.
    func mediScrollReveal() -> some View {
        scrollTransition(.interactive, axis: .vertical) { contenido, fase in
            contenido
                .opacity(fase.isIdentity ? 1 : 0.6)
                .scaleEffect(fase.isIdentity ? 1 : 0.96)
        }
    }

    /// Para un QR o una imagen que se "arma" al aparecer.
    func mediRevelar() -> some View {
        modifier(MediRevelar())
    }

    func mediExitoHost() -> some View {
        modifier(MediExitoHost())
    }
}

struct MediRevelar: ViewModifier {
    @State private var listo = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(listo ? 1 : 0.88)
            .opacity(listo ? 1 : 0)
            .blur(radius: listo ? 0 : 6)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { listo = true }
            }
    }
}
