import SwiftUI
import Observation

/// Servicios de la plataforma que se prenden y apagan desde el panel de administración,
/// sin publicar una versión nueva de la app (GET /api/v1/public/config).
@Observable
final class PlataformaConfig {
    static let shared = PlataformaConfig()

    /// Receta electrónica: apagada hasta que ReNaPDiS apruebe la plataforma.
    private(set) var recetas: Bool = UserDefaults.standard.bool(forKey: "servicio_recetas")

    private struct Resp: Decodable {
        struct Servicios: Decodable { let recetas: Bool? }
        let servicios: Servicios?
    }

    @MainActor
    func cargar() async {
        guard let r: Resp = try? await APIClient.shared.get("/api/v1/public/config") else { return }
        let valor = r.servicios?.recetas ?? false
        withAnimation(.snappy) { recetas = valor }
        UserDefaults.standard.set(valor, forKey: "servicio_recetas")
    }
}
