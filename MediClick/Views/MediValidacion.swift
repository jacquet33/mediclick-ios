import SwiftUI

// MARK: - Validaciones de formularios (mismas reglas que el servidor)
// Cada función devuelve el mensaje de error, o nil si el valor es válido.

enum MediValida {
    static func digitos(_ s: String) -> String { s.filter(\.isNumber) }
    static func limpio(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

    static func nombre(_ s: String, campo: String) -> String? {
        let t = limpio(s)
        if t.isEmpty { return "Completá el \(campo)" }
        if t.count < 2 { return "El \(campo) es muy corto" }
        let permitidos = CharacterSet.letters.union(CharacterSet(charactersIn: " '´-.")).union(.whitespaces)
        if t.unicodeScalars.contains(where: { !permitidos.contains($0) }) { return "El \(campo) solo puede tener letras" }
        return nil
    }

    static func dni(_ s: String, obligatorio: Bool = false) -> String? {
        let t = limpio(s)
        if t.isEmpty { return obligatorio ? "Completá el DNI" : nil }
        if t.contains(where: { !$0.isNumber && $0 != "." && $0 != " " }) { return "El DNI solo lleva números" }
        let d = digitos(t)
        if d.count < 7 || d.count > 8 { return "El DNI tiene que tener 7 u 8 números" }
        if Set(d).count == 1 { return "Revisá el DNI" }
        return nil
    }

    static func digitoCuil(_ diez: String) -> Int {
        let pesos = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]
        let suma = zip(diez.compactMap { $0.wholeNumberValue }, pesos).reduce(0) { $0 + $1.0 * $1.1 }
        let r = 11 - (suma % 11)
        return r == 11 ? 0 : r
    }

    static func cuilValido(_ s: String) -> Bool {
        let d = digitos(s)
        guard d.count == 11, ["20", "23", "24", "27", "30", "33", "34"].contains(String(d.prefix(2))) else { return false }
        let v = digitoCuil(String(d.prefix(10)))
        return v != 10 && v == d.last?.wholeNumberValue
    }

    /// Calcula el CUIL desde DNI y sexo ("female" / "male"), igual que el servidor.
    static func cuilDesdeDni(_ dni: String, sexo: String) -> String? {
        let d = digitos(dni)
        guard d.count >= 7, d.count <= 8 else { return nil }
        let ocho = String(repeating: "0", count: 8 - d.count) + d
        var pref: String
        switch sexo { case "male": pref = "20"; case "female": pref = "27"; default: return nil }
        var v = digitoCuil(pref + ocho)
        if v == 10 { v = pref == "20" ? 9 : 4; pref = "23" }
        return pref + ocho + String(v)
    }

    static func cuil(_ s: String, dni: String) -> String? {
        let t = limpio(s)
        if t.isEmpty { return nil }
        let d = digitos(t)
        if d.count != 11 { return "El CUIL tiene 11 números (XX-XXXXXXXX-X)" }
        if !cuilValido(d) { return "El CUIL no es válido: revisá el último número" }
        let dd = digitos(dni)
        if !dd.isEmpty {
            let ocho = String(repeating: "0", count: max(0, 8 - dd.count)) + dd
            if !d.contains(ocho) { return "El CUIL no corresponde al DNI" }
        }
        return nil
    }

    static func formatoCuil(_ d: String) -> String {
        let x = digitos(d)
        guard x.count == 11 else { return d }
        return "\(x.prefix(2))-\(x.dropFirst(2).prefix(8))-\(x.suffix(1))"
    }

    static func telefono(_ s: String) -> String? {
        let t = limpio(s)
        if t.isEmpty { return nil }
        if t.contains(where: { !$0.isNumber && !" +-()".contains($0) }) { return "El teléfono solo lleva números" }
        let d = digitos(t)
        if d.count < 10 || d.count > 13 { return "Poné el celular con característica, ej: 3447 414137" }
        return nil
    }

    static func email(_ s: String) -> String? {
        let t = limpio(s)
        if t.isEmpty { return nil }
        let ok = t.range(of: #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
        return ok ? nil : "El email no es válido"
    }

    static func nacimiento(_ fecha: Date) -> String? {
        if fecha > Date() { return "La fecha de nacimiento no puede ser futura" }
        if let lim = Calendar.current.date(byAdding: .year, value: -120, to: Date()), fecha < lim { return "Revisá la fecha de nacimiento" }
        return nil
    }

    static func diagnostico(_ s: String) -> String? {
        let t = limpio(s)
        if t.isEmpty { return "Indicá el diagnóstico" }
        if t.count < 3 { return "El diagnóstico es muy corto" }
        if t.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace }) { return "Escribí el diagnóstico en palabras" }
        return nil
    }

    /// CIE-10: una letra, dos números y opcionalmente un punto con 1 o 2 números (ej: J02.9).
    static func cie10(_ s: String) -> String? {
        let t = limpio(s).uppercased()
        if t.isEmpty { return nil }
        let ok = t.range(of: #"^[A-Z][0-9]{2}(\.[0-9A-Z]{1,2})?$"#, options: .regularExpression) != nil
        return ok ? nil : "Código CIE-10 inválido. Ej: J02.9"
    }

    /// Cantidad de la dosis: número mayor a 0 (500, 1, 0,5, 1/2).
    static func cantidad(_ s: String) -> String? {
        let t = limpio(s).replacingOccurrences(of: ",", with: ".")
        if t.isEmpty { return "Completá la dosis" }
        if t.range(of: #"^[0-9]+/[0-9]+$"#, options: .regularExpression) != nil {
            let p = t.split(separator: "/").compactMap { Double($0) }
            return p.count == 2 && p[0] > 0 && p[1] > 0 ? nil : "Dosis inválida"
        }
        guard let n = Double(t) else { return "La dosis tiene que ser un número" }
        if n <= 0 { return "La dosis tiene que ser mayor a 0" }
        if n > 100_000 { return "Revisá la dosis" }
        return nil
    }

    static func textoLibre(_ s: String, campo: String) -> String? {
        limpio(s).isEmpty ? "Completá la \(campo)" : nil
    }
}

// MARK: - Mensaje de error debajo de un campo

struct MediFieldError: View {
    let mensaje: String?

    var body: some View {
        if let m = mensaje {
            Label(m, systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.mediDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

extension View {
    /// Borde rojo cuando hay error.
    func mediErrorBorde(_ hayError: Bool, radio: CGFloat = 10) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radio)
                .stroke(Color.mediDanger, lineWidth: hayError ? 1.2 : 0)
        )
        .animation(.snappy, value: hayError)
    }
}
