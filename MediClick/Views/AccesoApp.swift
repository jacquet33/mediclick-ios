import SwiftUI

/// La app es solo para cuentas con plan pago: el alta y el pago se hacen en la web.
/// Consulta GET /api/v1/app/acceso al abrir y cada vez que la app vuelve a primer plano.
struct AccesoApp<Contenido: View>: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.scenePhase) private var fase
    @ViewBuilder var contenido: () -> Contenido

    private enum Estado: Equatable { case revisando, permitido, bloqueado(String) }
    @State private var estado: Estado = UserDefaults.standard.bool(forKey: "app_acceso_ok") ? .permitido : .revisando

    private struct Resp: Decodable { let permitido: Bool; let motivo: String? }

    var body: some View {
        Group {
            switch estado {
            case .permitido: contenido()
            case .revisando:
                ZStack { MediBackground(); ProgressView() }
            case .bloqueado(let motivo):
                SinPlanView(motivo: motivo) { await revisar() } salir: { auth.logout() }
            }
        }
        .task { await revisar() }
        .onChange(of: fase) { _, f in if f == .active { Task { await revisar() } } }
    }

    @MainActor
    private func revisar() async {
        do {
            let r: Resp = try await APIClient.shared.get("/api/v1/app/acceso")
            UserDefaults.standard.set(r.permitido, forKey: "app_acceso_ok")
            withAnimation(.snappy) {
                estado = r.permitido ? .permitido : .bloqueado(r.motivo ?? "Tu cuenta no tiene un plan activo.")
            }
        } catch {
            // Sin conexión: si ya estaba habilitada se sigue usando; si no, se muestra el aviso
            if estado == .revisando { estado = .bloqueado("No pudimos verificar tu plan. Revisá tu conexión e intentá de nuevo.") }
        }
    }
}

private struct SinPlanView: View {
    let motivo: String
    let reintentar: () async -> Void
    let salir: () -> Void
    @State private var revisando = false

    var body: some View {
        ZStack {
            MediBackground()
            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LinearGradient.medi([.mediCyan, .mediSky]))
                    .symbolEffect(.bounce, value: revisando)
                Text("Activá tu plan para usar la app")
                    .font(.mediHeadline(20))
                    .foregroundStyle(Color.mediText)
                    .multilineTextAlignment(.center)
                Text(motivo)
                    .font(.mediCaption(15))
                    .foregroundStyle(Color.mediTextSoft)
                    .multilineTextAlignment(.center)
                Button {
                    Task { revisando = true; await reintentar(); revisando = false }
                } label: {
                    if revisando { ProgressView().tint(.white) } else { Label("Ya lo activé, revisar de nuevo", systemImage: "arrow.clockwise") }
                }
                .buttonStyle(MediButtonStyle())
                Button("Cerrar sesión", action: salir)
                    .buttonStyle(MediButtonStyle(isSecondary: true))
            }
            .padding(28)
            .mediAparecer(0)
        }
    }
}
